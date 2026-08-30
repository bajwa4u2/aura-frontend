import 'package:aura/core/eligibility/eligibility_refusal.dart';
import 'package:aura/core/eligibility/jurisdictions.dart';
import 'package:aura/core/errors/app_error.dart';
import 'package:aura/core/errors/app_error_mapper.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// WHAT THE CLIENT PROMISES A PERSON IT REFUSED.
///
/// The backend distinguishes refusals a person can clear right now from ones
/// only time can lift. If that distinction does not survive the trip through
/// the error mapper, the UI has exactly two failure modes and both are bad: it
/// offers a country picker to a twelve-year-old, or it tells a sixteen-year-old
/// in the United States that they are simply too young. These tests pin the
/// distinction at the boundary where it is easiest to lose.
DioException _forbidden({
  required String code,
  required String message,
  Object? resolvable,
}) {
  final options = RequestOptions(path: '/posts');
  return DioException(
    requestOptions: options,
    response: Response<dynamic>(
      requestOptions: options,
      statusCode: 403,
      data: {
        'ok': false,
        'error': {
          'code': code,
          'message': message,
          if (resolvable != null) 'details': {'resolvable': resolvable},
        },
      },
    ),
  );
}

void main() {
  group('the resolvable flag survives error mapping', () {
    test('a resolvable refusal arrives as resolvable', () {
      final error = AppErrorMapper.from(
        _forbidden(
          code: kEligibilityJurisdictionRequired,
          message: 'Confirm where you are to continue.',
          resolvable: true,
        ),
      );

      expect(error.type, AppErrorType.forbidden);
      expect(error.code, kEligibilityJurisdictionRequired);
      expect(error.resolvable, isTrue);
    });

    test('an age refusal arrives as not resolvable', () {
      final error = AppErrorMapper.from(
        _forbidden(
          code: kEligibilityPublicationAge,
          message: 'You must be 18 or older to publish here.',
          resolvable: false,
        ),
      );
      expect(error.resolvable, isFalse);
    });

    test('a missing flag is unknown, never an implied yes', () {
      // An older backend that does not send the flag must not have its
      // silence read as permission to offer a retry.
      final error = AppErrorMapper.from(
        _forbidden(
          code: kEligibilityPublicationAge,
          message: 'You must be 18 or older to publish here.',
        ),
      );
      expect(error.resolvable, isNull);
    });

    test('a non-boolean flag is not coerced', () {
      // "false" is truthy in most coercions, which would invert the meaning
      // of the one field whose whole job is to say no.
      final error = AppErrorMapper.from(
        _forbidden(
          code: kEligibilityPublicationAge,
          message: 'You must be 18 or older to publish here.',
          resolvable: 'false',
        ),
      );
      expect(error.resolvable, isNull);
    });
  });

  group('classifying a refusal', () {
    EligibilityRefusal? refusalFor(String code, {Object? resolvable}) =>
        EligibilityRefusal.from(
          AppErrorMapper.from(
            _forbidden(code: code, message: 'nope', resolvable: resolvable),
          ),
        );

    test('recognises every governed code', () {
      expect(
        refusalFor(kEligibilityDobRequired)!.kind,
        EligibilityRefusalKind.dateOfBirthRequired,
      );
      expect(
        refusalFor(kEligibilityJurisdictionRequired)!.kind,
        EligibilityRefusalKind.jurisdictionRequired,
      );
      expect(
        refusalFor(kEligibilityAccountAge)!.kind,
        EligibilityRefusalKind.accountAge,
      );
      expect(
        refusalFor(kEligibilityPublicationAge)!.kind,
        EligibilityRefusalKind.publicationAge,
      );
      expect(
        refusalFor(kEligibilityInstitutionRepresentationAge)!.kind,
        EligibilityRefusalKind.institutionRepresentationAge,
      );
    });

    test('does not claim an unrelated 403', () {
      // Institution membership, plan gates, capability gates — all 403s that
      // a country picker would be a nonsense answer to.
      expect(refusalFor('PLAN_REQUIRED_PRO'), isNull);
      expect(refusalFor('NOT_A_MEMBER'), isNull);
      expect(refusalFor(''), isNull);
    });

    test('only the jurisdiction refusal asks for a country', () {
      expect(
        refusalFor(kEligibilityJurisdictionRequired, resolvable: true)!
            .needsJurisdiction,
        isTrue,
      );
      for (final code in [
        kEligibilityDobRequired,
        kEligibilityAccountAge,
        kEligibilityPublicationAge,
        kEligibilityInstitutionRepresentationAge,
      ]) {
        expect(refusalFor(code)!.needsJurisdiction, isFalse);
      }
    });

    test('renders the backend sentence verbatim', () {
      // The authority's wording about its own rule. Paraphrasing it in the
      // client is how the two drift apart, and the client is the half that
      // does not get reviewed against the policy document.
      final refusal = EligibilityRefusal.from(
        AppErrorMapper.from(
          _forbidden(
            code: kEligibilityPublicationAge,
            message: 'You must be 18 or older to publish here.',
            resolvable: false,
          ),
        ),
      );
      expect(refusal!.message, 'You must be 18 or older to publish here.');
    });

    test('never carries an age or a date', () {
      // Policy §5 forbids echoing either. The client cannot leak what it was
      // never given, and this is the assertion that keeps it that way.
      final refusal = refusalFor(kEligibilityPublicationAge)!;
      expect(RegExp(r'\d{4}-\d{2}-\d{2}').hasMatch(refusal.message), isFalse);
    });
  });

  group('jurisdiction table', () {
    test('covers the buckets the policy names', () {
      expect(isKnownJurisdiction('US'), isTrue);
      expect(isKnownJurisdiction('de'), isTrue);
      expect(isKnownJurisdiction('  no  '), isTrue);
      expect(isKnownJurisdiction('PK'), isTrue);
      expect(isKnownJurisdiction('XX'), isFalse);
      expect(isKnownJurisdiction(null), isFalse);
      expect(isKnownJurisdiction(''), isFalse);
    });

    test('every code is two upper-case letters with a non-empty name', () {
      final codePattern = RegExp(r'^[A-Z]{2}$');
      kJurisdictions.forEach((code, name) {
        expect(codePattern.hasMatch(code), isTrue, reason: code);
        expect(name.trim(), isNotEmpty, reason: code);
      });
    });

    test('sorts by name, not by code', () {
      final sorted = jurisdictionCodesByName();
      expect(sorted.length, kJurisdictions.length);
      final names = sorted.map((c) => kJurisdictions[c]!).toList();
      final expected = [...names]..sort();
      expect(names, expected);
    });

    test('renders an unknown code as itself rather than blank', () {
      // A row already holding something we do not recognise still has to be
      // visible, or a person cannot see what they need to change.
      expect(jurisdictionName('ZZ'), 'ZZ');
      expect(jurisdictionName('us'), 'United States');
      expect(jurisdictionName(null), '');
    });
  });
}
