import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/app_error_mapper.dart';
import '../ui/aura_radius.dart';
import '../ui/aura_space.dart';
import '../ui/aura_surface.dart';
import '../ui/aura_text.dart';
import 'engagement_model.dart';
import 'engagement_repository.dart';

/// Canonical engagement controls for any eligible publication.
///
/// Deliberately NOT an article widget. Reactions were bound to Post by birth
/// order, cloned for institution posts, and absent for articles; building an
/// `ArticleReactionBar` would have repeated exactly that. A surface supplies
/// its [PublicationTarget] and gets the same affordances, the same emotions
/// and the same refusal behaviour as every other class.
class AuraEngagementBar extends ConsumerStatefulWidget {
  const AuraEngagementBar({
    super.key,
    required this.target,
    required this.publicationId,
    this.showSave = true,
  });

  final PublicationTarget target;
  final String publicationId;
  final bool showSave;

  @override
  ConsumerState<AuraEngagementBar> createState() => _AuraEngagementBarState();
}

class _AuraEngagementBarState extends ConsumerState<AuraEngagementBar> {
  bool _busy = false;

  ({PublicationTarget target, String id}) get _key =>
      (target: widget.target, id: widget.publicationId);

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      // The server owns the resulting state — a block, a deleted publication
      // or a concurrent change from another device all mean the optimistic
      // guess would be wrong. Refetching is cheap and always honest.
      ref.invalidate(engagementStateProvider(_key));
      await ref.read(engagementStateProvider(_key).future);
    } catch (e) {
      if (!mounted) return;
      final err = AppErrorMapper.from(e, feature: 'do that');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickReaction() async {
    final chosen = await showModalBottomSheet<AuraReaction>(
      context: context,
      showDragHandle: true,
      backgroundColor: AuraSurface.page,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AuraSpace.s16, AuraSpace.s8, AuraSpace.s16, AuraSpace.s20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('React',
                  style:
                      AuraText.body.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: AuraSpace.s12),
              Wrap(
                spacing: AuraSpace.s8,
                runSpacing: AuraSpace.s8,
                children: [
                  for (final r in AuraReaction.values)
                    InkWell(
                      borderRadius: BorderRadius.circular(AuraRadius.pill),
                      onTap: () => Navigator.of(ctx).pop(r),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AuraSpace.s12,
                            vertical: AuraSpace.s8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(r.glyph,
                                style: const TextStyle(fontSize: 26)),
                            const SizedBox(height: 2),
                            Text(r.label,
                                style: AuraText.micro
                                    .copyWith(color: AuraSurface.muted)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (chosen == null) return;
    await _run(() => ref
        .read(engagementRepositoryProvider)
        .react(widget.target, widget.publicationId, chosen)
        .then((_) {}));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(engagementStateProvider(_key));
    final state = async.value ?? const EngagementState();
    final mine = state.myReaction;

    return Row(
      children: [
        _Pill(
          busy: _busy,
          active: mine != null,
          // Long-press or the chevron opens the full set; a plain tap is the
          // ordinary Like, because most reactions are Likes and making people
          // choose every time would be worse than a default.
          onTap: () => _run(() => ref
              .read(engagementRepositoryProvider)
              .react(widget.target, widget.publicationId,
                  mine ?? AuraReaction.like)
              .then((_) {})),
          onLongPress: _pickReaction,
          icon: mine?.glyph,
          fallbackIcon: Icons.favorite_border,
          label: state.count > 0 ? '${state.count}' : 'React',
        ),
        const SizedBox(width: AuraSpace.s4),
        InkWell(
          borderRadius: BorderRadius.circular(AuraRadius.pill),
          onTap: _busy ? null : _pickReaction,
          child: const Padding(
            padding: EdgeInsets.all(AuraSpace.s4),
            child: Icon(Icons.expand_more, size: 16, color: AuraSurface.muted),
          ),
        ),
        if (state.breakdown.isNotEmpty) ...[
          const SizedBox(width: AuraSpace.s8),
          for (final entry in state.breakdown.entries)
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Text('${entry.key.glyph}${entry.value}',
                  style: AuraText.micro.copyWith(color: AuraSurface.muted)),
            ),
        ],
        const Spacer(),
        if (widget.showSave)
          _Pill(
            busy: _busy,
            active: state.saved,
            onTap: () => _run(() => ref
                .read(engagementRepositoryProvider)
                .setSaved(widget.target, widget.publicationId, !state.saved)),
            fallbackIcon:
                state.saved ? Icons.bookmark : Icons.bookmark_border,
            label: state.saved ? 'Saved' : 'Save',
          ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.busy,
    required this.active,
    required this.onTap,
    required this.fallbackIcon,
    required this.label,
    this.icon,
    this.onLongPress,
  });

  final bool busy;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final IconData fallbackIcon;
  final String? icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colour = active ? AuraSurface.ink : AuraSurface.muted;
    return InkWell(
      borderRadius: BorderRadius.circular(AuraRadius.pill),
      onTap: busy ? null : onTap,
      onLongPress: busy ? null : onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s8, vertical: AuraSpace.s4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null)
              Text(icon!, style: const TextStyle(fontSize: 15))
            else
              Icon(fallbackIcon, size: 16, color: colour),
            const SizedBox(width: 5),
            Text(label,
                style: AuraText.small
                    .copyWith(color: colour, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
