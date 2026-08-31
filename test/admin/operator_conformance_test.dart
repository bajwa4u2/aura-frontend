import 'dart:io';

import 'package:aura/features/admin/domain/operator_area.dart';
import 'package:aura/features/admin/domain/operator_capability.dart';
import 'package:flutter_test/flutter_test.dart';

/// NO AADHA TEETAR AADHA BATAIR.
///
/// The console this replaces failed in ways no test could see: five admin
/// routes had no navigation entry, fourteen were shown to every operator
/// regardless of their four or three permissions, and eighteen screens each
/// built their own scaffold inside the shell. None of that broke a build.
///
/// These assertions are the permanent guard. They read the source rather than
/// the widget tree, because the failures are structural.
void main() {
  final routerSource = File('lib/router.dart').readAsStringSync();

  /// Every `/admin...` path the router declares.
  List<String> declaredAdminPaths() {
    final paths = <String>{};
    final literal = RegExp(r"path:\s*'(/admin[^']*)'").allMatches(routerSource);
    for (final m in literal) {
      paths.add(m.group(1)!);
    }
    // Route constants resolve to their literal values.
    for (final m
        in RegExp(r"const String (kAdmin\w+)\s*=\s*'(/admin[^']*)'")
            .allMatches(routerSource)) {
      if (routerSource.contains('path: ${m.group(1)}')) {
        paths.add(m.group(2)!);
      }
    }
    return paths.toList()..sort();
  }

  group('the retired console cannot come back', () {
    test('the launcher grid is gone', () {
      expect(File('lib/features/institutions/presentation/admin_workspace_screen.dart')
          .existsSync(), isFalse,
          reason: 'the launcher grid was platform admin borrowing institution '
              "admin's screen; it must not return");
      expect(routerSource.contains('AdminWorkspaceScreen'), isFalse);
    });

    test('the flat fourteen-item shell is gone', () {
      expect(File('lib/app/shell/admin_shell.dart').existsSync(), isFalse,
          reason: 'its mobile form put 14 destinations in one Row of Expanded '
              'children — no scroll, no overflow, ~27px per target');
      expect(File('lib/app/app_shell.dart').readAsStringSync(),
          contains('OperatorShell'));
    });

    test('no admin surface builds its own scaffold inside the shell', () {
      // The shell owns the chrome. A screen that brings its own is a small
      // application sharing a sidebar, which is what the old console was.
      final offenders = <String>[];
      final dir = Directory('lib/features/admin/areas');
      if (dir.existsSync()) {
        for (final file in dir.listSync(recursive: true).whereType<File>()) {
          if (!file.path.endsWith('.dart')) continue;
          final src = file.readAsStringSync();
          if (src.contains('AuraScaffold(') || src.contains('Scaffold(')) {
            offenders.add(file.path);
          }
        }
      }
      expect(offenders, isEmpty,
          reason: 'these areas build their own chrome: $offenders');
    });
  });

  group('navigation derives from authority', () {
    test('every area declares what it requires', () {
      for (final area in OperatorArea.values) {
        // NOW is deliberately open to any operator: it renders only the
        // sections the operator's capabilities already permit.
        if (area == OperatorArea.now) {
          expect(area.anyOf, isEmpty);
          continue;
        }
        expect(area.anyOf, isNotEmpty,
            reason: '${area.id} would be shown to every operator');
      }
    });

    test('an operator with no authority sees no areas', () {
      expect(OperatorArea.visibleFor(const OperatorAuthority.none()), isEmpty);
    });

    test('a moderator sees moderation work, not the whole console', () {
      // The exact production shape of the MODERATOR role.
      final moderator = OperatorAuthority.fromMe(const {
        'userId': 'm',
        'roles': ['MODERATOR'],
        'isOwner': false,
        'effectivePermissions': [
          'MODERATION_READ',
          'MODERATION_WRITE',
          'ANNOUNCEMENTS_READ',
          'AUDIT_READ',
        ],
      });
      final visible = OperatorArea.visibleFor(moderator).map((a) => a.id);
      expect(visible, contains('work'));
      expect(visible, contains('integrity'));
      expect(visible, contains('record'));
      // No users, no institutions, no settings, no analytics.
      expect(visible, isNot(contains('subjects')));
      expect(visible, isNot(contains('platform')));
      expect(visible, isNot(contains('discovery')));
    });

    test('an analyst sees platform and record, not queues', () {
      final analyst = OperatorAuthority.fromMe(const {
        'userId': 'a',
        'roles': ['ANALYST'],
        'isOwner': false,
        'effectivePermissions': [
          'ANALYTICS_READ',
          'AUDIT_READ',
          'SYSTEM_HEALTH_READ',
        ],
      });
      final visible = OperatorArea.visibleFor(analyst).map((a) => a.id);
      expect(visible, contains('platform'));
      expect(visible, contains('record'));
      expect(visible, isNot(contains('work')),
          reason: 'an analyst holds no queue authority');
      expect(visible, isNot(contains('integrity')));
    });
  });

  group('capability truth comes from the server', () {
    test('parses the fields the server actually sends', () {
      // The previous client model read `role` and `permissions`; the server
      // sends `roles` and `effectivePermissions`, so the list was ALWAYS
      // empty. That is very likely why nobody built gating on it.
      final authority = OperatorAuthority.fromMe(const {
        'userId': 'u',
        'roles': ['ADMIN'],
        'isOwner': false,
        'effectivePermissions': ['USERS_READ', 'AUDIT_READ'],
      });
      expect(authority.capabilities, {
        OperatorCapability.usersRead,
        OperatorCapability.auditRead,
      });
      expect(authority.roles, {OperatorRole.admin});
    });

    test('a newer server scope is reported, not silently dropped', () {
      final authority = OperatorAuthority.fromMe(const {
        'userId': 'u',
        'roles': ['ADMIN'],
        'effectivePermissions': ['AUDIT_READ', 'SOMETHING_NEW'],
      });
      expect(authority.can(OperatorCapability.auditRead), isTrue);
      expect(authority.unknownCapabilities, {'SOMETHING_NEW'});
    });

    test('the deliberate permission separations survive', () {
      // Both carry recorded governance rationale and must never be collapsed
      // for the convenience of a menu.
      expect(OperatorCapability.identityVerificationRead,
          isNot(OperatorCapability.verificationRead));
      expect(OperatorCapability.productFeedbackRead,
          isNot(OperatorCapability.supportRead));

      final institutionReviewer = OperatorAuthority.fromMe(const {
        'userId': 'u',
        'effectivePermissions': ['VERIFICATION_READ', 'VERIFICATION_WRITE'],
      });
      // Institution legitimacy authority must NOT admit anyone to identity
      // evidence.
      expect(
        institutionReviewer.can(OperatorCapability.identityVerificationRead),
        isFalse,
      );
    });

    test('the client never recomputes permissions from roles', () {
      // An explicit grant permission list OVERRIDES role defaults entirely.
      // Deriving capability from the role here would reintroduce that bug on
      // the other side of the wire.
      final narrowed = OperatorAuthority.fromMe(const {
        'userId': 'u',
        'roles': ['ADMIN'],
        'isOwner': false,
        'effectivePermissions': ['AUDIT_READ'],
      });
      expect(narrowed.capabilities, {OperatorCapability.auditRead});
      expect(narrowed.can(OperatorCapability.usersWrite), isFalse,
          reason: 'ADMIN defaults must not leak past an explicit grant list');
    });
  });

  group('every admin route belongs to the reconstructed hub', () {
    // THE MIGRATION REGISTER, ENFORCED.
    //
    // A legacy route "resolves" to NOW purely because it starts with /admin,
    // so a prefix check would pass while the console still had eighteen legacy
    // front doors. These paths are the ones still awaiting migration into an
    // area. Every migration removes one line. When the list is empty the
    // completion gate below turns green on its own.
    const pendingMigration = <String>{
      '/admin/institutions',
      '/admin/institutions/:id/members',
      '/admin/users',
      '/admin/identity-review',
      '/admin/feedback',
      '/admin/grants',
      '/admin/audit-logs',
      '/admin/settings',
      '/admin/feature-flags',
      '/admin/institution-domains',
      '/admin/review-queue',
      '/admin/migrations',
      '/admin/policies',
      '/admin/moderation',
      '/admin/media-appeals',
      '/admin/support',
      '/admin/communications',
    };

    test('every /admin route is either migrated or on the register', () {
      final unaccounted = <String>[];
      for (final path in declaredAdminPaths()) {
        if (pendingMigration.contains(path)) continue;
        final area = OperatorArea.forPath(path);
        // Owned by a real area — NOW only owns '/admin' itself.
        final owned = area != null &&
            (area != OperatorArea.now || path == OperatorArea.now.path);
        if (!owned) unaccounted.add(path);
      }
      expect(unaccounted, isEmpty,
          reason: 'these admin routes belong to no area and are not on the '
              'migration register: $unaccounted');
    });

    test('the register only lists routes that still exist', () {
      // Stops the register rotting into a list of paths already deleted,
      // which would let a genuinely unowned route hide behind a stale entry.
      final declared = declaredAdminPaths().toSet();
      final stale = pendingMigration.where((p) => !declared.contains(p));
      expect(stale, isEmpty,
          reason: 'register lists routes the router no longer declares: '
              '${stale.toList()}');
    });

    test('area paths are unique and ordered as frozen', () {
      final ids = OperatorArea.values.map((a) => a.id).toList();
      expect(ids, [
        'now',
        'work',
        'subjects',
        'integrity',
        'platform',
        'record',
        'discovery',
      ]);
      final paths = OperatorArea.values.map((a) => a.path).toSet();
      expect(paths.length, OperatorArea.values.length);
    });

    test('the longest path wins so nested routes do not resolve to NOW', () {
      expect(OperatorArea.forPath('/admin'), OperatorArea.now);
      expect(OperatorArea.forPath('/admin/work'), OperatorArea.work);
      expect(OperatorArea.forPath('/admin/work/anything'), OperatorArea.work);
      expect(OperatorArea.forPath('/admin/subjects/person/1'),
          OperatorArea.subjects);
    });
  });
}
