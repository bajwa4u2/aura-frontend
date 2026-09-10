// FEEDBACK / RATE / VERSION — A SHARED PRODUCT CAPABILITY.
//
// Founder ruling: these three are a cross-platform product capability, not a
// store-review workaround. The failure this file guards against is not that
// they are missing — it is that they drift into three different answers:
// feedback routed through app-store reviews, a rating control invented on a
// platform with nowhere to send it, and a version typed into a widget that
// silently disagrees with the binary a person is running.
//
// Targets:
//   FEEDBACK_CAPABILITY_AUTHORITIES = 1
//   RATE_PLATFORM_MAPPING           = canonical
//   HARDCODED_VERSION_UI            = 0

import 'dart:io';

import 'package:aura/core/review/rate_aura.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

const _header = 'lib/app/shell/shell_header_tools.dart';
const _drawer = 'lib/app/shell/member_shell.dart';
const _rate = 'lib/core/review/rate_aura.dart';

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

void main() {
  group('FEEDBACK_CAPABILITY_AUTHORITIES = 1', () {
    test('both widths reach the same feedback destination', () {
      // The drawer has carried feedback for some time and the desktop menu did
      // not, so the same capability existed on one width and not the other.
      expect(_read(_drawer).contains("'/feedback'"), isTrue);
      expect(
        _read(_header).contains('NavigationAuthority.feedbackRoute'),
        isTrue,
      );
    });

    test('feedback is not routed through a store review', () {
      // Store review is for rating. Reporting that something is broken must
      // not become a public star rating, and a person with a bug to report
      // must not be handed a review sheet.
      final header = _codeOnly(_read(_header));
      final feedbackAt = header.indexOf("case 'feedback':");
      expect(feedbackAt, greaterThan(-1));
      // BOUNDED TO ITS OWN CASE. A fixed-size slice runs into the next one,
      // which is the rate handler — so a naive window would report the two
      // capabilities as tangled precisely because they sit next to each other.
      final handler = header.substring(
        feedbackAt,
        header.indexOf("case '", feedbackAt + 10),
      );
      expect(handler.contains('openRateAura'), isFalse);
      expect(handler.contains('InAppReview'), isFalse);
    });
  });

  group('RATE_PLATFORM_MAPPING = canonical', () {
    test('each platform maps to its own store, and web to none', () {
      expect(rateDestinationFor(TargetPlatform.android),
          RateDestination.playStore);
      expect(rateDestinationFor(TargetPlatform.iOS), RateDestination.appStore);
      expect(rateDestinationFor(TargetPlatform.windows),
          RateDestination.microsoftStore);
      expect(rateDestinationFor(TargetPlatform.linux), RateDestination.none);
    });

    test('web has no rating destination, on any platform', () {
      // A five-star widget that posts nowhere is a fiction, and symmetry with
      // the native clients is not a reason to ship one.
      for (final platform in TargetPlatform.values) {
        expect(
          rateDestinationFor(platform, web: true),
          RateDestination.none,
          reason: '$platform on web must offer no rating destination.',
        );
      }
    });

    test('the control is absent where there is nowhere to send it', () {
      // Shown-and-inert is the failure mode this guards: a control that does
      // nothing is worse than no control.
      expect(_read(_header).contains('if (rateDestination.exists)'), isTrue);
      expect(_read(_drawer).contains('if (rateDestination.exists)'), isTrue);
    });

    test('store ids are taken from the canonical destinations', () {
      final code = _codeOnly(_read(_rate));
      expect(code.contains('kWindowsStoreUrl'), isTrue);
      expect(code.contains('kIosStoreUrl'), isTrue);
      expect(code.contains('kAndroidStoreUrl'), isTrue);
      // Typed a second time is how a listing drifts from the contract that
      // publishes it.
      expect(code.contains('apps.microsoft.com'), isFalse);
      expect(code.contains('play.google.com'), isFalse);
      expect(code.contains('apps.apple.com'), isFalse);
    });

    test('an explicit press opens the listing, never the in-app sheet', () {
      // Google's In-App Review quota is silent, so a button wired to it can do
      // nothing at all with no explanation; Apple says the same of
      // SKStoreReviewController. A button has to take you somewhere.
      final code = _codeOnly(_read(_rate));
      expect(code.contains('openStoreListing'), isTrue);
      expect(
        code.contains('requestReview'),
        isFalse,
        reason: 'requestReview is the unsolicited prompt, not a button.',
      );
    });

    test('the deliberate path is not gated by the prompt cool-down', () {
      // `StoreReviewService.maybeAsk` refuses most moments by name, which is
      // right for something nobody asked for and wrong for a control someone
      // went looking for and pressed.
      final code = _codeOnly(_read(_rate));
      expect(code.contains('maybeAsk'), isFalse);
      expect(code.contains('ReviewMoment'), isFalse);
    });
  });

  group('HARDCODED_VERSION_UI = 0', () {
    test('the version comes from the canonical client identity', () {
      final code = _codeOnly(_read(_rate));
      expect(code.contains('clientIdentitySnapshotProvider'), isTrue);
      expect(code.contains('appVersion'), isTrue);
    });

    test('no shell surface types a version literal', () {
      // A version written into a widget disagrees with the binary the moment
      // someone forgets to update it — silently, in the one place a person
      // looks to tell support what they are running.
      final pattern = RegExp(r'''['"]\s*(Version\s+)?\d+\.\d+\.\d+''');
      for (final path in const [_header, _drawer, _rate]) {
        expect(
          pattern.hasMatch(_codeOnly(_read(path))),
          isFalse,
          reason: '$path contains a version literal.',
        );
      }
    });

    test('both widths render the version from the same provider', () {
      expect(_read(_header).contains('appVersionLabelProvider'), isTrue);
      expect(_read(_drawer).contains('appVersionLabelProvider'), isTrue);
    });

    test('it is not a control and not diagnostics', () {
      // Disabled in the menu, plain text in the drawer. A menu that becomes
      // developer diagnostics stops being an account menu.
      expect(_read(_header).contains('enabled: false'), isTrue);
      final drawer = _read(_drawer);
      final at = drawer.indexOf('appVersionLabelProvider');
      expect(at, greaterThan(-1));
    });

    test('an unresolved version renders nothing, not a placeholder', () {
      final code = _codeOnly(_read(_rate));
      expect(code.contains('if (version.isEmpty) return null;'), isTrue);
      expect(_read(_header).contains('if (version case final String label)'),
          isTrue);
      expect(_read(_drawer).contains('if (version case final String label)'),
          isTrue);
    });
  });

  /// THE VERSION GATE, REWRITTEN SO IT GATES SOMETHING.
  ///
  /// It used to hard-code `1.4.2` and assert pubspec still said that — which
  /// meant every legitimate version bump turned the build red for doing exactly
  /// what a release does. It caught 1.4.3 on the first CI run of this release
  /// and failed the TestFlight lane before it reached signing. A gate that
  /// fires on the intended change is not a gate, it is a tripwire across the
  /// doorway.
  ///
  /// What is actually worth pinning is DERIVED, not literal: that a version
  /// exists in the shape the stores require, that the build number only moves
  /// forward, that the MSIX version tracks it — and, the thing this group was
  /// named after and never checked, that iOS resolves its version FROM pubspec
  /// rather than from a literal in the Xcode project. A pinned MARKETING_VERSION
  /// there would silently ship 1.4.2 while pubspec said 1.4.3, and nothing else
  /// in this repository would have noticed.
  group('the marketing version is derived, and reaches every platform', () {
    test('pubspec declares a semantic version and a build number', () {
      final pubspec = _read('pubspec.yaml');
      final match =
          RegExp(r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)', multiLine: true)
              .firstMatch(pubspec);
      expect(match, isNotNull,
          reason: 'the stores need both halves; a bare version is not shippable');
      // Monotonic against the last number a store actually accepted, which is
      // the only number that can never be reused.
      expect(int.parse(match!.group(2)!), greaterThanOrEqualTo(37),
          reason: 'build 37 shipped; a lower number cannot be uploaded again');
    });

    test('iOS takes its version from pubspec, not from a literal in the project',
        () {
      // The Runner reads CFBundleShortVersionString / CFBundleVersion from the
      // Flutter build variables, and the Xcode project must not override them
      // with a pinned MARKETING_VERSION — that is how an IPA ends up declaring
      // a version the pubspec has already moved past.
      final plist = _read('ios/Runner/Info.plist');
      expect(plist.contains(r'$(FLUTTER_BUILD_NAME)'), isTrue,
          reason: 'CFBundleShortVersionString is not wired to the Flutter build name');
      expect(plist.contains(r'$(FLUTTER_BUILD_NUMBER)'), isTrue,
          reason: 'CFBundleVersion is not wired to the Flutter build number');

      final pbx = _read('ios/Runner.xcodeproj/project.pbxproj');
      final runnerConfigs = RegExp(
              r'isa = XCBuildConfiguration;(.*?)name = ([A-Za-z]+);',
              dotAll: true)
          .allMatches(pbx)
          .where((m) =>
              RegExp(r'PRODUCT_BUNDLE_IDENTIFIER = org\.auraplatform\.app;')
                  .hasMatch(m.group(1)!));
      expect(runnerConfigs, isNotEmpty,
          reason: 'found no Runner build configuration to audit');

      for (final cfg in runnerConfigs) {
        final body = cfg.group(1)!;
        final pinned = RegExp(r'MARKETING_VERSION = (?!"\$\(FLUTTER)([^;]+);')
            .firstMatch(body);
        expect(pinned, isNull,
            reason: 'Runner/${cfg.group(2)} pins MARKETING_VERSION='
                '${pinned?.group(1)}, which would ship a version pubspec has moved past');
      }
    });

    test('the MSIX version tracks it, which the Store requires', () {
      final pubspec = _read('pubspec.yaml');
      final version =
          RegExp(r'^version:\s*(\d+\.\d+\.\d+)', multiLine: true)
              .firstMatch(pubspec)!
              .group(1);
      final msix = RegExp(r'msix_version:\s*(\d+\.\d+\.\d+\.\d+)')
          .firstMatch(pubspec)!
          .group(1);
      // Partner Center validates this, and a mismatch is a hard certification
      // failure rather than a warning.
      expect(msix, '$version.0');
    });
  });

  group('no new permanent header row', () {
    test('the three controls live inside the account menu', () {
      // Founder: do not add another permanent header row, and do not create
      // developer-looking release controls. Permanent header width is for
      // immediate attention; none of these is that.
      final header = _read(_header);
      final menuAt = header.indexOf('class _HeaderAccountBtn');
      expect(menuAt, greaterThan(-1));
      final menu = header.substring(menuAt);
      expect(menu.contains("'feedback'"), isTrue);
      expect(menu.contains("'rate'"), isTrue);
      expect(menu.contains('version'), isTrue);
    });
  });
}
