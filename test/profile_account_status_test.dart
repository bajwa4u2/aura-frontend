import 'package:aura/features/profile/domain/profile.dart';
import 'package:flutter_test/flutter_test.dart';

// Account Lifecycle / Public Identity doctrine — Profile.fromJson must
// parse the backend's public-safe accountStatus field, defaulting to
// ACTIVE when absent (older/mocked responses), and isActive must reflect
// it precisely so profile-screen action affordances gate correctly.

void main() {
  test('defaults to ACTIVE when accountStatus is absent from the response', () {
    final profile = Profile.fromJson({
      'id': 'u1',
      'handle': 'alice',
      'displayName': 'Alice',
    });

    expect(profile.accountStatus, 'ACTIVE');
    expect(profile.isActive, isTrue);
  });

  test('parses ACTIVE explicitly', () {
    final profile = Profile.fromJson({
      'id': 'u1',
      'handle': 'alice',
      'displayName': 'Alice',
      'accountStatus': 'ACTIVE',
    });

    expect(profile.isActive, isTrue);
  });

  test('parses DISABLED and marks the profile inactive', () {
    final profile = Profile.fromJson({
      'id': 'u1',
      'handle': 'alice',
      'displayName': 'Alice',
      'accountStatus': 'DISABLED',
    });

    expect(profile.accountStatus, 'DISABLED');
    expect(profile.isActive, isFalse);
  });

  test('parses DELETED and marks the profile inactive', () {
    final profile = Profile.fromJson({
      'id': 'u1',
      'handle': 'alice',
      'displayName': 'Deleted user',
      'accountStatus': 'deleted',
    });

    expect(profile.accountStatus, 'DELETED');
    expect(profile.isActive, isFalse);
  });
}
