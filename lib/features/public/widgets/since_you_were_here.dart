import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/utils/relative_time.dart';
import '../../updates/providers.dart';

/// Public-UX Phase 6 — re-entry "Since you were here" section.
///
/// Renders at the top of the public/member home when there are recent,
/// unread, discourse-relevant notifications. The section is collapsible
/// — collapsed state persists for the rest of the session via a local
/// `StateNotifier`. We don't persist across app restarts because each
/// restart is a fresh re-entry: showing the band again is the point.
///
/// Source: the existing `notificationsControllerProvider`. We don't
/// fetch — the controller's own 120s poll already keeps state warm.
/// We filter to:
///   * unread (`readAt == null`),
///   * discourse-relevant (REPLY / ACCOUNTABILITY_TAGGED / PRIORITY_PINNED
///     / MENTION),
///   * within the last 7 days,
///   * cap at 4 items so the band stays calm.
class SinceYouWereHereSection extends ConsumerStatefulWidget {
  const SinceYouWereHereSection({super.key});

  @override
  ConsumerState<SinceYouWereHereSection> createState() =>
      _SinceYouWereHereSectionState();
}

class _SinceYouWereHereSectionState
    extends ConsumerState<SinceYouWereHereSection> {
  bool _collapsed = false;

  static const _kRelevantKinds = <String>{
    'REPLY',
    'ACCOUNTABILITY_TAGGED',
    'PRIORITY_PINNED',
    'MENTION',
  };

  static const _kFreshWindow = Duration(days: 7);

  List<Map<String, dynamic>> _eligibleItems(
    List<Map<String, dynamic>> all,
  ) {
    final now = DateTime.now();
    final out = <Map<String, dynamic>>[];
    for (final item in all) {
      final read = item['readAt'];
      if (read != null && read.toString().trim().isNotEmpty) continue;
      final kind =
          (item['type'] ?? item['kind'] ?? '').toString().toUpperCase();
      if (!_kRelevantKinds.contains(kind)) continue;
      final createdRaw =
          (item['createdAt'] ?? item['created_at'] ?? '').toString();
      final createdAt = DateTime.tryParse(createdRaw);
      if (createdAt == null) continue;
      if (now.difference(createdAt) > _kFreshWindow) continue;
      out.add(item);
      if (out.length >= 4) break;
    }
    return out;
  }

  String _headlineFor(Map<String, dynamic> item) {
    final kind =
        (item['type'] ?? item['kind'] ?? '').toString().toUpperCase();
    final actor = item['actor'];
    final actorInst = item['actorInstitution'];
    final actorName = actorInst is Map
        ? (actorInst['name'] ?? '').toString()
        : (actor is Map ? (actor['displayName'] ?? '').toString() : '');
    switch (kind) {
      case 'ACCOUNTABILITY_TAGGED':
        final tag = ((item['payload'] is Map ? item['payload'] : item['data'])
                as Map?)?['accountabilityTag']
            ?.toString()
            .toUpperCase();
        switch (tag) {
          case 'COMMITMENT':
            return actorName.isNotEmpty
                ? '$actorName committed to address your discussion'
                : 'An institution committed to address your discussion';
          case 'UPDATE':
            return actorName.isNotEmpty
                ? '$actorName posted an update on your discussion'
                : 'An institution posted an update on your discussion';
          case 'RESOLVED':
            return actorName.isNotEmpty
                ? 'Your discussion was resolved by $actorName'
                : 'Your discussion was resolved';
          default:
            return actorName.isNotEmpty
                ? '$actorName updated your discussion'
                : 'An institution updated your discussion';
        }
      case 'PRIORITY_PINNED':
        return actorName.isNotEmpty
            ? '$actorName pinned a priority response to your discussion'
            : 'A priority response was pinned to your discussion';
      case 'MENTION':
        return actorName.isNotEmpty
            ? '$actorName mentioned you'
            : 'You were mentioned';
      case 'REPLY':
      default:
        return actorName.isNotEmpty
            ? '$actorName replied to your discussion'
            : 'Someone replied to your discussion';
    }
  }

  IconData _iconFor(String kind) {
    switch (kind) {
      case 'ACCOUNTABILITY_TAGGED':
        return Icons.handshake_outlined;
      case 'PRIORITY_PINNED':
        return Icons.push_pin_rounded;
      case 'MENTION':
        return Icons.alternate_email_rounded;
      case 'REPLY':
      default:
        return Icons.forum_rounded;
    }
  }

  String? _routeFor(Map<String, dynamic> item) {
    final kind =
        (item['type'] ?? item['kind'] ?? '').toString().toUpperCase();
    final payload = item['payload'] is Map
        ? item['payload'] as Map
        : (item['data'] is Map ? item['data'] as Map : const {});
    final parentTargetType =
        (payload['targetType'] ?? '').toString().toUpperCase();
    final parentId = payload['parentPostId']?.toString().trim() ?? '';

    // For REPLY notifications, the user's intent is "open the parent
    // discussion I own", not "open the reply itself" (which is a separate
    // post and may have been deleted independently). The backend deeplink
    // upgrade routes new replies to the parent automatically; legacy
    // notifications that still carry a reply-targeted deeplink are
    // overridden here using `payload.parentPostId`.
    if (kind == 'REPLY' && parentId.isNotEmpty) {
      if (parentTargetType == 'INSTITUTION_POST') {
        return '/thread/$parentId?type=INSTITUTION_POST';
      }
      // Default / USER_POST / POST → user-post thread route.
      return '/thread/$parentId?type=USER_POST';
    }

    // Other kinds: trust the backend-computed deeplink first.
    final deeplink = item['deeplink']?.toString().trim() ?? '';
    if (deeplink.isNotEmpty) return deeplink;

    if (parentId.isNotEmpty) {
      return '/thread/$parentId?type=INSTITUTION_POST';
    }
    final institutionPostId =
        item['institutionPostId']?.toString().trim() ?? '';
    if (institutionPostId.isNotEmpty) {
      return '/thread/$institutionPostId?type=INSTITUTION_POST';
    }
    final postId = item['postId']?.toString().trim() ?? '';
    if (postId.isNotEmpty) {
      return '/thread/$postId?type=USER_POST';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsControllerProvider);
    final eligible = _eligibleItems(state.items);
    if (eligible.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.s14,
        AuraSpace.s12,
        AuraSpace.s14,
        AuraSpace.s12,
      ),
      decoration: BoxDecoration(
        color: AuraSurface.accentSoft.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AuraRadius.lg),
        border: Border.all(
          color: AuraSurface.accent.withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.notifications_active_outlined,
                size: 14,
                color: AuraSurface.accentText,
              ),
              const SizedBox(width: 6),
              Text(
                'SINCE YOU WERE HERE',
                style: AuraText.micro.copyWith(
                  color: AuraSurface.accentText,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.9,
                  fontSize: 10,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () =>
                    setState(() => _collapsed = !_collapsed),
                borderRadius: BorderRadius.circular(AuraRadius.pill),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    _collapsed
                        ? Icons.expand_more_rounded
                        : Icons.expand_less_rounded,
                    size: 18,
                    color: AuraSurface.accentText,
                  ),
                ),
              ),
            ],
          ),
          if (!_collapsed) ...[
            const SizedBox(height: AuraSpace.s8),
            for (var i = 0; i < eligible.length; i++) ...[
              _ItemRow(
                headline: _headlineFor(eligible[i]),
                createdAt: DateTime.tryParse(
                    (eligible[i]['createdAt'] ?? '').toString()),
                icon: _iconFor((eligible[i]['type'] ??
                        eligible[i]['kind'] ??
                        '')
                    .toString()
                    .toUpperCase()),
                onTap: () {
                  final route = _routeFor(eligible[i]);
                  if (route != null && route.isNotEmpty) {
                    context.push(route);
                  }
                },
              ),
              if (i < eligible.length - 1)
                const SizedBox(height: AuraSpace.s6),
            ],
          ],
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.headline,
    required this.createdAt,
    required this.icon,
    required this.onTap,
  });

  final String headline;
  final DateTime? createdAt;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AuraRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s10,
          vertical: AuraSpace.s8,
        ),
        decoration: BoxDecoration(
          color: AuraSurface.card,
          borderRadius: BorderRadius.circular(AuraRadius.md),
          border: Border.all(color: AuraSurface.divider),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: AuraSurface.muted),
            const SizedBox(width: AuraSpace.s8),
            Expanded(
              child: Text(
                headline,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AuraText.small.copyWith(
                  color: AuraSurface.ink,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
            ),
            if (createdAt != null) ...[
              const SizedBox(width: AuraSpace.s8),
              Text(
                formatRelative(createdAt!),
                style: AuraText.micro.copyWith(color: AuraSurface.faint),
              ),
            ],
            const SizedBox(width: 4),
            const Icon(
              Icons.arrow_forward_rounded,
              size: 13,
              color: AuraSurface.muted,
            ),
          ],
        ),
      ),
    );
  }
}
