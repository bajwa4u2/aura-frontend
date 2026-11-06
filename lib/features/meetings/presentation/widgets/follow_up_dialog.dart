import 'package:flutter/material.dart';

import '../../../../core/product/temporal.dart';
import '../../../../core/ui/aura_notice.dart';
import '../../../../core/ui/aura_space.dart';
import '../../../../core/ui/aura_surface.dart';
import '../meeting_schedule_rules.dart';

/// What the person chose in the follow-up dialog.
typedef FollowUpChoice = ({DateTime at, int durationMinutes, String title});

/// SCHEDULE A FOLLOW-UP (6 Nov 2026). The next meeting with the same people,
/// from the meeting it continues: the server copies the participants and
/// invitees, the institution and the settings.
///
/// The suggested time is the same time a week later, or tomorrow when that
/// has already passed. Returns null when dismissed.
Future<FollowUpChoice?> showFollowUpDialog(
  BuildContext context, {
  required String meetingTitle,
  required DateTime? scheduledAt,
  required int durationMinutes,
  DateTime? now,
}) {
  final n = now ?? DateTime.now();
  final base = scheduledAt == null
      ? null
      : ProductTime(scheduledAt, TimeEvent.scheduled).local;
  var suggested = base == null
      ? DateTime(n.year, n.month, n.day + 1, 10)
      : base.add(const Duration(days: 7));
  if (isPastMeetingTime(suggested, now: n)) {
    suggested = DateTime(n.year, n.month, n.day + 1, suggested.hour,
        suggested.minute);
  }
  return showDialog<FollowUpChoice>(
    context: context,
    builder: (_) => _FollowUpDialog(
      title: 'Follow-up: $meetingTitle',
      at: suggested,
      durationMinutes: durationMinutes,
    ),
  );
}

class _FollowUpDialog extends StatefulWidget {
  const _FollowUpDialog({
    required this.title,
    required this.at,
    required this.durationMinutes,
  });

  final String title;
  final DateTime at;
  final int durationMinutes;

  @override
  State<_FollowUpDialog> createState() => _FollowUpDialogState();
}

class _FollowUpDialogState extends State<_FollowUpDialog> {
  late final TextEditingController _title =
      TextEditingController(text: widget.title);
  late DateTime _at = widget.at;
  late int _duration = widget.durationMinutes;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = await showDatePicker(
      context: context,
      initialDate: _at.isBefore(today) ? today : _at,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_at),
    );
    if (time == null || !mounted) return;
    final picked =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (isPastMeetingTime(picked)) {
      AuraNotice.problem(context, kPastMeetingTimeMessage);
      return;
    }
    setState(() => _at = picked);
  }

  @override
  Widget build(BuildContext context) {
    final loc = MaterialLocalizations.of(context);
    final when = '${loc.formatFullDate(_at)} at '
        '${loc.formatTimeOfDay(TimeOfDay.fromDateTime(_at))}';
    return AlertDialog(
      title: const Text('Schedule a follow-up'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'The same people are invited to the new meeting.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AuraSurface.muted),
              ),
              const SizedBox(height: AuraSpace.s12),
              TextField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Meeting title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AuraSpace.s12),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today_rounded),
                label: Text(when),
                onPressed: _pick,
              ),
              const SizedBox(height: AuraSpace.s12),
              DropdownButtonFormField<int>(
                initialValue: _duration,
                decoration: const InputDecoration(
                  labelText: 'Duration',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final m in meetingDurationChoices(widget.durationMinutes))
                    DropdownMenuItem(value: m, child: Text('$m min')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _duration = v);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (isPastMeetingTime(_at)) {
              AuraNotice.problem(context, kPastMeetingTimeMessage);
              return;
            }
            Navigator.pop<FollowUpChoice>(context, (
              at: _at,
              durationMinutes: _duration,
              title: _title.text.trim(),
            ));
          },
          child: const Text('Schedule follow-up'),
        ),
      ],
    );
  }
}
