import 'package:aura/core/ui/aura_notice.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Aura notice, per platform (founder-approved spec, 21 Oct 2026).
void main() {
  late BuildContext bodyContext;

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(400, 800),
    bool bottomNav = true,
    bool composerBar = false,
    EdgeInsets viewInsets = EdgeInsets.zero,
    EdgeInsets padding = EdgeInsets.zero,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: auraScaffoldMessengerKey,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            viewInsets: viewInsets,
            padding: padding,
            viewPadding: padding,
          ),
          child: AuraNoticeHost(child: child!),
        ),
        home: Scaffold(
          bottomNavigationBar: bottomNav
              ? const SizedBox(key: Key('nav'), height: 80)
              : null,
          body: Builder(
            builder: (context) {
              bodyContext = context;
              return Column(
                children: [
                  const Expanded(child: SizedBox.expand()),
                  if (composerBar)
                    const AuraNoticeLift(
                      child: SizedBox(key: Key('composer'), height: 64),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  tearDown(() {
    AuraNotice.debugIsWebOverride = null;
    AuraNotice.debugAndroidSdkOverride = null;
    AuraNoticeLift.debugReset();
  });

  Rect cardRect(WidgetTester tester) {
    final snack = find.byType(SnackBar);
    if (snack.evaluate().isNotEmpty) {
      return tester.getRect(
        find.descendant(of: snack, matching: find.byType(Material)).first,
      );
    }
    return tester.getRect(find.byKey(const ValueKey('aura-notice')));
  }

  group('Android: Material snackbar at the bottom', () {
    testWidgets(
      'sits above the bottom navigation',
      (tester) async {
        await pump(tester);
        AuraNotice.done(bodyContext, 'Saved.');
        await tester.pumpAndSettle();
        expect(find.text('Saved.'), findsOneWidget);
        expect(
          cardRect(tester).bottom,
          lessThanOrEqualTo(tester.getRect(find.byKey(const Key('nav'))).top),
        );
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets(
      'sits above a registered composer bar',
      (tester) async {
        await pump(tester, composerBar: true);
        AuraNotice.problem(
          bodyContext,
          'Your message was not sent. Try again.',
        );
        await tester.pumpAndSettle();
        expect(
          cardRect(tester).bottom,
          lessThanOrEqualTo(
            tester.getRect(find.byKey(const Key('composer'))).top,
          ),
        );
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets(
      'sits above the keyboard',
      (tester) async {
        await pump(
          tester,
          bottomNav: false,
          viewInsets: const EdgeInsets.only(bottom: 300),
        );
        AuraNotice.info(bodyContext, 'Wait for the attachments to finish.');
        await tester.pumpAndSettle();
        expect(cardRect(tester).bottom, lessThanOrEqualTo(800 - 300));
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets(
      '16 px gutters on a phone; at most 560 px, centred, when wide',
      (tester) async {
        await pump(tester);
        AuraNotice.done(bodyContext, 'Saved.');
        await tester.pumpAndSettle();
        final phone = cardRect(tester);
        expect(phone.left, moreOrLessEquals(16, epsilon: 1));
        expect(phone.right, moreOrLessEquals(400 - 16, epsilon: 1));

        await pump(tester, size: const Size(1200, 800));
        AuraNotice.done(bodyContext, 'Saved again.');
        await tester.pumpAndSettle();
        final wide = cardRect(tester);
        expect(wide.width, lessThanOrEqualTo(560.5));
        expect(wide.center.dx, moreOrLessEquals(600, epsilon: 1));
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets(
      'a new notice replaces the old one',
      (tester) async {
        await pump(tester);
        AuraNotice.done(bodyContext, 'First.');
        await tester.pumpAndSettle();
        AuraNotice.done(bodyContext, 'Second.');
        await tester.pumpAndSettle();
        expect(find.text('First.'), findsNothing);
        expect(find.text('Second.'), findsOneWidget);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets(
      'done leaves after 4 s; a problem stays 6 s and carries ×',
      (tester) async {
        await pump(tester);
        AuraNotice.done(bodyContext, 'Saved.');
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.close), findsNothing);
        await tester.pump(const Duration(milliseconds: 4100));
        await tester.pumpAndSettle();
        expect(find.text('Saved.'), findsNothing);

        AuraNotice.problem(bodyContext, 'It was not saved. Try again.');
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.close), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 4100));
        expect(find.text('It was not saved. Try again.'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 2100));
        await tester.pumpAndSettle();
        expect(find.text('It was not saved. Try again.'), findsNothing);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets(
      'swiped sideways, it goes',
      (tester) async {
        await pump(tester);
        AuraNotice.done(bodyContext, 'Saved.');
        await tester.pumpAndSettle();
        await tester.drag(find.text('Saved.'), const Offset(400, 0));
        await tester.pumpAndSettle();
        expect(find.text('Saved.'), findsNothing);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets(
      'the one action stays and works',
      (tester) async {
        var undone = false;
        await pump(tester);
        AuraNotice.done(
          bodyContext,
          'Archived.',
          action: AuraNoticeAction(
            label: 'Undo',
            onPressed: () => undone = true,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Undo'));
        expect(undone, isTrue);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets(
      'ends as a sentence does',
      (tester) async {
        await pump(tester);
        AuraNotice.done(bodyContext, 'Link copied');
        await tester.pumpAndSettle();
        expect(find.text('Link copied.'), findsOneWidget);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets(
      'Android 13+ confirms a copy itself, so Aura says nothing',
      (tester) async {
        await pump(tester);
        AuraNotice.debugAndroidSdkOverride = 33;
        AuraNotice.copied(bodyContext, 'Link copied.');
        await tester.pumpAndSettle();
        expect(find.text('Link copied.'), findsNothing);

        AuraNotice.debugAndroidSdkOverride = 32;
        AuraNotice.copied(bodyContext, 'Link copied.');
        await tester.pumpAndSettle();
        expect(find.text('Link copied.'), findsOneWidget);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  });

  group('iOS: banner at the top', () {
    testWidgets(
      'drops in below the notch, clear of the tab bar',
      (tester) async {
        await pump(tester, padding: const EdgeInsets.only(top: 47, bottom: 34));
        AuraNotice.done(bodyContext, 'Saved.');
        await tester.pumpAndSettle();
        expect(find.byType(SnackBar), findsNothing);
        final rect = cardRect(tester);
        expect(rect.top, greaterThanOrEqualTo(47));
        expect(rect.bottom, lessThan(400));
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets(
      'swiped up, it goes',
      (tester) async {
        await pump(tester, padding: const EdgeInsets.only(top: 47));
        AuraNotice.info(bodyContext, 'Heads up.');
        await tester.pumpAndSettle();
        await tester.drag(find.text('Heads up.'), const Offset(0, -300));
        await tester.pumpAndSettle();
        expect(find.text('Heads up.'), findsNothing);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets(
      'a problem gives a light haptic',
      (tester) async {
        final calls = <MethodCall>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            calls.add(call);
            return null;
          },
        );
        await pump(tester);
        AuraNotice.problem(bodyContext, 'It was not sent. Try again.');
        await tester.pumpAndSettle();
        expect(
          calls.where(
            (c) =>
                c.method == 'HapticFeedback.vibrate' &&
                c.arguments == 'HapticFeedbackType.lightImpact',
          ),
          isNotEmpty,
        );
        AuraNotice.done(bodyContext, 'Saved.');
        await tester.pumpAndSettle();
        expect(
          calls.where((c) => c.method == 'HapticFeedback.vibrate').length,
          1,
        );
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets(
      'a new banner replaces the old one',
      (tester) async {
        await pump(tester);
        AuraNotice.done(bodyContext, 'First.');
        await tester.pumpAndSettle();
        AuraNotice.done(bodyContext, 'Second.');
        await tester.pumpAndSettle();
        expect(find.text('First.'), findsNothing);
        expect(find.text('Second.'), findsOneWidget);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  });

  group('Windows: toast in the bottom-right corner', () {
    testWidgets(
      'bottom-right, 360–420 px, × always',
      (tester) async {
        await pump(tester, size: const Size(1400, 900), bottomNav: false);
        AuraNotice.done(bodyContext, 'Saved.');
        await tester.pumpAndSettle();
        final rect = cardRect(tester);
        expect(rect.right, moreOrLessEquals(1400 - 16, epsilon: 1));
        expect(rect.bottom, lessThanOrEqualTo(900 - 16));
        expect(rect.width, inInclusiveRange(360, 420));
        expect(find.byKey(const ValueKey('aura-notice-close')), findsOneWidget);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );

    testWidgets(
      'Esc dismisses it',
      (tester) async {
        await pump(tester, size: const Size(1400, 900), bottomNav: false);
        AuraNotice.info(bodyContext, 'Heads up.');
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('Heads up.'), findsNothing);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );

    testWidgets(
      'hover pauses the timer',
      (tester) async {
        await pump(tester, size: const Size(1400, 900), bottomNav: false);
        AuraNotice.done(bodyContext, 'Saved.');
        await tester.pumpAndSettle();
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        addTearDown(mouse.removePointer);
        await mouse.moveTo(tester.getCenter(find.text('Saved.')));
        await tester.pump(const Duration(seconds: 10));
        expect(find.text('Saved.'), findsOneWidget);
        await mouse.moveTo(Offset.zero);
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        expect(find.text('Saved.'), findsNothing);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );

    testWidgets(
      'the action is reachable by keyboard',
      (tester) async {
        var viewed = false;
        await pump(tester, size: const Size(1400, 900), bottomNav: false);
        AuraNotice.info(
          bodyContext,
          'Scheduled.',
          action: AuraNoticeAction(
            label: 'View',
            onPressed: () => viewed = true,
          ),
        );
        await tester.pumpAndSettle();
        final button = find.widgetWithText(TextButton, 'View');
        expect(button, findsOneWidget);
        Focus.of(tester.element(find.text('View'))).requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(viewed, isTrue);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  });

  group('Web', () {
    setUp(() => AuraNotice.debugIsWebOverride = true);

    testWidgets('a phone-width browser behaves like Android', (tester) async {
      await pump(tester, size: const Size(400, 800));
      AuraNotice.done(bodyContext, 'Saved.');
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('a desktop browser: bottom-left card, at most 420 px, ×', (
      tester,
    ) async {
      await pump(tester, size: const Size(1400, 900), bottomNav: false);
      AuraNotice.done(bodyContext, 'Saved.');
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      final rect = cardRect(tester);
      expect(rect.left, moreOrLessEquals(16, epsilon: 1));
      expect(rect.width, lessThanOrEqualTo(420.5));
      expect(find.byKey(const ValueKey('aura-notice-close')), findsOneWidget);
    });

    testWidgets('hover pauses it there too', (tester) async {
      await pump(tester, size: const Size(1400, 900), bottomNav: false);
      AuraNotice.done(bodyContext, 'Saved.');
      await tester.pumpAndSettle();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.text('Saved.')));
      await tester.pump(const Duration(seconds: 10));
      expect(find.text('Saved.'), findsOneWidget);
    });
  });

  testWidgets(
    'banner and corner notices are announced to screen readers',
    (tester) async {
      final announced = <Object?>[];
      tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(SystemChannels.accessibility, (
            message,
          ) async {
            announced.add(message);
            return null;
          });
      await pump(tester, size: const Size(1400, 900), bottomNav: false);
      AuraNotice.done(bodyContext, 'Saved.');
      await tester.pumpAndSettle();
      expect(announced.toString(), contains('Saved.'));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
