import 'dart:io';

import 'package:aura/core/institutions/institution_space_route_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// SPACE ADDRESS → PERSISTENCE ID, RESOLVED ONCE AT THE BOUNDARY.
///
/// Founder ruling §9 (2026-08-23), and the lesson the Institution regression
/// paid for: every Space API is keyed by the Space's id, so if a screen is
/// handed the raw path segment it will ask its data layer for
/// `spaceId = 'general'`, match nothing, and the Space becomes unreachable
/// while its data sits untouched.
///
/// These prove the screen is never handed the address at all.
void main() {
  Widget harness(WidgetRef Function()? _, {required Widget child}) =>
      MaterialApp(home: Scaffold(body: child));

  ProviderScope scoped({
    required SpaceAddress? resolution,
    required Widget child,
  }) {
    return ProviderScope(
      overrides: [
        remoteSpaceAddressProvider
            .overrideWith((ref, key) async => resolution),
      ],
      child: child,
    );
  }

  testWidgets('the screen receives the ID, never the address', (tester) async {
    String? received;

    await tester.pumpWidget(
      scoped(
        resolution: const SpaceAddress(
          spaceId: 'cmk0space1',
          canonicalSlug: 'general',
          isCanonical: true,
        ),
        child: harness(
          null,
          child: InstitutionSpaceRouteScope(
            institutionId: 'cmk0inst1',
            address: 'general',
            builder: (entry) {
              received = entry.spaceId;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(received, 'cmk0space1');
    // The point of the boundary: the address is consumed here and cannot
    // reach a data layer that would query it as a key.
    expect(received, isNot('general'));
  });

  testWidgets('an unresolvable address is EMPTY, not a spinner', (tester) async {
    // Resolved-but-unknown is a real answer. Leaving it loading forever is the
    // F068 defect; treating it as a denial is the RC2 one.
    await tester.pumpWidget(
      scoped(
        resolution: null,
        child: harness(
          null,
          child: InstitutionSpaceRouteScope(
            institutionId: 'cmk0inst1',
            address: 'nothing-here',
            builder: (_) => const Text('SHOULD NOT MOUNT'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SHOULD NOT MOUNT'), findsNothing);
    expect(find.textContaining('could not be found'), findsOneWidget);
  });

  testWidgets('an empty segment never reaches the network', (tester) async {
    var asked = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          remoteSpaceAddressProvider.overrideWith((ref, key) async {
            asked = true;
            return null;
          }),
        ],
        child: harness(
          null,
          child: const InstitutionSpaceRouteScope(
            institutionId: 'cmk0inst1',
            address: '',
            builder: _neverBuilds,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(asked, isFalse);
    expect(find.textContaining('could not be found'), findsOneWidget);
  });

  test('the router resolves the Space address at the route boundary', () {
    // A structural check, because the widget tests above can only prove the
    // boundary WORKS — not that the route actually uses it. A future edit that
    // hands `state.pathParameters` straight to the screen would reintroduce
    // exactly the Institution regression, and would look perfectly ordinary.
    final router = File('lib/router.dart').readAsStringSync();

    // Bounded by the NEXT route declaration rather than by a character
    // budget: a fixed window stops matching the moment the route grows a
    // comment or a redirect, and a structural guard that silently stops
    // finding its subject is worse than no guard at all.
    final start =
        router.indexOf("path: '/institution/:institutionId/spaces/:spaceAddress'");
    final next = start < 0 ? -1 : router.indexOf('path: ', start + 10);
    final spaceRoute =
        start < 0 ? null : router.substring(start, next < 0 ? router.length : next);

    expect(
      spaceRoute,
      isNotNull,
      reason: 'the institution Space route is no longer declared as expected',
    );
    expect(
      spaceRoute,
      contains('InstitutionSpaceRouteScope'),
      reason: 'the Space route must resolve its address at the boundary '
          'rather than handing the raw segment to the screen',
    );
    expect(
      spaceRoute,
      isNot(contains("spaceId: state.pathParameters")),
      reason: 'the screen must never receive the raw path segment as a '
          'space id — that is the Institution regression, repeated',
    );
  });
}

Widget _neverBuilds(SpaceAddress entry) => const Text('SHOULD NOT MOUNT');
