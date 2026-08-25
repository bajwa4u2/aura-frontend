import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// POP THE DIALOG, NOT THE SCREEN.
///
/// Measured in production on 2026-08-25 while cleaning up the founder-authorized
/// certification meeting. Three attempts, each the same: the confirmation dialog
/// stayed open, `POST /meetings/:id/cancel` was never issued — confirmed against
/// a working network control that captured the app's own presence pings — and
/// the meeting stayed SCHEDULED. **Cancelling a meeting was not possible from
/// the released client.**
///
/// The cause was one character. The dialog builder discarded its own context —
/// `builder: (_) => AlertDialog(...)` — so both buttons called `Navigator.pop`
/// with the *screen's* context. `showDialog` pushes onto the ROOT navigator,
/// while the meeting screen lives inside go_router's SHELL navigator, so the
/// two contexts resolve to different `Navigator`s: the buttons popped the
/// meeting route out from under the dialog instead of closing it.
///
/// This test reproduces the topology rather than the screen, because the
/// topology is the defect: a dialog opened on the root navigator, from a page
/// that sits inside a nested one.
void main() {
  /// A root navigator with a nested one inside it, which is what a go_router
  /// ShellRoute produces.
  Future<bool?> runDialog(
    WidgetTester tester, {
    required bool useDialogContext,
  }) async {
    bool? result;
    final nestedKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        home: Navigator(
          key: nestedKey,
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (pageContext) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await showDialog<bool>(
                      context: pageContext,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Cancel meeting?'),
                        actions: [
                          FilledButton(
                            onPressed: () => Navigator.pop(
                              useDialogContext ? dialogContext : pageContext,
                              true,
                            ),
                            child: const Text('Cancel meeting'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel meeting?'), findsOneWidget,
        reason: 'the dialog did not open');

    await tester.tap(find.widgetWithText(FilledButton, 'Cancel meeting'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('the screen context does NOT close the dialog — the defect',
      (tester) async {
    final result = await runDialog(tester, useDialogContext: false);

    // This is what production did: the dialog is still on screen and the
    // future never completed, so the caller never reached the cancel request.
    expect(find.text('Cancel meeting?'), findsOneWidget,
        reason: 'if this now closes, the topology no longer reproduces the '
            'defect and this test has stopped being evidence');
    expect(result, isNull);
  });

  testWidgets('the dialog context closes it and returns the answer',
      (tester) async {
    final result = await runDialog(tester, useDialogContext: true);

    expect(find.text('Cancel meeting?'), findsNothing);
    expect(result, isTrue,
        reason: 'the confirmation never reached the caller, so the meeting '
            'would never be cancelled');
  });
}
