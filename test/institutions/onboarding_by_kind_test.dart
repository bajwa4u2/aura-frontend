import 'dart:io';

import 'package:aura/features/institutions/wizard/institution_kinds.dart';
import 'package:flutter_test/flutter_test.dart';

/// DD-42 (2026-10-08): institutions are onboarded by kind, signed in, as
/// themselves.
void main() {
  test('the seven kinds are exactly the server categories', () {
    expect(
      InstitutionKind.all.map((k) => k.wire).toSet(),
      {
        'GOVERNMENT_CIVIC',
        'EDUCATIONAL',
        'NONPROFIT_COMMUNITY',
        'RELIGIOUS',
        'CORPORATE_BUSINESS',
        'MEDIA',
        'HEALTHCARE',
      },
    );
    for (final k in InstitutionKind.all) {
      expect(k.existenceProof, isNotEmpty, reason: k.wire);
      expect(k.authorityProof, isNotEmpty, reason: k.wire);
    }
  });

  test('a person always reviews government, schools, media and healthcare', () {
    final always = InstitutionKind.all.where((k) => k.alwaysReviewed).map((k) => k.wire).toSet();
    expect(always, {'GOVERNMENT_CIVIC', 'EDUCATIONAL', 'MEDIA', 'HEALTHCARE'});
  });

  test('faith institutions are told the lighter proof applies when unregistered', () {
    expect(InstitutionKind.fromWire('RELIGIOUS')!.existenceProof, contains('If not'));
  });

  test('kinds whose review turns on a number ask for it; faith may be unregistered', () {
    final asks = InstitutionKind.all.where((k) => k.registryLabel != null).map((k) => k.wire).toSet();
    expect(asks, {'NONPROFIT_COMMUNITY', 'RELIGIOUS', 'CORPORATE_BUSINESS', 'HEALTHCARE'});
    final unregistered = InstitutionKind.all.where((k) => k.mayBeUnregistered).map((k) => k.wire).toSet();
    expect(unregistered, {'RELIGIOUS'});
  });

  group('the wizard', () {
    final src = File('lib/features/institutions/wizard/institution_onboarding_wizard.dart').readAsStringSync();

    test('creates through the signed-in route with a kind', () {
      expect(src.contains("'/institutions/create-request'"), isTrue);
      expect(src.contains("'kind': _kind!.wire"), isTrue);
      expect(src.contains("'/institutions/verification-request'"), isFalse,
          reason: 'the signed-out request that made a second account is retired');
    });

    test('never asks for a password, a name or an email again', () {
      expect(src.contains("'password'"), isFalse);
      expect(src.contains('_firstName'), isFalse);
      expect(src.contains('_workEmail'), isFalse);
    });

    test('never points people at a separate institution sign-in or a universal DNS step', () {
      expect(src.contains('/institution/sign-in'), isFalse);
      expect(src.contains('add a DNS record'), isFalse);
    });

    // Founder, 2026-10-09: "website, jurisidection, description" — what the
    // review needs is never labelled optional.
    test('nothing the review needs is labelled optional', () {
      for (final label in ["'Website (optional)'", "'Location / jurisdiction (optional)'", "'Short description (optional)'"]) {
        expect(src.contains(label), isFalse, reason: label);
      }
      expect(src.contains("_error = \"Enter the institution's website.\""), isTrue);
      expect(src.contains("'Enter where the institution is.'"), isTrue);
      expect(src.contains("'Describe the institution in a few words.'"), isTrue);
      expect(src.contains("'Enter your role at the institution.'"), isTrue);
      expect(src.contains("'description': opt(_description)"), isTrue);
    });

    test('a reviewer question is answered in the app', () {
      expect(src.contains("'/institutions/my-requests'"), isTrue);
      expect(src.contains('/respond'), isTrue);
    });
  });
}
