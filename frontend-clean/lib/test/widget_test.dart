import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aura/main.dart';

void main() {
  testWidgets('AuraApp builds without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const AuraApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
