import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Flutter assets keep their names across builds, so the web server must make
/// browsers revalidate them. Served immutable for 30 days, the new wordmark
/// (DD-64, 2026-10-25) stayed invisible to every returning browser.
void main() {
  final docker = File('Dockerfile').readAsStringSync();

  test('/assets/ and /icons/ revalidate ahead of the immutable rule', () {
    for (final prefix in ['/assets/', '/icons/']) {
      final at = docker.indexOf('location ^~ $prefix {');
      expect(at, isNonNegative, reason: '$prefix must have its own rule');
      final rule = docker.substring(at, docker.indexOf('}', at));
      expect(rule, contains('Cache-Control "no-cache"'),
          reason: '$prefix must be no-cache');
      expect(docker.indexOf('location ^~ $prefix'),
          lessThan(docker.indexOf('max-age=2592000, immutable')),
          reason: '$prefix must be declared before the immutable rule');
    }
  });
}
