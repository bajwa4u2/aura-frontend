import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/auth/session_providers.dart';
import '../../../core/interactions/follows_repository.dart';
import '../../../core/navigation/navigation_authority.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../discover/data/discover_repository.dart';
import '../../discover/data/people_discovery.dart';
import '../../discover/widgets/discover_domain_cards.dart';
import '../../discover/widgets/person_suggestion_card.dart';

/// Under this many people followed, a person is still getting started.
const kStartHereFollowingThreshold = 3;

String _dismissKey(String userId) => 'aura.start_here.dismissed.$userId';

/// Whether this signed-in person should see "Start here" (2026-10-09).
///
/// Two of three people who signed up from one company in October got in,
/// looked for a minute or twelve, and left without a single follow, post or
/// reaction: Home showed them a quiet stream and nothing to do. "Start here"
/// shows until they follow a few people or say they are set, per ACCOUNT
/// (the activation overlay before it was remembered per device).
final startHereNeededProvider = FutureProvider.autoDispose<bool>((ref) async {
  if (!ref.watch(isAuthedProvider)) return false;
  final me = await ref.watch(authMeDataProvider.future);
  final user = me['user'] is Map ? Map<String, dynamic>.from(me['user'] as Map) : me;
  final userId = (user['id'] ?? '').toString();
  final handle = (user['handle'] ?? '').toString();
  if (userId.isEmpty || handle.isEmpty) return false;
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_dismissKey(userId)) == true) return false;
  } catch (_) {
    // No local storage (private window): fall through to the follow count.
  }
  final counts = await ref.watch(followsRepositoryProvider).personFollowCounts(handle);
  return counts.following < kStartHereFollowingThreshold;
});

final _startHereInstitutionsProvider = FutureProvider.autoDispose<DiscoverPage<DiscoveredInstitution>>(
  (ref) => ref.read(discoverRepositoryProvider).institutions(limit: 2),
);

/// START HERE — the first minutes for a new person.
///
/// Public-first: people and institutions to follow, a question to ask, a
/// space to join. Every row does something; nothing explains the product.
class StartHereCard extends ConsumerWidget {
  const StartHereCard({super.key});

  Future<void> _dismiss(WidgetRef ref) async {
    final me = ref.read(authMeDataProvider).valueOrNull ?? const <String, dynamic>{};
    final user = me['user'] is Map ? Map<String, dynamic>.from(me['user'] as Map) : me;
    final userId = (user['id'] ?? '').toString();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_dismissKey(userId), true);
    } catch (_) {
      // Nothing to remember it in; it hides for this visit only.
    }
    ref.invalidate(startHereNeededProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final needed = ref.watch(startHereNeededProvider).valueOrNull ?? false;
    if (!needed) return const SizedBox.shrink();

    final people = ref.watch(peopleDiscoveryProvider).valueOrNull;
    final institutions = ref.watch(_startHereInstitutionsProvider).valueOrNull;
    final suggestions = (people?.suggestions ?? const []).where((s) => s.followState == 'NONE').take(3).toList();
    final orgs = (institutions?.items ?? const <DiscoveredInstitution>[]).where((i) => !i.viewerFollows).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: AuraSpace.s16),
      padding: const EdgeInsets.all(AuraSpace.s16),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Start here', style: AuraText.title.copyWith(fontSize: 18))),
              TextButton(onPressed: () => _dismiss(ref), child: const Text("I'm set")),
            ],
          ),
          const SizedBox(height: AuraSpace.s4),
          Text(
            'Follow a few people and institutions, and what they say appears on Home.',
            style: AuraText.body.copyWith(color: AuraSurface.muted, height: 1.4),
          ),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s12),
            for (final s in suggestions) ...[
              PersonSuggestionCard(suggestion: s),
              const SizedBox(height: AuraSpace.s8),
            ],
          ],
          if (orgs.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s4),
            for (final i in orgs) ...[
              InstitutionPresenceCard(institution: i),
              const SizedBox(height: AuraSpace.s8),
            ],
          ],
          const SizedBox(height: AuraSpace.s8),
          Wrap(
            spacing: AuraSpace.s8,
            runSpacing: AuraSpace.s8,
            children: [
              AuraSecondaryButton(
                label: 'More people',
                onPressed: () => context.push(NavigationAuthority.discoverPeopleRoute),
              ),
              AuraSecondaryButton(
                label: 'More institutions',
                onPressed: () => context.push(NavigationAuthority.discoverInstitutionsRoute),
              ),
              AuraSecondaryButton(
                label: 'Ask a question',
                onPressed: () => context.push(
                  Uri(path: NavigationAuthority.composeRoute, queryParameters: const {'intent': 'ask'}).toString(),
                ),
              ),
              AuraSecondaryButton(
                label: 'Find a space',
                onPressed: () => context.push(NavigationAuthority.spacesRoute),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
