/// Item 15 — the client-side mirror of the backend's deterministic
/// plain-text projection (`aura-backend/src/common/content/markdown-plain-text.ts`).
/// Used where a rendered rich body needs a plain-text representation
/// without a round trip to the server -- primarily the clipboard's
/// plain-text flavor (§H: "Aura-only structured clipboard data" must never
/// be the sole representation; copying legitimate Aura content must still
/// interoperate with any plain-text paste target).
///
/// Keep in sync with the backend function's behavior; both implement the
/// same canonical vocabulary (`rich-content-policy.ts`).
String markdownToPlainText(String raw) {
  var text = raw;

  // Images and links -- keep the human-readable label, drop the target.
  text = text.replaceAllMapped(
    RegExp(r'!\[([^\]]*)\]\([^)]*\)'),
    (m) => m.group(1) ?? '',
  );
  text = text.replaceAllMapped(
    RegExp(r'\[([^\]]*)\]\([^)]*\)'),
    (m) => m.group(1) ?? '',
  );

  // Fenced and inline code -- keep the contained text.
  text = text.replaceAllMapped(
    RegExp(r'```[a-zA-Z0-9]*\n([\s\S]*?)```'),
    (m) => m.group(1) ?? '',
  );
  text = text.replaceAllMapped(RegExp(r'`([^`]*)`'), (m) => m.group(1) ?? '');

  // Block-level markers at the start of a line.
  text = text.replaceAll(RegExp(r'^ {0,3}#{1,6}\s+', multiLine: true), '');
  text = text.replaceAll(RegExp(r'^ {0,3}>\s?', multiLine: true), '');
  text = text.replaceAll(RegExp(r'^ {0,3}[-*+]\s+', multiLine: true), '');
  text = text.replaceAll(RegExp(r'^ {0,3}\d+\.\s+', multiLine: true), '');

  // Emphasis markers.
  text = text.replaceAllMapped(
    RegExp(r'(\*\*\*|___)(.+?)\1'),
    (m) => m.group(2) ?? '',
  );
  text = text.replaceAllMapped(
    RegExp(r'(\*\*|__)(.+?)\1'),
    (m) => m.group(2) ?? '',
  );
  text = text.replaceAllMapped(
    RegExp(r'(\*|_)(.+?)\1'),
    (m) => m.group(2) ?? '',
  );

  text = text.replaceAll(RegExp(r'[ \t]+\n'), '\n');
  text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');

  return text.trim();
}
