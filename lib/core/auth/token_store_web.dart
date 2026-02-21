// token_store_web.dart
//
// Web shim file.
// We intentionally do NOT use `dart:html`.
// SharedPreferences works on Flutter web, so the main TokenStore is already web-safe.
//
// Keeping this file as a compatibility layer prevents breakage if any older code
// still imports `token_store_web.dart`.

export 'token_store.dart';
