// TRACK B2 — ANDROID SHARE TARGET.
//
// An entry in a share sheet is a PROMISE: it says Aura will take this. The
// manifest is where that promise is made, and `media_mime.dart` is where it is
// kept. This file holds the two together, because they are two files that
// nobody edits at the same time and the failure is invisible until a person
// shares something and is told no.
//
// The manifest cannot be executed here — no Android device, no AVD, no adb —
// so B2 is IMPLEMENTED / UNVERIFIED and never PASS. What CAN be proved is that
// the declaration and the code agree, and that is what this proves.

import 'dart:io';

import 'package:aura/core/media/content_normalizer.dart';
import 'package:aura/core/media/media_mime.dart';
import 'package:flutter_test/flutter_test.dart';

const _manifest = 'android/app/src/main/AndroidManifest.xml';
const _shareIntakeKotlin =
    'android/app/src/main/kotlin/org/auraplatform/app/ShareIntake.kt';
const _mainActivityKotlin =
    'android/app/src/main/kotlin/org/auraplatform/app/MainActivity.kt';

String _read(String path) {
  final file = File(path);
  if (!file.existsSync()) throw StateError('$path is missing.');
  return file.readAsStringSync();
}

/// The `android:mimeType` values inside the share intent-filters.
Set<String> _declaredShareMimes() {
  final manifest = _read(_manifest);
  final mimes = <String>{};
  for (final action in const ['SEND', 'SEND_MULTIPLE']) {
    final start = manifest.indexOf('android.intent.action.$action"');
    expect(start, greaterThan(-1), reason: 'ACTION_$action filter is missing.');
    final end = manifest.indexOf('</intent-filter>', start);
    expect(end, greaterThan(start));
    for (final match in RegExp(r'android:mimeType="([^"]+)"')
        .allMatches(manifest.substring(start, end))) {
      mimes.add(match.group(1)!);
    }
  }
  return mimes;
}

void main() {
  group('the share sheet promises exactly what intake accepts', () {
    test('every declared type is one Aura actually takes', () {
      final unsupported = <String>[];
      for (final mime in _declaredShareMimes()) {
        // HEIC and HEIF are accepted through normalization rather than the
        // allow-list: intake re-encodes them BEFORE judging, so the allow-list
        // never sees them and does not need an exception carved into it.
        if (ContentNormalizer.needsNormalization(mime)) continue;
        if (!isAnyMimeAllowed(mime)) unsupported.add(mime);
      }
      expect(
        unsupported,
        isEmpty,
        reason: 'Aura offers itself in the Android share sheet for these types '
            'and would then refuse them. Appearing in the sheet is a promise; '
            'a refusal afterwards is one a person could not have predicted.',
      );
    });

    test('every type intake accepts is offered in the sheet', () {
      final declared = _declaredShareMimes();
      final missing = <String>[];
      for (final mime in <String>{
        ...kAllowedImageMimes,
        ...kAllowedVideoMimes,
        ...kAllowedAudioMimes,
        ...kAllowedDocumentMimes,
      }) {
        if (!declared.contains(mime)) missing.add(mime);
      }
      expect(
        missing,
        isEmpty,
        reason: 'These are accepted by intake but Aura does not appear in the '
            'share sheet for them. The two lists drift silently, in the '
            'direction nobody notices until someone cannot share a file the '
            'product supports.',
      );
    });

    test('HEIC and HEIF are offered, because intake re-encodes them', () {
      // Photographs from an iPhone reaching an Android share sheet. Refusing
      // them would be refusing the single most-shared thing there is, for a
      // format Aura already handles.
      final declared = _declaredShareMimes();
      for (final mime in kNormalizableImageMimes) {
        expect(declared, contains(mime));
      }
    });

    test('no wildcard type is declared', () {
      final wildcards =
          _declaredShareMimes().where((m) => m.contains('*')).toList();
      expect(
        wildcards,
        isEmpty,
        reason: '`image/*` would put Aura in the share sheet for SVG, which '
            'the backend rejects at five separate gates. `*/*` would put it '
            'there for everything. Every type is enumerated so the sheet says '
            'what is true.',
      );
    });
  });

  group('the manifest declares no more authority than it needs', () {
    test('the share filters grant nothing and name no destination', () {
      final manifest = _read(_manifest);
      final start = manifest.indexOf('android.intent.action.SEND"');
      final end = manifest.indexOf('</intent-filter>', start);
      final filter = manifest.substring(start, end);
      // A share filter that also carried a scheme or a path would be claiming
      // to be a destination rather than a door.
      expect(filter.contains('android:scheme'), isFalse);
      expect(filter.contains('android:pathPrefix'), isFalse);
    });

    test('no permission was added for sharing', () {
      // A share intent carries its own read grant. An app that asked for
      // storage permission in order to receive one would be asking for
      // standing access to everything in exchange for a single file.
      final manifest = _read(_manifest);
      for (final permission in const [
        'READ_EXTERNAL_STORAGE',
        'WRITE_EXTERNAL_STORAGE',
        'MANAGE_EXTERNAL_STORAGE',
        'READ_MEDIA_IMAGES',
        'READ_MEDIA_VIDEO',
      ]) {
        expect(
          manifest.contains(permission),
          isFalse,
          reason: '$permission is not needed to receive a share.',
        );
      }
    });

    test('flutter_deeplinking_enabled sits where Flutter reads it', () {
      // FlutterActivity.shouldHandleDeeplinking() reads
      // getActivityInfo(getComponentName(), GET_META_DATA).metaData, and the
      // Gradle app-link tooling walks <activity> children only. This
      // meta-data lived inside the <receiver> until 2026-09-04, where neither
      // could see it.
      //
      // Runtime was unaffected — FlutterActivityLaunchConfigs.deepLinkEnabled
      // returns true when the key is absent, checked by disassembly rather
      // than assumed. What was affected is the build tooling, which reported
      // deeplinkingFlagEnabled=false and so described the app wrongly. This
      // asserts the declaration is somewhere it is actually read, so it means
      // what it says on the day the default changes or someone needs to turn
      // it off.
      final manifest = _read(_manifest);
      final activityStart = manifest.indexOf('<activity');
      final activityEnd = manifest.indexOf('</activity>');
      expect(activityStart, greaterThan(-1));
      expect(activityEnd, greaterThan(activityStart));

      final insideActivity = manifest.substring(activityStart, activityEnd);
      expect(
        insideActivity.contains('flutter_deeplinking_enabled'),
        isTrue,
        reason: 'Outside the activity element, nothing reads it.',
      );
      expect(
        'flutter_deeplinking_enabled'.allMatches(manifest).length,
        1,
        reason: 'Declared once, in the one place it is read.',
      );
    });
  });

  group('the adapter transports, and decides nothing', () {
    test('it names no destination, identity or publication', () {
      final kotlin = _read(_shareIntakeKotlin);
      for (final forbidden in const [
        'conversation',
        'destination',
        'publish',
        'actingIdentity',
        'token',
      ]) {
        // Comments explain what this file must not do, so the CODE is judged.
        final code = kotlin
            .split('\n')
            .where((line) {
              final t = line.trimLeft();
              return !t.startsWith('//') && !t.startsWith('*') &&
                  !t.startsWith('/*');
            })
            .join('\n');
        expect(
          code.toLowerCase().contains(forbidden.toLowerCase()),
          isFalse,
          reason: 'The Android adapter must carry content and nothing else. '
              '"$forbidden" is decided in Aura, by a person.',
        );
      }
    });

    test('it classifies nothing — the bytes are read in Dart', () {
      final kotlin = _read(_shareIntakeKotlin);
      // No allow-list, no kind decision, no mime judgement. `getType` is
      // recorded as a claim and passed on; the moment Kotlin decided what
      // something IS, there would be two answers to that question.
      expect(kotlin.contains('image/'), isFalse);
      expect(kotlin.contains('video/'), isFalse);
      expect(kotlin.contains('isAllowed'), isFalse);
    });

    test('content is taken while the intent grant is alive', () {
      final kotlin = _read(_shareIntakeKotlin);
      // An Android read grant is scoped to the intent that delivered it.
      // Deferring the read until the person has chosen a destination is a
      // share that works in testing and fails as a permission error in
      // someone's hand.
      expect(kotlin.contains('openInputStream'), isTrue);
      expect(kotlin.contains('EXTRA_STREAM'), isTrue);
    });

    test('an oversized item is refused before it is read', () {
      final kotlin = _read(_shareIntakeKotlin);
      expect(kotlin.contains('MAX_ITEM_BYTES'), isTrue);
      // The SAME ceiling as every other door. A smaller one here would mean a
      // file Aura accepts from the picker is refused from the share sheet,
      // for a reason nobody could work out.
      expect(kotlin.contains('150L * 1024 * 1024'), isTrue);
    });

    test('a share is handed over at most once', () {
      final activity = _read(_mainActivityKotlin);
      expect(activity.contains('consumePendingShare'), isTrue);
      expect(activity.contains('pendingShare = null'), isTrue);
      // The launch intent is re-delivered on resume; without clearing it the
      // same content arrives again, which on that surface means publishing
      // twice.
      expect(activity.contains('removeExtra(Intent.EXTRA_STREAM)'), isTrue);
    });

    test('the copies are not left on the person\'s device', () {
      expect(_read(_shareIntakeKotlin).contains('fun clearCache'), isTrue);
      expect(_read(_mainActivityKotlin).contains('releaseSharedContent'), isTrue);
    });
  });

  group('one channel, three platforms, no Dart branch', () {
    test('the Dart adapter and the Kotlin adapter agree on the name', () {
      const name = 'org.auraplatform.app/share_intake';
      expect(_read(_shareIntakeKotlin).contains(name), isTrue);
      expect(
        File('lib/features/share_intake/application/share_intake_channel.dart')
            .readAsStringSync()
            .contains(name),
        isTrue,
      );
    });

    test('an unimplemented platform is an answer, not a branch', () {
      final channel =
          _read('lib/features/share_intake/application/share_intake_channel.dart');
      // The absence of a share target is discovered by asking, not by
      // checking which platform this is. That is what lets iOS be added in
      // Swift alone.
      expect(channel.contains('MissingPluginException'), isTrue);
      // Judged on the CODE: the file's own documentation names the construct
      // it must not contain, and a gate that tripped on its rationale would
      // teach the next person to delete the rationale.
      final code = channel
          .split('\n')
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');
      expect(code.contains('Platform.is'), isFalse);
    });
  });
}
