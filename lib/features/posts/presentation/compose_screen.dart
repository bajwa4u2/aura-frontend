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

enum _ComposeMode { text, image, video }

enum _PostVisibility { public, followers, private }

class _ComposeScreenState extends ConsumerState<ComposeScreen> {
  static const int _limit = 2000;

  final _textController = TextEditingController();
  final _contextController = TextEditingController();

  bool _posting = false;
  bool _saving = false;
  bool _showTextError = false;

  _ComposeMode _mode = _ComposeMode.text;
  _PostVisibility _visibility = _PostVisibility.public;

  XFile? _pickedFile;
  Uint8List? _pickedBytes;
  int? _imgW;
  int? _imgH;

  String? _existingMediaUrl;

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

  bool get _hasPickedMedia =>
      _pickedFile != null &&
      (_mode == _ComposeMode.image || _mode == _ComposeMode.video);

  bool get _hasExistingMedia =>
      (_existingMediaUrl ?? '').trim().isNotEmpty &&
      (_mode == _ComposeMode.image || _mode == _ComposeMode.video);

  bool get _hasAnyMedia => _hasPickedMedia || _hasExistingMedia;

  bool get _canPublish {
    if (!_hasText) return false;
    if (_textTooLong) return false;

    switch (_mode) {
      case _ComposeMode.text:
        return true;
      case _ComposeMode.image:
      case _ComposeMode.video:
        return _hasAnyMedia;
    }
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

  String _inferMime(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
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

  Future<void> _decodeImageSize(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final img = frame.image;

    if (!mounted) return;

    setState(() {
      _imgW = img.width;
      _imgH = img.height;
    });
  }

  @override
  void initState() {
    super.initState();

    if (!_isReply) {
      _loadDraft();
    }

    _textController.addListener(_scheduleAutosave);
    _contextController.addListener(_scheduleAutosave);
  }

  @override
  void dispose() {
    _autosaveDebounce?.cancel();
    _textController.dispose();
    _contextController.dispose();
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
      final mediaType = (draft['mediaType'] ?? 'NONE').toString().toUpperCase();
      final mediaUrl = (draft['mediaUrl'] ?? '').toString();
      final caption = (draft['caption'] ?? '').toString();
      final visibility = _visibilityFromApi(draft['visibility']);

      final updatedAtRaw = (draft['updatedAt'] ?? '').toString();
      final savedAt = DateTime.tryParse(updatedAtRaw)?.toLocal();

      if (!mounted) return;

      setState(() {
        _textController.text = text;
        _contextController.text = caption;
        _visibility = visibility;

        if (mediaType == 'IMAGE') {
          _mode = _ComposeMode.image;
          _existingMediaUrl = mediaUrl.trim().isEmpty ? null : mediaUrl.trim();
        } else if (mediaType == 'VIDEO') {
          _mode = _ComposeMode.video;
          _existingMediaUrl = mediaUrl.trim().isEmpty ? null : mediaUrl.trim();
        } else {
          _mode = _ComposeMode.text;
          _existingMediaUrl = null;
        }

        final w = draft['mediaWidth'];
        final h = draft['mediaHeight'];
        _imgW = (w is int) ? w : int.tryParse((w ?? '').toString());
        _imgH = (h is int) ? h : int.tryParse((h ?? '').toString());

        _lastSavedAt = savedAt;

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
    _autosaveDebounce = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      if (_posting) return;
      if (!_hasText) return;
      _saveDraft(silent: true);
    });
  }

  void _setMode(_ComposeMode next) {
    if (_posting) return;
    if (_mode == next) return;

    setState(() {
      _mode = next;
      _pickedFile = null;
      _pickedBytes = null;
      _imgW = null;
      _imgH = null;
      _existingMediaUrl = null;

      if (_mode == _ComposeMode.text) {
        _contextController.clear();
      }
    });

    _scheduleAutosave();
  }

  void _setVisibility(_PostVisibility next) {
    if (_posting) return;
    if (_visibility == next) return;

    setState(() {
      _visibility = next;
    });

    _scheduleAutosave();
  }

  void _clearMedia({bool clearContext = true}) {
    if (_posting) return;

    setState(() {
      _pickedFile = null;
      _pickedBytes = null;
      _existingMediaUrl = null;
      _imgW = null;
      _imgH = null;
      if (clearContext) {
        _contextController.clear();
      }
    });

    _scheduleAutosave();
  }

  Future<void> _pickImage() async {
    if (_posting) return;

    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    final bytes = await file.readAsBytes();
    if (!mounted) return;

    setState(() {
      _mode = _ComposeMode.image;
      _pickedFile = file;
      _pickedBytes = bytes;
      _existingMediaUrl = null;
    });

    try {
      await _decodeImageSize(bytes);
    } catch (_) {}

    _scheduleAutosave();
  }

  Future<void> _pickVideo() async {
    if (_posting) return;

    final picker = ImagePicker();
    final file = await picker.pickVideo(source: ImageSource.gallery);
    if (file == null) return;
    if (!mounted) return;

    setState(() {
      _mode = _ComposeMode.video;
      _pickedFile = file;
      _pickedBytes = null;
      _existingMediaUrl = null;
      _imgW = null;
      _imgH = null;
    });

    _scheduleAutosave();
  }

  String _mediaTypeForMode() {
    switch (_mode) {
      case _ComposeMode.text:
        return 'NONE';
      case _ComposeMode.image:
        return _hasAnyMedia ? 'IMAGE' : 'NONE';
      case _ComposeMode.video:
        return _hasAnyMedia ? 'VIDEO' : 'NONE';
    }
  }

  String _savedLine() {
    if (_isReply) {
      return 'Replies publish directly and do not use the main draft.';
    }
    if (_saving) return 'Saving…';
    final dt = _lastSavedAt;
    if (dt == null) return 'Draft not saved yet.';
    return 'Draft saved ${_time(dt)}.';
  }

  Map<String, dynamic> _buildComposePayload({String? mediaUrlOverride}) {
    final payload = <String, dynamic>{
      'text': _textController.text,
      'visibility': _visibilityApiValue(_visibility),
      'mediaType': _mediaTypeForMode(),
      if (_isReply && _replyToPostId.isNotEmpty) 'replyToPostId': _replyToPostId,
    };

    if (_isReply && _replyToPostId.isNotEmpty) {
      payload['replyToPostId'] = _replyToPostId;
    }

    if (_mode == _ComposeMode.image && _hasAnyMedia) {
      final url = (mediaUrlOverride ?? _existingMediaUrl ?? '').trim();
      if (url.isNotEmpty) payload['mediaUrl'] = url;
      if (_imgW != null) payload['mediaWidth'] = _imgW;
      if (_imgH != null) payload['mediaHeight'] = _imgH;

      final ctx = _contextController.text.trim();
      if (ctx.isNotEmpty) payload['caption'] = ctx;
    }

    if (_mode == _ComposeMode.video && _hasAnyMedia) {
      final url = (mediaUrlOverride ?? _existingMediaUrl ?? '').trim();
      if (url.isNotEmpty) payload['mediaUrl'] = url;

      final ctx = _contextController.text.trim();
      if (ctx.isNotEmpty) payload['caption'] = ctx;
    }

    return payload;
  }

  Future<void> _saveDraft({
    bool silent = false,
    String? mediaUrlOverride,
  }) async {
    if (_isReply) return;
    if (_saving || _posting) return;

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
      final dio = ref.read(dioProvider);
      final payload = _buildComposePayload(mediaUrlOverride: mediaUrlOverride);

      await dio.put('/posts/draft', data: payload);

      if (!mounted) return;
      setState(() => _lastSavedAt = DateTime.now());
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save draft: $e')),
        );
      }
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

  Future<String?> _uploadPickedMediaIfNeeded() async {
    final dio = ref.read(dioProvider);

    final hasFreshUpload =
        _pickedFile != null &&
        (_mode == _ComposeMode.image || _mode == _ComposeMode.video);

    if (!hasFreshUpload) {
      final existing = (_existingMediaUrl ?? '').trim();
      return existing.isEmpty ? null : existing;
    }

    final mime = _inferMime(_pickedFile!.name);
    final bytes = await _pickedFile!.readAsBytes();

    if (_mode == _ComposeMode.image && bytes.length > 10 * 1024 * 1024) {
      throw Exception('Image too large (max 10MB)');
    }
    if (_mode == _ComposeMode.video && bytes.length > 50 * 1024 * 1024) {
      throw Exception('Video too large (max 50MB)');
    }

    final pres = await dio.post(
      '/media/presign',
      data: {
        'fileName': _pickedFile!.name,
        'mimeType': mime,
        'bytes': bytes.length,
        'kind': _mode == _ComposeMode.image ? 'IMAGE' : 'VIDEO',
        if (_mode == _ComposeMode.image) 'width': _imgW,
        if (_mode == _ComposeMode.image) 'height': _imgH,
      },
    );

    final presigned = _unwrapDataMap(pres.data);

    final uploadedPublicUrl = (presigned['publicUrl'] ??
            presigned['url'] ??
            ((presigned['media'] is Map)
                ? _asMap(presigned['media'])['url']
                : null))
        ?.toString();

    final upload = _asMap(presigned['upload']);
    final uploadUrl = (upload['url'] ?? '').toString();
    final headers = _asMap(upload['headers']);

    if (uploadUrl.isEmpty) {
      throw Exception('Upload URL missing from presign response.');
    }
    if (uploadedPublicUrl == null || uploadedPublicUrl.trim().isEmpty) {
      throw Exception('publicUrl missing from presign response.');
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

    return uploadedPublicUrl.trim();
  }

  Future<void> _publishReplyNow() async {
    final dio = ref.read(dioProvider);
    final mediaUrl = await _uploadPickedMediaIfNeeded();
    final payload = _buildComposePayload(mediaUrlOverride: mediaUrl);

    if (_replyToPostId.isEmpty) {
      throw Exception('Reply target missing.');
    }

    try {
      await dio.post('/posts/$_replyToPostId/replies', data: payload);
      return;
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code != 404 && code != 405) {
        rethrow;
      }
    }

    await dio.post('/posts/draft/publish', data: payload);
  }

  Future<void> _publishPostNow() async {
    final dio = ref.read(dioProvider);

    if (_mode == _ComposeMode.image || _mode == _ComposeMode.video) {
      final mediaUrl = await _uploadPickedMediaIfNeeded();
      if (mediaUrl != null && mediaUrl.isNotEmpty) {
        await _saveDraft(silent: true, mediaUrlOverride: mediaUrl);
      } else {
        await _saveDraft(silent: true);
      }
    } else {
      await _saveDraft(silent: true);
    }

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

    if (!_canPublish) return;

    final review = await _runAuraEditor(fromPublish: true);
    if (!mounted) return;

    final proceed = await _openAuraEditorSheet(
      reviewResult: review,
      publishMode: true,
    );
    if (proceed != true || !mounted) return;

    setState(() => _posting = true);

    try {
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

    setState(() {
      _textController.clear();
      _contextController.clear();
      _pickedFile = null;
      _pickedBytes = null;
      _existingMediaUrl = null;
      _imgW = null;
      _imgH = null;
      _mode = _ComposeMode.text;
      _visibility = _PostVisibility.public;
      _showTextError = false;
      _auditResult = null;
      _auditError = null;
    });

    if (!mounted) return;
    context.pop(false);
  }

  Widget _modeChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: selected ? AuraSurface.card : Colors.transparent,
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

  Widget _divider() => Container(height: 1, color: AuraSurface.divider);

  @override
  Widget build(BuildContext context) {
    final title = _isReply ? 'Reply' : 'Compose';

    return AuraScaffold(
      title: title,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.pop(),
      ),
      actions: [
        TextButton(
          onPressed: (_posting || _auditBusy)
              ? null
              : () async {
                  final result = await _runAuraEditor();
                  if (!mounted) return;
                  await _openAuraEditorSheet(reviewResult: result);
                },
          child: const Text('Aura Editor'),
        ),
        TextButton(
          onPressed: _posting ? null : _discardAndClose,
          child: const Text('Discard'),
        ),
      ],
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: AuraSpace.xl),
        child: AuraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_isReply ? 'Composing reply' : 'Composing', style: AuraText.title),
              const SizedBox(height: AuraSpace.s6),
              Text(
                _savedLine(),
                style: AuraText.small.copyWith(color: AuraSurface.muted),
              ),
              const SizedBox(height: AuraSpace.s12),
              _divider(),
              const SizedBox(height: AuraSpace.s10),

              Wrap(
                spacing: AuraSpace.s8,
                runSpacing: AuraSpace.s8,
                children: [
                  _modeChip(
                    label: 'Text',
                    selected: _mode == _ComposeMode.text,
                    onTap: () => _setMode(_ComposeMode.text),
                  ),
                  _modeChip(
                    label: 'Image',
                    selected: _mode == _ComposeMode.image,
                    onTap: () => _setMode(_ComposeMode.image),
                  ),
                  _modeChip(
                    label: 'Video',
                    selected: _mode == _ComposeMode.video,
                    onTap: () => _setMode(_ComposeMode.video),
                  ),
                ],
              ),

              const SizedBox(height: AuraSpace.s10),
              _divider(),
              const SizedBox(height: AuraSpace.s12),

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

              const SizedBox(height: AuraSpace.s12),
              _divider(),
              const SizedBox(height: AuraSpace.s12),

              Container(
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
                  minLines: 10,
                  onChanged: (_) {
                    setState(() {
                      if (_showTextError && _hasText) {
                        _showTextError = false;
                      }
                    });
                  },
                  style: AuraText.body,
                  decoration: InputDecoration(
                    hintText: _isReply
                        ? 'Write a reply…'
                        : 'Add to the record… (required)',
                    hintStyle: AuraText.small.copyWith(
                      color: AuraSurface.muted,
                    ),
                    border: InputBorder.none,
                    errorText: _showTextError ? 'Text is required' : null,
                  ),
                ),
              ),
              const SizedBox(height: AuraSpace.s8),
              Text(
                '${_textController.text.trim().length}/$_limit',
                style: AuraText.small.copyWith(
                  color: _textTooLong ? AuraSurface.warnInk : AuraSurface.muted,
                ),
              ),

              if (_mode == _ComposeMode.image) ...[
                const SizedBox(height: AuraSpace.s12),
                _MediaZone(
                  label: _hasAnyMedia ? 'Image attached' : 'Add image',
                  sublabel: _hasAnyMedia
                      ? 'Tap to replace, or remove.'
                      : 'One image per post.',
                  isBusy: _posting,
                  hasMedia: _hasAnyMedia,
                  onTap: _posting ? null : _pickImage,
                  trailing: _hasAnyMedia
                      ? TextButton(
                          onPressed: _posting ? null : _clearMedia,
                          child: const Text('Remove'),
                        )
                      : null,
                  child: () {
                    if (_pickedBytes != null) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 320),
                          child: Image.memory(
                            _pickedBytes!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                        ),
                      );
                    }

                    if (_hasExistingMedia) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 320),
                          child: Image.network(
                            _existingMediaUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (_, __, ___) => Padding(
                              padding: const EdgeInsets.all(AuraSpace.s12),
                              child: Text(
                                'Preview unavailable. The image is still attached.',
                                style: AuraText.small.copyWith(
                                  color: AuraSurface.muted,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    return null;
                  }(),
                ),
                const SizedBox(height: AuraSpace.s12),
                _ContextField(
                  controller: _contextController,
                  hint: 'Add context (optional)',
                  enabled: !_posting,
                ),
              ],

              if (_mode == _ComposeMode.video) ...[
                const SizedBox(height: AuraSpace.s12),
                _MediaZone(
                  label: _hasAnyMedia ? 'Video attached' : 'Add video',
                  sublabel: _hasAnyMedia
                      ? 'Tap to replace, or remove.'
                      : 'One video per post.',
                  isBusy: _posting,
                  hasMedia: _hasAnyMedia,
                  onTap: _posting ? null : _pickVideo,
                  trailing: _hasAnyMedia
                      ? TextButton(
                          onPressed: _posting ? null : _clearMedia,
                          child: const Text('Remove'),
                        )
                      : null,
                  child: () {
                    if (_pickedFile != null) {
                      return Text(
                        _pickedFile!.name,
                        style: AuraText.body,
                      );
                    }

                    if (_hasExistingMedia) {
                      return Text(
                        'Preview is available after publish.',
                        style: AuraText.small.copyWith(
                          color: AuraSurface.muted,
                        ),
                      );
                    }

                    return null;
                  }(),
                ),
                const SizedBox(height: AuraSpace.s12),
                _ContextField(
                  controller: _contextController,
                  hint: 'Add context (optional)',
                  enabled: !_posting,
                ),
              ],

              const SizedBox(height: AuraSpace.s16),
              _divider(),
              const SizedBox(height: AuraSpace.s12),

              Wrap(
                spacing: AuraSpace.s10,
                runSpacing: AuraSpace.s10,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton(
                    onPressed: (_isReply || _posting || _saving || !_hasText)
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
            ],
          ),
        ),
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

class _ContextField extends StatelessWidget {
  const _ContextField({
    required this.controller,
    required this.hint,
    required this.enabled,
  });

  final TextEditingController controller;
  final String hint;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
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
        controller: controller,
        enabled: enabled,
        maxLines: null,
        minLines: 3,
        style: AuraText.body,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AuraText.small.copyWith(color: AuraSurface.muted),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

class _MediaZone extends StatelessWidget {
  const _MediaZone({
    required this.label,
    required this.sublabel,
    required this.isBusy,
    required this.hasMedia,
    required this.onTap,
    this.trailing,
    this.child,
  });

  final String label;
  final String sublabel;
  final bool isBusy;
  final bool hasMedia;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Widget? child;

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: AuraSpace.s6),
          Text(
            sublabel,
            style: AuraText.small.copyWith(color: AuraSurface.muted),
          ),
          const SizedBox(height: AuraSpace.s12),
          if (child != null) ...[
            child!,
            const SizedBox(height: AuraSpace.s12),
          ],
          OutlinedButton.icon(
            onPressed: isBusy ? null : onTap,
            icon: const Icon(Icons.add),
            label: Text(hasMedia ? 'Replace' : 'Add'),
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