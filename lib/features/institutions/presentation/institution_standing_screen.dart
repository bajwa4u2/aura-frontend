import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/institutions/institution_access_provider.dart';
import '../../../core/institutions/institution_route_authority.dart';
import '../../../core/product/product_state.dart';
import '../../../core/product/product_state_view.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_scaffold.dart';

/// INSTITUTION STANDING — the non-workspace answer.
///
/// Founder ruling D5/D6 (2026-08-23). Terminal denial and "you hold no
/// institution" used to resolve to `/institution/dashboard`, which is also the
/// Overview. Three distinct meanings arrived at one address, and once Overview
/// became an ADMIN destination a refusal would have landed a person on an
/// administrative surface.
///
/// So this exists as its own destination. It explains standing truthfully and
/// does **not** pretend the person entered the workspace: no rail, no
/// operational chrome, nothing branded as institution administration.
///
/// RC4 — TERMINAL DENIAL IS TERMINAL. There is deliberately nothing to return
/// to here. Standing inside an institution is granted by that institution,
/// never by arriving at a screen, so no preserved navigation intent may defeat
/// the denial by carrying someone onward.
///
/// Denial and no-affiliation share this presentation, but they are not the
/// same statement and are not conflated: one is "that institution has not
/// granted you this", the other is "there is nothing to enter and nobody has
/// said no".
enum InstitutionStandingReason {
  /// An institution refused this destination, or the authority for it changed.
  denied,

  /// The person holds no institution at all.
  noAffiliation,
}

InstitutionStandingReason institutionStandingReasonFrom(String? wire) {
  return (wire ?? '').trim().toLowerCase() == 'denied'
      ? InstitutionStandingReason.denied
      : InstitutionStandingReason.noAffiliation;
}

class InstitutionStandingScreen extends ConsumerWidget {
  const InstitutionStandingScreen({super.key, this.reason});

  final InstitutionStandingReason? reason;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolved = ref.watch(myAffiliationsResolvedProvider);
    final affiliations = ref.watch(myAffiliationsProvider);

    // UNKNOWN IS NOT ABSENT. Saying "you hold no institution" while the answer
    // is still in flight is its own untruth, so a still-resolving read shows
    // as resolving rather than as a denial.
    if (!resolved) {
      return AuraScaffold(
        title: 'Institution access',
        showHomeAction: true,
        body: const AuraProductState(state: ProductState.loading),
      );
    }

    final wasDenied = reason == InstitutionStandingReason.denied;

    return AuraScaffold(
      title: 'Institution access',
      showHomeAction: true,
      body: AuraProductState(
        state: ProductState.empty,
        icon: wasDenied ? Icons.lock_outline_rounded : Icons.domain_outlined,
        headline: wasDenied
            ? 'You do not have access to that'
            : 'You are not part of an institution yet',
        detail: wasDenied
            ? _deniedDetail(affiliations.length)
            : 'Institutions invite the people who speak, host and administer '
                'on their behalf. When one adds you, it appears here.',
        // Deliberately no "return" action: standing is granted by the
        // institution, never by navigating back to the address that refused.
        action: affiliations.isEmpty
            ? null
            : AuraSecondaryButton(
                label: 'Go to your institution',
                icon: Icons.arrow_forward_rounded,
                // The Navigation Authority owns institution entry; standing
                // must not mint its own address for it.
                onPressed: () => context.go(
                  institutionEntryDestination(affiliations.first.id),
                ),
              ),
      ),
    );
  }

  String _deniedDetail(int affiliationCount) {
    const base =
        'That part of the institution needs authority you have not been '
        'granted. Only the institution can change that.';
    return affiliationCount > 0
        ? '$base You still have full access to everything your standing does '
            'include.'
        : base;
  }
}
