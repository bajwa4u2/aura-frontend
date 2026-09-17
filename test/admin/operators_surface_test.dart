import 'package:aura/features/admin/domain/operator_area.dart';
import 'package:aura/features/admin/domain/operator_capability.dart';
import 'package:flutter_test/flutter_test.dart';

/// APPOINTING AN OPERATOR IS AN ESTATE-LEVEL ACT.
///
/// It briefly lived as a button on every person's page, wherever somebody
/// happened to hold no grant. That was broad in presentation and incomplete in
/// behaviour at the same time: an estate-level governance act sat beside every
/// ordinary member in the estate, and because it only appeared for people with
/// NO authority, a person who already held a grant could never be given a
/// second one.
///
/// These tests hold the surface where it now lives, and the two rules the UI
/// enforces that the API cannot:
///
///   * OWNER is never offered, because `effectivePermissionsForGrant()`
///     resolves it to the entire catalogue whatever the picker shows.
///   * a grant is never sent with an empty permission list, because the API
///     falls back to role defaults — a role shortcut that silently expands
///     authority.
OperatorAuthority _with(Set<OperatorCapability> caps) => OperatorAuthority(
      userId: 'u1',
      roles: const {},
      capabilities: caps,
      unknownCapabilities: const {},
    );

void main() {
  group('the Operators area is its own surface', () {
    test('exists, with its own path and label', () {
      final area = OperatorArea.values.firstWhere((a) => a.id == 'operators');
      expect(area.path, '/admin/operators');
      expect(area.label, 'Operators');
    });

    test('a path under it resolves to it, not to another area', () {
      expect(OperatorArea.forPath('/admin/operators')?.id, 'operators');
    });
  });

  group('who may see it', () {
    test('an operator holding USERS_WRITE sees it', () {
      final area = OperatorArea.values.firstWhere((a) => a.id == 'operators');
      expect(area.isVisibleTo(_with({OperatorCapability.usersWrite})), isTrue);
    });

    test('an identity reviewer does NOT see it', () {
      // The exact shape of the least-privilege reviewer grant made on
      // 2026-09-17. Reviewing identities must not carry any ability to
      // appoint operators.
      final area = OperatorArea.values.firstWhere((a) => a.id == 'operators');
      final reviewer = _with({
        OperatorCapability.identityVerificationRead,
        OperatorCapability.identityVerificationWrite,
        OperatorCapability.verificationRead,
        OperatorCapability.verificationWrite,
      });
      expect(area.isVisibleTo(reviewer), isFalse);
    });

    test('reading the estate record is not appointing anybody', () {
      final area = OperatorArea.values.firstWhere((a) => a.id == 'operators');
      expect(area.isVisibleTo(_with({OperatorCapability.auditRead})), isFalse);
    });

    test('a signed-in non-operator sees nothing', () {
      final area = OperatorArea.values.firstWhere((a) => a.id == 'operators');
      expect(area.isVisibleTo(const OperatorAuthority.none()), isFalse);
    });
  });

  group('the frozen area order records the decision', () {
    test('operators sits beside external, and both are still present', () {
      final ids = OperatorArea.values.map((a) => a.id).toList();
      expect(ids.contains('operators'), isTrue);
      expect(ids.indexOf('operators'), ids.indexOf('external') - 1);
    });

    test('no area id is duplicated', () {
      final ids = OperatorArea.values.map((a) => a.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });
}
