import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/media/recording_time.dart';

/// WHERE A MEETING YOU STEPPED OUT OF WAITS FOR YOU (founder-approved design,
/// 23 Oct 2026). Each platform keeps its own convention:
///
///  * iPhone and iPad: a ribbon across the TOP, where the system puts its own
///    call indicator.
///  * Android: a bar at the BOTTOM, above the navigation.
///  * Desktop and wide web: a small CORNER panel with the live picture.
///  * Narrow web: the top ribbon, as on iPhone.
enum MeetingRibbonPlacement { top, bottom, corner }

/// The width at which a web window is a desktop rather than a phone — the same
/// line the meeting record uses for its two-column layout.
const double kMeetingRibbonWideWidth = 1100;

MeetingRibbonPlacement meetingRibbonPlacement({
  required TargetPlatform platform,
  required bool isWeb,
  required double width,
}) {
  if (isWeb) {
    return width >= kMeetingRibbonWideWidth
        ? MeetingRibbonPlacement.corner
        : MeetingRibbonPlacement.top;
  }
  switch (platform) {
    case TargetPlatform.iOS:
      return MeetingRibbonPlacement.top;
    case TargetPlatform.android:
      return MeetingRibbonPlacement.bottom;
    default:
      return MeetingRibbonPlacement.corner;
  }
}

/// The ribbon itself, for the [MeetingRibbonPlacement.top] and
/// [MeetingRibbonPlacement.bottom] placements. The corner panel is the
/// floating call card.
///
/// Returns a [Positioned]: it lives in the app-wide live layer's `Stack`, and
/// must cover only its own strip so the app beneath stays usable.
class MeetingLiveRibbon extends StatelessWidget {
  const MeetingLiveRibbon({
    super.key,
    required this.placement,
    required this.startedAt,
    required this.inRoom,
    required this.mayEndForEveryone,
    required this.isEnding,
    required this.onReturn,
    required this.onEnd,
  });

  final MeetingRibbonPlacement placement;
  final DateTime? startedAt;
  final int inRoom;
  final bool mayEndForEveryone;
  final bool isEnding;
  final VoidCallback onReturn;
  final VoidCallback onEnd;

  /// Clearance above the Android bottom navigation, so the bar never sits
  /// on top of Home, Create, Messages and Discover.
  static const double androidNavClearance = 76;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.viewPaddingOf(context);
    final top = placement == MeetingRibbonPlacement.top;

    final bar = Material(
      color: const Color(0xF00B2A1F),
      elevation: 6,
      shape: top
          ? null
          : RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onReturn,
        child: Padding(
          padding: EdgeInsets.fromLTRB(14, top ? pad.top + 6 : 8, 6, 6),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _RibbonLabel(
                  startedAt: startedAt,
                  // The Android bar spends its width on End, as designed.
                  inRoom: top ? inRoom : null,
                ),
              ),
              TextButton(
                onPressed: onReturn,
                child: const Text(
                  'Return',
                  style: TextStyle(
                    color: Color(0xFF34D399),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (!top)
                TextButton(
                  onPressed: isEnding ? null : onEnd,
                  child: Text(
                    mayEndForEveryone ? 'End' : 'Leave',
                    style: const TextStyle(
                      color: Color(0xFFF87171),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (top) {
      return Positioned(left: 0, right: 0, top: 0, child: bar);
    }
    return Positioned(
      left: 10,
      right: 10,
      bottom: pad.bottom + androidNavClearance,
      child: bar,
    );
  }
}

/// "In meeting · m:ss · N in room", ticking on its own so the bar around it
/// is not rebuilt every second.
class _RibbonLabel extends StatefulWidget {
  const _RibbonLabel({required this.startedAt, required this.inRoom});

  final DateTime? startedAt;
  final int? inRoom;

  @override
  State<_RibbonLabel> createState() => _RibbonLabelState();
}

class _RibbonLabelState extends State<_RibbonLabel> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final startedAt = widget.startedAt;
    final parts = <String>[
      'In meeting',
      startedAt == null
          ? '--:--'
          : formatRecordingElapsed(DateTime.now().difference(startedAt)),
      if (widget.inRoom != null) '${widget.inRoom} in room',
    ];
    return Text(
      parts.join(' · '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        fontFeatures: [ui.FontFeature.tabularFigures()],
      ),
    );
  }
}
