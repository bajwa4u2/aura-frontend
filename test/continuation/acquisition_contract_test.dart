import 'dart:convert';
import 'dart:io';

import 'package:aura/core/continuation/acquisition_contract.dart';
import 'package:flutter_test/flutter_test.dart';

/// THE DART MIRROR MUST NOT DRIFT FROM THE CONTRACT.
///
/// A Dart constant list is easy to edit and impossible to notice. The whole
/// point of the contract is that eligibility lives in ONE place; this is what
/// stops the mirror quietly becoming a second opinion.
void main() {
  final contract = jsonDecode(
    File('contracts/native_continuation_contract.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  final scope = contract['associationScope'] as Map<String, dynamic>;
  final includes = (scope['include'] as List).cast<Map<String, dynamic>>();

  test('eligible prefixes match the association scope exactly', () {
    final fromContract = includes
        .where((e) => e['prefix'] != null)
        .map((e) => e['prefix'] as String)
        .toSet();
    expect(kEligiblePrefixes.toSet(), fromContract);
  });

  test('eligible exact paths match the association scope exactly', () {
    final fromContract = includes
        .where((e) => e['path'] != null)
        .map((e) => e['path'] as String)
        .toSet();
    expect(kEligibleExactPaths, fromContract);
  });

  test('store destinations match the contract', () {
    final stores = contract['storeDestinations'] as Map<String, dynamic>;
    expect(kAndroidStoreUrl, stores['android']);
    expect(kIosStoreUrl, stores['ios']);
    expect(kWindowsStoreUrl, stores['windows']);
  });

  test('shipped-in-client flags match the contract', () {
    final platforms = contract['platformContinuation'] as Map<String, dynamic>;
    expect(kAndroidContinuationShipped,
        (platforms['android'] as Map)['shippedInClient']);
    expect(kIosContinuationShipped, (platforms['ios'] as Map)['shippedInClient']);
    expect(kWindowsContinuationShipped,
        (platforms['windows'] as Map)['shippedInClient']);
  });

  test('every platform has association configured in this tree', () {
    // The three platforms are configured here even though none has shipped.
    // If one of these ever reads false, the corresponding platform files were
    // reverted and continuation is silently dead on it.
    final platforms = contract['platformContinuation'] as Map<String, dynamic>;
    for (final key in const ['android', 'ios', 'windows']) {
      expect((platforms[key] as Map)['associationConfigured'], isTrue,
          reason: '$key association is not configured');
    }
  });

  test('the acquisition surface is dismissible and non-blocking', () {
    final web = contract['webAcquisition'] as Map<String, dynamic>;
    expect(web['dismissible'], isTrue);
    expect(web['blocking'], isFalse);
    expect(web['eligibilitySource'], 'associationScope.include');
  });

  test('every excluded pattern is refused by the eligibility function', () {
    const probes = <String, String>{
      '/posts/*/edit': '/posts/abc/edit',
      '/articles/write*': '/articles/write',
      '/announcements/create': '/announcements/create',
      '/institutions/get-started': '/institutions/get-started',
      '/home*': '/home',
      '/messages*': '/messages',
      '/me*': '/me',
      '/admin*': '/admin',
      '/settings*': '/settings',
    };
    for (final entry in (scope['exclude'] as List).cast<Map>()) {
      final probe = probes[entry['pattern'] as String];
      expect(probe, isNotNull, reason: 'no probe for ${entry['pattern']}');
      expect(isContinuationEligiblePath(probe!), isFalse, reason: probe);
    }
  });
}
