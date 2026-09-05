#ifndef RUNNER_TIMEZONE_CHANNEL_H_
#define RUNNER_TIMEZONE_CHANNEL_H_

#include <flutter/flutter_view_controller.h>

/// Answer the device's IANA timezone identifier, or nothing.
///
/// Windows is the one platform Aura ships on that does not name its zones the
/// way the rest of the world does: it says "Pakistan Standard Time" where IANA
/// says "Asia/Karachi". Converting between them needs the CLDR mapping, which
/// Windows itself carries inside ICU.
void RegisterTimezoneChannel(flutter::FlutterViewController* controller);

#endif  // RUNNER_TIMEZONE_CHANNEL_H_
