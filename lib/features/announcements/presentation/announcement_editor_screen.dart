
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/institutions/institution_access_provider.dart';
import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../composition/data/composition_repository.dart';
import '../../composition/domain/composition_models.dart';
import '../providers.dart';
import 'announcement_distribution.dart';

enum AnnouncementEditorScope {
  platform,
  institution,
}

enum _AttachmentType { image, video }
enum _AttachmentSource { camera, gallery }

class _AnnouncementAttachment {
  _AnnouncementAttachment({
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
  String? error;

  bool get isImage => type == _AttachmentType.image;
  bool get isVideo => type == _AttachmentType.video;
  bool get isUploaded => (mediaId ?? '').trim().isNotEmpty;

  void dispose() {
    captionController.dispose();
  }
}

class AnnouncementEditorScreen extends ConsumerStatefulWidget {
  const AnnouncementEditorScreen({
    super.key,
    required this.scope,
  });

  final AnnouncementEditorScope scope;

  @override
  ConsumerState<AnnouncementEditorScreen> createState() =>
      _AnnouncementEditorScreenState();
}

class _AnnouncementEditorScreenState
    extends ConsumerState<AnnouncementEditorScreen> {
  final _titleController = TextEditingController();
  final _summaryController = TextEditingController();
  final _bodyController = TextEditingController();

  bool _pinNotice = false;
  bool _publishToAura = true;
  bool _publishToLinkedIn = false;
  bool _publishToTikTok = false;

  bool _submitting = false;
  bool _uploadingMedia = false;

  bool _tiktokLoading = false;
  bool _tiktokConnected = false;
  String _tiktokAccountLabel = '';
  String? _tiktokError;

  bool _linkedinLoading = false;
  bool _linkedinConnected = false;
  String _linkedinAccountLabel = '';
  String? _linkedinError;

  String _currentUserId = '';
  final List<_AnnouncementAttachment> _attachments = [];

  CompositionReviewResult? _compositionReview;
  String? _compositionError;
  bool _compositionReviewing = false;
  final Set<String> _applyingFindingIds = <String>{};

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_handleAnnouncementInputChanged);
    _summaryController.addListener(_handleAnnouncementInputChanged);
    _bodyController.addListener(_handleAnnouncementInputChanged);
    if (widget.scope == AnnouncementEditorScope.platform) {
      _loadExternalConnections();
    }
  }

  @override
  void dispose() {
    _titleController.removeListener(_handleAnnouncementInputChanged);
    _summaryController.removeListener(_handleAnnouncementInputChanged);
    _bodyController.removeListener(_handleAnnouncementInputChanged);
    _titleController.dispose();
    _summaryController.dispose();
    _bodyController.dispose();
    for (final attachment in _attachments) {
      attachment.dispose();
    }
    super.dispose();
  }

  String get _scopeLabel {
    switch (widget.scope) {
      case AnnouncementEditorScope.platform:
        return 'Platform';
      case AnnouncementEditorScope.institution:
        return 'Institution';
    }
  }

  String get _pageTitle {
    switch (widget.scope) {
      case AnnouncementEditorScope.platform:
        return 'Platform announcement';
      case AnnouncementEditorScope.institution:
        return 'Institution announcement';
    }
  }

  String get _introText {
    switch (widget.scope) {
      case AnnouncementEditorScope.platform:
        return 'Use this surface for official platform notices.';
      case AnnouncementEditorScope.institution:
        return 'Institution publishing is not wired yet. This surface remains for structure only.';
    }
  }

  bool get _institutionMode =>
      widget.scope == AnnouncementEditorScope.institution;

  bool get _hasTikTokVideo => _attachments.any((a) {
        final url = (a.url ?? '').trim();
        return a.isVideo && a.isUploaded && !a.uploading && url.isNotEmpty;
      });

  _AnnouncementAttachment? get _primaryTikTokVideoAttachment {
    for (final attachment in _attachments) {
      final url = (attachment.url ?? '').trim();
      if (attachment.isVideo &&
          attachment.isUploaded &&
          !attachment.uploading &&
          url.isNotEmpty) {
        return attachment;
      }
    }
    return null;
  }

  bool get _canPublishPlatform {
    if (_submitting || _uploadingMedia) return false;
    if (_titleController.text.trim().isEmpty) return false;
    if (_summaryController.text.trim().isEmpty) return false;
    if (_bodyController.text.trim().isEmpty) return false;
    return true;
  }

  String _str(dynamic v) => (v ?? '').toString().trim();

  Map<String, dynamic> _asMap(dynamic v) {
    if (v == null) return <String, dynamic>{};
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    if (v is String) {
      final s = v.trim();
      if (s.isEmpty) return <String, dynamic>{};
      try {
        final decoded = jsonDecode(s);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
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

  String _firstNonEmpty(List<String?> values, {String fallback = ''}) {
    for (final value in values) {
      final s = (value ?? '').trim();
      if (s.isNotEmpty) return s;
    }
    return fallback;
  }

  Future<Response<dynamic>?> _safeGet(
    Dio dio,
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await dio.get(path, queryParameters: queryParameters);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _unwrapUser(dynamic raw) {
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final user = map['user'];
      if (user is Map) return Map<String, dynamic>.from(user);
      final data = map['data'];
      if (data is Map) {
        final nestedData = Map<String, dynamic>.from(data);
        final nestedUser = nestedData['user'];
        if (nestedUser is Map) return Map<String, dynamic>.from(nestedUser);
        return nestedData;
      }
      return map;
    }
    return <String, dynamic>{};
  }

  Map<String, dynamic> _unwrapTikTokAccount(dynamic raw) {
    if (raw is! Map) return <String, dynamic>{};
    final root = Map<String, dynamic>.from(raw);
    final account = root['account'];
    if (account is Map) {
      return Map<String, dynamic>.from(account);
    }
    final data = root['data'];
    if (data is Map) {
      final nested = Map<String, dynamic>.from(data);
      final nestedAccount = nested['account'];
      if (nestedAccount is Map) return Map<String, dynamic>.from(nestedAccount);
      return nested;
    }
    return root;
  }

  Map<String, dynamic> _unwrapLinkedInAccount(dynamic raw) {
    if (raw is! Map) return <String, dynamic>{};

    final root = Map<String, dynamic>.from(raw);
    final data = _asMap(root['data']);
    final nestedData = _asMap(data['data']);
    final account = _asMap(root['account']);
    final nestedAccount = _asMap(data['account']);
    final deepAccount = _asMap(nestedData['account']);

    for (final map in [deepAccount, nestedAccount, account, nestedData, data, root]) {
      if (map.isNotEmpty) return map;
    }
    return <String, dynamic>{};
  }

  bool _readTikTokConnected(Map<String, dynamic> account) {
    final connected = account['connected'];
    if (connected is bool) return connected;
    final platformUserId = _str(account['platformUserId']);
    final username = _str(account['username']);
    return platformUserId.isNotEmpty || username.isNotEmpty;
  }

  String _readTikTokAccountLabel(Map<String, dynamic> account) {
    return _firstNonEmpty([
      _str(account['username']),
      _str(account['platformUserId']),
      _str(account['id']),
    ]);
  }

  bool _readLinkedInConnected(Map<String, dynamic> account) {
    final connected = account['connected'];
    if (connected is bool) return connected;

    return _firstNonEmpty([
      _str(account['linkedinMemberId']),
      _str(account['memberId']),
      _str(account['id']),
      _str(account['sub']),
      _str(account['name']),
      _str(account['email']),
    ]).isNotEmpty;
  }

  String _readLinkedInAccountLabel(Map<String, dynamic> account) {
    return _firstNonEmpty([
      _str(account['name']),
      _str(account['localizedFirstName']),
      _str(account['email']),
      _str(account['linkedinMemberId']),
      _str(account['memberId']),
    ]);
  }

  Future<void> _loadExternalConnections() async {
    if (!mounted) return;
    setState(() {
      _tiktokLoading = true;
      _linkedinLoading = true;
      _tiktokError = null;
      _linkedinError = null;
    });

    try {
      final dio = ref.read(dioProvider);

      final meRes = await dio.get('/v1/users/me');
      final user = _unwrapUser(meRes.data);
      final userId = _str(user['id']);

      if (userId.isEmpty) {
        throw Exception('User id is missing.');
      }

      final results = await Future.wait<dynamic>([
        _safeGet(
          dio,
          '/v1/integrations/tiktok/account',
          queryParameters: {'userId': userId},
        ),
        _safeGet(
          dio,
          '/v1/integrations/linkedin/account',
          queryParameters: {'userId': userId},
        ),
        _safeGet(
          dio,
          '/integrations/linkedin/account',
          queryParameters: {'userId': userId},
        ),
      ]);

      final tiktokAccount = _unwrapTikTokAccount(results[0]?.data);
      final linkedinAccount = _unwrapLinkedInAccount(
        results[1]?.data ?? results[2]?.data,
      );

      if (!mounted) return;

      setState(() {
        _currentUserId = userId;
        _tiktokConnected = _readTikTokConnected(tiktokAccount);
        _tiktokAccountLabel = _readTikTokAccountLabel(tiktokAccount);
        _linkedinConnected = _readLinkedInConnected(linkedinAccount);
        _linkedinAccountLabel = _readLinkedInAccountLabel(linkedinAccount);
        if (!_linkedinConnected) _publishToLinkedIn = false;
        if (!_tiktokConnected) _publishToTikTok = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _tiktokError = e.toString();
        _linkedinError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _tiktokLoading = false;
          _linkedinLoading = false;
        });
      }
    }
  }

  String _buildExcerpt(String summary) {
    final clean = summary.trim();
    if (clean.length <= 180) return clean;
    return '${clean.substring(0, 177).trimRight()}...';
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

  Future<void> _pickImageFromGallery() async {
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

    final attachment = _AnnouncementAttachment(
      localId: '${DateTime.now().microsecondsSinceEpoch}_${file.name}',
      type: type,
      source: source,
      captionController: TextEditingController(),
      localFile: file,
      localBytes: bytes,
      width: width,
      height: height,
      uploading: true,
    );

    if (!mounted) return;
    setState(() {
      _attachments.add(attachment);
      _uploadingMedia = true;
      if (!_hasTikTokVideo) _publishToTikTok = false;
    });

    try {
      await _uploadAttachment(attachment);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        attachment.error = e.toString();
      });
      _showMessage('Could not upload attachment: $e', error: true);
    } finally {
      if (mounted) {
        setState(() {
          _uploadingMedia = _attachments.any((a) => a.uploading);
          if (!_hasTikTokVideo) _publishToTikTok = false;
        });
      }
    }
  }

  Future<void> _uploadAttachment(_AnnouncementAttachment attachment) async {
    final dio = ref.read(dioProvider);
    final file = attachment.localFile;
    if (file == null) throw Exception('Attachment file missing.');

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

    final patch = await dio.patch(
      '/media/$mediaId',
      data: {
        'caption': attachment.captionController.text.trim().isEmpty
            ? null
            : attachment.captionController.text.trim(),
        'editDisclosure': false,
        if (attachment.width != null) 'width': attachment.width,
        if (attachment.height != null) 'height': attachment.height,
      },
    );

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

  Future<void> _persistAttachmentMetadata(_AnnouncementAttachment attachment) async {
    final mediaId = _str(attachment.mediaId);
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
    } catch (_) {}
  }

  Future<void> _removeAttachment(_AnnouncementAttachment attachment) async {
    if (_submitting) return;
    final mediaId = _str(attachment.mediaId);

    if (!mounted) return;
    setState(() {
      _attachments.removeWhere((a) => a.localId == attachment.localId);
      _uploadingMedia = _attachments.any((a) => a.uploading);
      if (!_hasTikTokVideo) _publishToTikTok = false;
    });

    attachment.dispose();

    if (mediaId.isNotEmpty) {
      try {
        final dio = ref.read(dioProvider);
        await dio.delete('/media/$mediaId');
      } catch (_) {}
    }
  }

  Future<void> _showAddAttachmentSheet() async {
    if (_submitting) return;

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

  void _handleAnnouncementInputChanged() {
    if (!mounted) return;
    if (_compositionReview == null && _compositionError == null) return;
    setState(() {
      _compositionReview = null;
      _compositionError = null;
    });
  }

  bool get _canRunAnnouncementReview {
    if (_institutionMode || _submitting || _uploadingMedia || _compositionReviewing) {
      return false;
    }
    return _announcementCompositeText().trim().isNotEmpty;
  }

  String _announcementCompositeText() {
    return [
      'Title:',
      _titleController.text.trim(),
      '',
      'Summary:',
      _summaryController.text.trim(),
      '',
      'Body:',
      _bodyController.text.trim(),
    ].join('\n');
  }

  void _setAnnouncementCompositeText(String text) {
    final normalized = text.replaceAll('\r\n', '\n').trim();
    final reg = RegExp(r'Title:\s*\n([\s\S]*?)\n\s*Summary:\s*\n([\s\S]*?)\n\s*Body:\s*\n([\s\S]*)$', multiLine: true);
    final match = reg.firstMatch(normalized);

    if (match != null) {
      _titleController.text = (match.group(1) ?? '').trim();
      _summaryController.text = (match.group(2) ?? '').trim();
      _bodyController.text = (match.group(3) ?? '').trim();
      return;
    }

    _bodyController.text = normalized;
  }

  Future<void> _runAnnouncementReview() async {
    if (!_canRunAnnouncementReview) return;

    setState(() {
      _compositionReviewing = true;
      _compositionError = null;
      _compositionReview = null;
    });

    try {
      final repo = ref.read(compositionRepositoryProvider);
      final review = await repo.review(
        text: _announcementCompositeText(),
        surface: CompositionSurface.composer,
      );

      if (!mounted) return;
      setState(() {
        _compositionReview = review;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _compositionError = 'Review could not be completed: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _compositionReviewing = false);
      }
    }
  }

  Future<void> _applyAnnouncementFinding(CompositionFinding finding) async {
    final review = _compositionReview;
    if (review == null) return;
    if (finding.id.trim().isEmpty) return;

    setState(() {
      _applyingFindingIds.add(finding.id);
      _compositionError = null;
    });

    try {
      final repo = ref.read(compositionRepositoryProvider);
      final applied = await repo.apply(
        sessionId: review.sessionId,
        findingId: finding.id,
        text: _announcementCompositeText(),
        surface: CompositionSurface.composer,
      );

      if (!mounted) return;

      if (applied.text.trim().isNotEmpty) {
        _setAnnouncementCompositeText(applied.text);
      }

      setState(() {
        _compositionReview = applied.review ?? review;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _compositionError = 'Apply failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _applyingFindingIds.remove(finding.id);
        });
      }
    }
  }

  Map<String, List<CompositionFinding>> _groupAnnouncementFindings(
    List<CompositionFinding> findings,
  ) {
    final grouped = <String, List<CompositionFinding>>{};
    for (final finding in findings) {
      final key = finding.chapterLabel;
      grouped.putIfAbsent(key, () => <CompositionFinding>[]).add(finding);
    }
    return grouped;
  }

  Widget _compositionCard() {
    final review = _compositionReview;
    final grouped = review == null
        ? const <String, List<CompositionFinding>>{}
        : _groupAnnouncementFindings(review.findings);

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Composition review', style: AuraText.title),
                    const SizedBox(height: AuraSpace.s8),
                    Text(
                      'Review title, summary, and body before publishing. Apply stays backend-controlled.',
                      style: AuraText.body,
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _canRunAnnouncementReview ? _runAnnouncementReview : null,
                icon: _compositionReviewing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_fix_high_outlined),
                label: Text(_compositionReviewing ? 'Reviewing...' : 'Review'),
              ),
            ],
          ),
          if (review != null) ...[
            const SizedBox(height: AuraSpace.s12),
            Wrap(
              spacing: AuraSpace.s8,
              runSpacing: AuraSpace.s8,
              children: [
                _EditorChip(label: 'Surface: ${review.surface.label}'),
                if (review.intensityLabel.isNotEmpty)
                  _EditorChip(label: 'Intensity: ${review.intensityLabel}'),
                _EditorChip(label: 'Findings: ${review.findings.length}'),
                _EditorChip(label: review.allowApply ? 'Apply enabled' : 'Apply limited'),
              ],
            ),
          ],
          if ((review?.summary ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s10),
            Text(review!.summary, style: AuraText.body),
          ],
          if ((_compositionError ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s10),
            Text(
              _compositionError!,
              style: AuraText.small.copyWith(color: AuraSurface.warnInk),
            ),
          ],
          if (review != null && review.findings.isEmpty) ...[
            const SizedBox(height: AuraSpace.s12),
            Text(
              'No findings returned for this announcement.',
              style: AuraText.small.copyWith(color: AuraSurface.muted),
            ),
          ],
          for (final entry in grouped.entries) ...[
            const SizedBox(height: AuraSpace.s14),
            Text(
              entry.key,
              style: AuraText.body.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AuraSpace.s8),
            for (final finding in entry.value) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: AuraSpace.s10),
                padding: const EdgeInsets.all(AuraSpace.s12),
                decoration: BoxDecoration(
                  color: AuraSurface.page,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AuraSurface.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: AuraSpace.s8,
                      runSpacing: AuraSpace.s8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          finding.message,
                          style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                        ),
                        _EditorChip(label: finding.stateLabel),
                      ],
                    ),
                    if (finding.suggestion.trim().isNotEmpty) ...[
                      const SizedBox(height: AuraSpace.s8),
                      Text(finding.suggestion, style: AuraText.body),
                    ],
                    if (review.allowApply) ...[
                      const SizedBox(height: AuraSpace.s10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: _applyingFindingIds.contains(finding.id)
                              ? null
                              : () => _applyAnnouncementFinding(finding),
                          icon: _applyingFindingIds.contains(finding.id)
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.rule_folder_outlined),
                          label: Text(
                            _applyingFindingIds.contains(finding.id)
                                ? 'Applying...'
                                : (finding.actionLabel.trim().isNotEmpty
                                    ? finding.actionLabel
                                    : 'Apply'),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  void _showMessage(String message, {bool error = false}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  Future<void> _publishToLinkedInNow(String announcementId) async {
    final dio = ref.read(dioProvider);

    final payload = {
      'announcementId': announcementId,
      'text': _summaryController.text.trim().isNotEmpty
          ? _summaryController.text.trim()
          : _titleController.text.trim(),
    };

    DioException? lastDioError;
    for (final path in [
      '/v1/integrations/linkedin/publish/announcement',
      '/integrations/linkedin/publish/announcement',
    ]) {
      try {
        await dio.post(path, data: payload);
        return;
      } on DioException catch (e) {
        lastDioError = e;
        if (e.response?.statusCode != 404) rethrow;
      }
    }

    if (lastDioError != null) throw lastDioError;
    throw Exception('LinkedIn publish endpoint was not available.');
  }

  Future<void> _publishToTikTokNow(String announcementId) async {
    final attachment = _primaryTikTokVideoAttachment;
    if (attachment == null) {
      throw Exception('Add and upload a video first.');
    }

    final mediaUrl = _str(attachment.url);
    if (mediaUrl.isEmpty) {
      throw Exception('Uploaded video URL is missing.');
    }

    final dio = ref.read(dioProvider);

    await dio.post(
      '/v1/integrations/tiktok/publish/video/announcement',
      data: {
        'announcementId': announcementId,
        'mediaUrl': mediaUrl,
        'caption': _summaryController.text.trim().isNotEmpty
            ? _summaryController.text.trim()
            : _titleController.text.trim(),
      },
    );
  }

  Future<void> _handlePublish() async {
    if (_institutionMode) {
      _showMessage('Institution announcement publishing is not wired yet.', error: true);
      return;
    }

    if (!_canPublishPlatform) {
      _showMessage('Title, summary, and body are required.', error: true);
      return;
    }

    setState(() => _submitting = true);

    try {
      for (final attachment in _attachments) {
        await _persistAttachmentMetadata(attachment);
      }

      final repo = ref.read(announcementsRepoProvider);
      final mediaIds = _attachments
          .map((a) => _str(a.mediaId))
          .where((e) => e.isNotEmpty)
          .toList();

      final created = await repo.createDraft(
        title: _titleController.text.trim(),
        summary: _summaryController.text.trim(),
        excerpt: _buildExcerpt(_summaryController.text.trim()),
        bodyMarkdown: _bodyController.text.trim(),
        mediaIds: mediaIds,
      );

      await repo.publish(created.id);

      if (_pinNotice) {
        await repo.pin(created.id);
      }

      final queuedTargets = <String>[];
      final failedTargets = <String>[];

      if (_publishToLinkedIn && _linkedinConnected) {
        try {
          await _publishToLinkedInNow(created.id);
          queuedTargets.add('LinkedIn');
        } catch (e) {
          failedTargets.add('LinkedIn ($e)');
        }
      }

      if (_publishToTikTok && _tiktokConnected && _hasTikTokVideo) {
        try {
          await _publishToTikTokNow(created.id);
          queuedTargets.add('TikTok');
        } catch (e) {
          failedTargets.add('TikTok ($e)');
        }
      }

      ref.invalidate(announcementsProvider);
      ref.invalidate(pinnedAnnouncementsProvider);
      ref.invalidate(announcementBySlugProvider(created.slug));

      if (!mounted) return;

      if (queuedTargets.isNotEmpty && failedTargets.isEmpty) {
        _showMessage(
          'Platform notice published in Aura and shared to ${queuedTargets.join(' and ')}.',
        );
      } else if (queuedTargets.isNotEmpty && failedTargets.isNotEmpty) {
        _showMessage(
          'Platform notice published in Aura. Shared to ${queuedTargets.join(' and ')}. ${failedTargets.join(', ')} could not be queued.',
        );
      } else if (failedTargets.isNotEmpty) {
        _showMessage(
          'Platform notice published in Aura. ${failedTargets.join(', ')} could not be queued.',
        );
      } else {
        _showMessage('Platform notice published.');
      }

      context.go('/announcements/${created.slug}');
    } catch (e) {
      if (!mounted) return;
      _showMessage('Failed to publish platform notice: $e', error: true);
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Map<String, dynamic> _mapOrEmpty(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  String _institutionName() {
    final access = ref.read(institutionAccessProvider).maybeWhen(
          data: (value) => value,
          orElse: () => null,
        );

    if (access == null) return 'Institution';

    final institution = _mapOrEmpty(access.institution);
    final fromInstitution = (institution['name'] ?? '').toString().trim();
    if (fromInstitution.isNotEmpty) return fromInstitution;

    final request = _mapOrEmpty(access.request);
    final fromRequest = (request['organizationName'] ?? '').toString().trim();
    if (fromRequest.isNotEmpty) return fromRequest;

    return 'Institution';
  }

  Widget _textField({
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AuraText.body.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: AuraSpace.s8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _metadataCard() {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Controls', style: AuraText.title),
          const SizedBox(height: AuraSpace.s8),
          Text(
            'Pinned notices should be used sparingly.',
            style: AuraText.body,
          ),
          const SizedBox(height: AuraSpace.s12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Pin this notice'),
            subtitle: const Text('Keep visible at the top of announcement surfaces'),
            value: _pinNotice,
            onChanged: _submitting
                ? null
                : (value) {
                    setState(() => _pinNotice = value);
                  },
          ),
        ],
      ),
    );
  }

  Widget _attachmentsCard() {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Attachments', style: AuraText.title),
          const SizedBox(height: AuraSpace.s8),
          Text(
            'Images and videos upload through the Aura media system and attach to the announcement record.',
            style: AuraText.body,
          ),
          const SizedBox(height: AuraSpace.s12),
          OutlinedButton.icon(
            onPressed: _submitting ? null : _showAddAttachmentSheet,
            icon: const Icon(Icons.add),
            label: const Text('Add attachment'),
          ),
          if (_attachments.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s12),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth < 700
                    ? 1
                    : (constraints.maxWidth < 1080 ? 2 : 3);
                final gap = AuraSpace.s12;
                final itemWidth =
                    (constraints.maxWidth - ((columns - 1) * gap)) / columns;

                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: _attachments.map((attachment) {
                    return SizedBox(
                      width: itemWidth,
                      child: _AttachmentCard(
                        attachment: attachment,
                        busy: _submitting,
                        onRemove: () => _removeAttachment(attachment),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _distributionCard() {
    if (_institutionMode) {
      return AuraCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Distribution', style: AuraText.title),
            const SizedBox(height: AuraSpace.s8),
            Text(
              'Institution distribution is not wired yet.',
              style: AuraText.body,
            ),
          ],
        ),
      );
    }

    final linkedinHelper = (_linkedinError ?? '').trim();
    final tiktokHelper = (_tiktokError ?? '').trim();

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnnouncementDistribution(
            linkedinConnected: _linkedinConnected && !_linkedinLoading,
            tiktokConnected: _tiktokConnected && !_tiktokLoading,
            tiktokEnabled: _hasTikTokVideo,
            initialAura: _publishToAura,
            initialLinkedin: _publishToLinkedIn,
            initialTiktok: _publishToTikTok,
            onChanged: ({
              required bool aura,
              required bool linkedin,
              required bool tiktok,
            }) {
              setState(() {
                _publishToAura = aura;
                _publishToLinkedIn = linkedin;
                _publishToTikTok = tiktok;
              });
            },
          ),
          if (_linkedinLoading || _tiktokLoading) ...[
            const SizedBox(height: AuraSpace.s8),
            Text(
              'Checking external connections…',
              style: AuraText.small.copyWith(color: AuraSurface.muted),
            ),
          ],
          if (_linkedinAccountLabel.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s8),
            Text(
              'LinkedIn: $_linkedinAccountLabel',
              style: AuraText.small.copyWith(color: AuraSurface.muted),
            ),
          ],
          if (_tiktokAccountLabel.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s4),
            Text(
              'TikTok: $_tiktokAccountLabel',
              style: AuraText.small.copyWith(color: AuraSurface.muted),
            ),
          ],
          if (linkedinHelper.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s8),
            Text(
              linkedinHelper,
              style: AuraText.small.copyWith(color: AuraSurface.warnInk),
            ),
          ],
          if (tiktokHelper.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s4),
            Text(
              tiktokHelper,
              style: AuraText.small.copyWith(color: AuraSurface.warnInk),
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionCard() {
    return AuraCard(
      child: Wrap(
        spacing: AuraSpace.s10,
        runSpacing: AuraSpace.s10,
        children: [
          FilledButton.icon(
            onPressed: _institutionMode
                ? null
                : (_canPublishPlatform ? _handlePublish : null),
            icon: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.publish_outlined),
            label: Text(
              _institutionMode ? 'Institution publishing unavailable' : 'Publish platform notice',
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final institutionName = _institutionName();

    return AuraScaffold(
      title: _pageTitle,
      showHomeAction: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AuraSpace.s16,
          AuraSpace.s12,
          AuraSpace.s16,
          AuraSpace.s24,
        ),
        children: [
          AuraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_pageTitle, style: AuraText.title),
                const SizedBox(height: AuraSpace.s8),
                Text(_introText, style: AuraText.body),
                const SizedBox(height: AuraSpace.s12),
                Wrap(
                  spacing: AuraSpace.s10,
                  runSpacing: AuraSpace.s10,
                  children: [
                    _EditorChip(label: 'Scope: $_scopeLabel'),
                    if (_institutionMode) _EditorChip(label: institutionName),
                    if (_institutionMode) const _EditorChip(label: 'Publishing unavailable'),
                    if (!_institutionMode && _currentUserId.isNotEmpty)
                      _EditorChip(label: 'Admin ready'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AuraSpace.s12),
          AuraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _textField(
                  label: 'Title',
                  controller: _titleController,
                  hint: 'Write the formal notice title',
                ),
                const SizedBox(height: AuraSpace.s16),
                _textField(
                  label: 'Summary',
                  controller: _summaryController,
                  maxLines: 3,
                  hint: 'Short orientation line for archive and detail views',
                ),
                const SizedBox(height: AuraSpace.s16),
                _textField(
                  label: 'Body',
                  controller: _bodyController,
                  maxLines: 12,
                  hint: 'Write the full announcement body',
                ),
              ],
            ),
          ),
          const SizedBox(height: AuraSpace.s12),
          _compositionCard(),
          const SizedBox(height: AuraSpace.s12),
          _metadataCard(),
          const SizedBox(height: AuraSpace.s12),
          _attachmentsCard(),
          const SizedBox(height: AuraSpace.s12),
          _distributionCard(),
          const SizedBox(height: AuraSpace.s12),
          _actionCard(),
        ],
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
    required this.busy,
    required this.onRemove,
  });

  final _AnnouncementAttachment attachment;
  final bool busy;
  final VoidCallback onRemove;

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
                  attachment.isImage ? 'Image' : 'Video',
                  style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (attachment.uploading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  onPressed: busy ? null : onRemove,
                  icon: const Icon(Icons.close),
                  tooltip: 'Remove',
                ),
            ],
          ),
          const SizedBox(height: AuraSpace.s8),
          _AttachmentPreview(attachment: attachment),
          const SizedBox(height: AuraSpace.s10),
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
          if ((attachment.error ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s8),
            Text(
              attachment.error!,
              style: AuraText.small.copyWith(color: AuraSurface.warnInk),
            ),
          ],
        ],
      ),
    );
  }
}

class _AttachmentPreview extends StatelessWidget {
  const _AttachmentPreview({
    required this.attachment,
  });

  final _AnnouncementAttachment attachment;

  double _aspectRatio() {
    final w = attachment.width;
    final h = attachment.height;
    if (w != null && h != null && w > 0 && h > 0) {
      var ratio = w / h;
      if (ratio < 0.7) ratio = 0.7;
      if (ratio > 1.8) ratio = 1.8;
      return ratio;
    }
    return attachment.isVideo ? 16 / 9 : 4 / 3;
  }

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

class _EditorChip extends StatelessWidget {
  const _EditorChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s10,
        vertical: AuraSpace.s6,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AuraText.small.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}
