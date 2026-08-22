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

    // STATE ANNOUNCEMENT, declaratively.
    //
    // Reacting and saving change a control's meaning with no text arriving on
    // screen, so a screen-reader user got silence and no confirmation that
    // anything happened. A live region announces the new state whenever it
    // changes, and unlike an imperative announcement it stays correct if the
    // state changes from another device rather than from a tap here.
    return Semantics(
      // `container` + `explicitChildNodes` are both load-bearing. Without
      // them this annotation had no node of its own and was folded into the
      // subtree, which SWALLOWED every child label: the pills announced as
      // unnamed buttons even though each one set a label. Found by dumping
      // the semantics tree, not by reading the widget code — "it has
      // Semantics" and "it is labelled" turned out to be different claims.
      container: true,
      explicitChildNodes: true,
      liveRegion: true,
      value: _spokenState(state),
      child: Row(
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
          // Spoken, the visible label is a bare number. This says what the
          // control does and what the number counts.
          semanticLabel: mine != null
              ? 'Remove your ${mine.label} reaction. '
                  '${state.count} reactions'
              : (state.count > 0
                  ? 'React. ${state.count} reactions'
                  : 'React'),
        ),
        const SizedBox(width: AuraSpace.s4),
        // ACCESSIBILITY. This was an unlabelled chevron inside a bare InkWell:
        // a screen reader announced "button" with no indication of what it
        // does, and its 24px box was under the 48dp minimum target. IconButton
        // supplies both the tooltip-derived label and the standard target.
        IconButton(
          onPressed: _busy ? null : _pickReaction,
          tooltip: 'Choose a reaction',
          iconSize: 16,
          color: AuraSurface.muted,
          // NOT VisualDensity.compact. That looked tidier and shrank the
          // control to 32px — below the 48dp minimum target, which is the
          // defect this whole pass exists to remove. Caught by the hit-target
          // test, not by looking at it.
          // Explicit: IconButton's own default resolved to 40px here, which is
          // still under the minimum.
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: const Icon(Icons.expand_more),
        ),
        if (state.breakdown.isNotEmpty) ...[
          const SizedBox(width: AuraSpace.s8),
          for (final entry in state.breakdown.entries)
            Padding(
              padding: const EdgeInsets.only(right: 2),
              // The visible form is a glyph and a number; spoken, that is an
              // emoji name followed by a bare digit. The label says what it
              // means instead, and the visual stays exactly as designed.
              child: Semantics(
                label: '${entry.value} ${entry.key.label}',
                excludeSemantics: true,
                child: Text('${entry.key.glyph}${entry.value}',
                    style: AuraText.micro.copyWith(color: AuraSurface.muted)),
              ),
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
            semanticLabel: state.saved
                ? 'Saved. Activate to remove from your saved items'
                : 'Save this to your saved items',
          ),
      ],
      ),
    );
  }

  /// What a screen reader hears when engagement state changes.
  String _spokenState(EngagementState state) {
    final parts = <String>[
      if (state.myReaction != null) 'Your reaction: ${state.myReaction!.label}',
      if (state.count > 0) '${state.count} reactions',
      if (state.saved) 'Saved',
    ];
    return parts.isEmpty ? 'No reactions yet' : parts.join('. ');
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
    this.semanticLabel,
  });

  final bool busy;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final IconData fallbackIcon;
  final String? icon;
  final String label;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colour = active ? AuraSurface.ink : AuraSurface.muted;
    // MergeSemantics, not a bare Semantics wrapper.
    //
    // A `Semantics(label:)` around an InkWell produced NO label at all: the
    // InkWell creates its own node, the annotation above it had nothing to
    // attach to, and the control announced as an unnamed button. That was
    // invisible until the semantics tree was actually dumped — the widget
    // "had Semantics" and was still unlabelled.
    //
    // Merging makes the label and the button one node, which is what a screen
    // reader needs to say "React, 3 reactions, button" as a single control.
    return Semantics(
      container: true,
      button: true,
      enabled: !busy,
      // `label` is the count or the verb; on its own that is not an action.
      // Naming the action makes the control comprehensible without sight of
      // the row it sits in.
      label: semanticLabel ?? label,
      child: InkWell(
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        onTap: busy ? null : onTap,
        onLongPress: busy ? null : onLongPress,
        // A 24px control is under the 48dp minimum target and is genuinely
        // hard to hit. The visual padding is unchanged; the CONSTRAINT is what
        // grows, so the design is untouched and the target is real.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AuraSpace.s8, vertical: AuraSpace.s4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null)
                  // An emoji is decoration here: the label already says what
                  // this control is, and spoken emoji names add noise.
                  ExcludeSemantics(
                    child: Text(icon!, style: const TextStyle(fontSize: 15)),
                  )
                else
                  Icon(fallbackIcon, size: 16, color: colour),
                const SizedBox(width: 5),
                // When a spoken label is supplied it already contains the
                // count, so leaving the visible text in the semantics made the
                // control announce "React. 3 reactions. 3" — the number said
                // twice, the second time meaninglessly.
                if (semanticLabel != null)
                  ExcludeSemantics(
                    child: Text(label,
                        style: AuraText.small.copyWith(
                            color: colour, fontWeight: FontWeight.w700)),
                  )
                else
                  Text(label,
                      style: AuraText.small.copyWith(
                          color: colour, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
