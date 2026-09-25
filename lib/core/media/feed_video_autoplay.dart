/// FEED VIDEO AUTOPLAY — one silent video at a time, the one most in view.
///
/// Founder direction 2026-09-25: in the public, member and institution feeds
/// a video should play where it sits instead of asking for a tap to open a
/// viewer and a second tap to start it. This is the feed half; the viewer now
/// starts on open (`aura_media_viewer.dart`).
///
/// The rules, and why each exists:
///
///   * SILENT UNTIL ASKED. A browser refuses sound nobody asked for, and a
///     feed is read, not listened to. The speaker control on a playing video
///     turns sound on for the whole feed until it is turned off again; the
///     viewer — one tap away — always plays with sound.
///   * ONE AT A TIME. Several moving pictures compete for the eye; the card
///     most in view plays and every other one rests on its first frame.
///   * ONLY WHILE SEEN. At least [kFeedAutoplayVisibleFraction] of the video
///     must be on screen, the feed's route must be the current one, its
///     branch must be the visible one, and the app must be in the foreground.
///   * NEVER FOR SOMEONE WHO ASKED FOR STILLNESS. The platform's reduce-motion
///     setting turns it off entirely.
///
/// A scope wraps a feed. Video surfaces that hand off to the viewer find the
/// nearest scope and register themselves; surfaces outside any scope behave
/// exactly as they always have.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// How much of a video must be on screen before it may play.
const double kFeedAutoplayVisibleFraction = 0.6;

/// A video surface that a [FeedVideoAutoplay] scope may start and stop.
abstract class FeedAutoplayCandidate {
  /// The element whose render box is measured against the viewport.
  BuildContext get candidateContext;

  /// Start silently (true) or come to rest (false).
  void setAutoplaying(bool on);
}

/// Which of [rects] should play inside [viewport], or null for none.
///
/// Pure so the choice is testable without a platform: the largest visible
/// fraction at or above [minFraction] wins, and a tie goes to the one nearer
/// the top — the one the reader reaches first.
int? pickAutoplayCandidate(
  List<Rect> rects,
  Rect viewport, {
  double minFraction = kFeedAutoplayVisibleFraction,
}) {
  int? best;
  var bestFraction = 0.0;
  for (var i = 0; i < rects.length; i++) {
    final rect = rects[i];
    final area = rect.width * rect.height;
    if (area <= 0) continue;
    final seen = rect.intersect(viewport);
    if (seen.width <= 0 || seen.height <= 0) continue;
    final fraction = (seen.width * seen.height) / area;
    if (fraction < minFraction) continue;
    final better =
        best == null ||
        fraction > bestFraction + 0.001 ||
        ((fraction - bestFraction).abs() <= 0.001 &&
            rect.top < rects[best].top);
    if (better) {
      best = i;
      bestFraction = fraction;
    }
  }
  return best;
}

/// Marks a subtree as a feed whose videos play silently while in view.
class FeedVideoAutoplay extends StatefulWidget {
  const FeedVideoAutoplay({super.key, required this.child});

  final Widget child;

  /// The nearest scope, or null where videos keep their tap-to-open behaviour.
  static FeedVideoAutoplayScope? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<_FeedVideoAutoplayState>();

  @override
  State<FeedVideoAutoplay> createState() => _FeedVideoAutoplayState();
}

/// What a registered surface may ask of its scope.
abstract class FeedVideoAutoplayScope {
  void register(FeedAutoplayCandidate candidate);
  void unregister(FeedAutoplayCandidate candidate);

  /// Whether feed videos play silently. One setting for the feed, not one per
  /// card: a person who turned sound on expects the next video to have it too.
  ValueListenable<bool> get muted;
  void setMuted(bool muted);
}

class _FeedVideoAutoplayState extends State<FeedVideoAutoplay>
    implements FeedVideoAutoplayScope {
  final Set<FeedAutoplayCandidate> _candidates = <FeedAutoplayCandidate>{};
  FeedAutoplayCandidate? _active;
  bool _evaluationPending = false;
  final ValueNotifier<bool> _muted = ValueNotifier<bool>(true);

  @override
  ValueListenable<bool> get muted => _muted;

  @override
  void setMuted(bool muted) => _muted.value = muted;

  bool _tickerEnabled = true;
  bool _routeIsCurrent = true;
  bool _reduceMotion = false;
  bool _foreground = true;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        _foreground = state == AppLifecycleState.resumed;
        _schedule();
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Each of these is a dependency, so a route pushed over the feed, a shell
    // branch switched away, or the reduce-motion setting changing all arrive
    // here and are re-judged.
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    _routeIsCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _schedule();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _muted.dispose();
    _candidates.clear();
    _active = null;
    super.dispose();
  }

  @override
  void register(FeedAutoplayCandidate candidate) {
    _candidates.add(candidate);
    _schedule();
  }

  @override
  void unregister(FeedAutoplayCandidate candidate) {
    _candidates.remove(candidate);
    if (identical(_active, candidate)) _active = null;
    _schedule();
  }

  bool get _allowed =>
      _tickerEnabled && _routeIsCurrent && !_reduceMotion && _foreground;

  /// At most one evaluation per frame, however many scroll events arrive.
  void _schedule() {
    if (_evaluationPending || !mounted) return;
    _evaluationPending = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _evaluationPending = false;
      if (mounted) _evaluate();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _evaluate() {
    if (!_allowed) {
      _makeActive(null);
      return;
    }
    final own = context.findRenderObject();
    if (own is! RenderBox || !own.attached || !own.hasSize) {
      _makeActive(null);
      return;
    }
    final screen = Offset.zero & MediaQuery.sizeOf(context);
    final viewport = (own.localToGlobal(Offset.zero) & own.size).intersect(
      screen,
    );

    final candidates = <FeedAutoplayCandidate>[];
    final rects = <Rect>[];
    for (final candidate in _candidates) {
      final box = candidate.candidateContext.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      candidates.add(candidate);
      rects.add(box.localToGlobal(Offset.zero) & box.size);
    }
    final pick = pickAutoplayCandidate(rects, viewport);
    _makeActive(pick == null ? null : candidates[pick]);
  }

  void _makeActive(FeedAutoplayCandidate? next) {
    if (identical(next, _active)) return;
    _active?.setAutoplaying(false);
    _active = next;
    next?.setAutoplaying(true);
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (_) {
        _schedule();
        return false;
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (_) {
          _schedule();
          return false;
        },
        child: widget.child,
      ),
    );
  }
}
