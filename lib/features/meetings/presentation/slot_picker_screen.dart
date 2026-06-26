import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
        _selectedDate!.year, _selectedDate!.month, _selectedDate!.day);
    final end = start.add(const Duration(days: 1));
    return ref.watch(availableSlotsProvider(SlotQueryParams(
      slug: profile.slug,
      start: start,
      end: end,
      duration: _selectedDuration,
    )));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final slotsAsync = _slotsForDate(ref);
    final now = DateTime.now();

    // Calendar day names
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    // Build calendar grid
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final lastDay = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
    // Pad to start of week (Monday = 0)
    final startOffset = (firstDay.weekday - 1) % 7;
    final totalCells = startOffset + lastDay.day;
    final rows = (totalCells / 7).ceil();

    return AuraScaffold(
      title: 'Pick a time',
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => context.pop(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AuraSpace.s16),
        children: [
          // Duration selector
          if (profile.durationOptions.length > 1) ...[
            Text('Duration',
                style: theme.textTheme.labelMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: AuraSpace.s8),
            Wrap(
              spacing: AuraSpace.s8,
              children: profile.durationOptions.map((d) {
                final selected = d == _selectedDuration;
                return ChoiceChip(
                  label: Text(_durationLabel(d)),
                  selected: selected,
                  onSelected: (_) => setState(() {
                    _selectedDuration = d;
                    _selectedDate = null;
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: AuraSpace.s16),
          ],

          // Month navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () => setState(() {
                  _focusedMonth = DateTime(
                      _focusedMonth.year, _focusedMonth.month - 1);
                  _selectedDate = null;
                }),
              ),
              Text(
                DateFormat('MMMM yyyy').format(_focusedMonth),
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: () => setState(() {
                  _focusedMonth = DateTime(
                      _focusedMonth.year, _focusedMonth.month + 1);
                  _selectedDate = null;
                }),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s8),

          // Day headers
          Row(
            children: dayNames
                .map((d) => Expanded(
                      child: Center(
                        child: Text(d,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF9CA3AF))),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: AuraSpace.s4),

          // Calendar grid
          ...List.generate(rows, (row) {
            return Row(
              children: List.generate(7, (col) {
                final idx = row * 7 + col;
                final dayNum = idx - startOffset + 1;
                if (dayNum < 1 || dayNum > lastDay.day) {
                  return const Expanded(child: SizedBox(height: 44));
                }

                final date = DateTime(
                    _focusedMonth.year, _focusedMonth.month, dayNum);
                final isPast = date.isBefore(
                    DateTime(now.year, now.month, now.day));
                final isSelected = _selectedDate != null &&
                    _selectedDate!.year == date.year &&
                    _selectedDate!.month == date.month &&
                    _selectedDate!.day == date.day;
                final isToday = date.year == now.year &&
                    date.month == now.month &&
                    date.day == now.day;

                return Expanded(
                  child: GestureDetector(
                    onTap: isPast
                        ? null
                        : () =>
                            setState(() => _selectedDate = date),
                    child: Container(
                      height: 44,
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF6C63FF)
                            : isToday
                                ? const Color(0xFF6C63FF).withOpacity(0.12)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '$dayNum',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected || isToday
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: isSelected
                                ? Colors.white
                                : isPast
                                    ? const Color(0xFF6B7280)
                                        .withOpacity(0.4)
                                    : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            );
          }),

          const SizedBox(height: AuraSpace.s20),

          // Time slots for selected date
          if (_selectedDate != null) ...[
            Text(
              DateFormat('EEEE, MMMM d').format(_selectedDate!),
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AuraSpace.s12),
            slotsAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator()),
              error: (e, _) => Text('Could not load slots: $e',
                  style: const TextStyle(color: Color(0xFF9CA3AF))),
              data: (slots) {
                if (slots.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: AuraSpace.s8),
                    child: Text(
                        'No availability on this day. Try another.',
                        style: TextStyle(color: Color(0xFF6B7280))),
                  );
                }
                return Wrap(
                  spacing: AuraSpace.s8,
                  runSpacing: AuraSpace.s8,
                  children: slots.map((slot) {
                    return OutlinedButton(
                      onPressed: () =>
                          context.push('/meet/${profile.slug}/book',
                              extra: {
                            'profile': profile,
                            'slot': slot,
                            'duration': _selectedDuration,
                          }),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                      child: Text(
                          DateFormat('h:mm a')
                              .format(slot.startAt.toLocal())),
                    );
                  }).toList(),
                );
              },
            ),
          ] else
            const Center(
              child: Padding(
                padding: EdgeInsets.all(AuraSpace.s16),
                child: Text('Select a day to see available times.',
                    style: TextStyle(color: Color(0xFF9CA3AF))),
              ),
            ),

          const SizedBox(height: AuraSpace.s32),
        ],
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
