import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../../core/attachments/aura_media_upload.dart';
import '../../../core/content_policy/content_length_policy.dart';
import '../../../core/errors/app_error_mapper.dart';
import '../../../core/tagging/governed_tag_field.dart';
import '../../../core/tagging/tag_entities.dart';
import '../../../core/tagging/tag_text_hydration.dart';
import '../../../core/compliance/objectionable_content.dart';
import '../../../core/institutions/institution_access_provider.dart';
import '../../../core/distribution/destination_capability.dart';
import '../../../core/link_preview/compose_link_detector.dart';
import '../../../core/media/local_video_source_stub.dart'
    if (dart.library.io) '../../../core/media/local_video_source_io.dart'
    if (dart.library.html) '../../../core/media/local_video_source_web.dart';
import '../../../core/link_preview/internal_reference_card.dart';
import '../../../core/rich_content/rich_paste_field.dart';
import '../../../core/link_preview/link_preview.dart';
import '../../../core/link_preview/link_preview_card.dart';
import '../../../core/link_preview/link_preview_service.dart';
import '../../../core/composition/composition_authority.dart';
import '../../../core/composition/content_intake.dart';
import '../../../core/media/attachment.dart';
import '../../../core/media/media_acquisition.dart';
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
import '../../feed/data/unified_feed_providers.dart';
import '../../institutions/posts/integrity/institution_post_integrity_review_sheet.dart';
import '../../institutions/announcements/integrity/announcement_integrity.dart';
import '../data/personal_post_integrity_repository.dart';
import '../../topics/aura_topic_selector.dart';
import '../../topics/topic.dart';
import '../../topics/topic_repository.dart';
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

  /// Communication Governance v1.0, Roadmap Milestone 5/8 — Continuation.
  /// When set, this new post carries a reference to the communication it
  /// evolves out of. The origin's own intent is never touched by this.
  final String? continuesPostId;

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
    this.continuesPostId,
  });

  @override
  ConsumerState<ComposeScreen> createState() => _ComposeScreenState();
}

/// Public-UX Phase 5 — discourse intent. Shapes placeholder, tone
/// hint, and the "intent" chip group. Backend doesn't know about
/// intent today — it's purely a UX-shaping signal.
enum _ComposeIntent { none, ask, raise, share }

/// Thrown when an institution-voice reply's Communication Integrity review
/// sheet is dismissed without publishing — signals the outer publish flow
/// to quietly reset (no error toast, no navigation) rather than reporting
/// a failure the user never actually hit.
class _ReplyReviewInterrupted implements Exception {}

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
  static const int _limit = ContentLengthPolicy.post;
  /// The shared ceiling, not a surface-local number.
  ///
  /// This was 5 here and unbounded elsewhere, so how many photographs a person
  /// could attach depended on which composer they happened to open. The limit
  /// is a product policy about compositions, not a property of posts.
  static const int _maxAttachments = kMaxComposableMedia;

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

  /// Communication Governance v1.0, Roadmap Milestone 6 — Enrichment panel
  /// (Topics/Media/Audience) is collapsed by default, showing a one-line
  /// summary; nothing about the sections themselves changes on expand.
  bool _enrichmentExpanded = false;

  /// Communication Governance v1.0, Roadmap Milestone 7 — Ambient
  /// Governance. Tracks the current draft's own post id (populated from
  /// the autosave response) so a Communication Integrity review can be
  /// requested against it — mirrors the institution composer's existing
  /// "create a real draft first, then review" sequencing.
  String? _draftPostId;
  bool _governanceExpanded = false;
  bool _governanceChecking = false;
  AnnouncementIntegrityAssessment? _governanceAssessment;
  AnnouncementIntegrityPendingAction? _governancePendingAction;
  bool _governanceAckAccepted = false;
  Timer? _governanceDebounce;

  PostVisibility _visibility = PostVisibility.public;

  /// Content Topics — human-selected Primary Topic (authoritative) + optional
  /// Secondary Topics (suggested, editable). Mirrors the institution composer
  /// so member posts carry the same LEFT-side feed-filter dimension. Sent on
  /// the draft payload and preserved through publish.
  AuraTopic? _primaryTopic;
  List<AuraTopic> _secondaryTopics = <AuraTopic>[];
  final List<TagReference> _selectedTagReferences = <TagReference>[];

  final List<Attachment> _attachments = [];

  // Compose Link Intelligence / OG Preview -- Phase 1. `_linkPreview` is
  // the current attached preview (or null); `_linkDetector` watches
  // `_textController` and resolves a pasted URL through the canonical
  // backend endpoint. Draft editing stays stable because the detector
  // clears `_linkPreview` itself the moment the URL leaves the text.
  LinkPreview? _linkPreview;
  ComposeLinkDetector? _linkDetector;

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

  DestinationCapability _tiktok = const DestinationCapability(
      id: 'tiktok', label: 'TikTok', state: DestinationState.temporarilyUnavailable);
  DestinationCapability _linkedin = const DestinationCapability(
      id: 'linkedin', label: 'LinkedIn', state: DestinationState.temporarilyUnavailable);

  bool _tiktokLoading = false;
  final bool _tiktokActionBusy = false;
  bool _publishToTikTok = false;
  bool _publishingToTikTok = false;

  bool _linkedinLoading = false;
  bool _publishToLinkedIn = false;

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

  /// The canonical composition. Built from live fields rather than stored, so
  /// it cannot drift from them.
  CompositionState get _composition => CompositionState(
        body: _textController.text,
        attachments: _attachments,
        maxLength: _limit,
        // A photograph with no caption is a real post. Requiring text was a
        // per-composer accident, not a rule — CompositionState still refuses a
        // composition that carries nothing at all.
        requiresBody: false,
        isSubmitting: _posting || _saving,
      );

  bool get _canPublish {
    // Readiness is the authority's answer. The guard that stood here asked
    // `a.uploading`, so a FAILED attachment read as finished: publish
    // proceeded and the mediaId filter below silently dropped it, and the post
    // went out without the image the person had attached to it.
    if (!_composition.canSubmit) return false;
    // A DESTINATION requirement, not a composition one: a post must be filed
    // under a topic. Replies inherit their parent's.
    if (!_isReply && _primaryTopic == null) return false;
    return true;
  }

  /// Why publishing is blocked, in the authority's words.
  String? get _publishBlockedReason {
    final reason = _composition.blockedReason;
    if (reason != null) return reason;
    if (!_isReply && _primaryTopic == null) return 'Choose a topic first.';
    return null;
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

  /// How big the picked file is, or null when the platform will not say.
  ///
  /// Null means UNKNOWN, and intake treats unknown as "do not judge on size"
  /// rather than as zero -- refusing a file because the platform declined to
  /// measure it would turn a missing fact into a rejection.
  Future<int?> _measureFileSize(XFile file) async {
    try {
      final length = await file.length();
      return length >= 0 ? length : null;
    } catch (_) {
      return null;
    }
  }

  /// WHAT A VIDEO IS, MEASURED BEFORE IT LEAVES THE DEVICE.
  ///
  /// THE MISSING PRODUCER (2026-08-29). `Attachment.durationMs`, `width` and
  /// `height` are read all over the product -- `aura_video_surface` renders a
  /// duration label, layouts size themselves from the aspect ratio, the upload
  /// sends all three -- and NOTHING EVER WROTE THEM FOR VIDEO. `_addPickedFile`
  /// populated dimensions only `if (type == AttachmentKind.image)`, and the
  /// upload then read them back as
  ///
  ///     width:    attachment.isImage ? attachment.width : null,
  ///     duration: attachment.isVideo ? attachment.durationMs : null,
  ///
  /// so every recorded video arrived at storage with no dimensions, no
  /// duration and nothing for a poster to be laid out against. The file was
  /// intact; the CONTENT IDENTITY was not. That is why a video that uploaded
  /// successfully still rendered as broken -- upload success was never content
  /// success.
  ///
  /// Measured locally rather than inferred later: the person is holding the
  /// device that just made this file, and the same facts recovered server-side
  /// after the fact would arrive too late to lay the composer out with.
  ///
  /// BEST EFFORT BY CONSTRUCTION. A platform without video playback support,
  /// a codec the decoder declines, a file the OS has already reclaimed -- none
  /// of those may cost the person their capture. Failure returns null and the
  /// attachment proceeds exactly as it does today, which is the current
  /// behaviour and therefore cannot regress it.
  Future<void> _probeVideoIdentity(Attachment attachment, XFile file) async {
    VideoPlayerController? controller;
    try {
      // The platform abstraction this codebase already uses for local video
      // (`aura_video_surface` resolves the same one). Reaching for `dart:io`
      // here would have compiled cleanly, passed analysis, and broken the WEB
      // build -- a platform the release must ship.
      controller = localVideoController(file.path);
      if (controller == null) return;
      await controller.initialize().timeout(const Duration(seconds: 8));
      final v = controller.value;
      final ms = v.duration.inMilliseconds;
      if (ms > 0) attachment.durationMs = ms;
      final size = v.size;
      if (size.width > 0 && size.height > 0) {
        // ROTATION IS PART OF THE SHAPE, NOT A DETAIL. A phone recording in
        // portrait reports a landscape natural size with a 90-degree rotation,
        // and laying it out from the raw numbers produces a sideways letterbox
        // in every feed it reaches.
        final quarterTurned = v.rotationCorrection == 90 || v.rotationCorrection == 270;
        attachment.width = (quarterTurned ? size.height : size.width).round();
        attachment.height = (quarterTurned ? size.width : size.height).round();
      }
    } catch (_) {
      // Unmeasurable is not unusable.
    } finally {
      await controller?.dispose();
    }
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

    _linkDetector = ComposeLinkDetector(
      controller: _textController,
      resolve: (url) => ref.read(linkPreviewServiceProvider).resolve(url),
      onPreviewChanged: (preview) {
        if (!mounted) return;
        setState(() => _linkPreview = preview);
        _scheduleAutosave();
      },
    );
  }

  @override
  void dispose() {
    _autosaveDebounce?.cancel();
    _governanceDebounce?.cancel();
    _linkDetector?.dispose();
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

    // RC4 x RC7 — the sign-in round trip must return to THIS composer, not to
    // a generic one. Without the context below, someone bounced to /login
    // while replying in an institution's voice came back to a blank personal
    // post: the draft body survived (it is the author's held draft) while
    // everything that made it that particular composition did not.
    if (_editPostId.isNotEmpty) {
      params['edit'] = _editPostId;
    }
    final replyToInstitutionPostId =
        (widget.replyToInstitutionPostId ?? '').trim();
    if (replyToInstitutionPostId.isNotEmpty) {
      params['replyToInstitutionPostId'] = replyToInstitutionPostId;
      final parentInstitutionId = (widget.parentInstitutionId ?? '').trim();
      if (parentInstitutionId.isNotEmpty) {
        params['parentInstitutionId'] = parentInstitutionId;
      }
    }
    final institutionId = (widget.institutionId ?? '').trim();
    if (widget.asInstitution && institutionId.isNotEmpty) {
      params['asInstitution'] = 'true';
      params['institutionId'] = institutionId;
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
      });
    }

    try {
      final dio = ref.read(dioProvider);

      final meRes = await dio.get('/users/me');
      final user = _unwrapUser(meRes.data);
      if (_str(user['id']).isEmpty) {
        throw Exception('User id is missing.');
      }

      // A PROBE REPORTS WHAT HAPPENED. IT DOES NOT ANSWER FOR THE PROVIDER.
      //
      // These used to go through `_safeGet`, which returns null on ANY failure
      // -- and null then became `connected = false`, which removed the
      // destination from the composer entirely. A dropped request, an expired
      // token, a 500 and a genuinely unconnected account were one answer, so
      // whether LinkedIn appeared depended on whether a transient GET
      // succeeded. That is the "does not feel deterministic" defect, exactly.
      final probes = await Future.wait<_ProviderProbe>([
        _probeProvider(dio, '/integrations/tiktok/account'),
        _probeProvider(dio, '/integrations/linkedin/account'),
      ]);

      final tiktokAccount = _unwrapTikTokAccount(probes[0].data);
      final linkedinAccount = _unwrapLinkedInAccount(probes[1].data);

      if (!mounted) return;

      setState(() {
        _tiktok = _resolveDestination(
          id: 'tiktok',
          label: 'TikTok',
          probe: probes[0],
          connected: _readTikTokConnected(tiktokAccount),
          accountLabel: _readTikTokAccountLabel(tiktokAccount),
          // TikTok publishes video. A composition without one cannot go there,
          // and saying so beats offering an action that will fail.
          contentSupported: _hasTikTokVideo,
          unsupportedDetail: 'TikTok needs a video in this post',
        );
        _linkedin = _resolveDestination(
          id: 'linkedin',
          label: 'LinkedIn',
          probe: probes[1],
          connected: _readLinkedInConnected(linkedinAccount),
          accountLabel: _readLinkedInAccountLabel(linkedinAccount),
        );
      });
    } catch (_) {
      // WE COULD NOT ASK. That is a state, not an error message -- and
      // certainly not `e.toString()` rendered at a person, which is what used
      // to appear here. Both destinations stay visible and say so.
      if (!mounted) return;
      setState(() {
        _tiktok = _tiktok.copyWith(state: DestinationState.temporarilyUnavailable);
        _linkedin = _linkedin.copyWith(state: DestinationState.temporarilyUnavailable);
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

  /// One provider read, with the FAILURE KEPT rather than discarded.
  Future<_ProviderProbe> _probeProvider(Dio dio, String path) async {
    try {
      final res = await dio.get(path);
      return _ProviderProbe(reachable: true, data: res.data);
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      // 401/403 mean the provider ANSWERED and refused this authorisation --
      // that is a reconnect, not an absence, and it is the case that used to
      // make a destination the person deliberately connected disappear.
      if (code == 401 || code == 403) {
        return const _ProviderProbe(reachable: true, authorisationValid: false);
      }
      // 404 is a real "no such connection".
      if (code == 404) return const _ProviderProbe(reachable: true);
      // Anything else -- offline, timeout, 5xx -- is us failing to ask.
      return const _ProviderProbe(reachable: false);
    } catch (_) {
      return const _ProviderProbe(reachable: false);
    }
  }

  DestinationCapability _resolveDestination({
    required String id,
    required String label,
    required _ProviderProbe probe,
    required bool connected,
    required String accountLabel,
    bool contentSupported = true,
    String? unsupportedDetail,
  }) {
    final state = destinationStateFromProbe(
      reachable: probe.reachable,
      // A refused authorisation still means an account IS connected; it is the
      // token that is stale. Treating it as unconnected is what erased it.
      connected: connected || !probe.authorisationValid,
      authorisationValid: probe.authorisationValid,
      contentSupported: contentSupported,
    );
    return DestinationCapability(
      id: id,
      label: label,
      state: state,
      accountLabel: accountLabel,
      detail: state == DestinationState.unsupportedContent
          ? unsupportedDetail
          : null,
    );
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

  /// A DESTINATION THAT CANNOT PUBLISH MUST NOT STAY SELECTED.
  ///
  /// This asked `_linkedinConnected`, a boolean that went false on any failed
  /// request -- so a network blip silently cleared a choice the person had
  /// deliberately made. The capability is the authority now: selection is
  /// dropped only when the destination genuinely cannot take this
  /// composition, and a destination that is merely unreachable keeps the
  /// person's intent while the switch itself stays disabled.
  void _syncExternalPublishingToggles() {
    _syncTikTokToggle();

    if (!_tiktok.isPublishable && _publishToTikTok) {
      _publishToTikTok = false;
    }
    if (!_linkedin.isPublishable && _publishToLinkedIn) {
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

      final tagRefs = _parseTagReferences(draft['tagReferences']);
      final hydrated = hydrateTextWithDisplayTags(text, tagRefs);

      // Compose Link Intelligence / OG Preview -- Phase 1. Hydrate
      // directly from the draft's own already-resolved fields rather than
      // waiting on a fresh resolve() round trip -- the preview appears
      // immediately on load, not after a debounce delay.
      final draftLinkUrl = _str(draft['linkUrl']);
      final draftLinkPreview = draftLinkUrl.isEmpty
          ? null
          : LinkPreview(
              eligible: true,
              internal: false,
              sourceUrl: draftLinkUrl,
              status: _str(draft['linkTitle']).isNotEmpty || _str(draft['linkImageUrl']).isNotEmpty
                  ? 'READY'
                  : 'PENDING',
              title: _str(draft['linkTitle']).isEmpty ? null : _str(draft['linkTitle']),
              description: _str(draft['linkDescription']).isEmpty ? null : _str(draft['linkDescription']),
              siteName: _str(draft['linkSiteName']).isEmpty ? null : _str(draft['linkSiteName']),
              imageUrl: _str(draft['linkImageUrl']).isEmpty ? null : _str(draft['linkImageUrl']),
            );

      // RC7 (compose half) — RESTORE THE DRAFT'S IDENTITY, NOT ONLY ITS
      // CONTENT.
      //
      // The post composer's lifecycle is deliberately unlike the article
      // editor's: `PUT /posts/draft` upserts the author's ONE held draft, so
      // a remount can never mint a duplicate and the route needs no id. What
      // the restore dropped was the identity of the draft it had just loaded
      // — `_draftPostId` stayed null after every refresh.
      //
      // Everything keyed to that id therefore reported a draft that plainly
      // existed as absent: the governance panel read "Not yet reviewed" for
      // work already assessed, and acknowledging a pending action silently
      // did nothing. This is the backend's own id, never a client-minted
      // stand-in.
      final restoredId = _str(draft['id']).trim();

      setState(() {
        if (restoredId.isNotEmpty) _draftPostId = restoredId;
        _textController.text = hydrated.text;
        _visibility = visibility;
        _primaryTopic = AuraTopic.fromWire(_str(draft['primaryTopic']));
        _secondaryTopics = AuraTopic.listFromWire(draft['secondaryTopics']);
        _selectedTagReferences
          ..clear()
          ..addAll(hydrated.references);
        _lastSavedAt = savedAt;
        _attachments
          ..clear()
          ..addAll(loadedAttachments);
        _linkPreview = draftLinkPreview;
        _syncExternalPublishingToggles();

        if (_hasText) {
          _showTextError = false;
        }
      });

      // With the draft's identity back, ambient governance can speak about
      // the real draft again instead of about nothing.
      if (restoredId.isNotEmpty) _scheduleGovernanceCheck();
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
      final tagRefs = _parseTagReferences(post['tagReferences']);
      final hydrated = hydrateTextWithDisplayTags(_str(post['text']), tagRefs);

      final postLinkUrl = _str(post['linkUrl']);
      final postLinkPreview = postLinkUrl.isEmpty
          ? null
          : LinkPreview(
              eligible: true,
              internal: false,
              sourceUrl: postLinkUrl,
              status: _str(post['linkTitle']).isNotEmpty || _str(post['linkImageUrl']).isNotEmpty
                  ? 'READY'
                  : 'PENDING',
              title: _str(post['linkTitle']).isEmpty ? null : _str(post['linkTitle']),
              description: _str(post['linkDescription']).isEmpty ? null : _str(post['linkDescription']),
              siteName: _str(post['linkSiteName']).isEmpty ? null : _str(post['linkSiteName']),
              imageUrl: _str(post['linkImageUrl']).isEmpty ? null : _str(post['linkImageUrl']),
            );

      setState(() {
        _textController.text = hydrated.text;
        _visibility = _visibilityFromApi(post['visibility']);
        _primaryTopic = AuraTopic.fromWire(_str(post['primaryTopic']));
        _secondaryTopics = AuraTopic.listFromWire(post['secondaryTopics']);
        _selectedTagReferences
          ..clear()
          ..addAll(hydrated.references);
        _lastSavedAt = null;
        _attachments
          ..clear()
          ..addAll(loadedAttachments);
        _linkPreview = postLinkPreview;
        if (_hasText) _showTextError = false;
      });
    } catch (e) {
      if (!mounted) return;
      final message = AppErrorMapper.from(e, feature: 'edit this').message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load post for editing: $message')),
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

  /// ONE SELECTION, images and videos together.
  ///
  /// This was `pickImage` — singular — so composing a post with four
  /// photographs meant four trips through the picker, and a post with photos
  /// AND a video meant using two different menu entries. Neither was a policy
  /// anyone chose; both are the shape the old single-select API left behind.
  Future<void> _pickMediaFromGallery() async {
    if (!_canAddMoreAttachments || _posting) return;

    final remaining = _maxAttachments - _attachments.length;
    final picked = await ImagePicker().pickMultipleMedia();
    if (picked.isEmpty) return;

    final admitted = picked.take(remaining).toList(growable: false);
    for (final file in admitted) {
      // Kind is inferred PER FILE, because one selection may legitimately
      // contain both. Branching on the menu entry instead — as the two
      // separate pickers did — cannot express a mixed choice at all.
      final isVideo = _looksLikeVideo(file.name, file.mimeType);
      await _addPickedFile(
        file,
        type: isVideo ? AttachmentKind.video : AttachmentKind.image,
        source: AttachmentSource.gallery,
      );
    }

    final message = acquisitionLimitMessage(picked.length - admitted.length);
    if (message != null && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  /// Kind from the platform's answer, falling back to the extension.
  ///
  /// The mime is preferred because it is evidence; the name is a last resort
  /// for platforms that decline to say. Content truth has the final word
  /// server-side, so a wrong guess here is corrected rather than believed.
  bool _looksLikeVideo(String name, String? mimeType) {
    final mime = (mimeType ?? '').toLowerCase();
    if (mime.startsWith('video/')) return true;
    if (mime.startsWith('image/')) return false;
    final lower = name.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m4v') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.3gp');
  }

  Future<void> _pickImageFromGallery() => _pickMediaFromGallery();

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

  /// Gallery video goes through the SAME selection as gallery photos.
  ///
  /// Keeping a separate singular video picker would re-create the split this
  /// pass removed: a person choosing a photo and a video would again have to
  /// use two menu entries to express one composition.
  Future<void> _pickVideoFromGallery() => _pickMediaFromGallery();

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

    // ONE governed door. `kind` used to be whatever the CALLER declared, and
    // the mime was not resolved here at all — `_uploadAttachment` inferred it
    // later and fell back to `application/octet-stream`, which the server's
    // allow-list refuses at presign. The attachment appeared in the composer,
    // climbed, and failed late.
    // SIZE IS PART OF THE DOOR, AND IT WAS BEING SKIPPED.
    //
    // `resolveFile` refuses an empty file and an oversized one -- but both
    // checks are guarded by `sizeBytes != null`, and this call never passed
    // it. So a zero-byte capture (a cancelled recording, a camera that failed
    // after creating its file, an OS that reclaimed the temp file early)
    // sailed through intake, appeared in the composition, uploaded, and failed
    // somewhere further down where the person could no longer tell what went
    // wrong. The same silence covered files past the size ceiling.
    final int? sizeBytes = await _measureFileSize(file);
    final resolution = ContentIntake.resolveFile(
      path: IntakePath.picker,
      file: file,
      sizeBytes: sizeBytes,
      source: source,
    );
    final attachment = resolution.attachment;
    if (attachment == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(resolution.rejectionMessage!)),
      );
      return;
    }
    // The picker promised a kind; the content decides whether it kept the
    // promise. Uploading a document through the Video button is a refusal, not
    // a reclassification.
    if (attachment.kind != type) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            type == AttachmentKind.video
                ? 'That is not a video file.'
                : 'That is not an image file.',
          ),
        ),
      );
      return;
    }

    if (type == AttachmentKind.image) {
      final bytes = await file.readAsBytes();
      attachment.bytes = bytes;
      try {
        final size = await _decodeImageSize(bytes);
        attachment.width = size?['width'];
        attachment.height = size?['height'];
      } catch (_) {}
    } else if (type == AttachmentKind.video) {
      // A recorded video is measured here for the same reason a photograph is
      // decoded here: so the composition knows what it is holding before it
      // asks anyone else.
      await _probeVideoIdentity(attachment, file);
    }
    attachment.uploading = true;
    attachment.attachedToDraft = false;

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
      final message = AppErrorMapper.from(e, feature: 'upload this').message;
      setState(() {
        attachment.error = message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not upload attachment: $message')),
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

    // Resolved at intake. The `?? 'application/octet-stream'` that used to
    // stand here turned a legitimate DOCX into a generic binary the server
    // refuses, and did it AFTER the person had seen the file attached.
    final mime = attachment.mimeType!;
    final captionText = _captionText(attachment);
    final result = await uploadAuraMedia(
      dio: ref.read(dioProvider),
      bytes: await file.readAsBytes(),
      fileName: file.name,
      mimeType: mime,
      originalMimeType: attachment.originalMimeType,
      kind: wireKind(attachment.kind),
      source: wireSource(attachment.source),
      // NOT `isImage ? … : null`. Dimensions were nulled for video because
      // nothing measured them; measuring them and then discarding them at the
      // door would be the same defect wearing a different hat.
      width: attachment.width,
      height: attachment.height,
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
      'tagReferences': _currentMentionPayload(),
      'mentions': _currentMentionPayload(),
      // Public-record routing — intent tells the backend which accountability
      // route to attempt when PUBLIC_RECORD_ROUTING_ENABLED is on.
      // Null/absent means no routing is attempted.
      if (intentWire != null) 'intent': intentWire,
      // Communication Governance v1.0, Milestone 5/8 — Continuation. Only
      // honored by the backend on initial creation of this draft; harmless
      // to resend on later autosaves since the backend ignores it then.
      if ((widget.continuesPostId ?? '').trim().isNotEmpty)
        'continuesPostId': widget.continuesPostId!.trim(),
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
      // Compose Link Intelligence / OG Preview -- Phase 1. Always resent
      // (like primaryTopic/tagReferences above) so removing the URL from
      // the text clears the association on the next autosave, not just
      // locally. `linkPreviewId` is null for an internal/ineligible/absent
      // link -- only `linkSourceUrl` is kept in that case, so an internal
      // Aura link or an unresolvable-but-typed URL still renders as a
      // plain link rather than being silently dropped.
      'linkPreviewId': (_linkPreview?.eligible ?? false) ? _linkPreview!.linkPreviewId : null,
      'linkSourceUrl': (_linkPreview?.eligible ?? false) ? _linkPreview!.sourceUrl : null,
    };
  }

  void _rememberSelectedTag(TagReference reference) {
    if (!reference.isMention) return;
    final id = reference.canonicalId.trim();
    final inserted = reference.insertText.trim();
    if (id.isEmpty || inserted.isEmpty) return;
    _selectedTagReferences.removeWhere(
      (existing) =>
          existing.kind == reference.kind && existing.canonicalId == id,
    );
    _selectedTagReferences.add(reference);
  }

  List<Map<String, dynamic>> _currentMentionPayload() {
    final text = _textController.text;
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];
    for (final reference in _selectedTagReferences) {
      if (!reference.isMention) continue;
      if (!text.contains(reference.insertText)) continue;
      final key = '${reference.kind.name}:${reference.canonicalId}';
      if (!seen.add(key)) continue;
      out.add(reference.toJson());
    }
    return out;
  }

  List<TagReference> _parseTagReferences(Object? raw) {
    if (raw is! List) return const <TagReference>[];
    final out = <TagReference>[];
    for (final item in raw) {
      if (item is Map) {
        out.add(TagReference.fromJson(Map<String, dynamic>.from(item)));
      }
    }
    return out;
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

      final res = await dio.put('/posts/draft', data: payload);

      if (!mounted) return;
      final savedId = _extractPublishedPostId(res.data);
      setState(() {
        _lastSavedAt = DateTime.now();
        if ((savedId ?? '').trim().isNotEmpty) {
          _draftPostId = savedId;
        }
        for (final attachment in _attachments) {
          if ((attachment.mediaId ?? '').trim().isNotEmpty) {
            attachment.attachedToDraft = true;
          }
        }
      });
      // Communication Governance v1.0, Roadmap Milestone 7 — a draft now
      // exists (or was updated); check ambient governance against it,
      // debounced the same way autosave is so typing doesn't spam reviews.
      _scheduleGovernanceCheck();
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        final message = AppErrorMapper.from(e, feature: 'save this').message;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not hold this work: $message')),
        );
      }
      rethrow;
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  // ── Communication Governance v1.0, Roadmap Milestone 7 — Ambient Governance ──
  //
  // Personal posts previously had no client-side integrity surfacing at
  // all: `PersonalPostIntegrityGateway` already ran silently on the
  // backend at publish time, and a REQUIRE_ACKNOWLEDGEMENT decision simply
  // surfaced as a raw, un-actionable error. This makes the same,
  // already-real backend capability visible ambiently — a standing status,
  // not a blocking modal — and gives the author an actual way to satisfy
  // it, mirroring the institution composer's review flow.

  void _scheduleGovernanceCheck() {
    if (_isReply) return;
    final postId = (_draftPostId ?? '').trim();
    if (postId.isEmpty) return;

    _governanceDebounce?.cancel();
    _governanceDebounce = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      _runGovernanceReview(postId);
    });
  }

  Future<void> _runGovernanceReview(String postId) async {
    if (_governanceChecking) return;
    setState(() => _governanceChecking = true);
    try {
      final repo = PersonalPostIntegrityRepository(ref.read(dioProvider));
      final result = await repo.requestReview(postId);
      if (!mounted) return;
      setState(() {
        _governanceAssessment = result.assessment;
        _governancePendingAction = result.pendingAction;
        _governanceAckAccepted = result.pendingAction.satisfied;
        // Auto-expand only when there's something the author needs to act
        // on — a clear result stays collapsed to a one-line status.
        if (!result.pendingAction.clearsPublish) {
          _governanceExpanded = true;
        }
      });
    } catch (_) {
      // Best-effort ambient check — publish still re-validates server-side
      // regardless, so a failed background check here is not fatal.
    } finally {
      if (mounted) setState(() => _governanceChecking = false);
    }
  }

  Future<bool> _acknowledgeGovernance() async {
    final postId = (_draftPostId ?? '').trim();
    final pending = _governancePendingAction;
    if (postId.isEmpty || pending == null) return false;

    setState(() => _governanceChecking = true);
    try {
      final repo = PersonalPostIntegrityRepository(ref.read(dioProvider));
      final updated = await repo.acknowledge(postId: postId, decisionId: pending.decisionId);
      if (!mounted) return false;
      setState(() {
        _governancePendingAction = updated;
        _governanceAckAccepted = updated.satisfied;
      });
      return updated.satisfied;
    } catch (e) {
      if (!mounted) return false;
      final message = AppErrorMapper.from(e, feature: 'record this acknowledgment').message;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      return false;
    } finally {
      if (mounted) setState(() => _governanceChecking = false);
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
          if (_linkPreview != null && _linkPreview!.eligible) ...[
            const SizedBox(height: AuraSpace.s10),
            if (_linkPreview!.internal)
              InternalReferenceCard(
                sourceUrl: _linkPreview!.sourceUrl,
                reference: _linkPreview!.internalReference,
                dense: true,
                onRemove: () {
                  setState(() => _linkPreview = null);
                  _scheduleAutosave();
                },
              )
            else
              LinkPreviewCard(
                url: _linkPreview!.sourceUrl,
                title: _linkPreview!.title,
                description: _linkPreview!.description,
                siteName: _linkPreview!.siteName,
                imageUrl: _linkPreview!.imageUrl,
                dense: true,
                onRemove: () {
                  setState(() => _linkPreview = null);
                  _scheduleAutosave();
                },
              ),
          ],
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
            _buildEnrichmentPanel(),
            const SizedBox(height: AuraSpace.s16),
            const Divider(color: AuraSurface.divider),
            const SizedBox(height: AuraSpace.s16),
            _buildGovernancePanel(),
          ],
        ],
      ),
    );
  }

  /// Communication Governance v1.0, Roadmap Milestone 7 — Governance
  /// becomes a visible, standing panel instead of a surprise blocking
  /// modal. Collapsed to a one-line status when clear; auto-expands the
  /// moment there's something the author needs to see, per the frozen
  /// UX Proposal's exact framing.
  Widget _buildGovernancePanel() {
    final pending = _governancePendingAction;
    final assessment = _governanceAssessment;

    String statusLine;
    IconData statusIcon;
    Color statusColor;
    if (_draftPostId == null) {
      statusLine = 'Not yet reviewed';
      statusIcon = Icons.hourglass_top_rounded;
      statusColor = AuraSurface.muted;
    } else if (_governanceChecking && assessment == null) {
      statusLine = 'Checking…';
      statusIcon = Icons.hourglass_top_rounded;
      statusColor = AuraSurface.muted;
    } else if (pending == null || pending.clearsPublish) {
      statusLine = 'Looks clear';
      statusIcon = Icons.check_circle_outline;
      statusColor = AuraSurface.coVerdant;
    } else {
      statusLine = 'Needs your acknowledgment';
      statusIcon = Icons.warning_amber_rounded;
      statusColor = AuraSurface.coSun;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(AuraRadius.md),
          onTap: () => setState(() => _governanceExpanded = !_governanceExpanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AuraSpace.s4),
            child: Row(
              children: [
                Icon(
                  _governanceExpanded
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.keyboard_arrow_right_rounded,
                  size: 20,
                  color: AuraSurface.muted,
                ),
                const SizedBox(width: AuraSpace.s6),
                Text(
                  'Governance',
                  style: AuraText.small.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AuraSurface.muted,
                  ),
                ),
                const SizedBox(width: AuraSpace.s10),
                Icon(statusIcon, size: 14, color: statusColor),
                const SizedBox(width: 4),
                Text(
                  statusLine,
                  style: AuraText.small.copyWith(fontWeight: FontWeight.w700, color: statusColor),
                ),
              ],
            ),
          ),
        ),
        if (_governanceExpanded && assessment != null && pending != null) ...[
          const SizedBox(height: AuraSpace.s10),
          Container(
            padding: const EdgeInsets.all(AuraSpace.s12),
            decoration: BoxDecoration(
              color: AuraSurface.subtle,
              borderRadius: BorderRadius.circular(AuraRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(assessment.statusLabel, style: AuraText.small.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: AuraSpace.s4),
                Text(assessment.summaryExplanation, style: AuraText.small),
              ],
            ),
          ),
          if (!pending.clearsPublish) ...[
            const SizedBox(height: AuraSpace.s10),
            Text(pending.reason, style: AuraText.small.copyWith(color: AuraSurface.muted)),
            const SizedBox(height: AuraSpace.s10),
            CheckboxListTile(
              value: _governanceAckAccepted,
              onChanged: _governanceChecking
                  ? null
                  : (v) => setState(() => _governanceAckAccepted = v == true),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              activeColor: AuraSurface.accent,
              title: Text(
                'I acknowledge this and accept responsibility for publishing it.',
                style: AuraText.small.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            AuraSecondaryButton(
              label: _governanceChecking ? 'Recording…' : 'Acknowledge',
              onPressed: (_governanceChecking || !_governanceAckAccepted)
                  ? null
                  : () => _acknowledgeGovernance(),
            ),
          ],
        ],
      ],
    );
  }

  /// Communication Governance v1.0, Roadmap Milestone 6 — Enrichment
  /// (Topics · Media · Audience). Collapsed by default with a one-line
  /// summary; expanding reveals the exact same Audience/Attachments/Topics
  /// widgets that were always here — this is pure re-parenting and
  /// collapse/expand behavior, not a rewrite of what any section does.
  Widget _buildEnrichmentPanel() {
    final topicSummary = _primaryTopic == null
        ? 'None'
        : (_secondaryTopics.isEmpty
              ? _primaryTopic!.label
              : '${_primaryTopic!.label} · +${_secondaryTopics.length} secondary');
    final mediaSummary = _attachments.isEmpty
        ? 'None'
        : '${_attachments.length} attachment${_attachments.length == 1 ? '' : 's'}';
    final audienceSummary = _visibilityLabel(_visibility);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(AuraRadius.md),
          onTap: () => setState(() => _enrichmentExpanded = !_enrichmentExpanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AuraSpace.s4),
            child: Row(
              children: [
                Icon(
                  _enrichmentExpanded
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.keyboard_arrow_right_rounded,
                  size: 20,
                  color: AuraSurface.muted,
                ),
                const SizedBox(width: AuraSpace.s6),
                Text(
                  'Enrichment',
                  style: AuraText.small.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AuraSurface.muted,
                  ),
                ),
                const SizedBox(width: AuraSpace.s10),
                if (!_enrichmentExpanded)
                  Expanded(
                    child: Text(
                      'Topics: $topicSummary · Media: $mediaSummary · Audience: $audienceSummary',
                      style: AuraText.small.copyWith(color: AuraSurface.muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_enrichmentExpanded) ...[
          const SizedBox(height: AuraSpace.s12),
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
            // AuraTopicSelector itself now handles dropping any secondary
            // that is no longer approved under a new primary (relationship
            // gate, not just an equals-primary check) and calls
            // onSecondariesChanged accordingly — no extra pruning needed here.
            onPrimaryChanged: (t) {
              setState(() => _primaryTopic = t);
              _scheduleAutosave();
            },
            onSecondariesChanged: (list) {
              setState(() => _secondaryTopics = list);
              _scheduleAutosave();
            },
            fetchApprovedSecondaries: (primary) =>
                ref.read(topicRepositoryProvider).approvedSecondaries(primary),
            fetchSuggestions: (primary, text) =>
                ref.read(topicRepositoryProvider).suggestSecondary(primary, text),
          ),
        ],
      ],
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

  Future<String?> _publishReplyNow() async {
    final dio = ref.read(dioProvider);
    final text = _textController.text.trim();
    final instId = (widget.institutionId ?? '').trim();

    // Branch on the reply target: regular post vs institution post live in
    // different tables and behind different endpoints.
    if (_isInstitutionPostReply) {
      final asInstitution = widget.asInstitution && instId.isNotEmpty;
      // Domain 9 — previously omitted entirely, so a picker-selected
      // mention in a reply persisted nothing and notified nobody. Same
      // state/shape the top-level post publish payload already sends.
      final body = <String, dynamic>{
        'body': text,
        'tagReferences': _currentMentionPayload(),
        'mentions': _currentMentionPayload(),
      };
      if (asInstitution) {
        body['asInstitution'] = true;
        body['actorInstitutionId'] = instId;
      }
      final res = await dio.post(
        '/institutions/$_parentInstitutionId/posts/$_replyToInstitutionPostId/replies',
        data: body,
      );

      // Ordinary member replies publish immediately — nothing further to do.
      if (!asInstitution) return null;

      // Institution-voice replies are created as a DRAFT pending
      // Communication Integrity review (2026-08-04 correction — this used
      // to attempt create+authorize in one step and surface a raw
      // "REQUIRE_ACKNOWLEDGEMENT" backend error with no way to act on it).
      // Route through the same review-then-publish sheet the top-level
      // institution post composer already uses: a CLEAR assessment
      // publishes immediately, a flagged one gets real acknowledgment UI.
      final root = _asMap(res.data);
      final replyId = _str(_asMap(root['post'])['id']);
      if (replyId.isEmpty) {
        throw Exception('Reply was created but its id was not returned.');
      }
      if (!mounted) throw _ReplyReviewInterrupted();

      final published = await showInstitutionPostIntegrityReviewSheet(
        context: context,
        ref: ref,
        institutionId: _parentInstitutionId,
        postId: replyId,
      );
      if (published != true) throw _ReplyReviewInterrupted();
      return null;
    }

    if (_replyToPostId.isEmpty) {
      throw Exception('Reply target missing.');
    }

    // Domain 9 — previously omitted entirely, so a picker-selected
    // mention in a reply persisted nothing and notified nobody.
    final body = <String, dynamic>{
      'text': text,
      'tagReferences': _currentMentionPayload(),
      'mentions': _currentMentionPayload(),
    };
    if (widget.asInstitution && instId.isNotEmpty) {
      body['asInstitution'] = true;
      body['institutionId'] = instId;
    }
    await dio.post('/posts/$_replyToPostId/reply', data: body);
    return null;
  }

  Future<String?> _publishPostNow() async {
    final dio = ref.read(dioProvider);
    final res = await dio.post(
      '/posts/draft/publish',
      data: _buildComposePayload(),
    );
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

    final payload = {
      'postId': postId,
      'commentary': _textController.text.trim(),
    };

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
      // ONE AUTHORITY AT THE ACTION TOO. A disabled-looking destination must
      // not be able to reach the legacy publishing path behind the UI.
      if (!_tiktok.isPublishable) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_tiktok.label}: ${_tiktok.statusLine}')),
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

    // Communication Governance v1.0, Roadmap Milestone 7 — if the ambient
    // check already found something requiring acknowledgment, surface the
    // panel instead of letting the raw backend rejection through.
    final pendingGovernance = _governancePendingAction;
    if (!_isReply &&
        pendingGovernance != null &&
        !pendingGovernance.clearsPublish &&
        !_governanceAckAccepted) {
      setState(() => _governanceExpanded = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review the Governance panel before publishing.')),
      );
      return;
    }
    if (!_isReply &&
        pendingGovernance != null &&
        !pendingGovernance.clearsPublish &&
        _governanceAckAccepted) {
      final satisfied = await _acknowledgeGovernance();
      if (!satisfied) return;
    }

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
            failedTargets.add('TikTok (${AppErrorMapper.from(e).message})');
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
            failedTargets.add('LinkedIn (${AppErrorMapper.from(e).message})');
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
          router.go('/messages');
        } else if ((publishedPostId ?? '').trim().isNotEmpty) {
          router.go('/posts/${publishedPostId!.trim()}');
        } else {
          router.go('/home');
        }
      }
    } catch (e) {
      if (!mounted) return;

      // The reply draft was created (and, if Communication Integrity had no
      // findings, may already be published) — the user just didn't
      // complete the review sheet. Nothing went wrong; say nothing.
      if (e is _ReplyReviewInterrupted) return;

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

      final appError = AppErrorMapper.from(e, feature: 'publish this');
      final detail = appError.hasIssues
          ? '${appError.message} (${appError.issues!.join('; ')})'
          : appError.message;

      final message =
          publishedPostId != null && publishedPostId.trim().isNotEmpty
          ? 'Published to Aura, but the screen could not finish cleanly: $detail'
          : detail;

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
                const Text('Add to this post', style: AuraText.title),
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
                if (_supportsCameraCapture) ...[
                  const SizedBox(height: AuraSpace.s10),
                  ComposeAttachmentActionButton(
                    icon: Icons.videocam_outlined,
                    label: 'Record video',
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      await _pickVideoFromCamera();
                    },
                  ),
                ],
                const SizedBox(height: AuraSpace.s10),
                // ONE ENTRY, BECAUSE IT IS ONE ACTION. "Choose photo" and
                // "Choose video" both ran `_pickMediaFromGallery`, and the
                // picker returns photographs and videos in a single
                // selection -- so the split existed only in the menu, and it
                // made a person choose a category before choosing content.
                ComposeAttachmentActionButton(
                  icon: Icons.photo_library_outlined,
                  label: 'Choose photo or video',
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _pickMediaFromGallery();
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
                    // RETIRED 2026-08-25 - duplicated the governed return control. The
                    // comment that stood here named the real problem exactly ("reached via
                    // context.go from the Create hub has no back-stack") and answered it
                    // with a hardcoded /home. ReturnPathAuthority answers the same question
                    // from the destination, and presents it once.
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
              // RETIRED 2026-08-25 - duplicated the governed return control. The
              // comment that stood here named the real problem exactly ("reached via
              // context.go from the Create hub has no back-stack") and answered it
              // with a hardcoded /home. ReturnPathAuthority answers the same question
              // from the destination, and presents it once.
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
      // Item 15 — Rich Paste, wraps GovernedTagAutocomplete (which wraps
      // the TextField) so pasted rich clipboard content converts into
      // Aura's canonical Markdown before the tag-autocomplete layer ever
      // sees the resulting text.
      child: RichPasteField(
        controller: _textController,
        // AXR-1 — governed @member/@institution/#topic autocomplete.
        child: GovernedTagAutocomplete(
          controller: _textController,
          focusNode: _textFocus,
          onTagSelected: _rememberSelectedTag,
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
        // CAPTURE IS NOT AN ATTACHMENT MENU ITEM.
        //
        // The path to a photograph used to be: Compose -> "Add attachment" ->
        // sheet -> "Take photo" -> camera. Three taps and two doors to do the
        // thing people open a composer to do. The sheet also offered "Choose
        // photo" and "Choose video" as separate entries when
        // `_pickVideoFromGallery` is literally `=> _pickMediaFromGallery()` --
        // one behaviour wearing two labels, in a picker that already returns
        // photographs and videos together.
        //
        // Where a camera exists, taking a photo and recording a video are the
        // two things a person came to do, so they are one tap. Everything else
        // stays behind "More", which is where a file type nobody has in mind
        // belongs.
        Wrap(
          spacing: AuraSpace.s10,
          runSpacing: AuraSpace.s10,
          children: [
            if (_supportsCameraCapture) ...[
              AuraSecondaryButton(
                label: 'Photo',
                icon: Icons.camera_alt_outlined,
                onPressed: (_posting || !_canAddMoreAttachments)
                    ? null
                    : _pickImageFromCamera,
              ),
              AuraSecondaryButton(
                label: 'Video',
                icon: Icons.videocam_outlined,
                onPressed: (_posting || !_canAddMoreAttachments)
                    ? null
                    : _pickVideoFromCamera,
              ),
            ],
            AuraSecondaryButton(
              label: _supportsCameraCapture ? 'Library' : 'Add media',
              icon: Icons.photo_library_outlined,
              onPressed: (_posting || !_canAddMoreAttachments)
                  ? null
                  : _pickMediaFromGallery,
            ),
            AuraSecondaryButton(
              label: 'More',
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

  /// ONE ROW, DRIVEN BY THE CAPABILITY, FOR EVERY DESTINATION.
  ///
  /// THE MODEL THIS REPLACES. Each provider had its own ~90 lines deciding
  /// visibility, subtitle and enablement from its own booleans, and the two
  /// did not agree:
  ///
  ///     final linkedinVisible = _linkedinLoading || _linkedinConnected;
  ///     // TikTok had no visibility guard at all
  ///
  /// So TikTok always appeared and LinkedIn disappeared whenever `connected`
  /// went false -- which, since `connected` came from a swallowed error, meant
  /// whenever a GET failed. That asymmetry is precisely what "sometimes TikTok
  /// appears; LinkedIn can disappear entirely" describes.
  ///
  /// The subtitle also rendered `_linkedinError`, which was `e.toString()` --
  /// a raw exception where a sentence belongs.
  ///
  /// Presentation now reads the capability and nothing else. A destination
  /// disappears for exactly one reason: it is `notOffered`.
  Widget _buildDestinationRow({
    required DestinationCapability cap,
    required IconData icon,
    required bool selected,
    required ValueChanged<bool> onChanged,
  }) {
    if (!cap.isVisible) return const SizedBox.shrink();

    final busy = cap.id == 'tiktok'
        ? (_tiktokLoading || _tiktokActionBusy)
        : _linkedinLoading;
    final canPublishHere = cap.isPublishable && !_posting;

    Widget trailing;
    if (busy) {
      trailing = const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (cap.hasRecoveryAction) {
      // THE CASE THE OLD MODEL HANDLED WORST. An expired authorisation used to
      // erase the destination; the person had done nothing wrong and was given
      // nothing to do. The action is the whole point of distinguishing this
      // state, so it is what occupies the control.
      trailing = TextButton(
        onPressed: _posting ? null : () => _openDestinationSettings(cap),
        child: Text(cap.actionLabel!),
      );
    } else if (cap.state == DestinationState.temporarilyUnavailable) {
      trailing = TextButton(
        onPressed: _posting ? null : _loadExternalConnections,
        child: Text(cap.actionLabel!),
      );
    } else {
      trailing = Switch(
        value: selected && canPublishHere,
        onChanged: canPublishHere ? onChanged : null,
      );
    }

    return Row(
      children: [
        Icon(icon, size: 18, color: AuraSurface.ink),
        const SizedBox(width: AuraSpace.s10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                cap.label,
                style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                busy ? 'Checking connection…' : cap.statusLine,
                style: AuraText.small.copyWith(color: AuraSurface.muted),
              ),
            ],
          ),
        ),
        trailing,
      ],
    );
  }

  /// Where a person goes to connect or reconnect a destination.
  ///
  /// Deliberately not an in-composer OAuth flow: the composition is the thing
  /// being protected, and sending someone through an external authorisation
  /// mid-draft is how drafts get lost.
  void _openDestinationSettings(DestinationCapability cap) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          cap.state == DestinationState.reconnectRequired
              ? '${cap.label} needs signing in again — open Me › Connected accounts.'
              : 'Connect ${cap.label} from Me › Connected accounts.',
        ),
      ),
    );
  }

  Widget _buildExternalPublishingBlock() {
    if (_isReply) return const SizedBox.shrink();
    if (!_tiktok.isVisible && !_linkedin.isVisible) {
      return const SizedBox.shrink();
    }

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
              _buildDestinationRow(
                cap: _tiktok,
                icon: Icons.music_note_outlined,
                selected: _publishToTikTok,
                onChanged: (v) => setState(() => _publishToTikTok = v),
              ),
              if (_tiktok.isVisible && _linkedin.isVisible) ...[
                const SizedBox(height: AuraSpace.s12),
                Container(height: 1, color: AuraSurface.divider),
                const SizedBox(height: AuraSpace.s12),
              ],
              _buildDestinationRow(
                cap: _linkedin,
                icon: Icons.business_center_outlined,
                selected: _publishToLinkedIn,
                onChanged: (v) => setState(() => _publishToLinkedIn = v),
              ),
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

    // A disabled control that will not say why is a dead end. The reason comes
    // from the authority where it owns the answer, and from this surface where
    // the requirement is the destination's.
    final publishBtn = Tooltip(
      message: _publishBlockedReason ?? '',
      child: AuraPrimaryButton(
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
              if (!_hasText && _composition.composableAttachments.isEmpty) {
                setState(() => _showTextError = true);
                return;
              }
              _publish();
            },
    ));

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

/// What one provider read actually reported.
///
/// Deliberately not a bool: the difference between "the provider said no" and
/// "we could not reach the provider" is the whole defect this replaces.
class _ProviderProbe {
  const _ProviderProbe({
    required this.reachable,
    this.authorisationValid = true,
    this.data,
  });

  /// Did we get an answer at all?
  final bool reachable;

  /// Did the provider refuse this authorisation (401/403)?
  final bool authorisationValid;

  final dynamic data;
}
