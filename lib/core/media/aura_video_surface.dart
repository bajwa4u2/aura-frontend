/// AURA VIDEO SURFACE — the canonical inline presentation primitive for
/// STORED video, platform-wide.
///
/// ## THE DEFECT THIS REPLACES
///
/// The backend sets a thumbnail only for images:
///
///     thumbnailUrl: kind === 'IMAGE' ? publicUrl : null   // media.service.ts
///
/// and its derivative pipeline refuses anything that is not an image mime, so
/// for EVERY video the product has ever stored, `thumbUrl` is null. That is
/// not dishonesty in the backend — a poster it cannot make is truthfully
/// absent. The defect was what each client surface then improvised:
///
///   * `CanonicalMediaThumb` — the shared adapter behind the feed,
///     announcements and institution announcements — had no video branch at
///     all. It passed the media URL to the image pipeline; an MP4 handed to an
///     image decoder fails, and the frame fell back to `BrokenMediaTile`, a
///     `broken_image` icon. This is the founder-observed defect.
///   * The post card asked `previewUrl`, which for a poster-less video
///     returned the VIDEO url, and fed that to the same image pipeline — the
///     same broken tile reached by a different road.
///   * Four composers showed a videocam glyph and a file name, so a video was
///     never visible before publishing it.
///   * Conversation alone had real inline playback, in a PRIVATE widget inside
///     `conversation_screen.dart` that no other surface could reach.
///
/// Four surfaces, four answers, three of them wrong. Sharing a video into
/// Correspondence worked; sharing the same video into a post, an announcement
/// or an institution space produced a broken image.
///
/// ## POSTER STRATEGY (hybrid, server-authoritative)
///
/// `video_player` resolves only `video_player_android`,
/// `video_player_avfoundation` and `video_player_web`. There is NO Windows or
/// Linux implementation, and Aura ships Windows. So client-side frame
/// extraction CANNOT be the authority: on a released platform it cannot run at
/// all. The order is therefore:
///
///   1. SERVER POSTER — a plain image, so it works on every platform
///      including the ones that cannot decode video, caches like any other
///      image, and costs nothing per tile. This is the canonical mechanism and
///      the durable answer.
///   2. CLIENT FIRST FRAME — where the running platform can decode, the first
///      frame of the video itself is the only other truthful picture of it.
///      An enhancement, never the authority.
///   3. HONEST VIDEO TILE — identity, duration and a play affordance, with no
///      claim to show content. Never a broken-image glyph.
///
/// [posterUrl] is a pure input. If the backend later grows frame extraction it
/// populates that field and nothing here changes but the cost.
///
/// PLAYBACK REUSES THE POSTER'S CONTROLLER: the frame shown before play and
/// the frames shown during it come from one decode, so pressing play does not
/// re-open the video.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../ui/aura_radius.dart';
import '../ui/aura_space.dart';
import '../ui/aura_surface.dart';
import '../ui/aura_text.dart';
import 'local_video_source_stub.dart'
    if (dart.library.io) 'local_video_source_io.dart'
    if (dart.library.html) 'local_video_source_web.dart';
import 'media_initialization.dart';
import 'media_url_resolver.dart';

/// Whether the running platform can decode video in-process.
///
/// Derived from the federated implementations `video_player` actually
/// resolves, not from a guess: android, avfoundation (iOS/macOS) and web.
/// Windows and Linux have no implementation, so a surface there must present
/// the video honestly rather than attempt a decode that throws.
///
/// Exposed as a pure function so the fallback grammar is testable without a
/// platform.
bool storedVideoCanDecodeInline({TargetPlatform? platform, bool? isWeb}) {
  if (isWeb ?? kIsWeb) return true;
  switch (platform ?? defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return true;
    case TargetPlatform.windows:
    case TargetPlatform.linux:
    case TargetPlatform.fuchsia:
      return false;
  }
}

/// `m:ss`, matching the voice player's clock so a duration reads the same
/// whether it is attached to audio or to video.
String formatVideoDuration(int? milliseconds) {
  final ms = milliseconds ?? 0;
  if (ms <= 0) return '';
  final total = (ms / 1000).round();
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = (total % 60).toString().padLeft(2, '0');
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$s';
  return '$m:$s';
}

/// What a tap means on this surface.
enum AuraVideoTap {
  /// Play where it sits. Correspondence and composers read this way: the video
  /// is part of the message being read or written.
  inline,

  /// Hand off to the fullscreen viewer. Feed and post cards read this way: the
  /// card references the media, it is not the media's home.
  viewer,
}

/// Canonical inline surface for a single stored video.
///
/// Callers supply a URL that is already fetchable; visibility-gated media is
/// resolved by [AuraVideoMedia], which owns the signed-URL flow.
class AuraVideoSurface extends StatefulWidget {
  const AuraVideoSurface({
    super.key,
    this.url = '',
    this.localPath,
    this.posterUrl,
    this.intrinsicWidth,
    this.intrinsicHeight,
    this.durationMs,
    this.fileName,
    this.maxHeight,
    this.borderRadius,
    this.tap = AuraVideoTap.inline,
    this.onOpenViewer,
    this.showDuration = true,
    this.canDecode,
  });

  /// A directly fetchable video URL. Never handed to an image decoder.
  final String url;

  /// A local, pre-upload source: a filesystem path natively, a `blob:` URL on
  /// web. Compose surfaces pass this so a chosen video looks the same before
  /// it is sent as it will afterwards — §8's continuity requirement — without
  /// a second compose-only preview architecture.
  final String? localPath;

  /// Server-provided poster when one exists. Absent for every video the
  /// product stores today — see the library doc.
  final String? posterUrl;

  final int? intrinsicWidth;
  final int? intrinsicHeight;

  /// Duration in MILLISECONDS (F133), as the rest of the product carries it.
  final int? durationMs;

  /// Retained so a video that cannot be shown still keeps its identity.
  final String? fileName;

  final double? maxHeight;
  final BorderRadius? borderRadius;
  final AuraVideoTap tap;

  /// Invoked instead of inline playback when [tap] is [AuraVideoTap.viewer].
  final VoidCallback? onOpenViewer;

  final bool showDuration;

  /// Test seam for the platform capability decision.
  final bool? canDecode;

  @override
  State<AuraVideoSurface> createState() => _AuraVideoSurfaceState();
}

class _AuraVideoSurfaceState extends State<AuraVideoSurface> {
  VideoPlayerController? _controller;
  bool _preparing = false;
  bool _failed = false;
  bool _playing = false;

  bool get _hasServerPoster => (widget.posterUrl ?? '').trim().isNotEmpty;
  bool get _canDecode => widget.canDecode ?? storedVideoCanDecodeInline();

  @override
  void initState() {
    super.initState();
    // With a server poster there is nothing to decode until someone plays.
    // Without one, the first frame IS the poster — but only where the platform
    // can produce it. Elsewhere the honest tile stands, and no decode is
    // attempted that could only throw.
    //
    // Deferred by a microtask rather than run inline: `_prepare` calls
    // setState, and doing that synchronously from initState marks the element
    // dirty while its own mount is still in progress.
    if (!_hasServerPoster && _canDecode) {
      _preparing = true;
      scheduleMicrotask(_prepare);
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onPlaybackChanged);
    _controller?.dispose();
    super.dispose();
  }

  void _onPlaybackChanged() {
    final controller = _controller;
    if (controller == null || !mounted) return;
    final playing = controller.value.isPlaying;
    if (playing != _playing) setState(() => _playing = playing);
  }

  Future<void> _prepare({bool thenPlay = false}) async {
    final existing = _controller;
    if (existing != null) {
      if (thenPlay) await existing.play();
      return;
    }
    final url = widget.url.trim();
    final local = (widget.localPath ?? '').trim();
    if ((url.isEmpty && local.isEmpty) || !_canDecode) {
      if (mounted) setState(() => _failed = url.isEmpty && local.isEmpty);
      return;
    }
    setState(() => _preparing = true);
    try {
      // A local source is preferred when present: during compose the object
      // has no server URL yet, and after upload the caller stops passing one.
      final controller = local.isNotEmpty
          ? localVideoController(local)
          : VideoPlayerController.networkUrl(Uri.parse(url));
      if (controller == null) {
        setState(() {
          _failed = true;
          _preparing = false;
        });
        return;
      }
      // BOUNDED. A stalled load is silence, not an error, so without this the
      // surface would sit in `_preparing` forever instead of reaching the
      // honest failure state below.
      await boundedMediaInit(
        MediaInitPhase.acquisition,
        () => controller.initialize(),
      );
      // Some platforms present nothing until a position is requested, so the
      // poster would be a black rectangle rather than a frame of the video.
      await boundedMediaInit(
        MediaInitPhase.decode,
        () => controller.seekTo(Duration.zero),
      );
      if (!mounted) {
        await controller.dispose();
        return;
      }
      controller.addListener(_onPlaybackChanged);
      setState(() {
        _controller = controller;
        _preparing = false;
      });
      if (thenPlay) await controller.play();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _preparing = false;
      });
    }
  }

  Future<void> _toggle() async {
    final controller = _controller;
    if (controller == null) {
      await _prepare(thenPlay: true);
      return;
    }
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
  }

  void _onTap() {
    final openViewer = widget.onOpenViewer;
    // A platform that cannot decode must still be able to reach the media,
    // so the viewer (which can offer open/download) is preferred there.
    if ((widget.tap == AuraVideoTap.viewer || !_canDecode) &&
        openViewer != null) {
      openViewer();
      return;
    }
    _toggle();
  }

  double get _aspectRatio {
    final fromVideo = _controller?.value.aspectRatio ?? 0;
    if (fromVideo > 0) return fromVideo;
    final w = widget.intrinsicWidth;
    final h = widget.intrinsicHeight;
    if (w != null && h != null && w > 0 && h > 0) return w / h;
    return 16 / 9;
  }

  String get _semanticLabel {
    final parts = <String>['Video'];
    final name = (widget.fileName ?? '').trim();
    if (name.isNotEmpty) parts.add(name);
    final duration = formatVideoDuration(widget.durationMs);
    if (duration.isNotEmpty) parts.add(duration);
    if (_failed) parts.add('unavailable');
    return parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(16);

    if (_failed) {
      return AuraVideoUnavailableTile(
        fileName: widget.fileName,
        borderRadius: radius,
      );
    }

    final Widget surface;
    if (_hasServerPoster && _controller == null) {
      surface = Image.network(
        widget.posterUrl!.trim(),
        fit: BoxFit.cover,
        width: double.infinity,
        // A poster that will not load must not become a broken image. The
        // video is still the truth, so fall through to decoding it where that
        // is possible, and to the honest tile where it is not.
        errorBuilder: (_, __, ___) {
          if (_canDecode) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _controller == null && !_preparing) _prepare();
            });
          }
          return _placeholder();
        },
      );
    } else if (_controller != null) {
      surface = VideoPlayer(_controller!);
    } else {
      surface = _placeholder();
    }

    final durationLabel = formatVideoDuration(widget.durationMs);

    final content = ClipRRect(
      borderRadius: radius,
      child: AspectRatio(
        aspectRatio: _aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            surface,
            if (!_playing) _playAffordance(),
            if (widget.showDuration && durationLabel.isNotEmpty)
              Positioned(top: 12, right: 12, child: _durationChip(durationLabel)),
          ],
        ),
      ),
    );

    return Semantics(
      button: true,
      label: _semanticLabel,
      child: GestureDetector(
        onTap: _onTap,
        child: widget.maxHeight == null
            ? content
            : ConstrainedBox(
                constraints: BoxConstraints(maxHeight: widget.maxHeight!),
                child: content,
              ),
      ),
    );
  }

  /// Neutral ground while a frame is being produced, or where none can be.
  /// It keeps the media's identity as video and never implies damage.
  Widget _placeholder() => Container(
        color: AuraSurface.subtle,
        alignment: Alignment.center,
        child: _preparing
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.videocam_outlined, color: AuraSurface.faint),
      );

  Widget _playAffordance() => Center(
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.58),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.play_arrow_rounded,
              size: 36, color: Colors.white),
        ),
      );

  Widget _durationChip(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AuraRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam, size: 14, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              label,
              style: AuraText.small
                  .copyWith(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
}

/// Honest tile for a video that cannot be reached or decoded.
///
/// Deliberately NOT `BrokenMediaTile`. A broken-image glyph asserts the file is
/// damaged; usually the truth is that this surface could not fetch or decode
/// it. This keeps the object's identity as video, and its name where known.
class AuraVideoUnavailableTile extends StatelessWidget {
  const AuraVideoUnavailableTile({
    super.key,
    this.label = 'Video unavailable',
    this.fileName,
    this.borderRadius,
  });

  final String label;
  final String? fileName;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final name = (fileName ?? '').trim();
    return Semantics(
      label: name.isEmpty ? 'Video, $label' : 'Video, $name, $label',
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        child: Container(
          color: AuraSurface.subtle,
          padding: const EdgeInsets.all(AuraSpace.s12),
          constraints: const BoxConstraints(minHeight: 120),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off_outlined,
                  color: AuraSurface.faint, size: 32),
              const SizedBox(height: AuraSpace.s8),
              Text(
                name.isEmpty ? label : name,
                style: AuraText.small.copyWith(color: AuraSurface.muted),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Visibility-aware entry point: resolves a signed URL for gated media, then
/// renders the canonical surface.
///
/// This mirrors the fullscreen viewer's own resolution path, so a restricted
/// video behaves the same inline as it does fullscreen and the poster's
/// authorization follows the parent object rather than becoming a second,
/// separately-reachable URL.
class AuraVideoMedia extends ConsumerWidget {
  const AuraVideoMedia({
    super.key,
    required this.mediaId,
    required this.isPublic,
    this.publicUrl,
    this.posterUrl,
    this.intrinsicWidth,
    this.intrinsicHeight,
    this.durationMs,
    this.fileName,
    this.maxHeight,
    this.borderRadius,
    this.tap = AuraVideoTap.inline,
    this.onOpenViewer,
    this.showDuration = true,
  });

  final String mediaId;
  final bool isPublic;
  final String? publicUrl;
  final String? posterUrl;
  final int? intrinsicWidth;
  final int? intrinsicHeight;
  final int? durationMs;
  final String? fileName;
  final double? maxHeight;
  final BorderRadius? borderRadius;
  final AuraVideoTap tap;
  final VoidCallback? onOpenViewer;
  final bool showDuration;

  Widget _surface(String url) => AuraVideoSurface(
        url: url,
        posterUrl: posterUrl,
        intrinsicWidth: intrinsicWidth,
        intrinsicHeight: intrinsicHeight,
        durationMs: durationMs,
        fileName: fileName,
        maxHeight: maxHeight,
        borderRadius: borderRadius,
        tap: tap,
        onOpenViewer: onOpenViewer,
        showDuration: showDuration,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final direct = (publicUrl ?? '').trim();
    if (isPublic && direct.isNotEmpty) return _surface(direct);

    final id = mediaId.trim();
    if (id.isEmpty) {
      return direct.isEmpty
          ? AuraVideoUnavailableTile(
              fileName: fileName, borderRadius: borderRadius)
          : _surface(direct);
    }

    return ref.watch(mediaUrlProvider(id)).when(
          data: (result) {
            final url = result.url.trim();
            if (url.isEmpty) {
              return AuraVideoUnavailableTile(
                label: 'This video is no longer available.',
                fileName: fileName,
                borderRadius: borderRadius,
              );
            }
            return _surface(url);
          },
          loading: () => ClipRRect(
            borderRadius: borderRadius ?? BorderRadius.circular(16),
            child: Container(
              color: AuraSurface.subtle,
              height: 160,
              alignment: Alignment.center,
              child: const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          error: (_, __) => AuraVideoUnavailableTile(
            label: 'This media link has expired or is no longer available.',
            fileName: fileName,
            borderRadius: borderRadius,
          ),
        );
  }
}
