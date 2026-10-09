import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// VERIFY WITH A CODE (2026-10-09). A sign-up from a company address never
/// verified: two links went out and neither was opened. The verification
/// email now carries a 6-digit code, and the waiting screen accepts it.
void main() {
  final src = File('lib/features/auth/presentation/verify_pending_screen.dart').readAsStringSync();

  test('the waiting screen verifies with the code from the email', () {
    expect(src.contains("'/auth/verify-email-code'"), isTrue);
    expect(src.contains("'code': code"), isTrue);
    expect(src.contains('AutofillHints.oneTimeCode'), isTrue);
    expect(src.contains("'Verify with code'"), isTrue);
  });

  test('it says where a held email goes, in plain words', () {
    expect(src.contains('quarantine'), isTrue);
    expect(src.contains('or enter the 6-digit code it contains'), isTrue);
  });

  test('after the code it goes to sign in, marked verified', () {
    expect(src.contains('NavigationAuthority.loginRoute'), isTrue);
    expect(src.contains("'verified': '1', 'email': email"), isTrue);
  });
}
