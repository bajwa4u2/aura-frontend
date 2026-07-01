import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config.dart';
import '../../institutions/ui/institution_ds.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import 'package:go_router/go_router.dart';
import '../../institutions/data/institutions_repository.dart';
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
        error: (e, _) => const Center(child: Text('Unable to load availability settings.')),
        data: (profiles) {
          return ListView(
            padding: const EdgeInsets.all(AuraSpace.s16),
            children: [
              const _Header(),
              const SizedBox(height: AuraSpace.s20),
              if (profiles.isEmpty)
                _EmptyState(onCreateTap: () => _showCreateDialog(context, ref))
              else ...[
                OutlinedButton.icon(
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('New booking page'),
                  onPressed: () => _showCreateDialog(context, ref),
                ),
                const SizedBox(height: AuraSpace.s16),
                ...profiles.map(
                  (profile) => Padding(
                    padding: const EdgeInsets.only(bottom: AuraSpace.s8),
                    child: _ProfileCard(
                      profile: profile,
                      institutionId: institutionId,
                    ),
                  ),
                ),
              ],
            ],
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

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return const InsModeHeader(
      title: 'Booking pages',
      description:
          'Manage the booking pages, public links, and availability windows used by the institution workspace.',
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
              'Create a booking page so visitors can schedule meetings with your workspace.',
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

    return InsCard(
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
                      ).showSnackBar(const SnackBar(content: Text('Something went wrong. Try again.')));
                    }
                  } else if (v == 'bookings') {
                    await _afterPopupClosed(
                      context,
                      () => showDialog<void>(
                        context: context,
                        builder: (_) => _BookingInboxDialog(
                          profile: profile,
                          institutionId: institutionId,
                        ),
                      ),
                    );
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
                    value: 'bookings',
                    child: Text('View bookings'),
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
    await showDialog<void>(
      context: context,
      builder: (_) => _EditProfileDialog(
        profile: profile,
        institutionId: institutionId,
      ),
    );
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
      ).showSnackBar(const SnackBar(content: Text('Something went wrong. Try again.')));
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
                    ).showSnackBar(const SnackBar(content: Text('Something went wrong. Try again.')));
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
      ).showSnackBar(const SnackBar(content: Text('Something went wrong. Try again.')));
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
  List<Map<String, dynamic>> _members = [];
  String? _selectedHostId;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      final data = await ref
          .read(institutionsRepositoryProvider)
          .listMembers(widget.institutionId);
      final raw = data['members'];
      if (raw is List && mounted) {
        setState(() {
          _members = raw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        });
      }
    } catch (_) {}
  }

  String _memberName(Map<String, dynamic> m) {
    final user = m['user'];
    final displayName = user is Map ? (user['displayName'] as String?) : null;
    final handle = user is Map ? (user['handle'] as String?) : null;
    if (displayName?.isNotEmpty == true) return displayName!;
    if (handle?.isNotEmpty == true) return handle!;
    return 'Unknown';
  }

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
            // J2: Assigned host selection using real institution members.
            if (_members.isNotEmpty) ...[
              const SizedBox(height: 12),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Assigned host (optional)',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                ),
                child: DropdownButton<String?>(
                  value: _selectedHostId,
                  isExpanded: true,
                  underline: const SizedBox(),
                  isDense: true,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Creator (default)'),
                    ),
                    ..._members.map(
                      (m) => DropdownMenuItem<String?>(
                        value: (m['userId'] ?? m['user']?['id'] ?? m['id']) as String?,
                        child: Text(_memberName(m)),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _selectedHostId = v),
                ),
              ),
            ],
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
            assignedHostId: _selectedHostId,
          );
      await _refreshInstitutionProfiles(ref, widget.institutionId);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Something went wrong. Try again.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _toSlug(String v) =>
      v.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
}

// ── J2 + J3: Edit profile dialog (host assignment + operational settings) ─────

class _EditProfileDialog extends ConsumerStatefulWidget {
  final AvailabilityProfile profile;
  final String institutionId;
  const _EditProfileDialog(
      {required this.profile, required this.institutionId});

  @override
  ConsumerState<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends ConsumerState<_EditProfileDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _bufferBeforeCtrl;
  late final TextEditingController _bufferAfterCtrl;
  late final TextEditingController _minNoticeCtrl;
  late final TextEditingController _maxBookingsCtrl;
  late bool _requireApproval;
  List<Map<String, dynamic>> _members = [];
  String? _selectedHostId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _titleCtrl = TextEditingController(text: p.meetingTitle);
    _descCtrl = TextEditingController(text: p.meetingDescription ?? '');
    _bufferBeforeCtrl =
        TextEditingController(text: p.bufferBefore.toString());
    _bufferAfterCtrl =
        TextEditingController(text: p.bufferAfter.toString());
    _minNoticeCtrl =
        TextEditingController(text: p.minimumNotice.toString());
    _maxBookingsCtrl =
        TextEditingController(text: p.maxBookingsPerDay?.toString() ?? '');
    _requireApproval = p.requireApproval;
    _selectedHostId = p.assignedHost?.id;
    _loadMembers();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _bufferBeforeCtrl.dispose();
    _bufferAfterCtrl.dispose();
    _minNoticeCtrl.dispose();
    _maxBookingsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    try {
      final data = await ref
          .read(institutionsRepositoryProvider)
          .listMembers(widget.institutionId);
      final raw = data['members'];
      if (raw is List && mounted) {
        setState(() {
          _members = raw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        });
      }
    } catch (_) {}
  }

  String _memberName(Map<String, dynamic> m) {
    final user = m['user'];
    final displayName = user is Map ? (user['displayName'] as String?) : null;
    final handle = user is Map ? (user['handle'] as String?) : null;
    if (displayName?.isNotEmpty == true) return displayName!;
    if (handle?.isNotEmpty == true) return handle!;
    return 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit booking page'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Meeting title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
            // J2: Host assignment from real institution member list.
            if (_members.isNotEmpty) ...[
              const SizedBox(height: 12),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Assigned host',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                ),
                child: DropdownButton<String?>(
                  value: _selectedHostId,
                  isExpanded: true,
                  underline: const SizedBox(),
                  isDense: true,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Creator (default)'),
                    ),
                    ..._members.map(
                      (m) => DropdownMenuItem<String?>(
                        value: (m['userId'] ?? m['user']?['id'] ?? m['id']) as String?,
                        child: Text(_memberName(m)),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _selectedHostId = v),
                ),
              ),
            ],
            // J3: Booking behavior settings.
            const SizedBox(height: 20),
            const Text(
              'Booking behavior',
              style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _bufferBeforeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Buffer before (min)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _bufferAfterCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Buffer after (min)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minNoticeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Min notice (min)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _maxBookingsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Max per day',
                      hintText: 'Unlimited',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _requireApproval,
              title: const Text(
                'Guests need approval to join',
                style: TextStyle(fontSize: 14),
              ),
              onChanged: (v) => setState(() => _requireApproval = v),
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
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final prevHostId = widget.profile.assignedHost?.id;
      final hostChanged = _selectedHostId != prevHostId;
      final desc = _descCtrl.text.trim();
      await ref
          .read(availabilityRepositoryProvider)
          .updateInstitutionProfile(
            widget.institutionId,
            widget.profile.id,
            meetingTitle: _titleCtrl.text.trim(),
            meetingDescription: desc.isEmpty ? null : desc,
            assignedHostId:
                (hostChanged && _selectedHostId != null) ? _selectedHostId : null,
            clearAssignedHost: hostChanged && _selectedHostId == null,
            bufferBefore: int.tryParse(_bufferBeforeCtrl.text.trim()),
            bufferAfter: int.tryParse(_bufferAfterCtrl.text.trim()),
            minimumNotice: int.tryParse(_minNoticeCtrl.text.trim()),
            maxBookingsPerDay:
                int.tryParse(_maxBookingsCtrl.text.trim()),
            requireApproval: _requireApproval,
          );
      await _refreshInstitutionProfiles(ref, widget.institutionId);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ── J1: Booking inbox dialog ──────────────────────────────────────────────────

class _BookingInboxDialog extends ConsumerWidget {
  final AvailabilityProfile profile;
  final String institutionId;
  const _BookingInboxDialog(
      {required this.profile, required this.institutionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key =
        InstitutionProfileBookingsKey(institutionId, profile.id);
    final async = ref.watch(institutionProfileBookingsProvider(key));

    return AlertDialog(
      title: Text('Bookings — ${profile.name}'),
      contentPadding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 480),
          child: async.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(24),
              child: const Text('Unable to load bookings.'),
            ),
            data: (bookings) {
              if (bookings.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 40, color: Color(0xFF9CA3AF)),
                      SizedBox(height: 12),
                      Text(
                        'No upcoming bookings',
                        style: TextStyle(color: Color(0xFF9CA3AF)),
                      ),
                    ],
                  ),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: bookings.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: Color(0xFF1F2937)),
                itemBuilder: (ctx, i) => _BookingRow(
                  booking: bookings[i],
                  institutionId: institutionId,
                  onNavigate: () => Navigator.pop(context),
                ),
              );
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _BookingRow extends StatelessWidget {
  final Map<String, dynamic> booking;
  final String institutionId;
  final VoidCallback onNavigate;
  const _BookingRow({
    required this.booking,
    required this.institutionId,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final bookerName = booking['bookerName'] as String? ?? '';
    final bookerEmail = booking['bookerEmail'] as String? ?? '';
    final scheduledAt = booking['scheduledAt'] as String? ?? '';
    final durationMinutes =
        (booking['durationMinutes'] as num?)?.toInt() ?? 30;
    final status = booking['status'] as String? ?? 'CONFIRMED';
    final notes = booking['bookerNotes'] as String?;
    final meetingId = booking['meetingId'] as String?;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  bookerName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              _StatusChip(status: status),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            bookerEmail,
            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.schedule_rounded,
                  size: 13, color: Color(0xFF6B7280)),
              const SizedBox(width: 4),
              Text(
                _formatTime(scheduledAt),
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF6B7280)),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.timelapse_rounded,
                  size: 13, color: Color(0xFF6B7280)),
              const SizedBox(width: 4),
              Text(
                '$durationMinutes min',
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ],
          ),
          if (notes != null && notes.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Note: $notes',
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF9CA3AF)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (meetingId != null) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () {
                onNavigate();
                context.go(
                    '/institution/$institutionId/meetings/$meetingId');
              },
              child: const Text(
                'View meeting',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6C63FF),
                  decoration: TextDecoration.underline,
                  decorationColor: Color(0xFF6C63FF),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final local = dt.toLocal();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '${months[local.month - 1]} ${local.day}, ${local.year} · $h:$m';
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final isConfirmed = status == 'CONFIRMED';
    final color =
        isConfirmed ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isConfirmed ? 'Confirmed' : 'Pending',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
