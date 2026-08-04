import 'package:flutter/material.dart';

import '../../core/ui/aura_radius.dart';
import '../../core/ui/aura_space.dart';
import '../../core/ui/aura_surface.dart';
import '../../core/ui/aura_text.dart';
import 'topic.dart';
import 'topic_repository.dart';

enum _FetchStatus { idle, loading, loaded, error }

/// Reusable topic-selection component for content composers.
///
/// Doctrine — Human Authority + Machine Assistance
/// (TOPIC_CLASSIFICATION_DOCTRINE.md):
///   * Primary Topic is **required** and **human-selected** (single choice).
///     Aura never sets or overrides it.
///   * Secondary Topics are optional and constrained to the backend's
///     approved-relationship set for the selected Primary — both for manual
///     "Add topic" selection and for Aura's ranked suggestions. The backend
///     is the sole authority for that relationship graph; this widget holds
///     no local copy of it and applies no local fallback if a request fails.
///
/// Controlled widget: the parent owns `primary`/`secondaries` state and is
/// notified via the `onPrimaryChanged` / `onSecondariesChanged` callbacks.
/// Designed so any content type (institution post, user post, announcement)
/// can reuse it.
class AuraTopicSelector extends StatefulWidget {
  const AuraTopicSelector({
    super.key,
    required this.primary,
    required this.secondaries,
    required this.contentText,
    required this.onPrimaryChanged,
    required this.onSecondariesChanged,
    required this.fetchApprovedSecondaries,
    required this.fetchSuggestions,
  });

  final AuraTopic? primary;
  final List<AuraTopic> secondaries;

  /// Title + body the suggestion capability analyzes for Secondary Topic
  /// suggestions.
  final String contentText;

  final ValueChanged<AuraTopic?> onPrimaryChanged;
  final ValueChanged<List<AuraTopic>> onSecondariesChanged;

  /// `GET /topics/:primary/secondaries` — the plain, deterministic approved
  /// set for the selected primary. Drives both manual "Add topic" selection
  /// and the primary-change auto-drop. Throws on failure; the widget shows a
  /// recoverable retry state rather than any local fallback list.
  final Future<List<ApprovedSecondaryTopic>> Function(AuraTopic primary)
  fetchApprovedSecondaries;

  /// `POST /topics/suggest-secondary` — ranked suggestions from the backend
  /// (approved-relationship gate → AI semantic relevance → deterministic
  /// keyword fallback, all server-side). Throws on failure; the widget shows
  /// a recoverable retry state rather than any local fallback.
  final Future<TopicSuggestionResult> Function(AuraTopic primary, String text)
  fetchSuggestions;

  @override
  State<AuraTopicSelector> createState() => _AuraTopicSelectorState();
}

class _AuraTopicSelectorState extends State<AuraTopicSelector> {
  List<AuraTopic> _approved = const <AuraTopic>[];
  _FetchStatus _approvedStatus = _FetchStatus.idle;
  bool _suggestBusy = false;

  @override
  void initState() {
    super.initState();
    _maybeFetchApproved(isPrimaryChange: false);
  }

  @override
  void didUpdateWidget(covariant AuraTopicSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.primary != widget.primary) {
      _maybeFetchApproved(isPrimaryChange: true);
    }
  }

  void _maybeFetchApproved({required bool isPrimaryChange}) {
    final primary = widget.primary;
    if (primary == null) {
      setState(() {
        _approved = const <AuraTopic>[];
        _approvedStatus = _FetchStatus.idle;
      });
      return;
    }

    setState(() => _approvedStatus = _FetchStatus.loading);

    widget
        .fetchApprovedSecondaries(primary)
        .then((list) {
          if (!mounted || widget.primary != primary) return;
          final approvedTopics = list.map((a) => a.topic).toSet();
          setState(() {
            _approved = approvedTopics.toList();
            _approvedStatus = _FetchStatus.loaded;
          });

          // Primary Changes (TOPIC_CLASSIFICATION_DOCTRINE.md): only
          // auto-drop when the user actually switched the primary, not on
          // the initial load of an existing (possibly legacy) combination —
          // "existing content remains valid," it's only re-checked going
          // forward from an explicit primary change.
          if (!isPrimaryChange) return;
          final kept = widget.secondaries
              .where(approvedTopics.contains)
              .toList();
          final droppedCount = widget.secondaries.length - kept.length;
          if (droppedCount == 0) return;

          widget.onSecondariesChanged(kept);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                droppedCount == 1
                    ? 'Removed 1 secondary topic that no longer relates to the new primary topic.'
                    : 'Removed $droppedCount secondary topics that no longer relate to the new primary topic.',
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        })
        .catchError((_) {
          if (!mounted || widget.primary != primary) return;
          setState(() => _approvedStatus = _FetchStatus.error);
        });
  }

  void _onPrimaryTap(AuraTopic tapped) {
    widget.onPrimaryChanged(widget.primary == tapped ? null : tapped);
  }

  void _addSecondary(AuraTopic t) {
    final primary = widget.primary;
    if (primary == null) return;
    if (_approvedStatus != _FetchStatus.loaded) return;
    if (t == primary || widget.secondaries.contains(t)) return;
    if (!_approved.contains(t)) return;
    widget.onSecondariesChanged([...widget.secondaries, t]);
  }

  void _removeSecondary(AuraTopic t) {
    widget.onSecondariesChanged(
      widget.secondaries.where((x) => x != t).toList(),
    );
  }

  Future<void> _runSuggest() async {
    final primary = widget.primary;
    if (primary == null || _suggestBusy) return;
    setState(() => _suggestBusy = true);
    try {
      final result = await widget.fetchSuggestions(
        primary,
        widget.contentText,
      );
      if (!mounted) return;
      final merged = <AuraTopic>[...widget.secondaries];
      for (final t in result.suggestions) {
        if (t != primary && !merged.contains(t)) merged.add(t);
      }
      widget.onSecondariesChanged(merged);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not get topic suggestions. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _suggestBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = widget.primary;
    final secondaries = widget.secondaries;
    final addable = _approvedStatus == _FetchStatus.loaded
        ? _approved.where((t) => !secondaries.contains(t)).toList()
        : const <AuraTopic>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Primary (required) ──────────────────────────────────────────
        Row(
          children: [
            Text('Primary topic', style: AuraText.small.copyWith(
              fontWeight: FontWeight.w700,
            )),
            const SizedBox(width: AuraSpace.s6),
            Text('· required', style: AuraText.micro.copyWith(
              color: primary == null ? AuraSurface.coRose : AuraSurface.faint,
              fontWeight: FontWeight.w700,
            )),
          ],
        ),
        const SizedBox(height: AuraSpace.s8),
        Wrap(
          spacing: AuraSpace.s6,
          runSpacing: AuraSpace.s6,
          children: [
            for (final t in AuraTopic.values)
              _TopicChip(
                label: t.label,
                selected: primary == t,
                onTap: () => _onPrimaryTap(t),
              ),
          ],
        ),

        const SizedBox(height: AuraSpace.s16),

        // ── Secondary (optional, suggested) ─────────────────────────────
        Row(
          children: [
            Text('Secondary topics', style: AuraText.small.copyWith(
              fontWeight: FontWeight.w700,
            )),
            const SizedBox(width: AuraSpace.s6),
            Text('· optional', style: AuraText.micro.copyWith(
              color: AuraSurface.faint,
              fontWeight: FontWeight.w700,
            )),
            const Spacer(),
            TextButton.icon(
              onPressed:
                  (primary == null ||
                      widget.contentText.trim().isEmpty ||
                      _suggestBusy)
                  ? null
                  : _runSuggest,
              icon: _suggestBusy
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_outlined, size: 16),
              label: const Text('Suggest'),
              style: TextButton.styleFrom(
                foregroundColor: AuraSurface.accentText,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        _HelperRow(
          primary: primary,
          status: _approvedStatus,
          onRetry: () => _maybeFetchApproved(isPrimaryChange: false),
        ),
        const SizedBox(height: AuraSpace.s8),
        if (secondaries.isNotEmpty)
          Wrap(
            spacing: AuraSpace.s6,
            runSpacing: AuraSpace.s6,
            children: [
              for (final t in secondaries)
                _TopicChip(
                  label: t.label,
                  selected: true,
                  trailing: Icons.close_rounded,
                  onTap: () => _removeSecondary(t),
                ),
            ],
          ),
        if (addable.isNotEmpty) ...[
          const SizedBox(height: AuraSpace.s8),
          PopupMenuButton<AuraTopic>(
            onSelected: _addSecondary,
            itemBuilder: (_) => [
              for (final t in addable)
                PopupMenuItem<AuraTopic>(value: t, child: Text(t.label)),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AuraSpace.s10,
                vertical: AuraSpace.s6,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AuraRadius.pill),
                border: Border.all(color: AuraSurface.divider),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded, size: 16,
                      color: AuraSurface.muted),
                  const SizedBox(width: 4),
                  Text('Add topic', style: AuraText.small.copyWith(
                    color: AuraSurface.muted,
                  )),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Status/helper line under the Secondary Topics header — explains why the
/// "Add topic" control is unavailable (no primary yet, loading, or a failed
/// fetch with a retry action) rather than silently showing nothing.
class _HelperRow extends StatelessWidget {
  const _HelperRow({
    required this.primary,
    required this.status,
    required this.onRetry,
  });

  final AuraTopic? primary;
  final _FetchStatus status;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (primary == null) {
      return Text(
        'Choose a primary topic first.',
        style: AuraText.micro.copyWith(color: AuraSurface.muted),
      );
    }
    if (status == _FetchStatus.error) {
      return Row(
        children: [
          Expanded(
            child: Text(
              'Couldn\'t load related topics.',
              style: AuraText.micro.copyWith(color: AuraSurface.coRose),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Retry'),
          ),
        ],
      );
    }
    if (status == _FetchStatus.loading) {
      return Text(
        'Loading related topics…',
        style: AuraText.micro.copyWith(color: AuraSurface.muted),
      );
    }
    return Text(
      'Aura suggests topics related to your primary topic. You decide — add, remove, or keep.',
      style: AuraText.micro.copyWith(color: AuraSurface.muted),
    );
  }
}

class _TopicChip extends StatelessWidget {
  const _TopicChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AuraRadius.pill),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s10,
          vertical: AuraSpace.s6,
        ),
        decoration: BoxDecoration(
          color: selected ? AuraSurface.accentSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(AuraRadius.pill),
          border: Border.all(
            color: selected ? AuraSurface.accent : AuraSurface.divider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AuraText.small.copyWith(
                color: selected ? AuraSurface.accentText : AuraSurface.ink,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 4),
              Icon(trailing, size: 14, color: AuraSurface.accentText),
            ],
          ],
        ),
      ),
    );
  }
}
