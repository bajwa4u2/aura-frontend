import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/attachments/aura_media_upload.dart';
import '../../../core/institutions/institution_access_provider.dart';
import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_design_system.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../ai/providers.dart';
import '../../feed/data/unified_feed_providers.dart';
import '../../composition/domain/composition_models.dart';
import 'compose/compose_models.dart';
import 'compose/compose_widgets.dart';

class ComposeScreen extends ConsumerStatefulWidget {
  final String? replyToPostId;

  /// When set, the compose screen replies to an InstitutionPost (separate
  /// table from `Post`). The two reply paths are mutually exclusive — the
  /// caller passes one or the other. `parentInstitutionId` is the feed
  /// institution that owns the parent post; required alongside the reply id.
  final String? replyToInstitutionPostId;
  final String? parentInstitutionId;

  final String? heldPostId;
  final String? surface;
  final String? mode;

  /// When true and `institutionId` is set, the reply is published with the
  /// institution as the post actor (Post.institutionId/institutionMemberId/
  /// institutionSpeechMode='AUTHORIZED_INSTITUTIONAL' for regular posts;
  /// InstitutionPost.actorInstitutionId for institution-post replies).
  final bool asInstitution;
  final String? institutionId;

  /// Public-UX Phase 4 — when set, the composer treats this as the
  /// target public-discourse space. The space is shown in the chip
  /// row and persisted on the draft + publish payloads as
  /// `publicSpaceId`.
  final String? publicSpaceId;

  /// Display name for the chip row when `publicSpaceId` is set. The
  /// composer tolerates a missing name (renders "In space"); the slug
  /// also drives the route to the space detail screen on chip tap.
  final String? publicSpaceName;
  final String? publicSpaceSlug;

  const ComposeScreen({
    super.key,
    this.replyToPostId,
    this.replyToInstitutionPostId,
    this.parentInstitutionId,
    this.heldPostId,
    this.surface,
    this.mode,
    this.asInstitution = false,
    this.institutionId,
    this.publicSpaceId,
    this.publicSpaceName,
    this.publicSpaceSlug,
  });

  @override
  ConsumerState<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends ConsumerState<ComposeScreen> {
  static const int _limit = 2000;
  static const int _maxAttachments = 5;

  final _textController = TextEditingController();

  bool _posting = false;
  bool _saving = false;
  bool _showTextError = false;
  bool _uploadingMedia = false;

  PostVisibility _visibility = PostVisibility.public;

  final List<ComposeAttachment> _attachments = [];

  DateTime? _lastSavedAt;
  Timer? _autosaveDebounce;

  bool _auditBusy = false;
  DateTime? _lastAuditAt;
  Map<String, dynamic>? _auditResult;
  String? _auditError;

  bool _compositionBusy = false;
  CompositionReviewResult? _compositionReview;
  String? _compositionError;
  String? _compositionSnapshot;
  final Set<String> _applyingSuggestionIds = <String>{};
  final Set<String> _dismissedSuggestionIds = <String>{};

  bool _translationBusy = false;
  String? _translationError;
  String _translationTargetLanguage = 'ur';
  CompositionTranslationResult? _translationPreview;
  String? _translationSnapshot;

  bool _tiktokLoading = false;
  final bool _tiktokActionBusy = false;
  bool _publishToTikTok = false;
  bool _publishingToTikTok = false;
  bool _tiktokConnected = false;
  String _tiktokAccountLabel = '';
  String? _tiktokError;

  bool _linkedinLoading = false;
  bool _publishToLinkedIn = false;
  bool _linkedinConnected = false;
  String _linkedinAccountLabel = '';
  String? _linkedinError;

  bool get _isReply =>
      widget.replyToPostId != null ||
      widget.replyToInstitutionPostId != null;
  bool get _isInstitutionPostReply =>
      (widget.replyToInstitutionPostId ?? '').trim().isNotEmpty &&
      (widget.parentInstitutionId ?? '').trim().isNotEmpty;

  String get _replyToPostId => (widget.replyToPostId ?? '').trim();
  String get _replyToInstitutionPostId =>
      (widget.replyToInstitutionPostId ?? '').trim();
  String get _parentInstitutionId =>
      (widget.parentInstitutionId ?? '').trim();
  String get _heldPostId => (widget.heldPostId ?? '').trim();

  bool get _hasText => _textController.text.trim().isNotEmpty;
  bool get _textTooLong => _textController.text.trim().length > _limit;
  bool get _hasUploadingAttachments => _attachments.any((a) => a.uploading);
  bool get _canAddMoreAttachments =>
      !_isReply && _attachments.length < _maxAttachments;
  bool get _supportsCameraCapture => !kIsWeb;

  ComposeAttachment? get _primaryTikTokVideoAttachment {
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

  bool get _hasTikTokVideo => _primaryTikTokVideoAttachment != null;

  bool get _canPublish {
    if (!_hasText) return false;
    if (_textTooLong) return false;
    if (_hasUploadingAttachments) return false;
    return true;
  }

  Map<String, dynamic> _asMap(dynamic v) {
    if (v == null) return <String, dynamic>{};

    if (v is Map) {
      return Map<String, dynamic>.from(v);
    }

    if (v is String) {
      final s = v.trim();
      if (s.isEmpty) return <String, dynamic>{};
      try {
        final decoded = jsonDecode(s);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }

    return <String, dynamic>{};
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

  String _firstNonEmpty(List<String?> values, {String fallback = ''}) {
    for (final value in values) {
      final s = (value ?? '').trim();
      if (s.isNotEmpty) {
        return s;
      }
    }
    return fallback;
  }

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

  String _visibilityApiValue(PostVisibility value) {
    switch (value) {
      case PostVisibility.public:
        return 'PUBLIC';
      case PostVisibility.followers:
        return 'FOLLOWERS';
      case PostVisibility.private:
        return 'PRIVATE';
    }
  }

  PostVisibility _visibilityFromApi(dynamic value) {
    final raw = (value ?? '').toString().trim().toUpperCase();
    switch (raw) {
      case 'FOLLOWERS':
        return PostVisibility.followers;
      case 'PRIVATE':
        // Public-UX Phase 1: the public composer no longer surfaces
        // Private. A draft that was last saved as Private is upgraded
        // to Social so the chips still match the loaded state. If we
        // left it at Private, the selected chip would be invisible
        // and the user would silently re-publish without realizing the
        // visibility flipped.
        return PostVisibility.followers;
      case 'PUBLIC':
      default:
        return PostVisibility.public;
    }
  }

  /// Public-UX Phase 1: the public composer offers only Social + Public.
  /// Personal/Private remains reachable through other (non-public)
  /// entry points so we don't lose the Personal layer; the public
  /// composer just refuses to surface it.
  static const _kPublicComposerVisibilities = <PostVisibility>[
    PostVisibility.followers,
    PostVisibility.public,
  ];

  String _visibilityLabel(PostVisibility value) {
    switch (value) {
      case PostVisibility.public:
        return 'Public';
      case PostVisibility.followers:
        // Public-UX Phase 1: rename "Followers" → "Social" so the
        // composer matches the visibility model the rest of the public
        // surface uses (Social / Public).
        return 'Social';
      case PostVisibility.private:
        return 'Private';
    }
  }

  String _visibilityHelp(PostVisibility value) {
    switch (value) {
      case PostVisibility.public:
        return 'Anyone on Aura can see this and reply.';
      case PostVisibility.followers:
        return 'People you’re connected with can see this.';
      case PostVisibility.private:
        return 'Visible only to you.';
    }
  }

  bool _isRtlLanguageCode(String? code) {
    final normalized = (code ?? '').trim().toLowerCase();
    return normalized == 'ur' ||
        normalized == 'ar' ||
        normalized == 'fa' ||
        normalized == 'he' ||
        normalized == 'ps' ||
        normalized == 'sd';
  }

  bool _looksRtlText(String text) {
    return RegExp(r'[\u0590-\u08FF]').hasMatch(text);
  }

  TextDirection _editorDirection() {
    return _looksRtlText(_textController.text)
        ? TextDirection.rtl
        : TextDirection.ltr;
  }

  TextAlign _editorTextAlign() {
    return _editorDirection() == TextDirection.rtl
        ? TextAlign.right
        : TextAlign.left;
  }

  TextDirection _translationPreviewDirection() {
    final preview = _translationPreview;
    if (preview != null && _isRtlLanguageCode(preview.targetLanguage)) {
      return TextDirection.rtl;
    }
    final previewText = _translationPreview?.translatedText ?? '';
    return _looksRtlText(previewText) ? TextDirection.rtl : TextDirection.ltr;
  }

  TextAlign _translationPreviewTextAlign() {
    return _translationPreviewDirection() == TextDirection.rtl
        ? TextAlign.right
        : TextAlign.left;
  }

  Future<Map<String, int>?> _decodeImageSize(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final img = frame.image;
    return {'width': img.width, 'height': img.height};
  }

  bool get _isMediaFirst =>
      !_isReply && (widget.mode ?? '').trim().toLowerCase() == 'media';

  @override
  void initState() {
    super.initState();

    if (!_isReply) {
      _loadDraft();
      _loadExternalConnections();
    }

    if (_isMediaFirst) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showAddAttachmentSheet();
      });
    }

    _textController.addListener(() {
      _scheduleAutosave();
      if (mounted) {
        setState(() {
          if (_showTextError && _hasText) {
            _showTextError = false;
          }
          final trimmed = _textController.text.trim();
          if (_compositionSnapshot != null && _compositionSnapshot != trimmed) {
            _compositionReview = null;
            _compositionError = null;
            _compositionSnapshot = null;
            _dismissedSuggestionIds.clear();
          }
          if (_translationSnapshot != null && _translationSnapshot != trimmed) {
            _translationPreview = null;
            _translationError = null;
            _translationSnapshot = null;
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

  String _currentComposeRedirect() {
    final params = <String, String>{};
    if (_replyToPostId.isNotEmpty) {
      params['replyTo'] = _replyToPostId;
    }
    if (_heldPostId.isNotEmpty) {
      params['held'] = _heldPostId;
    }
    final surface = (widget.surface ?? '').trim();
    if (surface.isNotEmpty) {
      params['surface'] = surface;
    }

    final mode = (widget.mode ?? '').trim();
    if (mode.isNotEmpty) {
      params['mode'] = mode;
    }

    final uri = Uri(
      path: '/compose',
      queryParameters: params.isEmpty ? null : params,
    );
    return uri.toString();
  }

  Future<bool> _ensureSignedIn() async {
    try {
      final dio = ref.read(dioProvider);
      await dio.get('/users/me');
      return true;
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      if (status == 401 || status == 403) {
        if (!mounted) return false;
        final redirect = Uri.encodeComponent(_currentComposeRedirect());
        context.go('/login?redirect=$redirect');
        return false;
      }
      rethrow;
    }
  }

  Future<void> _loadExternalConnections() async {
    if (_isReply) return;

    if (mounted) {
      setState(() {
        _tiktokLoading = true;
        _linkedinLoading = true;
        _tiktokError = null;
        _linkedinError = null;
      });
    }

    try {
      final dio = ref.read(dioProvider);

      final meRes = await dio.get('/users/me');
      final user = _unwrapUser(meRes.data);
      if (_str(user['id']).isEmpty) {
        throw Exception('User id is missing.');
      }

      final results = await Future.wait<dynamic>([
        _safeGet(dio, '/integrations/tiktok/account'),
        _safeGet(dio, '/integrations/linkedin/account'),
      ]);

      final tiktokAccount = _unwrapTikTokAccount(results[0]?.data);
      final linkedinAccount = _unwrapLinkedInAccount(results[1]?.data);

      if (!mounted) return;

      setState(() {
        _tiktokConnected = _readTikTokConnected(tiktokAccount);
        _tiktokAccountLabel = _readTikTokAccountLabel(tiktokAccount);
        _linkedinConnected = _readLinkedInConnected(linkedinAccount);
        _linkedinAccountLabel = _readLinkedInAccountLabel(linkedinAccount);
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
      if (nestedAccount is Map) {
        return Map<String, dynamic>.from(nestedAccount);
      }
      return nested;
    }

    return root;
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

  Map<String, dynamic> _unwrapLinkedInAccount(dynamic raw) {
    if (raw is! Map) return <String, dynamic>{};

    final root = Map<String, dynamic>.from(raw);
    final data = _asMap(root['data']);
    final nestedData = _asMap(data['data']);
    final account = _asMap(root['account']);
    final nestedAccount = _asMap(data['account']);
    final deepAccount = _asMap(nestedData['account']);

    return _firstNonEmptyMap([
      deepAccount,
      nestedAccount,
      account,
      nestedData,
      data,
      root,
    ]);
  }

  Map<String, dynamic> _firstNonEmptyMap(List<Map<String, dynamic>> maps) {
    for (final map in maps) {
      if (map.isNotEmpty) return map;
    }
    return <String, dynamic>{};
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

  void _syncTikTokToggle() {
    if (!_hasTikTokVideo && _publishToTikTok) {
      _publishToTikTok = false;
    }
  }

  void _syncExternalPublishingToggles() {
    _syncTikTokToggle();

    if (!_linkedinConnected && _publishToLinkedIn) {
      _publishToLinkedIn = false;
    }
  }

  Future<void> _loadDraft() async {
    if (_isReply) return;

    try {
      final dio = ref.read(dioProvider);
      Response<dynamic>? res;

      if (_heldPostId.isNotEmpty) {
        final heldRes = await _safeGet(dio, '/posts/held');
        final heldRoot = _asMap(heldRes?.data);
        final directItems = heldRoot['items'];
        final nestedItems = _asMap(heldRoot['data'])['items'];
        final heldItems = _listOfMap(
          directItems is List ? directItems : nestedItems,
        );
        for (final item in heldItems) {
          if (_str(item['id']) == _heldPostId) {
            res = Response(
              requestOptions: RequestOptions(path: '/posts/held'),
              data: item,
            );
            break;
          }
        }
      }

      res ??= await _safeGet(dio, '/posts/held/latest');
      res ??= await _safeGet(dio, '/posts/draft');
      if (res == null) return;

      final data = _asMap(res.data);
      final draftSource = data['item'] ?? data['draft'] ?? data;

      if (draftSource is! Map) return;

      final draft = Map<String, dynamic>.from(draftSource);
      final text = (draft['text'] ?? '').toString();
      final visibility = _visibilityFromApi(draft['visibility']);

      final updatedAtRaw = (draft['updatedAt'] ?? '').toString();
      final savedAt = DateTime.tryParse(updatedAtRaw)?.toLocal();

      final mediaItems = _listOfMap(draft['media']);

      final loadedAttachments = <ComposeAttachment>[];
      for (final item in mediaItems) {
        final typeRaw = _str(item['type']).toUpperCase();
        final mediaId = _str(item['id']);
        if (mediaId.isEmpty) continue;

        final isVideo = typeRaw == 'VIDEO';
        final captionController = TextEditingController(
          text: _str(item['caption']),
        );
        captionController.addListener(_scheduleAutosave);

        loadedAttachments.add(
          ComposeAttachment(
            localId: mediaId,
            type: isVideo ? ComposeAttachmentType.video : ComposeAttachmentType.image,
            source: ComposeAttachmentSource.gallery,
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
        _syncExternalPublishingToggles();

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

  void _setVisibility(PostVisibility next) {
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
      type: ComposeAttachmentType.image,
      source: ComposeAttachmentSource.gallery,
    );
  }

  Future<void> _pickImageFromCamera() async {
    if (!_canAddMoreAttachments || _posting) return;
    if (!_supportsCameraCapture) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Camera capture is not available here. Choose a file instead.',
          ),
        ),
      );
      await _pickImageFromGallery();
      return;
    }

    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.camera);
    if (file == null) return;

    await _addPickedFile(
      file,
      type: ComposeAttachmentType.image,
      source: ComposeAttachmentSource.camera,
    );
  }

  Future<void> _pickVideoFromGallery() async {
    if (!_canAddMoreAttachments || _posting) return;

    final picker = ImagePicker();
    final file = await picker.pickVideo(source: ImageSource.gallery);
    if (file == null) return;

    await _addPickedFile(
      file,
      type: ComposeAttachmentType.video,
      source: ComposeAttachmentSource.gallery,
    );
  }

  Future<void> _pickVideoFromCamera() async {
    if (!_canAddMoreAttachments || _posting) return;
    if (!_supportsCameraCapture) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Video recording is not available here. Choose a file instead.',
          ),
        ),
      );
      await _pickVideoFromGallery();
      return;
    }

    final picker = ImagePicker();
    final file = await picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(seconds: 30),
    );
    if (file == null) return;

    await _addPickedFile(
      file,
      type: ComposeAttachmentType.video,
      source: ComposeAttachmentSource.camera,
    );
  }

  Future<void> _addPickedFile(
    XFile file, {
    required ComposeAttachmentType type,
    required ComposeAttachmentSource source,
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

    if (type == ComposeAttachmentType.image) {
      bytes = await file.readAsBytes();
      try {
        final size = await _decodeImageSize(bytes);
        width = size?['width'];
        height = size?['height'];
      } catch (_) {}
    }

    final attachment = ComposeAttachment(
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
      _syncExternalPublishingToggles();
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
          _syncExternalPublishingToggles();
        });
      }
    }
  }

  Future<void> _uploadAttachment(ComposeAttachment attachment) async {
    final file = attachment.localFile;
    if (file == null) {
      throw Exception('Attachment file missing.');
    }

    final mime = _inferMime(file.name);
    final result = await uploadAuraMedia(
      dio: ref.read(dioProvider),
      bytes: await file.readAsBytes(),
      fileName: file.name,
      mimeType: mime,
      kind: attachment.isImage ? 'IMAGE' : 'VIDEO',
      source: attachment.source == ComposeAttachmentSource.camera
          ? 'CAMERA'
          : 'GALLERY',
      width: attachment.isImage ? attachment.width : null,
      height: attachment.isImage ? attachment.height : null,
      duration: attachment.isVideo ? attachment.durationMs : null,
      metadataPatch: <String, dynamic>{
        'caption': attachment.captionController.text.trim().isEmpty
            ? null
            : attachment.captionController.text.trim(),
        'editDisclosure': false,
        if (attachment.width != null) 'width': attachment.width,
        if (attachment.height != null) 'height': attachment.height,
      },
    );

    if (!mounted) return;

    setState(() {
      attachment.mediaId = result.mediaId;
      attachment.url = result.url.isNotEmpty ? result.url : null;
      attachment.thumbUrl = result.thumbUrl.isNotEmpty ? result.thumbUrl : null;
      attachment.uploading = false;
      attachment.error = null;
      _syncExternalPublishingToggles();
    });
  }

  Future<void> _persistAttachmentMetadata(ComposeAttachment attachment) async {
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

  Future<void> _removeAttachment(ComposeAttachment attachment) async {
    if (_posting) return;

    final mediaId = (attachment.mediaId ?? '').trim();
    final wasAttachedToDraft = attachment.attachedToDraft;

    setState(() {
      _attachments.removeWhere((a) => a.localId == attachment.localId);
      _uploadingMedia = _attachments.any((a) => a.uploading);
      _syncExternalPublishingToggles();
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
      _syncExternalPublishingToggles();
    });
    _scheduleAutosave();
  }

  void _moveAttachmentRight(int index) {
    if (index < 0 || index >= _attachments.length - 1) return;
    setState(() {
      final item = _attachments.removeAt(index);
      _attachments.insert(index + 1, item);
      _syncExternalPublishingToggles();
    });
    _scheduleAutosave();
  }

  String _savedLine() {
    if (_isReply) {
      return 'Replies publish directly.';
    }
    if (_uploadingMedia) return 'Uploading attachments…';
    if (_publishingToTikTok) return 'Queuing TikTok publish…';
    if (_saving) return 'Autosaving…';
    final dt = _lastSavedAt;
    if (dt == null) return 'Draft not saved yet.';
    return 'Saved ${_time(dt)}.';
  }

  Map<String, dynamic> _buildComposePayload() {
    return {
      'text': _textController.text.trim(),
      'visibility': _visibilityApiValue(_visibility),
      // Public-UX Phase 4 — anchor the post to a public discourse
      // space when the composer was entered with one (or the user
      // picked one). Backend persists this on the draft and replies
      // inherit it from the parent.
      if ((widget.publicSpaceId ?? '').trim().isNotEmpty)
        'publicSpaceId': widget.publicSpaceId!.trim(),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Text is required.')));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not hold this work: $e')));
      }
      rethrow;
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  CompositionSurface get _compositionSurface {
    final explicit = (widget.surface ?? '').trim().toLowerCase();
    switch (explicit) {
      case 'message':
      case 'dm':
      case 'thread':
        return CompositionSurface.message;
      case 'announcement':
        return CompositionSurface.announcement;
      case 'space':
      case 'conversation':
        return CompositionSurface.space;
      case 'post':
      default:
        return _isReply ? CompositionSurface.message : CompositionSurface.post;
    }
  }

  List<CompositionSuggestion> get _visibleSuggestions {
    final review = _compositionReview;
    if (review == null) return const <CompositionSuggestion>[];

    final out = <CompositionSuggestion>[];
    for (final suggestion in review.suggestions) {
      if (_dismissedSuggestionIds.contains(suggestion.id)) continue;
      if ((suggestion.message).trim().isEmpty &&
          (suggestion.replacement).trim().isEmpty) {
        continue;
      }
      out.add(suggestion);
      if (out.length >= 2) break;
    }
    return out;
  }

  Future<CompositionReviewResult?> _runCompositionReview({
    bool silent = false,
  }) async {
    final text = _textController.text.trim();

    if (text.isEmpty) {
      if (!mounted) return null;
      setState(() {
        _showTextError = true;
        _compositionError = 'Write something first.';
        _compositionReview = null;
        _compositionSnapshot = null;
      });
      return null;
    }

    if (_compositionBusy) return _compositionReview;

    setState(() {
      _compositionBusy = true;
      _compositionError = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post(
        '/composition/review',
        data: {'text': text, 'surface': _compositionSurface.name},
      );

      if (!mounted) return null;

      final root = _asMap(response.data);
      final review = CompositionReviewResult.fromJson(root);

      setState(() {
        _compositionReview = review;
        _compositionSnapshot = text;
        _dismissedSuggestionIds.clear();
      });

      if (!silent && review.suggestions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nothing urgent to refine right now.')),
        );
      }

      return review;
    } catch (e) {
      if (!mounted) return null;
      setState(() {
        _compositionError = e.toString();
      });
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Writing review could not run: $e')),
        );
      }
      return null;
    } finally {
      if (mounted) {
        setState(() => _compositionBusy = false);
      }
    }
  }

  Future<void> _applyCompositionSuggestion(
    CompositionSuggestion suggestion,
  ) async {
    final review = _compositionReview;
    if (review == null || suggestion.id.trim().isEmpty) return;

    final currentText = _textController.text;
    final selection = _textController.selection;

    setState(() {
      _applyingSuggestionIds.add(suggestion.id);
      _compositionError = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post(
        '/composition/apply',
        data: {
          'sessionId': review.sessionId,
          'findingId': suggestion.id,
          'currentText': currentText,
        },
      );

      if (!mounted) return;

      final root = _asMap(response.data);
      final nextText = _firstNonEmpty([
        _str(root['text']),
        _str(root['updatedText']),
        _str(root['resultText']),
        _str(_asMap(root['data'])['text']),
        _str(_asMap(root['data'])['updatedText']),
      ], fallback: currentText);

      final nextOffset = selection.baseOffset.clamp(0, nextText.length);
      _textController.value = TextEditingValue(
        text: nextText,
        selection: TextSelection.collapsed(offset: nextOffset),
        composing: TextRange.empty,
      );

      CompositionReviewResult? nextReview;
      try {
        nextReview = CompositionReviewResult.fromJson(root);
      } catch (_) {
        nextReview = null;
      }

      setState(() {
        _compositionSnapshot = nextText.trim();
        if (nextReview != null && nextReview.suggestions.isNotEmpty) {
          _compositionReview = nextReview;
          _dismissedSuggestionIds.clear();
        } else {
          _dismissedSuggestionIds.add(suggestion.id);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _compositionError = e.toString();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not apply suggestion: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _applyingSuggestionIds.remove(suggestion.id);
        });
      }
    }
  }

  Future<void> _translateDraft() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _showTextError = true;
        _translationError = 'Write something first.';
      });
      return;
    }

    if (_translationBusy) return;

    setState(() {
      _translationBusy = true;
      _translationError = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post(
        '/composition/translate',
        data: {'text': text, 'targetLanguage': _translationTargetLanguage},
      );

      if (!mounted) return;

      final root = _asMap(response.data);
      final translatedText = _firstNonEmpty([
        _str(root['translatedText']),
        _str(root['text']),
        _str(_asMap(root['data'])['translatedText']),
        _str(_asMap(root['data'])['text']),
      ]);

      final targetLanguage = _firstNonEmpty([
        _str(root['targetLanguage']),
        _str(_asMap(root['data'])['targetLanguage']),
        _translationTargetLanguage,
      ]);

      if (translatedText.isEmpty) {
        throw Exception('Translation response was empty.');
      }

      setState(() {
        _translationPreview = CompositionTranslationResult(
          translatedText: translatedText,
          targetLanguage: targetLanguage,
        );
        _translationSnapshot = text;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _translationError = e.toString();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Translation could not run: $e')));
    } finally {
      if (mounted) {
        setState(() => _translationBusy = false);
      }
    }
  }

  void _applyTranslationPreview() {
    final preview = _translationPreview;
    if (preview == null) return;

    final nextText = preview.translatedText;
    _textController.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
      composing: TextRange.empty,
    );

    setState(() {
      _translationSnapshot = nextText.trim();
      _translationPreview = null;
      _compositionReview = null;
      _compositionSnapshot = null;
      _dismissedSuggestionIds.clear();
    });
  }

  void _dismissSuggestion(String id) {
    setState(() {
      _dismissedSuggestionIds.add(id);
    });
  }

  Widget _buildSuggestionsCard() {
    final suggestions = _visibleSuggestions;
    final hasError = (_compositionError ?? '').trim().isNotEmpty;

    if (suggestions.isEmpty && !hasError && !_compositionBusy) {
      return const SizedBox.shrink();
    }

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Writing support',
                  style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (_compositionBusy)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          if (hasError) ...[
            const SizedBox(height: AuraSpace.s8),
            Text(
              _compositionError!,
              style: AuraText.small.copyWith(color: AuraSurface.warnInk),
            ),
          ],
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s10),
            for (final suggestion in suggestions) ...[
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
                    Text(
                      suggestion.message,
                      style: AuraText.body.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (suggestion.replacement.trim().isNotEmpty) ...[
                      const SizedBox(height: AuraSpace.s6),
                      Text(
                        suggestion.replacement,
                        style: AuraText.body.copyWith(color: AuraSurface.muted),
                      ),
                    ],
                    const SizedBox(height: AuraSpace.s10),
                    Wrap(
                      spacing: AuraSpace.s8,
                      runSpacing: AuraSpace.s8,
                      children: [
                        if (suggestion.canApply)
                          AuraPrimaryButton(
                            label:
                                _applyingSuggestionIds.contains(suggestion.id)
                                ? 'Applying...'
                                : 'Apply',
                            onPressed:
                                _applyingSuggestionIds.contains(suggestion.id)
                                ? null
                                : () => _applyCompositionSuggestion(suggestion),
                          ),
                        AuraGhostButton(
                          label: 'Dismiss',
                          onPressed: () => _dismissSuggestion(suggestion.id),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildTranslationCard() {
    final preview = _translationPreview;
    final hasError = (_translationError ?? '').trim().isNotEmpty;

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Translation',
                  style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              SizedBox(
                width: 140,
                child: DropdownButtonFormField<String>(
                  initialValue: _translationTargetLanguage,
                  items: const [
                    DropdownMenuItem(value: 'en', child: Text('English')),
                    DropdownMenuItem(value: 'ur', child: Text('Urdu')),
                    DropdownMenuItem(value: 'ar', child: Text('Arabic')),
                    DropdownMenuItem(value: 'tr', child: Text('Turkish')),
                    DropdownMenuItem(value: 'fa', child: Text('Persian')),
                    DropdownMenuItem(value: 'fr', child: Text('French')),
                    DropdownMenuItem(value: 'es', child: Text('Spanish')),
                    DropdownMenuItem(value: 'de', child: Text('German')),
                    DropdownMenuItem(value: 'it', child: Text('Italian')),
                    DropdownMenuItem(value: 'pt', child: Text('Portuguese')),
                    DropdownMenuItem(value: 'hi', child: Text('Hindi')),
                    DropdownMenuItem(value: 'bn', child: Text('Bengali')),
                    DropdownMenuItem(value: 'pa', child: Text('Punjabi')),
                  ],
                  onChanged: _translationBusy || _posting
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() {
                            _translationTargetLanguage = value;
                          });
                        },
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s10),
          Text(
            'Preview the draft in another language without leaving the record.',
            style: AuraText.small.copyWith(color: AuraSurface.muted),
          ),
          if (hasError) ...[
            const SizedBox(height: AuraSpace.s8),
            Text(
              _translationError!,
              style: AuraText.small.copyWith(color: AuraSurface.warnInk),
            ),
          ],
          if (preview != null) ...[
            const SizedBox(height: AuraSpace.s12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AuraSpace.s12),
              decoration: BoxDecoration(
                color: AuraSurface.page,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AuraSurface.divider),
              ),
              child: Directionality(
                textDirection: _translationPreviewDirection(),
                child: Text(
                  preview.translatedText,
                  style: AuraText.body,
                  textAlign: _translationPreviewTextAlign(),
                ),
              ),
            ),
            const SizedBox(height: AuraSpace.s10),
            Wrap(
              spacing: AuraSpace.s8,
              runSpacing: AuraSpace.s8,
              children: [
                AuraPrimaryButton(
                  label: 'Use translation',
                  onPressed: _posting ? null : _applyTranslationPreview,
                ),
                AuraGhostButton(
                  label: 'Clear',
                  onPressed: _posting
                      ? null
                      : () {
                          setState(() {
                            _translationPreview = null;
                            _translationError = null;
                            _translationSnapshot = null;
                          });
                        },
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: AuraSpace.s10),
            AuraSecondaryButton(
              label: _translationBusy
                  ? 'Translating...'
                  : 'Preview translation',
              onPressed: (_posting || _translationBusy)
                  ? null
                  : _translateDraft,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMainCard(BuildContext context, {required bool wide}) {
    final showSuggestions = _compositionBusy ||
        (_compositionError ?? '').isNotEmpty ||
        _visibleSuggestions.isNotEmpty;
    final showTranslation = _translationBusy ||
        (_translationError ?? '').isNotEmpty ||
        _translationPreview != null;

    final belowEditorItems = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showSuggestions) ...[
          const SizedBox(height: AuraSpace.s12),
          _buildSuggestionsCard(),
        ],
        if (!_isReply) ...[
          const SizedBox(height: AuraSpace.s12),
          if (showTranslation) ...[
            _buildTranslationCard(),
            const SizedBox(height: AuraSpace.s12),
          ],
        ],
      ],
    );

    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildEditorSection(),
                belowEditorItems,
              ],
            ),
          ),
          const SizedBox(width: AuraSpace.s16),
          SizedBox(width: 260, child: _buildSecondaryRail()),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildEditorSection(),
        belowEditorItems,
        if (!_isReply) ...[
          _buildDistributionSection(),
          const SizedBox(height: AuraSpace.s12),
          _buildIntentCard(),
        ],
      ],
    );
  }

  Widget _buildEditorSection() {
    return AuraCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusRow(),
          const SizedBox(height: AuraSpace.s14),
          _buildComposerBox(),
          const SizedBox(height: AuraSpace.s8),
          _buildCharacterLine(),
          if (_showTextError) ...[
            const SizedBox(height: AuraSpace.s8),
            Text(
              'Text is required',
              style: AuraText.small.copyWith(color: AuraSurface.warnInk),
            ),
          ],
          if (!_isReply) ...[
            const SizedBox(height: AuraSpace.s16),
            const Divider(color: AuraSurface.divider),
            const SizedBox(height: AuraSpace.s16),
            _buildInlineAudienceRow(),
            const SizedBox(height: AuraSpace.s14),
            _buildAttachmentsBlock(),
          ],
        ],
      ),
    );
  }

  Widget _buildInlineAudienceRow() {
    final spaceName = (widget.publicSpaceName ?? '').trim();
    final hasSpace = (widget.publicSpaceId ?? '').trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Audience',
              style: AuraText.small.copyWith(
                fontWeight: FontWeight.w600,
                color: AuraSurface.muted,
              ),
            ),
            const SizedBox(width: AuraSpace.s12),
            Expanded(
              child: Wrap(
                spacing: AuraSpace.s8,
                runSpacing: AuraSpace.s8,
                children: _kPublicComposerVisibilities
                    .map(
                      (v) => ComposeVisibilityChip(
                        label: _visibilityLabel(v),
                        selected: _visibility == v,
                        onTap: _posting ? null : () => _setVisibility(v),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
        const SizedBox(height: AuraSpace.s6),
        Text(
          _visibilityHelp(_visibility),
          style: AuraText.small.copyWith(color: AuraSurface.muted),
        ),
        // Public-UX Phase 4 — explicit space chip when the composer was
        // entered from a /spaces/:slug surface. The chip makes the
        // anchoring visible so the host knows this post lands inside
        // that space without relying on hashtag mentions.
        if (hasSpace) ...[
          const SizedBox(height: AuraSpace.s10),
          Row(
            children: [
              const Icon(
                Icons.tag_rounded,
                size: 12,
                color: AuraSurface.muted,
              ),
              const SizedBox(width: 5),
              Text(
                spaceName.isNotEmpty
                    ? 'Posting in $spaceName'
                    : 'Posting in space',
                style: AuraText.small.copyWith(
                  color: AuraSurface.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildSecondaryRail() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AuraSpace.s14),
          decoration: BoxDecoration(
            color: AuraSurface.elevated,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isReply ? 'Response' : 'Draft',
                style: AuraText.small.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AuraSurface.muted,
                ),
              ),
              const SizedBox(height: AuraSpace.s4),
              if (_isReply && widget.asInstitution &&
                  (widget.institutionId ?? '').trim().isNotEmpty) ...[
                _ReplyActorBanner(institutionId: widget.institutionId!.trim()),
                const SizedBox(height: AuraSpace.s4),
              ],
              Text(
                _savedLine(),
                style: AuraText.small.copyWith(color: AuraSurface.muted),
              ),
            ],
          ),
        ),
        if (!_isReply) ...[
          const SizedBox(height: AuraSpace.s12),
          AuraCard(
            padding: const EdgeInsets.all(AuraSpace.s14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Distribution',
                  style: AuraText.small.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AuraSurface.muted,
                  ),
                ),
                const SizedBox(height: AuraSpace.s12),
                _buildExternalPublishingBlock(),
              ],
            ),
          ),
          const SizedBox(height: AuraSpace.s12),
          _buildIntentCard(),
        ],
      ],
    );
  }


  Widget _buildDistributionSection() {
    if (_isReply) return const SizedBox.shrink();

    return AuraCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AuraSectionHeader(
            title: 'Advanced distribution',
            subtitle:
                'Cross-posting remains optional and separate from writing.',
          ),
          const SizedBox(height: AuraSpace.s12),
          _buildExternalPublishingBlock(),
        ],
      ),
    );
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Text is required.')));
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
    final assumptions = _listOfMap(
      r['assumptions'],
    ).take(3).map((x) => _str(x['reason'])).where((s) => s.isNotEmpty);
    final clarity = _listOfMap(
      r['clarity_issues'],
    ).take(3).map((x) => _str(x['reason'])).where((s) => s.isNotEmpty);
    final tone = _listOfMap(
      r['tone_flags'],
    ).take(2).map((x) => _str(x['reason'])).where((s) => s.isNotEmpty);

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

  Future<String?> _publishReplyNow() async {
    final dio = ref.read(dioProvider);
    final text = _textController.text.trim();
    final instId = (widget.institutionId ?? '').trim();

    // Branch on the reply target: regular post vs institution post live in
    // different tables and behind different endpoints.
    if (_isInstitutionPostReply) {
      final body = <String, dynamic>{
        'body': text,
      };
      if (widget.asInstitution && instId.isNotEmpty) {
        body['asInstitution'] = true;
        body['actorInstitutionId'] = instId;
      }
      await dio.post(
        '/institutions/$_parentInstitutionId/posts/$_replyToInstitutionPostId/replies',
        data: body,
      );
      return null;
    }

    if (_replyToPostId.isEmpty) {
      throw Exception('Reply target missing.');
    }

    final body = <String, dynamic>{'text': text};
    if (widget.asInstitution && instId.isNotEmpty) {
      body['asInstitution'] = true;
      body['institutionId'] = instId;
    }
    await dio.post('/posts/$_replyToPostId/reply', data: body);
    return null;
  }

  Future<String?> _publishPostNow() async {
    final dio = ref.read(dioProvider);
    final res = await dio.post('/posts/draft/publish');
    return _extractPublishedPostId(res.data);
  }

  Future<String?> _publishNow() async {
    if (_isReply) {
      return _publishReplyNow();
    }

    return _publishPostNow();
  }

  String? _extractPublishedPostId(dynamic raw) {
    final root = _asMap(raw);
    final candidates = <Map<String, dynamic>>[
      root,
      _asMap(root['data']),
      _asMap(root['post']),
      _asMap(_asMap(root['data'])['post']),
    ];

    for (final item in candidates) {
      final id = _str(item['id']);
      if (id.isNotEmpty) return id;
    }

    return null;
  }

  String _buildTikTokCaption() {
    final text = _textController.text.trim();
    if (text.isEmpty) return '';

    final collapsed = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (collapsed.length <= 150) return collapsed;
    return '${collapsed.substring(0, 147).trim()}...';
  }

  Future<void> _publishToLinkedInNow(String postId) async {
    final dio = ref.read(dioProvider);

    final payload = {'postId': postId, 'text': _textController.text.trim()};

    final attempts = <String>['/integrations/linkedin/publish/post'];

    DioException? lastDioError;
    Object? lastError;

    for (final path in attempts) {
      try {
        await dio.post(path, data: payload);
        return;
      } on DioException catch (e) {
        lastDioError = e;
        if (e.response?.statusCode != 404) rethrow;
      } catch (e) {
        lastError = e;
      }
    }

    if (lastDioError != null) throw lastDioError;
    if (lastError != null) throw Exception(lastError.toString());
    throw Exception('LinkedIn publish endpoint was not available.');
  }

  Future<void> _publishToTikTokNow(String postId) async {
    final attachment = _primaryTikTokVideoAttachment;
    if (attachment == null) {
      throw Exception('Add and upload a video first.');
    }

    final mediaUrl = (attachment.url ?? '').trim();
    if (mediaUrl.isEmpty) {
      throw Exception('Uploaded video URL is missing.');
    }

    final dio = ref.read(dioProvider);

    await dio.post(
      '/integrations/tiktok/publish/video',
      data: {
        'postId': postId,
        'mediaUrl': mediaUrl,
        'caption': _buildTikTokCaption(),
        if (_visibility == PostVisibility.public)
          'privacyLevel': 'PUBLIC_TO_EVERYONE',
      },
    );
  }

  Future<void> _publish() async {
    if (_posting) return;

    if (!_hasText) {
      setState(() => _showTextError = true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Text is required.')));
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

    if (_publishToTikTok) {
      if (!_tiktokConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connect TikTok in Me before publishing externally.'),
          ),
        );
        return;
      }

      if (!_hasTikTokVideo) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('TikTok publishing requires one uploaded video.'),
          ),
        );
        return;
      }
    }

    if (!_canPublish) return;

    final signedIn = await _ensureSignedIn();
    if (!signedIn) return;

    _autosaveDebounce?.cancel();

    setState(() => _posting = true);

    String? publishedPostId;
    String? externalMessage;

    try {
      if (!_isReply) {
        await _saveDraft(silent: true, allowWhilePosting: true);
      }

      publishedPostId = await _publishNow();

      if (!_isReply &&
          (_publishToTikTok || _publishToLinkedIn) &&
          (publishedPostId ?? '').trim().isNotEmpty) {
        final queuedTargets = <String>[];
        final failedTargets = <String>[];

        if (_publishToTikTok) {
          setState(() {
            _publishingToTikTok = true;
          });

          try {
            await _publishToTikTokNow(publishedPostId!);
            queuedTargets.add('TikTok');
          } catch (e) {
            failedTargets.add('TikTok ($e)');
          } finally {
            if (mounted) {
              setState(() {
                _publishingToTikTok = false;
              });
            }
          }
        }

        if (_publishToLinkedIn) {
          try {
            await _publishToLinkedInNow(publishedPostId!);
            queuedTargets.add('LinkedIn');
          } catch (e) {
            failedTargets.add('LinkedIn ($e)');
          }
        }

        if (queuedTargets.isNotEmpty && failedTargets.isEmpty) {
          externalMessage =
              'Published to Aura and shared to ${queuedTargets.join(' and ')}.';
        } else if (queuedTargets.isNotEmpty && failedTargets.isNotEmpty) {
          externalMessage =
              'Published to Aura. Shared to ${queuedTargets.join(' and ')}. ${failedTargets.join(', ')} could not be queued.';
        } else if (failedTargets.isNotEmpty) {
          externalMessage =
              'Published to Aura. ${failedTargets.join(', ')} could not be queued.';
        } else {
          externalMessage = 'Published to Aura.';
        }
      } else {
        externalMessage = _isReply ? 'Reply published.' : 'Published to Aura.';
      }

      if (!mounted) return;

      if (externalMessage.trim().isNotEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(externalMessage)));
      }

      if (!_isReply) {
        // Phase 2: invalidate the unified providers — every feed surface
        // consumes them now. Force-refetch so the previous screen finds
        // warm data when it re-mounts.
        ref.invalidate(globalPublicFeedProvider);
        ref.invalidate(memberHomeFeedProvider);
        await ref.read(globalPublicFeedProvider.future);
        await ref.read(memberHomeFeedProvider.future);
      }

      if (!mounted) return;

      final router = GoRouter.of(context);
      if (router.canPop()) {
        router.pop(true);
      } else {
        if (_isReply) {
          router.go('/me/correspondence');
        } else if ((publishedPostId ?? '').trim().isNotEmpty) {
          router.go('/posts/${publishedPostId!.trim()}');
        } else {
          router.go('/home');
        }
      }
    } catch (e) {
      if (!mounted) return;

      final message =
          publishedPostId != null && publishedPostId.trim().isNotEmpty
          ? 'Published to Aura, but the screen could not finish cleanly: $e'
          : 'Could not publish: $e';

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() {
          _posting = false;
          _publishingToTikTok = false;
        });
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
        final spelling = r == null
            ? const <Map<String, String>>[]
            : _spellingItems(r);
        final grammar = r == null
            ? const <Map<String, String>>[]
            : _grammarItems(r);
        final legacySignals = r == null ? const <String>[] : _legacySignals(r);

        final hasAnyContent =
            what.isNotEmpty ||
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
                      const Text('Aura Editor', style: AuraText.title),
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
                        const AuraCard(
                          child: Row(
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: AuraSpace.s10),
                              Expanded(
                                child: Text('Reviewing…', style: AuraText.body),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AuraSpace.s12),
                      ],
                      if (!_auditBusy &&
                          !hasAnyContent &&
                          (_auditError ?? '').trim().isEmpty) ...[
                        const AuraCard(
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
                          AuraSecondaryButton(
                            label: publishMode ? 'Edit' : 'Close',
                            onPressed: _auditBusy
                                ? null
                                : () => Navigator.of(ctx).pop(false),
                          ),
                          AuraSecondaryButton(
                            label: _auditCooldownActive
                                ? 'Please wait…'
                                : 'Run again',
                            onPressed: (_auditBusy || _auditCooldownActive)
                                ? null
                                : rerun,
                          ),
                          if (publishMode)
                            AuraPrimaryButton(
                              label: _isReply ? 'Publish reply' : 'Publish',
                              onPressed: _auditBusy
                                  ? null
                                  : () => Navigator.of(ctx).pop(true),
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
      _visibility = PostVisibility.public;
      _showTextError = false;
      _auditResult = null;
      _auditError = null;
      _uploadingMedia = false;
      _publishToTikTok = false;
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
                const Text('Add attachment', style: AuraText.title),
                const SizedBox(height: AuraSpace.s12),
                ComposeAttachmentActionButton(
                  icon: Icons.camera_alt_outlined,
                  label: _supportsCameraCapture ? 'Take photo' : 'Choose photo',
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _pickImageFromCamera();
                  },
                ),
                const SizedBox(height: AuraSpace.s10),
                ComposeAttachmentActionButton(
                  icon: Icons.photo_library_outlined,
                  label: 'Choose photo',
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _pickImageFromGallery();
                  },
                ),
                const SizedBox(height: AuraSpace.s10),
                ComposeAttachmentActionButton(
                  icon: Icons.videocam_outlined,
                  label: _supportsCameraCapture
                      ? 'Record video'
                      : 'Choose video',
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _pickVideoFromCamera();
                  },
                ),
                const SizedBox(height: AuraSpace.s10),
                ComposeAttachmentActionButton(
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

  int _attachmentColumns(double width) {
    if (width < 700) return 1;
    if (width < 1080) return 2;
    return 3;
  }

  Widget _buildPageTopBar() {
    final leadingIcon = Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AuraSurface.accentSoft,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.accent.withValues(alpha: 0.28)),
      ),
      child: Icon(
        _isReply
            ? Icons.reply_rounded
            : (_isMediaFirst
                ? Icons.perm_media_outlined
                : Icons.edit_note_rounded),
        color: AuraSurface.accentText,
      ),
    );

    final title = _isReply
        ? 'Write a response'
        : (_isMediaFirst ? 'Create with media' : 'Create post');
    final subtitle = _isReply
        ? 'Reply first. The response stays attached to the conversation.'
        : (_isMediaFirst
            ? 'Attach your media first, then add context.'
            : 'Write first, configure second, review third.');

    return LayoutBuilder(
      builder: (ctx, constraints) {
        if (constraints.maxWidth < 560) {
          return Container(
            padding: const EdgeInsets.all(AuraSpace.s16),
            decoration: BoxDecoration(
              gradient: AuraGradients.header,
              borderRadius: BorderRadius.circular(AuraRadius.card),
              border: Border.all(color: AuraSurface.divider),
              boxShadow: AuraShadows.panel,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    leadingIcon,
                    const SizedBox(width: AuraSpace.s12),
                    Expanded(
                      child: Text(title, style: AuraText.headline),
                    ),
                    AuraGhostButton(
                      label: 'Back',
                      icon: Icons.arrow_back,
                      onPressed: _posting ? null : () => context.pop(),
                    ),
                  ],
                ),
                const SizedBox(height: AuraSpace.s8),
                Text(
                  subtitle,
                  style: AuraText.body.copyWith(
                    color: AuraSurface.muted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: AuraSpace.s12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AuraSecondaryButton(
                      label: 'Review',
                      icon: Icons.fact_check_outlined,
                      onPressed: (_posting || _compositionBusy)
                          ? null
                          : () => _runCompositionReview(),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        return AuraGradientHeader(
          title: title,
          subtitle: subtitle,
          leading: leadingIcon,
          trailing: Wrap(
            spacing: AuraSpace.s8,
            runSpacing: AuraSpace.s8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.end,
            children: [
              AuraStatusChip(
                label: _savedLine(),
                backgroundColor: AuraSurface.subtle,
                textColor: AuraSurface.muted,
              ),
              AuraSecondaryButton(
                label: 'Review',
                icon: Icons.fact_check_outlined,
                onPressed: (_posting || _compositionBusy)
                    ? null
                    : () => _runCompositionReview(),
              ),
              AuraGhostButton(
                label: 'Back',
                icon: Icons.arrow_back,
                onPressed: _posting ? null : () => context.pop(),
              ),
            ],
          ),
        );
      },
    );
  }


  Widget _buildStatusRow() {
    return Wrap(
      spacing: AuraSpace.s10,
      runSpacing: AuraSpace.s10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s10,
            vertical: AuraSpace.s6,
          ),
          decoration: BoxDecoration(
            color: AuraSurface.elevated,
            borderRadius: BorderRadius.circular(AuraRadius.pill),
            border: Border.all(color: AuraSurface.divider),
          ),
          child: Text(
            _isReply ? 'Response' : 'Record',
            style: AuraText.small.copyWith(
              color: AuraSurface.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          _savedLine(),
          style: AuraText.small.copyWith(color: AuraSurface.muted),
        ),
      ],
    );
  }

  Widget _buildIntentCard() {
    final title = _isReply
        ? 'Your response will stay with the same conversation.'
        : 'What you place here can remain visible, reviewable, and accountable over time.';
    final subtitle = _isReply
        ? 'Respond with care. Your words become part of the public thread around this work.'
        : 'Write for the record first. Audience, attachments, translation, and distribution stay available as supporting tools.';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AuraSurface.elevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AuraSurface.divider),
      ),
      padding: const EdgeInsets.all(AuraSpace.s14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isReply ? 'Response context' : 'Publishing context',
            style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AuraSpace.s8),
          Text(title, style: AuraText.body),
          const SizedBox(height: AuraSpace.s6),
          Text(
            subtitle,
            style: AuraText.small.copyWith(color: AuraSurface.muted),
          ),
        ],
      ),
    );
  }


  Widget _buildComposerBox() {
    return Container(
      decoration: BoxDecoration(
        color: AuraSurface.page,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AuraSurface.divider),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s14,
        vertical: AuraSpace.s12,
      ),
      child: TextField(
        controller: _textController,
        maxLines: null,
        minLines: 10,
        textCapitalization: TextCapitalization.sentences,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        style: AuraText.body.copyWith(height: 1.55),
        textDirection: _editorDirection(),
        textAlign: _editorTextAlign(),
        decoration: InputDecoration(
          hintText: _isReply
              ? 'Add your response with care.'
              : 'Write for the record — your words, your voice.',
          hintStyle: AuraText.small.copyWith(color: AuraSurface.muted),
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
        const SizedBox(height: AuraSpace.s10),
        Wrap(
          spacing: AuraSpace.s10,
          runSpacing: AuraSpace.s10,
          children: [
            AuraSecondaryButton(
              label: 'Add attachment',
              icon: Icons.add,
              onPressed: (_posting || !_canAddMoreAttachments)
                  ? null
                  : _showAddAttachmentSheet,
            ),
          ],
        ),
        if (_attachments.isNotEmpty) ...[
          const SizedBox(height: AuraSpace.s12),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = _attachmentColumns(constraints.maxWidth);
              const gap = AuraSpace.s12;
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
                    child: ComposeAttachmentCard(
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

  Widget _buildExternalPublishingBlock() {
    if (_isReply) return const SizedBox.shrink();

    final canUseTikTok = _tiktokConnected && _hasTikTokVideo && !_posting;
    final tiktokSubtitle = _tiktokLoading
        ? 'Checking connection…'
        : !_tiktokConnected
        ? 'Connect TikTok from Me to publish externally.'
        : !_hasTikTokVideo
        ? 'Add and upload one video to enable TikTok publishing.'
        : _tiktokAccountLabel.isNotEmpty
        ? 'Connected as $_tiktokAccountLabel'
        : 'Connected';

    final linkedinVisible = _linkedinLoading || _linkedinConnected;
    final canUseLinkedIn = _linkedinConnected && !_posting;
    final linkedinSubtitle = _linkedinLoading
        ? 'Checking connection…'
        : _linkedinAccountLabel.isNotEmpty
        ? 'Connected as $_linkedinAccountLabel'
        : 'Connected';

    final tiktokHelper = (_tiktokError ?? '').trim();
    final linkedinHelper = (_linkedinError ?? '').trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Publish elsewhere',
          style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AuraSpace.s8),
        Container(
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
                  const Icon(
                    Icons.music_note_outlined,
                    size: 18,
                    color: AuraSurface.ink,
                  ),
                  const SizedBox(width: AuraSpace.s10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TikTok',
                          style: AuraText.body.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tiktokSubtitle,
                          style: AuraText.small.copyWith(
                            color: AuraSurface.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_tiktokLoading || _tiktokActionBusy)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Switch(
                      value: _publishToTikTok,
                      onChanged: canUseTikTok
                          ? (value) {
                              setState(() {
                                _publishToTikTok = value;
                              });
                            }
                          : null,
                    ),
                ],
              ),
              if (tiktokHelper.isNotEmpty) ...[
                const SizedBox(height: AuraSpace.s10),
                Text(
                  tiktokHelper,
                  style: AuraText.small.copyWith(color: AuraSurface.warnInk),
                ),
              ],
              if (linkedinVisible) ...[
                const SizedBox(height: AuraSpace.s12),
                Container(height: 1, color: AuraSurface.divider),
                const SizedBox(height: AuraSpace.s12),
                Row(
                  children: [
                    const Icon(
                      Icons.business_center_outlined,
                      size: 18,
                      color: AuraSurface.ink,
                    ),
                    const SizedBox(width: AuraSpace.s10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'LinkedIn',
                            style: AuraText.body.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            linkedinSubtitle,
                            style: AuraText.small.copyWith(
                              color: AuraSurface.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_linkedinLoading)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Switch(
                        value: _publishToLinkedIn,
                        onChanged: canUseLinkedIn
                            ? (value) {
                                setState(() {
                                  _publishToLinkedIn = value;
                                });
                              }
                            : null,
                      ),
                  ],
                ),
                if (linkedinHelper.isNotEmpty) ...[
                  const SizedBox(height: AuraSpace.s10),
                  Text(
                    linkedinHelper,
                    style: AuraText.small.copyWith(color: AuraSurface.warnInk),
                  ),
                ],
              ],
              if (_publishToTikTok || _publishToLinkedIn) ...[
                const SizedBox(height: AuraSpace.s10),
                Text(
                  _publishToTikTok && _publishToLinkedIn
                      ? 'Aura publishes first, then sends the post to TikTok and LinkedIn.'
                      : _publishToTikTok
                      ? 'Aura will publish the post first, then queue the first uploaded video to TikTok.'
                      : 'Aura will publish the post first, then send the text to LinkedIn.',
                  style: AuraText.small.copyWith(color: AuraSurface.muted),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    final discardBtn = AuraGhostButton(
      label: 'Discard',
      onPressed: _posting ? null : _discardAndClose,
    );

    final saveDraftBtn = AuraGhostButton(
      label: _isReply ? 'Save unavailable' : 'Save draft',
      onPressed: (_isReply || _posting || _saving || !_hasText || _uploadingMedia)
          ? null
          : () {
              if (!_hasText) {
                setState(() => _showTextError = true);
                return;
              }
              _saveDraft(silent: false);
            },
    );

    final publishBtn = AuraPrimaryButton(
      label: _posting
          ? (_isReply
                ? 'Publishing reply…'
                : (_publishingToTikTok ? 'Queuing TikTok…' : 'Publishing…'))
          : (_isReply ? 'Publish response' : 'Publish post'),
      onPressed: (_posting || !_canPublish)
          ? null
          : () {
              if (!_hasText) {
                setState(() => _showTextError = true);
                return;
              }
              _publish();
            },
    );

    return Container(
      padding: EdgeInsets.fromLTRB(
        AuraSpace.s16,
        AuraSpace.s12,
        AuraSpace.s16,
        AuraSpace.s12 + bottomPad,
      ),
      decoration: const BoxDecoration(
        color: AuraSurface.page,
        border: Border(top: BorderSide(color: AuraSurface.divider)),
      ),
      child: LayoutBuilder(
        builder: (_, constraints) {
          if (constraints.maxWidth < 520) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    discardBtn,
                    const SizedBox(width: AuraSpace.s8),
                    saveDraftBtn,
                  ],
                ),
                const SizedBox(height: AuraSpace.s8),
                publishBtn,
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                child: Text(
                  _savedLine(),
                  style: AuraText.small.copyWith(color: AuraSurface.muted),
                ),
              ),
              const SizedBox(width: AuraSpace.s8),
              discardBtn,
              const SizedBox(width: AuraSpace.s8),
              saveDraftBtn,
              const SizedBox(width: AuraSpace.s12),
              publishBtn,
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final wide = MediaQuery.of(context).size.width >= 1080;

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
                    constraints: const BoxConstraints(maxWidth: 1240),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPageTopBar(),
                        const SizedBox(height: AuraSpace.s16),
                        _buildMainCard(context, wide: wide),
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

String _time(DateTime dt) {
  final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final mm = dt.minute.toString().padLeft(2, '0');
  final ap = dt.hour >= 12 ? 'pm' : 'am';
  return '$h:$mm $ap';
}

/// Renders "Replying as: <Institution Name>" when the compose screen is
/// launched with `asInstitution=true&institutionId=...`. Reads the live
/// institution identity so the name follows whatever institution the user
/// is acting as.
class _ReplyActorBanner extends ConsumerWidget {
  const _ReplyActorBanner({required this.institutionId});

  final String institutionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(institutionIdentityProvider);
    final name =
        identity != null && identity.id == institutionId && identity.name.isNotEmpty
            ? identity.name
            : 'institution';
    return Container(
      margin: const EdgeInsets.only(top: AuraSpace.s4),
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s8,
        vertical: AuraSpace.s4,
      ),
      decoration: BoxDecoration(
        color: AuraSurface.accentSoft,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        border: Border.all(color: AuraSurface.accent.withValues(alpha: 0.4)),
      ),
      child: Text(
        'Replying as $name',
        style: AuraText.micro.copyWith(
          color: AuraSurface.accentText,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
