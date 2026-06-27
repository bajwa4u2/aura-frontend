import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../application/meetings_provider.dart';
import '../domain/availability_profile.dart';

class SlotPickerScreen extends ConsumerStatefulWidget {
  final AvailabilityProfile profile;
  const SlotPickerScreen({super.key, required this.profile});

  @override
  ConsumerState<SlotPickerScreen> createState() => _SlotPickerScreenState();
}

class _SlotPickerScreenState extends ConsumerState<SlotPickerScreen> {
  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedDate;
  int _selectedDuration = 0;

  AvailabilityProfile get profile => widget.profile;

  @override
  void initState() {
    super.initState();
    _selectedDuration = profile.defaultDuration;
  }

  AsyncValue<List<TimeSlot>> _slotsForDate(WidgetRef ref) {
    if (_selectedDate == null) return const AsyncValue.data([]);
    final start = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
    );
    final end = start.add(const Duration(days: 1));
    return ref.watch(
      availableSlotsProvider(
        SlotQueryParams(
          slug: profile.slug,
          start: start,
          end: end,
          duration: _selectedDuration,
          institutionSlug: profile.isInstitutionOwned
              ? profile.institution?.slug
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final slotsAsync = _slotsForDate(ref);
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 980;
    final timezone = DateTime.now().timeZoneName;

    return AuraScaffold(
      title: 'Pick a time',
      body: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: isWide ? AuraSpace.s32 : AuraSpace.s16,
          vertical: AuraSpace.s16,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text('Back'),
                      onPressed: () => context.pop(),
                    ),
                  ),
                  const SizedBox(height: AuraSpace.s8),
                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 360,
                          child: _MeetingSummary(
                            profile: profile,
                            duration: _selectedDuration,
                            timezone: timezone,
                            onDurationChanged: _setDuration,
                          ),
                        ),
                        const SizedBox(width: AuraSpace.s24),
                        Expanded(
                          child: _PickerSurface(
                            profile: profile,
                            focusedMonth: _focusedMonth,
                            selectedDate: _selectedDate,
                            selectedDuration: _selectedDuration,
                            slotsAsync: slotsAsync,
                            onPreviousMonth: _previousMonth,
                            onNextMonth: _nextMonth,
                            onSelectDate: _selectDate,
                          ),
                        ),
                      ],
                    )
                  else ...[
                    _MeetingSummary(
                      profile: profile,
                      duration: _selectedDuration,
                      timezone: timezone,
                      compact: true,
                      onDurationChanged: _setDuration,
                    ),
                    const SizedBox(height: AuraSpace.s16),
                    _PickerSurface(
                      profile: profile,
                      focusedMonth: _focusedMonth,
                      selectedDate: _selectedDate,
                      selectedDuration: _selectedDuration,
                      slotsAsync: slotsAsync,
                      onPreviousMonth: _previousMonth,
                      onNextMonth: _nextMonth,
                      onSelectDate: _selectDate,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _setDuration(int duration) {
    setState(() => _selectedDuration = duration);
  }

  void _previousMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
    });
  }

  void _selectDate(DateTime date) {
    setState(() => _selectedDate = date);
  }
}

class _MeetingSummary extends StatelessWidget {
  final AvailabilityProfile profile;
  final int duration;
  final String timezone;
  final bool compact;
  final ValueChanged<int> onDurationChanged;

  const _MeetingSummary({
    required this.profile,
    required this.duration,
    required this.timezone,
    required this.onDurationChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final host = profile.effectiveHost;
    final institution = profile.institution;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: const Color(0xFF243244)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AuraSpace.s18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (institution != null) ...[
              _SummaryLine(
                icon: Icons.business_rounded,
                title: institution.name,
                subtitle: (institution.description ?? '').trim().isEmpty
                    ? null
                    : institution.description!.trim(),
              ),
              const SizedBox(height: AuraSpace.s14),
            ],
            if (host != null) ...[
              _SummaryLine(
                icon: Icons.person_outline_rounded,
                title: host.name,
                subtitle: host.handle?.trim().isNotEmpty == true
                    ? '@${host.handle}'
                    : 'Meeting host',
              ),
              const SizedBox(height: AuraSpace.s14),
            ],
            Text(
              profile.meetingTitle,
              style:
                  (compact
                          ? theme.textTheme.titleLarge
                          : theme.textTheme.headlineSmall)
                      ?.copyWith(fontWeight: FontWeight.w800),
            ),
            if ((profile.meetingDescription ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: AuraSpace.s8),
              Text(
                profile.meetingDescription!.trim(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF9CA3AF),
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: AuraSpace.s16),
            _MetaRow(
              icon: Icons.schedule_rounded,
              text: _durationLabel(duration),
            ),
            _MetaRow(icon: Icons.public_rounded, text: timezone),
            if (profile.durationOptions.length > 1) ...[
              const SizedBox(height: AuraSpace.s14),
              Text(
                'Duration',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: const Color(0xFF9CA3AF),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AuraSpace.s8),
              Wrap(
                spacing: AuraSpace.s8,
                runSpacing: AuraSpace.s8,
                children: profile.durationOptions.map((option) {
                  return ChoiceChip(
                    label: Text(_durationLabel(option)),
                    selected: option == duration,
                    onSelected: (_) => onDurationChanged(option),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PickerSurface extends StatelessWidget {
  final AvailabilityProfile profile;
  final DateTime focusedMonth;
  final DateTime? selectedDate;
  final int selectedDuration;
  final AsyncValue<List<TimeSlot>> slotsAsync;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onSelectDate;

  const _PickerSurface({
    required this.profile,
    required this.focusedMonth,
    required this.selectedDate,
    required this.selectedDuration,
    required this.slotsAsync,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onSelectDate,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 980;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: const Color(0xFF243244)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AuraSpace.s18),
        child: isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 6,
                    child: _CalendarPanel(
                      focusedMonth: focusedMonth,
                      selectedDate: selectedDate,
                      onPreviousMonth: onPreviousMonth,
                      onNextMonth: onNextMonth,
                      onSelectDate: onSelectDate,
                    ),
                  ),
                  const SizedBox(width: AuraSpace.s18),
                  Expanded(
                    flex: 5,
                    child: _TimesPanel(
                      profile: profile,
                      selectedDate: selectedDate,
                      selectedDuration: selectedDuration,
                      slotsAsync: slotsAsync,
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  _CalendarPanel(
                    focusedMonth: focusedMonth,
                    selectedDate: selectedDate,
                    onPreviousMonth: onPreviousMonth,
                    onNextMonth: onNextMonth,
                    onSelectDate: onSelectDate,
                  ),
                  const SizedBox(height: AuraSpace.s18),
                  _TimesPanel(
                    profile: profile,
                    selectedDate: selectedDate,
                    selectedDuration: selectedDuration,
                    slotsAsync: slotsAsync,
                  ),
                ],
              ),
      ),
    );
  }
}

class _CalendarPanel extends StatelessWidget {
  final DateTime focusedMonth;
  final DateTime? selectedDate;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onSelectDate;

  const _CalendarPanel({
    required this.focusedMonth,
    required this.selectedDate,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onSelectDate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final firstDay = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final lastDay = DateTime(focusedMonth.year, focusedMonth.month + 1, 0);
    final startOffset = (firstDay.weekday - 1) % 7;
    final totalCells = startOffset + lastDay.day;
    final rows = (totalCells / 7).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: onPreviousMonth,
            ),
            Expanded(
              child: Center(
                child: Text(
                  _formatMonthYear(context, focusedMonth),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed: onNextMonth,
            ),
          ],
        ),
        const SizedBox(height: AuraSpace.s8),
        Row(
          children: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
              .map(
                (day) => Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: AuraSpace.s6),
        ...List.generate(rows, (row) {
          return Row(
            children: List.generate(7, (col) {
              final idx = row * 7 + col;
              final dayNum = idx - startOffset + 1;
              if (dayNum < 1 || dayNum > lastDay.day) {
                return const Expanded(child: SizedBox(height: 46));
              }

              final date = DateTime(
                focusedMonth.year,
                focusedMonth.month,
                dayNum,
              );
              final isPast = date.isBefore(
                DateTime(now.year, now.month, now.day),
              );
              final isSelected = _sameDay(selectedDate, date);
              final isToday = _sameDay(now, date);

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Semantics(
                    button: !isPast,
                    selected: isSelected,
                    label: _dayLabel(context, date),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: isPast ? null : () => onSelectDate(date),
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF6C63FF)
                              : isToday
                              ? const Color(0xFF6C63FF).withValues(alpha: 0.14)
                              : const Color(0xFF111827),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF8B85FF)
                                : const Color(0xFF1F2937),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '$dayNum',
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : isPast
                                  ? const Color(0xFF4B5563)
                                  : const Color(0xFFE5E7EB),
                              fontWeight: isSelected || isToday
                                  ? FontWeight.w800
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          );
        }),
      ],
    );
  }
}

class _TimesPanel extends StatelessWidget {
  final AvailabilityProfile profile;
  final DateTime? selectedDate;
  final int selectedDuration;
  final AsyncValue<List<TimeSlot>> slotsAsync;

  const _TimesPanel({
    required this.profile,
    required this.selectedDate,
    required this.selectedDuration,
    required this.slotsAsync,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 320),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF0B1220),
          border: Border.all(color: const Color(0xFF1F2937)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AuraSpace.s16),
          child: selectedDate == null
              ? const _EmptyTimesMessage(
                  icon: Icons.calendar_today_rounded,
                  title: 'Select a date',
                  body: 'Available times will appear here.',
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _formatFullDate(context, selectedDate!),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AuraSpace.s4),
                    Text(
                      'Times shown in ${DateTime.now().timeZoneName}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF9CA3AF),
                      ),
                    ),
                    const SizedBox(height: AuraSpace.s14),
                    slotsAsync.when(
                      loading: () => const _LoadingTimes(),
                      error: (e, _) => _EmptyTimesMessage(
                        icon: Icons.error_outline_rounded,
                        title: 'Could not load times',
                        body: '$e',
                      ),
                      data: (slots) {
                        if (slots.isEmpty) {
                          return const _EmptyTimesMessage(
                            icon: Icons.event_busy_rounded,
                            title: 'No times available',
                            body: 'Try another date or check back later.',
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: slots
                              .map(
                                (slot) => Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AuraSpace.s8,
                                  ),
                                  child: OutlinedButton(
                                    onPressed: () => context.push(
                                      '${profile.publicUrl}/book',
                                      extra: {
                                        'profile': profile,
                                        'slot': slot,
                                        'duration': selectedDuration,
                                      },
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      alignment: Alignment.centerLeft,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 14,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _formatTime(
                                              context,
                                              slot.startAt.toLocal(),
                                            ),
                                          ),
                                        ),
                                        const Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 18,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        );
                      },
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _LoadingTimes extends StatelessWidget {
  const _LoadingTimes();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AuraSpace.s24),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: AuraSpace.s12),
          Text(
            'Checking available times...',
            style: TextStyle(color: Color(0xFFD1D5DB)),
          ),
        ],
      ),
    );
  }
}

class _EmptyTimesMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _EmptyTimesMessage({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AuraSpace.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF9CA3AF), size: 28),
          const SizedBox(height: AuraSpace.s10),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AuraSpace.s4),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const _SummaryLine({required this.icon, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF8B85FF)),
        const SizedBox(width: AuraSpace.s10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF9CA3AF),
                      height: 1.3,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF9CA3AF)),
          const SizedBox(width: AuraSpace.s8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFFD1D5DB)),
            ),
          ),
        ],
      ),
    );
  }
}

bool _sameDay(DateTime? a, DateTime b) {
  return a != null && a.year == b.year && a.month == b.month && a.day == b.day;
}

String _durationLabel(int minutes) {
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final rem = minutes % 60;
  return rem == 0 ? '${hours}h' : '${hours}h ${rem}min';
}

String _formatMonthYear(BuildContext context, DateTime date) {
  return MaterialLocalizations.of(context).formatMonthYear(date);
}

String _formatFullDate(BuildContext context, DateTime date) {
  return MaterialLocalizations.of(context).formatFullDate(date);
}

String _formatTime(BuildContext context, DateTime date) {
  return TimeOfDay.fromDateTime(date).format(context);
}

String _dayLabel(BuildContext context, DateTime date) {
  return MaterialLocalizations.of(context).formatFullDate(date);
}
