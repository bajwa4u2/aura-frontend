import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/server_refusal.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../topics/topic.dart';
import '../workspace/workspace_page.dart';
import 'participation_models.dart';
import 'participation_providers.dart';
import 'participation_repository.dart';
import '../../../core/product/product_language.dart';

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

/// THE TOPICS AN INSTITUTION ANSWERS FOR: a Settings page (DD-43).
///
/// One section per topic, each with what it does and the one thing to do
/// next (start, pause, resume, turn off). Taking on a new topic is the page's
/// one gold action.
class ParticipationScreen extends ConsumerWidget {
  const ParticipationScreen({super.key, required this.institutionId});

  final String institutionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(participationListProvider(institutionId));
    final list = async.valueOrNull ?? const <InstitutionParticipation>[];

    return WorkspacePage(
      type: WorkspacePageType.settings,
      title: 'Topics you answer for',
      purpose: 'Questions and issues on an active topic reach your workspace. '
          'On an accountable topic, your commitments also show on your public profile.',
      back: WorkspaceBack(label: 'Questions', path: '/institution/$institutionId/public-engagement'),
      // No icon: a compact header would otherwise show a bare "+".
      primary: WorkspaceAction(
        label: 'Take on a topic',
        onPressed: () => _showCreateSheet(context, ref, list),
      ),
      loading: async.isLoading && !async.hasValue,
      children: [
        if (async.hasError && !async.hasValue)
          WorkspaceEmpty(
            icon: Icons.error_outline_rounded,
            title: 'Your topics could not be loaded',
            body: ServerRefusal.of(async.error!).message ?? 'Check the connection and try again.',
            action: WorkspaceAction(
              label: ProductLabels.of(ProductAction.retry),
              icon: Icons.refresh_rounded,
              onPressed: () => ref.invalidate(participationListProvider(institutionId)),
            ),
          )
        else if (list.isEmpty)
          WorkspaceEmpty(
            icon: Icons.domain_outlined,
            title: 'No topics yet',
            body: 'Choose the topics your institution answers for. Public questions '
                'and issues on those topics then reach your workspace, and the '
                'people who answer for you are told.',
            action: WorkspaceAction(
              label: 'Take on a topic',
              icon: Icons.add_rounded,
              onPressed: () => _showCreateSheet(context, ref, list),
            ),
          )
        else
          for (final item in list)
            _ParticipationSection(
              item: item,
              onStatusChanged: (newStatus) => _updateStatus(context, ref, item.id, newStatus),
            ),
      ],
    );
  }

  Future<void> _showCreateSheet(
    BuildContext context,
    WidgetRef ref,
    List<InstitutionParticipation> current,
  ) async {
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
        taken: {for (final p in current) if (p.topic != null) p.topic!},
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
// ONE TOPIC
// ─────────────────────────────────────────────────────────────────────────────

class _ParticipationSection extends StatelessWidget {
  const _ParticipationSection({
    required this.item,
    required this.onStatusChanged,
  });

  final InstitutionParticipation item;
  final void Function(String status) onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final topicLabel = item.topic?.label ?? 'Unknown topic';
    final isActive = item.status == ParticipationStatus.active;
    final isPaused = item.status == ParticipationStatus.paused;
    final isInactive = item.status == ParticipationStatus.inactive;
    final tone = switch (item.status) {
      ParticipationStatus.active => WorkspaceTone.done,
      ParticipationStatus.paused => WorkspaceTone.waiting,
      ParticipationStatus.inactive => WorkspaceTone.neutral,
    };
    const offTitle = 'Stop answering on this topic?';
    final offBody = 'Questions and issues on ${topicLabel.toLowerCase()} will stop reaching your workspace. '
        'You can turn it back on at any time.';

    return WorkspaceSection(
      title: topicLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.mode.label, style: WorkspaceType.rowTitle),
                    const SizedBox(height: 2),
                    Text(item.mode.shortDescription, style: AuraText.small),
                  ],
                ),
              ),
              const SizedBox(width: AuraSpace.s12),
              WorkspacePill(label: item.status.label, tone: tone),
            ],
          ),
          const SizedBox(height: AuraSpace.s12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isActive
                    ? Icons.alt_route_rounded
                    : isPaused
                        ? Icons.pause_circle_outline_rounded
                        : Icons.remove_circle_outline_rounded,
                size: 16,
                color: AuraSurface.muted,
              ),
              const SizedBox(width: AuraSpace.s8),
              Expanded(child: Text(item.status.routingNote, style: AuraText.small)),
            ],
          ),
          if ((item.notes ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s10),
            Text(item.notes!.trim(), style: AuraText.small.copyWith(height: 1.5)),
          ],
          const SizedBox(height: AuraSpace.s14),
          const Divider(color: AuraSurface.divider, height: 1),
          const SizedBox(height: AuraSpace.s10),
          Wrap(
            spacing: AuraSpace.s8,
            runSpacing: AuraSpace.s8,
            children: [
              if (isActive)
                _ActionButton(
                  label: 'Pause',
                  icon: Icons.pause_rounded,
                  onTap: () => onStatusChanged(ParticipationStatus.paused.wire),
                ),
              if (isPaused)
                _ActionButton(
                  label: 'Resume',
                  icon: Icons.play_arrow_rounded,
                  emphasis: true,
                  onTap: () => onStatusChanged(ParticipationStatus.active.wire),
                ),
              if (isInactive)
                _ActionButton(
                  label: item.activatedAt == null ? 'Start' : 'Turn back on',
                  icon: Icons.play_arrow_rounded,
                  emphasis: true,
                  onTap: () => onStatusChanged(ParticipationStatus.active.wire),
                ),
              if (isActive || isPaused)
                _DestructiveAction(
                  label: 'Turn off',
                  onConfirm: () => onStatusChanged(ParticipationStatus.inactive.wire),
                  confirmTitle: offTitle,
                  confirmBody: offBody,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A quiet action inside a section. Never gold: the page has one gold action.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.emphasis = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  /// The next step for this topic: drawn in the accent, outlined.
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: emphasis ? AuraSurface.accentText : AuraSurface.muted,
        side: BorderSide(color: emphasis ? AuraSurface.accent : AuraSurface.divider),
        padding: const EdgeInsets.symmetric(horizontal: AuraSpace.s12, vertical: AuraSpace.s8),
        minimumSize: const Size(0, 36),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        foregroundColor: AuraSurface.dangerInk,
        padding: const EdgeInsets.symmetric(horizontal: AuraSpace.s12, vertical: AuraSpace.s8),
        minimumSize: const Size(0, 36),
        textStyle: AuraText.small.copyWith(fontWeight: FontWeight.w600),
      ),
      child: Text(label),
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
    this.taken = const {},
  });

  final String institutionId;
  final ParticipationRepository repo;

  /// Topics the institution already has: shown, not offered again (each
  /// topic is held once; a second try was refused with a 409 nobody saw).
  final Set<AuraTopic> taken;

  @override
  State<_CreateParticipationSheet> createState() =>
      _CreateParticipationSheetState();
}

class _CreateParticipationSheetState
    extends State<_CreateParticipationSheet> {
  /// Several topics at once (founder, 9 Oct 2026), all with one mode.
  final Set<AuraTopic> _topics = {};

  /// The last one tapped, whose description is shown.
  AuraTopic? _lastTapped;
  ParticipationMode _mode = ParticipationMode.accountable;
  final _notesController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  /// Start receiving questions on this topic straight away (default).
  bool _startNow = true;

  Future<void> _save() async {
    if (_topics.isEmpty) {
      setState(() => _error = 'Choose at least one topic.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final notes = _notesController.text.trim().isEmpty ? null : _notesController.text.trim();
    final failed = <String>[];
    final done = <AuraTopic>[];
    for (final topic in _topics.toList()) {
      try {
        final created = await widget.repo.create(
          institutionId: widget.institutionId,
          topic: topic.wire,
          mode: _mode.wire,
          notes: notes,
        );
        // A new topic is created switched off; taking it on switches it on
        // in the same step unless the person chose later (2026-10-09).
        if (_startNow) {
          if (created.id.isEmpty) throw StateError('no id');
          await widget.repo.updateStatus(
            institutionId: widget.institutionId,
            participationId: created.id,
            status: ParticipationStatus.active.wire,
          );
        }
        done.add(topic);
      } catch (e) {
        failed.add('${topic.label}: ${_reason(e)}');
      }
    }
    if (!mounted) return;
    if (failed.isEmpty) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _topics.removeAll(done);
      _saving = false;
      _error = done.isEmpty
          ? failed.join('\n')
          : '${done.length} taken on. Not taken on:\n${failed.join('\n')}';
    });
  }

  String _reason(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        final err = data['error'];
        final msg = (err is Map ? err['message'] : data['message'])?.toString();
        if (msg != null && msg.isNotEmpty) return msg;
      }
      return 'it could not be saved just now';
    }
    return 'it could not be switched on';
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).viewInsets.bottom;
    final topicHint = _lastTapped != null && _topics.contains(_lastTapped) ? _kTopicHints[_lastTapped] : null;

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
              const Text('Take on a topic', style: AuraText.title),
              const SizedBox(height: AuraSpace.s4),
              Text(
                'Choose a topic and how your institution answers for it. '
                'Public questions and issues on it will reach your workspace.',
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
                selected: _topics,
                taken: widget.taken,
                onToggle: (t) => setState(() {
                  if (!_topics.remove(t)) _topics.add(t);
                  _lastTapped = t;
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
                maxLines: null,
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
                        color: AuraSurface.coTeal, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: AuraSpace.s20),

              CheckboxListTile(
                value: _startNow,
                onChanged: _saving ? null : (v) => setState(() => _startNow = v ?? true),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Start answering on this topic now', style: AuraText.body),
                subtitle: Text(
                  'Questions and issues on it reach your workspace from today.',
                  style: AuraText.small.copyWith(color: AuraSurface.muted),
                ),
              ),
              const SizedBox(height: AuraSpace.s8),
              // Beside the button, where the person is looking (the banner
              // at the top was scrolled out of view, so a refusal looked
              // like nothing happening; seen live, 9 Oct 2026).
              if (_error != null) ...[
                Text(_error!, style: AuraText.small.copyWith(color: AuraSurface.coRose, height: 1.5)),
                const SizedBox(height: AuraSpace.s8),
              ],
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AuraSurface.accent,
                  foregroundColor: AuraSurface.onAccent,
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
                    : Text(_topics.length > 1
                        ? (_startNow
                            ? 'Take on ${_topics.length} topics and start answering'
                            : 'Save ${_topics.length} topics, start later')
                        : (_startNow ? 'Take it on and start answering' : 'Save, start later')),
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
  const _TopicPicker({required this.selected, required this.onToggle, this.taken = const {}});

  final Set<AuraTopic> selected;
  final Set<AuraTopic> taken;
  final void Function(AuraTopic) onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AuraSpace.s8,
      runSpacing: AuraSpace.s8,
      children: AuraTopic.values.map((t) {
        final isSelected = selected.contains(t);
        if (taken.contains(t)) {
          // Already one of the institution's topics: shown, not offered.
          return Tooltip(
            message: 'Already yours. Switch it on or off on the Topics page.',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AuraSpace.s10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AuraRadius.pill),
                border: Border.all(color: AuraSurface.divider),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_rounded, size: 14, color: AuraSurface.faint),
                  const SizedBox(width: 4),
                  Text(t.label, style: AuraText.small.copyWith(color: AuraSurface.faint)),
                ],
              ),
            ),
          );
        }
        return GestureDetector(
          onTap: () => onToggle(t),
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
