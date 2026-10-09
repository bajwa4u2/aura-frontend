import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../product/product_state.dart';
import '../product/product_state_view.dart';
import '../ui/aura_space.dart';
import '../ui/aura_surface.dart';
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
    final snapshot = ref.watch(institutionAuthoritySnapshotProvider);

    // Still finding out. Not "no institution" — deciding here is the RC2
    // defect that made refresh unsurvivable.
    if (!snapshot.resolved) return const _WorkspaceOutline();

    final resolved = resolveInstitutionAddress(snapshot, address);
    if (resolved != null) return builder(resolved.institutionId);

    // The snapshot cannot resolve it — a historical slug, or an institution
    // this person does not hold. The server-side resolver is the authority for
    // the first case, so ask it rather than concluding anything here.
    final remote = ref.watch(
      remoteInstitutionAddressProvider((address ?? '').trim()),
    );

    return remote.when(
      loading: () => const _WorkspaceOutline(),
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

/// While the address resolves: an outline of a workspace page in place (a
/// title, a tabs row, three rows), never a centred "Just a moment" (DD-43).
/// Built from core tokens so core does not depend on the workspace feature;
/// it mirrors `WorkspaceLoading` there.
class _WorkspaceOutline extends StatelessWidget {
  const _WorkspaceOutline();

  @override
  Widget build(BuildContext context) {
    Widget bar(double w, double h, {double r = 6}) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(color: AuraSurface.elevated, borderRadius: BorderRadius.circular(r)),
        );
    Widget row() => Container(
          margin: const EdgeInsets.only(bottom: AuraSpace.s8),
          padding: const EdgeInsets.all(AuraSpace.s14),
          decoration: BoxDecoration(
            color: AuraSurface.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AuraSurface.divider),
          ),
          child: Row(children: [
            Container(width: 36, height: 36, decoration: const BoxDecoration(color: AuraSurface.elevated, shape: BoxShape.circle)),
            const SizedBox(width: AuraSpace.s12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                bar(200, 12),
                const SizedBox(height: AuraSpace.s8),
                bar(120, 10),
              ]),
            ),
          ]),
        );
    return Semantics(
      label: 'Loading',
      child: Material(
        color: AuraSurface.page,
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880 + 2 * AuraSpace.s32),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AuraSpace.s32, AuraSpace.s24, AuraSpace.s32, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(alignment: Alignment.centerLeft, child: bar(180, 24)),
                  const SizedBox(height: AuraSpace.s8),
                  Align(alignment: Alignment.centerLeft, child: bar(280, 12)),
                  const SizedBox(height: AuraSpace.s20),
                  Row(children: [bar(90, 32, r: 16), const SizedBox(width: AuraSpace.s8), bar(90, 32, r: 16)]),
                  const SizedBox(height: AuraSpace.s20),
                  row(),
                  row(),
                  row(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
