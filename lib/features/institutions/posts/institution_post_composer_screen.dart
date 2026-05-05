import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/attachments/aura_media_upload.dart';
import '../../../core/auth/session_providers.dart';
import '../../../core/institutions/institution_access_provider.dart';
import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/institution_draft_store.dart';
import '../data/institutions_repository.dart';
import '../domain/institution_post.dart';
import '../presentation/institution_detail_screen.dart' show institutionPublicPostsProvider;

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

  late InstitutionPostVisibility _visibility;
  InstitutionPostDistribution _distribution =
      InstitutionPostDistribution.institutionOnly;

  // Single-attachment state. The backend `InstitutionPost` schema accepts one
  // `mediaUrl`; the composer surfaces a real upload widget but persists only
  // the URL of the first uploaded asset. Multi-asset support is a separate
  // backend contract change (flagged below).
  final ImagePicker _picker = ImagePicker();
  String? _mediaUrl;
  String? _mediaThumbUrl;
  String? _mediaMimeType;
  bool _uploading = false;

  bool _busy = false;
  String? _error;

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

  static const int _kImageMaxBytes = 8 * 1024 * 1024; // 8 MB
  static const int _kVideoMaxBytes = 50 * 1024 * 1024; // 50 MB
  static const Set<String> _kImageMimeWhitelist = {
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/gif',
  };
  static const Set<String> _kVideoMimeWhitelist = {
    'video/mp4',
    'video/quicktime',
    'video/webm',
  };

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _titleCtrl.text = initial.title;
      _bodyCtrl.text = initial.body;
      _mediaUrl = initial.mediaUrl;
      _visibility = initial.visibility;
      _distribution = initial.distribution;
    } else {
      _visibility = _scopeToVisibility(widget.defaultScope);
    }
    _titleCtrl.addListener(_onFieldChanged);
    _bodyCtrl.addListener(_onFieldChanged);
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
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (!mounted) return;
    setState(() {});
    _scheduleDraftSave();
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
      _mediaUrl = draft.mediaUrl;
      _mediaThumbUrl = draft.mediaThumbUrl;
      _mediaMimeType = draft.mediaMimeType;
      _distribution =
          InstitutionPostDistributionX.fromWire(draft.distribution);
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

    if (mounted) {
      setState(() => _draftStatus = _DraftStatus.saving);
    }
    final now = DateTime.now();
    try {
      await InstitutionDraftStore.save(
        institutionId: widget.institutionId,
        userId: uid,
        draft: InstitutionDraft(
          title: title,
          body: body,
          mediaUrl: _mediaUrl,
          mediaThumbUrl: _mediaThumbUrl,
          mediaMimeType: _mediaMimeType,
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
              style: TextStyle(color: AuraSurface.dangerInk),
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
      _mediaUrl = draft.mediaUrl;
      _mediaThumbUrl = draft.mediaThumbUrl;
      _mediaMimeType = draft.mediaMimeType;
      _distribution =
          InstitutionPostDistributionX.fromWire(draft.distribution);
      _draftStatus = _DraftStatus.saved;
      _draftSavedAt = draft.updatedAt;
    });
    _suppressDraftSave = false;
  }

  String? get _localValidationError {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    if (title.isEmpty) return 'Title is required.';
    if (title.length > InstitutionPost.maxTitleChars) {
      return 'Title is too long (max ${InstitutionPost.maxTitleChars} chars).';
    }
    if (body.isEmpty) return 'Body is required.';
    if (body.length > InstitutionPost.maxBodyChars) {
      return 'Body is too long (max ${InstitutionPost.maxBodyChars} chars).';
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
      'title': _titleCtrl.text.trim(),
      'body': _bodyCtrl.text.trim(),
      if (_mediaUrl != null && _mediaUrl!.isNotEmpty) 'mediaUrl': _mediaUrl,
      'visibility': _visibility.wire,
      'distribution': _distribution.wire,
    };
  }

  // ── Media upload (presign flow) ───────────────────────────────────────────

  Future<void> _pickMedia({required bool video}) async {
    if (_busy || _uploading) return;
    XFile? file;
    if (video) {
      file = await _picker.pickVideo(source: ImageSource.gallery);
    } else {
      file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
      );
    }
    if (file == null) return;

    setState(() {
      _uploading = true;
      _error = null;
    });

    try {
      final bytes = await file.readAsBytes();
      final mimeType = file.mimeType ?? _inferMime(file.name, video: video);

      if (bytes.isEmpty) {
        throw const _MediaValidationException('File is empty.');
      }

      if (video) {
        if (!_kVideoMimeWhitelist.contains(mimeType.toLowerCase())) {
          throw const _MediaValidationException(
              'Unsupported video format. Use MP4, MOV, or WebM.');
        }
        if (bytes.length > _kVideoMaxBytes) {
          throw const _MediaValidationException(
              'Video must be ${_kVideoMaxBytes ~/ (1024 * 1024)} MB or smaller.');
        }
      } else {
        if (!_kImageMimeWhitelist.contains(mimeType.toLowerCase())) {
          throw const _MediaValidationException(
              'Unsupported image format. Use JPEG, PNG, WebP, or GIF.');
        }
        if (bytes.length > _kImageMaxBytes) {
          throw const _MediaValidationException(
              'Image must be ${_kImageMaxBytes ~/ (1024 * 1024)} MB or smaller.');
        }
      }

      final size = video ? null : await _decodeImageSize(bytes);

      final result = await uploadAuraMedia(
        dio: ref.read(dioProvider),
        bytes: bytes,
        fileName: file.name,
        mimeType: mimeType,
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
        _mediaUrl = url;
        _mediaThumbUrl = result.thumbUrl.trim().isNotEmpty
            ? result.thumbUrl.trim()
            : url;
        _mediaMimeType = mimeType;
      });
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

  void _removeMedia() {
    setState(() {
      _mediaUrl = null;
      _mediaThumbUrl = null;
      _mediaMimeType = null;
    });
    _scheduleDraftSave();
  }

  String _inferMime(String name, {required bool video}) {
    final ext = name.split('.').last.toLowerCase();
    if (video) {
      if (ext == 'mov') return 'video/quicktime';
      if (ext == 'webm') return 'video/webm';
      return 'video/mp4';
    }
    if (ext == 'png') return 'image/png';
    if (ext == 'webp') return 'image/webp';
    if (ext == 'gif') return 'image/gif';
    return 'image/jpeg';
  }

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
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _readError(e, 'Could not submit post for review.');
      });
    }
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
      final repo = ref.read(institutionsRepositoryProvider);
      if (widget.isEditing) {
        await repo.updateInstitutionPost(
          widget.institutionId,
          widget.postId!,
          _payload(),
        );
      } else {
        await repo.createInstitutionPost(
          widget.institutionId,
          _payload(),
          status: 'DRAFT',
        );
      }
      // The backend now owns this draft; clear the local fallback so a stale
      // copy can't resurrect after the server-side draft is moved/published.
      await _clearAllLocalDrafts();
      _invalidatePostFeeds();
      if (!mounted) return;
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
      final repo = ref.read(institutionsRepositoryProvider);
      InstitutionPost result;
      if (widget.isEditing) {
        final updated = await repo.updateInstitutionPost(
          widget.institutionId,
          widget.postId!,
          _payload(),
        );
        result = await repo.publishInstitutionPost(
          widget.institutionId,
          updated.id,
        );
      } else {
        // Single-shot create + publish via ?status=PUBLISHED (backend gates on
        // ADMIN/OWNER role and short-circuits the second round-trip).
        result = await repo.createInstitutionPost(
          widget.institutionId,
          _payload(),
          status: 'PUBLISHED',
        );
      }
      if (kDebugMode) {
        debugPrint(
          '[InstitutionPostComposer] publish-now response: '
          'id=${result.id} status=${result.status.wire} '
          'visibility=${result.visibility.wire} '
          'distribution=${result.distribution.wire} '
          'publishedAt=${result.publishedAt}',
        );
      }

      // Defensive: if the backend somehow returned a non-PUBLISHED status
      // (e.g. silent permission downgrade, gateway stripping the query
      // string), bail out before clearing the draft so the user can retry.
      if (result.status != InstitutionPostStatus.published) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _error =
              'Server saved this post as ${result.status.wire} instead of '
              'PUBLISHED. Your role may not allow direct publishing — '
              'try "Save draft" and ask an admin to publish.';
        });
        return;
      }

      // Publish succeeded — clear every visibility-scoped draft this user
      // has on this institution so reopening the composer starts fresh.
      await _clearAllLocalDrafts();
      _invalidatePostFeeds();
      if (!mounted) return;
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _readError(e, 'Could not publish post.');
      });
    }
  }

  void _invalidatePostFeeds() {
    // Mark the providers stale, then `read(.future)` to force the refetch
    // immediately — `ref.invalidate` alone only refetches when a consumer is
    // still listening at the moment of invalidation. Reading `.future`
    // additionally kicks the request off so the cache is warm by the time
    // the previous screen rebuilds and re-watches the provider.
    final scopedProviders = <ProviderListenable<Future<InstitutionPostPage>>>[];
    for (final scope in const ['public', 'member', 'internal']) {
      final args = InstitutionPostListArgs(
        institutionId: widget.institutionId,
        scope: scope,
      );
      ref.invalidate(institutionPostsFirstPageProvider(args));
      scopedProviders.add(institutionPostsFirstPageProvider(args).future);
    }
    ref.invalidate(
      institutionExplorePublicFeedProvider(widget.institutionId),
    );
    ref.invalidate(institutionPublicPostsProvider(widget.institutionId));

    // Fire-and-forget the refetches. Errors are swallowed here — the watcher
    // screens still render their own error states from the same providers.
    for (final p in scopedProviders) {
      ref.read(p).ignore();
    }
    ref
        .read(institutionExplorePublicFeedProvider(widget.institutionId).future)
        .ignore();
    ref
        .read(institutionPublicPostsProvider(widget.institutionId).future)
        .ignore();
  }

  String _readError(Object e, String fallback) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        final m = data['message']?.toString().trim() ?? '';
        if (m.isNotEmpty) return m;
      }
    }
    return fallback;
  }

  // ── Render ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final identity = ref.watch(institutionIdentityProvider);
    final canPublish = identity?.canPublishPosts ?? false;
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

    if (!canCreate) {
      return AuraScaffold(
        showHeader: false,
        body: ListView(
          padding: const EdgeInsets.all(AuraSpace.s16),
          children: [
            AuraErrorState(
              title: 'Not allowed',
              body: 'Only editors, admins, and owners can compose posts.',
              action: AuraSecondaryButton(
                label: 'Back',
                onPressed: () => context.pop(),
              ),
            ),
          ],
        ),
      );
    }

    return AuraScaffold(
      showHeader: false,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AuraSpace.s16,
          AuraSpace.s20,
          AuraSpace.s16,
          AuraSpace.s32,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          size: 20,
                          color: AuraSurface.muted,
                        ),
                      ),
                      const SizedBox(width: AuraSpace.s12),
                      Text(
                        widget.isEditing ? 'Edit post' : 'New post',
                        style: AuraText.headline,
                      ),
                    ],
                  ),
                  const SizedBox(height: AuraSpace.s10),
                  _ActorBanner(identity: identity),
                  const SizedBox(height: AuraSpace.s16),
                  Text(
                    'Posts are scoped by visibility. Distribution controls '
                    'whether public posts may surface in the global feed.',
                    style: AuraText.body
                        .copyWith(color: AuraSurface.muted, height: 1.5),
                  ),
                  const SizedBox(height: AuraSpace.s20),
                  if (_error != null) ...[
                    _ErrorBanner(message: _error!),
                    const SizedBox(height: AuraSpace.s14),
                  ],
                  _LabeledField(
                    label: 'Title',
                    counter: '${_titleCtrl.text.length} / '
                        '${InstitutionPost.maxTitleChars}',
                    counterColor: _counterColor(
                      _titleCtrl.text.length,
                      InstitutionPost.maxTitleChars,
                    ),
                    child: TextField(
                      controller: _titleCtrl,
                      maxLength: InstitutionPost.maxTitleChars,
                      decoration: _decoration('Post title…'),
                      style: AuraText.body,
                      buildCounter: _zeroCounter,
                    ),
                  ),
                  _LabeledField(
                    label: 'Body',
                    counter: '${_bodyCtrl.text.length} / '
                        '${InstitutionPost.maxBodyChars}',
                    counterColor: _counterColor(
                      _bodyCtrl.text.length,
                      InstitutionPost.maxBodyChars,
                    ),
                    child: TextField(
                      controller: _bodyCtrl,
                      maxLength: InstitutionPost.maxBodyChars,
                      maxLines: 14,
                      minLines: 8,
                      decoration: _decoration('Write your post…'),
                      style: AuraText.body,
                      buildCounter: _zeroCounter,
                    ),
                  ),
                  _LabeledField(
                    label: 'Media (optional)',
                    child: _MediaUploadSlot(
                      mediaUrl: _mediaUrl,
                      thumbUrl: _mediaThumbUrl,
                      mimeType: _mediaMimeType,
                      uploading: _uploading,
                      onPickImage: () => _pickMedia(video: false),
                      onPickVideo: () => _pickMedia(video: true),
                      onRemove: _removeMedia,
                    ),
                  ),
                  const SizedBox(height: AuraSpace.s8),
                  _VisibilitySection(
                    visibility: _visibility,
                    onChange: _onVisibilityChanged,
                  ),
                  const SizedBox(height: AuraSpace.s16),
                  _DistributionSection(
                    distribution: _distribution,
                    visibility: _visibility,
                    onChange: (d) {
                      setState(() => _distribution = d);
                      _scheduleDraftSave();
                    },
                  ),
                  const SizedBox(height: AuraSpace.s16),
                  if (!widget.isEditing)
                    _DraftStatusRow(
                      status: _draftStatus,
                      savedAt: _draftSavedAt,
                      canDiscard: _hasAnyDraftContent,
                      onDiscard: _busy ? null : _discardDraft,
                    ),
                  const SizedBox(height: AuraSpace.s12),
                  _ComposerActions(
                    busy: _busy || _uploading,
                    canPublish: canPublish,
                    onSubmitForReview: _submitForReview,
                    onSaveDraft: _saveDraft,
                    onPublish: _publishNow,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _counterColor(int used, int max) {
    final ratio = max == 0 ? 0.0 : used / max;
    if (used >= max) return AuraSurface.dangerInk;
    if (ratio >= 0.9) return AuraSurface.dangerInk;
    return AuraSurface.faint;
  }

  Widget? _zeroCounter(
    BuildContext context, {
    required int currentLength,
    required int? maxLength,
    required bool isFocused,
  }) =>
      const SizedBox.shrink();

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
          borderSide:
              const BorderSide(color: Color(0xFF0D9488), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s14,
          vertical: AuraSpace.s12,
        ),
      );
}

// ── Actor banner — "Posting as: <Institution Name>" ─────────────────────────

class _ActorBanner extends StatelessWidget {
  const _ActorBanner({required this.identity});

  final InstitutionIdentity? identity;

  static const Color _accent = Color(0xFF0D9488);
  static const Color _accentSoft = Color(0x1E0D9488);
  static const Color _accentText = Color(0xFF5EEAD4);

  @override
  Widget build(BuildContext context) {
    final name = identity?.name ?? '';
    final logoUrl = identity?.logoUrl ?? '';
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'I';

    return Container(
      padding: const EdgeInsets.all(AuraSpace.s12),
      decoration: BoxDecoration(
        color: _accentSoft,
        borderRadius: BorderRadius.circular(AuraRadius.md),
        border: Border.all(color: _accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _accentSoft,
              shape: BoxShape.circle,
              border: Border.all(color: _accent.withValues(alpha: 0.4)),
            ),
            clipBehavior: Clip.antiAlias,
            child: logoUrl.isNotEmpty
                ? Image.network(
                    logoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                      child: Text(
                        initial,
                        style: AuraText.small.copyWith(
                          color: _accentText,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      initial,
                      style: AuraText.small.copyWith(
                        color: _accentText,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: AuraSpace.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Posting as',
                  style: AuraText.micro.copyWith(
                    color: _accentText,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                Text(
                  name.isNotEmpty ? name : 'Institution',
                  style: AuraText.body.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AuraSurface.ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Media slot — bounded preview, image/video picker, progress, remove ───────

class _MediaUploadSlot extends StatelessWidget {
  const _MediaUploadSlot({
    required this.mediaUrl,
    required this.thumbUrl,
    required this.mimeType,
    required this.uploading,
    required this.onPickImage,
    required this.onPickVideo,
    required this.onRemove,
  });

  final String? mediaUrl;
  final String? thumbUrl;
  final String? mimeType;
  final bool uploading;
  final VoidCallback onPickImage;
  final VoidCallback onPickVideo;
  final VoidCallback onRemove;

  bool get _hasMedia => mediaUrl != null && mediaUrl!.isNotEmpty;
  bool get _isVideo => (mimeType ?? '').toLowerCase().startsWith('video/');

  static const double _kPreviewMaxWidth = 600;
  static const double _kPreviewMaxHeight = 340;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: _kPreviewMaxWidth,
              maxHeight: _kPreviewMaxHeight,
            ),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AuraRadius.md),
                child: _previewBody(),
              ),
            ),
          ),
        ),
        const SizedBox(height: AuraSpace.s10),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: uploading ? null : onPickImage,
              icon: Icon(
                _hasMedia && !_isVideo
                    ? Icons.swap_horiz_rounded
                    : Icons.image_outlined,
                size: 16,
              ),
              label: Text(
                uploading
                    ? 'Uploading…'
                    : _hasMedia && !_isVideo
                        ? 'Replace image'
                        : 'Add image',
              ),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                textStyle: AuraText.small.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: AuraSpace.s8),
            OutlinedButton.icon(
              onPressed: uploading ? null : onPickVideo,
              icon: Icon(
                _hasMedia && _isVideo
                    ? Icons.swap_horiz_rounded
                    : Icons.videocam_outlined,
                size: 16,
              ),
              label: Text(
                uploading
                    ? 'Uploading…'
                    : _hasMedia && _isVideo
                        ? 'Replace video'
                        : 'Add video',
              ),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                textStyle: AuraText.small.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            if (_hasMedia) ...[
              const SizedBox(width: AuraSpace.s8),
              TextButton(
                onPressed: uploading ? null : onRemove,
                child: Text(
                  'Remove',
                  style: AuraText.small.copyWith(
                    color: AuraSurface.dangerInk,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AuraSpace.s4),
        Text(
          'Image up to 8 MB · Video up to 50 MB · uploaded via Aura media presign.',
          style: AuraText.micro.copyWith(color: AuraSurface.faint, height: 1.4),
        ),
      ],
    );
  }

  Widget _previewBody() {
    if (uploading) {
      return Container(
        color: AuraSurface.subtle,
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_hasMedia) {
      final url = thumbUrl?.isNotEmpty == true ? thumbUrl! : mediaUrl!;
      return Stack(
        alignment: Alignment.center,
        children: [
          Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: AuraSurface.subtle,
              child: const Center(
                child: Icon(Icons.broken_image_outlined,
                    color: AuraSurface.faint),
              ),
            ),
          ),
          if (_isVideo)
            Container(
              padding: const EdgeInsets.all(AuraSpace.s8),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
        ],
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AuraSurface.subtle,
        border: Border.all(color: AuraSurface.divider),
      ),
      child: const Center(
        child: Icon(
          Icons.add_photo_alternate_outlined,
          color: AuraSurface.faint,
          size: 32,
        ),
      ),
    );
  }
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
                    fontWeight: counterColor == AuraSurface.dangerInk
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
  const _VisibilitySection({
    required this.visibility,
    required this.onChange,
  });

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
            'VISIBILITY',
            style: AuraText.micro.copyWith(
              color: AuraSurface.faint,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: AuraSpace.s8),
          RadioGroup<InstitutionPostVisibility>(
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
                    activeColor: const Color(0xFF0D9488),
                    contentPadding: EdgeInsets.zero,
                  ),
              ],
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
                activeThumbColor: const Color(0xFF0D9488),
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

class _ComposerActions extends StatelessWidget {
  const _ComposerActions({
    required this.busy,
    required this.canPublish,
    required this.onSubmitForReview,
    required this.onSaveDraft,
    required this.onPublish,
  });

  final bool busy;
  final bool canPublish;
  final VoidCallback onSubmitForReview;
  final VoidCallback onSaveDraft;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    if (!canPublish) {
      return Row(
        children: [
          Expanded(
            child: AuraPrimaryButton(
              label: busy ? 'Submitting…' : 'Submit for review',
              icon: busy ? null : Icons.send_rounded,
              onPressed: busy ? null : onSubmitForReview,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: AuraSecondaryButton(
            label: busy ? 'Saving…' : 'Save draft',
            icon: Icons.save_outlined,
            onPressed: busy ? null : onSaveDraft,
          ),
        ),
        const SizedBox(width: AuraSpace.s10),
        Expanded(
          child: AuraPrimaryButton(
            label: busy ? 'Publishing…' : 'Publish now',
            icon: busy ? null : Icons.publish_rounded,
            onPressed: busy ? null : onPublish,
          ),
        ),
      ],
    );
  }
}

// ── Draft persistence status ────────────────────────────────────────────────

enum _DraftStatus { idle, unsaved, saving, saved }

class _DraftStatusRow extends StatelessWidget {
  const _DraftStatusRow({
    required this.status,
    required this.savedAt,
    required this.canDiscard,
    required this.onDiscard,
  });

  final _DraftStatus status;
  final DateTime? savedAt;
  final bool canDiscard;
  final VoidCallback? onDiscard;

  String _label() {
    switch (status) {
      case _DraftStatus.saving:
        return 'Saving…';
      case _DraftStatus.saved:
        final at = savedAt;
        if (at == null) return 'Draft saved';
        final hh = at.hour.toString().padLeft(2, '0');
        final mm = at.minute.toString().padLeft(2, '0');
        return 'Draft saved · $hh:$mm';
      case _DraftStatus.unsaved:
        return 'Unsaved changes';
      case _DraftStatus.idle:
        return 'Drafts auto-save locally on this device';
    }
  }

  Color _color() {
    switch (status) {
      case _DraftStatus.saving:
      case _DraftStatus.unsaved:
        return AuraSurface.muted;
      case _DraftStatus.saved:
        return const Color(0xFF0D9488);
      case _DraftStatus.idle:
        return AuraSurface.faint;
    }
  }

  IconData _icon() {
    switch (status) {
      case _DraftStatus.saving:
        return Icons.cloud_sync_outlined;
      case _DraftStatus.saved:
        return Icons.check_circle_outline;
      case _DraftStatus.unsaved:
        return Icons.edit_note_rounded;
      case _DraftStatus.idle:
        return Icons.save_alt_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(_icon(), size: 14, color: _color()),
        const SizedBox(width: AuraSpace.s6),
        Expanded(
          child: Text(
            _label(),
            style: AuraText.micro.copyWith(
              color: _color(),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (canDiscard)
          TextButton.icon(
            onPressed: onDiscard,
            icon: const Icon(Icons.delete_outline, size: 14),
            label: const Text('Discard draft'),
            style: TextButton.styleFrom(
              foregroundColor: AuraSurface.dangerInk,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(0, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle:
                  AuraText.micro.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
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
        color: AuraSurface.dangerBg,
        borderRadius: BorderRadius.circular(AuraRadius.md),
        border: Border.all(
          color: AuraSurface.dangerInk.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              size: 16, color: AuraSurface.dangerInk),
          const SizedBox(width: AuraSpace.s8),
          Expanded(
            child: Text(
              message,
              style: AuraText.small.copyWith(color: AuraSurface.dangerInk),
            ),
          ),
        ],
      ),
    );
  }
}
