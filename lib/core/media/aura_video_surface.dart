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
import 'feed_video_autoplay.dart';
import 'local_video_source_stub.dart'
    if (dart.library.io) 'local_video_source_io.dart'
    if (dart.library.html) 'local_video_source_web.dart';
import 'media_initialization.dart';
import 'media_url_resolver.dart';

/// Whether the running platform can decode video in-process.
///
/// Derived from the federated implementations `video_player` actually
/// resolves, not from a guess: android, avfoundation (iOS/macOS), web, and
/// Windows through `video_player_win` (Media Foundation), added 2026-09-25 on
/// the founder's direction that feed video plays on Windows as it does
/// everywhere else. Linux still has no implementation, so a surface there
/// presents the video honestly rather than attempt a decode that throws.
///
/// Exposed as a pure function so the fallback grammar is testable without a
/// platform.
bool storedVideoCanDecodeInline({TargetPlatform? platform, bool? isWeb}) {
  if (isWeb ?? kIsWeb) return true;
  switch (platform ?? defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
      return true;
    case TargetPlatform.linux:
    case TargetPlatform.fuchsia:
      return false;
  }
}

/// Player options for a stored video, by where it plays and on what.
///
/// ANDROID ONLY. A silent feed video must not take audio focus there: ExoPlayer
/// asks for focus per player, and without `mixWithOthers` a muted feed video
/// paused whatever the person was already listening to.
///
/// NEVER ON iOS. There `mixWithOthers` is not per player: video_player applies
/// it by re-setting the category of the app's ONE shared AVAudioSession, every
/// time a player is created with it. The feed creates players while it is
/// alive — including under a call screen or behind the minimized call card —
/// and re-setting the session category mid-call stops WebRTC's audio unit in
/// both directions. Founder-observed on TestFlight 1.5.0 (40), 2026-09-25:
/// video good, no audio either way; the server saw the Pixel's audio reach the
/// iPhone and none leave it. Passing no options means video_player never
/// touches the session, which is exactly how 1.4.4 behaved.
@visibleForTesting
VideoPlayerOptions? feedVideoPlayerOptions({
  required bool inFeed,
  TargetPlatform? platform,
  bool? isWeb,
}) {
  if (!inFeed || (isWeb ?? kIsWeb)) return null;
  if ((platform ?? defaultTargetPlatform) != TargetPlatform.android) {
    return null;
  }
  return VideoPlayerOptions(mixWithOthers: true);
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
    this.fill = false,
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

  /// FILL THE CELL THE CALLER HAS ALREADY MEASURED.
  ///
  /// A video normally sets its own shape from its intrinsic aspect. Inside a
  /// collage cell that is wrong: the group has decided the geometry, and a
  /// video that keeps its own ratio leaves the same dead space that made a
  /// four-image post look broken. A mixed post shows it plainest -- the image
  /// cells fill and the video cell does not, so the grid reads as damaged.
  final bool fill;
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

class _AuraVideoSurfaceState extends State<AuraVideoSurface>
    implements FeedAutoplayCandidate {
  VideoPlayerController? _controller;
  bool _preparing = false;
  bool _failed = false;
  bool _playing = false;

  /// The feed this surface plays silently inside, if any. Only a surface that
  /// hands off to the viewer, decodes on this platform and plays a stored
  /// object joins one; composers and correspondence keep tap-to-play.
  FeedVideoAutoplayScope? _autoplayScope;
  bool _autoplaying = false;
  Future<void>? _opening;

  @override
  BuildContext get candidateContext => context;

  bool get _eligibleForAutoplay =>
      widget.tap == AuraVideoTap.viewer &&
      _canDecode &&
      (widget.localPath ?? '').trim().isEmpty;

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = _eligibleForAutoplay
        ? FeedVideoAutoplay.maybeOf(context)
        : null;
    if (identical(scope, _autoplayScope)) return;
    _autoplayScope?.muted.removeListener(_applyMute);
    _autoplayScope?.unregister(this);
    _autoplayScope = scope;
    scope?.muted.addListener(_applyMute);
    scope?.register(this);
  }

  @override
  void setAutoplaying(bool on) {
    if (!mounted || on == _autoplaying) return;
    setState(() => _autoplaying = on);
    if (on) {
      unawaited(_startInFeed());
    } else {
      unawaited(_controller?.pause());
    }
  }

  Future<void> _startInFeed() async {
    await _prepare();
    final controller = _controller;
    if (!mounted || !_autoplaying || controller == null) return;
    // Volume BEFORE play: a browser only lets a video start on its own when
    // it is already muted at the moment play is asked for.
    await controller.setVolume(_feedMuted ? 0 : 1);
    await controller.setLooping(true);
    if (mounted && _autoplaying) await controller.play();
  }

  bool get _feedMuted => _autoplayScope?.muted.value ?? true;

  void _applyMute() {
    if (!mounted) return;
    final controller = _controller;
    if (_autoplaying && controller != null) {
      unawaited(controller.setVolume(_feedMuted ? 0 : 1));
    }
    setState(() {});
  }

  @override
  void dispose() {
    _autoplayScope?.muted.removeListener(_applyMute);
    _autoplayScope?.unregister(this);
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

  /// One opening at a time. The first-frame decode starts from initState and
  /// autoplay can ask for the same controller moments later; without this the
  /// second request opened a second decoder and leaked the first.
  Future<void> _prepare({bool thenPlay = false}) async {
    final inflight = _opening;
    if (inflight != null) {
      await inflight;
      if (thenPlay) await _controller?.play();
      return;
    }
    final opening = _open(thenPlay: thenPlay);
    _opening = opening;
    try {
      await opening;
    } finally {
      if (identical(_opening, opening)) _opening = null;
    }
  }

  Future<void> _open({bool thenPlay = false}) async {
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
      // PREFERRED, THEN FALLBACK — not one source chosen and lived with.
      //
      // A local copy is tried first: it is the same object, costs no network,
      // and during compose the stored `Media.url` is a raw origin address that
      // answers 401 to an anonymous reader, so it is also the ONLY one that
      // works there. But a local handle can go stale — a blob URL can be
      // revoked — and the earlier rule of picking exactly one source meant a
      // stale handle became a permanently dead tile even when the server had
      // the bytes. So the stored object remains the second candidate.
      final candidates = <String>[
        if (local.isNotEmpty) local,
        if (url.isNotEmpty && url != local) url,
      ];
      VideoPlayerController? controller;
      for (final candidate in candidates) {
        final isLocal = candidate == local && local.isNotEmpty;
        final attempt = isLocal
            ? localVideoController(candidate)
            : VideoPlayerController.networkUrl(
                Uri.parse(candidate),
                videoPlayerOptions: feedVideoPlayerOptions(
                  inFeed: _autoplayScope != null,
                ),
              );
        if (attempt == null) continue;
        try {
          await boundedMediaInit(
            MediaInitPhase.acquisition,
            () => attempt.initialize(),
          );
          controller = attempt;
          break;
        } catch (_) {
          // Release the failed attempt before trying the next address;
          // otherwise a retry leaks a controller per failure.
          await attempt.dispose();
        }
      }
      final opened = controller;
      if (opened == null) {
        setState(() {
          _failed = true;
          _preparing = false;
        });
        return;
      }
      // Some platforms present nothing until a position is requested, so the
      // poster would be a black rectangle rather than a frame of the video.
      await boundedMediaInit(
        MediaInitPhase.decode,
        () => opened.seekTo(Duration.zero),
      );
      if (!mounted) {
        await opened.dispose();
        return;
      }
      opened.addListener(_onPlaybackChanged);
      setState(() {
        _controller = opened;
        _preparing = false;
      });
      if (thenPlay) await opened.play();
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

    final stack = Stack(
      fit: StackFit.expand,
      children: [
        surface,
        if (!_playing) _playAffordance(),
        if (widget.showDuration && durationLabel.isNotEmpty)
          Positioned(top: 12, right: 12, child: _durationChip(durationLabel)),
        if (_autoplayScope != null && _autoplaying && _controller != null)
          Positioned(left: 4, bottom: 4, child: _muteControl()),
      ],
    );

    // Filling means the cell's constraints decide, so the intrinsic aspect
    // is not imposed on top of them.
    final content = ClipRRect(
      borderRadius: radius,
      child: widget.fill
          ? stack
          : AspectRatio(aspectRatio: _aspectRatio, child: stack),
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

  /// Sound on or off for the feed. Its own tap target, so pressing it never
  /// also opens the viewer behind it.
  Widget _muteControl() {
    final muted = _feedMuted;
    return Semantics(
      button: true,
      label: muted ? 'Turn sound on' : 'Turn sound off',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _autoplayScope?.setMuted(!muted),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: Icon(
                muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _playAffordance() => Center(
    child: Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.play_arrow_rounded,
        size: 36,
        color: Colors.white,
      ),
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
          style: AuraText.small.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
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

  /// Below this, only the icon fits and only the icon is drawn.
  ///
  /// The composition strip renders these at 66x66. The tile asked for a
  /// `minHeight` of 120 inside that box and stacked a 32px icon, a gap and two
  /// lines of text into the 42px left after its own padding — about 68px of
  /// content in 42px of space.
  ///
  /// It overflowed on iOS and NOWHERE ELSE in certification, because the
  /// Windows and Android suites never rendered this tile at strip size. That
  /// is the whole reason the iOS lane exists.
  static const double _compactBelow = 96;

  @override
  Widget build(BuildContext context) {
    final name = (fileName ?? '').trim();
    return Semantics(
      label: name.isEmpty ? 'Video, $label' : 'Video, $name, $label',
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // ANSWER TO THE ROOM GIVEN, rather than declaring a minimum the
            // parent has already refused. A `minHeight` larger than the
            // incoming `maxHeight` is not a floor — it is an overflow.
            final compact =
                constraints.maxHeight < _compactBelow ||
                constraints.maxWidth < _compactBelow;

            if (compact) {
              // In a strip cell the caption is redundant anyway: the row
              // beneath already names the file. What a person needs at this
              // size is only that this one is a video that will not play.
              return Container(
                color: AuraSurface.subtle,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.videocam_off_outlined,
                  color: AuraSurface.faint,
                  size: 20,
                ),
              );
            }

            return Container(
              color: AuraSurface.subtle,
              padding: const EdgeInsets.all(AuraSpace.s12),
              constraints: const BoxConstraints(minHeight: 120),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.videocam_off_outlined,
                    color: AuraSurface.faint,
                    size: 32,
                  ),
                  const SizedBox(height: AuraSpace.s8),
                  Flexible(
                    child: Text(
                      name.isEmpty ? label : name,
                      style: AuraText.small.copyWith(color: AuraSurface.muted),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          },
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
    this.fill = false,
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

  /// See [AuraVideoSurface.fill] — the collage cell case.
  final bool fill;

  Widget _surface(String url) => AuraVideoSurface(
    url: url,
    posterUrl: posterUrl,
    intrinsicWidth: intrinsicWidth,
    intrinsicHeight: intrinsicHeight,
    durationMs: durationMs,
    fileName: fileName,
    maxHeight: maxHeight,
    fill: fill,
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
              fileName: fileName,
              borderRadius: borderRadius,
            )
          : _surface(direct);
    }

    return ref
        .watch(mediaUrlProvider(id))
        .when(
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
