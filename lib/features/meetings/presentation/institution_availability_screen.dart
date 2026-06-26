import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../application/meetings_provider.dart';
import '../domain/availability_profile.dart';

Future<void> _refreshInstitutionProfiles(WidgetRef ref, String institutionId) {
  return ref.refresh(institutionProfilesProvider(institutionId).future);
}

Future<void> _afterPopupClosed(
  BuildContext context,
  Future<void> Function() action,
) async {
  await Future<void>.delayed(const Duration(milliseconds: 180));
  if (!context.mounted) return;
  await action();
}

// Institution/workspace admin screen for creating and managing
// booking profiles. Accessible at /institution/:id/availability.
// Gated by institution ADMIN role on the backend.
class InstitutionAvailabilityScreen extends ConsumerWidget {
  final String institutionId;
  const InstitutionAvailabilityScreen({super.key, required this.institutionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(institutionProfilesProvider(institutionId));

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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load: $e')),
        data: (profiles) {
          if (profiles.isEmpty) {
            return _EmptyState(
              onCreateTap: () => _showCreateDialog(context, ref),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AuraSpace.s16),
            itemCount: profiles.length + 1,
            separatorBuilder: (_, i) => i == 0
                ? const SizedBox(height: AuraSpace.s16)
                : const SizedBox(height: AuraSpace.s8),
            itemBuilder: (_, i) {
              if (i == 0) {
                return OutlinedButton.icon(
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('New booking page'),
                  onPressed: () => _showCreateDialog(context, ref),
                );
              }
              return _ProfileCard(
                profile: profiles[i - 1],
                institutionId: institutionId,
              );
            },
          );
        },
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (_) =>
          _CreateProfileDialog(institutionId: institutionId, ref: ref),
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
            const Icon(
              Icons.calendar_today_rounded,
              size: 56,
              color: Color(0xFF9CA3AF),
            ),
            const SizedBox(height: AuraSpace.s16),
            Text(
              'No booking pages',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AuraSpace.s8),
            const Text(
              'Create a booking page so visitors can schedule meetings '
              'with your workspace without using Calendly.',
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
  final String institutionId;
  const _ProfileCard({required this.profile, required this.institutionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final baseHost = AppConfig.publicWebUrl.replaceFirst(
      RegExp(r'^https?://'),
      '',
    );
    final publicUrl = '$baseHost${profile.publicUrl}';
    final host = profile.effectiveHost;

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
          // Header row
          Row(
            children: [
              Expanded(
                child: Text(
                  profile.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _StatusBadge(isActive: profile.isActive),
              const SizedBox(width: AuraSpace.s8),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz_rounded, size: 20),
                onSelected: (v) async {
                  if (v == 'copy') {
                    Clipboard.setData(
                      ClipboardData(text: 'https://$publicUrl'),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Link copied')),
                    );
                  } else if (v == 'toggle') {
                    try {
                      await ref
                          .read(availabilityRepositoryProvider)
                          .updateInstitutionProfile(
                            institutionId,
                            profile.id,
                            isActive: !profile.isActive,
                          );
                      await _refreshInstitutionProfiles(ref, institutionId);
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  } else if (v == 'edit') {
                    await _afterPopupClosed(
                      context,
                      () => _showEditDialog(context, ref),
                    );
                  } else if (v == 'delete') {
                    await _afterPopupClosed(
                      context,
                      () => _confirmDelete(context, ref),
                    );
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'copy',
                    child: Text('Copy booking link'),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit profile'),
                  ),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(profile.isActive ? 'Disable' : 'Enable'),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Delete',
                      style: TextStyle(color: Color(0xFFEF4444)),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: AuraSpace.s4),
          Text(
            profile.meetingTitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFF6B7280),
            ),
          ),

          // Assigned host
          if (host != null) ...[
            const SizedBox(height: AuraSpace.s8),
            Row(
              children: [
                const Icon(
                  Icons.person_outline_rounded,
                  size: 14,
                  color: Color(0xFF9CA3AF),
                ),
                const SizedBox(width: 4),
                Text(
                  'Host: ${host.name}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ],

          // Duration chips
          const SizedBox(height: AuraSpace.s8),
          Wrap(
            spacing: AuraSpace.s6,
            children: profile.durationOptions
                .map(
                  (d) => Chip(
                    label: Text(
                      _durationLabel(d),
                      style: const TextStyle(fontSize: 11),
                    ),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                )
                .toList(),
          ),

          // Availability windows
          if (profile.windows.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s8),
            Wrap(
              spacing: AuraSpace.s6,
              runSpacing: 4,
              children: profile.windows
                  .map(
                    (w) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF374151),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${_dayAbbr(w.dayOfWeek)} ${w.label}',
                        style: const TextStyle(
                          color: Color(0xFFD1D5DB),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],

          const SizedBox(height: AuraSpace.s10),

          // Public link
          Row(
            children: [
              Expanded(
                child: Text(
                  publicUrl,
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 12,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 16),
                color: const Color(0xFF9CA3AF),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: 'https://$publicUrl'));
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Link copied')));
                },
              ),
            ],
          ),

          // Window management
          _WindowManager(profile: profile, institutionId: institutionId),
        ],
      ),
    );
  }

  Future<void> _showEditDialog(BuildContext context, WidgetRef ref) async {
    final titleCtrl = TextEditingController(text: profile.meetingTitle);
    final descCtrl = TextEditingController(
      text: profile.meetingDescription ?? '',
    );
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Edit booking page'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Meeting title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await ref
                      .read(availabilityRepositoryProvider)
                      .updateInstitutionProfile(
                        institutionId,
                        profile.id,
                        meetingTitle: titleCtrl.text.trim(),
                        meetingDescription: descCtrl.text.trim().isEmpty
                            ? null
                            : descCtrl.text.trim(),
                      );
                  await _refreshInstitutionProfiles(ref, institutionId);
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                } catch (e) {
                  if (!dialogContext.mounted) return;
                  ScaffoldMessenger.of(
                    dialogContext,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      );
    } finally {
      titleCtrl.dispose();
      descCtrl.dispose();
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete booking page'),
        content: Text('Delete "${profile.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(availabilityRepositoryProvider)
          .deleteInstitutionProfile(institutionId, profile.id);
      await _refreshInstitutionProfiles(ref, institutionId);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  String _durationLabel(int m) {
    if (m < 60) return '$m min';
    final h = m ~/ 60;
    final rem = m % 60;
    return rem == 0 ? '${h}h' : '${h}h ${rem}min';
  }

  String _dayAbbr(String day) => switch (day) {
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

class _StatusBadge extends StatelessWidget {
  final bool isActive;
  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (isActive ? const Color(0xFF10B981) : const Color(0xFF9CA3AF))
            .withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isActive ? 'Active' : 'Disabled',
        style: TextStyle(
          color: isActive ? const Color(0xFF10B981) : const Color(0xFF9CA3AF),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _WindowManager extends ConsumerStatefulWidget {
  final AvailabilityProfile profile;
  final String institutionId;
  const _WindowManager({required this.profile, required this.institutionId});

  @override
  ConsumerState<_WindowManager> createState() => _WindowManagerState();
}

class _WindowManagerState extends ConsumerState<_WindowManager> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final institutionId = widget.institutionId;

    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AuraSpace.s8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Manage availability windows',
                    style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                  ),
                ),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: const Color(0xFF9CA3AF),
                ),
              ],
            ),
          ),
        ),
        if (_expanded) ...[
          const Divider(height: 1, color: Color(0xFF1F2937)),
          ...profile.windows.map(
            (w) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                '${_dayFull(w.dayOfWeek)}: ${w.label}',
                style: const TextStyle(fontSize: 13),
              ),
              trailing: IconButton(
                icon: const Icon(
                  Icons.remove_circle_outline_rounded,
                  size: 18,
                  color: Color(0xFF9CA3AF),
                ),
                onPressed: () async {
                  try {
                    await ref
                        .read(availabilityRepositoryProvider)
                        .removeInstitutionWindow(
                          institutionId,
                          profile.id,
                          w.id,
                        );
                    await _refreshInstitutionProfiles(ref, institutionId);
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
              ),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: const Icon(
              Icons.add_rounded,
              size: 18,
              color: Color(0xFF6C63FF),
            ),
            title: const Text(
              'Add window',
              style: TextStyle(fontSize: 13, color: Color(0xFF6C63FF)),
            ),
            onTap: () => _showAddWindow(context),
          ),
        ],
      ],
    );
  }

  Future<void> _showAddWindow(BuildContext context) async {
    final input = await showDialog<_WindowInput>(
      context: context,
      builder: (_) => const _AddWindowDialog(),
    );
    if (input == null) return;

    try {
      await ref
          .read(availabilityRepositoryProvider)
          .addInstitutionWindow(
            widget.institutionId,
            widget.profile.id,
            dayOfWeek: input.day,
            startTime: input.startTime,
            endTime: input.endTime,
          );
      await _refreshInstitutionProfiles(ref, widget.institutionId);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
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

class _WindowInput {
  final String day;
  final String startTime;
  final String endTime;

  const _WindowInput({
    required this.day,
    required this.startTime,
    required this.endTime,
  });
}

class _AddWindowDialog extends StatefulWidget {
  const _AddWindowDialog();

  @override
  State<_AddWindowDialog> createState() => _AddWindowDialogState();
}

class _AddWindowDialogState extends State<_AddWindowDialog> {
  static const _days = <String, String>{
    'MON': 'Mon',
    'TUE': 'Tue',
    'WED': 'Wed',
    'THU': 'Thu',
    'FRI': 'Fri',
    'SAT': 'Sat',
    'SUN': 'Sun',
  };

  String _selectedDay = 'MON';
  final _startCtrl = TextEditingController(text: '09:00');
  final _endCtrl = TextEditingController(text: '17:00');

  @override
  void dispose() {
    _startCtrl.dispose();
    _endCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add availability window'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Day',
              style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _days.entries
                  .map(
                    (entry) => ChoiceChip(
                      label: Text(entry.value),
                      selected: _selectedDay == entry.key,
                      onSelected: (_) {
                        setState(() => _selectedDay = entry.key);
                      },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _startCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Start (HH:mm)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _endCtrl,
                    decoration: const InputDecoration(
                      labelText: 'End (HH:mm)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(
              context,
              _WindowInput(
                day: _selectedDay,
                startTime: _startCtrl.text.trim(),
                endTime: _endCtrl.text.trim(),
              ),
            );
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class _CreateProfileDialog extends ConsumerStatefulWidget {
  final String institutionId;
  final WidgetRef ref;
  const _CreateProfileDialog({required this.institutionId, required this.ref});

  @override
  ConsumerState<_CreateProfileDialog> createState() =>
      _CreateProfileDialogState();
}

class _CreateProfileDialogState extends ConsumerState<_CreateProfileDialog> {
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
                hintText: 'e.g. 30-min discovery call',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) {
                if (_slugCtrl.text.isEmpty ||
                    _slugCtrl.text == _toSlug(_nameCtrl.text)) {
                  _slugCtrl.text = _toSlug(v);
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Meeting title',
                hintText: 'Shown on the booking page to visitors',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _slugCtrl,
              decoration: const InputDecoration(
                labelText: 'URL slug',
                hintText: 'your-workspace/meet/this-slug',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _create,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
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
      await ref
          .read(availabilityRepositoryProvider)
          .createInstitutionProfile(
            widget.institutionId,
            name: name,
            slug: slug,
            meetingTitle: title,
            durationOptions: const [30, 60],
            defaultDuration: 30,
            timezone: DateTime.now().timeZoneName,
          );
      await _refreshInstitutionProfiles(ref, widget.institutionId);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _toSlug(String v) =>
      v.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
}
