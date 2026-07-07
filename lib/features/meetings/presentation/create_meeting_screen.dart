import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/utils/local_timezone.dart';
import '../application/meetings_provider.dart';

class CreateMeetingScreen extends ConsumerStatefulWidget {
  /// Ownership: when scheduling from an Institution Workspace, the created
  /// meeting belongs to that institution end to end.
  final String? institutionId;

  const CreateMeetingScreen({super.key, this.institutionId});

  @override
  ConsumerState<CreateMeetingScreen> createState() =>
      _CreateMeetingScreenState();
}

class _CreateMeetingScreenState extends ConsumerState<CreateMeetingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  DateTime? _scheduledAt;
  int _durationMinutes = 60;
  bool _waitingRoom = false;
  bool _allowGuests = true;
  bool _saving = false;

  static const _durations = [15, 30, 45, 60, 90, 120];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt ?? now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
          _scheduledAt ?? now.add(const Duration(hours: 1))),
    );
    if (time == null || !mounted) return;

    setState(() {
      _scheduledAt = DateTime(
          date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_scheduledAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick a date and time')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(meetingsRepositoryProvider);
      final meeting = await repo.createMeeting(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        type: 'SCHEDULED',
        scheduledAt: _scheduledAt!.toUtc().toIso8601String(),
        durationMinutes: _durationMinutes,
        timezone: resolveLocalTimezone(),
        waitingRoomEnabled: _waitingRoom,
        allowGuests: _allowGuests,
        organizationId: widget.institutionId,
      );

      if (widget.institutionId == null) {
        ref.invalidate(upcomingMeetingsProvider);
      } else {
        ref.invalidate(
          institutionUpcomingMeetingsProvider(widget.institutionId!),
        );
      }

      if (!mounted) return;
      context.pushReplacement(
        widget.institutionId == null
            ? '/meetings/${meeting.id}'
            : '/institution/${widget.institutionId}/meetings/${meeting.id}',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Unable to create meeting. Try again.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = _scheduledAt == null
        ? 'Pick date and time'
        : DateFormat('EEE, MMM d, yyyy · h:mm a').format(_scheduledAt!);

    return AuraScaffold(
      title: 'Schedule meeting',
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => context.pop(),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AuraSpace.s16),
          children: [
            const _SectionLabel('Meeting title'),
            TextFormField(
              controller: _titleCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'e.g. Product review · Investor call',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Title is required'
                  : null,
            ),
            const SizedBox(height: AuraSpace.s16),

            const _SectionLabel('Description (optional)'),
            TextFormField(
              controller: _descCtrl,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Agenda, context, or notes for participants',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AuraSpace.s16),

            const _SectionLabel('Date and time'),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today_rounded, size: 18),
              label: Text(dateLabel),
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
              ),
              onPressed: _pickDateTime,
            ),
            const SizedBox(height: AuraSpace.s16),

            const _SectionLabel('Duration'),
            DropdownButtonFormField<int>(
              initialValue: _durationMinutes,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: _durations
                  .map((d) => DropdownMenuItem(
                        value: d,
                        child: Text(_durationLabel(d)),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _durationMinutes = v);
              },
            ),
            const SizedBox(height: AuraSpace.s20),

            const Divider(),
            const SizedBox(height: AuraSpace.s8),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Allow guests to join'),
              subtitle: const Text(
                  'People without an Aura account can join via link'),
              value: _allowGuests,
              onChanged: (v) => setState(() => _allowGuests = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Waiting room'),
              subtitle: const Text(
                  'Participants wait until the host admits them'),
              value: _waitingRoom,
              onChanged: (v) => setState(() => _waitingRoom = v),
            ),

            const SizedBox(height: AuraSpace.s24),

            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Schedule meeting'),
              ),
            ),
            const SizedBox(height: AuraSpace.s32),
          ],
        ),
      ),
    );
  }

  String _durationLabel(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (m == 0) return '${h}h';
    return '${h}h ${m}min';
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s6),
      child: Text(label,
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(fontWeight: FontWeight.w600)),
    );
  }
}
