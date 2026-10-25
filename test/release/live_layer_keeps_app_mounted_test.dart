import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A CALL STARTING MUST NOT REBUILD THE APP, 2026-10-24.
///
/// The live layer returned the app bare when idle and inside a Stack when
/// joined. The new parent remounted every screen: the meeting room mounted
/// twice on every join, and the PiP forgot its room had been shown, so a
/// host who stepped out of a meeting had no way back.
void main() {
  test('every return of the live layer carries the same keyed app', () {
    final src = File('lib/features/realtime/presentation/incoming_live_overlay.dart')
        .readAsStringSync();
    final start = src.indexOf('final app = KeyedSubtree(key: _appKey');
    expect(start, greaterThan(0));
    final end = src.indexOf('Widget build(BuildContext context)', start);
    final body = src.substring(start, end);
    expect(body.replaceFirst('child: widget.child', ''), isNot(contains('widget.child')));
  });

  test('the shown-room record outlives one PiP widget', () {
    final src = File('lib/features/realtime/presentation/widgets/floating_call_widget.dart')
        .readAsStringSync();
    expect(src, contains('static final Set<String> _surfaceShown'));
  });

  testWidgets('a keyed subtree moved under a Stack keeps its state',
      (tester) async {
    final key = GlobalKey();
    var inits = 0;
    Widget frame(bool joined) {
      final app = KeyedSubtree(key: key, child: _Counter(onInit: () => inits++));
      return MaterialApp(
        home: joined ? Stack(children: [app, const SizedBox()]) : app,
      );
    }

    await tester.pumpWidget(frame(false));
    await tester.pumpWidget(frame(true));
    await tester.pumpWidget(frame(false));
    expect(inits, 1);
  });
}

class _Counter extends StatefulWidget {
  const _Counter({required this.onInit});
  final VoidCallback onInit;
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}
