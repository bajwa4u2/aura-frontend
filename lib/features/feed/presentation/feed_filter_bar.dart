import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../topics/topic.dart';
import '../data/unified_feed_providers.dart';

/// Two-dimension feed filter bar (Global Feed Ordering doctrine), rendered as
/// two dropdowns on one row, opposite each other:
///
///   Topic: [All Topics ▼] ........ Resources: [All Resources ▼]
///
///   * Topic ("what is it about?") — All Topics + the 17 topics.
///   * Resources ("who published it / what kind?") — All Resources,
///     Institutions, Members, Official, Announcements, Public, Internal.
///
/// The two are independent and combine. Changing either updates
/// [feedFilterProvider]; neither changes the default reverse-chronological
/// ordering — they only narrow what is shown.
class FeedFilterBar extends ConsumerWidget {
  const FeedFilterBar({super.key, this.compact = false});

  /// When true, used inline alongside other controls (e.g. the Institution
  /// Explore visibility tabs) — drops the outer row spacing assumptions.
  final bool compact;

  /// (wire, label) for the Resources dimension. null = no filter.
  static const List<(String?, String)> resources = [
    (null, 'All Resources'),
    ('institutions', 'Institutions'),
    ('members', 'Members'),
    ('official', 'Official'),
    ('announcements', 'Announcements'),
    ('public', 'Public'),
    ('internal', 'Internal'),
  ];

  static String resourceLabel(String? wire) {
    for (final (w, l) in resources) {
      if (w == wire) return l;
    }
    return 'All Resources';
  }

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

    return Row(
      children: [
        Flexible(
          child: LabeledFilterDropdown<AuraTopic?>(
            label: 'Topic',
            current: selectedTopic?.label ?? 'All Topics',
            selected: selectedTopic != null,
            onSelected: setTopic,
            items: [
              (null, 'All Topics'),
              for (final t in AuraTopic.values) (t, t.label),
            ],
          ),
        ),
        const SizedBox(width: AuraSpace.s12),
        Flexible(
          child: Align(
            alignment: Alignment.centerRight,
            child: LabeledFilterDropdown<String?>(
              label: 'Resources',
              current: resourceLabel(filter.source),
              selected: filter.source != null,
              onSelected: setSource,
              items: resources,
            ),
          ),
        ),
      ],
    );
  }
}

/// A labeled dropdown rendered as `Label: [current ▼]`. Public so feed
/// surfaces (Works, Explore, Institution preview) reuse the exact control.
class LabeledFilterDropdown<T> extends StatelessWidget {
  const LabeledFilterDropdown({
    super.key,
    required this.label,
    required this.current,
    required this.selected,
    required this.items,
    required this.onSelected,
  });

  final String label;
  final String current;
  final bool selected;

  /// (value, label) pairs.
  final List<(T, String)> items;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label:',
          style: AuraText.micro.copyWith(
            color: AuraSurface.faint,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(width: AuraSpace.s6),
        Flexible(
          child: PopupMenuButton<T>(
            onSelected: onSelected,
            itemBuilder: (_) => [
              for (final (value, itemLabel) in items)
                PopupMenuItem<T>(value: value, child: Text(itemLabel)),
            ],
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
                  Flexible(
                    child: Text(
                      current,
                      overflow: TextOverflow.ellipsis,
                      style: AuraText.small.copyWith(
                        color: selected
                            ? AuraSurface.accentText
                            : AuraSurface.ink,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_drop_down_rounded,
                      size: 18,
                      color: selected ? AuraSurface.accentText : AuraSurface.muted),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
