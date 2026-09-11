import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

// NATIVE ANDROID CERTIFICATION — AUTHORITY AND ASSURANCE GOVERNANCE.
//
//     adb reverse tcp:34999 tcp:34999
//     node scripts/identity-certification/institution-verification-journey-proof.mjs
//     flutter test integration_test/android_institution_governance_certification_test.dart -d <device>
//
// The seeder runs IMMEDIATELY BEFORE each run, not once: this lane promotes and
// demotes people, which mutates the fixture. `setUpAll` asserts the fixture is
// in the posture it expects and names the remedy if it is not, so a stale
// fixture can never be reported as a product defect.
//
// WHAT THIS CERTIFIES, from ARM64 Android over the real transport:
//
//   ORDINARY AURA IS NOT GATED. Verification is a capability gate, never a
//   login gate. An account holding no identity record at all still uses Aura.
//
//   THE ELEVATED GATE TELLS FOUR POSTURES APART — none, base, elevated, and
//   elevated-then-contradicted. The last is the interesting one: that person
//   HOLDS an approved ELEVATED submission, so a refusal for them can only come
//   from the date-of-birth conflict rule and from nothing else.
//
//   DELEGATION IS CHECKED ON THE TARGET. The person being promoted is the one
//   who gains the power to speak; an owner's own verification says nothing
//   about theirs.
//
//   DEMOTION IS NEVER GATED. An institution that could not demote an
//   unverified representative would be trapped with one.
//
// WHAT IT DOES NOT CERTIFY: nothing here drives a screen. Authority is decided
// on the server, and this lane proves the server's answer arrives intact on a
// phone. Screen rendering is certified in
// `android_institution_verification_certification_test.dart`.

// 127.0.0.1, NOT `localhost`. `adb reverse` binds the device's loopback, and
// a literal address needs no resolution; `localhost` goes through Android's
// DNS resolver, which intermittently answers 'No address associated with
// hostname' on a device with no active network. That failure looks exactly
// like the certification stack being down, and it is not.
const String _api = 'http://127.0.0.1:34999/v1';
const String _password = 'certification_only_pw_1';

const String _owner = 'wincert@certification.invalid';
const String _base = 'basecert@certification.invalid';
const String _none = 'nonecert@certification.invalid';
const String _dobConflicted = 'dobcert@certification.invalid';

const String _handleBase = 'basecertm';
const String _handleElevated = 'elevcertm';
const String _handleLegacyAdmin = 'legadmcertm';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final tokens = <String, String>{};
  late String institutionId;
  late Map<String, String> userIdByHandle;
  late Map<String, String> roleByHandle;

  Future<http.Response> get(String email, String path) => http.get(
        Uri.parse('$_api$path'),
        headers: {'authorization': 'Bearer ${tokens[email]}'},
      );

  Future<http.Response> post(String email, String path, Object body) => http.post(
        Uri.parse('$_api$path'),
        headers: {
          'authorization': 'Bearer ${tokens[email]}',
          'content-type': 'application/json',
        },
        body: jsonEncode(body),
      );

  Future<http.Response> patch(String email, String path, Object body) => http.patch(
        Uri.parse('$_api$path'),
        headers: {
          'authorization': 'Bearer ${tokens[email]}',
          'content-type': 'application/json',
        },
        body: jsonEncode(body),
      );

  // THE ENVELOPES, AS CAPTURED FROM THE RUNNING SERVER RATHER THAN ASSUMED.
  //
  //   refusal, everywhere      {"ok":false,"error":{"code":..,"message":..}}
  //   verification routes      {"ok":true,"data":{...}}
  //   institution/auth routes  {"ok":true,"members":[..]} — domain key on top
  //
  // Two success conventions and one refusal convention. Reading a refusal at
  // the top level is the defect this release already had to repair twice, and
  // a test that guesses the level re-creates it one layer up. So `unwrap`
  // handles the refusal and the `data` case, and callers that want a
  // top-level domain key ask for it BY NAME through `field`.
  Map<String, dynamic> unwrap(http.Response r) {
    final decoded = jsonDecode(r.body);
    if (decoded is! Map) return <String, dynamic>{};
    final inner = decoded['error'] ?? decoded['data'] ?? decoded;
    return inner is Map ? Map<String, dynamic>.from(inner) : <String, dynamic>{};
  }

  /// A named top-level key of a success body, for the routes that put the
  /// domain object there instead of under `data`.
  Map<String, dynamic> field(http.Response r, String name) {
    final decoded = jsonDecode(r.body);
    final value = decoded is Map ? decoded[name] : null;
    expect(value, isA<Map>(),
        reason: 'expected a top-level `$name` object: ${r.body}');
    return Map<String, dynamic>.from(value as Map);
  }

  setUpAll(() async {
    for (final email in const [_owner, _base, _none, _dobConflicted]) {
      final res = await http.post(
        Uri.parse('$_api/auth/login'),
        headers: const {'content-type': 'application/json'},
        body: jsonEncode({'email': email, 'password': _password}),
      );
      expect(
        res.statusCode,
        inInclusiveRange(200, 299),
        reason: 'the phone must reach the isolated stack through the adb '
            'reverse tunnel, and $email must be seeded: ${res.body}',
      );
      final data = unwrap(res);
      tokens[email] = (data['accessToken'] ?? data['token']) as String;
    }

    final mine = await get(_owner, '/institutions/me');
    final membership = unwrap(mine)['membership'] as Map<String, dynamic>?;
    expect(membership, isNotNull, reason: 'the fixture owner must hold a membership');
    institutionId = (membership!['institution'] as Map)['id'].toString();

    final roster = await get(_owner, '/institutions/$institutionId/members');
    expect(roster.statusCode, 200, reason: roster.body);
    final rows = jsonDecode(roster.body)['members'] as List;
    userIdByHandle = <String, String>{};
    roleByHandle = <String, String>{};
    for (final row in rows.cast<Map<String, dynamic>>()) {
      final handle = ((row['user'] as Map?)?['handle'] ?? '').toString();
      if (handle.isEmpty) continue;
      userIdByHandle[handle] = row['userId'].toString();
      roleByHandle[handle] = (row['role'] ?? '').toString();
    }

    // PRECONDITION, ASSERTED. This lane promotes and demotes; run against a
    // fixture a previous run already moved, its results would mean something
    // other than what they say.
    for (final expected in const {
      _handleBase: 'MEMBER',
      _handleElevated: 'MEMBER',
      _handleLegacyAdmin: 'ADMIN',
    }.entries) {
      expect(
        roleByHandle[expected.key],
        expected.value,
        reason: 'the governance fixture is stale: ${expected.key} is '
            '${roleByHandle[expected.key]}, expected ${expected.value}. '
            'Re-seed before certifying:\n'
            '  node scripts/identity-certification/'
            'institution-verification-journey-proof.mjs',
      );
    }
  });

  group('ordinary Aura is not gated', () {
    // POSITIVE CONTROL for every refusal below. If an unverified account were
    // simply locked out, each refusal would pass for the wrong reason.
    test('AN ACCOUNT WITH NO IDENTITY RECORD STILL USES AURA', () async {
      final me = await get(_none, '/users/me');
      expect(me.statusCode, 200, reason: 'general use must not require verification: ${me.body}');
    });

    test('AND STILL SEES THE INSTITUTION THEY BELONG TO', () async {
      final roster = await get(_none, '/institutions/$institutionId/members');
      expect(roster.statusCode, 200, reason: roster.body);
    });
  });

  group('the elevated capability gate, from the phone', () {
    // Claiming an institution is gated at ELEVATED. An empty body is sent
    // deliberately: a caller who PASSES the gate is refused later by
    // validation, and those two refusals are distinguishable. Asserting the
    // gate by status alone would confuse "not allowed" with "malformed".
    Future<Map<String, dynamic>> claim(String email) async {
      final res = await post(email, '/institutions/claim-request', const <String, dynamic>{});
      return {'status': res.statusCode, ...unwrap(res)};
    }

    test('ELEVATED REACHES THE CAPABILITY', () async {
      final r = await claim(_owner);
      expect(r['code'], isNot('ASSURANCE_REQUIRED'),
          reason: 'a verified representative must not be refused by assurance');
      expect(r['status'], isNot(403));
    });

    test('BASE IS REFUSED, AND TOLD WHAT IS MISSING', () async {
      final r = await claim(_base);
      expect(r['status'], 403);
      expect(r['code'], 'ASSURANCE_REQUIRED');
      final details = r['details'] as Map<String, dynamic>;
      expect(details['requiredTier'], 'ELEVATED');
      // Resolvable, deliberately: this is a thing the person can go and do.
      expect(details['resolvable'], isTrue);
    });

    test('NO RECORD AT ALL IS REFUSED THE SAME WAY', () async {
      final r = await claim(_none);
      expect(r['status'], 403);
      expect(r['code'], 'ASSURANCE_REQUIRED');
    });

    test('A GRANTED ELEVATED THAT WAS LATER CONTRADICTED FALLS', () async {
      // THE SHARPEST ASSERTION IN THIS FILE. This account holds an APPROVED
      // ELEVATED submission. If the date-of-birth conflict rule were removed,
      // it would reach the capability. So this refusal can come from nothing
      // else, and the test cannot pass for an accidental reason.
      final r = await claim(_dobConflicted);
      expect(r['status'], 403);
      expect(r['code'], 'ASSURANCE_REQUIRED');
    });

    test('AND THE REFUSAL NEVER SAYS THE ACCOUNT IS IN TROUBLE', () async {
      final r = await claim(_base);
      final message = (r['message'] ?? '').toString();
      expect(message, isNotEmpty);
      // Policy: state what is missing and that nothing else changed. Never
      // present a capability gate as punishment or account failure.
      expect(message.toLowerCase(), isNot(contains('suspend')));
      expect(message.toLowerCase(), isNot(contains('violat')));
      expect(message.toLowerCase(), isNot(contains('banned')));
      expect(message, contains('good standing'));
    });
  });

  group('delegation is checked on the target, never the actor', () {
    test('PROMOTING AN UNVERIFIED MEMBER IS REFUSED, NAMING THE TARGET', () async {
      final res = await patch(
        _owner,
        '/institutions/$institutionId/members/${userIdByHandle[_handleBase]}/role',
        const {'role': 'ADMIN'},
      );
      expect(res.statusCode, 403, reason: res.body);
      final err = unwrap(res);
      expect(err['code'], 'ASSURANCE_REQUIRED');
      // The actor here is the OWNER, who IS elevated. The refusal must say so.
      expect((err['details'] as Map)['subject'], 'TARGET_MEMBER');
    });

    test('PROMOTING A VERIFIED MEMBER SUCCEEDS', () async {
      // Without this the group above would pass against a gate that refuses
      // every promotion, which is not the rule and would trap institutions.
      final res = await patch(
        _owner,
        '/institutions/$institutionId/members/${userIdByHandle[_handleElevated]}/role',
        const {'role': 'ADMIN'},
      );
      expect(res.statusCode, inInclusiveRange(200, 299), reason: res.body);
      final row = field(res, 'member');
      expect(row['role'], 'ADMIN');
      // The voice comes WITH the principal role — that is what promotion is.
      expect(row['canSpeakOfficially'], isTrue);
    });

    test('DEMOTING AN UNVERIFIED ADMIN REMAINS POSSIBLE', () async {
      // Reducing authority is never the act that needs a verified claimant.
      // This admin holds NO identity record at all, which is exactly the case
      // an institution most needs to be able to undo.
      final res = await patch(
        _owner,
        '/institutions/$institutionId/members/${userIdByHandle[_handleLegacyAdmin]}/role',
        const {'role': 'MEMBER'},
      );
      expect(res.statusCode, inInclusiveRange(200, 299), reason: res.body);
      final row = field(res, 'member');
      expect(row['role'], 'MEMBER');
      // And the voice goes with the role, unless it was granted separately.
      expect(row['canSpeakOfficially'], isFalse);
    });

    test('NOBODY IS MADE OWNER THROUGH A ROLE CHANGE', () async {
      final res = await patch(
        _owner,
        '/institutions/$institutionId/members/${userIdByHandle[_handleBase]}/role',
        const {'role': 'OWNER'},
      );
      expect(res.statusCode, 403, reason: res.body);
    });
  });

  group('the invite path is protected', () {
    test('AN ORDINARY MEMBER CANNOT INVITE', () async {
      final res = await post(
        _base,
        '/institutions/$institutionId/invites',
        const {'email': 'invitee@certification.invalid', 'role': 'MEMBER'},
      );
      expect(res.statusCode, anyOf(401, 403), reason: res.body);
    });

    test('THE OWNER CAN', () async {
      // The positive control for the refusal above.
      final res = await post(
        _owner,
        '/institutions/$institutionId/invites',
        const {'email': 'invitee@certification.invalid', 'role': 'MEMBER'},
      );
      expect(res.statusCode, inInclusiveRange(200, 299), reason: res.body);
    });
  });
}
