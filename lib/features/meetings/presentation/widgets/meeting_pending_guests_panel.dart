import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/aura_surface.dart';
import '../../application/meetings_provider.dart';

/// Phase 3.1 — host-only "Waiting to join" panel. Polls the meeting's pending
/// guests and lets the host admit or deny each. Renders nothing when no one is
/// waiting, so it is safe to always mount for the host. No realtime signal is
/// used (the guest's waiting screen polls its own admission), so this never
/// touches the frozen realtime gateway.
class MeetingPendingGuestsPanel extends ConsumerStatefulWidget {
  final String meetingId;

  const MeetingPendingGuestsPanel({super.key, required this.meetingId});

  @override
  ConsumerState<MeetingPendingGuestsPanel> createState() =>
      _MeetingPendingGuestsPanelState();
}

class _MeetingPendingGuestsPanelState
    extends ConsumerState<MeetingPendingGuestsPanel> {
  Timer? _poller;
  List<Map<String, dynamic>> _pending = const [];
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    unawaited(_poll());
    _poller = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted) return;
      unawaited(_poll());
    });
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    try {
      final list = await ref
          .read(meetingsRepositoryProvider)
          .pendingGuests(widget.meetingId);
      if (!mounted) return;
      setState(() => _pending = list);
    } catch (_) {
      // Endpoint unavailable (e.g. backend not yet deployed) — stay hidden.
    }
  }

  Future<void> _decide(String participantId, bool admit) async {
    if (_busy.contains(participantId)) return;
    setState(() => _busy.add(participantId));
    try {
      final repo = ref.read(meetingsRepositoryProvider);
      if (admit) {
        await repo.admitGuest(widget.meetingId, participantId);
      } else {
        await repo.denyGuest(widget.meetingId, participantId);
      }
      // Optimistically drop the row, then reconcile.
      if (mounted) {
        setState(() =>
            _pending = _pending.where((g) => g['id'] != participantId).toList());
      }
      await _poll();
    } catch (_) {
      // Leave the row in place so the host can retry.
    } finally {
      if (mounted) setState(() => _busy.remove(participantId));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_pending.isEmpty) return const SizedBox.shrink();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AuraSurface.subtle,
          border: Border.all(color: AuraSurface.divider),
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(color: Color(0x55000000), blurRadius: 16, offset: Offset(0, 6)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.pan_tool_alt_rounded,
                      size: 16, color: AuraSurface.warnInk),
                  const SizedBox(width: 8),
                  Text(
                    'Waiting to join (${_pending.length})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ..._pending.map(_guestRow),
            ],
          ),
        ),
      ),
    );
  }

  Widget _guestRow(Map<String, dynamic> g) {
    final id = (g['id'] ?? '').toString();
    final name = (g['guestName'] ?? 'Guest').toString();
    final email = (g['guestEmail'] ?? '').toString();
    final busy = _busy.contains(id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AuraSurface.ink,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                if (email.isNotEmpty)
                  Text(
                    email,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AuraSurface.muted,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (busy)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else ...[
            _IconAction(
              icon: Icons.close_rounded,
              color: AuraSurface.dangerInk,
              tooltip: 'Deny',
              onTap: () => _decide(id, false),
            ),
            const SizedBox(width: 6),
            _IconAction(
              icon: Icons.check_rounded,
              color: AuraSurface.goodInk,
              tooltip: 'Admit',
              onTap: () => _decide(id, true),
            ),
          ],
        ],
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _IconAction({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            border: Border.all(color: color.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}
