import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'html_to_markdown.dart';
import 'rich_clipboard.dart';

/// Item 15 — Rich Paste. Wraps a composer's `TextField`/`TextEditingController`
/// (same "wrap the controller" convention `GovernedTagAutocomplete` and
/// `ComposeLinkDetector` already established -- not a new mechanism) and
/// intercepts Flutter's `PasteTextIntent` (fired uniformly for Ctrl+V/Cmd+V
/// and the context-menu Paste action) to read the clipboard's rich
/// `text/html` flavor where the platform exposes it, converting recognized
/// formatting into Aura's canonical Markdown syntax before insertion.
///
/// Falls back to Flutter's own default plain-text paste whenever: the
/// platform has no rich-clipboard access (everywhere but web today, see
/// `rich_clipboard_io.dart`), the clipboard has no `text/html` flavor, or
/// that flavor's content has no recognized formatting worth converting
/// (`htmlFragmentHasRecognizedFormatting`) -- never worse than today's
/// existing paste behavior, only richer when there is something legitimate
/// to preserve.
class RichPasteField extends StatelessWidget {
  const RichPasteField({
    super.key,
    required this.controller,
    required this.child,
  });

  final TextEditingController controller;
  final Widget child;

  Future<void> _handlePaste() async {
    final html = await readClipboardHtml();
    String? text;
    if (html != null && htmlFragmentHasRecognizedFormatting(html)) {
      text = htmlToMarkdown(html);
    }
    text ??= await Clipboard.getData(Clipboard.kTextPlain).then((d) => d?.text);
    if (text == null || text.isEmpty) return;
    controller.value = applyPastedText(controller.value, text);
  }

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: <Type, Action<Intent>>{
        PasteTextIntent: CallbackAction<PasteTextIntent>(
          onInvoke: (intent) {
            _handlePaste();
            return null;
          },
        ),
      },
      child: child,
    );
  }
}

/// Pure insertion logic, factored out of the widget so it is directly unit
/// -testable without pumping a widget tree or exercising the platform
/// clipboard channel: replaces the current selection (or inserts at the
/// cursor, for a collapsed/invalid selection) with [text], leaving the
/// cursor positioned immediately after the inserted text -- the same
/// placement a normal paste produces.
TextEditingValue applyPastedText(TextEditingValue current, String text) {
  final selection = current.selection;
  final currentText = current.text;
  final validSelection = selection.isValid
      ? selection
      : TextSelection.collapsed(offset: currentText.length);
  final newText = currentText.replaceRange(
    validSelection.start,
    validSelection.end,
    text,
  );
  return TextEditingValue(
    text: newText,
    selection: TextSelection.collapsed(
      offset: validSelection.start + text.length,
    ),
  );
}
