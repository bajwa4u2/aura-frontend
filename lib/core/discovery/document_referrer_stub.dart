/// Native builds have no referrer. Returning null is the truth, not a
/// degradation: a phone did not arrive from a search engine.
String? currentDocumentReferrer() => null;
