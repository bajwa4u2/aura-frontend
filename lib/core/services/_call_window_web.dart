// Popup call window removed — all calls route via /realtime/:sessionId.
// All operations are no-ops.

bool webWindowIsOpen() => false;
void webWindowOpen(String url) {}
void webWindowFocus() {}
void webWindowClose() {}
void webWindowSelfClose() {}
