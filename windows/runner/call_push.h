#ifndef RUNNER_CALL_PUSH_H_
#define RUNNER_CALL_PUSH_H_

#include <string>
#include <vector>

namespace aura {

/// The argument Windows passes when it starts `aura.exe` to service a
/// background task, matching the `Arguments` attribute of the `com:ExeServer`
/// declaration in the package manifest. The two must agree; the packaging
/// tool writes the manifest side and `kComServerArgument` is the runner side.
extern const wchar_t* const kComServerArgument;

/// True when this process was started by COM to run the push background task
/// rather than by a person opening Aura.
bool IsComServerLaunch(const std::vector<std::string>& arguments);

/// Serve the background-task class until Windows is finished with it.
///
/// Returns the process exit code. Never creates a window: this process exists
/// to receive one raw notification while Aura is closed and then get out of
/// the way.
int RunComServer();

/// Ask the OS to start this app's COM server when a raw push arrives.
///
/// Idempotent — an existing registration for the same name is left alone, so
/// this can be called on every launch without accumulating registrations.
/// Returns false when the app has no package identity (an unpackaged build)
/// or when registration is refused; both are reported to Dart rather than
/// thrown, because a failure to register background delivery must not stop an
/// app that still works while it is open.
bool RegisterCallPushTask(std::string* error);

/// A call payload delivered while Aura was closed, or an empty string.
///
/// Read-and-clear: the payload is handed over exactly once, so a relaunch
/// minutes later does not resurrect a call that has already been dealt with.
std::string TakePendingCallPush();

/// Record a payload for the app to collect when it starts. Used by the
/// background task; exposed here so both halves share one file location.
void WritePendingCallPush(const std::string& payload);

}  // namespace aura

#endif  // RUNNER_CALL_PUSH_H_
