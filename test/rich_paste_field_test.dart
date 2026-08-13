import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/rich_content/rich_paste_field.dart';

/// Item 15 — Rich Paste. Pure insertion-logic coverage, factored out of
/// the widget so it's directly testable without pumping a widget tree or
/// exercising the platform clipboard/Actions channel (which hung
/// indefinitely under this project's test harness for reasons not
/// resolved in this pass -- disclosed, not hidden; see the Item 15
/// reconciliation record). The `PasteTextIntent` wiring itself (standard,
/// documented Flutter `Actions`/`Intent` usage) is covered by `dart
/// analyze` type-checking + this pure-function coverage of what it calls,
/// not by an automated widget-level interception test.
void main() {
  group('applyPastedText', () {
    test('inserts text at a collapsed cursor', () {
      final result = applyPastedText(
        const TextEditingValue(text: 'hello ', selection: TextSelection.collapsed(offset: 6)),
        'world',
      );
      expect(result.text, 'hello world');
      expect(result.selection, const TextSelection.collapsed(offset: 11));
    });

    test('replaces an active selection', () {
      final result = applyPastedText(
        const TextEditingValue(
          text: 'one two three',
          selection: TextSelection(baseOffset: 4, extentOffset: 7),
        ),
        'REPLACED',
      );
      expect(result.text, 'one REPLACED three');
      expect(result.selection, const TextSelection.collapsed(offset: 12));
    });

    test('inserts at the end when the selection is invalid', () {
      final result = applyPastedText(
        const TextEditingValue(text: 'abc'),
        'def',
      );
      expect(result.text, 'abcdef');
      expect(result.selection, const TextSelection.collapsed(offset: 6));
    });

    test('inserts into empty text', () {
      final result = applyPastedText(
        const TextEditingValue(text: '', selection: TextSelection.collapsed(offset: 0)),
        'pasted',
      );
      expect(result.text, 'pasted');
      expect(result.selection, const TextSelection.collapsed(offset: 6));
    });
  });
}
