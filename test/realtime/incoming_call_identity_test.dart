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
  group('the fallback order is canonical-first', () {
    late String src;

    setUpAll(() {
      src = File(
        'lib/features/realtime/presentation/incoming_live_overlay.dart',
      ).readAsStringSync();
    });

    test('the canonical actor is still consulted FIRST', () {
      // This must stay a fallback, not a second source of truth.
      final display = src.indexOf('person.displayName');
      final fallback = src.indexOf("_stringOf(data['callerDisplayName'])");
      expect(display, greaterThan(-1));
      expect(fallback, greaterThan(-1),
          reason: 'the payload caller name is no longer read, so an empty '
              'actor block shows "Someone" again');
      expect(display, lessThan(fallback),
          reason: 'the payload fallback now outranks the canonical actor');
    });

    test('the handle is preferred over the placeholder', () {
      final handle = src.indexOf("_stringOf(data['callerHandle'])");
      final placeholder = src.indexOf("'Someone',");
      expect(handle, greaterThan(-1));
      expect(placeholder, greaterThan(handle),
          reason: '"Someone" is reachable before the handle is tried');
    });

    test('the avatar follows the same rule', () {
      expect(src, contains("_stringOf(data['callerAvatarUrl'])"),
          reason: 'the caller photo falls back to an initial letter even when '
              'the payload carries a real avatar');
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
