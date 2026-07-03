import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../application/meeting_entry_prefs.dart';

/// Handle the parent uses to release the preview camera/mic BEFORE navigating
/// into the live room. The device-check preview holds its own getUserMedia
/// stream; on a single physical camera it must be released first or the room's
/// acquisition would collide with it (→ audio-only). Call [release] right
/// before `context.push(...)`.
class MeetingDeviceCheckController {
  Future<void> Function()? _release;
  bool _released = false;

  Future<void> release() async {
    if (_released) return;
    _released = true;
    await _release?.call();
  }
}

/// Pre-join / lobby device check: a live self-preview with camera + mic
/// readiness. Fully isolated from the verified live-media service — it owns its
/// own renderer + stream, so it can never perturb the frozen RTC path. The
/// camera/mic ON-OFF choice is recorded in [meetingEntryPrefsProvider] and the
/// live room applies it after joining.
class MeetingDeviceCheck extends ConsumerStatefulWidget {
  const MeetingDeviceCheck({
    super.key,
    this.controller,
    this.displayName,
  });

  final MeetingDeviceCheckController? controller;
  final String? displayName;

  @override
  ConsumerState<MeetingDeviceCheck> createState() => _MeetingDeviceCheckState();
}

class _MeetingDeviceCheckState extends ConsumerState<MeetingDeviceCheck> {
  RTCVideoRenderer? _renderer;
  MediaStream? _stream;
  bool _cameraOn = true;
  bool _micOn = true;
  bool _cameraUnavailable = false;
  bool _ready = false;
  bool _initializing = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.controller?._release = _stop;
    // Seed prefs to the defaults this preview starts with.
    Future.microtask(() {
      if (!mounted) return;
      final prefs = ref.read(meetingEntryPrefsProvider.notifier);
      prefs.setCameraOn(true);
      prefs.setMicOn(true);
    });
    _init();
  }

  Future<void> _init() async {
    try {
      final renderer = RTCVideoRenderer();
      await renderer.initialize();

      MediaStream? stream;
      try {
        stream = await navigator.mediaDevices.getUserMedia(<String, dynamic>{
          'audio': true,
          'video': <String, dynamic>{'facingMode': 'user'},
        });
      } catch (_) {
        // Camera busy/denied → try audio-only so the mic check still works and
        // the user is told their camera is unavailable (same behaviour the room
        // uses when a single camera is shared across apps/browsers).
        try {
          stream = await navigator.mediaDevices.getUserMedia(
            <String, dynamic>{'audio': true, 'video': false},
          );
          _cameraUnavailable = true;
        } catch (_) {
          stream = null;
        }
      }

      if (!mounted) {
        await renderer.dispose();
        await stream?.dispose();
        return;
      }

      if (stream == null) {
        setState(() {
          _initializing = false;
          _ready = false;
          _error = 'Camera and microphone are unavailable. '
              'Check your browser permissions.';
        });
        await renderer.dispose();
        return;
      }

      renderer.srcObject = stream;
      final hasVideo = stream.getVideoTracks().isNotEmpty;
      setState(() {
        _renderer = renderer;
        _stream = stream;
        _initializing = false;
        _ready = true;
        _cameraOn = hasVideo;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _ready = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _stop() async {
    final stream = _stream;
    final renderer = _renderer;
    _stream = null;
    _renderer = null;
    try {
      renderer?.srcObject = null;
      for (final track in stream?.getTracks() ?? const []) {
        await track.stop();
      }
      await stream?.dispose();
      await renderer?.dispose();
    } catch (_) {
      // best-effort teardown
    }
  }

  void _toggleCamera() {
    final tracks = _stream?.getVideoTracks() ?? const <MediaStreamTrack>[];
    if (tracks.isEmpty) return; // no camera (unavailable) → nothing to toggle
    final next = !_cameraOn;
    for (final t in tracks) {
      t.enabled = next;
    }
    ref.read(meetingEntryPrefsProvider.notifier).setCameraOn(next);
    setState(() => _cameraOn = next);
  }

  void _toggleMic() {
    final tracks = _stream?.getAudioTracks() ?? const <MediaStreamTrack>[];
    if (tracks.isEmpty) return;
    final next = !_micOn;
    for (final t in tracks) {
      t.enabled = next;
    }
    ref.read(meetingEntryPrefsProvider.notifier).setMicOn(next);
    setState(() => _micOn = next);
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initial = (widget.displayName ?? '').trim().isNotEmpty
        ? widget.displayName!.trim()[0].toUpperCase()
        : '?';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 16 / 10,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: DecoratedBox(
              decoration: const BoxDecoration(color: Color(0xFF0B1120)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_renderer != null && _cameraOn && !_cameraUnavailable)
                    RTCVideoView(
                      _renderer!,
                      mirror: true,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    )
                  else
                    _buildPlaceholder(initial),
                  if (_initializing)
                    const Center(
                      child: SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ),
                  // On-glass control row.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 10,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _GlassToggle(
                          on: _micOn,
                          onIcon: Icons.mic_rounded,
                          offIcon: Icons.mic_off_rounded,
                          onTap: _stream == null ? null : _toggleMic,
                        ),
                        const SizedBox(width: 12),
                        _GlassToggle(
                          on: _cameraOn && !_cameraUnavailable,
                          onIcon: Icons.videocam_rounded,
                          offIcon: Icons.videocam_off_rounded,
                          onTap: (_stream == null || _cameraUnavailable)
                              ? null
                              : _toggleCamera,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _buildReadiness(),
      ],
    );
  }

  Widget _buildPlaceholder(String initial) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: const Color(0xFF6C63FF).withValues(alpha: 0.25),
            child: Text(
              initial,
              style: const TextStyle(
                color: Color(0xFFE5E7EB),
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _cameraUnavailable ? 'Camera unavailable' : 'Camera off',
            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildReadiness() {
    final (icon, color, text) = switch ((_ready, _cameraUnavailable, _error)) {
      (_, _, final e?) when e.isNotEmpty => (
        Icons.error_outline_rounded,
        const Color(0xFFF87171),
        e,
      ),
      (true, true, _) => (
        Icons.mic_rounded,
        const Color(0xFFF59E0B),
        'Camera unavailable — you\'ll join with audio only.',
      ),
      (true, false, _) => (
        Icons.check_circle_rounded,
        const Color(0xFF10B981),
        'You\'re ready to join.',
      ),
      _ => (
        Icons.hourglass_empty_rounded,
        const Color(0xFF9CA3AF),
        'Checking your camera and microphone…',
      ),
    };
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: color, fontSize: 13.5, height: 1.35),
          ),
        ),
      ],
    );
  }
}

class _GlassToggle extends StatelessWidget {
  const _GlassToggle({
    required this.on,
    required this.onIcon,
    required this.offIcon,
    required this.onTap,
  });

  final bool on;
  final IconData onIcon;
  final IconData offIcon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Material(
      color: on
          ? Colors.white.withValues(alpha: 0.16)
          : const Color(0xFFEF4444).withValues(alpha: 0.85),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            on ? onIcon : offIcon,
            size: 20,
            color: disabled
                ? const Color(0xFF6B7280)
                : const Color(0xFFF9FAFB),
          ),
        ),
      ),
    );
  }
}
