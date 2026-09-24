/// THE MEETING STAGE.
///
/// One surface, owned by the people in the meeting. It replaces a
/// `GridView.count` that reserved a cell for a participant who did not exist,
/// computed its cell height against a viewport it did not have, and let the
/// last row fall off the bottom of the window.
///
/// The rules it obeys live in `meeting_stage_layout.dart` so they can be
/// argued about in tests rather than in screenshots.
library;

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'meeting_stage_layout.dart';

/// One person on the stage, as the stage needs to know them.
class StageTile {
  const StageTile({
    required this.key,
    required this.label,
    this.renderer,
    this.avatarUrl,
    this.micOn = true,
    this.isLocal = false,
    this.mirror = false,
    this.isSpeaking = false,
    this.cameraOffReason,
  });

  final String key;
  final String label;
  final RTCVideoRenderer? renderer;
  final String? avatarUrl;
  final bool micOn;
  final bool isLocal;
  final bool mirror;
  final bool isSpeaking;

  /// Why there is no picture, when there is none. Held so the surface can be
  /// deliberate about it instead of painting an unexplained black rectangle —
  /// and so a stale state cannot hide behind a pretty tile.
  final String? cameraOffReason;

  /// GROUND TRUTH IS THE MEDIA PLANE.
  ///
  /// This asks the renderer what it is holding, and nothing else. Two flags
  /// have now been trusted here and both lied: the roster's `videoOn` (which
  /// could not be trusted before a meeting's camera signalled the session at
  /// all) and the received track's `muted` (which is the browser saying "no
  /// data this instant", and which left an avatar and the words "Camera off"
  /// over a picture the receiver was decoding at 1,745 frames and climbing).
  ///
  /// A track that exists and has not ended is a picture. Nothing else is.
  bool get hasPicture {
    final tracks = renderer?.srcObject?.getVideoTracks() ?? const [];
    return stageTileShowsPicture(
      hasVideoTrack: tracks.isNotEmpty && tracks.first.kind == 'video',
      trackMuted: tracks.isEmpty ? null : tracks.first.muted,
    );
  }

  /// The video's own shape, when the renderer knows it yet.
  double? get videoAspect {
    final r = renderer;
    if (r == null) return null;
    final w = r.videoWidth;
    final h = r.videoHeight;
    if (w <= 0 || h <= 0) return null;
    return w / h;
  }
}

/// The participant stage: every tile visible, the whole surface used.
class MeetingStage extends StatelessWidget {
  const MeetingStage({
    super.key,
    required this.tiles,
    this.presentation,
    this.presenterLabel,
    this.onExitPresentation,
    this.gap = 6,
  });

  final List<StageTile> tiles;

  /// A shared screen, when somebody is presenting. It takes the stage and the
  /// people move to a filmstrip beside it.
  final RTCVideoRenderer? presentation;
  final String? presenterLabel;
  final VoidCallback? onExitPresentation;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final stage = Size(c.maxWidth, c.maxHeight);
        if (presentation != null) {
          return _PresentationComposition(
            stage: stage,
            presentation: presentation!,
            presenterLabel: presenterLabel,
            onExit: onExitPresentation,
            tiles: tiles,
            gap: gap,
          );
        }
        return _ParticipantComposition(stage: stage, tiles: tiles, gap: gap);
      },
    );
  }
}

class _ParticipantComposition extends StatelessWidget {
  const _ParticipantComposition({
    required this.stage,
    required this.tiles,
    required this.gap,
  });

  final Size stage;
  final List<StageTile> tiles;
  final double gap;

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.expand();
    final rows = stageRows(
      count: tiles.length,
      stageAspect: stage.height <= 0 ? 16 / 9 : stage.width / stage.height,
    );

    // EXPANDED, NOT A COMPUTED ASPECT. Rows and cells take their share of what
    // actually exists, so nothing can overflow the stage or be clipped by the
    // window — the defect this composition replaces.
    final columns = stageColumns(rows);
    var taken = 0;
    final rowWidgets = <Widget>[];
    for (var r = 0; r < rows.length; r++) {
      final n = rows[r];
      final rowTiles = tiles.sublist(taken, taken + n);
      taken += n;
      // A SHORT ROW IS CENTRED, NOT STRETCHED. Each tile carries flex 2 so the
      // two side spacers can split the leftover columns exactly; every tile on
      // the stage then has the same width whatever row it sits in.
      //
      // The slack is counted in COLUMNS, not in flex units. Counting it in
      // flex units gave a single participant half the stage and three
      // participants a quarter each — caught by the geometry test, which is
      // why that test measures rectangles rather than trusting the arithmetic.
      final slack = columns - n;
      rowWidgets.add(
        Expanded(
          child: Row(
            children: [
              if (slack > 0) Spacer(flex: slack),
              for (var i = 0; i < rowTiles.length; i++) ...[
                if (i > 0) SizedBox(width: gap),
                Expanded(
                  flex: 2,
                  child: _Tile(tile: rowTiles[i]),
                ),
              ],
              if (slack > 0) Spacer(flex: slack),
            ],
          ),
        ),
      );
      if (r < rows.length - 1) rowWidgets.add(SizedBox(height: gap));
    }

    return Padding(
      padding: EdgeInsets.all(gap),
      child: Column(children: rowWidgets),
    );
  }
}

class _PresentationComposition extends StatelessWidget {
  const _PresentationComposition({
    required this.stage,
    required this.presentation,
    required this.presenterLabel,
    required this.onExit,
    required this.tiles,
    required this.gap,
  });

  final Size stage;
  final RTCVideoRenderer presentation;
  final String? presenterLabel;
  final VoidCallback? onExit;
  final List<StageTile> tiles;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final placement = filmstripPlacement(stage);
    final extent = filmstripExtent(stage, placement, tiles.length);

    // THE PRESENTATION IS NEVER CROPPED. A document that loses its margin, or
    // an application whose toolbar is cut off, has lost the thing it was
    // shared for.
    final surface = Container(
      decoration: BoxDecoration(
        color: const Color(0xFF05070D),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: RTCVideoView(
              presentation,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
            ),
          ),
          if (presenterLabel != null)
            Positioned(
              left: 10,
              top: 10,
              child: _Chip(
                icon: Icons.present_to_all_rounded,
                text: '$presenterLabel is presenting',
              ),
            ),
          if (onExit != null)
            Positioned(
              right: 10,
              top: 10,
              child: _GhostButton(
                icon: Icons.grid_view_rounded,
                label: 'People',
                onTap: onExit!,
              ),
            ),
        ],
      ),
    );

    final strip = _Filmstrip(tiles: tiles, placement: placement, gap: gap);

    return Padding(
      padding: EdgeInsets.all(gap),
      child: placement == FilmstripPlacement.right
          ? Row(children: [
              Expanded(child: surface),
              SizedBox(width: gap),
              SizedBox(width: extent, child: strip),
            ])
          : Column(children: [
              Expanded(child: surface),
              SizedBox(height: gap),
              SizedBox(height: extent, child: strip),
            ]),
    );
  }
}

class _Filmstrip extends StatelessWidget {
  const _Filmstrip({
    required this.tiles,
    required this.placement,
    required this.gap,
  });

  final List<StageTile> tiles;
  final FilmstripPlacement placement;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final vertical = placement == FilmstripPlacement.right;
    return ListView.separated(
      scrollDirection: vertical ? Axis.vertical : Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      itemCount: tiles.length,
      separatorBuilder: (_, __) => SizedBox(width: gap, height: gap),
      itemBuilder: (context, i) => AspectRatio(
        aspectRatio: 16 / 9,
        child: _Tile(tile: tiles[i], compact: true),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.tile, this.compact = false});

  final StageTile tile;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final speaking = tile.isSpeaking;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220),
        borderRadius: BorderRadius.circular(compact ? 8 : 12),
        border: Border.all(
          color: speaking ? const Color(0xFF6C63FF) : const Color(0x14FFFFFF),
          width: speaking ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (tile.hasPicture)
            RTCVideoView(
              tile.renderer!,
              mirror: tile.mirror,
              // Always Cover for a person — see `participantTilesAlwaysCover`.
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            )
          else
            _CameraOff(tile: tile, compact: compact),
          Positioned(
            left: compact ? 6 : 10,
            bottom: compact ? 6 : 10,
            child: _NamePlate(
              label: tile.isLocal ? 'You' : tile.label,
              micOn: tile.micOn,
              compact: compact,
            ),
          ),
        ],
      ),
    );
  }
}

/// A DELIBERATE ABSENCE, NOT A BLACK RECTANGLE.
///
/// When there is no picture the tile says so, with the person's own face or
/// initial and a plain word for what is happening. An unexplained black cell
/// reads as a broken product; this reads as somebody with their camera off.
class _CameraOff extends StatelessWidget {
  const _CameraOff({required this.tile, required this.compact});

  final StageTile tile;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final name = tile.label.trim();
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    final avatar = (tile.avatarUrl ?? '').trim();
    final r = compact ? 18.0 : 34.0;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF131C2E), Color(0xFF0A111C)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: r,
              backgroundColor: const Color(0xFF6C63FF).withValues(alpha: 0.22),
              backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
              child: avatar.isNotEmpty
                  ? null
                  : Text(
                      initial,
                      style: TextStyle(
                        color: const Color(0xFFE5E7EB),
                        fontSize: r * 0.8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
            if (!compact) ...[
              const SizedBox(height: 10),
              Text(
                tile.cameraOffReason ?? 'Camera off',
                style: const TextStyle(
                  color: Color(0xFF7C8AA5),
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NamePlate extends StatelessWidget {
  const _NamePlate({
    required this.label,
    required this.micOn,
    required this.compact,
  });

  final String label;
  final bool micOn;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 9,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: const Color(0xB3030712),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
            size: compact ? 11 : 13,
            color: micOn ? const Color(0xFFE5E7EB) : const Color(0xFFF87171),
          ),
          SizedBox(width: compact ? 4 : 6),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: compact ? 92 : 180),
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: const Color(0xFFE5E7EB),
                fontSize: compact ? 11 : 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xCC030712),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: const Color(0xFF9AE6B4)),
          const SizedBox(width: 6),
          Text(text,
              style: const TextStyle(
                  color: Color(0xFFE5E7EB),
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ]),
      );
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: Material(
          color: const Color(0xCC030712),
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 13, color: const Color(0xFFE5E7EB)),
                const SizedBox(width: 6),
                Text(label,
                    style: const TextStyle(
                        color: Color(0xFFE5E7EB),
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
      );
}
