import 'package:flutter/material.dart';

import '../../core/ui/aura_radius.dart';
import '../../core/ui/aura_space.dart';
import '../../core/ui/aura_surface.dart';
import '../../core/ui/aura_text.dart';
import 'topic.dart';

/// Reusable topic-selection component for content composers.
///
/// Doctrine — Human Authority + Machine Assistance:
///   * Primary Topic is **required** and **human-selected** (single choice).
///     Aura never sets or overrides it.
///   * Secondary Topics are optional. Aura *suggests* them from the content
///     ("Suggest"); the creator may accept, remove, or add any of them.
///
/// Controlled widget: the parent owns the state and is notified via the
/// `onPrimaryChanged` / `onSecondariesChanged` callbacks. Designed so any
/// content type (institution post, user post, announcement) can reuse it.
class AuraTopicSelector extends StatelessWidget {
  const AuraTopicSelector({
    super.key,
    required this.primary,
    required this.secondaries,
    required this.contentText,
    required this.onPrimaryChanged,
    required this.onSecondariesChanged,
  });

  final AuraTopic? primary;
  final List<AuraTopic> secondaries;

  /// Title + body the suggester analyzes for Secondary Topic suggestions.
  final String contentText;

  final ValueChanged<AuraTopic?> onPrimaryChanged;
  final ValueChanged<List<AuraTopic>> onSecondariesChanged;

  void _runSuggest() {
    final suggested = AuraTopicSuggester.suggest(
      contentText,
      exclude: primary,
      max: 3,
    );
    final merged = <AuraTopic>[...secondaries];
    for (final t in suggested) {
      if (t != primary && !merged.contains(t)) merged.add(t);
    }
    onSecondariesChanged(merged);
  }

  void _addSecondary(AuraTopic t) {
    if (t == primary || secondaries.contains(t)) return;
    onSecondariesChanged([...secondaries, t]);
  }

  void _removeSecondary(AuraTopic t) {
    onSecondariesChanged(secondaries.where((x) => x != t).toList());
  }

  @override
  Widget build(BuildContext context) {
    final addable = AuraTopic.values
        .where((t) => t != primary && !secondaries.contains(t))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Primary (required) ──────────────────────────────────────────
        Row(
          children: [
            Text('Primary topic', style: AuraText.small.copyWith(
              fontWeight: FontWeight.w700,
            )),
            const SizedBox(width: AuraSpace.s6),
            Text('· required', style: AuraText.micro.copyWith(
              color: primary == null ? AuraSurface.coRose : AuraSurface.faint,
              fontWeight: FontWeight.w700,
            )),
          ],
        ),
        const SizedBox(height: AuraSpace.s8),
        Wrap(
          spacing: AuraSpace.s6,
          runSpacing: AuraSpace.s6,
          children: [
            for (final t in AuraTopic.values)
              _TopicChip(
                label: t.label,
                selected: primary == t,
                onTap: () => onPrimaryChanged(primary == t ? null : t),
              ),
          ],
        ),

        const SizedBox(height: AuraSpace.s16),

        // ── Secondary (optional, suggested) ─────────────────────────────
        Row(
          children: [
            Text('Secondary topics', style: AuraText.small.copyWith(
              fontWeight: FontWeight.w700,
            )),
            const SizedBox(width: AuraSpace.s6),
            Text('· optional', style: AuraText.micro.copyWith(
              color: AuraSurface.faint,
              fontWeight: FontWeight.w700,
            )),
            const Spacer(),
            TextButton.icon(
              onPressed: contentText.trim().isEmpty ? null : _runSuggest,
              icon: const Icon(Icons.auto_awesome_outlined, size: 16),
              label: const Text('Suggest'),
              style: TextButton.styleFrom(
                foregroundColor: AuraSurface.accentText,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        Text(
          'Aura suggests from your content. You decide — add, remove, or keep.',
          style: AuraText.micro.copyWith(color: AuraSurface.muted),
        ),
        const SizedBox(height: AuraSpace.s8),
        if (secondaries.isNotEmpty)
          Wrap(
            spacing: AuraSpace.s6,
            runSpacing: AuraSpace.s6,
            children: [
              for (final t in secondaries)
                _TopicChip(
                  label: t.label,
                  selected: true,
                  trailing: Icons.close_rounded,
                  onTap: () => _removeSecondary(t),
                ),
            ],
          ),
        if (addable.isNotEmpty) ...[
          const SizedBox(height: AuraSpace.s8),
          PopupMenuButton<AuraTopic>(
            onSelected: _addSecondary,
            itemBuilder: (_) => [
              for (final t in addable)
                PopupMenuItem<AuraTopic>(value: t, child: Text(t.label)),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AuraSpace.s10,
                vertical: AuraSpace.s6,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AuraRadius.pill),
                border: Border.all(color: AuraSurface.divider),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded, size: 16,
                      color: AuraSurface.muted),
                  const SizedBox(width: 4),
                  Text('Add topic', style: AuraText.small.copyWith(
                    color: AuraSurface.muted,
                  )),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TopicChip extends StatelessWidget {
  const _TopicChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AuraRadius.pill),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s10,
          vertical: AuraSpace.s6,
        ),
        decoration: BoxDecoration(
          color: selected ? AuraSurface.accentSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(AuraRadius.pill),
          border: Border.all(
            color: selected ? AuraSurface.accent : AuraSurface.divider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AuraText.small.copyWith(
                color: selected ? AuraSurface.accentText : AuraSurface.ink,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 4),
              Icon(trailing, size: 14, color: AuraSurface.accentText),
            ],
          ],
        ),
      ),
    );
  }
}
