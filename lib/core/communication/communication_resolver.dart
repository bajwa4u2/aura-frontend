import 'package:flutter/material.dart';

enum CommunicationOwner {
thread,
space,
spaceLiveRoom,
standaloneRealtime,
}

class CommunicationTarget {
final CommunicationOwner owner;
final String? threadId;
final String? spaceId;
final String? sessionId;

const CommunicationTarget({
required this.owner,
this.threadId,
this.spaceId,
this.sessionId,
});
}

class CommunicationResolver {
const CommunicationResolver();

/// 🔹 Resolve ownership from raw payload (activity / event / deeplink)
CommunicationTarget resolveFromPayload(Map<String, dynamic> payload) {
final threadId = _pick(payload, ['threadId', 'thread_id']);
final spaceId = _pick(payload, ['spaceId', 'space_id']);
final sessionId = _pick(payload, ['sessionId', 'session_id', 'id']);

```
final surfaceType =
    (payload['surfaceType'] ?? payload['surface_type'] ?? '')
        .toString()
        .toLowerCase();

// THREAD owned
if (threadId.isNotEmpty) {
  return CommunicationTarget(
    owner: CommunicationOwner.thread,
    threadId: threadId,
    spaceId: spaceId,
    sessionId: sessionId,
  );
}

// SPACE owned
if (surfaceType == 'space' && spaceId.isNotEmpty) {
  return CommunicationTarget(
    owner: CommunicationOwner.space,
    spaceId: spaceId,
    sessionId: sessionId,
  );
}

// fallback → standalone
return CommunicationTarget(
  owner: CommunicationOwner.standaloneRealtime,
  sessionId: sessionId,
);
```

}

/// 🔹 Resolve navigation path
String resolveRoute(CommunicationTarget target) {
switch (target.owner) {
case CommunicationOwner.thread:
final space = target.spaceId ?? '';
final thread = target.threadId ?? '';
return '/me/correspondence/$space/thread/$thread';

```
  case CommunicationOwner.space:
    return '/me/correspondence/${target.spaceId ?? ''}';

  case CommunicationOwner.spaceLiveRoom:
    return '/space-live/${target.spaceId ?? ''}';

  case CommunicationOwner.standaloneRealtime:
    return '/realtime/${target.sessionId ?? ''}';
}
```

}

/// 🔹 Helper
String _pick(Map<String, dynamic> map, List<String> keys) {
for (final k in keys) {
final v = (map[k] ?? '').toString().trim();
if (v.isNotEmpty) return v;
}
return '';
}
}
