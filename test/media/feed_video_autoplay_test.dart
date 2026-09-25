// Feed video autoplay — which video plays, and when none may.
//
// Founder direction 2026-09-25: videos in the public, member and institution
// feeds play silently while in view. These tests drive the real coordinator
// with real scrolling, a real pushed route and the real reduce-motion
// setting; only the video itself is a stand-in, because the test binding has
// no decoder.
import 'package:aura/core/media/aura_video_surface.dart';
import 'package:aura/core/media/feed_video_autoplay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pickAutoplayCandidate', () {
    const viewport = Rect.fromLTWH(0, 0, 400, 800);

    test('the video most in view plays', () {
      final pick = pickAutoplayCandidate([
        const Rect.fromLTWH(0, -150, 400, 200), // 25% visible
        const Rect.fromLTWH(0, 300, 400, 200), // fully visible
      ], viewport);
      expect(pick, 1);
    });

    test('below the threshold nothing plays', () {
      final pick = pickAutoplayCandidate([
        const Rect.fromLTWH(0, 700, 400, 200), // 50% visible
      ], viewport);
      expect(pick, isNull);
    });

    test('a tie goes to the one the reader reaches first', () {
      final pick = pickAutoplayCandidate([
        const Rect.fromLTWH(0, 500, 400, 200),
        const Rect.fromLTWH(0, 100, 400, 200),
      ], viewport);
      expect(pick, 1);
    });

    test('an off-screen or empty box never plays', () {
      expect(
        pickAutoplayCandidate([
          const Rect.fromLTWH(0, 900, 400, 200),
          Rect.zero,
        ], viewport),
        isNull,
      );
    });
  });

  // iOS call audio — 2026-09-25, TestFlight 1.5.0 (40): video good, no audio
  // either way. On iOS `mixWithOthers` re-sets the app's single AVAudioSession
  // category each time a player is created with it, which stops a live call's
  // audio unit. The feed must therefore pass NO options there.
  group('feed player options', () {
    test('iOS: none, so the shared audio session is never touched', () {
      expect(
        feedVideoPlayerOptions(
          inFeed: true,
          platform: TargetPlatform.iOS,
          isWeb: false,
        ),
        isNull,
      );
    });

    test('macOS: none either — the same AVAudioSession rules apply', () {
      expect(
        feedVideoPlayerOptions(
          inFeed: true,
          platform: TargetPlatform.macOS,
          isWeb: false,
        ),
        isNull,
      );
    });

    test('Android feed: mixes, so a muted video never takes audio focus', () {
      final options = feedVideoPlayerOptions(
        inFeed: true,
        platform: TargetPlatform.android,
        isWeb: false,
      );
      expect(options?.mixWithOthers, isTrue);
    });

    test('outside a feed, or on web: none', () {
      expect(
        feedVideoPlayerOptions(
          inFeed: false,
          platform: TargetPlatform.android,
          isWeb: false,
        ),
        isNull,
      );
      expect(
        feedVideoPlayerOptions(
          inFeed: true,
          platform: TargetPlatform.android,
          isWeb: true,
        ),
        isNull,
      );
    });
  });

  group('FeedVideoAutoplay', () {
    testWidgets('plays exactly one video: the one in view', (tester) async {
      final log = _Log();
      await tester.pumpWidget(_feed(log));
      await tester.pump();

      expect(log.playing, {0});
    });

    testWidgets('scrolling hands playback to the next video', (tester) async {
      final log = _Log();
      await tester.pumpWidget(_feed(log));
      await tester.pump();
      expect(log.playing, {0});

      await tester.drag(find.byType(ListView), const Offset(0, -700));
      await tester.pump();

      expect(log.playing.length, 1);
      expect(log.playing.single, isNot(0));
    });

    testWidgets('a route pushed over the feed stops it', (tester) async {
      final log = _Log();
      await tester.pumpWidget(_feed(log));
      await tester.pump();
      expect(log.playing, {0});

      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      nav.push(MaterialPageRoute<void>(builder: (_) => const Text('viewer')));
      await tester.pumpAndSettle();
      expect(log.playing, isEmpty);

      nav.pop();
      await tester.pumpAndSettle();
      expect(log.playing, {0});
    });

    testWidgets('a see-through route over the feed stops it too', (
      tester,
    ) async {
      // An opaque route also disables the tickers beneath it, which would
      // stop playback on its own. A translucent one (a dialog, a viewer
      // overlay) does not — only the route-is-current rule catches it.
      final log = _Log();
      await tester.pumpWidget(_feed(log));
      await tester.pump();
      expect(log.playing, {0});

      tester
          .state<NavigatorState>(find.byType(Navigator))
          .push(
            PageRouteBuilder<void>(
              opaque: false,
              pageBuilder: (_, __, ___) => const Text('overlay'),
            ),
          );
      await tester.pumpAndSettle();
      expect(log.playing, isEmpty);
    });

    testWidgets('reduce motion means no autoplay at all', (tester) async {
      final log = _Log();
      await tester.pumpWidget(_feed(log, disableAnimations: true));
      await tester.pump();

      expect(log.playing, isEmpty);
    });

    testWidgets('sound is one setting for the whole feed, off by default', (
      tester,
    ) async {
      final log = _Log();
      await tester.pumpWidget(_feed(log));
      await tester.pump();

      final scope = FeedVideoAutoplay.maybeOf(
        tester.element(find.byKey(const ValueKey('video-0'))),
      )!;
      expect(scope.muted.value, isTrue);
      scope.setMuted(false);
      expect(
        FeedVideoAutoplay.maybeOf(
          tester.element(find.byKey(const ValueKey('video-1'))),
        )!.muted.value,
        isFalse,
      );
    });

    testWidgets('a video outside any feed is never registered', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: _Probe())),
      );
      expect(
        FeedVideoAutoplay.maybeOf(tester.element(find.byType(_Probe))),
        isNull,
      );
    });
  });
}

class _Log {
  final Set<int> playing = <int>{};
}

Widget _feed(_Log log, {bool disableAnimations = false}) {
  return MaterialApp(
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(disableAnimations: disableAnimations),
        child: FeedVideoAutoplay(
          child: Scaffold(
            body: ListView(
              children: [
                for (var i = 0; i < 6; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 40),
                    child: _FakeVideo(
                      key: ValueKey('video-$i'),
                      index: i,
                      log: log,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _FakeVideo extends StatefulWidget {
  const _FakeVideo({super.key, required this.index, required this.log});

  final int index;
  final _Log log;

  @override
  State<_FakeVideo> createState() => _FakeVideoState();
}

class _FakeVideoState extends State<_FakeVideo>
    implements FeedAutoplayCandidate {
  FeedVideoAutoplayScope? _scope;

  @override
  BuildContext get candidateContext => context;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scope ??= FeedVideoAutoplay.maybeOf(context)?..register(this);
  }

  @override
  void setAutoplaying(bool on) {
    if (on) {
      widget.log.playing.add(widget.index);
    } else {
      widget.log.playing.remove(widget.index);
    }
  }

  @override
  void dispose() {
    _scope?.unregister(this);
    widget.log.playing.remove(widget.index);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 300, child: ColoredBox(color: Colors.black));
}

class _Probe extends StatelessWidget {
  const _Probe();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
