#ifndef RUNNER_SHARE_INTAKE_H_
#define RUNNER_SHARE_INTAKE_H_

#include <flutter/flutter_view_controller.h>

// THE WINDOWS HALF OF SHARE ACQUISITION.
//
// Windows delivers a share by ACTIVATING the application with
// `ActivationKind::ShareTarget` and handing it a `ShareOperation`. That is
// only possible for an app with PACKAGE IDENTITY: the share target is declared
// in the MSIX manifest, so a loose `aura.exe` run out of the build directory
// is not a share target and never will be. The same truth the WNS channel
// records, for the same reason, and it is reported rather than swallowed —
// `flutter run -d windows` legitimately has no share to hand over.
//
// WHAT THIS DOES, AND WHERE IT STOPS. It reads what the sharing application
// put in the `DataPackageView`, takes any files into Aura's own storage while
// the operation is still alive, and hands the result to Dart over the same
// channel Android and iOS use. It chooses no destination, resolves no
// identity, and publishes nothing — all of that happens in Aura, on
// `/share/incoming`, with the person deciding.
void RegisterShareIntake(flutter::FlutterViewController* controller);

#endif  // RUNNER_SHARE_INTAKE_H_
