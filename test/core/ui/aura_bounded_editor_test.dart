import 'package:aura/core/ui/aura_bounded_editor.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// NESTED SCROLL, THE WAY A PERSON EXPECTS IT.
///
/// The small thing moves until it cannot, then the big thing does.
///
/// These are widget tests, and the defect that started all of this was NOT
/// reproducible in a widget test — so what is asserted here is the decision
/// logic and the wiring, not the browser outcome. The browser outcome is
/// proven separately against a pinned build, and this file does not claim it.
void main() {
  Future<(ScrollController outer, ScrollController inner)> pump(
    WidgetTester tester, {
    required String text,
  }) async {
    final controller = TextEditingController(text: text);
    addTearDown(controller.dispose);
    final outer = ScrollController();
    addTearDown(outer.dispose);
    late ScrollController inner;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 500,
            child: SingleChildScrollView(
              controller: outer,
              child: Column(
                children: [
                  const SizedBox(height: 200),
                  AuraBoundedEditor(
                    builder: (context, sc, ph) {
                      inner = sc;
                      return TextField(
                        controller: controller,
                        scrollController: sc,
                        scrollPhysics: ph,
                        minLines: 1,
                        maxLines: 3,
                      );
                    },
                  ),
                  const SizedBox(height: 900),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (outer, inner);
  }

  Future<void> wheelOverEditor(WidgetTester tester, double dy) async {
    final centre = tester.getCenter(find.byType(TextField));
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(centre));
    await tester.sendEventToBinding(pointer.scroll(Offset(0, dy)));
    await tester.pump();
  }

  testWidgets('the editor hands the wheel over when it has no range', (t) async {
    // An empty composer has nothing of its own to scroll, so the page moves.
    final (outer, inner) = await pump(t, text: '');
    expect(inner.position.maxScrollExtent, 0);

    final before = outer.offset;
    await wheelOverEditor(t, 120);
    expect(outer.offset, greaterThan(before),
        reason: 'an editor with nothing to scroll must not trap the page');
  });

  testWidgets('the editor consumes while it has room', (t) async {
    final (outer, inner) = await pump(t, text: List.filled(40, 'line').join('\n'));
    expect(inner.position.maxScrollExtent, greaterThan(0));

    final outerBefore = outer.offset;
    await wheelOverEditor(t, 60);

    expect(inner.offset, greaterThan(0), reason: 'the editor should have moved');
    expect(outer.offset, outerBefore,
        reason: 'and the page must NOT have moved at the same time');
  });

  testWidgets('at the internal bottom, further down-scroll reaches the page', (t) async {
    final (outer, inner) = await pump(t, text: List.filled(40, 'line').join('\n'));
    inner.jumpTo(inner.position.maxScrollExtent);
    await t.pump();

    final outerBefore = outer.offset;
    await wheelOverEditor(t, 120);

    expect(inner.offset, inner.position.maxScrollExtent,
        reason: 'the editor had nowhere left to go');
    expect(outer.offset, greaterThan(outerBefore),
        reason: 'so the page continues from the boundary');
  });

  testWidgets('at the internal top, up-scroll reaches the page', (t) async {
    final (outer, inner) = await pump(t, text: List.filled(40, 'line').join('\n'));
    outer.jumpTo(150);
    inner.jumpTo(0);
    await t.pump();

    final outerBefore = outer.offset;
    await wheelOverEditor(t, -120);

    expect(inner.offset, 0);
    expect(outer.offset, lessThan(outerBefore),
        reason: 'upward movement continues past the editor top');
  });

  testWidgets('one party per event — never both', (t) async {
    // Double-scroll is the classic failure of hand-rolled nesting: the child
    // moves AND the parent moves for a single notch.
    final (outer, inner) = await pump(t, text: List.filled(40, 'line').join('\n'));
    final o0 = outer.offset;
    final i0 = inner.offset;
    await wheelOverEditor(t, 60);

    final movedInner = inner.offset != i0;
    final movedOuter = outer.offset != o0;
    expect(movedInner && movedOuter, isFalse,
        reason: 'a single notch moved both the editor and the page');
  });

  testWidgets('typing and selection still work through the wrapper', (t) async {
    final (_, _) = await pump(t, text: '');
    await t.tap(find.byType(TextField));
    await t.pump();
    await t.enterText(find.byType(TextField), 'hello there');
    await t.pump();
    expect(find.text('hello there'), findsOneWidget);
  });
}
