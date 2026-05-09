// Post-composer model file.
//
// `ComposeAttachment`, `ComposeAttachmentType`, and `ComposeAttachmentSource`
// were removed in the C1 attachment-model consolidation. The post composer
// now uses the canonical `Attachment` / `AttachmentKind` / `AttachmentSource`
// from `lib/core/media/`. Per-attachment caption `TextEditingController`
// objects (which were owned by the old `ComposeAttachment`) are now held
// in a parallel `Map<String, TextEditingController>` on the screen state,
// keyed by `attachment.localId` — see `compose_screen.dart`.
//
// `PostVisibility` and the language helpers below are unrelated to media
// and remain here.

// ─────────────────────────────────────────────────────────────────────────────
// ENUMS
// ─────────────────────────────────────────────────────────────────────────────

enum PostVisibility { public, followers, private }

// ─────────────────────────────────────────────────────────────────────────────
// LANGUAGE CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────

const Map<String, String> kComposeLanguageLabels = {
  'en': 'English',
  'ur': 'Urdu',
  'ar': 'Arabic',
  'es': 'Spanish',
  'fr': 'French',
  'de': 'German',
  'it': 'Italian',
  'pt': 'Portuguese',
  'tr': 'Turkish',
  'fa': 'Persian',
  'hi': 'Hindi',
  'bn': 'Bengali',
  'zh': 'Chinese',
  'ja': 'Japanese',
  'ko': 'Korean',
  'ru': 'Russian',
};

String composeLanguageLabel(String code) {
  final key = code.trim().toLowerCase();
  if (key.isEmpty) return '';
  return kComposeLanguageLabels[key] ?? key.toUpperCase();
}
