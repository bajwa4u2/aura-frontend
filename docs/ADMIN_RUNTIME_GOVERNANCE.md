# Admin Runtime Governance — polling budget + lifecycle policy

This document is the source of truth for how the Aura admin workspace
(`/admin/*`) handles polling, refresh cadence, and lifecycle. It is
mandatory reading before adding any new admin screen, widget, or
provider that fetches data.

---

## 1. Mental model

The admin workspace is a long-lived single-page surface where an
operator may sit idle for hours. Every periodic request must justify
itself against three questions:

1. **Does the operator actually need this data to refresh now?**
2. **Will this fire when the tab is hidden / the operator is away?**
3. **Will it stop completely when the operator leaves `/admin/*`?**

If the answer to (1) is "not really", the cadence is too high. If (2)
or (3) is "yes", the work is not gated by the runtime coordinator.

Every admin polling decision should leave the workspace **operationally
calm at idle** — a focused tab with no human input should produce ≤ 1
backend request per minute total, including notifications and
compatibility.

---

## 2. The Admin Runtime Coordinator

Single source of truth for admin polling: `lib/features/admin/runtime/
admin_runtime_coordinator.dart`.

State it tracks:

| Field             | Source                              | When it flips                                    |
|-------------------|-------------------------------------|--------------------------------------------------|
| `shellMounted`    | `AdminShell.initState/dispose`       | True while any `/admin/*` route is in the stack. |
| `foregrounded`    | `appForegroundedProvider`            | Mirrors `WidgetsBindingObserver` lifecycle.       |
| `tickCount`       | the coordinator's own timer          | Increments once per scheduled tick.              |
| `lastTickAt`      | the coordinator's own timer          | Wall-clock of the most recent tick.              |

Derived: `shouldPoll = shellMounted && foregrounded`.

Public API:

```dart
final coordinator = ref.read(adminRuntimeCoordinatorProvider.notifier);

// Subscribe in initState. Returns a disposer; call it in dispose.
final unsubscribe = coordinator.subscribe('adminUsers', () async {
  await ref.refresh(adminUsersProvider.future);
});

// Manual refresh button.
await coordinator.refreshNow();

// Read-only: did we tick recently? Useful for "as of HH:MM" footers.
final state = ref.watch(adminRuntimeCoordinatorProvider);
final tick = state.lastTickAt;
```

**Hard rules**:

- No admin screen may create its own `Timer.periodic`. If you need
  periodic refresh, subscribe to the coordinator.
- The coordinator is NOT a global polling manager. It governs
  admin-workspace polling only. App-wide polling (notifications,
  compatibility) lives outside but observes the same visibility signal.
- Dispose subscriptions in your widget's `dispose`. The coordinator's
  registry maps name → handler; failing to unsubscribe leaks a closure.

---

## 3. Polling budget

| Source              | Cadence        | Visibility-gated? | Route-scope        | Rationale |
|---------------------|----------------|-------------------|--------------------|-----------|
| Admin coordinator tick | 60s default | yes (foreground)  | yes (admin only)   | Shared across admin screens; subscribers run on the same tick instead of staggering. |
| Per-screen subscriptions | 30s minimum (kMinAdminTickInterval) | yes (inherit)     | yes (inherit)      | Floor exists to prevent thundering herd on one screen. |
| Notifications poll  | 120s           | yes (foreground)  | no (app-wide)      | Drives the unread badge across the app, not just admin. |
| Compatibility poll  | 600s           | yes (foreground)  | no (app-wide)      | Drives `UpdateGate`. Resume forces immediate refresh via `force:true`. |
| Realtime / WebSocket | event-driven  | n/a               | no (app-wide)      | Socket protocol-level keep-alive only; no app-level timer. |

Hard ceilings to honor:

- **No more than 4 in-flight requests at once** from admin code paths.
  The Dio interceptor already dedupes per-request; admin code should
  not pre-flight or retry without exponential backoff.
- **No periodic refresh shorter than 30 seconds** anywhere. If a UI
  needs sub-30s freshness, it should be on a WebSocket channel.
- **No refresh while `state.foregrounded == false`.** The OS has
  already paused the tab; making it less paused defeats the purpose.

---

## 4. Lifecycle diagram

```
┌──────────────────────────────────────────────────────────────────┐
│  AuraApp boot                                                    │
│   └── ProviderScope                                              │
│        ├── appForegroundedProvider   (WidgetsBindingObserver)    │
│        ├── compatibilityControllerProvider                       │
│        │      └── Timer.periodic 600s (refresh skipped if hidden)│
│        └── notificationsControllerProvider                       │
│               └── Timer.periodic 120s (refresh skipped if hidden)│
│                                                                  │
│  Router enters /admin/*                                          │
│   └── AdminShell mounts                                          │
│        └── coordinator.markShellMounted()                        │
│             └── timer starts ticking 60s while foregrounded      │
│                                                                  │
│  Operator switches tab away                                      │
│   └── appForegroundedProvider → false                            │
│        ├── coordinator timer cancels (no ticks)                  │
│        ├── notifications periodic skips fetch                    │
│        └── compatibility periodic skips fetch                    │
│                                                                  │
│  Operator returns                                                │
│   └── appForegroundedProvider → true                             │
│        ├── coordinator timer restarts                            │
│        ├── compatibility refresh(force: true) (UpdateGate hook)  │
│        └── notifications refreshIfStale()                         │
│                                                                  │
│  Router leaves /admin/*                                          │
│   └── AdminShell disposes                                        │
│        └── coordinator.markShellUnmounted()                      │
│             └── timer cancels; subscriptions become dormant      │
└──────────────────────────────────────────────────────────────────┘
```

---

## 5. Failure handling

- A subscribed handler that throws is logged via `debugPrint` and the
  other handlers continue. The coordinator never escalates a single
  failure into a tick-stop.
- Failed HTTP calls use the existing Dio interceptor's per-host backoff
  on 429s (`dio_provider.dart`). Admin screens do not need their own
  retry loops.
- A 401 anywhere causes the Dio interceptor to attempt a token
  refresh, then retry once. After that the session is cleared and
  router redirects out of admin — at which point `AdminShell.dispose`
  fires and the coordinator stops.

---

## 6. What goes WHERE — adding a new admin screen

1. Build the data provider as a normal `FutureProvider` /
   `AsyncNotifierProvider`. **Do not** add `Timer.periodic` inside it.
2. In the screen widget's `initState`, subscribe to the coordinator:
   ```dart
   final unsub = ref
       .read(adminRuntimeCoordinatorProvider.notifier)
       .subscribe('myScreen', () async {
         await ref.refresh(myScreenProvider.future);
       });
   _disposers.add(unsub);
   ```
3. In `dispose`, run every disposer.
4. If the screen has a "Refresh" button, call
   `coordinator.refreshNow()` rather than `ref.invalidate(...)` so the
   coordinator's tick metadata stays accurate and the visibility gate
   is honored.

If your screen needs sub-minute freshness, **stop and discuss** in this
doc before adding any new periodic behavior. Real-time admin data
belongs on a WebSocket channel (compare `realtime_socket_service.dart`
patterns), not on a faster timer.

---

## 7. What you must NOT do

- Do not add a `Timer` (or `Stream.periodic`, or any other
  scheduler) inside an admin widget or provider.
- Do not poll while `appForegroundedProvider` is false. The
  coordinator enforces this; if you skip it, your code WILL produce
  wasted requests on hidden tabs.
- Do not fetch admin data from outside `/admin/*`. The `appAdmin`
  guard already redirects unauthenticated users out; relying on
  permission checks alone is not enough — make the data dependency
  match the route scope so the runtime can dispose cleanly.
- Do not create parallel polling managers. There is one coordinator;
  it is final.
- Do not silently swallow refresh failures. Errors surface via the
  AsyncValue.error path on each provider; users see the failure in
  the screen's empty/error state.
