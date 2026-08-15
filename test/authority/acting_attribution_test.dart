import 'package:aura/core/authority/acting_attribution.dart';
import 'package:aura/core/authority/acting_context.dart';
import 'package:aura/core/authority/capability_projection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Certifies the founder-approved Option A pattern:
///
///   ACTING AUTHORITY BECOMES EXPLICIT WHEN A CONSEQUENTIAL ACTION REQUIRES
///   ATTRIBUTION — NOT BECAUSE OF THE ROUTE THE PERSON NAVIGATED THROUGH.
void main() {
  final authority = ActingContextAuthority(
    personId: 'p1',
    personDisplayName: 'Sam Rivera',
    institution: const InstitutionStanding(
      institutionId: 'i1',
      institutionName: 'Wayne County',
      effectiveCapabilities: {InstitutionCapabilityToken.publishOfficial},
      role: InstitutionRole.member,
    ),
  );

  Future<void> pump(WidgetTester tester, ActingResolution r) async {
    var selected = r.recommended!;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => ActingAttribution(
              resolution: r,
              selected: selected,
              onChanged: (o) => setState(() => selected = o),
              verb: 'Publishing',
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('single legitimate context states attribution and offers no choice',
      (tester) async {
    final r = authority.resolve(ConsequentialAct.publishInstitutionPost)!;
    expect(r.requiresExplicitChoice, isFalse);

    await pump(tester, r);

    expect(find.text('Publishing as'), findsOneWidget);
    expect(find.text('Wayne County'), findsOneWidget);
    // No unnecessary choice is introduced.
    expect(find.text('Switch identity'), findsNothing);
  });

  testWidgets('institutional attribution keeps the person visible',
      (tester) async {
    final r = authority.resolve(ConsequentialAct.publishInstitutionPost)!;
    await pump(tester, r);

    // The institution never appears to act by itself: the reason the acting
    // context exists is shown alongside it.
    expect(
      find.text('You hold this responsibility in this institution.'),
      findsOneWidget,
    );
    expect(r.recommended!.personId, 'p1');
  });

  testWidgets('multiple legitimate contexts require an explicit choice',
      (tester) async {
    final r = authority.resolve(
      ConsequentialAct.publishInstitutionPost,
      offerPersonalAlternative: true,
    )!;
    expect(r.requiresExplicitChoice, isTrue);

    await pump(tester, r);

    expect(find.text('Switch identity'), findsOneWidget);

    await tester.tap(find.text('Switch identity'));
    await tester.pumpAndSettle();

    // Both identities are offered, each explaining why it is available.
    expect(find.text('Sam Rivera'), findsOneWidget);
    expect(find.text('You are acting as yourself.'), findsOneWidget);

    await tester.tap(find.text('Sam Rivera'));
    await tester.pumpAndSettle();

    // The choice takes effect before the act is committed.
    expect(find.text('Sam Rivera'), findsOneWidget);
  });

  testWidgets('an unavailable act renders nothing at all', (tester) async {
    // Capability-Adaptive Experience: absent, not a disabled control.
    final none = ActingContextAuthority(
      personId: 'p1',
      personDisplayName: 'Sam Rivera',
      institution: const InstitutionStanding(
        institutionId: 'i1',
        institutionName: 'Wayne County',
        effectiveCapabilities: {},
        role: InstitutionRole.member,
      ),
    );
    final r = none.resolve(ConsequentialAct.publishInstitutionPost)!;
    expect(r.isAvailable, isFalse);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActingAttribution(
            resolution: r,
            selected: ActingOption(
              kind: ActingIdentityKind.person,
              id: 'p1',
              displayName: 'Sam Rivera',
              availability: ActingAvailability.personalDefault,
              personId: 'p1',
            ),
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Wayne County'), findsNothing);
    expect(find.text('Switch identity'), findsNothing);
  });
}
