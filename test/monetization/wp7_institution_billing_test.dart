import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/monetization/domain/monetization_models.dart';
import 'package:aura/features/monetization/presentation/institution_billing_screen.dart';
import 'package:aura/features/monetization/providers/monetization_providers.dart';

/// WP7 (2026-10-07): the institution's Plan & Billing page under the decided
/// model — public free, institutions pay for staff seats, an allowance and
/// an official voice; a 30-day grant on request; purchases on the web only.

Map<String, dynamic> _tier(String t, String label, int? seats, int cents) => {
  'tier': t,
  'label': label,
  'audience': '$label audience',
  'seatLimit': seats,
  'monthlyAllowance': 1000,
  'monthlyCents': cents,
  'yearlyCents': cents * 10,
  'monthlyProductCode': 'AURA_PLAN_${t}_MONTHLY',
  'yearlyProductCode': 'AURA_PLAN_${t}_YEARLY',
};

final _config = MonetizationConfig.fromJson({
  'monetizationMode': 'visible',
  'tiers': [
    _tier('COMMUNITY', 'Community', 3, 4900),
    _tier('ORGANISATION', 'Organisation', 15, 24900),
  ],
  'nonprofitDiscountPercent': 25,
  'creditPacks': [
    {'code': 'AURA_CREDITS_SMALL', 'credits': 1000, 'displayPrice': r'$19'},
  ],
});

InstitutionEntitlements _ent(Map<String, dynamic> j) =>
    InstitutionEntitlements.fromJson({
      'institutionId': 'inst',
      'monetizationMode': 'visible',
      ...j,
    });

Future<void> _pump(
  WidgetTester tester, {
  required InstitutionEntitlements ent,
  InstitutionGrant? grant,
}) async {
  tester.view
    ..physicalSize = const Size(1280, 2600)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        monetizationConfigProvider.overrideWith((ref) async => _config),
        institutionEntitlementProvider('inst').overrideWith((ref) async => ent),
        institutionGrantProvider('inst').overrideWith((ref) async => grant),
      ],
      child: const MaterialApp(
        home: Scaffold(body: InstitutionBillingScreen(institutionId: 'inst')),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('the wire', () {
    test('reads tiers, the discount, seats, the allowance and the grant', () {
      expect(_config.tiers.map((t) => t.tier), ['COMMUNITY', 'ORGANISATION']);
      expect(_config.tierByCode('ORGANISATION')!.seatLimit, 15);
      expect(_config.nonprofitDiscountPercent, 25);

      final e = _ent({
        'plan': 'PRO',
        'planTier': 'COMMUNITY',
        'seatLimit': 3,
        'seatsUsed': 2,
        'allowanceBalance': 640,
        'allowanceMonthly': 1000,
        'allowanceResetsAt': '2026-11-01T00:00:00.000Z',
        'grantEndsAt': null,
      });
      expect(
        [e.isPro, e.planTier, e.seatsUsed, e.allowanceBalance],
        [true, 'COMMUNITY', 2, 640],
      );
      expect(e.grantRunning, isFalse);

      final g = InstitutionGrant.fromJson({
        'id': 'g',
        'status': 'APPROVED',
        'requestedTier': 'COMMUNITY',
        'endsAt': DateTime.now().add(const Duration(days: 5)).toIso8601String(),
      });
      expect(g.running, isTrue);
    });

    test('calls and meetings are not metered: no per-minute costs remain', () {
      final costs = FeatureCosts.fromJson({'realtimeAudioPerMinute': 1});
      expect(costs.aiEditorShort, 0);
    });
  });

  group(
    'a store build shows what the institution has, never what it could buy',
    () {
      testWidgets(
        'iOS: no prices, no plan buttons, no top-ups, no destination',
        (tester) async {
          await _pump(
            tester,
            ent: _ent({'plan': 'FREE', 'seatLimit': 2, 'seatsUsed': 1}),
          );

          expect(find.textContaining(r'$'), findsNothing);
          expect(find.text('Choose'), findsNothing);
          expect(find.text('Buy'), findsNothing);
          expect(find.textContaining('auraplatform.org'), findsNothing);
          expect(
            find.text('Plans are not bought in this app'),
            findsOneWidget,
          );
          // The free grant may still be asked for: it is not a purchase.
          expect(find.text('Request the grant'), findsOneWidget);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );
    },
  );

  group('on the web', () {
    testWidgets(
      'the price list, the discount and top-ups are shown',
      (tester) async {
        await _pump(
          tester,
          ent: _ent({'plan': 'FREE', 'seatLimit': 2, 'seatsUsed': 1}),
        );

        expect(find.text(r'$49 / month'), findsOneWidget);
        expect(find.text('Choose'), findsNWidgets(2));
        expect(find.textContaining('pay 25% less'), findsOneWidget);
        expect(find.text('Buy'), findsOneWidget);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );

    testWidgets(
      'a paying institution changes tier on its subscription, never a second checkout',
      (tester) async {
        await _pump(
          tester,
          ent: _ent({
            'plan': 'PRO',
            'planTier': 'COMMUNITY',
            'seatLimit': 3,
            'seatsUsed': 2,
          }),
        );

        expect(find.text('Choose'), findsNothing);
        expect(find.text('Change'), findsOneWidget);
        expect(find.text('Manage billing'), findsOneWidget);
        expect(
          find.text('30-day grant'),
          findsNothing,
          reason: 'a paying institution is not offered the grant',
        );
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );

    testWidgets(
      'a used grant is not offered again',
      (tester) async {
        await _pump(
          tester,
          ent: _ent({'plan': 'FREE'}),
          grant: InstitutionGrant.fromJson({
            'id': 'g',
            'status': 'APPROVED',
            'requestedTier': 'COMMUNITY',
            'endsAt': '2026-09-01T00:00:00.000Z',
            'endedAt': '2026-09-01T00:00:00.000Z',
          }),
        );

        expect(find.text('Request the grant'), findsNothing);
        expect(
          find.text('This institution has had its 30-day grant.'),
          findsOneWidget,
        );
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  });
}
