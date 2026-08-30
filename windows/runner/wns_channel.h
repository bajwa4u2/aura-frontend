#ifndef RUNNER_WNS_CHANNEL_H_
#define RUNNER_WNS_CHANNEL_H_

#include <flutter/flutter_view_controller.h>

// THE WINDOWS HALF OF CALL ARRIVAL WAS NEVER BUILT.
//
// The backend has shipped a complete WNS adapter for some time — it reads a
// channel URI from `UserDevice.endpoint`, sends call invites as
// `X-WNS-Type: wns/raw` so the app draws its own incoming-call surface instead
// of a generic toast that cannot answer or decline, and treats HTTP 404/410 as
// a retired channel rather than retrying forever. `PushProvider.WNS` exists in
// the schema. None of it has ever been reachable, because the client registers
// no Windows device at all: `_nativePushPayload()` returns null for every
// platform except Android and iOS.
//
// This is the missing half. A WNS channel URI is issued by the OS to a
// PACKAGED application — it is a property of the MSIX identity, not of the
// executable — so it cannot be obtained from a loose `aura.exe` run out of the
// build directory, and the failure is reported as such rather than swallowed.
void RegisterWnsChannel(flutter::FlutterViewController* controller);

#endif  // RUNNER_WNS_CHANNEL_H_
