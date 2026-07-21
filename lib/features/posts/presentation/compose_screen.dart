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
import '../../../core/tagging/governed_tag_field.dart';
import '../../../core/compliance/objectionable_content.dart';
import '../../../core/institutions/institution_access_provider.dart';
import '../../../core/media/attachment.dart';
import '../../../core/media/media_mime.dart';
import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_design_system.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_responsive.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../ai/providers.dart';
import '../../feed/data/unified_feed_providers.dart';
import '../../topics/aura_topic_selector.dart';
import '../../topics/topic.dart';
import '../../composition/domain/composition_models.dart';
import '../../composition/presentation/composition_assist.dart';
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
  final String? editPostId;
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

  /// Public-UX Phase 5 — discourse intent token: `ask` / `raise` /
  /// `share`. Pre-selects the intent button on entry; the composer
  /// updates the placeholder + tone hint accordingly. Null leaves the
  /// composer in its default rotating-prompt state.
  final String? intent;

  const ComposeScreen({
    super.key,
    this.replyToPostId,
    this.replyToInstitutionPostId,
    this.parentInstitutionId,
    this.heldPostId,
    this.editPostId,
    this.surface,
    this.mode,
    this.asInstitution = false,
    this.institutionId,
    this.publicSpaceId,
    this.publicSpaceName,
    this.publicSpaceSlug,
    this.intent,
  });

  @override
  ConsumerState<ComposeScreen> createState() => _ComposeScreenState();
}

/// Public-UX Phase 5 — discourse intent. Shapes placeholder, tone
/// hint, and the "intent" chip group. Backend doesn't know about
/// intent today — it's purely a UX-shaping signal.
enum _ComposeIntent { none, ask, raise, share }

extension on _ComposeIntent {
  String get label {
    switch (this) {
      case _ComposeIntent.ask:
        return 'Ask';
      case _ComposeIntent.raise:
        return 'Raise issue';
      case _ComposeIntent.share:
        return 'Share update';
      case _ComposeIntent.none:
        return '';
    }
  }

  IconData get icon {
    switch (this) {
      case _ComposeIntent.ask:
        return Icons.help_outline_rounded;
      case _ComposeIntent.raise:
        return Icons.report_problem_outlined;
      case _ComposeIntent.share:
        return Icons.campaign_outlined;
      case _ComposeIntent.none:
        return Icons.edit_outlined;
    }
  }

  /// Tone hint shown beneath the intent row when an intent is picked.
  String? get toneHint {
    switch (this) {
      case _ComposeIntent.ask:
        return 'Frame this as a question others can answer.';
      case _ComposeIntent.raise:
        return 'State the issue clearly. People should be able to respond to it.';
      case _ComposeIntent.share:
        return 'Share something that needs attention. Be direct.';
      case _ComposeIntent.none:
        return null;
    }
  }

  /// Placeholder for the body field when this intent is selected.
  String get placeholder {
    switch (this) {
      case _ComposeIntent.ask:
        return 'Ask something others can answer';
      case _ComposeIntent.raise:
        return 'Raise an issue people should respond to';
      case _ComposeIntent.share:
        return 'Share something that needs attention';
      case _ComposeIntent.none:
        return '';
    }
  }
}

_ComposeIntent _intentFromWire(String? raw) {
  switch ((raw ?? '').toLowerCase().trim()) {
    case 'ask':
      return _ComposeIntent.ask;
    case 'raise':
    case 'raise_issue':
      return _ComposeIntent.raise;
    case 'share':
    case 'share_update':
      return _ComposeIntent.share;
    default:
      return _ComposeIntent.none;
  }
}

/// Default rotating placeholder pool used when no intent is set.
const List<String> _kRotatingPrompts = [
  'Ask something others can answer',
  'Raise an issue people should respond to',
  'Share something that needs attention',
];

class _ComposeScreenState extends ConsumerState<ComposeScreen> {
  static const int _limit = 2000;
  static const int _maxAttachments = 5;

  /// Public-UX Phase 5 — current selected intent. Initialised from
  /// the route query param (`?intent=ask`) and rotated to `_none`
  /// when the user clears it.
  late _ComposeIntent _intent = _intentFromWire(widget.intent);

  /// Index into `_kRotatingPrompts` — used only when `_intent` is
  /// `_ComposeIntent.none`. Set once on each composer mount so the
  /// prompt rotates by entry count, not by clock.
  final int _rotatingIdx =
      DateTime.now().millisecondsSinceEpoch % _kRotatingPrompts.length;

  final _textController = TextEditingController();
  // AXR-1 — explicit focus node so governed tag autocomplete can track
  // field focus (overlay closes on blur).
  final _textFocus = FocusNode();

  bool _posting = false;
  bool _saving = false;
  bool _showTextError = false;
  bool _uploadingMedia = false;

  PostVisibility _visibility = PostVisibility.public;

  /// Content Topics — human-selected Primary Topic (authoritative) + optional
  /// Secondary Topics (suggested, editable). Mirrors the institution composer
  /// so member posts carry the same LEFT-side feed-filter dimension. Sent on
  /// the draft payload and preserved through publish.
  AuraTopic? _primaryTopic;
  List<AuraTopic> _secondaryTopics = <AuraTopic>[];

  final List<Attachment> _attachments = [];

  /// Per-attachment caption text. Keyed by `attachment.localId`. Owned
  /// by the screen state (not the model) so the canonical `Attachment`
  /// stays free of UI-control coupling — see lib/core/media/attachment.dart.
  final Map<String, TextEditingController> _captionControllers = {};

  TextEditingController _ensureCaptionController(
    Attachment att, {
    String initialText = '',
  }) {
    final existing = _captionControllers[att.localId];
    if (existing != null) return existing;
    final c = TextEditingController(text: initialText);
    c.addListener(_scheduleAutosave);
    _captionControllers[att.localId] = c;
    return c;
  }

  String _captionText(Attachment att) {
    return _captionControllers[att.localId]?.text.trim() ?? '';
  }

  void _disposeCaptionController(String localId) {
    final c = _captionControllers.remove(localId);
    c?.dispose();
  }

  DateTime? _lastSavedAt;
  Timer? _autosaveDebounce;

  bool _auditBusy = false;
  DateTime? _lastAuditAt;
  Map<String, dynamic>? _auditResult;
  String? _auditError;

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
      widget.replyToPostId != null || widget.replyToInstitutionPostId != null;
  bool get _isInstitutionPostReply =>
      (widget.replyToInstitutionPostId ?? '').trim().isNotEmpty &&
      (widget.parentInstitutionId ?? '').trim().isNotEmpty;

  String get _replyToPostId => (widget.replyToPostId ?? '').trim();
  String get _replyToInstitutionPostId =>
      (widget.replyToInstitutionPostId ?? '').trim();
  String get _parentInstitutionId => (widget.parentInstitutionId ?? '').trim();
  String get _heldPostId => (widget.heldPostId ?? '').trim();
  String get _editPostId => (widget.editPostId ?? '').trim();
  bool get _isEditingPost => _editPostId.isNotEmpty;

  bool get _hasText => _textController.text.trim().isNotEmpty;
  bool get _textTooLong => _textController.text.trim().length > _limit;
  bool get _hasUploadingAttachments => _attachments.any((a) => a.uploading);
  bool get _canAddMoreAttachments =>
      !_isReply && _attachments.length < _maxAttachments;
  bool get _supportsCameraCapture => !kIsWeb;

  Attachment? get _primaryTikTokVideoAttachment {
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
    if (!_isReply && _primaryTopic == null) return false;
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

  // _inferMime moved to lib/core/media/media_mime.dart::inferMimeFromFileName.

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

    if (_isEditingPost) {
      _loadEditablePost();
    } else if (!_isReply) {
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
          // Composition-assist staleness is handled inside CompositionAssist
          // (it invalidates its own review/translation when `text` changes).
        });
      }
    });
  }

  @override
  void dispose() {
    _autosaveDebounce?.cancel();
    _textController.dispose();
    _textFocus.dispose();
    for (final c in _captionControllers.values) {
      c.dispose();
    }
    _captionControllers.clear();
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
    if (_isEditingPost) return;
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

      final loadedAttachments = <Attachment>[];
      for (final item in mediaItems) {
        final typeRaw = _str(item['type']).toUpperCase();
        final mediaId = _str(item['id']);
        if (mediaId.isEmpty) continue;

        final isVideo = typeRaw == 'VIDEO';

        final att = Attachment(
          localId: mediaId,
          kind: isVideo ? AttachmentKind.video : AttachmentKind.image,
          source: AttachmentSource.gallery,
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
        );
        _ensureCaptionController(att, initialText: _str(item['caption']));
        loadedAttachments.add(att);
      }

      if (!mounted) return;

      setState(() {
        _textController.text = text;
        _visibility = visibility;
        _primaryTopic = AuraTopic.fromWire(_str(draft['primaryTopic']));
        _secondaryTopics = AuraTopic.listFromWire(draft['secondaryTopics']);
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

  Future<void> _loadEditablePost() async {
    if (!_isEditingPost) return;

    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/posts/$_editPostId');
      final root = _asMap(res.data);
      final postSource = root['post'] ?? root['item'] ?? root['data'] ?? root;
      if (postSource is! Map) return;

      final post = Map<String, dynamic>.from(postSource);
      final mediaItems = _listOfMap(post['media']);
      final loadedAttachments = <Attachment>[];
      for (final item in mediaItems) {
        final typeRaw = _str(item['type']).toUpperCase();
        final mediaId = _str(item['id']);
        if (mediaId.isEmpty) continue;
        final isVideo = typeRaw == 'VIDEO';
        final att = Attachment(
          localId: mediaId,
          kind: isVideo ? AttachmentKind.video : AttachmentKind.image,
          source: AttachmentSource.gallery,
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
        );
        _ensureCaptionController(att, initialText: _str(item['caption']));
        loadedAttachments.add(att);
      }

      if (!mounted) return;
      setState(() {
        _textController.text = _str(post['text']);
        _visibility = _visibilityFromApi(post['visibility']);
        _primaryTopic = AuraTopic.fromWire(_str(post['primaryTopic']));
        _secondaryTopics = AuraTopic.listFromWire(post['secondaryTopics']);
        _lastSavedAt = null;
        _attachments
          ..clear()
          ..addAll(loadedAttachments);
        if (_hasText) _showTextError = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load post for editing: $e')),
      );
    }
  }

  void _scheduleAutosave() {
    if (_isEditingPost) return;
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
      type: AttachmentKind.image,
      source: AttachmentSource.gallery,
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
      type: AttachmentKind.image,
      source: AttachmentSource.camera,
    );
  }

  Future<void> _pickVideoFromGallery() async {
    if (!_canAddMoreAttachments || _posting) return;

    final picker = ImagePicker();
    final file = await picker.pickVideo(source: ImageSource.gallery);
    if (file == null) return;

    await _addPickedFile(
      file,
      type: AttachmentKind.video,
      source: AttachmentSource.gallery,
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
      type: AttachmentKind.video,
      source: AttachmentSource.camera,
    );
  }

  Future<void> _addPickedFile(
    XFile file, {
    required AttachmentKind type,
    required AttachmentSource source,
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

    if (type == AttachmentKind.image) {
      bytes = await file.readAsBytes();
      try {
        final size = await _decodeImageSize(bytes);
        width = size?['width'];
        height = size?['height'];
      } catch (_) {}
    }

    final attachment = Attachment(
      localId: '${DateTime.now().microsecondsSinceEpoch}_${file.name}',
      kind: type,
      source: source,
      file: file,
      bytes: bytes,
      fileName: file.name,
      width: width,
      height: height,
      uploading: true,
      attachedToDraft: false,
    );

    _ensureCaptionController(attachment);

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

  Future<void> _uploadAttachment(Attachment attachment) async {
    final file = attachment.file;
    if (file == null) {
      throw Exception('Attachment file missing.');
    }

    final mime = inferMimeFromFileName(file.name) ?? 'application/octet-stream';
    final captionText = _captionText(attachment);
    final result = await uploadAuraMedia(
      dio: ref.read(dioProvider),
      bytes: await file.readAsBytes(),
      fileName: file.name,
      mimeType: mime,
      kind: wireKind(attachment.kind),
      source: wireSource(attachment.source),
      width: attachment.isImage ? attachment.width : null,
      height: attachment.isImage ? attachment.height : null,
      duration: attachment.isVideo ? attachment.durationMs : null,
      metadataPatch: <String, dynamic>{
        'caption': captionText.isEmpty ? null : captionText,
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

  Future<void> _persistAttachmentMetadata(Attachment attachment) async {
    final mediaId = (attachment.mediaId ?? '').trim();
    if (mediaId.isEmpty) return;

    try {
      final dio = ref.read(dioProvider);
      final captionText = _captionText(attachment);
      await dio.patch(
        '/media/$mediaId',
        data: {'caption': captionText.isEmpty ? null : captionText},
      );
    } catch (_) {
      // best-effort
    }
  }

  Future<void> _removeAttachment(Attachment attachment) async {
    if (_posting) return;

    final mediaId = (attachment.mediaId ?? '').trim();
    final wasAttachedToDraft = attachment.attachedToDraft;

    setState(() {
      _attachments.removeWhere((a) => a.localId == attachment.localId);
      _uploadingMedia = _attachments.any((a) => a.uploading);
      _syncExternalPublishingToggles();
    });

    _disposeCaptionController(attachment.localId);

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

  /// Maps the current intent selection to the backend wire enum value.
  /// Returns null for replies or when no intent is selected (backend
  /// treats absent/null as no intent — post is not routed).
  String? _intentWire() {
    if (_isReply) return null;
    switch (_intent) {
      case _ComposeIntent.ask:
        return 'ASK';
      case _ComposeIntent.raise:
        return 'ISSUE';
      case _ComposeIntent.share:
        return 'UPDATE';
      case _ComposeIntent.none:
        return null;
    }
  }

  Map<String, dynamic> _buildComposePayload() {
    final intentWire = _intentWire();
    return {
      'text': _textController.text.trim(),
      'visibility': _visibilityApiValue(_visibility),
      // Content Topics — always send current selection so the draft (and the
      // post it publishes into) reflects the composer state. `null` clears.
      'primaryTopic': _primaryTopic?.wire,
      'secondaryTopics': _secondaryTopics.map((t) => t.wire).toList(),
      // Public-record routing — intent tells the backend which accountability
      // route to attempt when PUBLIC_RECORD_ROUTING_ENABLED is on.
      // Null/absent means no routing is attempted.
      if (intentWire != null) 'intent': intentWire,
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
          .map((entry) {
            final captionText = _captionText(entry.value);
            return {
              'mediaId': entry.value.mediaId,
              'position': entry.key,
              'caption': captionText.isEmpty ? null : captionText,
            };
          })
          .toList(),
    };
  }

  Future<void> _saveDraft({
    bool silent = false,
    bool allowWhilePosting = false,
  }) async {
    if (_isEditingPost) return;
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

  /// Apply assist output (a suggestion or translation) back into the body
  /// editor, preserving the caret where possible.
  void _applyAssistText(String next) {
    final sel = _textController.selection;
    final offset = sel.baseOffset >= 0
        ? sel.baseOffset.clamp(0, next.length)
        : next.length;
    _textController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: offset),
      composing: TextRange.empty,
    );
    if (mounted) setState(() {});
  }

  Widget _buildMainCard(BuildContext context, {required bool wide}) {
    // Composition assist (review + translation) — single shared widget. Hidden
    // on replies to keep the reply surface lean.
    final belowEditorItems = _isReply
        ? const SizedBox.shrink()
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AuraSpace.s12),
              CompositionAssist(
                text: _textController.text,
                surface: _compositionSurface,
                enabled: !_posting,
                onApply: _applyAssistText,
              ),
              const SizedBox(height: AuraSpace.s12),
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
              children: [_buildEditorSection(), belowEditorItems],
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
          // Public-UX Phase 5 — discourse intent buttons. Hidden on
          // replies (replies inherit intent from the parent) and
          // shown above the body input on new posts.
          if (!_isReply) ...[
            const SizedBox(height: AuraSpace.s12),
            _buildIntentRow(),
          ],
          const SizedBox(height: AuraSpace.s14),
          _buildComposerBox(),
          const SizedBox(height: AuraSpace.s8),
          _buildCharacterLine(),
          if (_showTextError) ...[
            const SizedBox(height: AuraSpace.s8),
            Text(
              'Text is required',
              style: AuraText.small.copyWith(color: AuraSurface.coSun),
            ),
          ],
          if (!_isReply) ...[
            const SizedBox(height: AuraSpace.s16),
            const Divider(color: AuraSurface.divider),
            const SizedBox(height: AuraSpace.s16),
            _buildInlineAudienceRow(),
            const SizedBox(height: AuraSpace.s14),
            _buildAttachmentsBlock(),
            const SizedBox(height: AuraSpace.s16),
            const Divider(color: AuraSurface.divider),
            const SizedBox(height: AuraSpace.s16),
            AuraTopicSelector(
              primary: _primaryTopic,
              secondaries: _secondaryTopics,
              contentText: _textController.text,
              onPrimaryChanged: (t) {
                setState(() => _primaryTopic = t);
                // Drop any secondary that now equals the primary, then persist.
                if (t != null && _secondaryTopics.contains(t)) {
                  setState(() {
                    _secondaryTopics = _secondaryTopics
                        .where((x) => x != t)
                        .toList();
                  });
                }
                _scheduleAutosave();
              },
              onSecondariesChanged: (list) {
                setState(() => _secondaryTopics = list);
                _scheduleAutosave();
              },
            ),
          ],
        ],
      ),
    );
  }

  /// Public-UX Phase 5 — discourse intent buttons. Three optional
  /// chips above the body input that shape the placeholder + tone
  /// hint. Tapping a selected chip clears the intent (toggle).
  Widget _buildIntentRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AuraSpace.s8,
          runSpacing: AuraSpace.s8,
          children: [
            _IntentChip(
              kind: _ComposeIntent.ask,
              selected: _intent == _ComposeIntent.ask,
              onTap: () => setState(() {
                _intent = _intent == _ComposeIntent.ask
                    ? _ComposeIntent.none
                    : _ComposeIntent.ask;
              }),
            ),
            _IntentChip(
              kind: _ComposeIntent.raise,
              selected: _intent == _ComposeIntent.raise,
              onTap: () => setState(() {
                _intent = _intent == _ComposeIntent.raise
                    ? _ComposeIntent.none
                    : _ComposeIntent.raise;
              }),
            ),
            _IntentChip(
              kind: _ComposeIntent.share,
              selected: _intent == _ComposeIntent.share,
              onTap: () => setState(() {
                _intent = _intent == _ComposeIntent.share
                    ? _ComposeIntent.none
                    : _ComposeIntent.share;
              }),
            ),
          ],
        ),
        if (_intent != _ComposeIntent.none && _intent.toneHint != null) ...[
          const SizedBox(height: AuraSpace.s8),
          Text(
            _intent.toneHint!,
            style: AuraText.small.copyWith(
              color: AuraSurface.muted,
              height: 1.4,
            ),
          ),
        ],
      ],
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
              const Icon(Icons.tag_rounded, size: 12, color: AuraSurface.muted),
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
              if (_isReply &&
                  widget.asInstitution &&
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
      final body = <String, dynamic>{'body': text};
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

  Future<String?> _saveEditedPostNow() async {
    final dio = ref.read(dioProvider);
    final res = await dio.put(
      '/posts/$_editPostId',
      data: _buildComposePayload(),
    );
    return _extractPublishedPostId(res.data) ?? _editPostId;
  }

  Future<String?> _publishNow() async {
    if (_isReply) {
      return _publishReplyNow();
    }
    if (_isEditingPost) {
      return _saveEditedPostNow();
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

    // Apple Store §1.2 UGC compliance — client-side first-pass
    // content filter. Backend re-runs the same rule at publish; this
    // client check is purely a UX courtesy that fails fast without a
    // network round-trip.
    final filterHit = scanForObjectionableContent(_textController.text);
    if (filterHit != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(kObjectionableContentMessage)),
      );
      return;
    }

    if (!_isReply && _primaryTopic == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a topic before publishing.'),
          duration: Duration(seconds: 3),
        ),
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
      if (!_isReply && !_isEditingPost) {
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
        // Refresh every unified feed surface. `invalidateUnifiedFeedSurfaces`
        // covers both the FutureProvider and StateNotifier (paged) variants
        // — the Works tab on /home subscribes to the paged variant, so a
        // bare `ref.invalidate(memberHomeFeedProvider)` would miss it and
        // the user's just-published post would not appear until pull-to-
        // refresh.
        invalidateUnifiedFeedSurfaces(ref);
        // Force-prime the FutureProvider variants so the previous screen
        // finds warm data when it re-mounts. The paged notifier's own
        // `refresh()` is already kicked off inside the helper.
        await ref.read(globalPublicFeedProvider.future);
        await ref.read(memberHomeFeedProvider.future);
      }

      if (!mounted) return;

      // Public-UX Phase 5 — micro-feedback on publish so the host feels
      // the action landed. Distinct copy for replies vs. statements.
      // We render via ScaffoldMessenger.maybeOf so it survives even if
      // we've already popped this scaffold off the stack.
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            _isReply
                ? 'Your reply is live in the discussion.'
                : 'Your discussion is live.',
          ),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );

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

      // Capability gate: backend returns 403 when the user is not eligible
      // to raise issues (CAN_RAISE_ISSUE_GATE_ENABLED=true). Show a calm,
      // non-judgmental message rather than a raw error string.
      if (e is DioException &&
          e.response?.statusCode == 403 &&
          _intent == _ComposeIntent.raise) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Raising issues may require account verification or eligibility. '
              'You can still ask a question or share an update.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
        return;
      }

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
    if (!_isReply && !_isEditingPost) {
      try {
        await ref.read(dioProvider).delete('/posts/draft');
      } catch (_) {
        // Discard is a local escape hatch too; backend cleanup is retried by
        // stale-draft filtering on the next Home load.
      }
    }

    for (final c in _captionControllers.values) {
      c.dispose();
    }
    _captionControllers.clear();

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
    ref.invalidate(memberHomeFeedPagedProvider);

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
        : (_isEditingPost
              ? 'Edit post'
              : (_isMediaFirst ? 'Create with media' : 'Create post'));
    final subtitle = _isReply
        ? 'Reply first. The response stays attached to the conversation.'
        : (_isEditingPost
              ? 'Update the existing post without creating a duplicate.'
              : (_isMediaFirst
                    ? 'Attach your media first, then add context.'
                    : 'Write first, configure second, review third.'));

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
                    Expanded(child: Text(title, style: AuraText.headline)),
                    AuraGhostButton(
                      label: 'Back',
                      icon: Icons.arrow_back,
                      onPressed: _posting
                          ? null
                          : () {
                              // Reached via context.go from the Create hub has no
                              // back-stack — fall back to a safe home so Back is
                              // never a dead tap.
                              if (context.canPop()) {
                                context.pop();
                              } else {
                                context.go('/home');
                              }
                            },
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
              AuraGhostButton(
                label: 'Back',
                icon: Icons.arrow_back,
                onPressed: _posting
                    ? null
                    : () {
                        // Reached via context.go from the Create hub has no
                        // back-stack — fall back to a safe home so Back is
                        // never a dead tap.
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/home');
                        }
                      },
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
      // AXR-1 — governed @member/@institution/#topic autocomplete.
      child: GovernedTagAutocomplete(
        controller: _textController,
        focusNode: _textFocus,
        child: TextField(
          controller: _textController,
          focusNode: _textFocus,
          maxLines: null,
          minLines: 10,
          textCapitalization: TextCapitalization.sentences,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          style: AuraText.body.copyWith(height: 1.55),
          textDirection: _editorDirection(),
          textAlign: _editorTextAlign(),
          decoration: InputDecoration(
            hintText: _composerHint(),
            hintStyle: AuraText.small.copyWith(color: AuraSurface.muted),
            border: InputBorder.none,
            errorText: _showTextError ? 'Text is required' : null,
          ),
        ),
      ),
    );
  }

  /// Public-UX Phase 5 — placeholder driven by reply context, then
  /// intent selection, then a rotating discourse prompt.
  String _composerHint() {
    if (_isReply) return 'Add your response with care.';
    if (_intent != _ComposeIntent.none) return _intent.placeholder;
    final idx = _rotatingIdx % _kRotatingPrompts.length;
    return _kRotatingPrompts[idx.abs()];
  }

  Widget _buildCharacterLine() {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        '${_textController.text.trim().length}/$_limit',
        style: AuraText.small.copyWith(
          color: _textTooLong ? AuraSurface.coSun : AuraSurface.muted,
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
                      captionController: _ensureCaptionController(attachment),
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
                  style: AuraText.small.copyWith(color: AuraSurface.coSun),
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
                    style: AuraText.small.copyWith(color: AuraSurface.coSun),
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
      label: (_isReply || _isEditingPost) ? 'Save unavailable' : 'Save draft',
      onPressed:
          (_isReply ||
              _isEditingPost ||
              _posting ||
              _saving ||
              !_hasText ||
              _uploadingMedia)
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
                : (_isEditingPost
                      ? 'Saving…'
                      : (_publishingToTikTok
                            ? 'Queuing TikTok…'
                            : 'Publishing…')))
          : (_isReply
                ? 'Publish response'
                : (_isEditingPost ? 'Save changes' : 'Publish post')),
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
                    constraints: const BoxConstraints(
                      maxWidth: kWorkspaceWidth,
                    ),
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
        identity != null &&
            identity.id == institutionId &&
            identity.name.isNotEmpty
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

/// Public-UX Phase 5 — single intent chip for the composer.
class _IntentChip extends StatelessWidget {
  const _IntentChip({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final _ComposeIntent kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AuraRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s12,
          vertical: AuraSpace.s8,
        ),
        decoration: BoxDecoration(
          color: selected ? AuraSurface.accentSoft : AuraSurface.subtle,
          borderRadius: BorderRadius.circular(AuraRadius.pill),
          border: Border.all(
            color: selected
                ? AuraSurface.accent.withValues(alpha: 0.4)
                : AuraSurface.divider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              kind.icon,
              size: 13,
              color: selected ? AuraSurface.accentText : AuraSurface.muted,
            ),
            const SizedBox(width: 5),
            Text(
              kind.label,
              style: AuraText.small.copyWith(
                color: selected ? AuraSurface.accentText : AuraSurface.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
