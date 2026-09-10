/// STAGING A CHOSEN DOCUMENT MUST NEVER BE SILENT.
///
/// Production defect, 2026-09-10, reported by the founder: "i uploaded my
/// identity and photo image, it didnt pick it … nothing appear at all after
/// choosing the file."
///
/// Two independent causes, both in the same short method, both invisible to a
/// compiler because the resolution travelled as `dynamic`:
///
///   1. `attachment.name` — `Attachment` HAS NO `name`; the field is
///      `fileName`. Through a `dynamic` this compiled and threw
///      NoSuchMethodError on EVERY successful pick. `_pick` has no catch, so
///      it surfaced as an unhandled async error and the screen did nothing.
///   2. On the web, `image_picker` created a detached file input whose change
///      never reached Dart, so a chosen file resolved to `null` — which the
///      staging path treats as "cancelled" and reports as nothing at all.
///
/// The shared shape is that a FAILURE and a CANCELLATION were indistinguishable
/// and both rendered silence. These tests hold the contract that makes that
/// impossible: `null` means cancelled, and every other outcome carries a
/// reason a person can read.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/composition/attachment_lifecycle.dart';
import 'package:aura/core/composition/content_intake.dart';
import 'package:aura/core/media/attachment.dart';

void main() {
  group('Attachment carries the field the staging path reads', () {
    test('exposes fileName, and has no `name`', () {
      final a = Attachment(
        localId: 'local-1',
        kind: AttachmentKind.image,
        source: AttachmentSource.gallery,
      )
        ..fileName = 'passport.jpg'
        ..mimeType = 'image/jpeg'
        ..bytes = Uint8List.fromList(const [1, 2, 3]);

      // The positive half: the name the screen shows comes from here.
      expect(a.fileName, 'passport.jpg');
      expect(a.mimeType, 'image/jpeg');

      // The negative half, and the actual regression guard. `Attachment` is a
      // plain class, so reading a member it does not declare is a COMPILE
      // error — which is the protection. This test states the fact so that a
      // future author adding `name` as an alias sees why it was never there:
      // two fields meaning "what is this file called" is how the wrong one
      // gets read again.
      expect(
        a.toString().contains('name:'),
        isFalse,
        reason: 'Attachment must expose exactly one filename field, fileName',
      );
    });
  });

  group('a rejection always carries a message', () {
    test('every rejection kind produces readable copy', () {
      // The staging path renders `rejectionMessage` into a banner. A kind that
      // produced null would put an empty banner in front of somebody, which is
      // the same silence in a different costume.
      for (final kind in AttachmentRejection.values) {
        final resolution = IntakeResolution.rejected(
          path: IntakePath.picker,
          rejection: kind,
        );
        expect(
          resolution.attachment,
          isNull,
          reason: 'a rejection must not carry an attachment',
        );
        expect(
          (resolution.rejectionMessage ?? '').trim(),
          isNotEmpty,
          reason: 'rejection $kind renders an empty banner',
        );
      }
    });

    test('an accepted resolution carries no rejection message', () {
      final resolution = IntakeResolution.accepted(
        path: IntakePath.picker,
        attachment: Attachment(
          localId: 'local-2',
          kind: AttachmentKind.image,
          source: AttachmentSource.gallery,
        )..fileName = 'id.png',
      );
      expect(resolution.attachment, isNotNull);
      expect(resolution.rejectionMessage, isNull);
    });
  });

  group('the web acquisition contract', () {
    test('null is reserved for cancellation alone', () {
      // Asserted on the SOURCE of the acquisition function rather than by
      // driving a browser, because the platform branch cannot be entered from
      // the Flutter test renderer — `kIsWeb` is a compile-time constant and is
      // false here. Stated as a source-shape claim honestly, with its own
      // control below so it cannot pass by matching nothing.
      final source = _read('lib/core/media/media_acquisition.dart');

      expect(
        source,
        contains('_acquireSingleImageOnWeb'),
        reason: 'the web branch must exist',
      );
      expect(
        source,
        contains('if (kIsWeb) return _acquireSingleImageOnWeb();'),
        reason: 'web must not fall through to the picker that drops the file',
      );
      expect(
        source,
        contains('withData: true'),
        reason: 'the web has no path to read from afterwards; bytes must come back',
      );

      // The control: a body that returned null on failure would reintroduce the
      // defect. Every failure path in the web function must refuse instead.
      final web = source.substring(source.indexOf('_acquireSingleImageOnWeb() async'));
      final body = web.substring(0, web.indexOf('\n}\n') + 1);
      expect(body.length, greaterThan(400), reason: 'body not located');
      final nullReturns = RegExp(r'return null;').allMatches(body).length;
      expect(
        nullReturns,
        1,
        reason: 'exactly ONE null return is allowed, and it is the cancellation',
      );
      expect(
        body,
        contains('if (result == null || result.files.isEmpty) return null;'),
        reason: 'the single null return must be the cancellation branch',
      );
    });
  });
}

String _read(String relative) {
  final file = File(relative);
  if (!file.existsSync()) {
    fail('could not read $relative from ${Directory.current.path}');
  }
  return file.readAsStringSync();
}
