import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aura/app/aura_app.dart';
import 'package:aura/core/auth/auth_providers.dart';
import 'package:aura/core/release_governance/compatibility_models.dart';
import 'package:aura/core/release_governance/compatibility_provider.dart';
import 'package:aura/core/release_governance/compatibility_repository.dart';

/// Stubs the release-governance compatibility fetch so the smoke test
/// never starts a real Dio request on boot. A live request leaves Dio's
/// internal request timer pending past the end of the test, which the
/// test framework reports as a leaked timer.
class _StubCompatibilityRepository implements CompatibilityRepository {
  @override
  Future<CompatibilityVerdict> fetch() async => CompatibilityVerdict.compatible;
}

void main() {
  testWidgets('AuraApp builds without crashing', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    final store = TokenStore();
    await store.load();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStoreProvider.overrideWith((ref) => store),
          compatibilityRepositoryProvider
              .overrideWithValue(_StubCompatibilityRepository()),
        ],
        child: const AuraApp(),
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);

    // Tear the app down inside the test body. AuraApp boots long-lived
    // background governance services that own periodic timers; replacing
    // the tree with an empty widget removes the ProviderScope, disposing
    // those providers and cancelling their timers before the framework's
    // end-of-test "no pending timers" invariant runs.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
