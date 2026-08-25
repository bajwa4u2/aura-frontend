import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// THE ORDERING INVARIANT — founder ruling, A/V continuation §2.
///
///     CALL INTENT
///       → PREFLIGHT
///       → PERMISSION / DEVICE READINESS
///       → USER PROCEEDS
///       → CALL SESSION CREATED
///       → OTHER PARTY MAY BE RUNG
///
/// `ConversationsRepository.startLive()` is the single act that both creates
/// the realtime session and rings the recipient. Before this chapter it was
/// the FIRST thing `_startCall` did: pressing Call created a session and woke
/// somebody up before the caller knew whether they had a working microphone,
/// and the OS permission prompt then arrived mid-join.
///
/// This is proved structurally, by reading the shipped source, because the
/// invariant is about statement ORDER inside one method and that is exactly
/// what a structural test can prove and a behavioural one cannot isolate. The
/// repository already uses this technique for architectural invariants (see
/// `test/conversation/institution_space_conversation_test.dart`).
///
/// The behavioural half — that dismissing yields a non-proceed answer, so the
/// guard below is actually reached — is certified on the physical handset in
/// `integration_test/av_android_certification_test.dart`.
void main() {
  late String startCall;

  setUpAll(() {
    final src = File(
      'lib/features/conversation/presentation/conversation_screen.dart',
    ).readAsStringSync();

    final begin = src.indexOf('Future<void> _startCall(');
    expect(begin, greaterThan(-1),
        reason: '_startCall was renamed; re-establish this invariant against '
            'whatever replaced it rather than deleting the test');

    // Bound the slice at the next method declaration so nothing later in the
    // file can accidentally satisfy or break the assertions.
    final end = src.indexOf('\n  String _draftPreviewLabel(', begin);
    expect(end, greaterThan(begin));
    startCall = src.substring(begin, end);
  });

  test('the preflight is awaited before anything else happens', () {
    expect(startCall, contains('await CallPreflightSheet.show('),
        reason: 'the preflight is gone — Call would ring somebody again');
  });

  test('a non-proceed answer returns before any session is created', () {
    final guard = startCall.indexOf('if (proceed != true');
    expect(guard, greaterThan(-1),
        reason: 'the preflight result is not checked, so "Not now" would '
            'still start the call');

    final show = startCall.indexOf('CallPreflightSheet.show(');
    expect(show, lessThan(guard),
        reason: 'the guard runs before the preflight is even shown');

    // The guard must actually return, not merely log.
    final afterGuard = startCall.substring(guard, guard + 120);
    expect(afterGuard, contains('return'),
        reason: 'declining did not abort the call');
  });

  test('startLive is reached ONLY after the guard', () {
    final guard = startCall.indexOf('if (proceed != true');
    final startLive = startCall.indexOf('.startLive(');
    expect(startLive, greaterThan(-1),
        reason: 'the call is no longer started here; re-point this invariant');
    expect(startLive, greaterThan(guard),
        reason: 'THE REGRESSION THIS PREVENTS: a session is created, and the '
            'recipient rung, before the caller has proceeded through '
            'readiness');
  });

  test('navigation into the room also happens only after the guard', () {
    final guard = startCall.indexOf('if (proceed != true');
    final push = startCall.indexOf('context.push(');
    expect(push, greaterThan(-1));
    expect(push, greaterThan(guard),
        reason: 'the caller was pushed into a room they had not agreed to '
            'enter');
  });

  test('an audio call does not ask for a camera', () {
    // Asking for permissions a call will never use is how products train
    // people to refuse.
    expect(startCall, contains("wantsCamera: video"),
        reason: 'the preflight requests a camera regardless of call kind');
  });

  test('the person being called is named from governed identity', () {
    // §13: never "User", "Member", "Someone" or "Guest" where a real name
    // exists.
    expect(startCall, contains('conversationDisplayName('),
        reason: 'the preflight no longer names who is being called');
    for (final placeholder in ["'User'", "'Someone'", "'Guest'", "'Member'"]) {
      expect(startCall, isNot(contains(placeholder)),
          reason: 'a placeholder identity appeared in the call preflight');
    }
  });
}
