/// AURA VOICE / AUDIO PLAYER — F014.
///
/// THE DEFECT THIS REPLACES. The product had two answers to "how does a voice
/// message play":
///
///   Conversation — a play/pause button beside the literal words "Voice note",
///   with NO progress, NO timeline and NO duration. The label was hardcoded, so
///   an uploaded MP3 was announced as a voice note it was not.
///
///   Correspondence — no playback at all. Its audio surface was a
///   StatelessWidget that handed the file to the browser.
///
/// F014's canonical remainder is exactly the missing half: "the timeline /
/// playback presentation".
///
/// VOICE IS NOT MERELY AUDIO, AND THE DISTINCTION IS REAL. A voice message is
/// `Media.source == RECORDING`, stamped by the composer at capture. That is
/// authoritative runtime truth, not an inference from the MIME — which is why
/// it is NOT folded into `attachmentKindFrom`. That resolver answers a
/// MIME-shaped question; this one answers a source-shaped question, and
/// collapsing them would make an uploaded `audio/m4a` indistinguishable from a
/// recording again.
///
/// NOTHING IS INVENTED. Duration comes from `Media.duration` (MILLISECONDS —
/// F133) and, once the media element has loaded, from the element itself.
/// When neither knows, the position is shown without a total rather than
/// against a fabricated one. There is no waveform: the product does not
/// compute amplitude data, and drawing a decorative one would assert a shape
/// the bytes never had.
library;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'media_initialization.dart';

import '../ui/aura_radius.dart';
import '../ui/aura_space.dart';
import '../ui/aura_surface.dart';
import '../ui/aura_text.dart';

/// `mm:ss`, the only format a message-length recording needs. Hours are
/// carried when a file genuinely runs that long rather than silently wrapping.
String formatPlaybackPosition(Duration d) {
  if (d.isNegative) return '0:00';
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$s';
  return '$m:$s';
}

/// True when this audio is a captured voice message rather than an uploaded
/// audio file. Source is stamped at capture and is the canonical distinction.
bool isVoiceMessageSource(String? mediaSource) =>
    (mediaSource ?? '').toUpperCase() == 'RECORDING';

/// Canonical inline player for voice messages and audio attachments.
///
/// Presentation differs by what the runtime actually knows: a recording is
/// announced as a voice message, an uploaded file keeps its own name. Playback
/// semantics are identical because nothing in the product makes them differ.
class AuraVoicePlayer extends StatefulWidget {
  const AuraVoicePlayer({
    super.key,
    required this.url,
    this.isVoiceMessage = false,
    this.fileName,
    this.durationMs,
    this.width = 260,
  });

  final String url;

  /// From `Media.source == RECORDING`. Never inferred from the MIME.
  final bool isVoiceMessage;

  /// The uploaded file's own name. Ignored for voice messages, which have no
  /// meaningful user-facing filename.
  final String? fileName;

  /// Authoritative length in MILLISECONDS (F133). Null when unknown — the
  /// player then shows position alone rather than inventing a total.
  final int? durationMs;

  final double width;

  @override
  State<AuraVoicePlayer> createState() => _AuraVoicePlayerState();
}

class _AuraVoicePlayerState extends State<AuraVoicePlayer> {
  VideoPlayerController? _controller;
  bool _initializing = false;
  bool _failed = false;

  Duration get _position => _controller?.value.position ?? Duration.zero;

  /// The element's own duration once loaded, else the authoritative value.
  /// Null when genuinely unknown.
  Duration? get _total {
    final c = _controller;
    if (c != null && c.value.isInitialized && c.value.duration > Duration.zero) {
      return c.value.duration;
    }
    final ms = widget.durationMs;
    if (ms != null && ms > 0) return Duration(milliseconds: ms);
    return null;
  }

  bool get _playing => _controller?.value.isPlaying ?? false;

  @override
  void dispose() {
    _controller?.removeListener(_tick);
    _controller?.dispose();
    super.dispose();
  }

  void _tick() {
    if (mounted) setState(() {});
  }

  Future<void> _toggle() async {
    if (_failed) return;
    if (_controller == null) {
      setState(() => _initializing = true);
      try {
        final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
        // Bounded: the honest `_failed` state below is unreachable while a
        // stalled load never completes and never throws.
        await boundedMediaInit(
          MediaInitPhase.acquisition,
          () => c.initialize(),
        );
        // Drives the progress bar and the position readout. Without this the
        // control could play while the surface stayed frozen — which is what
        // "no timeline presentation" looked like.
        c.addListener(_tick);
        if (!mounted) {
          await c.dispose();
          return;
        }
        setState(() => _controller = c);
        await c.play();
      } catch (_) {
        // Honest failure. Silence here is what made a broken voice note
        // indistinguishable from one that had simply not started.
        if (mounted) setState(() => _failed = true);
      } finally {
        if (mounted) setState(() => _initializing = false);
      }
      return;
    }
    if (_playing) {
      await _controller!.pause();
    } else {
      await _controller!.play();
    }
    if (mounted) setState(() {});
  }

  /// Seek by tapping the timeline. Only offered once a real duration is known,
  /// because seeking against an unknown total cannot be honoured.
  Future<void> _seekTo(double fraction) async {
    final c = _controller;
    final total = _total;
    if (c == null || !c.value.isInitialized || total == null) return;
    final target = total * fraction.clamp(0.0, 1.0);
    await c.seekTo(target);
    if (mounted) setState(() {});
  }

  String get _title {
    if (widget.isVoiceMessage) return 'Voice message';
    final name = (widget.fileName ?? '').trim();
    return name.isNotEmpty ? name : 'Audio';
  }

  @override
  Widget build(BuildContext context) {
    final total = _total;
    final position = _position;
    final progress = (total != null && total.inMilliseconds > 0)
        ? (position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    // Position over total once both are known; position alone while playing an
    // unknown-length file; the authoritative total before playback starts.
    final readout = _failed
        ? 'Unavailable'
        : total == null
            ? (_controller != null ? formatPlaybackPosition(position) : '')
            : _controller == null
                ? formatPlaybackPosition(total)
                : '${formatPlaybackPosition(position)} / ${formatPlaybackPosition(total)}';

    return SizedBox(
      width: widget.width,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s12, vertical: AuraSpace.s10),
        decoration: BoxDecoration(
          color: AuraSurface.subtle,
          borderRadius: BorderRadius.circular(AuraRadius.card),
        ),
        child: Row(
          children: [
            Semantics(
              button: true,
              label: _failed
                  ? 'Audio unavailable'
                  : _playing
                      ? 'Pause'
                      : 'Play $_title',
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: (_initializing || _failed) ? null : _toggle,
                child: SizedBox(
                  width: 30,
                  height: 30,
                  child: _initializing
                      ? const Padding(
                          padding: EdgeInsets.all(6),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _failed
                              ? Icons.error_outline_rounded
                              : _playing
                                  ? Icons.pause_circle_filled_rounded
                                  : Icons.play_circle_fill_rounded,
                          size: 28,
                          color: _failed
                              ? AuraSurface.muted
                              : AuraSurface.accentText,
                        ),
                ),
              ),
            ),
            const SizedBox(width: AuraSpace.s10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AuraText.small.copyWith(
                      color: AuraSurface.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // The timeline F014 names. Tappable to seek only when a real
                  // duration exists; otherwise it reports progress without
                  // offering a seek that could not be honoured.
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final bar = ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 4,
                          backgroundColor: AuraSurface.divider,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _failed ? AuraSurface.muted : AuraSurface.accent,
                          ),
                        ),
                      );
                      if (total == null || _controller == null) return bar;
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (d) => _seekTo(
                            d.localPosition.dx / constraints.maxWidth),
                        child: bar,
                      );
                    },
                  ),
                  if (readout.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      readout,
                      style: AuraText.micro.copyWith(color: AuraSurface.muted),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
