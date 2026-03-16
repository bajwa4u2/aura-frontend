import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../ai/providers.dart';

class ComposeScreen extends ConsumerStatefulWidget {
  final String? replyToPostId;

  const ComposeScreen({
    super.key,
    this.replyToPostId,
  });

  @override
  ConsumerState<ComposeScreen> createState() => _ComposeScreenState();
}

enum _PostVisibility { public, followers, private }

enum _AttachmentType { image, video }

enum _AttachmentSource { camera, gallery }

class _ComposeAttachment {
  _ComposeAttachment({
    required this.localId,
    required this.type,
    required this.source,
    required this.captionController,
    this.localFile,
    this.localBytes,
    this.width,
    this.height,
    this.durationMs,
    this.mediaId,
    this.url,
    this.thumbUrl,
    this.uploading = false,
    this.attachedToDraft = false,
    this.error,
  });

  final String localId;
  final _AttachmentType type;
  final _AttachmentSource source;
  final TextEditingController captionController;

  XFile? localFile;
  Uint8List? localBytes;

  int? width;
  int? height;
  int? durationMs;

  String? mediaId;
  String? url;
  String? thumbUrl;

  bool uploading;
  bool attachedToDraft;
  String? error;

  bool get isImage => type == _AttachmentType.image;
  bool get isVideo => type == _AttachmentType.video;
  bool get isUploaded => (mediaId ?? '').trim().isNotEmpty;

  void dispose() {
    captionController.dispose();
  }
}

class _ComposeScreenState extends ConsumerState<ComposeScreen> {
  static const int _limit = 2000;
  static const int _maxAttachments = 5;

  final _textController = TextEditingController();

  bool _posting = false;
  bool _saving = false;
  bool _showTextError = false;
  bool _uploadingMedia = false;

  _PostVisibility _visibility = _PostVisibility.public;

  final List<_ComposeAttachment> _attachments = [];

  DateTime? _lastSavedAt;
  Timer? _autosaveDebounce;

  bool _auditBusy = false;
  DateTime? _lastAuditAt;
  Map<String, dynamic>? _auditResult;
  String? _auditError;

  bool get _isReply => widget.replyToPostId != null;

  String get _replyToPostId => (widget.replyToPostId ?? '').trim();

  bool get _hasText => _textController.text.trim().isNotEmpty;
  bool get _textTooLong => _textController.text.trim().length > _limit;
  bool get _hasAttachments => _attachments.isNotEmpty;
  bool get _hasUploadingAttachments => _attachments.any((a) => a.uploading);
  bool get _canAddMoreAttachments =>
      !_isReply && _attachments.length < _maxAttachments;

  bool get _canPublish {
    if (!_hasText) return false;
    if (_textTooLong) return false;
    if (_hasUploadingAttachments) return false;
    return true;
  }

  Map<String, dynamic> _asMap(dynamic v) {
    if (v == null) return <String, dynamic>{};

    if (v is Map) {
      return Map<String, dynamic>.from(v as Map);
    }

    if (v is String) {
      final s = v.trim();
      if (s.isEmpty) return <String, dynamic>{};
      try {
        final decoded = jsonDecode(s);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded as Map);
        }
      } catch (_) {}
    }

    return <String, dynamic>{};
  }

  Map<String, dynamic> _unwrapDataMap(dynamic v) {
    Map<String, dynamic> cur = _asMap(v);
    while (cur.containsKey('ok') &&
        cur.containsKey('data') &&
        cur['data'] is Map) {
      cur = Map<String, dynamic>.from(cur['data'] as Map);
    }
    return cur;
  }

  List<Map<String, dynamic>> _listOfMap(dynamic v) {
    if (v is List) {
      final out = <Map<String, dynamic>>[];
      for (final x in v) {
        if (x is Map) {
          out.add(Map<String, dynamic>.from(x.cast<String, dynamic>()));
        }
      }
      return out;
    }
    return const [];
  }

  String _str(dynamic v) => (v ?? '').toString().trim();

  List<String> _listOfString(dynamic v, {int take = 3}) {
    if (v is! List) return const [];

    final out = <String>[];
    final seen = <String>{};

    for (final item in v) {
      final s = _str(item);
      if (s.isEmpty) continue;

      final k = s.toLowerCase();
      if (seen.contains(k)) continue;

      seen.add(k);
      out.add(s);

      if (out.length >= take) break;
    }

    return out;
  }

  String _inferMime(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.webm')) return 'video/webm';
    return 'application/octet-stream';
  }

  String _visibilityApiValue(_PostVisibility value) {
    switch (value) {
      case _PostVisibility.public:
        return 'PUBLIC';
      case _PostVisibility.followers:
        return 'FOLLOWERS';
      case _PostVisibility.private:
        return 'PRIVATE';
    }
  }

  _PostVisibility _visibilityFromApi(dynamic value) {
    final raw = (value ?? '').toString().trim().toUpperCase();
    switch (raw) {
      case 'FOLLOWERS':
        return _PostVisibility.followers;
      case 'PRIVATE':
        return _PostVisibility.private;
      case 'PUBLIC':
      default:
        return _PostVisibility.public;
    }
  }

  String _visibilityLabel(_PostVisibility value) {
    switch (value) {
      case _PostVisibility.public:
        return 'Public';
      case _PostVisibility.followers:
        return 'Followers';
      case _PostVisibility.private:
        return 'Private';
    }
  }

  String _visibilityHelp(_PostVisibility value) {
    switch (value) {
      case _PostVisibility.public:
        return 'Visible to everyone, including visitors.';
      case _PostVisibility.followers:
        return 'Visible only to followers and approved member surfaces.';
      case _PostVisibility.private:
        return 'Visible only to you.';
    }
  }

  Dio _cleanUploadDio() {
    return Dio(
      BaseOptions(
        responseType: ResponseType.plain,
        followRedirects: true,
      ),
    );
  }

  Future<Map<String, int>?> _decodeImageSize(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final img = frame.image;
    return {'width': img.width, 'height': img.height};
  }

  @override
  void initState() {
    super.initState();

    if (!_isReply) {
      _loadDraft();
    }

    _textController.addListener(() {
      _scheduleAutosave();
      if (mounted) {
        setState(() {
          if (_showTextError && _hasText) {
            _showTextError = false;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _autosaveDebounce?.cancel();
    _textController.dispose();
    for (final attachment in _attachments) {
      attachment.dispose();
    }
    super.dispose();
  }

  Future<void> _loadDraft() async {
    if (_isReply) return;

    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/posts/draft');
      final data = _asMap(res.data);
      final draftSource = data['draft'] ?? data;

      if (draftSource is! Map) return;

      final draft = Map<String, dynamic>.from(draftSource);
      final text = (draft['text'] ?? '').toString();
      final visibility = _visibilityFromApi(draft['visibility']);

      final updatedAtRaw = (draft['updatedAt'] ?? '').toString();
      final savedAt = DateTime.tryParse(updatedAtRaw)?.toLocal();

      final mediaItems = _listOfMap(draft['media']);

      final loadedAttachments = <_ComposeAttachment>[];
      for (final item in mediaItems) {
        final typeRaw = _str(item['type']).toUpperCase();
        final mediaId = _str(item['id']);
        if (mediaId.isEmpty) continue;

        final isVideo = typeRaw == 'VIDEO';
        final captionController =
            TextEditingController(text: _str(item['caption']));
        captionController.addListener(_scheduleAutosave);

        loadedAttachments.add(
          _ComposeAttachment(
            localId: mediaId,
            type: isVideo ? _AttachmentType.video : _AttachmentType.image,
            source: _AttachmentSource.gallery,
            captionController: captionController,
            mediaId: mediaId,
            url: _str(item['displayUrl']).isNotEmpty
                ? _str(item['displayUrl'])
                : _str(item['url']),
            thumbUrl: _str(item['thumbnailUrl']).isNotEmpty
                ? _str(item['thumbnailUrl'])
                : _str(item['thumbUrl']),
            width: item['width'] is int
                ? item['width'] as int
                : int.tryParse('${item['width'] ?? ''}'),
            height: item['height'] is int
                ? item['height'] as int
                : int.tryParse('${item['height'] ?? ''}'),
            durationMs: item['duration'] is int
                ? item['duration'] as int
                : int.tryParse('${item['duration'] ?? ''}'),
            uploading: false,
            attachedToDraft: true,
          ),
        );
      }

      if (!mounted) return;

      setState(() {
        _textController.text = text;
        _visibility = visibility;
        _lastSavedAt = savedAt;
        _attachments
          ..clear()
          ..addAll(loadedAttachments);

        if (_hasText) {
          _showTextError = false;
        }
      });
    } catch (_) {
      // best-effort
    }
  }

  void _scheduleAutosave() {
    if (_isReply) return;

    _autosaveDebounce?.cancel();
    _autosaveDebounce = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      if (_posting || _saving || _uploadingMedia) return;
      if (!_hasText) return;
      _saveDraft(silent: true);
    });
  }

  void _setVisibility(_PostVisibility next) {
    if (_posting) return;
    if (_visibility == next) return;

    setState(() {
      _visibility = next;
    });

    _scheduleAutosave();
  }

  Future<void> _pickImageFromGallery() async {
    if (!_canAddMoreAttachments || _posting) return;

    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    await _addPickedFile(
      file,
      type: _AttachmentType.image,
      source: _AttachmentSource.gallery,
    );
  }

  Future<void> _pickImageFromCamera() async {
    if (!_canAddMoreAttachments || _posting) return;

    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.camera);
    if (file == null) return;

    await _addPickedFile(
      file,
      type: _AttachmentType.image,
      source: _AttachmentSource.camera,
    );
  }

  Future<void> _pickVideoFromGallery() async {
    if (!_canAddMoreAttachments || _posting) return;

    final picker = ImagePicker();
    final file = await picker.pickVideo(source: ImageSource.gallery);
    if (file == null) return;

    await _addPickedFile(
      file,
      type: _AttachmentType.video,
      source: _AttachmentSource.gallery,
    );
  }

  Future<void> _pickVideoFromCamera() async {
    if (!_canAddMoreAttachments || _posting) return;

    final picker = ImagePicker();
    final file = await picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(seconds: 30),
    );
    if (file == null) return;

    await _addPickedFile(
      file,
      type: _AttachmentType.video,
      source: _AttachmentSource.camera,
    );
  }

  Future<void> _addPickedFile(
    XFile file, {
    required _AttachmentType type,
    required _AttachmentSource source,
  }) async {
    if (_attachments.length >= _maxAttachments) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 5 attachments per post.')),
      );
      return;
    }

    Uint8List? bytes;
    int? width;
    int? height;

    if (type == _AttachmentType.image) {
      bytes = await file.readAsBytes();
      try {
        final size = await _decodeImageSize(bytes);
        width = size?['width'];
        height = size?['height'];
      } catch (_) {}
    }

    final attachment = _ComposeAttachment(
      localId: '${DateTime.now().microsecondsSinceEpoch}_${file.name}',
      type: type,
      source: source,
      captionController: TextEditingController(),
      localFile: file,
      localBytes: bytes,
      width: width,
      height: height,
      uploading: true,
      attachedToDraft: false,
    );

    attachment.captionController.addListener(_scheduleAutosave);

    setState(() {
      _attachments.add(attachment);
      _uploadingMedia = true;
    });

    try {
      await _uploadAttachment(attachment);
      if (!mounted) return;
      await _saveDraft(silent: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        attachment.error = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not upload attachment: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploadingMedia = _attachments.any((a) => a.uploading);
        });
      }
    }
  }

  Future<void> _uploadAttachment(_ComposeAttachment attachment) async {
    final dio = ref.read(dioProvider);
    final file = attachment.localFile;
    if (file == null) {
      throw Exception('Attachment file missing.');
    }

    final bytes = await file.readAsBytes();
    final mime = _inferMime(file.name);

    final pres = await dio.post(
      '/media/presign',
      data: {
        'fileName': file.name,
        'mimeType': mime,
        'bytes': bytes.length,
        'kind': attachment.isImage ? 'IMAGE' : 'VIDEO',
        'source':
            attachment.source == _AttachmentSource.camera ? 'CAMERA' : 'GALLERY',
        if (attachment.isImage) 'width': attachment.width,
        if (attachment.isImage) 'height': attachment.height,
        if (attachment.isVideo && attachment.durationMs != null)
          'duration': attachment.durationMs,
      },
    );

    final presigned = _unwrapDataMap(pres.data);
    final mediaMap = _asMap(presigned['media']);
    final mediaId = _str(mediaMap['id']);
    final upload = _asMap(presigned['upload']);
    final uploadUrl = _str(upload['url']);
    final headers = _asMap(upload['headers']);

    if (mediaId.isEmpty) {
      throw Exception('Media ID missing from presign response.');
    }
    if (uploadUrl.isEmpty) {
      throw Exception('Upload URL missing from presign response.');
    }

    final uploadDio = _cleanUploadDio();
    final uploadHeaders = <String, String>{};
    headers.forEach((k, v) {
      if (v == null) return;
      uploadHeaders[k.toString()] = v.toString();
    });
    if (!uploadHeaders.containsKey('Content-Type')) {
      uploadHeaders['Content-Type'] = mime;
    }

    await uploadDio.put(
      uploadUrl,
      data: bytes,
      options: Options(
        headers: uploadHeaders,
        contentType: uploadHeaders['Content-Type'],
        responseType: ResponseType.plain,
        followRedirects: true,
        validateStatus: (code) => code != null && code >= 200 && code < 300,
      ),
    );

    await dio.post('/media/$mediaId/confirm');
    await dio.post('/media/$mediaId/ready');

    final patchBody = <String, dynamic>{
      'caption': attachment.captionController.text.trim().isEmpty
          ? null
          : attachment.captionController.text.trim(),
      'editDisclosure': false,
      if (attachment.width != null) 'width': attachment.width,
      if (attachment.height != null) 'height': attachment.height,
    };

    final patch = await dio.patch('/media/$mediaId', data: patchBody);
    final patched = _unwrapDataMap(patch.data);

    if (!mounted) return;

    setState(() {
      attachment.mediaId = mediaId;
      attachment.url = _str(patched['displayUrl']).isNotEmpty
          ? _str(patched['displayUrl'])
          : (_str(patched['url']).isNotEmpty ? _str(patched['url']) : null);
      attachment.thumbUrl = _str(patched['thumbnailUrl']).isNotEmpty
          ? _str(patched['thumbnailUrl'])
          : (_str(patched['thumbUrl']).isNotEmpty
              ? _str(patched['thumbUrl'])
              : null);
      attachment.uploading = false;
      attachment.error = null;
    });
  }

  Future<void> _persistAttachmentMetadata(_ComposeAttachment attachment) async {
    final mediaId = (attachment.mediaId ?? '').trim();
    if (mediaId.isEmpty) return;

    try {
      final dio = ref.read(dioProvider);
      await dio.patch(
        '/media/$mediaId',
        data: {
          'caption': attachment.captionController.text.trim().isEmpty
              ? null
              : attachment.captionController.text.trim(),
        },
      );
    } catch (_) {
      // best-effort
    }
  }

  Future<void> _removeAttachment(_ComposeAttachment attachment) async {
    if (_posting) return;

    final mediaId = (attachment.mediaId ?? '').trim();
    final wasAttachedToDraft = attachment.attachedToDraft;

    setState(() {
      _attachments.removeWhere((a) => a.localId == attachment.localId);
      _uploadingMedia = _attachments.any((a) => a.uploading);
    });

    attachment.dispose();

    if (_isReply) return;

    if (wasAttachedToDraft) {
      await _saveDraft(silent: true);
      return;
    }

    if (mediaId.isNotEmpty) {
      try {
        final dio = ref.read(dioProvider);
        await dio.delete('/media/$mediaId');
      } catch (_) {
        // best-effort
      }
    }
  }

  void _moveAttachmentLeft(int index) {
    if (index <= 0 || index >= _attachments.length) return;
    setState(() {
      final item = _attachments.removeAt(index);
      _attachments.insert(index - 1, item);
    });
    _scheduleAutosave();
  }

  void _moveAttachmentRight(int index) {
    if (index < 0 || index >= _attachments.length - 1) return;
    setState(() {
      final item = _attachments.removeAt(index);
      _attachments.insert(index + 1, item);
    });
    _scheduleAutosave();
  }

  String _savedLine() {
    if (_isReply) {
      return 'Replies publish directly and do not use the main draft yet.';
    }
    if (_uploadingMedia) return 'Uploading attachments…';
    if (_saving) return 'Saving…';
    final dt = _lastSavedAt;
    if (dt == null) return 'Draft not saved yet.';
    return 'Draft saved ${_time(dt)}.';
  }

  Map<String, dynamic> _buildComposePayload() {
    return {
      'text': _textController.text.trim(),
      'visibility': _visibilityApiValue(_visibility),
      'media': _attachments
          .asMap()
          .entries
          .where((entry) => (entry.value.mediaId ?? '').trim().isNotEmpty)
          .map(
            (entry) => {
              'mediaId': entry.value.mediaId,
              'position': entry.key,
              'caption': entry.value.captionController.text.trim().isEmpty
                  ? null
                  : entry.value.captionController.text.trim(),
            },
          )
          .toList(),
    };
  }

  Future<void> _saveDraft({
    bool silent = false,
    bool allowWhilePosting = false,
  }) async {
    if (_isReply) return;
    if (_saving) return;
    if (_posting && !allowWhilePosting) return;

    if (!_hasText) {
      if (!silent && mounted) {
        setState(() => _showTextError = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Text is required.')),
        );
      }
      return;
    }

    setState(() => _saving = true);

    try {
      for (final attachment in _attachments) {
        await _persistAttachmentMetadata(attachment);
      }

      final dio = ref.read(dioProvider);
      final payload = _buildComposePayload();

      await dio.put('/posts/draft', data: payload);

      if (!mounted) return;
      setState(() {
        _lastSavedAt = DateTime.now();
        for (final attachment in _attachments) {
          if ((attachment.mediaId ?? '').trim().isNotEmpty) {
            attachment.attachedToDraft = true;
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save draft: $e')),
        );
      }
      rethrow;
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  bool get _auditCooldownActive {
    final t = _lastAuditAt;
    if (t == null) return false;
    return DateTime.now().difference(t) < const Duration(seconds: 15);
  }

  Future<Map<String, dynamic>?> _runAuraEditor({
    bool fromPublish = false,
  }) async {
    final text = _textController.text.trim();

    if (text.isEmpty) {
      setState(() {
        _auditError = 'Text is required.';
        _auditResult = null;
      });

      if (!fromPublish && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Text is required.')),
        );
      }
      return null;
    }

    if (_auditBusy) return _auditResult;

    setState(() {
      _auditBusy = true;
      _auditError = null;
      _lastAuditAt = DateTime.now();
      if (!fromPublish) {
        _auditResult = null;
      }
    });

    try {
      final repo = ref.read(aiRepoProvider);

      Map<String, dynamic> out;
      try {
        out = await repo.editorReview(text: text);
      } on DioException catch (e) {
        final code = e.response?.statusCode;
        if (code == 404) {
          out = await repo.claimAudit(text: text);
        } else {
          rethrow;
        }
      }

      if (!mounted) return null;

      setState(() {
        _auditResult = out;
      });

      return out;
    } catch (e) {
      if (!mounted) return null;

      setState(() {
        _auditError = e.toString();
      });

      if (!fromPublish) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Aura Editor could not run: $e')),
        );
      }

      return null;
    } finally {
      if (mounted) {
        setState(() => _auditBusy = false);
      }
    }
  }

  List<Map<String, String>> _spellingItems(Map<String, dynamic> r) {
    final raw = r['spelling'];
    if (raw is! List) return const [];

    final out = <Map<String, String>>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      final original = _str(m['original']);
      final suggestion = _str(m['suggestion']);
      if (original.isEmpty || suggestion.isEmpty) continue;
      out.add({'original': original, 'suggestion': suggestion});
      if (out.length >= 5) break;
    }

    return out;
  }

  List<Map<String, String>> _grammarItems(Map<String, dynamic> r) {
    final raw = r['grammar'];
    if (raw is! List) return const [];

    final out = <Map<String, String>>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      final issue = _str(m['issue']);
      final suggestion = _str(m['suggestion']);
      if (issue.isEmpty || suggestion.isEmpty) continue;
      out.add({'issue': issue, 'suggestion': suggestion});
      if (out.length >= 5) break;
    }

    return out;
  }

  List<String> _legacySignals(Map<String, dynamic> r) {
    final assumptions = _listOfMap(r['assumptions'])
        .take(3)
        .map((x) => _str(x['reason']))
        .where((s) => s.isNotEmpty);
    final clarity = _listOfMap(r['clarity_issues'])
        .take(3)
        .map((x) => _str(x['reason']))
        .where((s) => s.isNotEmpty);
    final tone = _listOfMap(r['tone_flags'])
        .take(2)
        .map((x) => _str(x['reason']))
        .where((s) => s.isNotEmpty);

    final combined = <String>[...clarity, ...assumptions, ...tone];
    final seen = <String>{};
    final out = <String>[];

    for (final s in combined) {
      final k = s.toLowerCase();
      if (k.isEmpty || seen.contains(k)) continue;
      seen.add(k);
      out.add(s);
      if (out.length >= 5) break;
    }

    return out;
  }

  String _legacyRefinement(Map<String, dynamic> r, String original) {
    final signals = _legacySignals(r);
    final firstLine = signals.isNotEmpty ? signals.first : '';

    final text = original.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (text.isEmpty) return '';

    final softened = text
        .replaceAll(
          RegExp(
            r'\b(always|never|everyone|no one|obviously|clearly|completely|totally)\b',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final example = softened.isEmpty ? text : softened;

    if (firstLine.isEmpty) {
      return 'Try tightening one sentence for clarity.\nExample: $example';
    }

    return '$firstLine\nExample: $example';
  }

  Future<void> _publishReplyNow() async {
    final dio = ref.read(dioProvider);

    if (_replyToPostId.isEmpty) {
      throw Exception('Reply target missing.');
    }

    await dio.post(
      '/posts/$_replyToPostId/reply',
      data: {
        'text': _textController.text.trim(),
      },
    );
  }

  Future<void> _publishPostNow() async {
    final dio = ref.read(dioProvider);
    await dio.post('/posts/draft/publish');
  }

  Future<void> _publishNow() async {
    if (_isReply) {
      await _publishReplyNow();
      return;
    }

    await _publishPostNow();
  }

  Future<void> _publish() async {
    if (_posting) return;

    if (!_hasText) {
      setState(() => _showTextError = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Text is required.')),
      );
      return;
    }

    if (_textTooLong) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Too long. Please shorten your post.')),
      );
      return;
    }

    if (_hasUploadingAttachments) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait for attachments to finish uploading.'),
        ),
      );
      return;
    }

    if (!_canPublish) return;

    final review = await _runAuraEditor(fromPublish: true);
    if (!mounted) return;

    final proceed = await _openAuraEditorSheet(
      reviewResult: review,
      publishMode: true,
    );
    if (proceed != true || !mounted) return;

    _autosaveDebounce?.cancel();

    setState(() => _posting = true);

    try {
      if (!_isReply) {
        await _saveDraft(
          silent: true,
          allowWhilePosting: true,
        );
      }

      await _publishNow();

      if (!mounted) return;
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not publish: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _posting = false);
      }
    }
  }

  Future<bool?> _openAuraEditorSheet({
    Map<String, dynamic>? reviewResult,
    bool publishMode = false,
  }) async {
    if (reviewResult != null && mounted) {
      setState(() {
        _auditResult = reviewResult;
        _auditError = null;
      });
    }

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AuraSurface.page,
      builder: (ctx) {
        final pad = MediaQuery.of(ctx).viewInsets.bottom;
        final r = reviewResult ?? _auditResult;

        final what = r == null ? '' : _str(r['what_this_is_doing']);
        final consider = r == null
            ? const <String>[]
            : _listOfString(r['things_to_consider'], take: 3);
        final strengthen = r == null
            ? const <String>[]
            : _listOfString(r['ways_to_strengthen'], take: 3);
        final civic = r == null ? '' : _str(r['civic_awareness']);
        final refinement = r == null
            ? ''
            : (_str(r['suggested_refinement']).isNotEmpty
                ? _str(r['suggested_refinement'])
                : _legacyRefinement(r, _textController.text));
        final spelling =
            r == null ? const <Map<String, String>>[] : _spellingItems(r);
        final grammar =
            r == null ? const <Map<String, String>>[] : _grammarItems(r);
        final legacySignals =
            r == null ? const <String>[] : _legacySignals(r);

        final hasAnyContent = what.isNotEmpty ||
            consider.isNotEmpty ||
            strengthen.isNotEmpty ||
            civic.isNotEmpty ||
            refinement.isNotEmpty ||
            spelling.isNotEmpty ||
            grammar.isNotEmpty ||
            legacySignals.isNotEmpty;

        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> rerun() async {
              setModalState(() {});
              final out = await _runAuraEditor(fromPublish: publishMode);
              if (!ctx.mounted) return;
              Navigator.of(ctx).pop(false);
              if (!mounted) return;
              await _openAuraEditorSheet(
                reviewResult: out,
                publishMode: publishMode,
              );
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AuraSpace.s16,
                  AuraSpace.s16,
                  AuraSpace.s16,
                  AuraSpace.s16 + pad,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Aura Editor', style: AuraText.title),
                      const SizedBox(height: AuraSpace.s8),
                      if (_auditError != null &&
                          _auditError!.trim().isNotEmpty) ...[
                        AuraCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Note',
                                style: AuraText.body.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: AuraSpace.s8),
                              Text(_auditError!, style: AuraText.body),
                            ],
                          ),
                        ),
                        const SizedBox(height: AuraSpace.s12),
                      ],
                      if (_auditBusy && !hasAnyContent) ...[
                        AuraCard(
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              const SizedBox(width: AuraSpace.s10),
                              Expanded(
                                child: Text(
                                  'Reviewing…',
                                  style: AuraText.body,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AuraSpace.s12),
                      ],
                      if (!_auditBusy &&
                          !hasAnyContent &&
                          (_auditError ?? '').trim().isEmpty) ...[
                        AuraCard(
                          child: Text(
                            'No review available yet.',
                            style: AuraText.body,
                          ),
                        ),
                        const SizedBox(height: AuraSpace.s12),
                      ],
                      if (what.isNotEmpty) ...[
                        AuraCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'What this is doing',
                                style: AuraText.body.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: AuraSpace.s10),
                              Text(what, style: AuraText.body),
                            ],
                          ),
                        ),
                        const SizedBox(height: AuraSpace.s12),
                      ],
                      if (spelling.isNotEmpty) ...[
                        AuraCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Spelling',
                                style: AuraText.body.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: AuraSpace.s10),
                              for (final item in spelling)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AuraSpace.s10,
                                  ),
                                  child: Text(
                                    '• ${item['original']} → ${item['suggestion']}',
                                    style: AuraText.body,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AuraSpace.s12),
                      ],
                      if (grammar.isNotEmpty) ...[
                        AuraCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Grammar',
                                style: AuraText.body.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: AuraSpace.s10),
                              for (final item in grammar)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AuraSpace.s10,
                                  ),
                                  child: Text(
                                    '• ${item['issue']}\n  ${item['suggestion']}',
                                    style: AuraText.body,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AuraSpace.s12),
                      ],
                      if (consider.isNotEmpty) ...[
                        AuraCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Things to consider',
                                style: AuraText.body.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: AuraSpace.s10),
                              for (final item in consider)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AuraSpace.s10,
                                  ),
                                  child: Text('• $item', style: AuraText.body),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AuraSpace.s12),
                      ],
                      if (strengthen.isNotEmpty) ...[
                        AuraCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ways to strengthen',
                                style: AuraText.body.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: AuraSpace.s10),
                              for (final item in strengthen)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AuraSpace.s10,
                                  ),
                                  child: Text('• $item', style: AuraText.body),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AuraSpace.s12),
                      ],
                      if (civic.isNotEmpty) ...[
                        AuraCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Civic awareness',
                                style: AuraText.body.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: AuraSpace.s10),
                              Text(civic, style: AuraText.body),
                            ],
                          ),
                        ),
                        const SizedBox(height: AuraSpace.s12),
                      ],
                      if (refinement.isNotEmpty) ...[
                        AuraCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Suggested refinement',
                                style: AuraText.body.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: AuraSpace.s10),
                              Text(refinement, style: AuraText.body),
                            ],
                          ),
                        ),
                        const SizedBox(height: AuraSpace.s12),
                      ],
                      if (consider.isEmpty &&
                          strengthen.isEmpty &&
                          civic.isEmpty &&
                          refinement.isEmpty &&
                          spelling.isEmpty &&
                          grammar.isEmpty &&
                          legacySignals.isNotEmpty) ...[
                        AuraCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Signals',
                                style: AuraText.body.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: AuraSpace.s10),
                              for (final s in legacySignals)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AuraSpace.s10,
                                  ),
                                  child: Text('• $s', style: AuraText.body),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AuraSpace.s12),
                      ],
                      Wrap(
                        spacing: AuraSpace.s10,
                        runSpacing: AuraSpace.s10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          OutlinedButton(
                            onPressed: _auditBusy
                                ? null
                                : () => Navigator.of(ctx).pop(false),
                            child: Text(publishMode ? 'Edit' : 'Close'),
                          ),
                          OutlinedButton(
                            onPressed:
                                (_auditBusy || _auditCooldownActive) ? null : rerun,
                            child: Text(
                              _auditCooldownActive ? 'Please wait…' : 'Run again',
                            ),
                          ),
                          if (publishMode)
                            FilledButton(
                              onPressed: _auditBusy
                                  ? null
                                  : () => Navigator.of(ctx).pop(true),
                              child: Text(_isReply ? 'Publish reply' : 'Publish'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _discardAndClose() async {
    if (_posting) return;

    _autosaveDebounce?.cancel();

    for (final attachment in _attachments) {
      attachment.dispose();
    }

    setState(() {
      _textController.clear();
      _attachments.clear();
      _visibility = _PostVisibility.public;
      _showTextError = false;
      _auditResult = null;
      _auditError = null;
      _uploadingMedia = false;
    });

    if (!mounted) return;
    context.pop(false);
  }

  Future<void> _showAddAttachmentSheet() async {
    if (!_canAddMoreAttachments || _posting) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AuraSurface.page,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AuraSpace.s16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Add attachment', style: AuraText.title),
                const SizedBox(height: AuraSpace.s12),
                _AttachmentActionButton(
                  icon: Icons.camera_alt_outlined,
                  label: 'Take photo',
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _pickImageFromCamera();
                  },
                ),
                const SizedBox(height: AuraSpace.s10),
                _AttachmentActionButton(
                  icon: Icons.photo_library_outlined,
                  label: 'Choose photo',
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _pickImageFromGallery();
                  },
                ),
                const SizedBox(height: AuraSpace.s10),
                _AttachmentActionButton(
                  icon: Icons.videocam_outlined,
                  label: 'Record video',
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _pickVideoFromCamera();
                  },
                ),
                const SizedBox(height: AuraSpace.s10),
                _AttachmentActionButton(
                  icon: Icons.video_library_outlined,
                  label: 'Choose video',
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _pickVideoFromGallery();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _divider() => Container(height: 1, color: AuraSurface.divider);

  int _attachmentColumns(double width) {
    if (width < 700) return 1;
    if (width < 1080) return 2;
    return 3;
  }

  Widget _buildPageTopBar() {
    return Wrap(
      spacing: AuraSpace.s10,
      runSpacing: AuraSpace.s10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: _posting ? null : () => context.pop(),
          icon: const Icon(Icons.arrow_back),
          label: const Text('Back'),
        ),
        Text(
          _isReply ? 'Reply' : 'Compose',
          style: AuraText.title,
        ),
        if (!_isReply)
          Text(
            _savedLine(),
            style: AuraText.small.copyWith(color: AuraSurface.muted),
          ),
      ],
    );
  }

  Widget _buildActionRow() {
    return Wrap(
      spacing: AuraSpace.s10,
      runSpacing: AuraSpace.s10,
      children: [
        OutlinedButton(
          onPressed: (_posting || _auditBusy)
              ? null
              : () async {
                  final result = await _runAuraEditor();
                  if (!mounted) return;
                  await _openAuraEditorSheet(reviewResult: result);
                },
          child: const Text('Aura Editor'),
        ),
        OutlinedButton(
          onPressed: _posting ? null : _discardAndClose,
          child: const Text('Discard'),
        ),
      ],
    );
  }

  Widget _buildStatusRow() {
    return Wrap(
      spacing: AuraSpace.s10,
      runSpacing: AuraSpace.s10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          _isReply ? 'Composing reply' : 'Composing',
          style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
        ),
        Text(
          _savedLine(),
          style: AuraText.small.copyWith(color: AuraSurface.muted),
        ),
      ],
    );
  }

  Widget _buildAudienceBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Audience',
          style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AuraSpace.s8),
        Wrap(
          spacing: AuraSpace.s8,
          runSpacing: AuraSpace.s8,
          children: _PostVisibility.values
              .map(
                (v) => _VisibilityChip(
                  label: _visibilityLabel(v),
                  selected: _visibility == v,
                  onTap: _posting ? null : () => _setVisibility(v),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: AuraSpace.s8),
        Text(
          _visibilityHelp(_visibility),
          style: AuraText.small.copyWith(color: AuraSurface.muted),
        ),
      ],
    );
  }

  Widget _buildComposerBox() {
    return Container(
      decoration: BoxDecoration(
        color: AuraSurface.page,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AuraSurface.divider),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s12,
        vertical: AuraSpace.s10,
      ),
      child: TextField(
        controller: _textController,
        maxLines: null,
        minLines: 6,
        textCapitalization: TextCapitalization.sentences,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        style: AuraText.body,
        decoration: InputDecoration(
          hintText: _isReply ? 'Write a reply…' : 'Add to the record… (required)',
          hintStyle: AuraText.small.copyWith(
            color: AuraSurface.muted,
          ),
          border: InputBorder.none,
          errorText: _showTextError ? 'Text is required' : null,
        ),
      ),
    );
  }

  Widget _buildCharacterLine() {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        '${_textController.text.trim().length}/$_limit',
        style: AuraText.small.copyWith(
          color: _textTooLong ? AuraSurface.warnInk : AuraSurface.muted,
        ),
      ),
    );
  }

  Widget _buildAttachmentsBlock() {
    if (_isReply) {
      return AuraCard(
        child: Text(
          'Reply attachments will be added after the reply endpoint is upgraded. Right now replies are text-only.',
          style: AuraText.small.copyWith(color: AuraSurface.muted),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Attachments',
                style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              '${_attachments.length}/$_maxAttachments',
              style: AuraText.small.copyWith(color: AuraSurface.muted),
            ),
          ],
        ),
        const SizedBox(height: AuraSpace.s8),
        Text(
          'Images and videos upload through the new Aura media system. Each item can have its own caption.',
          style: AuraText.small.copyWith(color: AuraSurface.muted),
        ),
        const SizedBox(height: AuraSpace.s12),
        Wrap(
          spacing: AuraSpace.s10,
          runSpacing: AuraSpace.s10,
          children: [
            OutlinedButton.icon(
              onPressed:
                  (_posting || !_canAddMoreAttachments) ? null : _showAddAttachmentSheet,
              icon: const Icon(Icons.add),
              label: const Text('Add attachment'),
            ),
          ],
        ),
        if (_attachments.isNotEmpty) ...[
          const SizedBox(height: AuraSpace.s12),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = _attachmentColumns(constraints.maxWidth);
              final gap = AuraSpace.s12;
              final itemWidth =
                  (constraints.maxWidth - ((columns - 1) * gap)) / columns;

              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: _attachments.asMap().entries.map((entry) {
                  final index = entry.key;
                  final attachment = entry.value;
                  return SizedBox(
                    width: itemWidth,
                    child: _AttachmentCard(
                      attachment: attachment,
                      index: index,
                      count: _attachments.length,
                      busy: _posting,
                      onRemove: () => _removeAttachment(attachment),
                      onMoveLeft: index > 0
                          ? () => _moveAttachmentLeft(index)
                          : null,
                      onMoveRight: index < _attachments.length - 1
                          ? () => _moveAttachmentRight(index)
                          : null,
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AuraSpace.s16,
        AuraSpace.s12,
        AuraSpace.s16,
        AuraSpace.s12 + bottomPad,
      ),
      decoration: BoxDecoration(
        color: AuraSurface.page,
        border: Border(
          top: BorderSide(color: AuraSurface.divider),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: (_isReply || _posting || _saving || !_hasText || _uploadingMedia)
                  ? null
                  : () {
                      if (!_hasText) {
                        setState(() => _showTextError = true);
                        return;
                      }
                      _saveDraft(silent: false);
                    },
              child: Text(_isReply ? 'Draft disabled for replies' : 'Save draft'),
            ),
          ),
          const SizedBox(width: AuraSpace.s12),
          FilledButton(
            onPressed: (_posting || _auditBusy || !_canPublish)
                ? null
                : () {
                    if (!_hasText) {
                      setState(() => _showTextError = true);
                      return;
                    }
                    _publish();
                  },
            child: Text(
              _posting
                  ? (_isReply ? 'Publishing reply…' : 'Publishing…')
                  : (_auditBusy
                      ? 'Reviewing…'
                      : (_isReply ? 'Publish reply' : 'Publish to record')),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return AuraScaffold(
      showHeader: false,
      body: Column(
        children: [
          Expanded(
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: keyboardInset > 0 ? 12 : 0),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AuraSpace.s16,
                  AuraSpace.s12,
                  AuraSpace.s16,
                  AuraSpace.s20,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 920),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPageTopBar(),
                        const SizedBox(height: AuraSpace.s12),
                        _buildActionRow(),
                        const SizedBox(height: AuraSpace.s16),
                        AuraCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildStatusRow(),
                              const SizedBox(height: AuraSpace.s12),
                              _divider(),
                              const SizedBox(height: AuraSpace.s12),
                              if (!_isReply) ...[
                                _buildAudienceBlock(),
                                const SizedBox(height: AuraSpace.s12),
                                _divider(),
                                const SizedBox(height: AuraSpace.s12),
                              ],
                              _buildComposerBox(),
                              const SizedBox(height: AuraSpace.s8),
                              _buildCharacterLine(),
                              const SizedBox(height: AuraSpace.s12),
                              _divider(),
                              const SizedBox(height: AuraSpace.s12),
                              _buildAttachmentsBlock(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          _buildBottomBar(context),
        ],
      ),
    );
  }
}

class _VisibilityChip extends StatelessWidget {
  const _VisibilityChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: selected ? AuraSurface.card : AuraSurface.page,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AuraSurface.divider),
        ),
        child: Text(
          label,
          style: selected
              ? AuraText.body.copyWith(fontWeight: FontWeight.w700)
              : AuraText.small.copyWith(color: AuraSurface.muted),
        ),
      ),
    );
  }
}

class _AttachmentActionButton extends StatelessWidget {
  const _AttachmentActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Align(
          alignment: Alignment.centerLeft,
          child: Text(label),
        ),
      ),
    );
  }
}

class _AttachmentCard extends StatelessWidget {
  const _AttachmentCard({
    required this.attachment,
    required this.index,
    required this.count,
    required this.busy,
    required this.onRemove,
    this.onMoveLeft,
    this.onMoveRight,
  });

  final _ComposeAttachment attachment;
  final int index;
  final int count;
  final bool busy;
  final VoidCallback onRemove;
  final VoidCallback? onMoveLeft;
  final VoidCallback? onMoveRight;

  String _durationText(int? durationMs) {
    if (durationMs == null || durationMs <= 0) return '';
    final totalSeconds = (durationMs / 1000).round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AuraSurface.page,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AuraSurface.divider),
      ),
      padding: const EdgeInsets.all(AuraSpace.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  attachment.isImage
                      ? 'Image ${index + 1}'
                      : 'Video ${index + 1}',
                  style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (attachment.uploading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              if (!attachment.uploading)
                IconButton(
                  tooltip: 'Remove',
                  onPressed: busy ? null : onRemove,
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
          const SizedBox(height: AuraSpace.s8),
          _AttachmentPreview(attachment: attachment),
          const SizedBox(height: AuraSpace.s10),
          Row(
            children: [
              if (onMoveLeft != null)
                IconButton(
                  onPressed: busy ? null : onMoveLeft,
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Move left',
                ),
              if (onMoveRight != null)
                IconButton(
                  onPressed: busy ? null : onMoveRight,
                  icon: const Icon(Icons.arrow_forward),
                  tooltip: 'Move right',
                ),
              const Spacer(),
              Text(
                '${index + 1}/$count',
                style: AuraText.small.copyWith(color: AuraSurface.muted),
              ),
            ],
          ),
          if (attachment.isVideo && _durationText(attachment.durationMs).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AuraSpace.s8),
              child: Text(
                _durationText(attachment.durationMs),
                style: AuraText.small.copyWith(color: AuraSurface.muted),
              ),
            ),
          if ((attachment.error ?? '').trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AuraSpace.s8),
              child: Text(
                attachment.error!,
                style: AuraText.small.copyWith(color: AuraSurface.warnInk),
              ),
            ),
          Container(
            decoration: BoxDecoration(
              color: AuraSurface.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AuraSurface.divider),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AuraSpace.s10,
              vertical: AuraSpace.s8,
            ),
            child: TextField(
              controller: attachment.captionController,
              enabled: !busy && !attachment.uploading,
              maxLines: null,
              minLines: 2,
              style: AuraText.body,
              decoration: InputDecoration(
                hintText: 'Caption for this attachment (optional)',
                hintStyle: AuraText.small.copyWith(color: AuraSurface.muted),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentPreview extends StatelessWidget {
  const _AttachmentPreview({
    required this.attachment,
  });

  final _ComposeAttachment attachment;

  @override
  Widget build(BuildContext context) {
    if (attachment.isImage) {
      if (attachment.localBytes != null) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: _aspectRatio(),
            child: Image.memory(
              attachment.localBytes!,
              fit: BoxFit.cover,
              width: double.infinity,
            ),
          ),
        );
      }

      final imageUrl = (attachment.thumbUrl ?? attachment.url ?? '').trim();
      if (imageUrl.isNotEmpty) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: _aspectRatio(),
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              errorBuilder: (_, __, ___) => _fallbackPreview(),
            ),
          ),
        );
      }

      return _fallbackPreview();
    }

    final thumbUrl = (attachment.thumbUrl ?? '').trim();
    if (thumbUrl.isNotEmpty) {
      return Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                thumbUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (_, __, ___) => _videoFallback(),
              ),
            ),
          ),
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.45),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.play_arrow, color: Colors.white),
          ),
        ],
      );
    }

    return _videoFallback();
  }

  double _aspectRatio() {
    final w = attachment.width;
    final h = attachment.height;
    if (w != null && h != null && w > 0 && h > 0) {
      var ratio = w / h;
      if (ratio < 0.7) ratio = 0.7;
      if (ratio > 1.8) ratio = 1.8;
      return ratio;
    }
    return 4 / 3;
  }

  Widget _fallbackPreview() {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AuraSurface.divider),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.image_outlined,
        color: AuraSurface.muted,
        size: 36,
      ),
    );
  }

  Widget _videoFallback() {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AuraSurface.divider),
      ),
      padding: const EdgeInsets.all(AuraSpace.s12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.videocam_outlined,
            color: AuraSurface.muted,
            size: 36,
          ),
          const SizedBox(height: AuraSpace.s8),
          Text(
            attachment.localFile?.name ?? 'Video attachment',
            style: AuraText.small.copyWith(color: AuraSurface.muted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

String _time(DateTime dt) {
  final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final mm = dt.minute.toString().padLeft(2, '0');
  final ap = dt.hour >= 12 ? 'pm' : 'am';
  return '$h:$mm $ap';
}