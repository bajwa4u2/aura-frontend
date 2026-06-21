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
            return _EmptyState(
              onAdd: () => _showCreateSheet(context, ref),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AuraSpace.s16),
            itemCount: list.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AuraSpace.s12),
            itemBuilder: (_, i) => _ParticipationCard(
              item: list[i],
              onStatusChanged: (newStatus) async {
                await _updateStatus(context, ref, list[i].id, newStatus);
              },
            ),
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
      ParticipationStatus.paused => AuraSurface.muted,
      ParticipationStatus.inactive => AuraSurface.faint,
    };

    return Container(
      padding: const EdgeInsets.all(AuraSpace.s14),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(topicLabel, style: AuraText.body.copyWith(
                      color: AuraSurface.ink,
                      fontWeight: FontWeight.w700,
                    )),
                    const SizedBox(height: 2),
                    Text(item.mode.label, style: AuraText.small.copyWith(
                      color: AuraSurface.muted,
                    )),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AuraSpace.s8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AuraRadius.pill),
                ),
                child: Text(
                  item.status.label,
                  style: AuraText.micro.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if ((item.notes ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s8),
            Text(item.notes!, style: AuraText.small.copyWith(
              color: AuraSurface.muted,
              height: 1.5,
            )),
          ],
          const SizedBox(height: AuraSpace.s12),
          Row(
            children: [
              for (final s in ParticipationStatus.values)
                if (s != item.status)
                  Padding(
                    padding: const EdgeInsets.only(right: AuraSpace.s8),
                    child: OutlinedButton(
                      onPressed: () => onStatusChanged(s.wire),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AuraSurface.muted,
                        side: const BorderSide(color: AuraSurface.divider),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AuraSpace.s12,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: AuraText.small,
                      ),
                      child: Text('Set ${s.label}'),
                    ),
                  ),
            ],
          ),
        ],
      ),
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
              'Declare the topics your institution responds to or is accountable on. '
              'This helps public posts reach you.',
              style: AuraText.body.copyWith(color: AuraSurface.muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AuraSpace.s20),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Declare participation'),
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
      setState(() => _error = 'Select a topic.');
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
      final msg = (e.response?.data is Map)
          ? (e.response!.data as Map)['message']?.toString() ?? e.message
          : e.message;
      setState(() {
        _error = msg;
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

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AuraSpace.s16,
          AuraSpace.s16,
          AuraSpace.s16,
          AuraSpace.s16 + pad,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Declare participation', style: AuraText.title),
              const SizedBox(height: AuraSpace.s4),
              Text(
                'State the topic your institution responds to or is accountable on.',
                style: AuraText.small.copyWith(color: AuraSurface.muted),
              ),
              const SizedBox(height: AuraSpace.s20),
              const _SectionLabel('Topic'),
              const SizedBox(height: AuraSpace.s8),
              _TopicPicker(
                selected: _topic,
                onChanged: (t) => setState(() => _topic = t),
              ),
              const SizedBox(height: AuraSpace.s16),
              const _SectionLabel('Mode'),
              const SizedBox(height: AuraSpace.s8),
              ...ParticipationMode.values.map((m) => _ModeOption(
                    mode: m,
                    selected: _mode == m,
                    onTap: () => setState(() => _mode = m),
                  )),
              const SizedBox(height: AuraSpace.s16),
              const _SectionLabel('Notes (optional)'),
              const SizedBox(height: AuraSpace.s8),
              TextField(
                controller: _notesController,
                maxLines: 3,
                style: AuraText.body.copyWith(color: AuraSurface.ink),
                decoration: InputDecoration(
                  hintText: 'Any additional context for the public…',
                  hintStyle: AuraText.body.copyWith(color: AuraSurface.faint),
                  filled: true,
                  fillColor: AuraSurface.subtle,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AuraRadius.card),
                    borderSide: const BorderSide(color: AuraSurface.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AuraRadius.card),
                    borderSide: const BorderSide(color: AuraSurface.divider),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: AuraSpace.s12),
                Text(_error!, style: AuraText.small.copyWith(
                  color: Colors.redAccent,
                )),
              ],
              const SizedBox(height: AuraSpace.s20),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
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
    return Text(label, style: AuraText.small.copyWith(
      color: AuraSurface.muted,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.5,
    ));
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
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AuraSpace.s10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? AuraSurface.accent.withValues(alpha: 0.16)
                  : AuraSurface.subtle,
              borderRadius: BorderRadius.circular(AuraRadius.pill),
              border: Border.all(
                color: isSelected ? AuraSurface.accent : AuraSurface.divider,
              ),
            ),
            child: Text(
              t.label,
              style: AuraText.small.copyWith(
                color: isSelected ? AuraSurface.accent : AuraSurface.muted,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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
      child: Container(
        margin: const EdgeInsets.only(bottom: AuraSpace.s8),
        padding: const EdgeInsets.all(AuraSpace.s12),
        decoration: BoxDecoration(
          color: selected
              ? AuraSurface.accent.withValues(alpha: 0.10)
              : AuraSurface.subtle,
          borderRadius: BorderRadius.circular(AuraRadius.card),
          border: Border.all(
            color: selected ? AuraSurface.accent : AuraSurface.divider,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              size: 18,
              color: selected ? AuraSurface.accent : AuraSurface.faint,
            ),
            const SizedBox(width: AuraSpace.s10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(mode.label, style: AuraText.body.copyWith(
                    color: AuraSurface.ink,
                    fontWeight: FontWeight.w600,
                  )),
                  const SizedBox(height: 2),
                  Text(mode.description, style: AuraText.small.copyWith(
                    color: AuraSurface.muted,
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
