import '../../../core/trust/trust_marks.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/net/dio_provider.dart';
import '../../../core/product/product_language.dart';
import '../../../core/product/product_state.dart';
import '../../../core/product/product_state_view.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/identity/person_identity_model.dart';

/// DISCOVER → PEOPLE = personalized human discovery, with search always
/// available (founder-frozen 2026-08-16). Suggestions come from the
/// canonical /v1/discover/people projection (deterministic, explainable,
/// privacy-safe); search remains its own always-available mechanism.
/// Reasons render quietly; no mechanics, no leaderboards, no "Creators".
class PeopleDiscoveryScreen extends ConsumerWidget {
  const PeopleDiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(_peopleDiscoveryProvider);

    return AuraScaffold(
      showHeader: false,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(_peopleDiscoveryProvider),
        child: ListView(
          padding: const EdgeInsets.all(AuraSpace.s16),
          children: [
            const Text('People', style: AuraText.display),
            const SizedBox(height: AuraSpace.s6),
            Text(
              'Find people to follow and talk with.',
              style: AuraText.body.copyWith(color: AuraSurface.muted),
            ),
            const SizedBox(height: AuraSpace.s14),
            // SEARCH ALWAYS AVAILABLE — intentional lookup is its own door.
            InkWell(
              onTap: () => context.push('/search'),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AuraSpace.s16, vertical: AuraSpace.s12),
                decoration: BoxDecoration(
                  color: AuraSurface.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AuraSurface.divider),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, color: AuraSurface.muted),
                    const SizedBox(width: AuraSpace.s10),
                    Text('Search for someone…',
                        style:
                            AuraText.body.copyWith(color: AuraSurface.muted)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AuraSpace.s20),
            page.when(
              loading: () => const AuraProductState(
                  state: ProductState.loading, subject: ProductNoun.person),
              error: (e, _) => AuraProductState(
                state: ProductState.retryableError,
                subject: ProductNoun.person,
                detail: 'Search is still available above.',
                onRecover: () => ref.invalidate(_peopleDiscoveryProvider),
              ),
              data: (data) {
                final suggestions = data.suggestions;
                if (suggestions.isEmpty) {
                  return const AuraProductState(
                    state: ProductState.empty,
                    subject: ProductNoun.person,
                    headline: 'No suggestions yet',
                    detail:
                        'As you follow people and take part in Spaces, Aura '
                        'gets better at suggesting people worth meeting. '
                        'Search is always available.',
                    icon: Icons.groups_outlined,
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.coldStart
                          ? 'Active on Aura — a starting point while Aura '
                              'learns what matters to you'
                          : 'Suggested for you',
                      style: AuraText.title,
                    ),
                    const SizedBox(height: AuraSpace.s10),
                    for (final s in suggestions) _PersonCard(suggestion: s),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonSuggestion {
  const _PersonSuggestion({
    required this.person,
    required this.reasons,
    required this.followState,
  });

  /// THE PERSON, WHOLE. This used to hold three scalars copied off the
  /// canonical identity — userId, handle, displayName — which is the
  /// partial-adoption pattern: the canonical reader was called and then most
  /// of what it returned was thrown away, so a suggested person appeared as
  /// an initial with no verification while the same human rendered fully
  /// elsewhere. Holding the identity itself makes that impossible.
  final AuraPersonIdentity person;

  /// Discovery state — what this surface adds, never who the person is.
  final List<String> reasons;
  final String followState;

  String get userId => person.userId;
  String? get handle => person.handle.isEmpty ? null : person.handle;
  String get displayName => person.label;
}

class _PeoplePage {
  const _PeoplePage({required this.suggestions, required this.coldStart});
  final List<_PersonSuggestion> suggestions;
  final bool coldStart;
}

final _peopleDiscoveryProvider =
    FutureProvider.autoDispose<_PeoplePage>((ref) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get<dynamic>('/discover/people');
  final data = res.data is Map<String, dynamic> &&
          (res.data as Map<String, dynamic>)['data'] is Map<String, dynamic>
      ? (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>
      : res.data as Map<String, dynamic>;
  return _PeoplePage(
    coldStart: data['coldStart'] == true,
    suggestions: (data['suggestions'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        // F053/F116 — the identity half of a suggestion is read canonically
        // and KEPT canonical; `reasons` and `followState` are discovery
        // state, not identity, and stay on the suggestion beside it.
        .map((j) => _PersonSuggestion(
              person: AuraPersonIdentity.fromJson(j),
              reasons: (j['reasons'] as List<dynamic>? ?? const [])
                  .map((r) => r.toString())
                  .toList(),
              followState: (j['followState'] ?? 'NONE').toString(),
            ))
        .toList(),
  );
});

class _PersonCard extends ConsumerStatefulWidget {
  const _PersonCard({required this.suggestion});
  final _PersonSuggestion suggestion;

  @override
  ConsumerState<_PersonCard> createState() => _PersonCardState();
}

class _PersonCardState extends ConsumerState<_PersonCard> {
  String? _localState;
  bool _busy = false;

  /// Canonical Follow action — POST /follows against the user target; the
  /// card re-renders from the server truth (FOLLOWING or REQUESTED), never
  /// from an optimistic guess.
  Future<void> _follow() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post<dynamic>('/follows', data: {
        'targetType': 'USER',
        'targetUserId': widget.suggestion.userId,
      });
      final body = res.data is Map<String, dynamic>
          ? ((res.data['data'] ?? res.data) as Map<String, dynamic>)
          : const <String, dynamic>{};
      final status = (body['status'] ?? body['state'] ?? '').toString();
      setState(() => _localState =
          status.toUpperCase().contains('PEND') ? 'REQUESTED' : 'FOLLOWING');
    } on DioException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not follow — try again.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.suggestion;
    final state = _localState ?? s.followState;
    return Container(
      margin: const EdgeInsets.only(bottom: AuraSpace.s8),
      padding: const EdgeInsets.all(AuraSpace.s12),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Row(
        children: [
          AuraAvatar(
            name: s.displayName,
            imageUrl: s.person.avatarUrl,
            size: 44,
          ),
          const SizedBox(width: AuraSpace.s12),
          Expanded(
            child: InkWell(
              onTap: s.handle == null
                  ? null
                  : () => context.push('/u/${s.handle}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Choosing whom to follow is a trust decision, so the
                  // canonical verification travels with the name.
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          s.displayName,
                          overflow: TextOverflow.ellipsis,
                          style: AuraText.body
                              .copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (s.person.verification.hasAny) ...[
                        const SizedBox(width: AuraSpace.s4),
                        PersonVerificationMarks(
                          verification: s.person.verification,
                          size: TrustMarkSize.micro,
                        ),
                      ],
                    ],
                  ),
                  if (s.reasons.isNotEmpty)
                    Text(
                      s.reasons.first,
                      style:
                          AuraText.micro.copyWith(color: AuraSurface.muted),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AuraSpace.s8),
          switch (state) {
            'FOLLOWING' => Text('Following',
                style: AuraText.small.copyWith(color: AuraSurface.muted)),
            'REQUESTED' => Text('Requested',
                style: AuraText.small.copyWith(color: AuraSurface.muted)),
            _ => AuraSecondaryButton(
                label: _busy ? '…' : 'Follow',
                onPressed: _busy ? null : _follow,
              ),
          },
        ],
      ),
    );
  }
}
