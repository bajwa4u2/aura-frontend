import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/institutions/institution_access_provider.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/institutions_repository.dart';
import '../domain/institution_post.dart';

/// Composer for [InstitutionPost]s. Used in both create and edit modes.
///
/// Behavior by role:
///   * EDITOR — single CTA "Submit for review" (DRAFT -> PENDING_APPROVAL)
///   * OWNER / ADMIN — split control: Save draft, or Publish now
///
/// Note: edit mode opens the form blank unless an [initial] post is passed in
/// by the caller. Screens that route via `/posts/:postId/edit` should fetch
/// the post and pass it through the route extras (or upgrade this screen to
/// fetch by `postId` itself once a getById endpoint is wired). Today's
/// repository does not expose `getInstitutionPost` so the edit route is
/// best-effort.
class InstitutionPostComposerScreen extends ConsumerStatefulWidget {
  const InstitutionPostComposerScreen({
    super.key,
    required this.institutionId,
    this.postId,
    this.initial,
  });

  final String institutionId;
  final String? postId;
  final InstitutionPost? initial;

  bool get isEditing => postId != null && postId!.isNotEmpty;

  @override
  ConsumerState<InstitutionPostComposerScreen> createState() =>
      _InstitutionPostComposerScreenState();
}

class _InstitutionPostComposerScreenState
    extends ConsumerState<InstitutionPostComposerScreen> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _mediaCtrl = TextEditingController();

  InstitutionPostVisibility _visibility = InstitutionPostVisibility.memberOnly;
  InstitutionPostDistribution _distribution =
      InstitutionPostDistribution.institutionOnly;

  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _titleCtrl.text = initial.title;
      _bodyCtrl.text = initial.body;
      _mediaCtrl.text = initial.mediaUrl ?? '';
      _visibility = initial.visibility;
      _distribution = initial.distribution;
    }
    _titleCtrl.addListener(_rebuildOnInput);
    _bodyCtrl.addListener(_rebuildOnInput);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _mediaCtrl.dispose();
    super.dispose();
  }

  void _rebuildOnInput() {
    if (!mounted) return;
    setState(() {});
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

  Map<String, dynamic> _payload({String? statusOverride}) {
    return <String, dynamic>{
      'title': _titleCtrl.text.trim(),
      'body': _bodyCtrl.text.trim(),
      if (_mediaCtrl.text.trim().isNotEmpty) 'mediaUrl': _mediaCtrl.text.trim(),
      'visibility': _visibility.wire,
      'distribution': _distribution.wire,
      if (statusOverride != null) 'status': statusOverride,
    };
  }

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
          _payload(statusOverride: 'DRAFT'),
        );
      }
      await repo.submitInstitutionPost(widget.institutionId, post.id);
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
          _payload(statusOverride: 'DRAFT'),
        );
      }
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
          _payload(statusOverride: 'DRAFT'),
        );
      }
      await repo.publishInstitutionPost(widget.institutionId, post.id);
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
    for (final scope in const ['public', 'member', 'internal']) {
      ref.invalidate(
        institutionPostsFirstPageProvider(
          InstitutionPostListArgs(
            institutionId: widget.institutionId,
            scope: scope,
          ),
        ),
      );
    }
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

  @override
  Widget build(BuildContext context) {
    final identity = ref.watch(institutionIdentityProvider);
    final canPublish = identity?.canPublishPosts ?? false;
    final canCreate = identity?.canCreatePosts ?? false;

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
                  const SizedBox(height: AuraSpace.s6),
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
                    label: 'Media URL (optional)',
                    child: TextField(
                      controller: _mediaCtrl,
                      keyboardType: TextInputType.url,
                      decoration: _decoration('https://…'),
                      style: AuraText.body,
                    ),
                  ),
                  const SizedBox(height: AuraSpace.s8),
                  _VisibilitySection(
                    visibility: _visibility,
                    onChange: (v) {
                      setState(() {
                        _visibility = v;
                        // Hard-block invalid combinations on the client.
                        if (v != InstitutionPostVisibility.publicAll) {
                          _distribution =
                              InstitutionPostDistribution.institutionOnly;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: AuraSpace.s16),
                  _DistributionSection(
                    distribution: _distribution,
                    visibility: _visibility,
                    onChange: (d) => setState(() => _distribution = d),
                  ),
                  const SizedBox(height: AuraSpace.s24),
                  _ComposerActions(
                    busy: _busy,
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
      // EDITOR: single CTA submitting for review.
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

    // OWNER / ADMIN: split — Save draft / Publish now.
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
