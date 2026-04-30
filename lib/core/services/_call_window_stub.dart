// Stub implementations for non-web platforms.
// All operations are no-ops; the call lives within the same app instance.

bool webWindowIsOpen() => false;
void webWindowOpen(String url) {}
void webWindowFocus() {}
void webWindowClose() {}
