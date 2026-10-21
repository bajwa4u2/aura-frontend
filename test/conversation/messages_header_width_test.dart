import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/conversation/data/conversations_repository.dart';
import 'package:aura/features/conversation/presentation/conversation_identity.dart';
import 'package:aura/features/conversation/presentation/messages_screen.dart';

/// The Messages title broke inside the word on a phone, "Message" / "s",
/// because the labelled New conversation button took its width first
/// (Galaxy S24+, 21 Oct 2026). Where both do not fit on one line the button
/// goes below; the title is always one line.
void main() {
  Future<void> pump(WidgetTester tester, Size size, {double text = 1}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        conversationsListProvider.overrideWith((ref) async => const []),
        archivedConversationsProvider.overrideWith((ref) async => const []),
        pendingInvitationsProvider.overrideWith((ref) async => const []),
        myUserIdProvider.overrideWithValue('me'),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(text)),
          child: child!,
        ),
        home: const Scaffold(body: MessagesScreen()),
      ),
    ));
    await tester.pump();
  }

  double titleLineCount(WidgetTester tester) {
    final title = tester.renderObject<RenderParagraph>(find.text('Messages'));
    return title.size.height /
        title.getFullHeightForCaret(const TextPosition(offset: 0));
  }

  for (final (size, text) in const [
    (Size(360, 780), 1.0),
    (Size(412, 915), 1.0),
    (Size(412, 915), 1.6),
    (Size(1280, 800), 1.0),
  ]) {
    testWidgets('title stays one line at ${size.width.toInt()}px, text x$text',
        (tester) async {
      await pump(tester, size, text: text);
      // The test font draws every glyph a full em wide, so the labelled
      // button itself can overrun at phone widths here (not with real fonts).
      // That is not what this test is about; the title is.
      tester.takeException();
      expect(titleLineCount(tester), lessThan(1.5));
      expect(find.text('New conversation'), findsOneWidget);

      final title = tester.getRect(find.text('Messages'));
      final button = tester.getRect(find.text('New conversation'));
      if (size.width < 520 * text) {
        expect(button.top, greaterThan(title.bottom));
      } else {
        expect(button.center.dy, closeTo(title.center.dy, title.height));
      }
    });
  }
}
