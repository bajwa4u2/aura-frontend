import 'package:web/web.dart' as web;

/// THE FULL REFERRER, READ ONCE AND IMMEDIATELY REDUCED.
///
/// This is the only place the complete referring URL exists in Aura. Its one
/// caller passes it straight to `referrerOriginOf`, which discards everything
/// but scheme and host before any request is made. Nothing stores this value
/// and nothing logs it.
String? currentDocumentReferrer() {
  final referrer = web.document.referrer;
  return referrer.isEmpty ? null : referrer;
}
