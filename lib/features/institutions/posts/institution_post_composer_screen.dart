import 'dart:async';
import '../kind/kind_composition.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/attachments/aura_media_upload.dart';
import '../../../core/eligibility/eligibility_affordance.dart';
import '../../../core/eligibility/eligibility_refusal.dart';
import '../../../core/errors/app_error_mapper.dart';
import '../../../core/tagging/governed_tag_field.dart';
import '../../../core/tagging/tag_entities.dart';
import '../../../core/tagging/tag_text_hydration.dart';
import '../../../core/auth/session_providers.dart';
import '../../../core/media/attachment.dart';
import '../../../core/media/aura_composition_strip.dart';
import '../../../core/media/media_acquisition.dart';
import '../../../core/institutions/institution_access_provider.dart';
import '../../../core/link_preview/compose_link_detector.dart';
import '../../../core/link_preview/internal_reference_card.dart';
import '../../../core/link_preview/link_preview.dart';
import '../../../core/link_preview/link_preview_card.dart';
import '../../../core/link_preview/link_preview_service.dart';
import '../../../core/net/dio_provider.dart';
import '../../../core/rich_content/rich_paste_field.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/authority/acting_attribution.dart';
import '../../../core/authority/authority_providers.dart';
import '../../../core/authority/capability_projection.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../feed/data/unified_feed_providers.dart';
import '../../topics/aura_topic_selector.dart';
import '../../topics/topic.dart';
import '../../topics/topic_repository.dart';
import '../data/institution_draft_store.dart';
import '../../../core/composition/composition_authority.dart';
import '../../../core/composition/content_intake.dart';
import '../data/institutions_repository.dart';
import '../domain/communication_type.dart';
import '../verification/presentation/speaking_authority_notice.dart';
import '../domain/institution_post.dart';
import 'integrity/institution_post_integrity_review_sheet.dart';
import '../../monetization/domain/monetization_refusal_copy.dart';
import '../../composition/domain/composition_models.dart';
import '../../composition/presentation/composition_assist.dart';
import '../../../core/product/temporal.dart';
import '../../../core/institutions/institution_paths.dart';
import '../workspace/workspace_page.dart';

/// Composer for [InstitutionPost]s in create mode.
///
/// Behaviour by role:
///   * EDITOR — single CTA "Submit for review" (DRAFT -> PENDING_APPROVAL).
///   * OWNER / ADMIN — split control: Save draft / Publish now.
///
/// The composer is **scope-aware**: when launched from the Public / Member /
/// Internal tab of Explore, the active tab is passed via `?scope=` and
/// becomes the default visibility for the new post. Distribution is gated
/// to the public scope (the only scope where global feed eligibility is
/// meaningful — the backend rejects other combinations).
///
/// Media is uploaded via the existing presign flow (`uploadAuraMedia`); the
/// previous URL-input field has been replaced with a real picker + bounded
/// preview that mirrors the institution profile logo upload widget.
class InstitutionPostComposerScreen extends ConsumerStatefulWidget {
  const InstitutionPostComposerScreen({
    super.key,
    required this.institutionId,
    this.postId,
    this.initial,
    this.defaultScope,
  });

  final String institutionId;
  final String? postId;
  final InstitutionPost? initial;

  /// 'public' | 'member' | 'internal' — passed by the Explore tab so the
  /// composer opens with the right visibility preselected.
  final String? defaultScope;

  bool get isEditing => postId != null && postId!.isNotEmpty;

  @override
  ConsumerState<InstitutionPostComposerScreen> createState() =>
      _InstitutionPostComposerScreenState();
}

class _InstitutionPostComposerScreenState
    extends ConsumerState<InstitutionPostComposerScreen> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  // AXR-1 — explicit focus node for governed tag autocomplete on the body.
  final _bodyFocus = FocusNode();

  late InstitutionPostVisibility _visibility;
  InstitutionPostDistribution _distribution =
      InstitutionPostDistribution.institutionOnly;

  /// Frontend-only institutional type. Encoded into the stored `title` via
  /// `[OFFICIAL:TYPE]` marker because the backend post DTO does not carry a
  /// metadata field. Default is "Update".
  InsCommunicationType _communicationType = InsCommunicationType.update;

  // Single-attachment state. The backend `InstitutionPost` schema accepts one
  // `mediaUrl`; the composer surfaces a real upload widget but persists only
  // the URL of the first uploaded asset. Multi-asset support is a separate
  // backend contract change (flagged below).
  String? _mediaUrl;

  /// The server's identity for the uploaded media.
  ///
  /// This used to be DISCARDED — only `result.url` was kept — which is half of
  /// why the draft could not hold a governed claim on its own cover.
  /// THE ORDERED MEDIA COLLECTION — the authority for this composition.
  ///
  /// `InstitutionPostMedia` has always carried `position`; only the create
  /// contract was single-media, so this screen held one `_mediaId` and one
  /// `_mediaUrl`. Both remain below, derived from the first item, purely so
  /// draft persistence and restore keep working — they are TRANSITIONAL and
  /// are never read as the authority.
  final List<Attachment> _media = [];

  /// Refusals and cancellations, held beside the items rather than on them:
  /// a refusal is a judgement about intake and the attachment is evidence, so
  /// merging them would let a later mutation erase the judgement.
  CompositionState _mediaComposition = const CompositionState(
    requiresBody: false,
  );

  String? _mediaId;

  /// The server-side DRAFT post that holds this composition's media claim.
  /// Null while the composition has nothing worth protecting, or while it
  /// cannot yet be promoted (see [_ensureServerDraftClaim]).
  String? _serverDraftPostId;
  String? _mediaThumbUrl;
  String? _mediaMimeType;

  // Content Topics — Primary is human-selected and authoritative (required
  // before publishing); Secondary topics are suggested + human-editable.
  AuraTopic? _primaryTopic;
  List<AuraTopic> _secondaryTopics = <AuraTopic>[];
  final List<TagReference> _selectedTagReferences = <TagReference>[];
  bool _uploading = false;

  // Compose Link Intelligence / OG Preview -- Phase 1. Same
  // ComposeLinkDetector wired to _bodyCtrl that compose_screen.dart uses --
  // one canonical detector/resolver, not a duplicate for institution posts.
  LinkPreview? _linkPreview;
  ComposeLinkDetector? _linkDetector;

  bool _busy = false;
  bool _loadingExisting = false;
  String? _error;

  /// The last failure was the institution-authority refusal, so the banner
  /// offers the way to the Verification page alongside the server's words.
  bool _authorityRefused = false;

  // ── Local draft persistence state ─────────────────────────────────────────
  // The composer auto-saves a per-(institution, user, visibility) draft to
  // SharedPreferences (which is `localStorage` on web). The backend does not
  // currently expose a "list my drafts" endpoint, so a refreshed composer
  // cannot rehydrate from the server — this local fallback keeps the user's
  // in-progress text alive across reloads. It is **device-local only**.
  Timer? _draftDebounce;
  static const Duration _kDraftDebounce = Duration(milliseconds: 600);
  _DraftStatus _draftStatus = _DraftStatus.idle;
  DateTime? _draftSavedAt;
  String? _currentUserId;
  bool _draftBootstrapped = false;
  bool _suppressDraftSave =
      false; // true while we programmatically load a draft into the fields
  bool _draftCleared = false; // true after publish/discard so we don't resave

  // `_kImageMaxBytes = 8 MB` and `_kVideoMaxBytes = 50 MB` used to live here.
  // Neither came from a measured constraint — they were round numbers, set
  // once, and lower than both the backend's ceiling and every other composer's.
  // Capacity is now MediaCapacity's single answer, judged inside ContentIntake.
  // MIME allow-lists moved to lib/core/media/media_mime.dart (canonical
  // mirror of backend `media.service.ts::allowedMime()`). Local copies
  // here used to drift; consolidated.

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _applyInitialPost(initial);
    } else {
      _visibility = _scopeToVisibility(widget.defaultScope);
      // Public institution posts broadcast to the global/member Works feed
      // by default — institution operating infrastructure publishes to its
      // audience, not just its own profile. The operator can still switch a
      // public post to institution-only via the distribution control.
      if (_visibility == InstitutionPostVisibility.publicAll) {
        _distribution = InstitutionPostDistribution.globalEligible;
      }
    }
    _titleCtrl.addListener(_onFieldChanged);
    _bodyCtrl.addListener(_onFieldChanged);
    _linkDetector = ComposeLinkDetector(
      controller: _bodyCtrl,
      resolve: (url) => ref.read(linkPreviewServiceProvider).resolve(url),
      onPreviewChanged: (preview) {
        if (!mounted) return;
        setState(() => _linkPreview = preview);
        _onFieldChanged();
      },
    );
    if (widget.isEditing && initial == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadExistingPost();
      });
    }
  }

  void _applyInitialPost(InstitutionPost initial) {
    final decoded = InsCommunicationDecoded.parse(initial.title);
    _titleCtrl.text = decoded.hadMarker ? decoded.cleanTitle : initial.title;
    _communicationType = decoded.type;
    final hydrated = hydrateTextWithDisplayTags(
      initial.body,
      initial.tagReferences,
    );
    _bodyCtrl.text = hydrated.text;
    _mediaUrl = initial.mediaUrl;
    // Compose Link Intelligence / OG Preview -- Phase 1. Hydrate directly
    // from the already-resolved post fields rather than waiting on a
    // fresh resolve() round trip.
    final initialLinkUrl = (initial.linkUrl ?? '').trim();
    _linkPreview = initialLinkUrl.isEmpty
        ? null
        : LinkPreview(
            eligible: true,
            internal: false,
            sourceUrl: initialLinkUrl,
            status:
                (initial.linkTitle ?? '').isNotEmpty ||
                    (initial.linkImageUrl ?? '').isNotEmpty
                ? 'READY'
                : 'PENDING',
            title: initial.linkTitle,
            description: initial.linkDescription,
            siteName: initial.linkSiteName,
            imageUrl: initial.linkImageUrl,
          );
    _visibility = initial.visibility;
    _distribution = initial.distribution;
    _primaryTopic = AuraTopic.fromWire(initial.primaryTopic ?? '');
    _secondaryTopics = AuraTopic.listFromWire(initial.secondaryTopics);
    _selectedTagReferences
      ..clear()
      ..addAll(hydrated.references);
  }

  Future<void> _loadExistingPost() async {
    if (!widget.isEditing || (widget.postId ?? '').trim().isEmpty) return;
    setState(() {
      _loadingExisting = true;
      _error = null;
    });
    try {
      final repo = ref.read(institutionsRepositoryProvider);
      final post = await repo.getInstitutionPost(
        institutionId: widget.institutionId,
        postId: widget.postId!,
      );
      if (!mounted) return;
      _suppressDraftSave = true;
      setState(() {
        _applyInitialPost(post);
        _loadingExisting = false;
      });
      _suppressDraftSave = false;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingExisting = false;
        _error = _readError(e, 'Could not load post for editing.');
      });
    }
  }

  static InstitutionPostVisibility _scopeToVisibility(String? scope) {
    switch ((scope ?? '').trim().toLowerCase()) {
      case 'public':
        return InstitutionPostVisibility.publicAll;
      case 'internal':
        return InstitutionPostVisibility.internal;
      case 'member':
      case 'members':
        return InstitutionPostVisibility.memberOnly;
      default:
        // Without an explicit hint, default to member-only — the safe choice
        // that does not surface to the global feed accidentally.
        return InstitutionPostVisibility.memberOnly;
    }
  }

  @override
  void dispose() {
    _draftDebounce?.cancel();
    _linkDetector?.dispose();
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (!mounted) return;
    setState(() {});
    _scheduleDraftSave();
  }

  /// Writes an applied suggestion or translation back into the body, keeping
  /// the caret where it was (as the personal composer does).
  void _applyAssistText(String next) {
    final sel = _bodyCtrl.selection;
    final offset = sel.baseOffset >= 0
        ? sel.baseOffset.clamp(0, next.length)
        : next.length;
    _bodyCtrl.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: offset),
      composing: TextRange.empty,
    );
    // The body listener saves the draft and rebuilds.
  }

  // ── Local draft persistence ───────────────────────────────────────────────

  /// True when the composer should persist drafts locally for this
  /// invocation. Editing an existing post bypasses local drafts entirely —
  /// edits go through PATCH against the live record, not the draft store.
  bool get _shouldPersistDraft => !widget.isEditing && _currentUserId != null;

  void _bootstrapDraftsIfNeeded(String? userId) {
    if (_draftBootstrapped) return;
    if (userId == null || userId.trim().isEmpty) return;
    _currentUserId = userId.trim();
    _draftBootstrapped = true;

    if (widget.isEditing || widget.initial != null) return;
    // Defer to next frame — `setState` during build is illegal.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadDraftForCurrentScope();
    });
  }

  Future<void> _loadDraftForCurrentScope() async {
    final uid = _currentUserId;
    if (uid == null || widget.isEditing) return;
    final scope = _visibility.wire;
    final draft = await InstitutionDraftStore.load(
      institutionId: widget.institutionId,
      userId: uid,
      visibility: scope,
    );
    if (!mounted) return;
    if (draft == null || draft.isEmpty) {
      // No draft for this scope — leave fields as-is (which may include text
      // typed into the previous scope before the user switched). We don't
      // wipe the fields here because a brand-new composer should still
      // accept typing without losing it on first scope toggle.
      return;
    }
    _suppressDraftSave = true;
    setState(() {
      _titleCtrl.text = draft.title;
      _bodyCtrl.text = draft.body;
      _serverDraftPostId = draft.serverDraftPostId;
      _mediaUrl = draft.mediaUrl;
      _mediaThumbUrl = draft.mediaThumbUrl;
      _mediaMimeType = draft.mediaMimeType;
      _distribution = InstitutionPostDistributionX.fromWire(draft.distribution);
      _draftStatus = _DraftStatus.saved;
      _draftSavedAt = draft.updatedAt;
      _draftCleared = false;
    });
    _suppressDraftSave = false;
  }

  void _scheduleDraftSave() {
    if (!_shouldPersistDraft) return;
    if (_suppressDraftSave) return;
    if (_draftCleared) return;
    _draftDebounce?.cancel();
    if (mounted && _draftStatus != _DraftStatus.saving) {
      setState(() => _draftStatus = _DraftStatus.unsaved);
    }
    _draftDebounce = Timer(_kDraftDebounce, _persistDraftNow);
  }

  /// CO-RC-C5-007 — THE DRAFT CLAIM.
  ///
  /// Uploaded media starts life unreferenced: the backend stamps `orphanedAt`
  /// at confirm for any object with no parent, and the reaper reclaims it once
  /// the orphan window elapses. A draft that lives only in `localStorage` holds
  /// no `ContentReference`, so correctly-implemented cleanup eventually takes
  /// its cover and the person reopens a draft pointing at a dead URL. That was
  /// this screen's class-D exposure, and it was not a fault in the reaper — it
  /// was an unasserted claim.
  ///
  /// The answer is not a timer and not a longer retention window. It is to make
  /// the draft REAL. A server-side DRAFT post carries an `InstitutionPostMedia`
  /// link, which is one of the authoritative sources `ContentReference` derives
  /// from, so the media is protected for exactly as long as the draft exists
  /// and becomes reclaimable the moment it stops existing. Retention authority
  /// keeps re-deriving; nothing here asks it to trust a counter.
  ///
  /// A DRAFT needs only a title and a body — the topic the publish gate insists
  /// on is optional on the create — so promotion succeeds as soon as there is
  /// anything worth recovering.
  Future<void> _ensureServerDraftClaim() async {
    if (widget.isEditing) return; // already a server row; already claimed
    if (_serverDraftPostId != null) return;
    if ((_mediaUrl ?? '').trim().isEmpty) return; // nothing to protect

    final title = _encodedTitle().trim();
    final body = _bodyCtrl.text.trim();
    if (title.isEmpty || body.isEmpty) return; // not yet recoverable either

    try {
      final post = await ref
          .read(institutionsRepositoryProvider)
          .createInstitutionPost(
            widget.institutionId,
            _draftClaimPayload(),
            status: 'DRAFT',
          );
      if (!mounted) return;
      setState(() => _serverDraftPostId = post.id);
    } catch (_) {
      // Leave the claim unmade rather than pretend. `_draftClaim` stays
      // clientOnly, and `_persistDraftNow` will not write a media reference
      // the server cannot see.
    }
  }

  /// The create payload for a claim.
  ///
  /// Deliberately NOT [_payload]: that one dereferences `_primaryTopic!` because
  /// publishing requires a topic. A draft does not, and refusing to claim media
  /// because a topic has not been chosen yet would leave the exposure open for
  /// exactly the compositions most likely to be abandoned.
  Map<String, dynamic> _draftClaimPayload() {
    return <String, dynamic>{
      'title': _encodedTitle(),
      'body': _bodyCtrl.text.trim(),
      if ((_mediaUrl ?? '').trim().isNotEmpty) 'mediaUrl': _mediaUrl,
      'visibility': _visibility.wire,
      'distribution': _distribution.wire,
      if (_primaryTopic != null) 'primaryTopic': _primaryTopic!.wire,
    };
  }

  /// Whether this composition's media is visible to retention authority.
  ///
  /// Two shapes count as holding media. A FRESH upload is identified by
  /// `_mediaId` — server identity is the only proof an upload finished, and it
  /// is the object the reaper can actually reclaim. A RESTORED draft has only
  /// `_mediaUrl`, because the local store keeps the URL; it is nonetheless real
  /// media, and by the invariant in [_persistDraftNow] it was only written down
  /// because a claim already existed.
  /// Items the server may be given — everything with real identity.
  List<Attachment> get _composableMedia => _media
      .where((a) => (a.mediaId ?? '').trim().isNotEmpty)
      .toList(growable: false);

  /// Keep the transitional single fields in step with the collection.
  ///
  /// Draft persistence and restore still speak in one URL. Deriving them from
  /// the first item — rather than maintaining them independently — is what
  /// stops the two representations drifting while the legacy path is retired.
  void _syncTransitionalMediaFields() {
    final first = _media.isEmpty ? null : _media.first;
    _mediaId = (first?.mediaId ?? '').trim().isEmpty ? null : first!.mediaId;
    _mediaUrl = (first?.url ?? '').trim().isEmpty ? null : first!.url;
    _mediaThumbUrl = (first?.thumbUrl ?? '').trim().isEmpty
        ? _mediaUrl
        : first!.thumbUrl;
    _mediaMimeType = first?.mimeType;
  }

  void _removeMediaItem(String localId) {
    setState(() {
      _mediaComposition = _mediaComposition.removeAttachment(localId);
      _media.removeWhere((a) => a.localId == localId);
      _syncTransitionalMediaFields();
    });
    _scheduleDraftSave();
  }

  void _reorderMediaItem(int oldIndex, int newIndex) {
    setState(() {
      var target = newIndex;
      if (target > oldIndex) target -= 1;
      if (target < 0) target = 0;
      if (target > _media.length - 1) target = _media.length - 1;
      if (target == oldIndex) return;
      final moved = _media.removeAt(oldIndex);
      _media.insert(target, moved);
      _syncTransitionalMediaFields();
    });
    _scheduleDraftSave();
  }

  DraftClaim get _draftClaim {
    final uploaded = (_mediaId ?? '').trim().isNotEmpty;
    final restored = (_mediaUrl ?? '').trim().isNotEmpty;
    if (!uploaded && !restored) return DraftClaim.nothingToProtect;
    if (widget.isEditing || _serverDraftPostId != null) {
      return DraftClaim.serverHeld;
    }
    return DraftClaim.clientOnly;
  }

  Future<void> _persistDraftNow() async {
    if (!_shouldPersistDraft) return;
    final uid = _currentUserId;
    if (uid == null) return;

    final title = _titleCtrl.text;
    final body = _bodyCtrl.text;
    if (title.trim().isEmpty && body.trim().isEmpty) {
      // Nothing meaningful to keep — also remove any prior draft for this
      // scope so an emptied composer doesn't quietly resurrect old text.
      await InstitutionDraftStore.remove(
        institutionId: widget.institutionId,
        userId: uid,
        visibility: _visibility.wire,
      );
      if (!mounted) return;
      setState(() {
        _draftStatus = _DraftStatus.idle;
        _draftSavedAt = null;
      });
      return;
    }

    // Now that there IS something recoverable, make sure its media is claimed
    // before a reference to that media is written down anywhere.
    await _ensureServerDraftClaim();
    if (!mounted) return;

    if (mounted) {
      setState(() => _draftStatus = _DraftStatus.saving);
    }
    final now = DateTime.now();
    // THE INVARIANT: a local draft never records media the server cannot see.
    // Persisting the URL without a claim is what turned a cleanup the retention
    // authority performed correctly into a cover that vanished from a draft the
    // person could still open.
    final claimed = _draftClaim == DraftClaim.serverHeld;
    try {
      await InstitutionDraftStore.save(
        institutionId: widget.institutionId,
        userId: uid,
        draft: InstitutionDraft(
          title: title,
          body: body,
          mediaUrl: claimed ? _mediaUrl : null,
          mediaThumbUrl: claimed ? _mediaThumbUrl : null,
          mediaMimeType: claimed ? _mediaMimeType : null,
          serverDraftPostId: _serverDraftPostId,
          visibility: _visibility.wire,
          distribution: _distribution.wire,
          updatedAt: now,
        ),
      );
      if (!mounted) return;
      setState(() {
        _draftStatus = _DraftStatus.saved;
        _draftSavedAt = now;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _draftStatus = _DraftStatus.unsaved);
    }
  }

  Future<void> _clearAllLocalDrafts() async {
    final uid = _currentUserId;
    if (uid == null) return;
    _draftCleared = true;
    _draftDebounce?.cancel();
    await InstitutionDraftStore.clearAllScopes(
      institutionId: widget.institutionId,
      userId: uid,
    );
  }

  Future<void> _discardDraft() async {
    final uid = _currentUserId;
    if (uid == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AuraSurface.subtle,
        title: const Text('Discard draft?', style: AuraText.headline),
        content: Text(
          'Your locally saved draft for this scope will be removed. This '
          'cannot be undone.',
          style: AuraText.body.copyWith(color: AuraSurface.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Discard',
              style: TextStyle(color: AuraSurface.coRose),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    _draftDebounce?.cancel();
    _draftCleared = true;
    await InstitutionDraftStore.remove(
      institutionId: widget.institutionId,
      userId: uid,
      visibility: _visibility.wire,
    );
    if (!mounted) return;
    _suppressDraftSave = true;
    setState(() {
      _titleCtrl.clear();
      _bodyCtrl.clear();
      _mediaUrl = null;
      _mediaThumbUrl = null;
      _mediaMimeType = null;
      _distribution = InstitutionPostDistribution.institutionOnly;
      _draftStatus = _DraftStatus.idle;
      _draftSavedAt = null;
      _error = null;
    });
    _suppressDraftSave = false;
    // Allow saves again on the next user keystroke.
    _draftCleared = false;
  }

  bool get _hasAnyDraftContent =>
      _titleCtrl.text.trim().isNotEmpty ||
      _bodyCtrl.text.trim().isNotEmpty ||
      (_mediaUrl != null && _mediaUrl!.isNotEmpty);

  Future<void> _onVisibilityChanged(InstitutionPostVisibility next) async {
    if (next == _visibility) return;

    // Flush whatever the user has typed into the *current* scope before we
    // switch — otherwise a fast scope-toggle would lose the in-flight text.
    _draftDebounce?.cancel();
    if (_shouldPersistDraft && !_draftCleared) {
      await _persistDraftNow();
    }

    if (!mounted) return;
    setState(() {
      _visibility = next;
      if (next != InstitutionPostVisibility.publicAll) {
        _distribution = InstitutionPostDistribution.institutionOnly;
      } else {
        // Switching to public defaults to global/member Works broadcast
        // (operator can still toggle back to institution-only).
        _distribution = InstitutionPostDistribution.globalEligible;
      }
      _draftStatus = _DraftStatus.idle;
      _draftSavedAt = null;
    });

    // Now load the draft (if any) for the new scope. This intentionally
    // does NOT clear fields when no draft exists for the new scope — a
    // brand-new composer should still let the user keep typing into the
    // new scope.
    await _loadDraftForNewScope();
  }

  Future<void> _loadDraftForNewScope() async {
    final uid = _currentUserId;
    if (uid == null || widget.isEditing) return;
    final scope = _visibility.wire;
    final draft = await InstitutionDraftStore.load(
      institutionId: widget.institutionId,
      userId: uid,
      visibility: scope,
    );
    if (!mounted) return;
    if (draft == null || draft.isEmpty) return;

    _suppressDraftSave = true;
    setState(() {
      _titleCtrl.text = draft.title;
      _bodyCtrl.text = draft.body;
      _serverDraftPostId = draft.serverDraftPostId;
      _mediaUrl = draft.mediaUrl;
      _mediaThumbUrl = draft.mediaThumbUrl;
      _mediaMimeType = draft.mediaMimeType;
      _distribution = InstitutionPostDistributionX.fromWire(draft.distribution);
      _draftStatus = _DraftStatus.saved;
      _draftSavedAt = draft.updatedAt;
    });
    _suppressDraftSave = false;
  }

  /// Title used at submission time. If the user left the title field
  /// blank, derive a short title from the first non-empty line of the
  /// body (capped at 80 chars) so the institutional statement always
  /// has a headline. Returns an empty string only when both fields are
  /// blank — in which case [_localValidationError] still rejects the
  /// submit because body is required.
  String _resolvedCleanTitle() {
    final t = _titleCtrl.text.trim();
    if (t.isNotEmpty) return t;
    final body = _bodyCtrl.text.trim();
    if (body.isEmpty) return '';
    final firstLine = body
        .split('\n')
        .firstWhere((l) => l.trim().isNotEmpty, orElse: () => '')
        .trim();
    if (firstLine.isEmpty) return '';
    return firstLine.length > 80
        ? firstLine.substring(0, 80).trim()
        : firstLine;
  }

  String _encodedTitle() {
    return InsCommunicationDecoded.encode(
      type: _communicationType,
      cleanTitle: _resolvedCleanTitle(),
    );
  }

  String? get _localValidationError {
    final body = _bodyCtrl.text.trim();
    final cleanTitle = _resolvedCleanTitle();
    // Title may be derived from body, so we no longer hard-require it
    // at the field level. We still ensure the *resolved* clean title is
    // non-empty (which fails only when both title and body are blank —
    // body is the next check anyway).
    if (cleanTitle.isEmpty) return 'Title or body is required.';
    final encoded = InsCommunicationDecoded.encode(
      type: _communicationType,
      cleanTitle: cleanTitle,
    );
    if (encoded.length > InstitutionPost.maxTitleChars) {
      // Marker + clean title exceeds the title cap. Surface as a title
      // length error so the user knows to shorten the headline.
      return 'Title is too long (max ${InstitutionPost.maxTitleChars} chars).';
    }
    if (body.isEmpty) return 'Body is required.';
    if (body.length > InstitutionPost.maxBodyChars) {
      return 'Body is too long (max ${InstitutionPost.maxBodyChars} chars).';
    }
    if (_primaryTopic == null) {
      return 'Select a primary topic.';
    }
    return InstitutionPost.validate(_visibility, _distribution);
  }

  /// Builds the request body for create/update.
  ///
  /// `status` is intentionally **never** placed in the body — the backend's
  /// `CreateInstitutionPostDto` rejects unknown properties (`property status
  /// should not exist`). Status is sent as the `?status=` query parameter on
  /// create; updates do not change status (publish/submit/archive go through
  /// dedicated endpoints).
  Map<String, dynamic> _payload() {
    return <String, dynamic>{
      // Title is encoded with `[OFFICIAL:TYPE] ` prefix so the institutional
      // type round-trips without a backend schema change. The feed card
      // and post detail strip the marker on render.
      'title': _encodedTitle(),
      'body': _bodyCtrl.text.trim(),
      // THE CANONICAL COLLECTION. Order is the author's, sent as array order,
      // and the server derives `position` from it rather than from any index
      // this client might disagree with.
      //
      // The legacy `mediaUrl` is deliberately NOT sent alongside it: the server
      // ignores it when `media` is present, and sending both would invite a
      // post whose stored order disagreed with its legacy field.
      'media': [
        for (final a in _composableMedia)
          {'mediaId': a.mediaId, 'position': _composableMedia.indexOf(a)},
      ],
      'visibility': _visibility.wire,
      'distribution': _distribution.wire,
      'primaryTopic': _primaryTopic!.wire,
      'secondaryTopics': _secondaryTopics.map((t) => t.wire).toList(),
      'tagReferences': _currentMentionPayload(),
      'mentions': _currentMentionPayload(),
      // Compose Link Intelligence / OG Preview -- Phase 1. Same
      // always-resend-current-value convention as the other fields above.
      'linkPreviewId': (_linkPreview?.eligible ?? false)
          ? _linkPreview!.linkPreviewId
          : null,
      'linkSourceUrl': (_linkPreview?.eligible ?? false)
          ? _linkPreview!.sourceUrl
          : null,
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
    final text = _bodyCtrl.text;
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

  // ── Media upload (presign flow) ───────────────────────────────────────────

  /// ONE SELECTION, images and videos together.
  ///
  /// The `video:` flag existed only because the pickers behind it were
  /// singular; a person attaching two photographs and a video had to use two
  /// menu entries and three trips. Kind is now inferred per file, so one mixed
  /// selection is expressible.
  Future<void> _pickMediaMultiple() async {
    if (_busy || _uploading) return;
    final remaining = kMaxComposableMedia - _media.length;
    if (remaining <= 0) return;
    // THE CANONICAL ACQUISITION. This held a private `ImagePicker` and
    // re-implemented the module's ceiling, ordering and limit message by hand
    // -- and the private picker cost this screen the Android Photo Picker, so
    // choosing media opened the legacy file browser.
    final acquired = await acquireMultipleMedia(remainingSlots: remaining);
    if (acquired.isEmpty) return;
    for (final r in acquired.resolutions) {
      await _uploadResolved(r);
    }
    final message = acquisitionLimitMessage(acquired.droppedForLimit);
    if (message != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  /// Upload one ALREADY-RESOLVED item.
  ///
  /// Intake happens once, in the acquisition module, rather than again here.
  /// Repeating it was how this screen ended up with its own picker: once a
  /// surface re-does the door, owning the door's input feels natural.
  Future<void> _uploadResolved(IntakeResolution resolution) async {
    if (_busy) return;

    setState(() {
      _uploading = true;
      _error = null;
    });

    try {
      final attachment = resolution.attachment;
      if (attachment == null) {
        throw _MediaValidationException(resolution.rejectionMessage!);
      }
      // KIND IS INFERRED, not demanded. The old check compared what intake
      // resolved against which BUTTON was pressed, which is why one selection
      // could never hold a photograph and a video together. Intake has already
      // refused anything the destination cannot carry.
      final video = attachment.kind == AttachmentKind.video;
      // WHAT GETS UPLOADED IS WHAT INTAKE PRODUCED, not what was picked.
      //
      // These must travel together. Sending the ORIGINAL bytes with the
      // resolved mime is exactly the mislabelling the whole intake design
      // exists to prevent — and after normalization the two genuinely differ:
      // a picked HEIC resolves to image/jpeg and carries re-encoded bytes.
      final prepared = attachment.bytes!;
      final mimeType = attachment.mimeType!;
      final uploadName = attachment.fileName ?? 'media';

      final size = video ? null : await _decodeImageSize(prepared);

      final result = await uploadAuraMedia(
        dio: ref.read(dioProvider),
        bytes: prepared,
        fileName: uploadName,
        mimeType: mimeType,
        originalMimeType: attachment.originalMimeType,
        kind: video ? 'VIDEO' : 'IMAGE',
        source: 'UPLOAD',
        width: size?['width'],
        height: size?['height'],
        metadataPatch: <String, dynamic>{
          if (size?['width'] != null) 'width': size!['width'],
          if (size?['height'] != null) 'height': size!['height'],
          'editDisclosure': false,
        },
      );

      final url = result.url.trim();
      if (url.isEmpty) {
        throw Exception('Uploaded media URL missing from response.');
      }

      if (!mounted) return;
      setState(() {
        // APPEND, in selection order. The transitional single fields are
        // derived from the first item so draft persistence keeps working
        // without becoming a second source of truth.
        _media.add(
          Attachment(
            localId:
                '${DateTime.now().microsecondsSinceEpoch}-${_media.length}',
            kind: mimeType.startsWith('video/')
                ? AttachmentKind.video
                : AttachmentKind.image,
            source: AttachmentSource.gallery,
            mediaId: result.mediaId.trim().isEmpty
                ? null
                : result.mediaId.trim(),
            url: url,
            // A POSTER IS A PICTURE OF THE MEDIA, NEVER THE MEDIA.
            //
            // This fell back to `url` when the server issued no thumbnail —
            // and for video the server NEVER issues one, because the
            // derivative pipeline accepts image mimes only. So every video
            // attached here got its own .mp4 as a poster, an image decoder was
            // pointed at it, and the strip showed a blank tile after
            // downloading the entire file. Founder-observed 2026-09-24.
            //
            // For a still image the object IS its own picture, so the fallback
            // is sound there and is kept.
            thumbUrl: result.thumbUrl.trim().isNotEmpty
                ? result.thumbUrl.trim()
                : (video ? null : url),
            mimeType: mimeType,
            bytes: prepared,
            // KEEP THE LOCAL HANDLE. On web an XFile's `path` is a blob: URL,
            // which a media element loads like any other source and without
            // copying bytes — so this is the only preview that does not depend
            // on the network.
            //
            // Dropping it is why a video broke HERE and not in the member
            // composer: that one MUTATES the attachment it already has and so
            // keeps `file`, while this one built a fresh Attachment from the
            // upload response alone. The stored `url` is a raw R2 origin
            // address that answers 401 to an anonymous reader, and a <video>
            // tag cannot send an Authorization header.
            file: attachment.file,
          ),
        );
        _mediaComposition = _mediaComposition.copyWith(
          attachments: [..._media],
        );
        _syncTransitionalMediaFields();
      });
      // Claim it before anything persists a reference to it.
      await _ensureServerDraftClaim();
      _scheduleDraftSave();
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _error = _readError(e, 'Could not upload media.'));
    } on _MediaValidationException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _readError(e, 'Could not upload media.'));
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  // _inferMime removed — replaced with `inferMimeFromFileName` from
  // lib/core/media/media_mime.dart (canonical).

  Future<Map<String, int>?> _decodeImageSize(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final w = frame.image.width;
      final h = frame.image.height;
      frame.image.dispose();
      return {'width': w, 'height': h};
    } catch (_) {
      return null;
    }
  }

  // ── Save / submit / publish ────────────────────────────────────────────────

  Future<void> _submitForReview() async {
    final err = _localValidationError;
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final repo = ref.read(institutionsRepositoryProvider);
      InstitutionPost post;
      if (widget.isEditing) {
        post = await repo.updateInstitutionPost(
          widget.institutionId,
          widget.postId!,
          _payload(),
        );
      } else {
        post = await repo.createInstitutionPost(
          widget.institutionId,
          _payload(),
          status: 'DRAFT',
        );
      }
      await repo.submitInstitutionPost(widget.institutionId, post.id);
      await _clearAllLocalDrafts();
      _invalidatePostFeeds();
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Submitted for review'),
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _readError(e, 'Could not submit post for review.');
      });
    }
  }

  /// Write the composition to its server row.
  ///
  /// Reuses the DRAFT post that already holds this composition's media claim.
  /// Without this, promoting a claimed draft would mint a SECOND post and
  /// leave the first one behind still holding a reference to the media —
  /// turning a fix for lost media into a source of orphaned drafts.
  Future<InstitutionPost> _commitComposition() async {
    final repo = ref.read(institutionsRepositoryProvider);
    final existing = widget.isEditing ? widget.postId : _serverDraftPostId;
    if (existing != null && existing.trim().isNotEmpty) {
      return repo.updateInstitutionPost(
        widget.institutionId,
        existing.trim(),
        _payload(),
      );
    }
    return repo.createInstitutionPost(
      widget.institutionId,
      _payload(),
      status: 'DRAFT',
    );
  }

  Future<void> _saveDraft() async {
    final err = _localValidationError;
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _commitComposition();
      // The backend now owns this draft; clear the local fallback so a stale
      // copy can't resurrect after the server-side draft is moved/published.
      await _clearAllLocalDrafts();
      _invalidatePostFeeds();
      if (!mounted) return;
      _showDistributionToast(
        published: false,
        type: _communicationType,
        visibility: _visibility,
        distribution: _distribution,
      );
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _readError(e, 'Could not save draft.');
      });
    }
  }

  Future<void> _publishNow() async {
    final err = _localValidationError;
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // A real draft must exist so the integrity review has a durable post id
      // to evaluate, acknowledge and publish against. When media was attached
      // earlier, that row already exists and already holds the media claim.
      final InstitutionPost post = await _commitComposition();
      if (!mounted) return;
      setState(() => _busy = false);

      final published = await showInstitutionPostIntegrityReviewSheet(
        context: context,
        ref: ref,
        institutionId: widget.institutionId,
        postId: post.id,
      );

      if (published != true) return;

      if (kDebugMode) {
        debugPrint(
          '[InstitutionPostComposer] publish-now response: '
          'id=${post.id}',
        );
      }
      // Publish succeeded; clear every visibility-scoped draft this user
      // has on this institution so reopening the composer starts fresh.
      await _clearAllLocalDrafts();
      _invalidatePostFeeds();
      if (!mounted) return;
      // Distribution Phase 1: publish-success acknowledgment that names
      // the audience reach. The backend may or may not enqueue push on
      // this endpoint; the snackbar communicates frontend intent so the
      // host knows which audience just received the statement.
      _showDistributionToast(
        published: true,
        type: _communicationType,
        visibility: _visibility,
        distribution: _distribution,
      );
      context.pop(true);
    } catch (e) {
      if (!mounted) return;

      // ELIGIBILITY REFUSAL. Institution voice is TWO gates — personal
      // publication and the flat 18 for representing an institution — so a
      // refusal here can mean either. The backend says which; this hands the
      // person its sentence and, where a country confirmation would change
      // the answer, the one control that resolves it.
      if (EligibilityRefusal.from(AppErrorMapper.from(e)) != null) {
        setState(() => _busy = false);
        final retry = await handleEligibilityRefusal(
          context,
          ref,
          e,
          feature: 'publish this',
        );
        // The composition is untouched either way: no controller was cleared
        // and no draft discarded, so a retry republishes exactly what was
        // already written.
        if (retry && mounted) await _publishNow();
        return;
      }

      setState(() {
        _busy = false;
        _error = _readError(e, 'Could not publish post.');
      });
    }
  }

  /// Distribution Phase 1 — surface a calm publish-confirmation snackbar
  /// that tells the host who they just reached. The text reflects the
  /// post's [visibility] (and global eligibility for public posts) so
  /// the institutional voice is closing the loop on its own action.
  void _showDistributionToast({
    required bool published,
    required InsCommunicationType type,
    required InstitutionPostVisibility visibility,
    required InstitutionPostDistribution distribution,
  }) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    String reach;
    switch (visibility) {
      case InstitutionPostVisibility.publicAll:
        reach = distribution == InstitutionPostDistribution.globalEligible
            ? 'Public audience · eligible for the global feed'
            : 'Public audience';
        break;
      case InstitutionPostVisibility.memberOnly:
        reach = 'Members only';
        break;
      case InstitutionPostVisibility.internal:
        reach = 'Internal — admins and editors';
        break;
    }

    final headline = !published
        ? 'Draft saved'
        : type == InsCommunicationType.announcement
        ? 'Announcement published'
        : 'Statement published';

    messenger.showSnackBar(
      SnackBar(
        content: Text('$headline · $reach'),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _invalidatePostFeeds() {
    // Refresh every unified feed surface. `invalidateUnifiedFeedSurfaces`
    // covers BOTH the FutureProvider variants AND the StateNotifier
    // (paged) variants. The Works tab on `/home` subscribes to the paged
    // variant — a bare `ref.invalidate(memberHomeFeedProvider)` would
    // miss it and the just-published institution post would not appear
    // in the member home feed until pull-to-refresh.
    invalidateUnifiedFeedSurfaces(ref);
    // Activity surface is institution-scoped and not part of the
    // unified-feed helper, so it still needs its own invalidate.
    ref.invalidate(
      institutionActivityFirstPageProvider(
        InstitutionActivityArgs(institutionId: widget.institutionId),
      ),
    );

    // Fire-and-forget the refetches. Errors are swallowed here — the
    // watcher screens still render their own error states from the same
    // providers.
    ref
        .read(institutionProfileFeedProvider(widget.institutionId).future)
        .ignore();
    ref.read(globalPublicFeedProvider.future).ignore();
    ref.read(memberHomeFeedProvider.future).ignore();
    ref
        .read(
          institutionActivityFirstPageProvider(
            InstitutionActivityArgs(institutionId: widget.institutionId),
          ).future,
        )
        .ignore();
    for (final scope in const ['public', 'member', 'internal']) {
      ref
          .read(
            institutionExploreFeedProvider(
              InstitutionExploreFeedArgs(
                institutionId: widget.institutionId,
                scope: scope,
              ),
            ).future,
          )
          .ignore();
    }
  }

  String _readError(Object e, String fallback) {
    final appError = AppErrorMapper.from(e, feature: 'publish this');

    // A VERIFIED PERSON WITHOUT CONFIRMED AUTHORITY FOR THIS INSTITUTION. The
    // server's sentence already names the step; the banner adds the way to it.
    _authorityRefused = appError.code == kInstitutionAuthorityRequired;

    final planCopy = institutionPublishRefusalCopy(
      appError.code,
      serverMessage: appError.message,
    );
    if (planCopy != null) return planCopy;

    if (appError.hasIssues) {
      return '${appError.message} (${appError.issues!.join('; ')})';
    }

    return appError.message.trim().isNotEmpty ? appError.message : fallback;
  }

  // ── Render ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final identity = ref.watch(institutionIdentityProvider);
    final canPublish = identity?.canPublishPosts ?? false;
    final actingAs = ref.watch(
      actingResolutionProvider(ConsequentialAct.publishInstitutionPost),
    );
    final canCreate = identity?.canCreatePosts ?? false;

    // Resolve the current user id once and bootstrap the local draft pipeline.
    // /auth/me may settle slightly after the composer mounts; we re-check on
    // every build until it's available, then load the right draft.
    final me = ref.watch(authMeDataProvider).valueOrNull;
    if (me != null) {
      final user = me['user'];
      if (user is Map) {
        final uid = (user['id'] ?? '').toString().trim();
        if (uid.isNotEmpty) _bootstrapDraftsIfNeeded(uid);
      }
    }

    // HELD BACK BY AUTHORITY, NOT BY ROLE (founder, 2026-09-19). An owner or
    // admin whose authority for this institution is not confirmed yet is told
    // exactly that and given the one step — "not allowed" would read as if
    // Aura did not recognise them. Any draft already saved stays saved: this
    // branch reads nothing from and writes nothing to the draft store.
    if (!canCreate && (identity?.awaitsSpeakingAuthority ?? false)) {
      return WorkspacePage(
        type: WorkspacePageType.composer,
        title: 'Speaking for ${identity!.name}',
        back: WorkspaceBack(
          label: 'Posts',
          path: institutionWorkspacePath(widget.institutionId, InstitutionSection.explore),
        ),
        children: [
          SpeakingAuthorityNotice(
            institutionAddress: identity.workspaceAddress,
            authorityState: identity.speakingAuthorityState,
          ),
        ],
      );
    }

    if (!canCreate) {
      return WorkspacePage(
        type: WorkspacePageType.composer,
        title: 'New post',
        back: WorkspaceBack(
          label: 'Posts',
          path: institutionWorkspacePath(widget.institutionId, InstitutionSection.explore),
        ),
        children: const [
          WorkspaceEmpty(
            icon: Icons.lock_outline_rounded,
            title: 'Not allowed',
            body: 'Only editors, admins, and owners can compose posts.',
          ),
        ],
      );
    }

    if (_loadingExisting) {
      return WorkspacePage(
        type: WorkspacePageType.composer,
        title: widget.isEditing ? 'Edit post' : 'New post',
        back: WorkspaceBack(
          label: 'Posts',
          path: institutionWorkspacePath(widget.institutionId, InstitutionSection.explore),
        ),
        loading: true,
      );
    }

    final back = WorkspaceBack(
      label: 'Posts',
      path: institutionWorkspacePath(widget.institutionId, InstitutionSection.explore),
    );
    final name = identity?.name.trim() ?? '';
    final voice = name.isEmpty
        ? 'Published in the institution’s name, as its official voice.'
        : 'Published in $name’s name, as its official voice.';

    // The writing: what is said.
    final writing = <Widget>[
      if (_error != null) ...[
        _ErrorBanner(message: _error!),
        const SizedBox(height: AuraSpace.s14),
        if (_authorityRefused) ...[
          SpeakingAuthorityNotice(
            institutionAddress: identity?.workspaceAddress ?? widget.institutionId,
            authorityState: identity?.speakingAuthorityState,
            compact: true,
          ),
          const SizedBox(height: AuraSpace.s14),
        ],
      ],
      _LabeledField(
        label: 'Communication type',
        child: _CommunicationTypePicker(
          selected: _communicationType,
          onChanged: (t) => setState(() => _communicationType = t),
        ),
      ),
      // The kind's guard, where the institution writes in its own voice
      // (DD-42 phase 3): official speech, minors, health information.
      Consumer(
        builder: (context, ref, _) {
          final composition = compositionForInstitution(ref, widget.institutionId);
          if (composition.guards.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: AuraSpace.s12),
            child: KindGuardNotice(composition: composition),
          );
        },
      ),
      _LabeledField(
        label: 'Title (optional — derived from body if empty)',
        counter: '${_titleCtrl.text.length} / ${InstitutionPost.maxTitleChars}',
        counterColor: _counterColor(_titleCtrl.text.length, InstitutionPost.maxTitleChars),
        child: TextField(
          controller: _titleCtrl,
          maxLength: InstitutionPost.maxTitleChars,
          decoration: _decoration('Headline for this statement…'),
          style: AuraText.body,
          buildCounter: _zeroCounter,
        ),
      ),
      _LabeledField(
        label: 'Body',
        counter: '${_bodyCtrl.text.length} / ${InstitutionPost.maxBodyChars}',
        counterColor: _counterColor(_bodyCtrl.text.length, InstitutionPost.maxBodyChars),
        // Item 15 — Rich Paste, wraps the AXR-1 governed @/# autocomplete.
        child: RichPasteField(
          controller: _bodyCtrl,
          child: GovernedTagAutocomplete(
            controller: _bodyCtrl,
            focusNode: _bodyFocus,
            onTagSelected: _rememberSelectedTag,
            child: TextField(
              controller: _bodyCtrl,
              focusNode: _bodyFocus,
              maxLength: InstitutionPost.maxBodyChars,
              // A bounded maxLines makes this a second Scrollable that
              // swallows the wheel once the text overflows (the announcement
              // editor's scroll trap); it declines scroll ownership so the
              // page takes every gesture.
              maxLines: null,
              minLines: 8,
              scrollPhysics: const NeverScrollableScrollPhysics(),
              decoration: _decoration('Write your post…'),
              style: AuraText.body,
              buildCounter: _zeroCounter,
            ),
          ),
        ),
      ),
      if (_linkPreview != null && _linkPreview!.eligible) ...[
        Padding(
          padding: const EdgeInsets.only(bottom: AuraSpace.s16),
          child: _linkPreview!.internal
              ? InternalReferenceCard(
                  sourceUrl: _linkPreview!.sourceUrl,
                  reference: _linkPreview!.internalReference,
                  dense: true,
                  onRemove: () {
                    setState(() => _linkPreview = null);
                    _onFieldChanged();
                  },
                )
              : LinkPreviewCard(
                  url: _linkPreview!.sourceUrl,
                  title: _linkPreview!.title,
                  description: _linkPreview!.description,
                  siteName: _linkPreview!.siteName,
                  imageUrl: _linkPreview!.imageUrl,
                  dense: true,
                  onRemove: () {
                    setState(() => _linkPreview = null);
                    _onFieldChanged();
                  },
                ),
        ),
      ],
      _LabeledField(
        label: 'Media (optional)',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // THE CANONICAL STRIP: each item carries its own state, order
            // and removal; a video shows its own frame.
            if (_media.isNotEmpty)
              AuraCompositionStrip(
                attachments: _media,
                phaseOf: _mediaComposition.phaseOf,
                onRemove: _removeMediaItem,
                onReorder: _reorderMediaItem,
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: (_busy || _uploading || _media.length >= kMaxComposableMedia) ? null : _pickMediaMultiple,
                icon: const Icon(Icons.perm_media_outlined),
                label: Text(_media.isEmpty ? 'Add photos & videos' : 'Add more'),
              ),
            ),
            if (_uploading)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: LinearProgressIndicator(minHeight: 2),
              ),
          ],
        ),
      ),
    ];

    // Writing assistance, as the institution: the check and the translation
    // are the institution's work and count against its allowance
    // (2026-10-08). Beside the writing on wide screens, as in every composer.
    final assist = CompositionAssist(
      text: _bodyCtrl.text,
      surface: CompositionSurface.post,
      enabled: !_busy,
      onApply: _applyAssistText,
      actingForInstitutionId: widget.institutionId,
    );

    // Who sees it and where it surfaces: wide choices, so they sit under
    // the writing.
    final audience = WorkspaceSection(
      title: 'Who sees it',
      // The audience and distribution controls carry their own frames.
      boxed: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _VisibilitySection(visibility: _visibility, onChange: _onVisibilityChanged),
          const SizedBox(height: AuraSpace.s16),
          _DistributionSection(
            distribution: _distribution,
            visibility: _visibility,
            onChange: (d) {
              setState(() => _distribution = d);
              _scheduleDraftSave();
            },
          ),
        ],
      ),
    );

    // What it is about, and who is publishing it. C1: attribution sits with
    // the consequential act.
    final placement = <Widget>[
      AuraTopicSelector(
        primary: _primaryTopic,
        secondaries: _secondaryTopics,
        contentText: '${_titleCtrl.text} ${_bodyCtrl.text}',
        onPrimaryChanged: (t) => setState(() => _primaryTopic = t),
        onSecondariesChanged: (list) => setState(() => _secondaryTopics = list),
        fetchApprovedSecondaries: (primary) => ref.read(topicRepositoryProvider).approvedSecondaries(primary),
        fetchSuggestions: (primary, text) => ref.read(topicRepositoryProvider).suggestSecondary(primary, text),
      ),
      if (actingAs != null) ...[
        const SizedBox(height: AuraSpace.s16),
        ActingAttribution(
          resolution: actingAs,
          selected: actingAs.recommended!,
          onChanged: (_) {},
          verb: 'Publishing',
        ),
      ],
    ];

    final busy = _busy || _uploading;
    // One gold act: Save changes when editing, Publish now for those who may
    // publish, Submit for review for those who may not. Save draft is the
    // quiet second act; Discard draft lives under More.
    final WorkspaceAction primary = widget.isEditing
        ? WorkspaceAction(
            label: busy ? 'Saving…' : 'Save changes',
            icon: Icons.save_rounded,
            onPressed: busy ? null : _saveDraft,
          )
        : canPublish
            ? WorkspaceAction(
                label: busy ? 'Publishing…' : 'Publish now',
                icon: Icons.publish_rounded,
                onPressed: busy ? null : _publishNow,
              )
            : WorkspaceAction(
                label: busy ? 'Submitting…' : 'Submit for review',
                icon: Icons.send_rounded,
                onPressed: busy ? null : _submitForReview,
              );

    return PopScope(
      // C-17 — BACK PUTS THE KEYBOARD AWAY BEFORE IT LEAVES. Only swallowed
      // while the keyboard is up: a BACK with no keyboard must still leave.
      canPop: !backShouldDismissKeyboard(MediaQuery.viewInsetsOf(context).bottom),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        FocusScope.of(context).unfocus();
      },
      child: WorkspacePage(
        type: WorkspacePageType.composer,
        title: widget.isEditing ? 'Edit post' : 'New post',
        purpose: voice,
        back: back,
        more: [
          if (!widget.isEditing && _hasAnyDraftContent)
            WorkspaceAction(
              label: 'Discard draft',
              icon: Icons.delete_outline,
              destructive: true,
              onPressed: _busy ? null : _discardDraft,
            ),
        ],
        bar: WorkspaceBar(
          status: widget.isEditing ? null : _draftLabel(_draftStatus, _draftSavedAt),
          cancel: WorkspaceAction(label: 'Cancel', onPressed: busy ? null : () => context.pop(false)),
          secondary: !widget.isEditing && canPublish
              ? WorkspaceAction(label: busy ? 'Saving…' : 'Save draft', onPressed: busy ? null : _saveDraft)
              : null,
          primary: primary,
        ),
        children: [
          LayoutBuilder(
            builder: (context, box) {
              // The audience choices and the topic picker are built wide,
              // so they stay in the main column; only writing support sits
              // beside it, as in the announcement composer.
              final main = <Widget>[
                ...writing,
                const SizedBox(height: AuraSpace.s8),
                audience,
                WorkspaceSection(
                  title: 'What it is about',
                  boxed: false,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: placement),
                ),
              ];
              if (box.maxWidth < 900) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [...writing, assist, const SizedBox(height: AuraSpace.s16), ...main.skip(writing.length)],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: main)),
                  const SizedBox(width: AuraSpace.s24),
                  SizedBox(width: 340, child: assist),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Color _counterColor(int used, int max) {
    final ratio = max == 0 ? 0.0 : used / max;
    if (used >= max) return AuraSurface.coRose;
    if (ratio >= 0.9) return AuraSurface.coRose;
    return AuraSurface.faint;
  }

  Widget? _zeroCounter(
    BuildContext context, {
    required int currentLength,
    required int? maxLength,
    required bool isFocused,
  }) => const SizedBox.shrink();

  InputDecoration _decoration(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: AuraSurface.subtle,
    hintStyle: AuraText.body.copyWith(color: AuraSurface.faint),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AuraRadius.md),
      borderSide: const BorderSide(color: AuraSurface.divider),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AuraRadius.md),
      borderSide: const BorderSide(color: AuraSurface.divider),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AuraRadius.md),
      // The workspace's one focus colour (DD-43).
      borderSide: const BorderSide(color: AuraSurface.accent, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AuraSpace.s14,
      vertical: AuraSpace.s12,
    ),
  );
}

class _MediaValidationException implements Exception {
  const _MediaValidationException(this.message);
  final String message;
  @override
  String toString() => message;
}

// ── Layout helpers (unchanged) ───────────────────────────────────────────────

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.child,
    this.counter,
    this.counterColor,
  });

  final String label;
  final Widget child;
  final String? counter;
  final Color? counterColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AuraText.micro.copyWith(
                    color: AuraSurface.faint,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              if (counter != null)
                Text(
                  counter!,
                  style: AuraText.micro.copyWith(
                    color: counterColor ?? AuraSurface.faint,
                    fontWeight: counterColor == AuraSurface.coRose
                        ? FontWeight.w800
                        : FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AuraSpace.s6),
          child,
        ],
      ),
    );
  }
}

class _VisibilitySection extends StatelessWidget {
  const _VisibilitySection({required this.visibility, required this.onChange});

  final InstitutionPostVisibility visibility;
  final ValueChanged<InstitutionPostVisibility> onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s12),
      decoration: BoxDecoration(
        color: AuraSurface.subtle,
        borderRadius: BorderRadius.circular(AuraRadius.md),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            // Phase 1 Distribution: framed as AUDIENCE to make "who this
            // reaches" the explicit decision the host is making. Backed
            // by the existing post `visibility` enum so no schema change
            // is needed.
            'AUDIENCE',
            style: AuraText.micro.copyWith(
              color: AuraSurface.faint,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: AuraSpace.s8),
          // THE TILES NEED A MATERIAL INSIDE THE DECORATION, NOT OUTSIDE IT.
          //
          // These rows sit in a Container whose BoxDecoration paints a
          // background. A ListTile draws its own colour and its ink splash
          // onto the nearest ancestor Material — which, without this, is the
          // one ABOVE the decoration, so every ripple was painted underneath
          // the section's own background and never seen. Newer Flutter
          // asserts on exactly this ("ListTile background color or ink
          // splashes may be invisible"), which is how it surfaced: three
          // widget tests failed on Codemagic's Flutter and passed on the
          // older one here.
          //
          // A transparent Material between the decoration and the tiles gives
          // them somewhere to paint that is in front of it. Nothing about the
          // section's appearance changes; the taps become visible.
          Material(
            type: MaterialType.transparency,
            child: RadioGroup<InstitutionPostVisibility>(
              groupValue: visibility,
              onChanged: (selected) {
                if (selected != null) onChange(selected);
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final v in InstitutionPostVisibility.values)
                    RadioListTile<InstitutionPostVisibility>(
                      value: v,
                      title: Text(v.label, style: AuraText.body),
                      dense: true,
                      activeColor: AuraSurface.coTeal,
                      contentPadding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DistributionSection extends StatelessWidget {
  const _DistributionSection({
    required this.distribution,
    required this.visibility,
    required this.onChange,
  });

  final InstitutionPostDistribution distribution;
  final InstitutionPostVisibility visibility;
  final ValueChanged<InstitutionPostDistribution> onChange;

  @override
  Widget build(BuildContext context) {
    final globalEnabled = visibility == InstitutionPostVisibility.publicAll;

    return Container(
      padding: const EdgeInsets.all(AuraSpace.s12),
      decoration: BoxDecoration(
        color: AuraSurface.subtle,
        borderRadius: BorderRadius.circular(AuraRadius.md),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DISTRIBUTION',
            style: AuraText.micro.copyWith(
              color: AuraSurface.faint,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: AuraSpace.s8),
          Row(
            children: [
              Expanded(
                child: Text(
                  distribution.label,
                  style: AuraText.body.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Switch.adaptive(
                value:
                    distribution == InstitutionPostDistribution.globalEligible,
                activeThumbColor: AuraSurface.coTeal,
                onChanged: globalEnabled
                    ? (v) => onChange(
                        v
                            ? InstitutionPostDistribution.globalEligible
                            : InstitutionPostDistribution.institutionOnly,
                      )
                    : null,
              ),
            ],
          ),
          if (!globalEnabled) ...[
            const SizedBox(height: AuraSpace.s4),
            Text(
              'Distribution is locked when not public.',
              style: AuraText.micro.copyWith(color: AuraSurface.faint),
            ),
          ],
        ],
      ),
    );
  }
}

/// C-17 — SHOULD BACK PUT THE KEYBOARD AWAY INSTEAD OF LEAVING?
///
/// Yes exactly while the soft keyboard is up. The first BACK press is the one
/// people use to get the keyboard out of the way; without this the composer
/// popped instead and spent their draft.
///
/// Measured from the keyboard's own inset rather than from focus: a field can
/// hold focus with the keyboard already dismissed, and swallowing BACK then
/// would make the screen impossible to leave.
bool backShouldDismissKeyboard(double keyboardInset) => keyboardInset > 0;

// ── Draft persistence status ────────────────────────────────────────────────

enum _DraftStatus { idle, unsaved, saving, saved }

/// What the bar says about the local draft.
String _draftLabel(_DraftStatus status, DateTime? savedAt) {
  switch (status) {
    case _DraftStatus.saving:
      return 'Saving…';
    case _DraftStatus.saved:
      if (savedAt == null) return 'Draft saved';
      return 'Draft saved · ${AuraTemporal.fullShort(savedAt)}';
    case _DraftStatus.unsaved:
      return 'Unsaved changes';
    case _DraftStatus.idle:
      return 'Drafts save on this device as you write';
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s12),
      decoration: BoxDecoration(
        color: AuraSurface.coRose.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AuraRadius.md),
        border: Border.all(color: AuraSurface.coRose.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: AuraSurface.coRose),
          const SizedBox(width: AuraSpace.s8),
          Expanded(
            child: Text(
              message,
              style: AuraText.small.copyWith(color: AuraSurface.coRose),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunicationTypePicker extends StatelessWidget {
  const _CommunicationTypePicker({
    required this.selected,
    required this.onChanged,
  });

  final InsCommunicationType selected;
  final ValueChanged<InsCommunicationType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AuraSpace.s8,
      runSpacing: AuraSpace.s8,
      children: [
        for (final t in InsCommunicationType.values)
          _TypeChip(
            label: t.label,
            selected: selected == t,
            onTap: () => onChanged(t),
          ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
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
        child: Text(
          label,
          style: AuraText.small.copyWith(
            color: selected ? AuraSurface.accentText : AuraSurface.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Plain sentences for the plan refusals publishing can meet (monetization,
/// 2026-10-08), or null when [code] is not one of them.
///
/// No "Upgrade": the same binary ships to the stores, which do not allow an
/// invitation to buy. Seats are no longer counted by member, so the old
/// MEMBER_LIMIT_REACHED sentence is gone; the seat refusal carries the
/// server's own sentence, which names the plan's seat count.
@visibleForTesting
String? institutionPublishRefusalCopy(
  String? code, {
  required String serverMessage,
}) {
  switch (code) {
    case kPlanRequiredPro:
      return kOfficialVoiceNeedsProSentence;
    case 'PLAN_REQUIRED_VERIFIED':
      return 'This action requires a Verified institution.';
    case kSeatLimitReached:
      final m = serverMessage.trim();
      return m.isEmpty ? null : m;
    case kCreditsRequired:
      return kAllowanceUsedSentence;
    case 'BILLING_FORBIDDEN':
      return 'Only institution owners or admins can perform this action.';
  }
  return null;
}
