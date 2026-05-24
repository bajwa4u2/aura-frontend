import 'package:flutter/material.dart';

import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/substrate_chip.dart';
import '../../feed/domain/feed_item.dart';

/// Accountability timeline rail — renders the canonical
/// COMMITMENT → UPDATE(s) → RESOLVED sequence as it actually
/// unfolds inside a thread. Composes the already-loaded reply set
/// from `feedItemRepliesProvider`; this widget makes no network
/// calls and invents no events.
///
/// Replies without an accountability tag are filtered out — the
/// timeline is the *accountable* spine of the thread, not a
/// reproduction of the full reply log. When no reply carries a
/// tag, the widget collapses to `SizedBox.shrink`.
///
/// Doctrine mirror — AU-01 §5 (Accountability lifecycle).
/// `openCommitments = commitments − resolvedDistinct`. The rail
/// surfaces that calculation visibly: if a RESOLVED entry is
/// present, the COMMITMENT chip dims to record the closure rather
/// than disappear.
class AccountabilityTimelineRail extends StatelessWidget {
  const AccountabilityTimelineRail({super.key, required this.replies});

  final List<FeedReply> replies;

  @override
  Widget build(BuildContext context) {
    final events = _events(replies);
    if (events.isEmpty) return const SizedBox.shrink();
    final hasResolved = events.any((e) => e.kind == _AccountabilityKind.resolved);
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s14),
      decoration: BoxDecoration(
        color: AuraSurface.subtle,
        borderRadius: BorderRadius.circular(AuraRadius.r14),
        border: Border.all(color: AuraSurface.divider.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RailHeading(resolved: hasResolved),
          const SizedBox(height: AuraSpace.s10),
          for (var i = 0; i < events.length; i++) ...[
            _TimelineRow(
              event: events[i],
              isLast: i == events.length - 1,
              closed: hasResolved && events[i].kind == _AccountabilityKind.commitment,
            ),
          ],
        ],
      ),
    );
  }
}

class _RailHeading extends StatelessWidget {
  const _RailHeading({required this.resolved});
  final bool resolved;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 4,
          height: 14,
          decoration: BoxDecoration(
            color: AuraSurface.coTeal,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: AuraSpace.s8),
        Expanded(
          child: Text(
            'Accountability timeline',
            style: AuraText.subtitle.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        if (resolved)
          const SubstrateChip(
            label: 'closed',
            state: SubstrateChipState.verdant,
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.event,
    required this.isLast,
    required this.closed,
  });

  final _AccountabilityEvent event;
  final bool isLast;

  /// True when an upstream RESOLVED has fired and this row is a
  /// prior COMMITMENT that the resolution has closed.
  final bool closed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 14,
            child: Column(
              children: [
                const SizedBox(height: 4),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _dotColor(event.kind),
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 1,
                    height: 30,
                    margin: const EdgeInsets.only(top: 2),
                    color: AuraSurface.divider.withValues(alpha: 0.6),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AuraSpace.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SubstrateChip(
                      label: event.kind.label,
                      state: _chipState(event.kind),
                      dimmed: closed,
                    ),
                    const SizedBox(width: 8),
                    if (event.at != null)
                      Text(
                        _ago(event.at!),
                        style: AuraText.micro.copyWith(
                          color: AuraSurface.faint,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _preview(event.body),
                  style: AuraText.small.copyWith(
                    color: AuraSurface.ink,
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _dotColor(_AccountabilityKind kind) {
    switch (kind) {
      case _AccountabilityKind.commitment:
        return AuraSurface.coTeal;
      case _AccountabilityKind.update:
        return AuraSurface.coSun;
      case _AccountabilityKind.resolved:
        return AuraSurface.coVerdant;
    }
  }

  SubstrateChipState _chipState(_AccountabilityKind kind) {
    switch (kind) {
      case _AccountabilityKind.commitment:
        return SubstrateChipState.teal;
      case _AccountabilityKind.update:
        return SubstrateChipState.sun;
      case _AccountabilityKind.resolved:
        return SubstrateChipState.verdant;
    }
  }

  static String _preview(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return '(no body)';
    return trimmed;
  }

  static String _ago(DateTime at) {
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 30) return '${diff.inDays}d';
    return '${(diff.inDays / 30).floor()}mo';
  }
}

enum _AccountabilityKind {
  commitment,
  update,
  resolved;

  String get label {
    switch (this) {
      case _AccountabilityKind.commitment:
        return 'COMMITMENT';
      case _AccountabilityKind.update:
        return 'UPDATE';
      case _AccountabilityKind.resolved:
        return 'RESOLVED';
    }
  }
}

class _AccountabilityEvent {
  const _AccountabilityEvent({
    required this.kind,
    required this.body,
    required this.at,
  });

  final _AccountabilityKind kind;
  final String body;
  final DateTime? at;
}

List<_AccountabilityEvent> _events(List<FeedReply> replies) {
  final out = <_AccountabilityEvent>[];
  for (final r in replies) {
    final tag = r.accountabilityTagWire;
    if (tag == null) continue;
    final kind = _parseKind(tag);
    if (kind == null) continue;
    out.add(_AccountabilityEvent(kind: kind, body: r.body, at: r.createdAt));
  }
  out.sort((a, b) {
    final ax = a.at;
    final bx = b.at;
    if (ax == null && bx == null) return 0;
    if (ax == null) return 1;
    if (bx == null) return -1;
    return ax.compareTo(bx);
  });
  return out;
}

_AccountabilityKind? _parseKind(String wire) {
  switch (wire.trim().toUpperCase()) {
    case 'COMMITMENT':
      return _AccountabilityKind.commitment;
    case 'UPDATE':
      return _AccountabilityKind.update;
    case 'RESOLVED':
      return _AccountabilityKind.resolved;
    default:
      return null;
  }
}
