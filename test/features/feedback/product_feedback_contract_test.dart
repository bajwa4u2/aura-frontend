import 'dart:convert';
import 'dart:io';

import 'package:aura/features/feedback/data/product_feedback_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// CONFORMANCE TO THE CANONICAL CONTRACT.
///
/// The client is a second place the vocabulary can drift, and a client that
/// quietly invents a fourth intent or collects a forbidden field is exactly as
/// broken as a backend that does. So the client is held to the same file.
void main() {
  final contract = jsonDecode(
    File('contracts/product_feedback_contract.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  test('the three intents match the contract, exactly', () {
    final keys = (contract['intents'] as List)
        .map((i) => (i as Map)['key'] as String)
        .toSet();
    expect(FeedbackIntent.values.map((v) => v.wire).toSet(), keys);
  });

  test('the four lifecycle states match the contract, exactly', () {
    final states =
        ((contract['lifecycle'] as Map)['states'] as List).cast<String>().toSet();
    expect(FeedbackState.values.map((v) => v.wire).toSet(), states);
  });

  test('an unknown state from the wire does not crash the person\'s list', () {
    // A backend one version ahead must not blank the screen of someone who
    // has not updated yet.
    expect(FeedbackState.fromWire('SOMETHING_NEW'), FeedbackState.received);
    expect(FeedbackState.fromWire(null), FeedbackState.received);
  });

  group('what leaves the device', () {
    final ctx = FeedbackContext.from(
      identity: null,
      surface: '/messages',
      locale: 'en-GB',
    );

    test('carries only fields the contract allows', () {
      final allowed =
          ((contract['diagnosticContext'] as Map)['allowed'] as List).cast<String>();
      for (final key in ctx.toJson().keys) {
        expect(allowed, contains(key),
            reason: '$key is not an allowed context field');
      }
    });

    test('carries nothing the contract forbids', () {
      final forbidden =
          ((contract['diagnosticContext'] as Map)['forbidden'] as List).cast<String>();
      final sent = ctx.toJson();
      for (final key in forbidden) {
        expect(sent.containsKey(key), isFalse, reason: '$key must never be sent');
      }
    });

    test('names the product, so one operator queue can serve several', () {
      expect(ctx.product, 'aura');
      expect(ctx.platform, isNotEmpty);
    });

    test('the surface is a pattern, never a populated path', () {
      // The screen only ever passes a first segment; this asserts the shape
      // that reaches the wire, since a real path names a real conversation.
      final json = FeedbackContext.from(
        identity: null,
        surface: '/messages',
        locale: null,
      ).toJson();
      expect(json['surface'], '/messages');
      expect(RegExp(r'^/[a-z-]*$').hasMatch(json['surface'] as String), isTrue);
    });
  });
}
