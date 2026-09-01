/// Where the visitor came from, read once, on web only.
///
/// Split behind a conditional import because `dart:html` cannot be imported on
/// a native build at all — and because this is the exact point where the
/// sensitive value enters the program. Keeping it in one named function makes
/// the disclosure boundary greppable rather than scattered through the router.
library;

export 'document_referrer_stub.dart'
    if (dart.library.js_interop) 'document_referrer_web.dart';
