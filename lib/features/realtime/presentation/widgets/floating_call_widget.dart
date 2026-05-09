import 'dart:async';
import 'dart:ui' as ui show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/call_presence_bridge.dart';
import '../../../../core/ui/aura_platform_components.dart';
import '../../../../core/ui/aura_radius.dart';
import '../../../../core/ui/aura_space.dart';
import '../../../../core/ui/aura_surface.dart';
import '../../../../core/ui/aura_text.dart';
import '../../application/realtime_providers.dart';
import '../../domain/realtime_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DIMENSIONS
// ─────────────────────────────────────────────────────────────────────────────

const double _kWidth = 276.0;
const double _kEstimatedHeight = 88.0;

// ─────────────────────────────────────────────────────────────────────────────
// RESOLVED CALL INFO
// ─────────────────────────────────────────────────────────────────────────────

class _CallInfo {
  const _CallInfo({
    required this.sessionId,
    required this.isVideo,
    required this.micOn,
    required this.cameraOn,
    required this.startedAt,
    required this.participants,
    required this.isOwner,
    this.localRenderer,
  });

  final String sessionId;
  final bool isVideo;
  final bool micOn;
  final bool cameraOn;
  final DateTime? startedAt;
  final List<RealtimeParticipant> participants;
  final RTCVideoRenderer? localRenderer;

  /// True when this tab owns and is joined to the call.
  /// False when the call is active in another tab (passive view only).
  final bool isOwner;
}

// ─────────────────────────────────────────────────────────────────────────────
// FLOATING CALL WIDGET
// ─────────────────────────────────────────────────────────────────────────────

/// Minimised call status strip.
///
/// Shown when the user navigates away from the full call screen (/realtime/:id).
/// When this tab owns the call: shows Return and End/Leave controls.
/// When the call is in another tab: shows a passive "Call active in another tab"
/// indicator with no interactive controls — passive tabs must not end calls.
///
/// Returns a [Positioned] widget so the render box is exactly card-sized.
/// This prevents a full-screen hitbox from blocking underlying UI.
class FloatingCallWidget extends ConsumerStatefulWidget {
  const FloatingCallWidget({super.key});

  @override
  ConsumerState<FloatingCallWidget> createState() => _FloatingCallWidgetState();
}

class _FloatingCallWidgetState extends ConsumerState<FloatingCallWidget> {
  Offset? _offset;
  bool _positionInitialized = false;
  Timer? _ticker;
  bool _isEnding = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_positionInitialized) _initPosition();
  }

  void _initPosition() {
    final size = MediaQuery.sizeOf(context);
    if (size.isEmpty) return;
    _positionInitialized = true;
    _offset = Offset(
      size.width - _kWidth - 20,
      size.height - _kEstimatedHeight - 84,
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  // ── Drag ────────────────────────────────────────────────────────────────────

  void _onPanUpdate(DragUpdateDetails d) {
    if (_offset == null) return;
    final size = MediaQuery.sizeOf(context);
    setState(() {
      final raw = _offset! + d.delta;
      _offset = Offset(
        raw.dx.clamp(0.0, (size.width - _kWidth).clamp(0.0, double.infinity)),
        raw.dy
            .clamp(0.0, (size.height - _kEstimatedHeight).clamp(0.0, double.infinity)),
      );
    });
  }

  // ── Resolve active call info ─────────────────────────────────────────────

  _CallInfo? _resolve() {
    final local = ref.read(realtimeControllerProvider);
    final sessionId = local.sessionId;
    if (local.isJoined && sessionId != null && sessionId.isNotEmpty) {
      // A3: Active in this tab — only render when the loaded session is
      // confirmed active. `session?.isActive == false` (terminal) AND
      // `session == null` (still hydrating / cleared / stale ref) both
      // suppress the card, so we never show a dead session card during
      // the post-end race window.
      final session = local.session;
      if (session == null || !session.isActive) {
        return null;
      }
      return _CallInfo(
        sessionId: sessionId,
        isVideo: local.isVideoMode,
        micOn: local.microphoneEnabled,
        cameraOn: local.cameraEnabled,
        startedAt: session.startedAt,
        participants: local.participants.where((p) => p.isPresent).toList(),
        isOwner: true,
        localRenderer: local.localRenderer,
      );
    }

    // Fallback: a call is active in *another* tab. Show a passive PiP so
    // the user can see at a glance that they're still in a call (e.g.
    // after navigating to another tab/window). Owner controls are
    // suppressed because this tab does not own the media session.
    final presence = ref.read(callPresenceBridgeProvider);
    if (presence == null) return null;
    if (presence.sessionId.isEmpty) return null;
    return _CallInfo(
      sessionId: presence.sessionId,
      isVideo: presence.isVideo,
      micOn: presence.micOn,
      cameraOn: presence.cameraOn,
      startedAt: presence.startedAt,
      participants: const [],
      isOwner: false,
      localRenderer: null,
    );
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  void _returnToCall(_CallInfo info) {
    if (info.isOwner) {
      // A2: only navigate to /realtime/:sessionId when the controller still
      // holds an active session for this id. If the host ended (or the
      // server tore down) the session between the PiP rendering and the tap
      // landing, clear the stale local reference instead of routing to a
      // dead screen.
      final local = ref.read(realtimeControllerProvider);
      final session = local.session;
      final stillActive = local.isJoined &&
          session != null &&
          session.isActive &&
          (local.sessionId ?? '') == info.sessionId;
      if (!stillActive) {
        ref.read(realtimeControllerProvider.notifier).clearLocalSession();
        return;
      }
    }
    context.go('/realtime/${info.sessionId}');
  }

  // A1: End the call from PiP using the same authoritative controller path.
  // Local guard prevents double-tap; controller has its own _endingCall guard
  // so a stray double-fire is harmless.
  Future<void> _endCallFromPip() async {
    if (_isEnding) return;
    setState(() => _isEnding = true);
    try {
      await ref.read(realtimeControllerProvider.notifier).endCall();
    } catch (_) {
      // endCall is local-first; backend errors are swallowed by the controller.
    } finally {
      if (mounted) setState(() => _isEnding = false);
    }
  }

  // ── Duration ────────────────────────────────────────────────────────────────

  String _formatDuration(DateTime? startedAt) {
    if (startedAt == null) return '--:--';
    final diff = DateTime.now().difference(startedAt);
    final h = diff.inHours;
    final m = diff.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = diff.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ref.watch(realtimeControllerProvider);
    // Re-render when cross-tab presence changes so passive PiP appears /
    // disappears within one heartbeat without polling.
    ref.watch(callPresenceBridgeProvider);

    final path = GoRouterState.of(context).uri.path;

    // Do not overlay the full call screen itself.
    if (path.startsWith('/realtime')) return const SizedBox.shrink();

    final info = _resolve();
    if (info == null) return const SizedBox.shrink();

    if (_offset == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_positionInitialized) _initPosition();
      });
      return const SizedBox.shrink();
    }

    return Positioned(
      left: _offset!.dx,
      top: _offset!.dy,
      width: _kWidth,
      child: GestureDetector(
        onPanUpdate: _onPanUpdate,
        child: MouseRegion(
          cursor: SystemMouseCursors.move,
          child: _FloatingCard(
            isVideo: info.isVideo,
            micOn: info.micOn,
            cameraOn: info.cameraOn,
            participants: info.participants,
            duration: _formatDuration(info.startedAt),
            isOwner: info.isOwner,
            onReturn: info.isOwner ? () => _returnToCall(info) : null,
            // A1: passive (cross-tab) PiPs cannot end the call; only the
            // owner tab has the media session and authoritative state.
            onEnd: info.isOwner ? _endCallFromPip : null,
            isEnding: _isEnding,
            localRenderer: info.localRenderer,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD CONTENT
// ─────────────────────────────────────────────────────────────────────────────

class _FloatingCard extends StatelessWidget {
  const _FloatingCard({
    required this.isVideo,
    required this.micOn,
    required this.cameraOn,
    required this.participants,
    required this.duration,
    required this.isOwner,
    required this.onReturn,
    required this.onEnd,
    required this.isEnding,
    this.localRenderer,
  });

  final bool isVideo;
  final bool micOn;
  final bool cameraOn;
  final List<RealtimeParticipant> participants;
  final String duration;
  final bool isOwner;
  final VoidCallback? onReturn;
  final VoidCallback? onEnd;
  final bool isEnding;
  final RTCVideoRenderer? localRenderer;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _kWidth,
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.s12, AuraSpace.s10, AuraSpace.s10, AuraSpace.s10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1E33),
        borderRadius: BorderRadius.circular(AuraRadius.xl),
        border: Border.all(color: AuraSurface.divider),
        boxShadow: const [
          BoxShadow(
            color: Color(0x99000000),
            blurRadius: 28,
            offset: Offset(0, 10),
          ),
          BoxShadow(
            color: Color(0x0D5B6CFF),
            blurRadius: 40,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Video preview (video calls with camera on) ────────────────────
          if (isVideo && cameraOn && localRenderer != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AuraRadius.md),
              child: SizedBox(
                width: double.infinity,
                height: 68,
                child: RTCVideoView(
                  localRenderer!,
                  mirror: true,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              ),
            ),
            const SizedBox(height: AuraSpace.s8),
          ],

          // ── Row 1: live indicator · title · duration · drag handle ────────
          Row(
            children: [
              _LiveDot(active: isOwner),
              const SizedBox(width: AuraSpace.s6),
              Text(
                isOwner
                    ? (isVideo ? 'Video Call' : 'Audio Call')
                    : 'Call in another tab',
                style: AuraText.small.copyWith(
                  color: AuraSurface.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                duration,
                style: AuraText.small.copyWith(
                  color: AuraSurface.muted,
                  fontFeatures: const [ui.FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: AuraSpace.s8),
              const Icon(
                Icons.drag_indicator_rounded,
                size: 14,
                color: AuraSurface.faint,
              ),
            ],
          ),

          const SizedBox(height: AuraSpace.s8),

          // ── Row 2: avatars · status · buttons ────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (participants.isNotEmpty) ...[
                _MiniAvatarStack(participants: participants),
                const SizedBox(width: AuraSpace.s8),
              ],

              if (isOwner) ...[
                _StatusDot(
                  icon: micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
                  on: micOn,
                ),
                if (isVideo) ...[
                  const SizedBox(width: AuraSpace.s4),
                  _StatusDot(
                    icon: cameraOn
                        ? Icons.videocam_rounded
                        : Icons.videocam_off_rounded,
                    on: cameraOn,
                  ),
                ],
              ] else ...[
                // Passive tab — show a subtle indicator only
                Text(
                  'Active',
                  style: AuraText.micro.copyWith(
                    color: AuraSurface.muted,
                  ),
                ),
              ],

              const Spacer(),

              if (onReturn != null) ...[
                _Chip(
                  label: 'Return',
                  icon: Icons.open_in_full_rounded,
                  accent: true,
                  onTap: onReturn!,
                ),
                if (onEnd != null) const SizedBox(width: AuraSpace.s6),
              ],
              if (onEnd != null)
                _Chip(
                  label: isEnding ? 'Ending…' : 'End',
                  icon: Icons.call_end_rounded,
                  danger: true,
                  onTap: isEnding ? null : onEnd!,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MICRO-WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _LiveDot extends StatelessWidget {
  const _LiveDot({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: active ? const Color(0xFF4ADE80) : AuraSurface.muted,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _MiniAvatarStack extends StatelessWidget {
  const _MiniAvatarStack({required this.participants});
  final List<RealtimeParticipant> participants;

  @override
  Widget build(BuildContext context) {
    final shown = participants.take(3).toList();
    const size = 22.0;
    const step = 12.0;

    return SizedBox(
      width: size + (shown.length - 1) * step,
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * step,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF0F1E33),
                    width: 1.5,
                  ),
                ),
                child: ClipOval(
                  child: AuraAvatar(
                    name: shown[i].displayName?.trim().isNotEmpty == true
                        ? shown[i].displayName!
                        : shown[i].handle ?? '?',
                    size: size,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.icon, required this.on});
  final IconData icon;
  final bool on;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: on ? AuraSurface.goodBg : AuraSurface.dangerBg,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 12, color: on ? AuraSurface.goodInk : AuraSurface.dangerInk),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.icon,
    required this.onTap,
    this.accent = false,
    this.danger = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool accent;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final Color bg;
    final Color fg;
    final Color border;
    if (danger) {
      bg = AuraSurface.dangerBg;
      fg = AuraSurface.dangerInk;
      border = AuraSurface.dangerInk.withValues(alpha: 0.35);
    } else if (accent) {
      bg = AuraSurface.accentSoft;
      fg = AuraSurface.accentText;
      border = AuraSurface.accent.withValues(alpha: 0.35);
    } else {
      bg = AuraSurface.card;
      fg = AuraSurface.muted;
      border = AuraSurface.divider;
    }

    return MouseRegion(
      cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: disabled ? 0.6 : 1.0,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AuraSpace.s8,
              vertical: AuraSpace.s4,
            ),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AuraRadius.md),
              border: Border.all(color: border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 11, color: fg),
                const SizedBox(width: AuraSpace.s4),
                Text(
                  label,
                  style: AuraText.micro.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
