import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// CREATE MUST NOT DECIDE ANNOUNCE AUTHORITY FROM A COLD DISPLAY CACHE.
///
/// `appAdminCachedDisplayProvider` is populated by a probe that only fires on
/// entering `/admin`. Create read it to answer "may this person announce for
/// Aura?", so a platform admin who had not opened the admin workspace this
/// session was silently routed to `/announcements/create?scope=institution`
/// — a drafting-only surface whose Publish button is disabled. Nothing was
/// sent, so nothing appeared in the admin audit log either; the button simply
/// did nothing, which is the hardest kind of defect to report.
///
/// `shell_header_tools.dart` hit the same wall for the operator entrance and
/// moved to `canEnterOperatorConsoleProvider`, in its own words because "an
/// operator could not see the door until they had already found it by typing
/// the address". This gate keeps Create on that side of the lesson.
void main() {
  final src = File(
    'lib/features/create/presentation/create_hub_screen.dart',
  ).readAsStringSync();

  test('platform-announce authority is asked for, not read from the cache', () {
    expect(
      src.contains('canEnterOperatorConsoleProvider'),
      isTrue,
      reason: 'Create must ask the audit-safe operator question before '
          'offering to announce for Aura.',
    );
    expect(
      src.contains('appAdminCachedDisplayProvider'),
      isFalse,
      reason: 'The display cache is only warm after a visit to /admin. '
          'Deciding announce authority from it silently downgrades a platform '
          'admin to a surface that cannot publish.',
    );
  });

  test('the institution fallback is still reachable for a speaker', () {
    // The fix must not remove the legitimate route: someone who speaks for an
    // institution and is not a platform admin still composes there.
    expect(src.contains("/announcements/create?scope=institution"), isTrue);
    expect(
      src.contains('InstitutionAccessState.authorizedSpeaker'),
      isTrue,
      reason: 'Institution announce authority is a separate grant and must '
          'keep its own check.',
    );
  });

  test('the editor explains a refusal it used to keep to itself', () {
    final editor = File(
      'lib/features/announcements/presentation/announcement_editor_screen.dart',
    ).readAsStringSync();

    // `_canSubmit` blocks on `!_isPlatformMode`, and `_submitBlockedReason`
    // used to return null for exactly that case — a disabled Publish with no
    // sentence anywhere on the surface.
    final reason = RegExp(
      r'String\?\s+get\s+_submitBlockedReason\s*\{(.*?)\n  \}',
      dotAll: true,
    ).firstMatch(editor)?.group(1);

    expect(reason, isNotNull, reason: '_submitBlockedReason moved or changed shape.');
    expect(
      reason!.contains('_isPlatformMode'),
      isTrue,
      reason: 'Every gate in _canSubmit must have words. A refusal a person '
          'cannot see is indistinguishable from a broken button.',
    );
  });
}
