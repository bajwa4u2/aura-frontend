import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_space.dart';
import '../../../core/ui/guest_shell.dart';
import '../../../core/utils/local_timezone.dart';
import '../application/meetings_provider.dart';
import '../domain/availability_profile.dart';

class BookingRescheduleScreen extends ConsumerStatefulWidget {
  final String token;
  final AvailabilityProfile profile;

  const BookingRescheduleScreen({
    super.key,
    required this.token,
    required this.profile,
  });

  @override
  ConsumerState<BookingRescheduleScreen> createState() =>
      _BookingRescheduleScreenState();
}

class _BookingRescheduleScreenState
    extends ConsumerState<BookingRescheduleScreen> {
  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedDate;
  int _selectedDuration = 0;
  bool _rescheduling = false;
  bool _done = false;
  String? _error;

  AvailabilityProfile get profile => widget.profile;

  @override
  void initState() {
    super.initState();
    _selectedDuration = profile.defaultDuration;
  }

  AsyncValue<List<TimeSlot>> _slotsForDate() {
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

  Future<void> _reschedule(TimeSlot slot) async {
    setState(() => _rescheduling = true);
    try {
      await ref.read(availabilityRepositoryProvider).rescheduleBookingByToken(
            widget.token,
            scheduledAt: slot.startAt,
            timezone: resolveLocalTimezone(),
          );
      setState(() => _done = true);
    } catch (e) {
      setState(() => _error = 'Unable to reschedule. Try again.');
    } finally {
      if (mounted) setState(() => _rescheduling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final institution = profile.institution;
    final host = profile.effectiveHost;

    if (_done) {
      return GuestShell(
        institutionName: institution?.name ?? host?.name,
        institutionLogoUrl: institution?.logoUrl ?? host?.avatarUrl,
        body: ListView(
          padding: const EdgeInsets.all(AuraSpace.s24),
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.event_available_rounded,
                    size: 60,
                    color: Color(0xFF10B981),
                  ),
                  const SizedBox(height: AuraSpace.s16),
                  Text(
                    'Booking rescheduled',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AuraSpace.s8),
                  Text(
                    'A new confirmation has been sent to your email.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: AuraSpace.s24),
                  OutlinedButton(
                    onPressed: () => context.go('/'),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AuraSpace.s32),
          ],
        ),
      );
    }

    final slotsAsync = _slotsForDate();
    final localizations = MaterialLocalizations.of(context);

    return GuestShell(
      institutionName: institution?.name ?? host?.name,
      institutionLogoUrl: institution?.logoUrl ?? host?.avatarUrl,
      showBackButton: true,
      body: ListView(
        padding: const EdgeInsets.all(AuraSpace.s16),
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AuraSpace.s8),
                  Text(
                    'Reschedule: ${profile.meetingTitle}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AuraSpace.s16),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AuraSpace.s12),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Color(0xFFEF4444)),
                      ),
                    ),
                  // Month navigation
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded),
                        onPressed: () => setState(() {
                          _focusedMonth = DateTime(
                              _focusedMonth.year, _focusedMonth.month - 1);
                        }),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            localizations.formatMonthYear(_focusedMonth),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded),
                        onPressed: () => setState(() {
                          _focusedMonth = DateTime(
                              _focusedMonth.year, _focusedMonth.month + 1);
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: AuraSpace.s8),
                  _CalendarGrid(
                    focusedMonth: _focusedMonth,
                    selectedDate: _selectedDate,
                    onSelectDate: (d) => setState(() => _selectedDate = d),
                  ),
                  if (_selectedDate != null) ...[
                    const SizedBox(height: AuraSpace.s16),
                    Text(
                      localizations.formatFullDate(_selectedDate!),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AuraSpace.s8),
                    slotsAsync.when(
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(AuraSpace.s16),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (e, _) => const Text('Unable to load available times. Try again.',
                          style: TextStyle(color: Color(0xFFEF4444))),
                      data: (slots) {
                        if (slots.isEmpty) {
                          return const Text(
                            'No times available. Try another date.',
                            style: TextStyle(color: Color(0xFF6B7280)),
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: slots
                              .map((slot) => Padding(
                                    padding: const EdgeInsets.only(
                                        bottom: AuraSpace.s8),
                                    child: OutlinedButton(
                                      onPressed: _rescheduling
                                          ? null
                                          : () => _reschedule(slot),
                                      child: _rescheduling
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child:
                                                  CircularProgressIndicator(
                                                      strokeWidth: 2),
                                            )
                                          : Text(
                                              TimeOfDay.fromDateTime(
                                                      slot.startAt.toLocal())
                                                  .format(context),
                                            ),
                                    ),
                                  ))
                              .toList(),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AuraSpace.s32),
        ],
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  final DateTime focusedMonth;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onSelectDate;

  const _CalendarGrid({
    required this.focusedMonth,
    required this.selectedDate,
    required this.onSelectDate,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final firstDay = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final lastDay = DateTime(focusedMonth.year, focusedMonth.month + 1, 0);
    final startOffset = (firstDay.weekday - 1) % 7;
    final totalCells = startOffset + lastDay.day;
    final rows = (totalCells / 7).ceil();

    return Column(
      children: [
        Row(
          children: const ['M', 'T', 'W', 'T', 'F', 'S', 'S']
              .map((d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: const TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 4),
        ...List.generate(rows, (row) {
          return Row(
            children: List.generate(7, (col) {
              final idx = row * 7 + col;
              final dayNum = idx - startOffset + 1;
              if (dayNum < 1 || dayNum > lastDay.day) {
                return const Expanded(child: SizedBox(height: 40));
              }
              final date = DateTime(
                  focusedMonth.year, focusedMonth.month, dayNum);
              final isPast =
                  date.isBefore(DateTime(now.year, now.month, now.day));
              final isSelected = selectedDate != null &&
                  selectedDate!.year == date.year &&
                  selectedDate!.month == date.month &&
                  selectedDate!.day == date.day;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: GestureDetector(
                    onTap: isPast ? null : () => onSelectDate(date),
                    child: Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF6C63FF)
                            : const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(6),
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
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : null,
                            fontSize: 13,
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
