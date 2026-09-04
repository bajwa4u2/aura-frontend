// TRACK B4 — WINDOWS SHARE TARGET.
//
// Windows delivers a share by ACTIVATING the application and handing it a
// `ShareOperation`. That is a property of PACKAGE IDENTITY: the target is
// declared in the MSIX manifest, so a loose `aura.exe` out of the build
// directory is not a share target and never will be. The runner already
// records that truth for the WNS channel, for the same reason, and the share
// target says it the same way.
//
// The manifest declaration cannot be expressed in `msix_config` — the package
// builds its manifest from a fixed template with no key for a share target and
// no escape hatch. So it is injected between `msix:build` and `msix:pack`,
// which is a supported flow rather than a patch of a finished package. This
// file holds that tool to the authority it reads from, and holds the C++ to
// the same rules the other two platforms keep.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _cpp = 'windows/runner/share_intake.cpp';
const _header = 'windows/runner/share_intake.h';
const _cmake = 'windows/runner/CMakeLists.txt';
const _window = 'windows/runner/flutter_window.cpp';
const _tool = 'tool/windows/declare_share_target.dart';
const _packager = 'tool/windows/package_windows.dart';
const _mimeAuthority = 'lib/core/media/media_mime.dart';

String _read(String path) {
  final file = File(path);
  if (!file.existsSync()) throw StateError('$path is missing.');
  return file.readAsStringSync();
}

String _codeOnly(String source) => source
    .split('\n')
    .where((line) {
      final trimmed = line.trimLeft();
      return !trimmed.startsWith('//') && !trimmed.startsWith('*');
    })
    .join('\n');

/// The extensions the tool would declare, derived the way the tool derives
/// them — from `inferMimeFromFileName` itself.
Set<String> _authorityExtensions() {
  final text = _read(_mimeAuthority);
  final start = text.indexOf('String? inferMimeFromFileName(');
  final end = text.indexOf('\n}', start);
  final body = text.substring(start, end);
  return RegExp(r"case '([a-z0-9]+)':")
      .allMatches(body)
      .map((m) => '.${m.group(1)}')
      .toSet();
}

void main() {
  group('the declaration is derived, never hand-listed', () {
    test('the tool reads the same authority intake reads', () {
      final tool = _read(_tool);
      expect(tool.contains('inferMimeFromFileName'), isTrue);
      expect(tool.contains(_mimeAuthority), isTrue);
    });

    test('no file extension is written down in the tool', () {
      // A hand-written list here would be a fourth place the accepted set is
      // recorded, and the first one to go stale.
      final code = _codeOnly(_read(_tool));
      for (final extension in const ['.jpg', '.png', '.pdf', '.mp4', '.docx']) {
        expect(
          code.contains("'$extension'"),
          isFalse,
          reason: '$extension is listed rather than derived.',
        );
      }
    });

    test('the authority yields a real set to declare', () {
      final extensions = _authorityExtensions();
      expect(extensions.length, greaterThan(20));
      // Spot-checks against the classes intake accepts, so a parse that
      // silently returned nothing cannot pass this file.
      expect(extensions, containsAll(<String>['.jpg', '.png', '.pdf', '.mp4']));
      expect(
        extensions,
        containsAll(<String>['.heic', '.heif']),
        reason: 'Intake re-encodes these; refusing them at the door would '
            'refuse most photographs.',
      );
    });

    test('it refuses to declare a share target that promises nothing', () {
      // A parse that came back empty must fail loudly. Declaring a share
      // target with no supported types would put Aura in the share sheet and
      // then decline everything.
      expect(_read(_tool).contains('Refusing to'), isTrue);
      expect(_read(_tool).contains('exit(1)'), isTrue);
    });

    test('it is idempotent, so a repeated build cannot double-declare', () {
      expect(_read(_tool).contains('already declared'), isTrue);
    });
  });

  group('the runner transports, and decides nothing', () {
    test('it names no destination, identity or publication', () {
      final code = _codeOnly(_read(_cpp));
      for (final forbidden in const [
        'conversation',
        'destination',
        'publish',
        'actingIdentity',
        'token',
        'recent',
      ]) {
        expect(
          code.toLowerCase().contains(forbidden.toLowerCase()),
          isFalse,
          reason: 'Windows carries content into Aura. "$forbidden" is decided '
              'in Aura, by a person.',
        );
      }
    });

    test('it classifies nothing — the bytes are read in Dart', () {
      final code = _codeOnly(_read(_cpp));
      // ContentType() is recorded as a claim and passed on. The moment C++
      // decided what something IS, there would be two answers to that
      // question and one of them would be wrong first.
      expect(code.contains('image/'), isFalse);
      expect(code.contains('video/'), isFalse);
      expect(code.contains('isAllowed'), isFalse);
    });

    test('content is taken while the share operation is still alive', () {
      final code = _codeOnly(_read(_cpp));
      // The files belong to the SENDING application and are not guaranteed to
      // outlive the operation — the same judgement Android makes about an
      // intent-scoped read grant.
      expect(code.contains('CopyAsync'), isTrue);
      expect(code.contains('ShareFolder()'), isTrue);
    });

    test('an oversized item is refused before it is copied', () {
      final code = _codeOnly(_read(_cpp));
      expect(code.contains('kMaxItemBytes'), isTrue);
      // The SAME ceiling as every other door.
      expect(code.contains('150ull * 1024 * 1024'), isTrue);
    });

    test('Windows is told the share is finished with', () {
      // Without this the sharing UI stays open and the person is stranded in
      // the other application's sheet.
      expect(_read(_cpp).contains('ReportCompleted()'), isTrue);
    });

    test('a share is handed over at most once', () {
      final code = _codeOnly(_read(_cpp));
      expect(code.contains('consumePendingShare'), isTrue);
      expect(code.contains('g_pending = nullptr'), isTrue);
    });

    test('the copies are not left on the person\'s machine', () {
      final code = _codeOnly(_read(_cpp));
      expect(code.contains('releaseSharedContent'), isTrue);
      expect(code.contains('ClearLocal'), isTrue);
    });

    test('an unpackaged run answers honestly instead of crashing', () {
      final source = _read(_cpp);
      // `flutter run -d windows` has no package identity and therefore no
      // activation args. That is the ordinary development case and it is not
      // an error.
      expect(source.contains('catch (winrt::hresult_error const&)'), isTrue);
      expect(_read(_header).contains('PACKAGE IDENTITY'), isTrue);
    });
  });

  group('it is actually in the build', () {
    test('the source is compiled into the runner', () {
      expect(_read(_cmake).contains('"share_intake.cpp"'), isTrue);
    });

    test('the channel is registered before the first frame', () {
      final window = _read(_window);
      expect(window.contains('#include "share_intake.h"'), isTrue);
      expect(window.contains('RegisterShareIntake('), isTrue);
    });

    test('WinRT is linked', () {
      expect(_read(_cmake).contains('windowsapp.lib'), isTrue);
    });
  });

  group('one channel, three platforms', () {
    test('Windows answers on the shared channel name', () {
      expect(
        _read(_cpp).contains('org.auraplatform.app/share_intake'),
        isTrue,
      );
    });

    test('it answers the same two methods the others do', () {
      final source = _read(_cpp);
      expect(source.contains('"consumePendingShare"'), isTrue);
      expect(source.contains('"releaseSharedContent"'), isTrue);
    });

    test('it speaks the envelope the Dart adapter parses', () {
      final source = _read(_cpp);
      for (final key in const [
        'platform',
        'payloads',
        'refusals',
        'receivedAt',
        'subject',
        'filePath',
        'declaredMimeType',
      ]) {
        expect(source.contains('"$key"'), isTrue, reason: '$key is missing.');
      }
    });
  });

  group('packaging cannot silently drop the share target', () {
    test('there is ONE canonical packaging command', () {
      // Three steps that a person has to remember is not a release step.
      // `dart run msix:create` is the obvious command, it regenerates the
      // manifest, it drops the declaration, and it SUCCEEDS.
      final canonical = _read(_packager);
      expect(canonical.contains("'run', 'msix:build'"), isTrue);
      expect(canonical.contains("tool/windows/declare_share_target.dart"), isTrue);
      expect(canonical.contains("'run', 'msix:pack'"), isTrue);
    });

    test('it verifies the ARTIFACT, not that the right commands were typed', () {
      final canonical = _read(_packager);
      // The finished .msix is opened and its manifest read. Passing means the
      // package is correct, which is a different claim from "the script ran".
      expect(canonical.contains('verifyPackage'), isTrue);
      expect(canonical.contains('AppxManifest.xml'), isTrue);
      expect(canonical.contains('ZipDecoder'), isTrue);
    });

    test('a package without the declaration is REJECTED, not warned about', () {
      final canonical = _read(_packager);
      expect(canonical.contains('WINDOWS PACKAGE REJECTED'), isTrue);
      expect(canonical.contains('exit(1)'), isTrue);
    });

    test('the gate also guards what the declaration must not displace', () {
      final canonical = _read(_packager);
      // Both are load-bearing continuation mechanisms, and an injection that
      // stepped on either would be a silent regression of a shipped feature.
      expect(canonical.contains('windows.protocol'), isTrue);
      expect(canonical.contains('windows.appUriHandler'), isTrue);
    });

    test('it can be run against an existing package as a release gate', () {
      expect(_read(_packager).contains('--verify-only'), isTrue);
    });

    test('the canonical command is what the release config points at', () {
      // pubspec is where anyone configuring the Windows build looks.
      final pubspec = _read('pubspec.yaml');
      expect(pubspec.contains('tool/windows/package_windows.dart'), isTrue);
    });
  });
}
