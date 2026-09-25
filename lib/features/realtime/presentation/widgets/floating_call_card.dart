/// THE MINIMISED CALL CARD.
///
/// Founder, 2026-09-24: *"pip is odd and ugly its same for the audio and
/// video"*, and then: *"it was thoughtless design in early stage"*. So this is
/// a replacement rather than a repair.
///
/// The rules it obeys — which composition a call takes, how big it is, and how
/// big a control has to be for a thumb — live in `floating_call_layout.dart`,
/// where they can be asserted without a renderer. The card itself takes its
/// picture as a WIDGET so that both compositions can be painted and LOOKED AT,
/// the same structure the meetings stage was rebuilt with hours earlier.
library;

import 'dart:async';
import 'dart:ui' as ui show FontFeature;

import 'package:flutter/material.dart';

import '../../../../core/media/recording_time.dart';
import '../../../../core/ui/aura_platform_components.dart';
import '../../../../core/ui/aura_radius.dart';
import '../../../../core/ui/aura_space.dart';
import '../../../../core/ui/aura_surface.dart';
import '../../../../core/ui/aura_text.dart';
import '../../domain/realtime_models.dart';
import 'floating_call_layout.dart';

class FloatingCallCard extends StatelessWidget {
  const FloatingCallCard({
    super.key,
    required this.composition,
    required this.isVideo,
    required this.micOn,
    required this.cameraOn,
    required this.participants,
    required this.startedAt,
    required this.joinedHere,
    required this.onReturn,
    required this.onEnd,
    required this.isEnding,
    this.mayEndForEveryone = true,
    required this.onPanUpdate,
    this.remoteName,
    this.picture,
  });

  final FloatingCallComposition composition;
  final bool isVideo;
  final bool micOn;
  final bool cameraOn;
  final List<RealtimeParticipant> participants;
  final DateTime? startedAt;

  /// True when this tab owns the call's media and is joined to it; false for
  /// the passive view of a call running in another tab. Named for what it is:
  /// it was `joinedHere`, which read as a role and is not one.
  final bool joinedHere;
  final VoidCallback? onReturn;
  final VoidCallback? onEnd;
  final bool isEnding;

  /// Whether this person may end the call FOR EVERYONE, as opposed to leaving
  /// it. See `mayEndForEveryone` — the host always may; in a two-person call
  /// either side may, because a telephone has never worked otherwise; in a
  /// group call or a meeting only the host may, and everyone else leaves.
  ///
  /// This changes the word and the icon, not the handler: `onEnd` is the same
  /// act, and the server applies the same rule. A capability, not a role — it
  /// was named `mayEndForEveryone`, though a non-host in a two-person call may end it.
  final bool mayEndForEveryone;
  final String? remoteName;

  /// The other person, already built.
  ///
  /// A WIDGET, not a renderer, so the compositions can be painted in a test —
  /// and so this file does not need to know that WebRTC exists. Null means
  /// there is nothing to look at, and [composition] will be
  /// [FloatingCallComposition.bar].
  final Widget? picture;

  /// Applied to the card's BODY only, never to the controls — see the note at
  /// the call site.
  final GestureDragUpdateCallback onPanUpdate;

  static const Color _surface = Color(0xFF0F1E33);

  @override
  Widget build(BuildContext context) {
    final card = floatingCallSize(composition);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AuraRadius.xl),
        boxShadow: const [
          // ONE shadow. The old card stacked a 28px black drop and a 40px blue
          // spread bloom, which is most of what read as "ugly" at this size.
          BoxShadow(
            color: Color(0x99000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      // THE CARD IS MOUNTED OUTSIDE ANY MATERIAL, AND TEXT NOTICED.
      //
      // `AuraIncomingLiveLayer` mounts this in a bare `Stack` beside the app's
      // child — there is no `Scaffold` and no `Material` above it. Flutter
      // answers that with `DefaultTextStyle.fallback()`, whose decoration is a
      // YELLOW DOUBLE UNDERLINE, and every `Text` here inherits it: our styles
      // set colour and weight and never `decoration`, so the fallback's wins.
      //
      // Founder-observed on a live call, 2026-09-24: the elapsed time reading
      // `02:39` underlined in yellow over the video. It is very likely part of
      // what "odd and ugly" meant about the old card too — the same mount, the
      // same missing ancestor.
      //
      // `MaterialType.transparency` supplies the theme's text style and ink
      // without painting anything, so nothing about the card's appearance
      // changes except the decoration that should never have been there.
      //
      // Worth noting why the frames test missed it: it renders the card inside
      // a `Scaffold`, which PROVIDES a Material. The test was kinder than the
      // real mount — so it now renders one case without one.
      child: Material(
        type: MaterialType.transparency,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AuraRadius.xl),
          child: SizedBox(
            width: card.width,
            height: card.height,
            child: floatingCallShowsPicture(composition)
                ? _buildPicture(context)
                : _buildBar(context),
          ),
        ),
      ),
    );
  }

  // ── The picture composition ────────────────────────────────────────────────

  /// The card IS the other person, framed 16:9 like a face on the meetings
  /// stage, with the call's state and controls laid over the bottom of it.
  Widget _buildPicture(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // The picture is also the drag surface. It carries no tap handler: a
        // tap and a pan on one surface is precisely the ambiguity that made
        // Return dead on Android, and the controls below are unambiguous.
        GestureDetector(
          onPanUpdate: onPanUpdate,
          behavior: HitTestBehavior.opaque,
          child: MouseRegion(
            cursor: SystemMouseCursors.move,
            child: ColoredBox(color: Colors.black, child: picture),
          ),
        ),

        // Elapsed time, top-left, on its own small scrim so it stays legible
        // over a bright frame.
        Positioned(
          top: AuraSpace.s8,
          left: AuraSpace.s8,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AuraSpace.s8,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: const Color(0x8C000000),
              borderRadius: BorderRadius.circular(AuraRadius.md),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LiveDot(active: joinedHere),
                const SizedBox(width: AuraSpace.s6),
                _DurationDisplay(startedAt: startedAt),
              ],
            ),
          ),
        ),

        // YOUR OWN STATE, ONLY WHEN IT IS WORTH SAYING.
        //
        // The old card showed a mic dot and a camera dot at all times, green
        // for on — two more pieces of furniture reporting the unremarkable. A
        // badge appears here only when something is OFF, which is the only
        // case where the viewer needs telling.
        if (joinedHere && (!micOn || (isVideo && !cameraOn)))
          Positioned(
            top: AuraSpace.s8,
            right: AuraSpace.s8,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!micOn) const _OffBadge(icon: Icons.mic_off_rounded),
                if (isVideo && !cameraOn) ...[
                  if (!micOn) const SizedBox(width: AuraSpace.s4),
                  const _OffBadge(icon: Icons.videocam_off_rounded),
                ],
              ],
            ),
          ),

        // The controls, over a gradient so they read against any frame.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: kFloatingCallScrimHeight,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00000000), Color(0xC7000000)],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AuraSpace.s6),
              child: Row(
                children: [
                  if (remoteName != null)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: AuraSpace.s6),
                        child: Text(
                          remoteName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AuraText.small.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  _buildControls(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── The bar composition ────────────────────────────────────────────────────

  /// One row. No picture area, because there is no picture.
  Widget _buildBar(BuildContext context) {
    final label =
        remoteName ??
        (joinedHere
            ? (isVideo ? 'Video call' : 'Audio call')
            : 'Call in another tab');

    return ColoredBox(
      color: _surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AuraSpace.s10),
        child: Row(
          children: [
            // The informational half is the drag surface. The controls are not.
            Expanded(
              child: GestureDetector(
                onPanUpdate: onPanUpdate,
                behavior: HitTestBehavior.opaque,
                child: MouseRegion(
                  cursor: SystemMouseCursors.move,
                  child: Row(
                    children: [
                      if (participants.isNotEmpty) ...[
                        _MiniAvatarStack(participants: participants),
                        const SizedBox(width: AuraSpace.s8),
                      ],
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AuraText.small.copyWith(
                                color: AuraSurface.ink,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Row(
                              children: [
                                _LiveDot(active: joinedHere),
                                const SizedBox(width: AuraSpace.s6),
                                _DurationDisplay(startedAt: startedAt),
                                if (joinedHere && !micOn) ...[
                                  const SizedBox(width: AuraSpace.s6),
                                  const _OffBadge(
                                    icon: Icons.mic_off_rounded,
                                    compact: true,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _buildControls(),
          ],
        ),
      ),
    );
  }

  // ── Controls, identical in both compositions ───────────────────────────────

  Widget _buildControls() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onReturn != null)
          _RoundControl(
            icon: Icons.open_in_full_rounded,
            semanticLabel: 'Return to call',
            accent: true,
            onTap: onReturn,
          ),
        if (onEnd != null)
          _RoundControl(
            icon: mayEndForEveryone
                ? Icons.call_end_rounded
                : Icons.logout_rounded,
            semanticLabel: isEnding
                ? (mayEndForEveryone ? 'Ending call' : 'Leaving call')
                : (mayEndForEveryone ? 'End call' : 'Leave call'),
            danger: true,
            onTap: isEnding ? null : onEnd,
          ),
      ],
    );
  }
}

class _OffBadge extends StatelessWidget {
  const _OffBadge({required this.icon, this.compact = false});

  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 16.0 : 22.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AuraSurface.coRose.withValues(alpha: 0.9),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: compact ? 10 : 13, color: Colors.white),
    );
  }
}

class _RoundControl extends StatelessWidget {
  const _RoundControl({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
    this.accent = false,
    this.danger = false,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onTap;
  final bool accent;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final Color bg;
    final Color fg;
    if (danger) {
      bg = AuraSurface.coRose.withValues(alpha: 0.22);
      fg = AuraSurface.coRose;
    } else if (accent) {
      bg = AuraSurface.accentSoft;
      fg = AuraSurface.accentText;
    } else {
      bg = AuraSurface.card;
      fg = AuraSurface.muted;
    }

    return Semantics(
      button: true,
      enabled: !disabled,
      label: semanticLabel,
      // NO TOOLTIP HERE, DELIBERATELY.
      //
      // `Tooltip` requires an `Overlay` ancestor, and this card is mounted in
      // a bare `Stack` by `AuraIncomingLiveLayer` — there is none. A tooltip
      // therefore throws while BUILDING, and the founder saw exactly that on a
      // live call: hovering Return replaced the control with an error.
      //
      // `Semantics` above already carries the label for anyone using a screen
      // reader, which is what the tooltip was there for. The nicety is not
      // worth a control that breaks when you point at it.
      child: MouseRegion(
        cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          // A TRANSPARENT MISS IS STILL A MISS. Without this, only the
          // painted disc answers a tap and the slack around it — which is
          // the entire point of the 48px target — would swallow the press.
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: kFloatingControlTapTarget,
            height: kFloatingControlTapTarget,
            child: Center(
              child: Opacity(
                opacity: disabled ? 0.5 : 1.0,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                  child: Icon(icon, size: 16, color: fg),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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

class _DurationDisplay extends StatefulWidget {
  const _DurationDisplay({required this.startedAt});
  final DateTime? startedAt;

  @override
  State<_DurationDisplay> createState() => _DurationDisplayState();
}

class _DurationDisplayState extends State<_DurationDisplay> {
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
    // One clock grammar for elapsed time: the same `m:ss` / `h:mm:ss` a voice
    // note shows while recording. This card used to declare its own
    // zero-padded formatter, which the C0 temporal gate forbids on a screen.
    final startedAt = widget.startedAt;
    return Text(
      startedAt == null
          ? '--:--'
          : formatRecordingElapsed(DateTime.now().difference(startedAt)),
      style: AuraText.small.copyWith(
        color: AuraSurface.muted,
        fontFeatures: const [ui.FontFeature.tabularFigures()],
      ),
    );
  }
}
