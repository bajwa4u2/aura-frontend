/// Item 15 — Rich Paste, non-web platforms.
///
/// Mobile/desktop native clipboard rich-text access (`text/html`/RTF) is
/// inconsistent across platform APIs and Flutter has no first-party
/// cross-platform binding for it. Rather than build three separate
/// platform-channel implementations of uncertain reliability, this stays a
/// deliberate, disclosed no-op here: paste on these platforms continues to
/// use Flutter's existing default plain-text behavior, exactly as before
/// this item -- never worse, just not newly richer yet.
Future<String?> readClipboardHtml() async => null;
