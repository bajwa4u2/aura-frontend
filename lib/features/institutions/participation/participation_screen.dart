import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../topics/topic.dart';
import 'participation_models.dart';
import 'participation_providers.dart';
import 'participation_repository.dart';

// Brief description of what types of posts fall under each topic.
// Used in the create sheet to help admins choose wisely.
const _kTopicHints = <AuraTopic, String>{
  AuraTopic.government: 'Policy decisions, permits, local governance, elections.',
  AuraTopic.education: 'Schools, curricula, tuition, student welfare, institutions.',
  AuraTopic.healthcare: 'Hospitals, clinics, public health, patient services.',
  AuraTopic.faith: 'Religious organizations, worship, community faith activities.',
  AuraTopic.community: 'Neighborhood issues, civic life, volunteer programs.',
  AuraTopic.business: 'Commerce, local economy, business licensing, trade.',
  AuraTopic.technology: 'Digital services, data, platforms, tech policy.',
  AuraTopic.agriculture: 'Farming, crops, food supply, rural land use.',
  AuraTopic.transportation: 'Transit, roads, commuting, traffic, freight.',
  AuraTopic.environment: 'Climate, pollution, conservation, sustainability.',
  AuraTopic.publicSafety: 'Police, fire, emergency services, disaster response.',
  AuraTopic.artsCulture: 'Arts funding, cultural programs, heritage, events.',
  AuraTopic.sports: 'Sports facilities, leagues, public recreation.',
  AuraTopic.research: 'Scientific studies, surveys, published findings.',
  AuraTopic.infrastructure: 'Roads, utilities, construction, public facilities.',
  AuraTopic.employment: 'Jobs, wages, labor rights, workforce programs.',
  AuraTopic.housing: 'Rent, housing supply, tenants, affordable housing.',
};

class ParticipationScreen extends ConsumerWidget {
  const ParticipationScreen({super.key, required this.institutionId});

  final String institutionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(participationListProvider(institutionId));

    return AuraScaffold(
      title: 'Public Participation',
      showHomeAction: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: 'Declare participation',
          onPressed: () => _showCreateSheet(context, ref),
        ),
      ],
      body: async.when(
        loading: () =>
            const Center(child: AuraLoadingState(message: 'Loading…')),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AuraSpace.s16),
            child: AuraErrorState(
              title: 'Could not load participation',
              body: e.toString(),
            ),
          ),
        ),
        data: (list) {
          if (list.isEmpty) {
            return _EmptyState(onAdd: () => _showCreateSheet(context, ref));
          }
          return ListView(
            padding: const EdgeInsets.all(AuraSpace.s16),
            children: [
              _DoctrineNote(),
              const SizedBox(height: AuraSpace.s16),
              ...list.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: AuraSpace.s12),
                    child: _ParticipationCard(
                      item: item,
                      onStatusChanged: (newStatus) =>
                          _updateStatus(context, ref, item.id, newStatus),
                    ),
                  )),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showCreateSheet(BuildContext context, WidgetRef ref) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AuraSurface.page,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AuraRadius.lg),
        ),
      ),
      builder: (_) => _CreateParticipationSheet(
        institutionId: institutionId,
        repo: ref.read(participationRepositoryProvider),
      ),
    );
    if (created == true) {
      ref.invalidate(participationListProvider(institutionId));
    }
  }

  Future<void> _updateStatus(
    BuildContext context,
    WidgetRef ref,
    String participationId,
    String status,
  ) async {
    try {
      await ref.read(participationRepositoryProvider).updateStatus(
            institutionId: institutionId,
            participationId: participationId,
            status: status,
          );
      ref.invalidate(participationListProvider(institutionId));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update status: $e')),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DOCTRINE NOTE
// ─────────────────────────────────────────────────────────────────────────────

class _DoctrineNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s12),
      decoration: BoxDecoration(
        color: AuraSurface.accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(
          color: AuraSurface.accent.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 15,
            color: AuraSurface.accent,
          ),
          const SizedBox(width: AuraSpace.s8),
          Expanded(
            child: Text(
              'Active declarations route matching public posts to your '
              'engagement workspace. Accountable declarations track '
              'commitments on your public profile.',
              style: AuraText.small.copyWith(
                color: AuraSurface.muted,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD
// ─────────────────────────────────────────────────────────────────────────────

class _ParticipationCard extends StatelessWidget {
  const _ParticipationCard({
    required this.item,
    required this.onStatusChanged,
  });

  final InstitutionParticipation item;
  final void Function(String status) onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final topicLabel = item.topic?.label ?? 'Unknown topic';

    final statusColor = switch (item.status) {
      ParticipationStatus.active => const Color(0xFF1B8A4C),
      ParticipationStatus.paused => const Color(0xFFE8853A),
      ParticipationStatus.inactive => AuraSurface.faint,
    };

    final isActive = item.status == ParticipationStatus.active;
    final isPaused = item.status == ParticipationStatus.paused;
    final isInactive = item.status == ParticipationStatus.inactive;

    return Container(
      padding: const EdgeInsets.all(AuraSpace.s14),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(
          color: isActive
              ? const Color(0xFF1B8A4C).withValues(alpha: 0.25)
              : AuraSurface.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Topic + status badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topicLabel,
                      style: AuraText.body.copyWith(
                        color: AuraSurface.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.mode.label,
                      style: AuraText.small.copyWith(
                        color: AuraSurface.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.mode.shortDescription,
                      style: AuraText.micro.copyWith(
                        color: AuraSurface.muted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AuraSpace.s10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AuraSpace.s8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AuraRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      item.status.label,
                      style: AuraText.micro.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Routing note
          const SizedBox(height: AuraSpace.s10),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AuraSpace.s10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFF1B8A4C).withValues(alpha: 0.07)
                  : AuraSurface.subtle,
              borderRadius: BorderRadius.circular(AuraRadius.md),
            ),
            child: Row(
              children: [
                Icon(
                  isActive
                      ? Icons.alt_route_rounded
                      : isPaused
                          ? Icons.pause_circle_outline_rounded
                          : Icons.remove_circle_outline_rounded,
                  size: 13,
                  color: isActive
                      ? const Color(0xFF1B8A4C)
                      : AuraSurface.faint,
                ),
                const SizedBox(width: AuraSpace.s6),
                Expanded(
                  child: Text(
                    item.status.routingNote,
                    style: AuraText.micro.copyWith(
                      color: isActive
                          ? const Color(0xFF1B8A4C)
                          : AuraSurface.muted,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Admin notes
          if ((item.notes ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s10),
            Text(
              item.notes!.trim(),
              style: AuraText.small.copyWith(
                color: AuraSurface.muted,
                height: 1.5,
              ),
            ),
          ],

          // Status actions
          const SizedBox(height: AuraSpace.s12),
          const Divider(color: AuraSurface.divider, height: 1),
          const SizedBox(height: AuraSpace.s12),
          Row(
            children: [
              if (isActive) ...[
                _ActionButton(
                  label: 'Pause',
                  icon: Icons.pause_rounded,
                  onTap: () => onStatusChanged(ParticipationStatus.paused.wire),
                ),
                const SizedBox(width: AuraSpace.s8),
                _DestructiveAction(
                  label: 'Deactivate',
                  onConfirm: () =>
                      onStatusChanged(ParticipationStatus.inactive.wire),
                  confirmTitle: 'Deactivate participation?',
                  confirmBody:
                      'Posts on ${topicLabel.toLowerCase()} will no longer route to your workspace. '
                      'You can reactivate at any time.',
                ),
              ] else if (isPaused) ...[
                _PrimaryAction(
                  label: 'Reactivate',
                  icon: Icons.play_arrow_rounded,
                  onTap: () => onStatusChanged(ParticipationStatus.active.wire),
                ),
                const SizedBox(width: AuraSpace.s8),
                _DestructiveAction(
                  label: 'Deactivate',
                  onConfirm: () =>
                      onStatusChanged(ParticipationStatus.inactive.wire),
                  confirmTitle: 'Deactivate participation?',
                  confirmBody:
                      'Posts on ${topicLabel.toLowerCase()} will no longer route to your workspace. '
                      'You can reactivate at any time.',
                ),
              ] else if (isInactive) ...[
                _PrimaryAction(
                  label: 'Reactivate',
                  icon: Icons.play_arrow_rounded,
                  onTap: () => onStatusChanged(ParticipationStatus.active.wire),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AuraSurface.muted,
        side: const BorderSide(color: AuraSurface.divider),
        padding:
            const EdgeInsets.symmetric(horizontal: AuraSpace.s12, vertical: 7),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: AuraText.small.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: AuraSurface.accent,
        foregroundColor: Colors.white,
        padding:
            const EdgeInsets.symmetric(horizontal: AuraSpace.s12, vertical: 7),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: AuraText.small.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _DestructiveAction extends StatelessWidget {
  const _DestructiveAction({
    required this.label,
    required this.onConfirm,
    required this.confirmTitle,
    required this.confirmBody,
  });

  final String label;
  final VoidCallback onConfirm;
  final String confirmTitle;
  final String confirmBody;

  Future<void> _handleTap(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AuraSurface.subtle,
        title: Text(confirmTitle, style: AuraText.headline),
        content: Text(
          confirmBody,
          style: AuraText.body.copyWith(color: AuraSurface.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              label,
              style: const TextStyle(color: AuraSurface.coRose),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) onConfirm();
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => _handleTap(context),
      style: TextButton.styleFrom(
        foregroundColor: AuraSurface.coRose,
        padding:
            const EdgeInsets.symmetric(horizontal: AuraSpace.s10, vertical: 7),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: AuraText.small.copyWith(fontWeight: FontWeight.w600),
      ),
      child: Text(label),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AuraSpace.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AuraSurface.accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.domain_outlined,
                size: 24,
                color: AuraSurface.accent,
              ),
            ),
            const SizedBox(height: AuraSpace.s16),
            const Text('No participation declarations', style: AuraText.title),
            const SizedBox(height: AuraSpace.s8),
            Text(
              'Declare the topics your institution responds to or is accountable '
              'on. Active declarations route matching public posts to your '
              'engagement workspace.',
              style: AuraText.body.copyWith(color: AuraSurface.muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AuraSpace.s20),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Declare participation'),
              style: FilledButton.styleFrom(
                backgroundColor: AuraSurface.accent,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CREATE SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _CreateParticipationSheet extends StatefulWidget {
  const _CreateParticipationSheet({
    required this.institutionId,
    required this.repo,
  });

  final String institutionId;
  final ParticipationRepository repo;

  @override
  State<_CreateParticipationSheet> createState() =>
      _CreateParticipationSheetState();
}

class _CreateParticipationSheetState
    extends State<_CreateParticipationSheet> {
  AuraTopic? _topic;
  ParticipationMode _mode = ParticipationMode.accountable;
  final _notesController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_topic == null) {
      setState(() => _error = 'Select a topic to continue.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repo.create(
        institutionId: widget.institutionId,
        topic: _topic!.wire,
        mode: _mode.wire,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      final data = e.response?.data;
      String? msg;
      if (data is Map) {
        final err = data['error'];
        msg = (err is Map ? err['message'] : data['message'])?.toString();
      }
      setState(() {
        _error = msg ?? e.message ?? 'Could not save declaration.';
        _saving = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).viewInsets.bottom;
    final topicHint = _topic != null ? _kTopicHints[_topic] : null;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AuraSpace.s16,
          AuraSpace.s12,
          AuraSpace.s16,
          AuraSpace.s16 + pad,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AuraSurface.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AuraSpace.s16),
              const Text('Declare participation', style: AuraText.title),
              const SizedBox(height: AuraSpace.s4),
              Text(
                'Choose a topic and how your institution participates. '
                'Active declarations route matching public posts to your workspace.',
                style: AuraText.small.copyWith(
                  color: AuraSurface.muted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: AuraSpace.s20),

              // Error banner
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(AuraSpace.s12),
                  decoration: BoxDecoration(
                    color: AuraSurface.coRose.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AuraRadius.md),
                    border: Border.all(
                      color: AuraSurface.coRose.withValues(alpha: 0.30),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          size: 15, color: AuraSurface.coRose),
                      const SizedBox(width: AuraSpace.s8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: AuraText.small
                              .copyWith(color: AuraSurface.coRose),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AuraSpace.s14),
              ],

              const _SectionLabel('TOPIC'),
              const SizedBox(height: AuraSpace.s8),
              _TopicPicker(
                selected: _topic,
                onChanged: (t) => setState(() {
                  _topic = t;
                  _error = null;
                }),
              ),
              // Topic description hint
              if (topicHint != null) ...[
                const SizedBox(height: AuraSpace.s8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AuraSpace.s10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AuraSurface.accent.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(AuraRadius.md),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.label_outline_rounded,
                          size: 13, color: AuraSurface.accent),
                      const SizedBox(width: AuraSpace.s6),
                      Expanded(
                        child: Text(
                          topicHint,
                          style: AuraText.micro.copyWith(
                            color: AuraSurface.muted,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AuraSpace.s20),

              const _SectionLabel('MODE'),
              const SizedBox(height: AuraSpace.s8),
              ...ParticipationMode.values.map(
                (m) => _ModeOption(
                  mode: m,
                  selected: _mode == m,
                  onTap: () => setState(() => _mode = m),
                ),
              ),
              const SizedBox(height: AuraSpace.s16),

              const _SectionLabel('NOTES (OPTIONAL)'),
              const SizedBox(height: AuraSpace.s8),
              TextField(
                controller: _notesController,
                maxLines: 3,
                style: AuraText.body.copyWith(color: AuraSurface.ink),
                decoration: InputDecoration(
                  hintText: 'Any additional context for the public…',
                  hintStyle:
                      AuraText.body.copyWith(color: AuraSurface.faint),
                  filled: true,
                  fillColor: AuraSurface.subtle,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AuraRadius.card),
                    borderSide:
                        const BorderSide(color: AuraSurface.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AuraRadius.card),
                    borderSide:
                        const BorderSide(color: AuraSurface.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AuraRadius.card),
                    borderSide: const BorderSide(
                        color: Color(0xFF0D9488), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: AuraSpace.s20),

              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AuraSurface.accent,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(vertical: AuraSpace.s12),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save declaration'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AuraText.micro.copyWith(
        color: AuraSurface.faint,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
      ),
    );
  }
}

class _TopicPicker extends StatelessWidget {
  const _TopicPicker({required this.selected, required this.onChanged});

  final AuraTopic? selected;
  final void Function(AuraTopic?) onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AuraSpace.s8,
      runSpacing: AuraSpace.s8,
      children: AuraTopic.values.map((t) {
        final isSelected = selected == t;
        return GestureDetector(
          onTap: () => onChanged(isSelected ? null : t),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            padding: const EdgeInsets.symmetric(
              horizontal: AuraSpace.s10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? AuraSurface.accent.withValues(alpha: 0.14)
                  : AuraSurface.subtle,
              borderRadius: BorderRadius.circular(AuraRadius.pill),
              border: Border.all(
                color: isSelected
                    ? AuraSurface.accent.withValues(alpha: 0.5)
                    : AuraSurface.divider,
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Text(
              t.label,
              style: AuraText.small.copyWith(
                color: isSelected ? AuraSurface.accent : AuraSurface.muted,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final ParticipationMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        margin: const EdgeInsets.only(bottom: AuraSpace.s8),
        padding: const EdgeInsets.all(AuraSpace.s12),
        decoration: BoxDecoration(
          color: selected
              ? AuraSurface.accent.withValues(alpha: 0.08)
              : AuraSurface.subtle,
          borderRadius: BorderRadius.circular(AuraRadius.card),
          border: Border.all(
            color: selected
                ? AuraSurface.accent.withValues(alpha: 0.4)
                : AuraSurface.divider,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                size: 18,
                color: selected ? AuraSurface.accent : AuraSurface.faint,
              ),
            ),
            const SizedBox(width: AuraSpace.s10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode.label,
                    style: AuraText.body.copyWith(
                      color: AuraSurface.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    mode.description,
                    style: AuraText.small.copyWith(
                      color: AuraSurface.muted,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
