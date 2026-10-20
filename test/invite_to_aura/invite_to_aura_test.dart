// INVITE TO AURA (canon amendment 2026-10-20): a member's personal link,
// shared through the platforms' own share pages, offered at a few moments,
// each once ever. These keep the link exact, the channels countable, the
// public page public, and a failed read from ever showing a prompt.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/app/route_classification.dart';
import 'package:aura/features/invite_to_aura/invite_to_aura.dart';

class _FakeClient implements InviteToAuraClient {
  _FakeClient(this.state);

  InvitePromptState state;
  final recorded = <String>[];

  @override
  Future<InvitePromptState> prompts() async => state;

  @override
  Future<void> record(InvitePromptSurface surface, String outcome) async {
    recorded.add('${surface.name}:$outcome');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('the personal link names the member and carries the channel', () {
    expect(inviteToAuraUrl('BajwaWrites'), 'https://auraplatform.org/join/bajwawrites');
    expect(
      inviteToAuraUrl('bajwawrites', via: 'facebook'),
      'https://auraplatform.org/join/bajwawrites?via=facebook',
    );
  });

  test('only the channels the server counts travel as a channel', () {
    expect(normalizedInviteChannel(' WhatsApp '), 'whatsapp');
    expect(normalizedInviteChannel('qr'), 'qr');
    expect(normalizedInviteChannel('summer-campaign'), isNull);
    expect(normalizedInviteChannel(null), isNull);
  });

  test('WhatsApp opens its own share page with the message prefilled', () {
    expect(
      whatsappShareUrl('Join me https://auraplatform.org/join/a?via=whatsapp'),
      'https://wa.me/?text=Join%20me%20https%3A%2F%2Fauraplatform.org%2Fjoin%2Fa%3Fvia%3Dwhatsapp',
    );
  });

  test('the invitation page is public: it is for people not on Aura yet', () {
    expect(isPublicPath('/join/bajwawrites'), isTrue);
  });

  test('a failed or empty read offers nothing', () {
    expect(InvitePromptState.none.offers(InvitePromptSurface.feedCard), isFalse);
    expect(InvitePromptState.none.offers(InvitePromptSurface.dialog), isFalse);
    final s = InvitePromptState.fromJson({
      'pending': ['FEED_CARD', 'AFTER_POST', 'DIALOG'],
      'dialogEligible': false,
    });
    expect(s.offers(InvitePromptSurface.feedCard), isTrue);
    expect(s.offers(InvitePromptSurface.afterPost), isTrue);
    // Pending is not enough for the dialog; the server must say eligible.
    expect(s.offers(InvitePromptSurface.dialog), isFalse);
  });

  testWidgets('the sheet offers every channel, without overflowing a small phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showInviteToAuraSheet(
                context,
                handle: 'bajwawrites',
                displayName: 'M S Bajwa',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Invite to Aura'), findsOneWidget);
    expect(find.textContaining('M S Bajwa invited them'), findsOneWidget);
    expect(find.text('https://auraplatform.org/join/bajwawrites'), findsOneWidget);
    for (final label in [
      'Copy link',
      'Share to Facebook',
      'Share on WhatsApp',
      'Share to LinkedIn',
      'Share by email',
      'Show QR code',
    ]) {
      final f = find.text(label);
      await tester.ensureVisible(f);
      expect(f, findsOneWidget, reason: label);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('the QR code opens and lays out', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showInviteToAuraSheet(
                context,
                handle: 'bajwawrites',
                displayName: 'M S Bajwa',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Show QR code'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show QR code'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Done'), findsOneWidget);
    expect(find.textContaining('open M S Bajwa'), findsOneWidget);
  });

  testWidgets('the feed card shows once, and "Not now" records it for good', (
    tester,
  ) async {
    final client = _FakeClient(
      const InvitePromptState(
        pending: {InvitePromptSurface.feedCard},
        dialogEligible: false,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [inviteToAuraClientProvider.overrideWithValue(client)],
        child: const MaterialApp(
          home: Scaffold(
            body: InviteToAuraFeedCard(handle: 'bajwawrites', displayName: 'M S Bajwa'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Aura is better with people you know.'), findsOneWidget);

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.text('Aura is better with people you know.'), findsNothing);
    expect(client.recorded, ['feedCard:DISMISSED']);
  });

  testWidgets('a feed card already had does not appear', (tester) async {
    final client = _FakeClient(
      const InvitePromptState(pending: {}, dialogEligible: false),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [inviteToAuraClientProvider.overrideWithValue(client)],
        child: const MaterialApp(
          home: Scaffold(
            body: InviteToAuraFeedCard(handle: 'bajwawrites', displayName: 'M S Bajwa'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Aura is better with people you know.'), findsNothing);
  });

  testWidgets('the dialog appears only when eligible, and is recorded before it shows', (
    tester,
  ) async {
    final client = _FakeClient(
      const InvitePromptState(pending: {}, dialogEligible: false),
    );
    late WidgetRef capturedRef;
    late BuildContext capturedContext;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [inviteToAuraClientProvider.overrideWithValue(client)],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              capturedRef = ref;
              capturedContext = context;
              return const Scaffold(body: SizedBox());
            },
          ),
        ),
      ),
    );

    await maybeShowInviteDialog(
      capturedContext,
      capturedRef,
      handle: 'bajwawrites',
      displayName: 'M S Bajwa',
    );
    await tester.pumpAndSettle();
    expect(find.text('Bring someone to Aura?'), findsNothing);
    expect(client.recorded, isEmpty);

    client.state = const InvitePromptState(
      pending: {InvitePromptSurface.dialog},
      dialogEligible: true,
    );
    // ignore: unawaited_futures
    maybeShowInviteDialog(
      capturedContext,
      capturedRef,
      handle: 'bajwawrites',
      displayName: 'M S Bajwa',
    );
    await tester.pumpAndSettle();
    expect(find.text('Bring someone to Aura?'), findsOneWidget);
    expect(client.recorded, ['dialog:SHOWN']);
    await tester.tap(find.text('Maybe later'));
    await tester.pumpAndSettle();
    expect(find.text('Bring someone to Aura?'), findsNothing);
  });
}
