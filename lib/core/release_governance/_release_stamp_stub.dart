/// Non-web platforms have no bootstrap stamp to read, and no in-place reload
/// to offer — a native release arrives through a store update instead.
Future<String?> readReleaseStamp() async => null;
