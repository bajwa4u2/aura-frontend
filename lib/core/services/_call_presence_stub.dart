// Non-web stub — all functions are no-ops.
// On mobile/desktop, cross-tab synchronization is not needed.

void initPresenceChannel(
  String name,
  void Function(Map<String, dynamic>) onMessage,
) {}

void postPresenceMessage(Map<String, dynamic> data) {}

void closePresenceChannel() {}

void registerWindowUnloadCallback(void Function() callback) {}
