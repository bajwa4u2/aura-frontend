import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Flutter assets keep their names across builds, so the web server must make
/// browsers revalidate them. Served immutable for 30 days, the new wordmark
/// (DD-64, 2026-10-25) stayed invisible to every returning browser.
void main() {
  final docker = File('Dockerfile').readAsStringSync();

  test('/assets/ and /icons/ revalidate ahead of the immutable rule', () {
    for (final prefix in ['/assets/', '/icons/']) {
      final rule = RegExp('location \^~ ${RegExp.escape(prefix)} \{[^}]*no-cache');
      expect(rule.hasMatch(docker), isTrue, reason: '$prefix must be no-cache');
      expect(docker.indexOf('location ^~ $prefix'),
          lessThan(docker.indexOf('immutable')),
          reason: '$prefix must be declared before the immutable rule');
    }
  });
}
