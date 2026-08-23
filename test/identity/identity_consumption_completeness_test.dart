import 'dart:io';

import 'package:aura/core/identity/person_identity_model.dart';
import 'package:aura/core/trust/verification.dart';
import 'package:flutter_test/flutter_test.dart';

/// CANONICAL IDENTITY MUST BE CONSUMED WHOLE — F053 / F116, CH-03.
///
/// The measured shape of this debt was never "some screens are broken". It was
/// one absence: no single canonical identity model, so 103 surfaces each read
/// person fields their own way. The model now exists — and a NEW failure mode
/// appeared with it, which the founder observed on Institution → Members:
///
///   PARTIAL ADOPTION. A surface calls the canonical reader, uses it for the
///   name, and throws away the avatar, the verification and the lifecycle. It
///   looks converged in review — the canonical reader is right there — and the
///   person still renders as a generic initial with no trust state.
///
/// PB-05 says F116 may not be closed by fixing one consumer. So this walks the
/// consumer set rather than asserting one screen, and fails when a surface
/// reads the canonical identity and then renders an avatar without it.
void main() {
  /// A surface reads the canonical identity.
  final readsIdentity = RegExp(r'AuraPersonIdentity\.fromJson');

  /// A surface renders an avatar.
  final rendersAvatar = RegExp(r'AuraAvatar\(');

  /// The avatar is given an image. Written to match the argument rather than
  /// the value, because the value legitimately varies — `person.avatarUrl`,
  /// `s.person.avatarUrl`, a nullable local — and pinning the value would make
  /// this a style rule instead of a behavioural one.
  final passesImage = RegExp(r'imageUrl:');

  /// NOT PEOPLE. These render an `AuraAvatar` for something that is not a
  /// person — an institution, a space, a room — where there is no person
  /// identity to consume and no avatar to drop. Kept explicit and short.
  const notPersonAvatars = <String>{};

  List<File> dartFiles(String dir) => Directory(dir)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('a surface that reads a person renders their face', () {
    final partial = <String>[];

    for (final file in dartFiles('lib')) {
      final rel = file.path.replaceAll(r'\', '/');
      if (notPersonAvatars.any(rel.endsWith)) continue;

      final source = file.readAsStringSync();
      if (!readsIdentity.hasMatch(source)) continue;
      if (!rendersAvatar.hasMatch(source)) continue;
      if (passesImage.hasMatch(source)) continue;

      partial.add(rel);
    }

    expect(
      partial,
      isEmpty,
      reason:
          'These read the canonical person identity and then render an avatar '
          'without it, so the person appears as a generic initial while the '
          'same human renders with a photo elsewhere. Pass the identity\'s '
          'avatarUrl to AuraAvatar — do not reconstruct one, and do not add a '
          'surface-local avatar model:\n  ${partial.join('\n  ')}',
    );
  });

  group('the canonical model carries the whole person', () {
    test('verification travels with identity, not beside it', () {
      // The roster could not have rendered trust even if it wanted to: the
      // client model had no verification at all, so every surface either
      // fetched it separately or silently omitted it.
      final person = AuraPersonIdentity.fromJson({
        'id': 'u1',
        'displayName': 'A Person',
        'handle': 'aperson',
        'avatarUrl': 'https://auraplatform.org/media/m1/raw',
        'accountStatus': 'ACTIVE',
        'verification': {
          'classes': ['IDENTITY'],
        },
      });

      expect(person.avatarUrl, 'https://auraplatform.org/media/m1/raw');
      expect(person.verification.hasAny, isTrue);
      expect(person.verification.has(PersonVerificationClass.identity), isTrue);
    });

    test('absence of verification is empty, never an error or a claim', () {
      final person = AuraPersonIdentity.fromJson({
        'id': 'u1',
        'displayName': 'A Person',
        'handle': 'aperson',
      });

      expect(person.verification.hasAny, isFalse);
      expect(person.accountStatus, isNull);
    });

    test('reads the person out of the canonical `person` envelope', () {
      // The backend emits the projection under `person` when a payload
      // carries its own state beside the human — a discovery suggestion.
      // Before this the reader looked everywhere except there.
      final person = AuraPersonIdentity.fromJson({
        'person': {
          'id': 'u1',
          'displayName': 'A Person',
          'handle': 'aperson',
          'avatarUrl': 'https://auraplatform.org/media/m1/raw',
          'verification': {
            'classes': ['IDENTITY'],
          },
        },
        'reasons': ['Followed by someone you follow'],
        'followState': 'NONE',
      });

      expect(person.userId, 'u1');
      expect(person.avatarUrl, 'https://auraplatform.org/media/m1/raw');
      expect(person.verification.hasAny, isTrue);
    });

    test('the same payload yields the same person, whichever surface reads it', () {
      // §F: a verified person must not become unverified by being looked at
      // through a different endpoint.
      const payload = {
        'id': 'u1',
        'displayName': 'A Person',
        'handle': 'aperson',
        'avatarUrl': 'https://auraplatform.org/media/m1/raw',
        'accountStatus': 'ACTIVE',
        'verification': {
          'classes': ['IDENTITY'],
        },
      };

      expect(
        AuraPersonIdentity.fromJson(payload),
        AuraPersonIdentity.fromJson({'user': payload}),
      );
      expect(
        AuraPersonIdentity.fromJson({'actor': payload}),
        AuraPersonIdentity.fromJson({'person': payload}),
      );
    });
  });

  group('presentation may differ; the DATA may not', () {
    /// FOUNDER RULING 2026-08-23 — Institution Activity.
    ///
    /// Activity is an event / continuity / accountability surface. Its default
    /// actor presentation is the canonical name, avatar and handle WITHOUT
    /// mechanically drawing verification glyphs on every row. That is a
    /// legitimate destination-specific presentation difference.
    ///
    /// The distinction this group protects is exact, and both halves have a
    /// plausible-looking way to go wrong:
    ///
    ///   - someone "completes" the convergence by adding trust marks to every
    ///     Activity row, making an audit log noisier without making it truer;
    ///   - someone "simplifies" the model by dropping verification from the
    ///     identity Activity reads, because Activity does not draw it — which
    ///     WOULD be partial adoption, and would silently degrade every other
    ///     consumer that shares the reader.
    const activity =
        'lib/features/institutions/activity/institution_activity_screen.dart';

    test('Activity consumes the canonical actor, avatar included', () {
      final source = File(activity).readAsStringSync();
      expect(source, contains('AuraPersonIdentity.fromJson'));
      expect(source, contains('imageUrl:'));
    });

    test('Activity deliberately draws no verification marks', () {
      final source = File(activity).readAsStringSync();
      expect(
        source.contains('PersonVerificationMarks'),
        isFalse,
        reason:
            'Founder ruling: Activity presents EVENTS, and verification glyphs '
            'on every row are not required. Render a mark here only where the '
            'event or actor context makes it materially relevant — and record '
            'that reasoning if you do.',
      );
    });

    test('...while the verification still TRAVELS to it', () {
      // The data is not stripped because one destination declines to draw it.
      // This is what separates a presentation choice from partial adoption.
      final actor = AuraPersonIdentity.fromJson({
        'actor': {
          'id': 'u1',
          'displayName': 'A Person',
          'handle': 'aperson',
          'verification': {
            'classes': ['IDENTITY'],
          },
        },
      });

      expect(actor.verification.hasAny, isTrue);
    });

    test('Activity defines no trust model of its own', () {
      // The ruling forbids an Activity-specific trust model, not the presence
      // of verification code elsewhere — the admin review sheet and the
      // institution verification request screen are legitimate surfaces about
      // verification, which is a different thing from a parallel model of it.
      final source = File(activity).readAsStringSync();

      // Widget classes are expected here. A class that models VERIFICATION or
      // TRUST is not — that would be the parallel model the ruling forbids.
      final localTrustModel =
          RegExp(r'class \w*(Verification|Trust)\w*').allMatches(source);
      expect(localTrustModel, isEmpty);

      // Nor may it reach past the projection into the raw column the canonical
      // authority exists to interpret.
      expect(source, isNot(contains('verifiedClasses')));
    });
  });

  test('the four measured surfaces consume the identity they read', () {
    // Named explicitly, because the walker above can only prove that nothing
    // is partially adopted — not that these particular surfaces, the ones the
    // founder measured, are the ones that were fixed.
    const measured = [
      'lib/features/institutions/presentation/institution_members_screen.dart',
      'lib/features/institutions/presentation/institution_join_requests_screen.dart',
      'lib/features/institutions/activity/institution_activity_screen.dart',
      'lib/features/discover/presentation/people_discovery_screen.dart',
    ];

    for (final path in measured) {
      final source = File(path).readAsStringSync();
      expect(source, contains('AuraPersonIdentity'), reason: path);
      expect(source, contains('imageUrl:'), reason: path);
    }
  });
}
