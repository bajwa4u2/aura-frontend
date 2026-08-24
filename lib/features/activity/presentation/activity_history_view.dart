import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/product/product_language.dart';
import '../../../core/product/product_state.dart';
import '../../../core/product/product_state_view.dart';
import '../../../core/product/temporal.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/activity_history_repository.dart';

/// CONTINUITY, NOT AN INBOX.
///
/// Founder ruling (2026-08-23). Nothing here is acknowledged, cleared or
/// counted. Opening this view leaves every record exactly as it was, and none
/// of it reaches the drawer attention signal.
///
/// THE AUDIENCE POLICY LIVES ON THE SERVER and is deliberately not
/// re-implemented here. A rule enforced in a widget is a rule anyone can skip
/// by calling the endpoint, so this renders what it is given and filters
/// nothing — client-side filtering would be theatre, not security.
class ActivityHistoryView extends ConsumerStatefulWidget {
  const ActivityHistoryView({super.key});

  @override
  ConsumerState<ActivityHistoryView> createState() =>
      _ActivityHistoryViewState();
}

class _ActivityHistoryViewState extends ConsumerState<ActivityHistoryView> {
  final List<ActivityHistoryItem> _items = [];
  String? _cursor;
  bool _loadingMore = false;
  bool _seeded = false;

  Future<void> _loadMore() async {
    if (_loadingMore || (_cursor ?? '').isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      // The server's keyset cursor is passed back verbatim. Deriving one from
      // the last item's timestamp would break the total ordering the backend
      // established and let a row slip between pages.
      final page =
          await ref.read(activityHistoryRepositoryProvider).page(cursor: _cursor);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _cursor = page.nextCursor;
      });
    } catch (_) {
      // A failed page must not discard the pages already read.
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final first = ref.watch(activityHistoryFirstPageProvider);

    return first.when(
      loading: () => const AuraProductState(state: ProductState.loading),
      // C0 — say what is TRUE and let the product-state authority decide how
      // that looks and whether retry is an honest offer.
      error: (_, __) => AuraProductState(
        state: ProductState.unavailable,
        headline: 'Your record could not be loaded',
        action: AuraSecondaryButton(
          label: ProductLabels.of(ProductAction.retry),
          onPressed: () => ref.invalidate(activityHistoryFirstPageProvider),
          icon: Icons.refresh_rounded,
        ),
      ),
      data: (page) {
        // Seeded once. Re-seeding on every rebuild would discard the reader's
        // accumulated pages each time they loaded more.
        if (!_seeded) {
          _seeded = true;
          _items
            ..clear()
            ..addAll(page.items);
          _cursor = page.nextCursor;
        }

        if (_items.isEmpty) {
          return const AuraProductState(
            state: ProductState.empty,
            headline: 'Nothing has happened here yet',
            detail: 'Calls, invitations and other events in your conversations '
                'appear here as a record.',
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final item in _items) _HistoryTile(item: item),
            if ((_cursor ?? '').isNotEmpty) ...[
              const SizedBox(height: AuraSpace.s20),
              Center(
                child: AuraSecondaryButton(
                  label: _loadingMore ? 'Loading…' : 'Load more',
                  onPressed: _loadingMore ? null : _loadMore,
                  icon: Icons.expand_more_rounded,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// One record. States what the row says and nothing more — no manufactured
/// summary, no inferred causality, no invented target identity.
class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.item});

  final ActivityHistoryItem item;

  String get _what {
    switch (item.activityType) {
      case 'LIVE_STARTED':
        return 'started a live session';
      case 'LIVE_ENDED':
        return 'ended a live session';
      case 'PARTICIPANT_INVITED':
        return 'invited someone to the conversation';
      default:
        // An unclassified type is shown as itself rather than guessed at.
        return item.activityType.toLowerCase().replaceAll('_', ' ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final actorName = item.actor.isNotEmpty ? item.actor.label : 'Someone';
    final contextName = item.contextName;

    final body = Container(
      margin: const EdgeInsets.only(bottom: AuraSpace.s8),
      padding: const EdgeInsets.all(AuraSpace.s14),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Canonical person identity — the same reader every other surface
          // uses, so an actor looks the same here as on Members.
          AuraAvatar(
            name: actorName,
            imageUrl: item.actor.avatarUrl,
            size: 32,
          ),
          const SizedBox(width: AuraSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$actorName $_what',
                  style: AuraText.small.copyWith(color: AuraSurface.ink),
                ),
                if (contextName != null) ...[
                  const SizedBox(height: AuraSpace.s2),
                  Text(
                    contextName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AuraText.micro.copyWith(color: AuraSurface.muted),
                  ),
                ],
                if (item.occurredAt != null) ...[
                  const SizedBox(height: AuraSpace.s4),
                  Text(
                    // C0 Human Temporal Presentation Authority — the one
                    // place timezone and phrasing are decided.
                    AuraTemporal.humanize(
                      ProductTime(item.occurredAt!, TimeEvent.occurred),
                      style: TemporalStyle.compact,
                    ),
                    style: AuraText.micro.copyWith(color: AuraSurface.faint),
                  ),
                ],
              ],
            ),
          ),
          // A null destination is the SERVER'S real answer — the conversation
          // may be gone. The row stays true about the past and simply offers
          // nowhere to go, rather than a chevron leading somewhere broken.
          if (item.hasDestination)
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AuraSurface.faint),
        ],
      ),
    );

    if (!item.hasDestination) return body;
    return InkWell(
      onTap: () => context.push(item.destination!),
      borderRadius: BorderRadius.circular(AuraRadius.card),
      child: body,
    );
  }
}
