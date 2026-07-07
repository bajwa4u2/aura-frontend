import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config.dart';
import '../../../core/auth/session_providers.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/utils/local_timezone.dart';
import '../application/meetings_provider.dart';
import '../domain/availability_profile.dart';

class AvailabilitySetupScreen extends ConsumerWidget {
  const AvailabilitySetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(myAvailabilityProfilesProvider);

    return AuraScaffold(
      title: 'Booking pages',
      actions: [
        IconButton(
          icon: const Icon(Icons.add_rounded),
          tooltip: 'Create booking page',
          onPressed: () => _showCreateDialog(context, ref),
        ),
      ],
      body: profilesAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(child: Text('Unable to load booking pages.')),
        data: (profiles) {
          if (profiles.isEmpty) {
            return _EmptyState(
              onCreateTap: () => _showCreateDialog(context, ref),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AuraSpace.s16),
            itemCount: profiles.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AuraSpace.s8),
            itemBuilder: (_, i) => _ProfileCard(profile: profiles[i]),
          );
        },
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (_) => _CreateProfileDialog(ref: ref),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreateTap;
  const _EmptyState({required this.onCreateTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AuraSpace.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today_rounded,
                size: 56, color: Color(0xFF9CA3AF)),
            const SizedBox(height: AuraSpace.s16),
            Text('No booking pages yet',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AuraSpace.s8),
            const Text(
              'Create a booking page so guests can schedule time with you.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: AuraSpace.s20),
            FilledButton.icon(
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create booking page'),
              onPressed: onCreateTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends ConsumerWidget {
  final AvailabilityProfile profile;
  const _ProfileCard({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final baseHost = AppConfig.publicWebUrl.replaceFirst(RegExp(r'^https?://'), '');
    final publicUrl = '$baseHost${profile.publicUrl}';

    return Container(
      padding: const EdgeInsets.all(AuraSpace.s16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF374151).withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(profile.name,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (profile.isActive
                          ? const Color(0xFF10B981)
                          : const Color(0xFFF59E0B))
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(profile.isActive ? 'Active' : 'Paused',
                    style: TextStyle(
                        color: profile.isActive
                            ? const Color(0xFF10B981)
                            : const Color(0xFFF59E0B),
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s4),
          Text(profile.meetingTitle,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF6B7280))),

          // Governance context: this profile is operated by the viewer but
          // governed by the institution admin who created it.
          if (_isAssignedNotOwner(ref)) ...[
            const SizedBox(height: AuraSpace.s6),
            Row(
              children: [
                const Icon(Icons.verified_user_outlined,
                    size: 13, color: Color(0xFF8B85FF)),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Assigned to you · governed by ${profile.owner?.name ?? 'your institution'}',
                    style: const TextStyle(
                        color: Color(0xFF8B85FF),
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: AuraSpace.s10),

          // Window summary
          if (profile.windows.isNotEmpty) ...[
            Wrap(
              spacing: AuraSpace.s6,
              runSpacing: AuraSpace.s4,
              children: profile.windows
                  .take(5)
                  .map((w) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF374151),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${_dayLabel(w.dayOfWeek)} ${w.label}',
                          style: const TextStyle(
                              color: Color(0xFFD1D5DB),
                              fontSize: 11),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: AuraSpace.s10),
          ],

          // Public link
          Row(
            children: [
              Expanded(
                child: Text(publicUrl,
                    style: const TextStyle(
                        color: Color(0xFF9CA3AF), fontSize: 12)),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 16),
                color: const Color(0xFF9CA3AF),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                    minWidth: 32, minHeight: 32),
                onPressed: () {
                  Clipboard.setData(
                      ClipboardData(text: 'https://$publicUrl'));
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Link copied to clipboard')));
                },
              ),
            ],
          ),

          const SizedBox(height: AuraSpace.s10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.settings_rounded, size: 16),
                  label: const Text('Edit settings'),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => _EditProfileDialog(profile: profile, ref: ref),
                  ),
                ),
              ),
              const SizedBox(width: AuraSpace.s8),
              // Pause/resume — operational, so owner AND assigned host.
              OutlinedButton.icon(
                icon: Icon(
                  profile.isActive
                      ? Icons.pause_circle_outline_rounded
                      : Icons.play_circle_outline_rounded,
                  size: 16,
                ),
                label: Text(profile.isActive ? 'Pause' : 'Resume'),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await ref
                        .read(availabilityRepositoryProvider)
                        .updateProfile(profile.id,
                            isActive: !profile.isActive);
                    ref.invalidate(myAvailabilityProfilesProvider);
                  } catch (_) {
                    messenger.showSnackBar(const SnackBar(
                        content:
                            Text('Could not update availability state.')));
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s10),
          _WindowManagerSection(profile: profile),
        ],
      ),
    );
  }

  bool _isAssignedNotOwner(WidgetRef ref) {
    final ownerId = profile.owner?.id ?? '';
    if (ownerId.isEmpty) return false;
    final myId = ref.watch(authMeDataProvider).maybeWhen(
          data: (me) {
            final u = me['user'];
            return (u is Map ? (u['id'] ?? '') : (me['id'] ?? ''))
                .toString()
                .trim();
          },
          orElse: () => '',
        );
    return myId.isNotEmpty && myId != ownerId;
  }

  String _dayLabel(String day) {
    return switch (day) {
      'MON' => 'Mon',
      'TUE' => 'Tue',
      'WED' => 'Wed',
      'THU' => 'Thu',
      'FRI' => 'Fri',
      'SAT' => 'Sat',
      'SUN' => 'Sun',
      _ => day.length >= 3 ? day.substring(0, 3) : day,
    };
  }
}

class _WindowManagerSection extends ConsumerWidget {
  final AvailabilityProfile profile;
  const _WindowManagerSection({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text('Manage availability windows',
          style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
      children: [
        ...profile.windows.map((w) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                  '${_dayFull(w.dayOfWeek)}: ${w.label}',
                  style: const TextStyle(fontSize: 13)),
              trailing: IconButton(
                icon: const Icon(Icons.remove_circle_outline_rounded,
                    size: 18, color: Color(0xFF9CA3AF)),
                onPressed: () async {
                  try {
                    await ref
                        .read(availabilityRepositoryProvider)
                        .removeWindow(profile.id, w.id);
                    ref.invalidate(myAvailabilityProfilesProvider);
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Something went wrong. Try again.')));
                  }
                },
              ),
            )),
        ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: const Icon(Icons.add_rounded,
              size: 18, color: Color(0xFF6C63FF)),
          title: const Text('Add window',
              style: TextStyle(
                  fontSize: 13, color: Color(0xFF6C63FF))),
          onTap: () => _showAddWindow(context, ref),
        ),
      ],
    );
  }

  void _showAddWindow(BuildContext context, WidgetRef ref) {
    String? selectedDay = 'MON';
    final startCtrl = TextEditingController(text: '09:00');
    final endCtrl = TextEditingController(text: '17:00');

    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add availability window'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: selectedDay,
              decoration: const InputDecoration(
                  labelText: 'Day', border: OutlineInputBorder()),
              items: const {
                'MON': 'Monday',
                'TUE': 'Tuesday',
                'WED': 'Wednesday',
                'THU': 'Thursday',
                'FRI': 'Friday',
                'SAT': 'Saturday',
                'SUN': 'Sunday',
              }.entries
                  .map((e) =>
                      DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => selectedDay = v,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: startCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Start (HH:mm)',
                        border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: endCtrl,
                    decoration: const InputDecoration(
                        labelText: 'End (HH:mm)',
                        border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (selectedDay == null) return;
              Navigator.pop(context);
              try {
                await ref
                    .read(availabilityRepositoryProvider)
                    .addWindow(profile.id,
                        dayOfWeek: selectedDay!,
                        startTime: startCtrl.text.trim(),
                        endTime: endCtrl.text.trim());
                ref.invalidate(myAvailabilityProfilesProvider);
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Something went wrong. Try again.')));
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  String _dayFull(String day) => switch (day) {
        'MON' => 'Monday',
        'TUE' => 'Tuesday',
        'WED' => 'Wednesday',
        'THU' => 'Thursday',
        'FRI' => 'Friday',
        'SAT' => 'Saturday',
        'SUN' => 'Sunday',
        _ => day,
      };
}

class _CreateProfileDialog extends ConsumerStatefulWidget {
  final WidgetRef ref;
  const _CreateProfileDialog({required this.ref});

  @override
  ConsumerState<_CreateProfileDialog> createState() =>
      _CreateProfileDialogState();
}

class _CreateProfileDialogState
    extends ConsumerState<_CreateProfileDialog> {
  final _nameCtrl = TextEditingController();
  final _slugCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _slugCtrl.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create booking page'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                  labelText: 'Page name',
                  hintText: 'e.g. 30-min intro call',
                  border: OutlineInputBorder()),
              onChanged: (v) {
                if (_slugCtrl.text.isEmpty ||
                    _slugCtrl.text ==
                        _toSlug(_nameCtrl.text)) {
                  _slugCtrl.text = _toSlug(v);
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                  labelText: 'Meeting title',
                  hintText: 'Shown to guests on the booking page',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _slugCtrl,
              decoration: const InputDecoration(
                  labelText: 'URL slug',
                  hintText: 'auraplatform.org/meet/your-slug',
                  prefixText: '/meet/',
                  border: OutlineInputBorder()),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _create,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Create'),
        ),
      ],
    );
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    final slug = _slugCtrl.text.trim();
    final title = _titleCtrl.text.trim();
    if (name.isEmpty || slug.isEmpty || title.isEmpty) return;

    setState(() => _saving = true);
    try {
      await ref.read(availabilityRepositoryProvider).createProfile(
            name: name,
            slug: slug,
            meetingTitle: title,
            durationOptions: const [30, 60],
            defaultDuration: 30,
            timezone: resolveLocalTimezone(),
          );
      ref.invalidate(myAvailabilityProfilesProvider);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Something went wrong. Try again.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _toSlug(String v) =>
      v.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
}

// H9: Edit profile settings dialog
class _EditProfileDialog extends ConsumerStatefulWidget {
  final AvailabilityProfile profile;
  final WidgetRef ref;
  const _EditProfileDialog({required this.profile, required this.ref});

  @override
  ConsumerState<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends ConsumerState<_EditProfileDialog> {
  late final TextEditingController _bufferBeforeCtrl;
  late final TextEditingController _bufferAfterCtrl;
  late final TextEditingController _minNoticeCtrl;
  late final TextEditingController _maxPerDayCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _bufferBeforeCtrl = TextEditingController(
        text: widget.profile.bufferBefore.toString());
    _bufferAfterCtrl = TextEditingController(
        text: widget.profile.bufferAfter.toString());
    _minNoticeCtrl = TextEditingController(
        text: widget.profile.minimumNotice.toString());
    _maxPerDayCtrl = TextEditingController(
        text: widget.profile.maxBookingsPerDay?.toString() ?? '');
  }

  @override
  void dispose() {
    _bufferBeforeCtrl.dispose();
    _bufferAfterCtrl.dispose();
    _minNoticeCtrl.dispose();
    _maxPerDayCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit booking settings'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _IntField(
              controller: _bufferBeforeCtrl,
              label: 'Buffer before (min)',
              hint: 'Minutes blocked before each booking',
            ),
            const SizedBox(height: 12),
            _IntField(
              controller: _bufferAfterCtrl,
              label: 'Buffer after (min)',
              hint: 'Minutes blocked after each booking',
            ),
            const SizedBox(height: 12),
            _IntField(
              controller: _minNoticeCtrl,
              label: 'Minimum notice (min)',
              hint: 'Earliest a booking can be made',
            ),
            const SizedBox(height: 12),
            _IntField(
              controller: _maxPerDayCtrl,
              label: 'Max bookings per day (optional)',
              hint: 'Leave blank for no limit',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final maxPerDay = _maxPerDayCtrl.text.trim().isEmpty
          ? null
          : int.tryParse(_maxPerDayCtrl.text.trim());
      await widget.ref.read(availabilityRepositoryProvider).updateProfile(
            widget.profile.id,
            bufferBefore: int.tryParse(_bufferBeforeCtrl.text.trim()),
            bufferAfter: int.tryParse(_bufferAfterCtrl.text.trim()),
            minimumNotice: int.tryParse(_minNoticeCtrl.text.trim()),
            maxBookingsPerDay: maxPerDay,
          );
      widget.ref.invalidate(myAvailabilityProfilesProvider);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Something went wrong. Try again.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _IntField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;

  const _IntField({
    required this.controller,
    required this.label,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
