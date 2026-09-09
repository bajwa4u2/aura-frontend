import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aura/core/auth/auth_providers.dart';
import 'package:aura/core/auth/session_bootstrap.dart';
import 'package:aura/core/auth/session_providers.dart';

/// IDENTITY IS THREE FACTS, AND ONLY ONE OF THEM IS A DOOR.
///
/// This file used to test a single boolean that stood for all three. The
/// boolean was `identityBaselineComplete`, the router gated ACCESS on it, and
/// the backend reported `true` off a date of birth alone — while the same
/// response listed the surname and jurisdiction as missing.
///
/// Making the backend honest about completeness is correct, and on its own it
/// would have sent every member who joined before Aura asked for a date of
/// birth straight into a completion wall. That is nearly the whole platform.
///
/// Founder correction, 2026-09-09: *legacy account continuity is not identity
/// baseline completeness.* So:
///
///   ADMISSION     decides access, and was decided by the policy that applied
///                 when the account was admitted. Never re-litigated.
///   COMPLETENESS  decides whether the person is INVITED to fill a gap.
///
/// The regression these tests exist to prevent is the two being collapsed
/// back together.

String _fakeJwt({required DateTime exp, String type = 'user'}) {
  String encode(Map<String, Object?> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final header = encode({'alg': 'none', 'typ': 'JWT'});
  final payload = encode({
    'sub': 'user-1',
    'type': type,
    'exp': exp.millisecondsSinceEpoch ~/ 1000,
  });
  return '$header.$payload.sig';
}

Future<ProviderContainer> _authedContainer(Map<String, dynamic> authMe) async {
  final validJwt = _fakeJwt(exp: DateTime.now().add(const Duration(hours: 1)));
  SharedPreferences.setMockInitialValues({'aura_access_token': validJwt});
  final container = ProviderContainer(
    overrides: [
      sessionBootstrapProvider.overrideWith((ref) => Future<void>.value()),
      authMeDataProvider.overrideWith((ref) async => authMe),
    ],
  );
  await container.read(tokenStoreProvider).waitUntilLoaded();
  await container.read(sessionBootstrapProvider.future);
  return container;
}

/// The shape production actually returns for the members who were already
/// here: admitted long ago, and Aura knows none of the facts it now asks for.
const _legacyMember = <String, dynamic>{
  'accountType': 'PUBLIC',
  'admissionBasis': 'CONTINUITY',
  'identityBaselineComplete': false,
  'identityMissingFields': [
    'firstName',
    'lastName',
    'dateOfBirth',
    'jurisdiction',
  ],
};

void main() {
  group('a legacy member is admitted, incomplete, and NOT held at the door', () {
    test('is never required to complete anything before using Aura', () async {
      final container = await _authedContainer(_legacyMember);
      addTearDown(container.dispose);

      final state = await container.read(identityStateProvider.future);

      expect(state!.admissionBasis, AdmissionBasis.continuity);
      // Honest: Aura genuinely does not know these facts.
      expect(state.baselineComplete, false);
      expect(state.missingFields, hasLength(4));
      // THE REGRESSION GUARD. If this ever becomes true, every member who
      // joined before Aura asked is shut out of their own account.
      expect(state.mustCompleteBeforeUse, false);
      // Invited instead — which is the whole difference.
      expect(state.shouldInviteCompletion, true);
    });

    test('stays admitted even when the response omits the missing-field list',
        () async {
      final container = await _authedContainer({
        'accountType': 'PUBLIC',
        'admissionBasis': 'CONTINUITY',
        'identityBaselineComplete': false,
      });
      addTearDown(container.dispose);

      final state = await container.read(identityStateProvider.future);
      expect(state!.mustCompleteBeforeUse, false);
    });
  });

  group('a prospective account is expected to arrive complete', () {
    test('is settled when the baseline is complete', () async {
      final container = await _authedContainer({
        'accountType': 'PUBLIC',
        'admissionBasis': 'PROSPECTIVE',
        'identityBaselineComplete': true,
        'identityMissingFields': <String>[],
      });
      addTearDown(container.dispose);

      final state = await container.read(identityStateProvider.future);
      expect(state!.admissionBasis, AdmissionBasis.prospective);
      expect(state.mustCompleteBeforeUse, false);
      expect(state.shouldInviteCompletion, false);
    });

    test('is asked once if it somehow is not', () async {
      // Registration establishes every baseline fact before the account row
      // exists, so this should be unreachable. It is still the one case where
      // holding someone at the door is right, and leaving it unhandled would
      // make the registration floor optional after the fact.
      final container = await _authedContainer({
        'accountType': 'PUBLIC',
        'admissionBasis': 'PROSPECTIVE',
        'identityBaselineComplete': false,
        'identityMissingFields': ['jurisdiction'],
      });
      addTearDown(container.dispose);

      final state = await container.read(identityStateProvider.future);
      expect(state!.mustCompleteBeforeUse, true);
    });
  });

  group('unknown is never resolved by guessing', () {
    test('an empty /auth/me reports unknown, so the router waits', () async {
      final container = await _authedContainer({});
      addTearDown(container.dispose);

      expect(await container.read(identityStateProvider.future), isNull);
    });

    test('a signed-out session describes no person, and fetches nothing',
        () async {
      SharedPreferences.setMockInitialValues({});
      var fetched = false;
      final container = ProviderContainer(
        overrides: [
          sessionBootstrapProvider.overrideWith((ref) => Future<void>.value()),
          authMeDataProvider.overrideWith((ref) async {
            fetched = true;
            return <String, dynamic>{};
          }),
        ],
      );
      addTearDown(container.dispose);
      await container.read(tokenStoreProvider).waitUntilLoaded();
      await container.read(sessionBootstrapProvider.future);

      expect(await container.read(identityStateProvider.future), isNull);
      expect(fetched, false);
    });

    test('an unrecognised admission reads as CONTINUITY, never PROSPECTIVE',
        () async {
      // Conservative on purpose: a response that does not say a floor was
      // applied is not evidence that one was, and guessing the other way holds
      // a legacy member at a door they should never have seen.
      final container = await _authedContainer({
        'accountType': 'PUBLIC',
        'identityBaselineComplete': false,
        'identityMissingFields': ['dateOfBirth'],
      });
      addTearDown(container.dispose);

      final state = await container.read(identityStateProvider.future);
      expect(state!.admissionBasis, AdmissionBasis.continuity);
      expect(state.mustCompleteBeforeUse, false);
    });

    test('a server reporting no completeness at all blocks and prompts nobody',
        () async {
      // Predates the contract entirely. There is nothing to prompt about, and
      // nothing that could justify holding anyone.
      final container = await _authedContainer({'accountType': 'PUBLIC'});
      addTearDown(container.dispose);

      final state = await container.read(identityStateProvider.future);
      expect(state!.baselineComplete, true);
      expect(state.mustCompleteBeforeUse, false);
    });
  });

  test('an institution account carries no person baseline and is never gated',
      () async {
    final container = await _authedContainer({
      'accountType': 'INSTITUTION',
      'identityBaselineComplete': false,
      'identityMissingFields': ['dateOfBirth'],
    });
    addTearDown(container.dispose);

    final state = await container.read(identityStateProvider.future);
    expect(state!.mustCompleteBeforeUse, false);
    expect(state.shouldInviteCompletion, false);
  });

  group('the router gates on admission, not on completeness', () {
    final router = File('lib/router.dart').readAsStringSync();

    test('nothing redirects on completeness alone', () {
      // The exact condition that would have walled off the platform.
      expect(
        router.contains('isIdentityBaselineComplete == false'),
        isFalse,
        reason: 'access must gate on admission; completeness only prompts',
      );
    });

    test('the completion route is only ever reached through the door test', () {
      // Every redirect to the completion screen must sit under
      // `mustCompleteIdentity`, which is false for every continuity account.
      final redirects = RegExp(
        'return .{1,4}kCompleteIdentityRoute',
      ).allMatches(router).toList();
      expect(redirects, isNotEmpty, reason: 'the gate still has to exist');

      for (final match in redirects) {
        final guard = router.lastIndexOf('mustCompleteIdentity', match.start);
        final block = router.lastIndexOf('\n      if (', match.start);
        expect(
          guard > block,
          isTrue,
          reason: 'a completion redirect a legacy member could reach',
        );
      }
    });
  });
}
