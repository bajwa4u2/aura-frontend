// CHOOSING A GOVERNED REPRESENTATION.
//
// Identity images are stored as governed NAMES that address Aura's delivery
// door. Which representation of that name a surface renders is a presentation
// decision, and these pin the two properties that make it safe to apply
// everywhere: it never breaks a URL Aura does not serve, and asking for a
// derivative that does not exist still yields a picture.

import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/media/governed_image_variant.dart';

void main() {
  const door = 'https://app.aura.example/media/med_123/raw';

  group('recognising a governed name', () {
    test('the delivery door is recognised', () {
      expect(isGovernedImageUrl(door), isTrue);
    });

    test('recognition survives a delivery-origin change', () {
      // Structural rather than host-based on purpose: the delivery origin
      // differs between environments and has been repointed before, and a
      // host-locked check would quietly stop recognising Aura's own images the
      // next time it moved.
      expect(
        isGovernedImageUrl('https://api.somewhere-else.test/media/m1/raw'),
        isTrue,
      );
      expect(isGovernedImageUrl('http://localhost:3000/media/m1/raw'), isTrue);
    });

    test('anything Aura does not serve is not a governed name', () {
      for (final foreign in [
        'https://lh3.googleusercontent.com/a/photo.jpg',
        'https://uploads.example/users/u1/avatar.png',
        'data:image/png;base64,AAAA',
        '',
        null,
      ]) {
        expect(isGovernedImageUrl(foreign), isFalse, reason: '$foreign');
      }
    });
  });

  group('asking for a representation', () {
    test('an avatar asks for the small one', () {
      expect(
        governedImageVariant(door, GovernedImageVariant.thumbnail),
        '$door?v=thumb',
      );
    });

    test('a cover asks for the display one', () {
      expect(
        governedImageVariant(door, GovernedImageVariant.display),
        '$door?v=display',
      );
    });

    test('the original sends no variant, because the door already means it', () {
      expect(governedImageVariant(door, GovernedImageVariant.original), door);
    });
  });

  group('the properties that make this safe everywhere', () {
    test('a foreign URL is returned untouched', () {
      // THE ONE THAT MATTERS MOST. Appending a query parameter to a URL Aura
      // does not serve would at best do nothing and at worst break it — and
      // one identity image in production is an external URL, deliberately left
      // alone by the value convergence because Aura cannot sign what it does
      // not host.
      const external = 'https://lh3.googleusercontent.com/a/photo.jpg';
      expect(
        governedImageVariant(external, GovernedImageVariant.thumbnail),
        external,
      );
    });

    test('an empty or absent value stays empty or absent', () {
      expect(governedImageVariant(null, GovernedImageVariant.thumbnail), isNull);
      expect(governedImageVariant('', GovernedImageVariant.display), '');
    });

    test('an explicit variant already on the URL is not second-guessed', () {
      const explicit = '$door?v=display';
      expect(
        governedImageVariant(explicit, GovernedImageVariant.thumbnail),
        explicit,
      );
    });

    test('no second identity URL is invented — only the name is decorated', () {
      // The convergence must not produce a parallel avatar-thumbnail field or
      // another durable string. Whatever comes back still addresses the same
      // media id through the same door.
      final asked = governedImageVariant(door, GovernedImageVariant.thumbnail)!;
      expect(asked.startsWith(door), isTrue);
      expect(asked.split('?').first, door);
      expect(RegExp(r'/media/med_123/raw').hasMatch(asked), isTrue);
    });
  });
}
