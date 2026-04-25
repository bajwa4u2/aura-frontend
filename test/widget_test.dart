import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aura/app/aura_app.dart';
import 'package:aura/core/auth/auth_providers.dart';

void main() {
  testWidgets('AuraApp builds without crashing', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    final store = TokenStore();
    await store.load();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStoreProvider.overrideWith((ref) => store),
        ],
        child: const AuraApp(),
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
