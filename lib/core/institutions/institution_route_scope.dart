import 'package:flutter/material.dart';

import '../diagnostics/route_probe.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../product/product_state.dart';
import '../product/product_state_view.dart';
import 'institution_route_authority.dart';

/// THE BOUNDARY BETWEEN A PRODUCT ADDRESS AND A PERSISTENCE ID.
///
/// Founder ruling (2026-08-23) and the regression that proved it necessary.
///
/// The workspace URL carries the institution's canonical ADDRESS — its slug.
/// Every institution API is keyed by the institution's persistence ID. Before
/// this existed, each screen took the raw path segment and handed it to its
/// data layer, so the moment navigation started minting slugs every workspace
/// screen queried `institutionId = 'aura-platform-llc'`, matched nothing, and
/// the institution became unreachable while its data sat untouched.
///
/// So the conversion happens HERE, once, at the route boundary:
///
///     route address (slug | historical slug | legacy id)
///       → canonical institution id
///       → screen, which only ever sees an id
///
/// A screen cannot accidentally satisfy both contracts with one ambiguous
/// String any more, because it is never handed the address at all.
///
/// UNKNOWN IS NOT UNAUTHORIZED (RC2 / F065 / F068). While standing is still
/// resolving this renders a bounded loading state rather than mounting a screen
/// against an address it cannot yet resolve — mounting early is what turns a
/// pending answer into a failed API call and then into a false denial.
class InstitutionRouteScope extends ConsumerWidget {
  const InstitutionRouteScope({
    super.key,
    required this.address,
    required this.builder,
  });

  /// The raw path segment. May be the current slug, a historical slug, a
  /// legacy persistence id, or a case variant.
  final String? address;

  /// Receives the CANONICAL INSTITUTION ID. Never the address.
  final Widget Function(String institutionId) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    RouteProbe.emit('instScope.build', {'address': address});
    final snapshot = ref.watch(institutionAuthoritySnapshotProvider);

    // Still finding out. Not "no institution" — deciding here is the RC2
    // defect that made refresh unsurvivable.
    if (!snapshot.resolved) {
      RouteProbe.emit('instScope.unresolved');
      return const AuraProductState(
          state: ProductState.loading, headline: 'Loading [A: authority]');
    }

    final resolved = resolveInstitutionAddress(snapshot, address);
    RouteProbe.emit('instScope.localResolve',
        {'hit': resolved != null, 'id': resolved?.institutionId});
    if (resolved != null) return builder(resolved.institutionId);

    // The snapshot cannot resolve it — a historical slug, or an institution
    // this person does not hold. The server-side resolver is the authority for
    // the first case, so ask it rather than concluding anything here.
    final remote = ref.watch(
      remoteInstitutionAddressProvider((address ?? '').trim()),
    );

    RouteProbe.emit('instScope.remote', {
      'loading': remote.isLoading,
      'hasValue': remote.hasValue,
      'hasError': remote.hasError,
    });
    return remote.when(
      loading: () => const AuraProductState(
          state: ProductState.loading, headline: 'Loading [B: address]'),
      // An error is resolved-but-unknown, never an eternal spinner (F068).
      error: (_, __) => const AuraProductState(
        state: ProductState.empty,
        headline: 'That institution could not be found',
      ),
      data: (institutionId) {
        if (institutionId == null) {
          return const AuraProductState(
            state: ProductState.empty,
            headline: 'That institution could not be found',
          );
        }
        return builder(institutionId);
      },
    );
  }
}
