import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/media/device_permission.dart';
import 'package:aura/features/meetings/domain/meeting.dart';
import 'package:aura/features/meetings/domain/meeting_lifecycle.dart';
import 'package:aura/features/meetings/domain/meeting_participation.dart';
import 'package:aura/features/meetings/presentation/meeting_semantics.dart';

/// ACCESSIBILITY AS DOMAIN, NOT DECORATION — §VII and §XXXIII.
///
/// The audit's P0 was one `Semantics` wrapper across 20,281 lines. The fix the
/// ruling forbids is wrapping screens in a bigger generic container; the fix
/// it asks for is meaning. These tests are about whether the words carry
/// information a person cannot get by looking.
void main() {
  group('meeting state is said, not coloured', () {
    test('every phase has its own words', () {
      final said = <String>{};
      for (final phase in MeetingPhase.values) {
        final text = MeetingSemantics.phase(phase);
        expect(text.trim(), isNotEmpty, reason: '$phase says nothing');
        expect(said.add(text), isTrue,
            reason: '$phase shares its announcement with another phase, so '
                'they cannot be told apart by ear');
      }
    });

    test('"unknown" is admitted rather than dressed up', () {
      expect(MeetingSemantics.phase(MeetingPhase.unknown),
          contains('unavailable'));
    });
  });

  group('time is spoken, not abbreviated', () {
    test('a date reads as words a screen reader can pronounce', () {
      // On screen this is "Tue, Aug 25, 2:30 PM". Abbreviations are read out
      // as letters or mispronounced.
      final text = MeetingSemantics.when(DateTime(2026, 8, 25, 14, 30));
      expect(text, contains('August'));
      expect(text, contains('2:30 PM'));
      expect(text, isNot(contains('Aug ')));
    });

    test('midnight and noon are not "0:00"', () {
      expect(MeetingSemantics.when(DateTime(2026, 8, 25, 0, 5)),
          contains('12:05 AM'));
      expect(MeetingSemantics.when(DateTime(2026, 8, 25, 12, 0)),
          contains('12:00 PM'));
    });

    test('a duration is said in units, not minutes-as-a-number', () {
      expect(MeetingSemantics.duration(30), '30 minutes');
      expect(MeetingSemantics.duration(60), '1 hour');
      expect(MeetingSemantics.duration(90), '1 hour 30 minutes');
      expect(MeetingSemantics.duration(120), '2 hours');
    });
  });

  group('a participant is a sentence, not a name and some icons', () {
    MeetingAttendance attendance({
      String role = 'PARTICIPANT',
      String rsvp = 'ACCEPTED',
      DateTime? joinedAt,
    }) =>
        MeetingAttendance.of(MeetingParticipant(
          id: 'p',
          meetingId: 'm',
          role: role,
          rsvpStatus: rsvp,
          attended: joinedAt != null,
          joinedAt: joinedAt,
        ));

    test('it carries who, what they are responsible for, and where they are',
        () {
      final text = MeetingSemantics.participant(
        name: 'Amara Okafor',
        attendance: attendance(role: 'HOST', joinedAt: DateTime(2026, 8, 25)),
        microphoneLive: false,
      );
      expect(text, contains('Amara Okafor'));
      expect(text, contains('host'));
      expect(text, contains('in the meeting'));
      expect(text, contains('microphone off'));
    });

    test('muted and unmuted do not sound the same', () {
      final muted = MeetingSemantics.participant(
        name: 'A',
        attendance: attendance(),
        microphoneLive: false,
      );
      final live = MeetingSemantics.participant(
        name: 'A',
        attendance: attendance(),
        microphoneLive: true,
      );
      expect(muted, isNot(live),
          reason: 'both rendered a microphone icon and announced the same '
              'thing, which is the state the audit found');
    });

    test('every presence has distinct words', () {
      final said = <String>{};
      for (final p in MeetingPresence.values) {
        expect(said.add(MeetingSemantics.presence(p)), isTrue, reason: '$p');
      }
    });

    test('a roster says its size, because counting by ear is not possible',
        () {
      final roster = MeetingRoster([
        attendance(joinedAt: DateTime(2026, 8, 25)),
        attendance(),
      ]);
      expect(MeetingSemantics.roster(roster), contains('2 participants'));
      expect(MeetingSemantics.roster(roster), contains('1 here now'));
    });

    test('an empty roster says so plainly', () {
      expect(MeetingSemantics.roster(const MeetingRoster([])),
          'No participants yet');
    });
  });

  group('a toggle announces its effect and its state', () {
    test('never just the name of the thing', () {
      final on = MeetingSemantics.toggle(thing: 'Microphone', on: true);
      final off = MeetingSemantics.toggle(thing: 'Microphone', on: false);
      expect(on, contains('on'));
      expect(on, contains('turn off'));
      expect(off, contains('off'));
      expect(off, contains('turn on'));
      expect(on, isNot(off));
    });
  });

  group('a whole meeting introduces itself in a useful order', () {
    test('title first — that is what somebody is scanning for', () {
      final text = MeetingSemantics.meeting(
        title: 'Quarterly review',
        phase: MeetingPhase.ready,
        scheduledAt: DateTime(2026, 8, 25, 9),
        hostName: 'Amara Okafor',
        institutionName: 'Aura',
      );
      expect(text, startsWith('Quarterly review'));
      expect(text, contains('hosted by Amara Okafor'));
      expect(text, contains('Ready to join now'));
    });

    test('it omits what it does not know rather than saying "unknown"', () {
      final text = MeetingSemantics.meeting(
        title: 'Catch up',
        phase: MeetingPhase.scheduled,
      );
      expect(text, 'Catch up. Scheduled');
    });
  });

  group('§IX — a device problem says what to do about it', () {
    test('every unusable state offers something other than "try again"', () {
      for (final state in DevicePermissionState.values) {
        if (state == DevicePermissionState.granted ||
            state == DevicePermissionState.notRequested) {
          continue;
        }
        final readiness =
            DeviceReadiness(kind: MediaDeviceKind.camera, state: state);
        expect(readiness.summary.trim(), isNotEmpty, reason: '$state');
        expect(readiness.recovery, isNotNull,
            reason: '$state left a person with nothing to do');
      }
    });

    test('a refused permission is not the same message as a busy camera', () {
      const denied = DeviceReadiness(
          kind: MediaDeviceKind.camera, state: DevicePermissionState.denied);
      const busy = DeviceReadiness(
          kind: MediaDeviceKind.camera, state: DevicePermissionState.inUse);
      expect(denied.summary, isNot(busy.summary));
      expect(busy.recovery, contains('Close the other app'));
    });

    test('a restriction does not tell somebody to change a setting they cannot',
        () {
      const restricted = DeviceReadiness(
        kind: MediaDeviceKind.microphone,
        state: DevicePermissionState.restricted,
      );
      expect(restricted.recovery, contains('cannot be changed from Aura'));
    });

    test('"not checked yet" is not an error and offers no recovery', () {
      const unknown = DeviceReadiness.unknown(MediaDeviceKind.microphone);
      expect(unknown.recovery, isNull,
          reason: 'the product scolded somebody before it had asked anything');
      expect(unknown.canRetryInApp, isTrue);
    });

    test('a denial cannot be retried in-app, so it must not offer to', () {
      const denied = DeviceReadiness(
          kind: MediaDeviceKind.microphone, state: DevicePermissionState.denied);
      expect(denied.canRetryInApp, isFalse);
    });
  });

  group('§IX — media failures are classified, not swallowed', () {
    test('the four real cases are told apart', () {
      expect(
        classifyMediaError('NotAllowedError: Permission denied',
            kind: MediaDeviceKind.camera),
        DevicePermissionState.denied,
      );
      expect(
        classifyMediaError('NotReadableError: Could not start video source',
            kind: MediaDeviceKind.camera),
        DevicePermissionState.inUse,
      );
      expect(
        classifyMediaError('NotFoundError: Requested device not found',
            kind: MediaDeviceKind.camera),
        DevicePermissionState.unavailable,
      );
      expect(
        classifyMediaError('SecurityError: insecure context',
            kind: MediaDeviceKind.camera),
        DevicePermissionState.restricted,
      );
    });

    test('an unrecognised failure is NOT reported as a denial', () {
      // Telling somebody they refused access when they did not is worse than
      // telling them the device did not work.
      expect(
        classifyMediaError('something else entirely',
            kind: MediaDeviceKind.camera),
        DevicePermissionState.unavailable,
      );
      expect(classifyMediaError(null, kind: MediaDeviceKind.camera),
          DevicePermissionState.unavailable);
    });
  });

  group('readiness knows what matters most', () {
    test('being unheard outranks being unseen', () {
      const readiness = MediaReadiness(
        microphone: DeviceReadiness(
            kind: MediaDeviceKind.microphone,
            state: DevicePermissionState.denied),
        camera: DeviceReadiness(
            kind: MediaDeviceKind.camera,
            state: DevicePermissionState.unavailable),
      );
      expect(readiness.primaryConcern?.kind, MediaDeviceKind.microphone);
    });

    test('a meeting is still joinable without either', () {
      // Listening is a legitimate way to attend; refusing entry would be worse
      // than joining silent.
      expect(MediaReadiness.unchecked.canJoin, isTrue);
    });

    test('nothing is said when nothing is wrong', () {
      const ok = MediaReadiness(
        microphone: DeviceReadiness(
            kind: MediaDeviceKind.microphone,
            state: DevicePermissionState.granted),
        camera: DeviceReadiness(
            kind: MediaDeviceKind.camera, state: DevicePermissionState.granted),
      );
      expect(ok.primaryConcern, isNull);
      expect(ok.isFullyReady, isTrue);
    });

    test('an unasked device is not a concern', () {
      expect(MediaReadiness.unchecked.primaryConcern, isNull,
          reason: 'the product complained before it had asked');
    });
  });
}
