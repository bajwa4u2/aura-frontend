import 'dart:io';

import 'package:aura/features/home/presentation/start_here_card.dart';
import 'package:flutter_test/flutter_test.dart';

/// A NEW PERSON'S FIRST MINUTES (2026-10-09): two of three sign-ups from one
/// company got in, saw a quiet Home with nothing to do, and left without a
/// single follow, post or reaction.
void main() {
  final card = File('lib/features/home/presentation/start_here_card.dart').readAsStringSync();
  final home = File('lib/features/home/presentation/member_home_screen.dart').readAsStringSync();

  test('Start here shows until a person follows a few people or says they are set', () {
    expect(kStartHereFollowingThreshold, 3);
    expect(card.contains('counts.following < kStartHereFollowingThreshold'), isTrue);
    expect(card.contains(r"'aura.start_here.dismissed.$userId'"), isTrue);
  });

  test('every row does something', () {
    for (final action in ["'More people'", "'More institutions'", "'Ask a question'", "'Find a space'", '"I\'m set"']) {
      expect(card.contains(action), isTrue, reason: action);
    }
    expect(card.contains('PersonSuggestionCard('), isTrue);
    expect(card.contains('InstitutionPresenceCard('), isTrue);
  });

  test('Home carries it, and an empty Home says what to do', () {
    expect(home.contains('const StartHereCard()'), isTrue);
    expect(home.contains('Quiet on the public stream right now'), isFalse);
    expect(home.contains('Follow people and institutions, or ask the first question. '), isTrue);
  });
}
