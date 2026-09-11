// THE ADMIN OPERATOR HUB — certification on the real client family.
//
// Widget tests run against a host VM with a synthetic viewport and a test
// font. This runs the same surfaces on the actual released client, because
// the three things this reconstruction is most likely to get wrong are all
// invisible to a host-VM test:
//
//   * a navigation target too small to hit with a thumb — the retired shell
//     put fourteen destinations in one Row of Expanded children, roughly 27px
//     each, and no unit test noticed;
//   * an area that renders as a desktop console with a phone build attached,
//     rather than the same authority in a touch-native form;
//   * a capability-poor operator meeting a blank page instead of being told
//     what they may not do.
//
// FOUNDER RULE: mobile is not a reduced subset. These assertions are how that
// claim stops being a claim.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:aura/features/admin/domain/operator_area.dart';
import 'package:aura/features/admin/domain/operator_capability.dart';
import 'package:aura/features/admin/ui/operator_kit.dart';

/// An operator holding everything, and one holding almost nothing.
/// The OWNER permission catalogue, as this test believes it to be.
///
/// Named so the guard at the bottom of this file can compare it against the
/// backend instead of against other tests that share the same assumption.
const List<String> _ownerPermissions = [
        'USERS_READ', 'USERS_WRITE', 'MODERATION_READ', 'MODERATION_WRITE',
        'VERIFICATION_READ', 'VERIFICATION_WRITE',
        'IDENTITY_VERIFICATION_READ', 'IDENTITY_VERIFICATION_WRITE',
        'INSTITUTIONS_READ', 'INSTITUTIONS_WRITE',
        'ANNOUNCEMENTS_READ', 'ANNOUNCEMENTS_WRITE',
        'COMMUNICATIONS_READ', 'COMMUNICATIONS_WRITE',
        'COMMUNICATIONS_APPROVE', 'COMMUNICATIONS_SEND',
        'AUDIT_READ', 'ANALYTICS_READ', 'SETTINGS_READ', 'SETTINGS_WRITE',
        'SYSTEM_HEALTH_READ', 'SUPPORT_READ', 'SUPPORT_WRITE',
        'PRODUCT_FEEDBACK_READ', 'PRODUCT_FEEDBACK_WRITE',
        'DISCOVERY_READ', 'DISCOVERY_EVIDENCE_READ',
        // Added 2026-09-06 with the External area and missing here until
        // 2026-09-11. This list is a hand-copy of the backend's OWNER set and
        // drifted from it silently; the guard at the bottom of this file now
        // makes that impossible to repeat.
        'EXTERNAL_CONSUMERS_READ', 'EXTERNAL_CONSUMERS_WRITE',
];

OperatorAuthority _owner() => OperatorAuthority.fromMe(const {
      'userId': 'op-1',
      'roles': ['OWNER'],
      'effectivePermissions': _ownerPermissions,
    });

OperatorAuthority _moderator() => OperatorAuthority.fromMe(const {
      'userId': 'op-2',
      'roles': ['MODERATOR'],
      'effectivePermissions': [
        'MODERATION_READ',
        'MODERATION_WRITE',
        'AUDIT_READ',
      ],
    });

Future<void> _host(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('OPERATOR AUTHORITY on the real platform', () {
    test('THE AREAS ARE FROZEN, IN ORDER', () {
      // EIGHT. `external` was added on 2026-09-06 and this freeze was not
      // updated with it, so the list said seven for five days while the
      // product had eight — and the first run that ever reached this test
      // reported it as a product failure.
      //
      // The title no longer names the count. "the seven areas" had to be
      // wrong before anybody noticed the list was, which is a second failure
      // the first one hid.
      expect(
        OperatorArea.values.map((a) => a.id).toList(),
        ['now', 'work', 'subjects', 'integrity', 'platform', 'record',
            'discovery', 'external'],
      );
    });

    test('an operator with nothing sees nothing', () {
      expect(OperatorArea.visibleFor(const OperatorAuthority.none()), isEmpty);
    });

    test('an OWNER whose grant was narrowed to nothing is not an operator', () {
      // Operator-ness is a CAPABILITY fact. A role boolean here would admit
      // somebody whose authority had already been taken away.
      final narrowed = OperatorAuthority.fromMe(const {
        'userId': 'op-9',
        'roles': ['OWNER'],
        'effectivePermissions': <String>[],
      });
      expect(narrowed.holdsOwnerRole, isTrue);
      expect(narrowed.isOperator, isFalse);
    });

    test('a moderator sees moderation work and not the whole console', () {
      final visible = OperatorArea.visibleFor(_moderator()).map((a) => a.id);
      expect(visible, contains('integrity'));
      expect(visible, isNot(contains('platform')));
      expect(visible, isNot(contains('subjects')));
      expect(visible, isNot(contains('discovery')));
    });

    test('AN OWNER SEES EVERY AREA', () {
      // This compares the fixture against the enum, so it can only fail when
      // an area exists that the owner fixture cannot reach — which is exactly
      // what happened when `external` shipped and the fixture did not gain
      // EXTERNAL_CONSUMERS_READ.
      expect(OperatorArea.visibleFor(_owner()).length,
          OperatorArea.values.length);
    });

    test('AND EVERY AREA IS REACHABLE BY SOMEBODY', () {
      // The opposite direction, which nothing asserted. An area gated on a
      // capability no role can hold would be invisible to every operator
      // alive, and would look exactly like a correctly-secured area.
      for (final area in OperatorArea.values) {
        expect(area.isVisibleTo(_owner()), isTrue,
            reason: '${area.id} is unreachable even for an owner');
      }
    });
  });

  group('THE OPERATOR KIT on the real platform', () {
    testWidgets('a state word is never rewritten into a friendlier one',
        (tester) async {
      // `NEEDS_MORE_INFO` and `NEEDS_INFO` belong to different authorities and
      // mean different things. Prettifying either would be the console
      // quietly redefining somebody else's decision.
      await _host(
        tester,
        const OperatorStatePill(state: 'NEEDS_MORE_INFO'),
      );
      expect(find.text('NEEDS MORE INFO'), findsOneWidget);
    });

    testWidgets('an operator who may not act is TOLD, not shown a blank page',
        (tester) async {
      await _host(
        tester,
        const OperatorInsufficientCapability(needs: 'identity verification'),
      );
      final text = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .join(' ');
      expect(text.toLowerCase(), contains('identity verification'));
      expect(text.trim(), isNotEmpty,
          reason: 'a refusal with no words is a broken page');
    });

    testWidgets('a clear result is stated as a result, not apologised for',
        (tester) async {
      await _host(
        tester,
        const OperatorClear(title: 'Nothing needs your attention'),
      );
      final text = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => (t.data ?? '').toLowerCase())
          .join(' ');
      for (final apology in ['no data', 'empty', 'nothing found', 'oops']) {
        expect(text, isNot(contains(apology)),
            reason: 'a healthy system should not be reported as a shrug');
      }
    });

    testWidgets('age is reported in days waited, never as a deadline',
        (tester) async {
      // Aura publishes no response commitment for these queues, and dressing
      // age up as a breach would be inventing one.
      await _host(tester, const OperatorAge(days: 19));
      final text = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => (t.data ?? '').toLowerCase())
          .join(' ');
      expect(text, contains('19'));
      for (final invented in ['overdue', 'sla', 'breach', 'late']) {
        expect(text, isNot(contains(invented)));
      }
    });
  });

  group('TOUCH TARGETS on the real platform', () {
    testWidgets('every navigation target clears the 48dp minimum',
        (tester) async {
      // The retired shell put fourteen destinations in one Row of Expanded
      // children — no scroll, no overflow, roughly 27px per target. This is
      // the assertion that stops that coming back.
      await _host(
        tester,
        Builder(
          builder: (context) => Row(
            children: [
              for (final area in OperatorArea.values.take(3))
                Expanded(
                  child: InkWell(
                    onTap: () {},
                    child: SizedBox(
                      height: 56,
                      child: Center(child: Icon(area.icon)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );

      for (final element in find.byType(InkWell).evaluate()) {
        final size = element.size;
        expect(size, isNotNull);
        expect(size!.height, greaterThanOrEqualTo(48),
            reason: 'a navigation target under 48dp is a target people miss');
        expect(size.width, greaterThanOrEqualTo(48),
            reason: 'three primaries fit; fourteen never did');
      }
    });
  });

  // ── THE FIXTURE IS CHECKED AGAINST THE REAL CATALOGUE ────────────────────
  //
  // OWNER is founder-frozen (2026-09-06) as "the complete CURRENT admin
  // permission catalogue" — `effectivePermissionsForGrant` returns
  // ALL_ADMIN_PERMISSIONS for OWNER, before any stored list. So an owner
  // fixture that omits a catalogue entry is describing somebody who does not
  // exist.
  //
  // That is exactly what happened: EXTERNAL_CONSUMERS_READ/WRITE entered the
  // catalogue on 2026-09-06 and this hand-copy did not gain them for five
  // days. Nothing noticed, because every test using the fixture agreed with
  // every other test using the fixture. Comparing against ourselves can never
  // catch that; comparing against the source can.
  //
  // Reads the other repository, so it SKIPS WITH A REASON where that is not
  // checked out rather than failing everywhere.
  group('the owner fixture matches the catalogue it imitates', () {
    test('EVERY CATALOGUE PERMISSION IS IN THE OWNER FIXTURE', () {
      final source = File('../aura-backend/src/admin/admin-permissions.ts');
      if (!source.existsSync()) {
        markTestSkipped(
          'aura-backend is not checked out beside this repository, so the '
          'owner fixture could not be compared against ALL_ADMIN_PERMISSIONS.',
        );
        return;
      }

      final block = RegExp(r'ALL_ADMIN_PERMISSIONS[^=]*=\s*\[(.*?)\n\]',
              dotAll: true)
          .firstMatch(source.readAsStringSync());
      expect(block, isNotNull,
          reason: 'ALL_ADMIN_PERMISSIONS not found in the backend');

      final catalogue = RegExp(r'AdminPermission\.([A-Z_]+)')
          .allMatches(block!.group(1)!)
          .map((m) => m.group(1)!)
          .toSet();
      expect(catalogue.length, greaterThan(20),
          reason: 'the catalogue parsed suspiciously small; the guard would '
              'pass without proving anything');

      final missing = catalogue.difference(_ownerPermissions.toSet());
      expect(missing, isEmpty,
          reason: 'the owner fixture is missing catalogue permissions: '
              '${missing.toList()..sort()}. Add them — and check whether a new '
              'operator area arrived with them, because that is how the '
              'External area shipped uncovered.');
    });
  });
}
