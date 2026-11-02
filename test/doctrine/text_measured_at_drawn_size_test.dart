import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// TEXT IS MEASURED AT THE SIZE IT IS DRAWN AT.
///
/// 2026-11-02, Windows at Text size 175%: the home Spaces row and a post's
/// "Open" check both measured text at 1.0 and drew it at 1.75 — descriptions
/// were cut in half and a long post stopped at line seven with no way on.
/// Every TextPainter in the app must carry the text scaler in force.
void main() {
  test('every TextPainter in lib/ is given a textScaler', () {
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      var i = src.indexOf('TextPainter(');
      while (i >= 0) {
        // The constructor's own argument list, to its matching parenthesis.
        var depth = 0, j = i + 'TextPainter'.length;
        for (; j < src.length; j++) {
          if (src[j] == '(') depth++;
          if (src[j] == ')' && --depth == 0) break;
        }
        if (!src.substring(i, j).contains('textScaler:')) {
          offenders.add('${f.path}:${'\n'.allMatches(src.substring(0, i)).length + 1}');
        }
        i = src.indexOf('TextPainter(', j);
      }
    }
    expect(offenders, isEmpty,
        reason: 'measure with MediaQuery.textScalerOf(context), or the text '
            'size the widget actually draws at');
  });
}
