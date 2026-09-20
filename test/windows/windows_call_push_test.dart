import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/realtime/application/incoming_call_projection.dart'
    as projection;

/// WINDOWS RINGS WHEN AURA IS CLOSED (2026-09-19).
///
/// The server has sent Windows call pushes as raw WNS since the adapter
/// shipped; nothing in `windows/` listened, so they evaporated and a Windows
/// machine only "rang" while Aura happened to be open. The receive path added
/// here has two halves — a foreground handler and a package background task —
/// and the failures it can suffer are all SILENT ones, which is what these
/// tests are for.
void main() {
  group('the raw payload the server actually sends', () {
    // MIRRORED FROM THE SERVER, NOT INVENTED.
    //
    // The WNS adapter's `buildBody` sends {type, title, body, data:{…}} —
    // nested, unlike FCM's flat data map — where `type` is the communication
    // type and `data` is the attention decision's payload
    // (`attention-policy.service.ts` `evaluateForLiveInvited`). It is handed
    // to the projection authority unreshaped, because that authority already
    // reads `data` as a nested map.
    //
    // The first version of this fixture omitted `attention`, and the test
    // failed — correctly. `isCallInterruptPayload` requires it, so a payload
    // without it would never have presented a call on Windows. Writing the
    // fixture from the server's own construction is the difference between a
    // test that proves the contract and one that agrees with the code.
    Map<String, dynamic> ring() => <String, dynamic>{
          'type': 'LIVE',
          'title': 'Incoming call',
          'body': 'Ada is calling',
          'data': <String, dynamic>{
            'sessionId': 'rts_windows_1',
            'channel': 'IN_APP',
            'attention': 'INTERRUPT',
            'notificationKind': 'CALL_RINGING',
            'mediaMode': 'VIDEO',
          },
        };

    Map<String, dynamic> cancelled() => <String, dynamic>{
          'type': 'CALL_CANCELLED',
          'title': 'Missed call',
          'body': 'Ada cancelled the call',
          'data': <String, dynamic>{
            'sessionId': 'rts_windows_1',
            'notificationKind': 'CALL_CANCELLED',
            'state': 'CANCELLED',
          },
        };

    test('a ring is recognised as a call to present', () {
      expect(projection.isCallInterruptPayload(ring()), isTrue);
      expect(projection.isTerminalCallPayload(ring()), isFalse);
      expect(projection.resolveCallSessionId(ring()), 'rts_windows_1');
    });

    test('a cancellation is recognised as terminal, and names its session', () {
      // THE MACHINE THAT RANG IS THE MACHINE TOLD TO STOP. The server sends
      // ring and cancel over the same transport with a shared collapse key;
      // the client only honours that if it reads the terminal case instead of
      // treating every call push as an arrival.
      expect(projection.isTerminalCallPayload(cancelled()), isTrue);
      expect(projection.isCallInterruptPayload(cancelled()), isFalse);
      expect(projection.resolveCallSessionId(cancelled()), 'rts_windows_1');
    });
  });

  group('the class id that three files must agree on', () {
    // A MISMATCH HERE REPORTS NOTHING. Registration succeeds against one id,
    // the manifest declares another, the push arrives, Windows has nothing to
    // activate — and no error is raised anywhere. So the agreement is pinned.
    const clsid = '7A6C2C1E-3E5B-4C52-9E1A-2F6B1D5C7A90';

    String read(String path) => File(path).readAsStringSync();

    test('the runner registers the id the manifest declares', () {
      final runner = read('windows/runner/call_push.cpp');
      // The C++ literal is the same guid in field form.
      expect(runner, contains('0x7a6c2c1e'));
      expect(runner, contains('0x3e5b'));
      expect(runner, contains('0x4c52'));
      expect(
        read('tool/windows/declare_call_push_task.dart'),
        contains(clsid),
        reason: 'the packaging tool must declare the id the runner serves',
      );
      expect(
        read('tool/windows/package_windows.dart'),
        contains(clsid),
        reason: 'the release gate must check for the id actually used',
      );
    });

    test('the COM server argument is the same on both sides', () {
      expect(
        read('windows/runner/call_push.cpp'),
        contains('-RegisterProcessAsComServer'),
      );
      expect(
        read('tool/windows/declare_call_push_task.dart'),
        contains('Arguments="-RegisterProcessAsComServer"'),
        reason:
            'Windows starts the executable with the manifest argument; the '
            'runner must recognise that exact string or it builds a window '
            'instead of serving the task',
      );
    });
  });

  group('the release gate refuses a package that cannot ring', () {
    // The share-target check exists because a package can install, run, and
    // silently not be a share target. A package that cannot be woken by a call
    // push fails the same way, so it is checked the same way.
    //
    // CORRECTED 2026-09-20, at the 1.4.4 release gate. This used to require
    // the gate to look for a `windows.backgroundTasks` extension as well. That
    // extension cannot be in the manifest: a winmain COM task is registered in
    // code by `SetTaskEntryPointClsid`, and declaring the extension anyway is
    // refused by the manifest schema — MakeAppx will not pack the package at
    // all. So the old assertion demanded a gate that could only ever pass a
    // package that could not exist, and neither the test nor the gate noticed,
    // because nothing had packed the manifest they were guarding.
    //
    // The COM server is the declaration that carries the behaviour, and it is
    // the one thing worth checking.
    test('packaging verifies the declaration that carries the behaviour', () {
      final gate = File('tool/windows/package_windows.dart').readAsStringSync();
      expect(gate, contains('windows.comServer'));
      expect(
        gate,
        contains('while Aura is already open'),
        reason: 'the failure must be described, not just detected',
      );
    });

    test('the manifest never declares a background task extension', () {
      // The packable shape, pinned. A future edit that adds the extension back
      // makes every Windows release unbuildable, and the error it produces
      // ("Unspecified error", after the first schema failure) does not say so.
      final declare =
          File('tool/windows/declare_call_push_task.dart').readAsStringSync();
      final emitted = RegExp(r"writeln\('\s*<[^']*'").allMatches(declare);
      for (final m in emitted) {
        expect(
          m.group(0),
          isNot(contains('windows.backgroundTasks')),
          reason: 'a backgroundTasks extension cannot be packed; the task is '
              'registered in code by SetTaskEntryPointClsid',
        );
      }
    });

    test('the packaging command runs the declaration step', () {
      expect(
        File('tool/windows/package_windows.dart').readAsStringSync(),
        contains('tool/windows/declare_call_push_task.dart'),
        reason:
            'a declaration nobody runs is the defect this tool was written to '
            'prevent',
      );
    });
  });
}
