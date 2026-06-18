import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../topics/topic.dart';
import '../data/unified_feed_providers.dart';

/// Two-dimension feed filter bar (Global Feed Ordering doctrine).
///
///   * LEFT  — Topic ("what is it about?"): All Topics + the 17 topics.
///   * RIGHT — Source / type ("who published it / what kind?"): Latest/All,
///             Institutions, Members, Official, Announcements.
///
/// The two are independent and combine. Selecting a filter updates
/// [feedFilterProvider]; it never changes the default reverse-chronological
/// ordering — it only narrows what is shown.
class FeedFilterBar extends ConsumerWidget {
  const FeedFilterBar({super.key});

  static const List<(String?, String)> _sources = [
    (null, 'Latest'),
    ('institutions', 'Institutions'),
    ('members', 'Members'),
    ('official', 'Official'),
    ('announcements', 'Announcements'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(feedFilterProvider);
    final selectedTopic = AuraTopic.fromWire(filter.topic);

    void setTopic(AuraTopic? t) {
      ref.read(feedFilterProvider.notifier).state =
          FeedFilter(topic: t?.wire, source: filter.source);
    }

    void setSource(String? s) {
      ref.read(feedFilterProvider.notifier).state =
          FeedFilter(topic: filter.topic, source: s);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── LEFT — Topic ────────────────────────────────────────────────
        Row(
          children: [
            Text('Topic', style: AuraText.micro.copyWith(
              color: AuraSurface.faint,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            )),
            const SizedBox(width: AuraSpace.s8),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: PopupMenuButton<AuraTopic?>(
                  onSelected: setTopic,
                  itemBuilder: (_) => [
                    const PopupMenuItem<AuraTopic?>(
                      value: null,
                      child: Text('All topics'),
                    ),
                    for (final t in AuraTopic.values)
                      PopupMenuItem<AuraTopic?>(
                        value: t,
                        child: Text(t.label),
                      ),
                  ],
                  child: _Pill(
                    label: selectedTopic?.label ?? 'All topics',
                    selected: selectedTopic != null,
                    trailing: Icons.arrow_drop_down_rounded,
                  ),
                ),
              ),
            ),
            if (selectedTopic != null)
              TextButton(
                onPressed: () => setTopic(null),
                style: TextButton.styleFrom(
                  foregroundColor: AuraSurface.muted,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Clear'),
              ),
          ],
        ),
        const SizedBox(height: AuraSpace.s8),
        // ── RIGHT — Source / type ──────────────────────────────────────
        Row(
          children: [
            Text('Source', style: AuraText.micro.copyWith(
              color: AuraSurface.faint,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            )),
            const SizedBox(width: AuraSpace.s8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final (wire, label) in _sources) ...[
                      _Pill(
                        label: label,
                        selected: filter.source == wire,
                        onTap: () => setSource(wire),
                      ),
                      const SizedBox(width: AuraSpace.s6),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    this.onTap,
    this.trailing,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) {
    final pill = Container(
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
          if (trailing != null)
            Icon(trailing, size: 16,
                color: selected ? AuraSurface.accentText : AuraSurface.muted),
        ],
      ),
    );
    if (onTap == null) return pill;
    return InkWell(
      borderRadius: BorderRadius.circular(AuraRadius.pill),
      onTap: onTap,
      child: pill,
    );
  }
}
