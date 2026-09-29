import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/public/widgets/mention_text.dart';

/// A post reads in the direction of its own first letter, whatever the app's
/// language (founder, 2026-09-29: published Urdu was laid out left to right,
/// "looks scattered"; the fix must hold for Arabic and Persian too).
void main() {
  const samples = {
    'Arabic': ('مرحبا بالجميع، كيف حالكم اليوم؟', TextDirection.rtl),
    'Persian': ('سلام به همه، امروز حال شما چطور است؟', TextDirection.rtl),
    'Urdu': ('چھوٹی چھوٹی خوشیاں ہی اصل خوشیاں ہیں۔ 😄', TextDirection.rtl),
    'Urdu first, then English': ('آج موسم اچھا ہے — what a day', TextDirection.rtl),
    'Hebrew': ('שלום לכולם', TextDirection.rtl),
    'English': ('Hello everyone — آج', TextDirection.ltr),
  };

  Future<RichText> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SizedBox(width: 600, child: child)),
    ));
    return tester.widget<RichText>(find.byType(RichText).first);
  }

  for (final entry in samples.entries) {
    final (text, expected) = entry.value;

    testWidgets('${entry.key} reads ${expected.name} in a post', (tester) async {
      final rich = await pump(tester, TagStyledText(text));
      expect(rich.textDirection, expected);
      expect(rich.textAlign, TextAlign.start);

      // A right-to-left post starts at the right edge of its space.
      final box = tester.getRect(find.byType(RichText).first);
      if (expected == TextDirection.rtl) {
        expect(box.right, closeTo(600, 1));
      } else {
        expect(box.left, closeTo(0, 1));
      }
    });

    testWidgets('${entry.key} reads ${expected.name} with a tag in it', (tester) async {
      final rich = await pump(tester, TagStyledText('$text #aura'));
      expect(rich.textDirection, expected);
    });
  }
}
