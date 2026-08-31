import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// THE PLATFORM FILES MUST AGREE WITH THE CONTRACT.
///
/// Every defect this suite exists for lived in a platform config file, not in
/// Dart: a manifest with no path data, two missing boolean flags, an AASA
/// claiming a retired family and omitting the one that matters, and a Windows
/// build declaring no association at all. None of it was reachable by any Dart
/// test, none of it broke a build, and all of it shipped.
///
/// So these read the actual files.
void main() {
  final contract = jsonDecode(
    File('contracts/native_continuation_contract.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final scope = contract['associationScope'] as Map<String, dynamic>;
  final hosts = (scope['hosts'] as List).cast<String>();
  final prefixes = (scope['include'] as List)
      .cast<Map<String, dynamic>>()
      .where((e) => e['prefix'] != null)
      .map((e) => e['prefix'] as String)
      .toList();
  final exactPaths = (scope['include'] as List)
      .cast<Map<String, dynamic>>()
      .where((e) => e['path'] != null)
      .map((e) => e['path'] as String)
      .toList();

  group('Android', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    test('Flutter is told to forward links to the router', () {
      // Without this the activity starts and the launch URL is dropped, so
      // every App Link resolves to home. This one line was the difference
      // between an association that validates and a product that continues.
      expect(manifest, contains('flutter_deeplinking_enabled'));
      final block = RegExp(
        r'<meta-data\s+android:name="flutter_deeplinking_enabled"\s+android:value="([^"]+)"',
        dotAll: true,
      ).firstMatch(manifest);
      expect(block, isNotNull);
      expect(block!.group(1), 'true');
    });

    test('the App Links filter declares paths, not a bare host', () {
      // A filter with hosts and NO path data claims every URL on them,
      // private member surfaces included.
      final filter = RegExp(
        r'<intent-filter android:autoVerify="true">(.*?)</intent-filter>',
        dotAll: true,
      ).firstMatch(manifest);
      expect(filter, isNotNull, reason: 'no autoVerify App Links filter');
      final body = filter!.group(1)!;
      expect(body, contains('android:pathPrefix'),
          reason: 'an unscoped host claims every URL on it');
      for (final host in hosts) {
        expect(body, contains('android:host="$host"'));
      }
    });

    test('every contract prefix and exact path is declared', () {
      for (final prefix in prefixes) {
        expect(manifest, contains('android:pathPrefix="$prefix"'),
            reason: '$prefix is eligible but not associated on Android');
      }
      for (final path in exactPaths) {
        expect(manifest, contains('android:path="$path"'), reason: path);
      }
    });

    test('nothing outside the contract is associated', () {
      final declared = RegExp(r'android:pathPrefix="([^"]+)"')
          .allMatches(manifest)
          .map((m) => m.group(1)!)
          .toSet();
      expect(declared, prefixes.toSet(),
          reason: 'Android claims a prefix the contract does not name');
    });
  });

  group('iOS', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final entitlements =
        File('ios/Runner/Runner.entitlements').readAsStringSync();
    final aasa = jsonDecode(
      File('web/.well-known/apple-app-site-association').readAsStringSync(),
    ) as Map<String, dynamic>;
    final components = ((aasa['applinks'] as Map)['details'] as List)
        .cast<Map<String, dynamic>>()
        .first['components'] as List;

    test('Flutter is told to forward Universal Links', () {
      final index = plist.indexOf('FlutterDeepLinkingEnabled');
      expect(index, greaterThan(-1));
      // The value is the next tag after the key.
      expect(plist.substring(index, index + 60), contains('<true/>'));
    });

    test('the entitlement hosts are the contract hosts', () {
      for (final host in hosts) {
        expect(entitlements, contains('applinks:$host'));
      }
    });

    test('every contract prefix and exact path is claimed', () {
      final claimed =
          components.map((c) => (c as Map)['/'] as String).toSet();
      for (final prefix in prefixes) {
        expect(claimed, contains('$prefix*'),
            reason: '$prefix is eligible but not claimed on iOS');
      }
      for (final path in exactPaths) {
        expect(claimed, contains(path), reason: path);
      }
    });

    test('exclusions come FIRST, because components are ordered', () {
      // AASA evaluates in order. An exclusion after the include that matches
      // it never runs, so ordering is behaviour, not tidiness.
      final firstInclude =
          components.indexWhere((c) => (c as Map)['exclude'] != true);
      final lastExclude =
          components.lastIndexWhere((c) => (c as Map)['exclude'] == true);
      expect(lastExclude, lessThan(firstInclude),
          reason: 'an exclusion after its include never applies');
    });

    test('no retired family is claimed', () {
      final claimed = components.map((c) => (c as Map)['/'] as String);
      expect(claimed.any((c) => c.contains('threads')), isFalse,
          reason: 'Thread was retired; claiming it associates a dead family');
    });
  });

  group('Windows', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final webLink = jsonDecode(
      File('web/.well-known/windows-app-web-link').readAsStringSync(),
    ) as Map<String, dynamic>;

    test('both association mechanisms are declared', () {
      expect(pubspec, contains('protocol_activation:'));
      expect(pubspec, contains('app_uri_handler_hosts:'));
      for (final host in hosts) {
        expect(pubspec, contains(host));
      }
    });

    test('the web link names a package family', () {
      final family = webLink['packageFamilyName'] as String;
      expect(family, startsWith('AuraPlatformLLC.AURAPLATFORM_'));
      // The hash is 13 characters of Microsoft's 32-character alphabet.
      final hash = family.split('_').last;
      expect(hash.length, 13);
      expect(RegExp(r'^[0-9abcdefghjkmnpqrstvwxyz]{13}$').hasMatch(hash), isTrue,
          reason: 'not a valid package family hash: $hash');
    });

    test('its paths are the contract paths', () {
      final paths = (webLink['paths'] as List).cast<String>().toSet();
      for (final prefix in prefixes) {
        expect(paths, contains('$prefix*'), reason: prefix);
      }
      for (final path in exactPaths) {
        expect(paths, contains(path), reason: path);
      }
    });
  });

  group('the association files are served', () {
    final dockerfile = File('Dockerfile').readAsStringSync();

    test('every association file has a location on the primary host', () {
      for (final name in const [
        'assetlinks.json',
        'apple-app-site-association',
        'windows-app-web-link',
      ]) {
        expect(dockerfile, contains('/.well-known/$name'), reason: name);
      }
    });

    test('the legacy host serves all three, not just assetlinks', () {
      // Apple and Windows verify against the tapped host and neither follows
      // redirects, so a host that 301s these can never verify. Android needed
      // this fix once already.
      final legacy = RegExp(
        r'server_name\s+app\.auraplatform\.org(.*?)location / \{',
        dotAll: true,
      ).firstMatch(dockerfile);
      expect(legacy, isNotNull, reason: 'legacy host block not found');
      final body = legacy!.group(1)!;
      for (final name in const [
        'assetlinks.json',
        'apple-app-site-association',
        'windows-app-web-link',
      ]) {
        expect(body, contains(name),
            reason: '$name is unreachable on app.auraplatform.org');
      }
    });

    test('extensionless association files declare application/json', () {
      // They otherwise fall to nginx default_type and are served as
      // application/octet-stream.
      final matches = RegExp(
        r'location = /\.well-known/(apple-app-site-association|windows-app-web-link) \{(.*?)\}',
        dotAll: true,
      ).allMatches(dockerfile);
      expect(matches.length, greaterThanOrEqualTo(2));
      for (final m in matches) {
        expect(m.group(2), contains('application/json'), reason: m.group(1));
      }
    });
  });
}
