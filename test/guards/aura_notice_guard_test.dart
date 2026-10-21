import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every message a person sees after an action goes through AuraNotice
/// (founder-approved spec, 21 Oct 2026). These guards keep it that way.
void main() {
  List<File> dartFiles() => Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  String norm(String path) => path.replaceAll('\\', '/');

  test('no showSnackBar outside the notice itself', () {
    final offenders = <String>[];
    for (final file in dartFiles()) {
      if (norm(file.path).endsWith('lib/core/ui/aura_notice.dart')) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains('showSnackBar(')) {
          offenders.add('${file.path}:${i + 1}');
        }
      }
    }
    expect(offenders, isEmpty, reason: 'Use AuraNotice.done/info/problem');
  });

  test('no notice is built from raw error text', () {
    final call = RegExp(
      r'(AuraNotice\.(done|info|problem|show|copied)|\.(done|info|problem))\(',
    );
    final raw = RegExp(
      r"\$e\b|\$\{e\}|\$err\b|\$error\b|\b(e|err|error)\.toString\(\)",
    );
    final offenders = <String>[];
    for (final file in dartFiles()) {
      final source = file.readAsStringSync();
      if (!source.contains('aura_notice.dart') &&
          !norm(file.path).endsWith('lib/core/ui/aura_notice.dart')) {
        continue;
      }
      for (final match in call.allMatches(source)) {
        var depth = 1;
        var i = match.end;
        while (i < source.length && depth > 0) {
          if (source[i] == '(') depth++;
          if (source[i] == ')') depth--;
          i++;
        }
        final args = source.substring(match.end, i);
        if (raw.hasMatch(args)) {
          final line = '\n'.allMatches(source.substring(0, match.start)).length + 1;
          offenders.add('${file.path}:$line');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'Say what failed and what to do, never the exception');
  });

  test('exactly one snackbar theme exists', () {
    var count = 0;
    for (final file in dartFiles()) {
      count += 'snackBarTheme:'.allMatches(file.readAsStringSync()).length;
    }
    expect(count, 1);
  });
}
