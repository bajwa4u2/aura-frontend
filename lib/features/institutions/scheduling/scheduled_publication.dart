import 'package:flutter/material.dart';

import '../../../core/product/temporal.dart';

/// SCHEDULED PUBLICATION (2026-10-11).
///
/// An institution post or announcement can be published at a chosen time. It
/// stays a draft until then; at its time Aura publishes it as the person who
/// scheduled it, checking everything again. The backend refuses a time less
/// than 5 minutes or more than a year away; the picker below offers only
/// times inside that window so nobody picks one that will be refused.
const Duration kScheduleMinLead = Duration(minutes: 5);
const Duration kScheduleMaxLead = Duration(days: 365);

/// "Publishes Tue, Oct 14, 2026 · 9:00 AM" in the viewer's zone (founder,
/// 2026-09-29: always the written date with its time).
String publishesLabel(DateTime at) => 'Publishes ${AuraTemporal.fullShort(at)}';

/// Asks for a date, then a time. Returns null if either is dismissed.
/// A time that has become too close or too far by the time it is chosen is
/// answered with a message, not silently moved.
Future<DateTime?> pickPublishTime(
  BuildContext context, {
  DateTime? initial,
  DateTime Function() now = DateTime.now,
}) async {
  final start = now();
  final suggested = initial != null && initial.isAfter(start.add(kScheduleMinLead))
      // The same instant as the viewer's wall clock (the pickers work in it).
      ? DateTime.fromMillisecondsSinceEpoch(initial.millisecondsSinceEpoch)
      : start.add(const Duration(hours: 1));
  final date = await showDatePicker(
    context: context,
    initialDate: suggested,
    firstDate: DateTime(start.year, start.month, start.day),
    lastDate: start.add(kScheduleMaxLead),
    helpText: 'Publish on',
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(suggested),
    helpText: 'Publish at',
  );
  if (time == null || !context.mounted) return null;
  final at = DateTime(date.year, date.month, date.day, time.hour, time.minute);
  final problem = scheduleTimeProblem(at, now: now());
  if (problem != null) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(problem), behavior: SnackBarBehavior.floating),
    );
    return null;
  }
  return at;
}

/// The same rule the backend applies, in its words. Null when the time is fine.
String? scheduleTimeProblem(DateTime at, {required DateTime now}) {
  final lead = at.difference(now);
  if (lead < kScheduleMinLead) {
    return 'Choose a time at least 5 minutes from now, or publish now.';
  }
  if (lead > kScheduleMaxLead) return 'Choose a time within the next year.';
  return null;
}

/// What the backend says after an edit to a scheduled item, or after an
/// attempt to schedule: still fine, or what needs attention.
class ScheduleCheck {
  const ScheduleCheck({required this.ok, this.code, this.message, this.outcome});

  final bool ok;
  final String? code;
  final String? message;
  final String? outcome;

  /// The integrity review needs the person's answer (acknowledgement, a second
  /// reviewer, approval) before this can go out on its own.
  bool get needsIntegrityReview => code == 'INTEGRITY_ACTION_REQUIRED';

  static ScheduleCheck? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    return ScheduleCheck(
      ok: m['ok'] == true,
      code: m['code']?.toString(),
      message: m['message']?.toString(),
      outcome: m['outcome']?.toString(),
    );
  }
}

/// The schedule fields an unpublished post or announcement carries.
class PublicationSchedule {
  const PublicationSchedule({
    this.publishAt,
    this.timezone,
    this.scheduledByUserId,
    this.failedAt,
    this.failureReason,
  });

  final DateTime? publishAt;
  final String? timezone;
  final String? scheduledByUserId;
  final DateTime? failedAt;
  final String? failureReason;

  bool get isScheduled => publishAt != null;
  bool get hasFailed => failedAt != null;

  static const none = PublicationSchedule();

  static PublicationSchedule fromJson(Map<String, dynamic> json) {
    DateTime? when(Object? v) => v == null ? null : DateTime.tryParse(v.toString());
    return PublicationSchedule(
      publishAt: when(json['scheduledPublishAt']),
      timezone: json['scheduledTimezone']?.toString(),
      scheduledByUserId: json['scheduledByUserId']?.toString(),
      failedAt: when(json['scheduleFailedAt']),
      failureReason: json['scheduleFailureReason']?.toString(),
    );
  }
}
