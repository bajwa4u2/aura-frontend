// TRACK B1 — OS SHARE INTAKE, GOVERNED.
//
// The five invariants the founder set for share intake, asserted rather than
// asserted-to. Four of them are structural: they hold because the feature
// contains no code that could break them, and this file proves the absence.
// The fifth is behavioural, and is exercised through the controller.
//
//   OS_SHARE_DIRECT_PUBLISH        = 0
//   LAST_USED_DESTINATION_INFERENCE = 0
//   LAST_USED_IDENTITY_INFERENCE    = 0
//   CONTENTINTAKE_BYPASS            = 0
//   PAGE_SPECIFIC_SHARE_PIPELINES   = 0
//
// A source-text gate is a blunt instrument and is used here deliberately. The
// thing being protected is an ABSENCE — that no one, under deadline, adds a
// "recent destinations" row or a direct send "just for Android". A test that
// only exercised today's behaviour would pass on the day that code is added.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:aura/features/share_intake/application/share_intake_controller.dart';
import 'package:aura/features/share_intake/domain/acquisition_envelope.dart';
import 'package:aura/features/share_intake/domain/share_destination.dart';
import 'package:aura/core/authority/acting_context.dart';
import 'package:aura/core/authority/capability_projection.dart';
import 'package:flutter_test/flutter_test.dart';

const _featureDir = 'lib/features/share_intake';

/// Every Dart file in the feature, as source text.
Map<String, String> _featureSources() {
  final dir = Directory(_featureDir);
  if (!dir.existsSync()) {
    throw StateError('$_featureDir is missing — share intake has moved.');
  }
  final sources = <String, String>{};
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      sources[entity.path.replaceAll(r'\', '/')] = entity.readAsStringSync();
    }
  }
  if (sources.isEmpty) throw StateError('$_featureDir has no Dart files.');
  return sources;
}

/// Source with `//` and `///` comment lines removed.
///
/// The gates below must judge CODE, not the documentation that explains why
/// the code is shaped as it is. Several of these files describe the very
/// constructs they must not contain, and a gate that tripped on its own
/// rationale would teach the next person to delete the rationale.
String _codeOnly(String source) => source
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  group('OS_SHARE_DIRECT_PUBLISH = 0', () {
    test('share intake contains nothing that can publish', () {
      // Writes of every shape. A share is an acquisition; the send belongs to
      // the destination's own composer, which already enforces its own rules.
      const forbidden = <String, String>{
        '.post(': 'an HTTP write',
        '.put(': 'an HTTP write',
        '.patch(': 'an HTTP write',
        '.delete(': 'an HTTP write',
        'uploadAuraMedia': 'the media upload',
        'publishDraft': 'publishing',
        'saveDraft': 'draft persistence',
        'FeedDraftPublisher': 'publishing',
      };

      final violations = <String>[];
      _featureSources().forEach((path, source) {
        final code = _codeOnly(source);
        forbidden.forEach((needle, what) {
          if (code.contains(needle)) violations.add('$path performs $what');
        });
      });

      expect(
        violations,
        isEmpty,
        reason: 'Share intake must not publish. It resolves content and hands '
            'it to the destination composer, which is why there is only one '
            'publishing implementation to keep correct.',
      );
    });

    test('the confirm action stages, it does not send', () {
      final screen = File('$_featureDir/presentation/share_intake_screen.dart')
          .readAsStringSync();
      expect(screen.contains('shareHandoffProvider'), isTrue);
      // The button says what it does. "Send" or "Publish" on this surface
      // would be a promise the code does not keep.
      expect(_codeOnly(screen).contains("label: 'Continue'"), isTrue);
    });
  });

  group('LAST_USED_DESTINATION_INFERENCE = 0', () {
    test('no destination is remembered between shares', () {
      const forbidden = <String>[
        'SharedPreferences',
        'recentDestination',
        'lastDestination',
        'lastUsedDestination',
        'mostRecentConversation',
      ];
      final violations = <String>[];
      _featureSources().forEach((path, source) {
        final code = _codeOnly(source);
        for (final needle in forbidden) {
          if (code.contains(needle)) violations.add('$path remembers $needle');
        }
      });
      expect(
        violations,
        isEmpty,
        reason: 'A share sheet that remembers where you last sent something is '
            'how a private photograph reaches the wrong person: the target is '
            'chosen by muscle memory rather than read.',
      );
    });

    test('a fresh controller has no destination at all', () {
      final controller = ShareIntakeController(_textEnvelope());
      expect(controller.destination, isNull);
      expect(controller.readyToConfirm, isFalse);
    });
  });

  group('LAST_USED_IDENTITY_INFERENCE = 0', () {
    test('no acting identity is remembered or derived from a route', () {
      const forbidden = <String>[
        'lastIdentity',
        'lastActingIdentity',
        'GoRouterState',
        'institutionIdFromPath',
      ];
      final violations = <String>[];
      _featureSources().forEach((path, source) {
        final code = _codeOnly(source);
        for (final needle in forbidden) {
          if (code.contains(needle)) violations.add('$path uses $needle');
        }
      });
      expect(violations, isEmpty);
    });

    test('identity comes from the C1 authority, not a private model', () {
      // A second acting-identity type would be a second answer to "who am I
      // acting as", and C1 exists precisely because two answers disagreed.
      final sources = _featureSources().values.join('\n');
      expect(sources.contains('ActingOption'), isTrue);
      expect(
        sources.contains('class ShareActingIdentity'),
        isFalse,
        reason: 'Acting identity is resolved by ActingContextAuthority.',
      );
    });

    test('the destination names the act; it does not choose the identity', () {
      expect(
        const ShareDestination(
          kind: ShareDestinationKind.publicPost,
          id: '',
          title: 'Publish publicly',
        ).act,
        ConsequentialAct.publishPersonalPost,
      );
      // The same destination inside an institution is a different act, and
      // therefore resolves against different authority.
      expect(
        const ShareDestination(
          kind: ShareDestinationKind.publicPost,
          id: '',
          title: 'Publish publicly',
          institutionId: 'inst_1',
        ).act,
        ConsequentialAct.publishInstitutionPost,
      );
    });
  });

  group('CONTENTINTAKE_BYPASS = 0', () {
    test('the feature never builds an Attachment itself', () {
      final violations = <String>[];
      _featureSources().forEach((path, source) {
        // `Attachment(` as a constructor call. Type annotations
        // (`List<Attachment>`) and parameters (`Attachment attachment`) are
        // not constructions and are not matched.
        if (RegExp(r'(^|[^A-Za-z_])Attachment\(')
            .hasMatch(_codeOnly(source))) {
          violations.add('$path constructs an Attachment directly');
        }
      });
      expect(
        violations,
        isEmpty,
        reason: 'Every attachment in Aura is produced by ContentIntake, which '
            'decides its class from the bytes. A hand-built one would carry '
            'whatever type the sharing application claimed.',
      );
    });

    test('resolution goes through the canonical door', () {
      final controller =
          File('$_featureDir/application/share_intake_controller.dart')
              .readAsStringSync();
      expect(
        controller.contains('ContentIntake.resolveAndPrepareBytes'),
        isTrue,
      );
      expect(controller.contains('IntakePath.share'), isTrue);
    });

    test('a declared type that lies is overruled by the bytes', () async {
      final controller = ShareIntakeController(
        AcquisitionEnvelope(
          platform: AcquisitionPlatform.android,
          receivedAt: DateTime.now(),
          payloads: [
            AcquiredPayload(
              kind: AcquiredPayloadKind.file,
              bytes: _png(),
              fileName: 'holiday.pdf',
              // What the sharing application said. It is wrong, which is the
              // entire reason this door reads the bytes.
              declaredMimeType: 'application/pdf',
            ),
          ],
        ),
      );
      await controller.resolve();

      expect(controller.attachments, hasLength(1));
      expect(controller.attachments.single.mimeType, 'image/png');
    });

    test('content that cannot be accepted is reported, never dropped', () async {
      final controller = ShareIntakeController(
        AcquisitionEnvelope(
          platform: AcquisitionPlatform.windows,
          receivedAt: DateTime.now(),
          payloads: [
            AcquiredPayload(
              kind: AcquiredPayloadKind.file,
              bytes: Uint8List.fromList(List<int>.filled(32, 0x00)),
              fileName: 'mystery.bin',
            ),
          ],
        ),
      );
      await controller.resolve();

      expect(controller.attachments, isEmpty);
      expect(controller.refusals, isNotEmpty);
      expect(controller.blockedReason, isNotNull);
    });
  });

  group('PAGE_SPECIFIC_SHARE_PIPELINES = 0', () {
    test('the feature branches on no platform', () {
      const forbidden = <String>[
        'Platform.isAndroid',
        'Platform.isIOS',
        'Platform.isWindows',
        'defaultTargetPlatform',
        'kIsWeb',
      ];
      final violations = <String>[];
      _featureSources().forEach((path, source) {
        final code = _codeOnly(source);
        for (final needle in forbidden) {
          if (code.contains(needle)) violations.add('$path branches on $needle');
        }
      });
      expect(
        violations,
        isEmpty,
        reason: 'Android, iOS and Windows differ in how a share is delivered '
            'and in nothing afterwards. A platform branch here would be a '
            'second place the destination and identity rules have to hold.',
      );
    });

    test('exactly one route renders the share destination', () {
      final router = File('lib/router.dart').readAsStringSync();
      expect(
        'ShareIntakeScreen('.allMatches(router).length,
        1,
        reason: 'One entrance, or the rules have to be kept in two places.',
      );
    });

    test('every platform adapter must deliver into one inbox', () {
      final inbox = File('$_featureDir/application/share_intake_inbox.dart')
          .readAsStringSync();
      expect(inbox.contains('void deliver('), isTrue);
      // Read-and-clear. A share presented twice is a person publishing twice
      // without having asked to.
      expect(inbox.contains('state = null'), isTrue);
    });
  });

  group('no consequence before explicit confirmation', () {
    late ShareIntakeController controller;

    setUp(() async {
      controller = ShareIntakeController(
        AcquisitionEnvelope(
          platform: AcquisitionPlatform.ios,
          receivedAt: DateTime.now(),
          payloads: [
            AcquiredPayload(kind: AcquiredPayloadKind.file, bytes: _png()),
          ],
        ),
      );
      await controller.resolve();
    });

    const destination = ShareDestination(
      kind: ShareDestinationKind.conversation,
      id: 'conv_1',
      title: 'A conversation',
    );

    const identity = ActingOption(
      kind: ActingIdentityKind.person,
      id: 'person_1',
      displayName: 'A Person',
      availability: ActingAvailability.personalDefault,
      personId: 'person_1',
    );

    test('content alone is not enough', () {
      expect(controller.hasContent, isTrue);
      expect(controller.readyToConfirm, isFalse);
      expect(controller.blockedReason, 'Choose where this goes.');
    });

    test('a destination alone is not enough', () {
      controller.chooseDestination(destination);
      expect(controller.readyToConfirm, isFalse);
      expect(controller.blockedReason, 'Choose who this is published as.');
    });

    test('an unseen preview blocks confirmation', () {
      controller.chooseDestination(destination);
      controller.chooseIdentity(identity);
      expect(controller.readyToConfirm, isFalse);
      expect(controller.blockedReason, 'Check what you are about to send.');
    });

    test('all four together, and only then', () {
      controller.chooseDestination(destination);
      controller.chooseIdentity(identity);
      controller.markPreviewSeen();
      expect(controller.blockedReason, isNull);
      expect(controller.readyToConfirm, isTrue);
    });

    test('changing the destination re-opens the identity question', () {
      controller.chooseDestination(destination);
      controller.chooseIdentity(identity);
      controller.markPreviewSeen();
      expect(controller.readyToConfirm, isTrue);

      // "As whom" is only meaningful against a "where". Carrying an identity
      // across a destination change is how an institutional voice ends up on
      // a personal public post.
      controller.chooseDestination(const ShareDestination(
        kind: ShareDestinationKind.publicPost,
        id: '',
        title: 'Publish publicly',
      ));
      expect(controller.actingIdentity, isNull);
      expect(controller.readyToConfirm, isFalse);
    });

    test('an unavailable destination can never be confirmed', () {
      controller.chooseDestination(const ShareDestination(
        kind: ShareDestinationKind.publicPost,
        id: '',
        title: 'Publish publicly',
        available: false,
        unavailableReason: 'You have a post in progress.',
      ));
      controller.chooseIdentity(identity);
      controller.markPreviewSeen();
      expect(controller.readyToConfirm, isFalse);
      expect(controller.blockedReason, 'You have a post in progress.');
    });
  });

  group('a share survives arriving mid-build', () {
    test('the screen claims the envelope AFTER the frame that mounts it', () {
      // FOUND ON A PHYSICAL PIXEL, 2026-09-04. Every real share ended on
      // "This section ran into a problem" instead of the person's content:
      // `take()` CLEARS the inbox, which is a provider mutation, and
      // `initState` runs while the widget tree is building — so claiming the
      // envelope there threw `Tried to modify a provider while the widget tree
      // was building` from the inbox's own listener.
      //
      // The share had already arrived and been read correctly. It died on the
      // way to being shown, which is why no gate and no headless test caught
      // it: every one of them exercises the controller, and none of them
      // mounts the screen against a live provider mid-build.
      final screen = File(
        '$_featureDir/presentation/share_intake_screen.dart',
      ).readAsStringSync();

      final initAt = screen.indexOf('void initState()');
      expect(initAt, greaterThan(-1));
      final initState = screen.substring(
        initAt,
        screen.indexOf('void _claimPendingShare', initAt),
      );

      expect(
        initState.contains('addPostFrameCallback'),
        isTrue,
        reason: 'The claim must wait for the frame that mounts this screen.',
      );
      expect(
        initState.contains('.take()'),
        isFalse,
        reason: 'Claiming inside initState mutates a provider during build.',
      );
    });

    test('navigation to the destination also waits for the frame', () {
      // Same cause, the other half of the chain: delivery notifies while the
      // tree is building, and `go()` would rebuild the router inside that
      // build.
      final app = File('lib/app/aura_app.dart').readAsStringSync();
      final at = app.indexOf('shareIntakeInboxProvider,');
      expect(at, greaterThan(-1));
      final listener = app.substring(at, at + 1200);
      expect(listener.contains('addPostFrameCallback'), isTrue);
    });
  });

  group('what the envelope carries', () {
    test('an envelope has no destination, identity or publish notion', () {
      final envelope =
          File('$_featureDir/domain/acquisition_envelope.dart').readAsStringSync();
      final code = _codeOnly(envelope);
      for (final needle in ['destination', 'actingIdentity', 'publish']) {
        expect(
          code.toLowerCase().contains(needle.toLowerCase()),
          isFalse,
          reason: 'A share is an acquisition. "$needle" is decided afterwards, '
              'by a person, with the content in front of them.',
        );
      }
    });

    test('a subject never displaces text the person actually shared', () async {
      final controller = ShareIntakeController(
        AcquisitionEnvelope(
          platform: AcquisitionPlatform.android,
          receivedAt: DateTime.now(),
          subject: 'Shared from SomeApp',
          payloads: const [
            AcquiredPayload(
              kind: AcquiredPayloadKind.url,
              text: 'https://example.org/a',
            ),
          ],
        ),
      );
      await controller.resolve();
      expect(controller.body, 'https://example.org/a');
    });
  });
}

AcquisitionEnvelope _textEnvelope() => AcquisitionEnvelope(
      platform: AcquisitionPlatform.android,
      receivedAt: DateTime.now(),
      payloads: const [
        AcquiredPayload(kind: AcquiredPayloadKind.text, text: 'hello'),
      ],
    );

/// A real 1×1 PNG, so the sniffer has actual bytes to read rather than a
/// header this test asserted into existence.
Uint8List _png() => base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8'
      'z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    );
