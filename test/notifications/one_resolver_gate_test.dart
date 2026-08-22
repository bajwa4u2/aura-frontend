import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ONE SEMANTIC AUTHORITY FOR NOTIFICATION TEXT.
//
// Aura had EIGHT places composing notification presentation — five in this
// client, three on the backend. Each was internally consistent and they
// disagreed with each other, which is why fixing the backend's forty classes
// left the Notifications screen still saying "<name> interacted with your
// content" for a call: it was answering the same question from its own table.
//
// The rule is not "one file". It is one ANSWER per event. This gate holds the
// client half: only the canonical resolver may turn a notification class into
// a sentence.
const _authority = 'lib/core/notifications/notification_presentation.dart';

/// A RATCHET, NOT AN EXEMPTION.
///
/// Converged so far: the Notifications screen, the rail's activity row, and on
/// the backend the email builder's subjects and CommunicationsService — all now
/// derive from one authority.
///
/// These two do not yet. `activity_screen.dart` carries SIX separate
/// type-switches (title, subtitle, icon, grouping, ...) and renders the
/// viewer's own outgoing actions as well as notifications, so converging it is
/// a real pass rather than a delete — and doing it blind risks the Activity
/// surface. `since_you_were_here.dart` is a small digest with two phrases.
///
/// This list may only ever SHRINK. Adding to it is the drift the gate exists
/// to stop; the honest move when a new surface needs notification text is to
/// consume the authority.
const _notYetConverged = <String>[
  'lib/features/activity/presentation/activity_screen.dart',
  'lib/features/public/widgets/since_you_were_here.dart',
];

/// Sentences that only a notification resolver would ever compose.
const _classPhrases = <String>[
  'liked your post',
  'reposted your',
  'sent you a message',
  'started following you',
  'interacted with your content',
  'mentioned you',
  'invited you to a space',
  'invited you to a discussion',
  'Missed call from',
  'started a call',
];

String _codeOnly(String source) => source
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

void main() {
  test('only the canonical resolver composes notification sentences', () {
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(String.fromCharCode(92), '/');
      if (path.endsWith('notification_presentation.dart')) continue;
      if (_notYetConverged.contains(path)) continue;

      final code = _codeOnly(entity.readAsStringSync());
      for (final phrase in _classPhrases) {
        if (code.contains(phrase)) offenders.add('$path :: "$phrase"');
      }
    }

    expect(offenders, isEmpty,
        reason: 'a second resolver is how the rail, the screen, the ribbon and '
            'the inbox came to describe the same event differently');
  });

  test('the canonical resolver is actually where the sentences live', () {
    final authority = File(_authority).readAsStringSync();
    for (final phrase in ['liked your post', 'sent you a message', 'Missed call']) {
      expect(authority, contains(phrase),
          reason: 'the authority must own the wording, not delegate it away');
    }
  });
}
