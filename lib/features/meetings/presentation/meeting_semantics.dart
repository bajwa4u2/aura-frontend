import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../domain/meeting_lifecycle.dart';
import '../domain/meeting_participation.dart';
import '../../../core/media/device_permission.dart';
import '../../../core/product/temporal.dart';

/// WHAT A MEETING SOUNDS LIKE.
///
/// Founder ruling 2026-08-25 §VII and §XXXIII. The audit found **one**
/// `Semantics` wrapper across 20,281 lines of Meetings client code, against 43
/// interactive controls, 12 tooltips and 109 icons. A person using a screen
/// reader met a wall of "button", "button", "button".
///
/// The ruling is equally clear about the wrong fix: *do not "fix" it by
/// wrapping entire screens in another generic Semantics container*. A screen
/// announced as one blob is no more usable than a screen announced as nothing.
///
/// So the labels are built from the DOMAIN, here, once. Two reasons:
///
///   * a label that is derived from `MeetingPhase` cannot drift away from what
///     the screen is actually showing, the way a hand-typed string does;
///   * the same meeting announces itself identically on the record, in the
///     list, and in the room — which is what makes it navigable at all.
///
/// Nothing here is decorative. Every function answers a question a person
/// cannot answer by looking.
class MeetingSemantics {
  const MeetingSemantics._();

  // ── State ──────────────────────────────────────────────────────────────

  /// The meeting's own condition, said as a sentence rather than shown as a
  /// coloured dot. Colour is the only thing carrying this on screen today,
  /// which makes it invisible to assistive technology and to anyone who
  /// cannot distinguish the colours.
  static String phase(MeetingPhase phase) => switch (phase) {
        MeetingPhase.draft => 'Draft, not yet scheduled',
        MeetingPhase.scheduled => 'Scheduled',
        MeetingPhase.ready => 'Ready to join now',
        MeetingPhase.active => 'Live now',
        MeetingPhase.ended => 'Ended',
        MeetingPhase.cancelled => 'Cancelled',
        MeetingPhase.missed => 'Missed',
        MeetingPhase.unknown => 'Status unavailable',
      };

  /// A whole meeting, in the order a person needs it: what it is, when, and
  /// what state it is in — title first, because that is what they are looking
  /// for in a list.
  static String meeting({
    required String title,
    required MeetingPhase phase,
    DateTime? scheduledAt,
    String? hostName,
    String? institutionName,
  }) {
    final parts = <String>[title];
    if (scheduledAt != null) parts.add(when(scheduledAt));
    if (hostName != null && hostName.trim().isNotEmpty) {
      parts.add('hosted by ${hostName.trim()}');
    }
    if (institutionName != null && institutionName.trim().isNotEmpty) {
      parts.add(institutionName.trim());
    }
    parts.add(MeetingSemantics.phase(phase));
    return parts.join('. ');
  }

  // ── Time ───────────────────────────────────────────────────────────────

  /// A date and time a screen reader can actually read.
  ///
  /// On screen these are abbreviated — "Tue 14:30", "in 5m". Abbreviations are
  /// read out as letters or mispronounced, so the spoken form is spelled out.
  /// §VII names time and date information explicitly.
  static String when(DateTime at) {
    // C0 ratchet: `toLocal()` is applied in exactly one governed place, so
    // screens stop deciding timezone semantics for themselves.
    final local = ProductTime(at, TimeEvent.scheduled).local;
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June', 'July',
      'August', 'September', 'October', 'November', 'December',
    ];
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
      'Sunday',
    ];
    final day = days[(local.weekday - 1).clamp(0, 6)];
    final month = months[(local.month - 1).clamp(0, 11)];
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final meridiem = local.hour < 12 ? 'AM' : 'PM';
    return '$day $month ${local.day}, at $hour:$minute $meridiem';
  }

  /// How long a meeting runs, said in words.
  static String duration(int minutes) {
    if (minutes < 60) return '$minutes minutes';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    final hourWord = hours == 1 ? '1 hour' : '$hours hours';
    return rest == 0 ? hourWord : '$hourWord $rest minutes';
  }

  // ── People ─────────────────────────────────────────────────────────────

  /// One participant, with everything that distinguishes them from the next
  /// one: who, what they are responsible for, and where they are.
  ///
  /// Visually this is a name plus a coloured ring plus two small icons. Spoken,
  /// it has to be a sentence or it is just a name repeated many times.
  static String participant({
    required String name,
    required MeetingAttendance attendance,
    bool? microphoneLive,
    bool? cameraLive,
    bool speaking = false,
  }) {
    final parts = <String>[name];
    switch (attendance.role) {
      case MeetingRole.host:
        parts.add('host');
      case MeetingRole.coHost:
        parts.add('co-host');
      case MeetingRole.guest:
        parts.add('guest');
      case MeetingRole.participant:
        break;
    }
    parts.add(presence(attendance.presence));
    if (microphoneLive == false) parts.add('microphone off');
    if (cameraLive == false) parts.add('camera off');
    if (speaking) parts.add('speaking');
    return parts.join(', ');
  }

  static String presence(MeetingPresence presence) => switch (presence) {
        MeetingPresence.away => 'not here',
        MeetingPresence.knocking => 'waiting to be let in',
        MeetingPresence.admitted => 'admitted, joining',
        MeetingPresence.present => 'in the meeting',
        MeetingPresence.disconnected => 'connection lost',
        MeetingPresence.departed => 'left',
        MeetingPresence.removed => 'removed',
      };

  static String invitation(MeetingInvitation invitation) =>
      switch (invitation) {
        MeetingInvitation.awaiting => 'invited, has not replied',
        MeetingInvitation.accepted => 'accepted',
        MeetingInvitation.declined => 'declined',
        MeetingInvitation.notInvited => 'joined without an invitation',
      };

  /// The roster as one spoken summary, for a list header. Counting by ear is
  /// not possible, so the count is said rather than left to be inferred.
  static String roster(MeetingRoster roster) {
    if (roster.all.isEmpty) return 'No participants yet';
    final parts = <String>['${roster.all.length} participants'];
    if (roster.present > 0) parts.add('${roster.present} here now');
    if (roster.knocking > 0) {
      parts.add('${roster.knocking} waiting to be let in');
    }
    return parts.join(', ');
  }

  // ── Controls ───────────────────────────────────────────────────────────

  /// A toggle announces its EFFECT and its CURRENT STATE, never just an icon
  /// name. "Microphone" tells a person nothing about whether they are audible.
  static String toggle({
    required String thing,
    required bool on,
  }) =>
      '$thing ${on ? 'on' : 'off'}. Activate to turn ${on ? 'off' : 'on'}';

  /// A device that is not merely off but cannot be turned on. Announcing this
  /// as an ordinary toggle would invite somebody to press a control that
  /// cannot work — §IX's "do not fake permission success" applied to sound.
  static String deviceUnavailable(DeviceReadiness readiness) {
    final recovery = readiness.recovery;
    return recovery == null || recovery.trim().isEmpty
        ? readiness.summary
        : '${readiness.summary}. ${recovery.trim()}';
  }

  // ── Announcements ──────────────────────────────────────────────────────

  /// Say something that has just happened, without stealing focus.
  ///
  /// §XXXIII: meeting state changes should be meaningful to assistive
  /// technology *without creating announcement noise*. Polite assertiveness is
  /// the whole point — somebody joining should not interrupt a sentence
  /// somebody is already reading.
  static void announce(BuildContext context, String message) {
    final text = message.trim();
    if (text.isEmpty) return;
    // Polite by default: a person joining must not cut across a sentence
    // somebody is already having read to them.
    SemanticsService.sendAnnouncement(
      View.of(context),
      text,
      Directionality.of(context),
    );
  }
}

/// A labelled control, without a second widget tree to maintain.
///
/// This exists because the alternative — remembering to write `Semantics(...)`
/// around 43 controls — is exactly how the product ended up with one. It is a
/// thin wrapper on purpose: it adds meaning, never layout.
class MeetingAction extends StatelessWidget {
  const MeetingAction({
    super.key,
    required this.label,
    required this.child,
    this.hint,
    this.enabled = true,
    this.selected,
  });

  /// What activating this does, in the person's terms.
  final String label;

  /// What will happen as a result, when that is not obvious from the label.
  final String? hint;

  final bool enabled;
  final bool? selected;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        enabled: enabled,
        selected: selected,
        label: label,
        hint: hint,
        // The child's own text would otherwise be announced a second time
        // after the label — "Join. Join." — which is the noise §XXXIII warns
        // about.
        excludeSemantics: true,
        child: child,
      );
}

/// Information that is currently carried by colour, shape or position alone.
class MeetingStatus extends StatelessWidget {
  const MeetingStatus({
    super.key,
    required this.label,
    required this.child,
    this.live = false,
  });

  final String label;

  /// Whether this value changes on its own and should be re-read when it does.
  final bool live;

  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
        label: label,
        liveRegion: live,
        excludeSemantics: true,
        child: child,
      );
}
