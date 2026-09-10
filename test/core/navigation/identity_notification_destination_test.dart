import 'package:aura/core/navigation/canonical_destinations.dart';
import 'package:flutter_test/flutter_test.dart';

/// A DESTINATION MUST NOT OUTLIVE THE BUILD IT WAS WRITTEN FOR.
///
/// The released clients (`1.4.0+27`, client commit `b73e8a1`) return a payload
/// deeplink verbatim, and their router has no `/verify-identity`. A decision
/// notice carrying that path therefore took someone who verified from a mobile
/// browser to a red "Route not found: /verify-identity" screen inside the
/// installed app.
///
/// So the backend sends no path, and the destination is minted here — where
/// the route actually exists. A build without the screen resolves nothing and
/// the tap is inert: a disappointment rather than a developer error page shown
/// to a person who just submitted their passport.
void main() {
  test('a subject decision resolves to the member surface', () {
    for (final type in [
      'IDENTITY_VERIFICATION_VERIFIED',
      'IDENTITY_VERIFICATION_REJECTED',
      'IDENTITY_VERIFICATION_NEEDS_MORE_INFO',
      'IDENTITY_VERIFICATION_EXPIRED',
    ]) {
      expect(identityVerificationDestination(type), '/verify-identity',
          reason: '$type should land the subject on their own verification');
    }
  });

  test('the reviewer queue notice does NOT land on the member surface', () {
    // Same family, different person, different place. Collapsing them would
    // send a reviewer to their own verification instead of the queue.
    //
    // THIS ASSERTED `/admin/identity-review`, WHICH THE ROUTER HAS NEVER
    // DECLARED. The intent was right and the value was a phantom: the test
    // pinned the destination apart from the member surface, and nothing
    // checked that the place it pinned it to existed. A reviewer tapping "a
    // verification is waiting for review" was sent nowhere.
    //
    // The Identity lane lives inside `/admin/integrity`.
    final destination =
        identityVerificationDestination('IDENTITY_VERIFICATION_SUBMITTED');
    expect(destination, '/admin/integrity');
    expect(destination, isNot('/verify-identity'));
    // The phantom specifically, so it cannot come back.
    expect(destination, isNot('/admin/identity-review'));
  });

  test('it claims nothing outside its own family', () {
    for (final other in [
      'MESSAGE',
      'MEDIA_QUARANTINED',
      'INVITATION',
      'IDENTITY', // close, but not this family
      '',
      null,
    ]) {
      expect(identityVerificationDestination(other), isNull,
          reason: '$other is not an identity verification notice');
    }
  });

  test('case and whitespace from a payload do not defeat it', () {
    expect(identityVerificationDestination(' identity_verification_verified '),
        '/verify-identity');
  });
}
