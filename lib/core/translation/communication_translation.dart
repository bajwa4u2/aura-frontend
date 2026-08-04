import 'package:flutter/material.dart';

/// The three row types that carry publishable communication text today.
/// Mirrors the backend's `CommunicationObjectType` Prisma enum exactly —
/// keep both in sync.
enum CommunicationObjectType {
  post,
  institutionPost,
  announcement;

  /// Wire value expected by `POST /communication/translate`.
  String get wireValue => switch (this) {
    CommunicationObjectType.post => 'POST',
    CommunicationObjectType.institutionPost => 'INSTITUTION_POST',
    CommunicationObjectType.announcement => 'ANNOUNCEMENT',
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
