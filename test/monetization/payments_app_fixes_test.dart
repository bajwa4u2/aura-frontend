import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/errors/app_error.dart';
import 'package:aura/core/institutions/institution_route_authority.dart';
import 'package:aura/core/net/dio_provider.dart';
import 'package:aura/features/composition/presentation/composition_assist.dart';
import 'package:aura/features/institutions/posts/institution_post_composer_screen.dart';
import 'package:aura/features/institutions/presentation/institution_members_screen.dart';
import 'package:aura/features/monetization/domain/monetization_models.dart';
import 'package:aura/features/monetization/domain/monetization_refusal_copy.dart';
import 'package:aura/features/monetization/presentation/institution_billing_screen.dart';
import 'package:aura/features/monetization/providers/monetization_providers.dart';

/// Payments app fixes (2026-10-08), before Aura switches on paid plans:
/// the return from checkout, refusals that must not freeze the app, and the
/// sentences a plan or allowance refusal shows.

final _config = MonetizationConfig.fromJson({
  'monetizationMode': 'visible',
  'tiers': [
    {
      'tier': 'COMMUNITY',
      'label': 'Community',
      'audience': 'Community audience',
      'seatLimit': 3,
      'monthlyAllowance': 1000,
      'monthlyCents': 4900,
      'yearlyCents': 49000,
      'monthlyProductCode': 'AURA_PLAN_COMMUNITY_MONTHLY',
      'yearlyProductCode': 'AURA_PLAN_COMMUNITY_YEARLY',
    },
  ],
  'creditPacks': const [],
});

InstitutionEntitlements _ent(Map<String, dynamic> j) =>
    InstitutionEntitlements.fromJson({
      'institutionId': 'inst',
      'monetizationMode': 'visible',
      ...j,
    });

DioException _refused(int status, Object? body) {
  final req = RequestOptions(path: '/x');
  return DioException(
    requestOptions: req,
    response: Response(requestOptions: req, statusCode: status, data: body),
    type: DioExceptionType.badResponse,
  );
}

Future<void> _pumpBilling(
  WidgetTester tester, {
  required Future<InstitutionEntitlements> Function() entitlements,
  CheckoutReturn checkoutReturn = CheckoutReturn.none,
  void Function()? onGrantRead,
}) async {
  tester.view
    ..physicalSize = const Size(1280, 2600)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        monetizationConfigProvider.overrideWith((ref) async => _config),
        institutionEntitlementProvider(
          'inst',
        ).overrideWith((ref) => entitlements()),
        institutionGrantProvider('inst').overrideWith((ref) async {
          onGrantRead?.call();
          return null;
        }),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: InstitutionBillingScreen(
            institutionId: 'inst',
            checkoutReturn: checkoutReturn,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('1. the return from checkout', () {
    test('only the server says a payment was received (2026-10-08)', () {
      String say(String? status, {bool gaveUp = false}) => checkoutReturnMessage(
            result: CheckoutReturn.success,
            serverStatus: status,
            gaveUp: gaveUp,
            hasSession: true,
          ).text;
      expect(say(null), 'Confirming your payment…');
      expect(say('CONFIRMING'), 'Confirming your payment…');
      expect(checkoutReturnMessage(result: CheckoutReturn.success, serverStatus: 'PAID', hasSession: true).confirmed, isTrue);
      expect(say('PROCESSING'), contains('bank payment is being processed'));
      expect(say('OPEN'), 'This checkout was not completed. Nothing was charged.');
      expect(say('FAILED'), 'This payment did not go through. Nothing was charged.');
      expect(say(null, gaveUp: true), startsWith('We could not confirm a payment yet'));
      for (final s in [null, 'CONFIRMING', 'PROCESSING', 'OPEN', 'FAILED', 'REFUNDED']) {
        expect(
          checkoutReturnMessage(result: CheckoutReturn.success, serverStatus: s, hasSession: true).confirmed,
          isFalse,
          reason: '$s is not a received payment',
        );
      }
      expect(
        checkoutReturnMessage(result: CheckoutReturn.cancelled).text,
        'Checkout was cancelled. Nothing was charged.',
      );
    });

    test('reads ?checkout= into what happened', () {
      expect(checkoutReturnFrom('success'), CheckoutReturn.success);
      expect(checkoutReturnFrom('cancelled'), CheckoutReturn.cancelled);
      expect(checkoutReturnFrom('canceled'), CheckoutReturn.cancelled);
      expect(checkoutReturnFrom(null), CheckoutReturn.none);
      expect(checkoutReturnFrom('anything'), CheckoutReturn.none);
    });

    test('a canonical redirect keeps the query the link carried', () {
      final from = Uri.parse('/institution/Inst-Id/billing?checkout=success');
      expect(
        carryQuery('/institution/inst/billing', from),
        '/institution/inst/billing?checkout=success',
      );
      expect(
        carryQuery('/institution/inst/billing', Uri.parse('/x')),
        '/institution/inst/billing',
      );
      // A target with its own query is not rewritten.
      expect(carryQuery('/a?b=1', from), '/a?b=1');
    });

    testWidgets('success: a calm word, and the plan is re-read until it '
        'changes', (tester) async {
      var reads = 0;
      await _pumpBilling(
        tester,
        checkoutReturn: CheckoutReturn.success,
        entitlements: () async {
          reads++;
          // The webhook lands after the second re-read.
          return reads >= 3
              ? _ent({'plan': 'PRO', 'planTier': 'COMMUNITY'})
              : _ent({'plan': 'FREE'});
        },
      );

      // No session id on this link: the page does not claim a payment.
      expect(
        find.text(
          'We could not confirm a payment yet. If you paid, it will show '
          'here shortly.',
        ),
        findsOneWidget,
      );
      expect(find.text('Free'), findsOneWidget);
      expect(reads, 1);

      for (var i = 0; i < 3; i++) {
        await tester.pump(kCheckoutRefreshInterval);
        await tester.pumpAndSettle();
      }
      expect(find.text('Pro · Community'), findsOneWidget);
      final settledAt = reads;

      // Once the plan has changed, nothing more is asked.
      for (var i = 0; i < 6; i++) {
        await tester.pump(kCheckoutRefreshInterval);
      }
      await tester.pumpAndSettle();
      expect(reads, settledAt);
    });

    testWidgets('success: re-reading stops after about thirty seconds even '
        'when nothing changes', (tester) async {
      var reads = 0;
      await _pumpBilling(
        tester,
        checkoutReturn: CheckoutReturn.success,
        entitlements: () async {
          reads++;
          return _ent({'plan': 'FREE'});
        },
      );
      for (var i = 0; i < 12; i++) {
        await tester.pump(kCheckoutRefreshInterval);
        await tester.pumpAndSettle();
      }
      expect(reads, 1 + kCheckoutRefreshLimit);
    });

    testWidgets('cancelled: says nothing was charged, and asks nothing more',
        (tester) async {
      var reads = 0;
      await _pumpBilling(
        tester,
        checkoutReturn: CheckoutReturn.cancelled,
        entitlements: () async {
          reads++;
          return _ent({'plan': 'FREE'});
        },
      );
      expect(
        find.text('Checkout was cancelled. Nothing was charged.'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(reads, 1);
    });

    testWidgets('no banner on an ordinary visit', (tester) async {
      await _pumpBilling(
        tester,
        entitlements: () async => _ent({'plan': 'FREE'}),
      );
      expect(find.textContaining('Payment received'), findsNothing);
      expect(find.textContaining('Checkout was cancelled'), findsNothing);
    });

    testWidgets('coming back to the tab re-reads the plan and the grant',
        (tester) async {
      var reads = 0;
      var grantReads = 0;
      await _pumpBilling(
        tester,
        entitlements: () async {
          reads++;
          return _ent({'plan': 'FREE'});
        },
        onGrantRead: () => grantReads++,
      );
      expect([reads, grantReads], [1, 1]);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect([reads, grantReads], [2, 2]);
    });
  });

  group('2. a per-feature refusal never freezes the app', () {
    test('a bare 429 is the host rate limiting', () {
      final req = RequestOptions(path: '/x');
      expect(
        isHostWideRateLimit(Response(requestOptions: req, statusCode: 429)),
        isTrue,
      );
      expect(
        isHostWideRateLimit(
          Response(
            requestOptions: req,
            statusCode: 429,
            data: {'message': 'Too many requests'},
          ),
        ),
        isTrue,
      );
    });

    test('a 429 that names a code is one feature saying no', () {
      final req = RequestOptions(path: '/x');
      for (final body in <Object>[
        {'code': 'FAIR_USE_DAILY_LIMIT', 'message': 'm'},
        {
          'ok': false,
          'error': {'code': 'FAIR_USE_DAILY_LIMIT', 'message': 'm'},
        },
        '{"ok":false,"error":{"code":"FAIR_USE_DAILY_LIMIT"}}',
      ]) {
        expect(
          isHostWideRateLimit(
            Response(requestOptions: req, statusCode: 429, data: body),
          ),
          isFalse,
          reason: '$body',
        );
      }
      expect(
        isHostWideRateLimit(Response(requestOptions: req, statusCode: 403)),
        isFalse,
      );
    });

    test('writing checks show sentences, never the exception', () {
      const fallback = 'Writing review could not run. Try again.';
      expect(
        compositionAssistErrorText(
          _refused(403, {
            'code': 'FAIR_USE_DAILY_LIMIT',
            'message': 'Daily limit reached.',
          }),
          fallback: fallback,
        ),
        kFairUseDailyLimitSentence,
      );
      expect(
        compositionAssistErrorText(
          _refused(402, {
            'ok': false,
            'error': {'code': 'CREDITS_REQUIRED', 'message': 'No credits.'},
          }),
          fallback: fallback,
        ),
        kAllowanceUsedSentence,
      );
      expect(
        compositionAssistErrorText(
          _refused(403, {
            'ok': false,
            'error': {
              'code': 'NOT_ACTING_FOR_INSTITUTION',
              'message': 'You are not acting for this institution.',
            },
          }),
          fallback: fallback,
        ),
        'You are not acting for this institution.',
      );
      // The server's own sentence where it sent one.
      expect(
        compositionAssistErrorText(
          _refused(400, {'message': 'Text is too long.'}),
          fallback: fallback,
        ),
        'Text is too long.',
      );
      // No body, a 5xx, or a non-Dio failure: the plain sentence.
      final dropped = DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.connectionError,
        message: 'SocketException: Failed host lookup',
      );
      for (final e in <Object>[
        dropped,
        _refused(500, {'message': 'Internal server error'}),
        Exception('Translation was empty.'),
      ]) {
        final text = compositionAssistErrorText(e, fallback: fallback);
        expect(text, fallback);
        expect(text, isNot(contains('Exception')));
      }
      // The code survives the interceptor's mapping even without a body.
      final mapped = DioException(
        requestOptions: RequestOptions(path: '/x'),
        error: const AppError(
          type: AppErrorType.forbidden,
          message: 'x',
          code: 'FAIR_USE_DAILY_LIMIT',
        ),
      );
      expect(
        compositionAssistErrorText(mapped, fallback: fallback),
        kFairUseDailyLimitSentence,
      );
    });
  });

  group('4. seat and plan refusals', () {
    test('members read the message inside the error envelope', () {
      const seat =
          'Your plan has 3 staff seats and all are in use. Remove an '
          'administrator or choose a larger plan.';
      expect(
        institutionMembersErrorMessage(
          _refused(403, {
            'ok': false,
            'error': {'code': 'SEAT_LIMIT_REACHED', 'message': seat},
          }),
          'Could not update role.',
        ),
        seat,
      );
      expect(
        institutionMembersErrorMessage(
          _refused(400, {'message': 'Flat message.'}),
          'Could not update role.',
        ),
        'Flat message.',
      );
      expect(
        institutionMembersErrorMessage(Exception('x'), 'Could not load.'),
        'Could not load.',
      );
    });

    test('publishing refusals use the decided sentences', () {
      expect(
        institutionPublishRefusalCopy('PLAN_REQUIRED_PRO', serverMessage: 'x'),
        kOfficialVoiceNeedsProSentence,
      );
      expect(
        institutionPublishRefusalCopy('CREDITS_REQUIRED', serverMessage: 'x'),
        kAllowanceUsedSentence,
      );
      expect(
        institutionPublishRefusalCopy(
          'SEAT_LIMIT_REACHED',
          serverMessage: 'All 3 staff seats are in use.',
        ),
        'All 3 staff seats are in use.',
      );
      // The retired member-limit code has no sentence of its own any more.
      expect(
        institutionPublishRefusalCopy('MEMBER_LIMIT_REACHED', serverMessage: ''),
        isNull,
      );
      for (final s in [
        kOfficialVoiceNeedsProSentence,
        kAllowanceUsedSentence,
        kFairUseDailyLimitSentence,
      ]) {
        expect(s.toLowerCase(), isNot(contains('upgrade')));
        expect(s.toLowerCase(), isNot(contains('buy')));
      }
    });
  });

  group('5. the plan card', () {
    testWidgets('a Pro institution with no recorded tier reads Pro',
        (tester) async {
      await _pumpBilling(
        tester,
        entitlements: () async => _ent({'plan': 'PRO', 'planTier': null}),
      );
      expect(find.text('Pro'), findsOneWidget);
      expect(find.text('Free'), findsNothing);
    });

    testWidgets('a Pro tier the config does not list still reads Pro',
        (tester) async {
      await _pumpBilling(
        tester,
        entitlements: () async =>
            _ent({'plan': 'PRO', 'planTier': 'PUBLIC_BODY_LARGE'}),
      );
      expect(find.text('Pro'), findsOneWidget);
      expect(find.text('Free'), findsNothing);
    });
  });
}
