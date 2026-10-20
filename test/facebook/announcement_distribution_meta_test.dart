// The announcement editor's Distribution list offers Facebook Page and
// Instagram beside LinkedIn and TikTok (2026-10-20). A switch for a place the
// member has not connected stays off and says where it comes alive.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/announcements/presentation/announcement_distribution.dart';

void main() {
  Widget host({required bool fb, required bool ig, required void Function(bool, bool) onChanged}) =>
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AnnouncementDistribution(
              linkedinConnected: false,
              tiktokConnected: false,
              tiktokEnabled: false,
              initialAura: true,
              initialLinkedin: false,
              initialTiktok: false,
              facebookConnected: fb,
              facebookPageName: 'Aura Platform',
              instagramConnected: ig,
              instagramUsername: 'auraplatform',
              onChanged: ({
                required bool aura,
                required bool linkedin,
                required bool tiktok,
                required bool facebook,
                required bool instagram,
              }) =>
                  onChanged(facebook, instagram),
            ),
          ),
        ),
      );

  testWidgets('not connected: both switches are off and say how to connect', (tester) async {
    await tester.pumpWidget(host(fb: false, ig: false, onChanged: (_, __) {}));
    expect(find.textContaining('connect a Facebook Page on your profile'), findsOneWidget);
    expect(find.text('Comes with a Facebook Page that has Instagram linked'), findsOneWidget);
    final switches = tester.widgetList<SwitchListTile>(find.byType(SwitchListTile)).toList();
    expect(switches.where((s) => s.onChanged == null).length, greaterThanOrEqualTo(4));
  });

  testWidgets('connected: the Page and the Instagram account are named and can be chosen', (
    tester,
  ) async {
    bool? fb;
    bool? ig;
    await tester.pumpWidget(host(fb: true, ig: true, onChanged: (f, i) {
      fb = f;
      ig = i;
    }));
    expect(find.text('Aura Platform'), findsOneWidget);
    expect(find.textContaining('@auraplatform'), findsOneWidget);
    await tester.tap(find.text('Facebook Page'));
    await tester.pumpAndSettle();
    expect(fb, isTrue);
    await tester.tap(find.text('Instagram'));
    await tester.pumpAndSettle();
    expect(ig, isTrue);
  });
}
