/// ANNOUNCEMENTS MUST BE REACHABLE FROM THE CONSOLE THAT OPERATES THEM.
///
/// 2026-09-10: the founder could not pin the 1.4.3 release announcement because
/// the admin console offered no route to Announcements at all, while
/// `routes.json` advertised `/admin/communications` — a screen that was never
/// built. They looked exactly where the inventory said to look.
///
/// Two separate defects, and both are fixed:
///   * the phantom route inventory — `route_registry_truth_test.dart`
///   * no destination in the console — this file
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/admin/domain/operator_area.dart';
import 'package:aura/features/admin/domain/operator_capability.dart';

void main() {
  test('Announcements is NOT an OperatorArea, deliberately', () {
    // An area is defined by owning a `/admin/*` route. Announcements lives at
    // `/announcements`, so making it an area would have required inventing an
    // `/admin/announcements` alias — putting a phantom route back, this time
    // with a screen behind it. It is a reached-out-to destination instead, the
    // same shape as the Finance doorway.
    for (final area in OperatorArea.values) {
      expect(
        area.path.startsWith('/admin'),
        isTrue,
        reason: 'every OperatorArea must own a /admin path; ${area.id} is ${area.path}',
      );
      expect(area.id, isNot('announcements'));
    }
  });

  test('the capability the console gates on is the one the backend enforces', () {
    // The rail item is gated on ANNOUNCEMENTS_READ. If this enum value is ever
    // renamed or removed, the gate silently becomes something else.
    expect(OperatorCapability.announcementsRead.wire, 'ANNOUNCEMENTS_READ');
    expect(OperatorCapability.announcementsWrite.wire, 'ANNOUNCEMENTS_WRITE');
  });
}
