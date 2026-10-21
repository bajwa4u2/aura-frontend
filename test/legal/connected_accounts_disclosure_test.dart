import 'package:aura/screens/account_deletion_screen.dart';
import 'package:aura/screens/privacy_policy_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// The privacy policy and the deletion page must say what happens to
// Facebook, Instagram, LinkedIn and TikTok connections. Meta's review, Apple's
// 5.1.1 and Play's Data safety form all read these pages against what Aura
// actually does.
void main() {
  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(child: MaterialApp(home: screen)));
    await tester.pump();
  }

  testWidgets('privacy policy has a connected accounts section', (tester) async {
    await pump(tester, const PrivacyPolicyScreen());

    expect(find.text('Connected accounts and sharing elsewhere'), findsOneWidget);
    expect(find.textContaining('it never publishes there unless you ask'), findsOneWidget);
    expect(find.textContaining('Deleting your Aura account disconnects every connected account'), findsOneWidget);
    expect(find.textContaining('data-deletion/status'), findsOneWidget);
    expect(find.textContaining('only as daily totals'), findsOneWidget);
  });

  testWidgets('privacy sections stay numbered in order', (tester) async {
    await pump(tester, const PrivacyPolicyScreen());

    for (var i = 1; i <= 12; i++) {
      expect(find.text(i.toString().padLeft(2, '0')), findsOneWidget);
    }
  });

  testWidgets('account deletion says connected accounts are disconnected', (tester) async {
    await pump(tester, const AccountDeletionScreen());

    expect(
      find.textContaining('Facebook Page, Instagram, LinkedIn or TikTok account'),
      findsOneWidget,
    );
  });
}
