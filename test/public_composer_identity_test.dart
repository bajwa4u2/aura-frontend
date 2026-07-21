import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aura/core/auth/session_providers.dart';
import 'package:aura/features/public/widgets/public_composer.dart';

void main() {
  testWidgets('PublicComposer uses available profile avatar image', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authMeDataProvider.overrideWith((ref) async {
            return {
              'user': {
                'id': 'u1',
                'displayName': 'Muhammad',
                'handle': 'msb',
                'avatarUrl': 'https://cdn.example.com/avatar.png',
              },
            };
          }),
        ],
        child: const MaterialApp(home: Scaffold(body: PublicComposer())),
      ),
    );

    await tester.pump();

    final image = tester.widget<Image>(find.byType(Image).first);
    expect(image.image, isA<NetworkImage>());
    expect(
      (image.image as NetworkImage).url,
      'https://cdn.example.com/avatar.png',
    );
  });
}
