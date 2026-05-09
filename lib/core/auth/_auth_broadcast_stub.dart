// Non-web stub. Cross-tab auth synchronization is a browser-only concern.
// On mobile/desktop the OS already gives each app a single auth state;
// publishing/listening from native is intentionally a no-op.

void initAuthBroadcast(void Function(String type) onMessage) {}

void publishAuthEvent(String type) {}

void closeAuthBroadcast() {}
