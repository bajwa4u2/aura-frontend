import 'package:flutter/material.dart';

/// The Aura content types that can be translated through the canonical
/// `POST /communication/translate` door.
///
/// This mirrors the backend `CommunicationObjectType` enum, and it has drifted
/// from it before: the backend gained `CONVERSATION_MESSAGE` and this list was
/// not updated, so the conversation surface had to bypass the type and send a
/// raw string — the canonical client became the reason to route around the
/// canonical server. `ARTICLE` was missing for the same reason.
///
/// Nothing across a language boundary can make this synchronisation automatic,
/// so the protection is placed where it can work: the backend registry is
/// keyed by its enum and will not compile with a member missing, and a request
/// carrying a type this client does not know is rejected at the edge with a
/// 400 rather than mistranslated. If you add a member here, add its resolver
/// there — the compiler on that side will insist.
enum CommunicationObjectType {
  post,
  institutionPost,
  announcement,
  conversationMessage,
  article;

  /// Wire value expected by `POST /communication/translate`.
  String get wireValue => switch (this) {
    CommunicationObjectType.post => 'POST',
    CommunicationObjectType.institutionPost => 'INSTITUTION_POST',
    CommunicationObjectType.announcement => 'ANNOUNCEMENT',
    CommunicationObjectType.conversationMessage => 'CONVERSATION_MESSAGE',
    CommunicationObjectType.article => 'ARTICLE',
  };
}

const Map<String, String> kTranslationLanguageLabels = {
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

/// ISO 639-1 codes that read right-to-left. Kept as a flat constant so any
/// surface rendering a translation (not just [CommunicationTranslateAction])
/// can apply the same directionality rule.
const Set<String> kRtlLanguageCodes = {
  'ar', // Arabic
  'ur', // Urdu
  'fa', // Persian/Farsi
  'he', // Hebrew
  'ps', // Pashto
  'sd', // Sindhi
  'ug', // Uyghur
  'yi', // Yiddish
  'ku', // Kurdish (Sorani)
  'dv', // Divehi
};

bool isRtlLanguage(String code) => kRtlLanguageCodes.contains(code.trim().toLowerCase());

TextDirection textDirectionFor(String code) =>
    isRtlLanguage(code) ? TextDirection.rtl : TextDirection.ltr;

String translationLanguageLabel(String code) {
  final key = code.trim().toLowerCase();
  return kTranslationLanguageLabels[key] ?? key.toUpperCase();
}

String defaultTranslationLanguage(BuildContext context) {
  final code = Localizations.localeOf(context).languageCode.trim().toLowerCase();
  if (kTranslationLanguageLabels.containsKey(code)) return code;
  return 'en';
}
