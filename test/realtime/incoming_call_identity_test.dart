import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/identity/person_identity_model.dart';

/// WHO IS CALLING — founder-observed live, 2026-08-25.
///
/// An incoming video call from **M S Bajwa** announced itself on a physical
/// Pixel as **"Someone"** — *"Someone started a video call"* — with an "S"
/// initial avatar.
///
/// That is the placeholder identity §13 forbids ("Do not display generic: User
/// / Member / Someone / Guest when governed identity exists"), on the one
/// surface where it matters most: you accept or decline before anything else
/// is on screen, so the caller's name is the entire basis for the decision.
///
/// `AuraPersonIdentity.label` is not at fault — falling back to "Someone" when
/// it has neither a display name nor a handle is correct. The fault was that
/// it was only ever handed `item['actor']`. The same canonical payload also
/// carries `callerDisplayName` / `callerHandle` / `callerAvatarUrl`
/// (`toCanonicalCallCommunicationData`, aura-backend), so when the actor block
/// arrived empty the identity was already in the message and simply unread.
void main() {
  group('the surface reads ONE authority', () {
    late String src;

    setUpAll(() {
      src = File(
        'lib/features/realtime/presentation/incoming_live_overlay.dart',
      ).readAsStringSync();
    });

    test('the ring card resolves identity from the canonical actor alone', () {
      // The first repair added a per-surface fallback here. Measurement then
      // showed the real problem was upstream: a push-delivered ring carries no
      // actor block at all, with the caller flat at the top level. That is
      // reconciled once, in the bridge both transports funnel through, so this
      // surface asks one question of one authority.
      expect(src, contains('AuraPersonIdentity.fromJson(actor)'));
      expect(src, contains('final actorName = person.label;'),
          reason: 'the ring card is deriving identity some other way again');
    });

    test('no per-surface caller fallback has crept back in', () {
      // A second place that knows how to find a caller is a second place that
      // can disagree with the first.
      for (final key in const [
        "data['callerDisplayName']",
        "data['callerHandle']",
        "data['callerAvatarUrl']",
      ]) {
        expect(src, isNot(contains(key)),
            reason: 'the surface reads $key directly instead of relying on '
                'the reconciled canonical actor');
      }
    });
  });

  group('the identity model itself is unchanged and still honest', () {
    test('it names a person when it has a name', () {
      const person = AuraPersonIdentity(
        userId: 'u1',
        displayName: 'M S Bajwa',
        handle: 'bajwawrites',
      );
      expect(person.label, 'M S Bajwa');
    });

    test('it falls back to the handle before the placeholder', () {
      const person =
          AuraPersonIdentity(userId: 'u1', displayName: '', handle: 'bajwawrites');
      expect(person.label, '@bajwawrites');
    });

    test('"Someone" remains the last resort, not a bug to remove', () {
      // When nothing is known, a neutral word is right. The defect was never
      // this fallback — it was reaching it with data still unread.
      const unknown = AuraPersonIdentity(userId: 'u1', displayName: '', handle: '');
      expect(unknown.label, 'Someone');
    });
  });
}
