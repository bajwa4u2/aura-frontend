// WINDOWS RINGS WHEN AURA IS CLOSED.
//
// ── THE DEFECT THIS EXISTS FOR ───────────────────────────────────────────
//
// The server has sent Windows call pushes since the WNS adapter shipped, as
// `X-WNS-Type: wns/raw`, deliberately: an incoming call must be presented by
// Aura's own call UI, which can accept and decline, not by a generic OS toast
// which cannot. `wns_channel.cpp` asked the OS for the channel and registered
// it, and that half worked.
//
// Nothing listened. There was no push-received handler and no background task
// anywhere in `windows/`, and Windows draws nothing for a raw notification by
// itself — so a raw push arrived at a process with no receiver and evaporated.
// A Windows machine only "rang" when Aura happened to be open and heard the
// call on its realtime socket, which is not ringing; it is being already in
// the room when the phone goes.
//
// ── WHY A COM SERVER, AND NOT THE EASIER THINGS ─────────────────────────
//
// Aura's Windows client is a packaged (MSIX) full-trust Win32 app. For that
// shape, a raw push delivered while the app is CLOSED reaches exactly one
// documented mechanism: a background task whose entry point is a COM class
// registered by the package — `BackgroundTaskBuilder::SetTaskEntryPointClsid`
// plus a `com:ExeServer` declaration naming this same executable. Windows
// starts `aura.exe -RegisterProcessAsComServer`, we hand it the class, it runs
// the task, and the process exits.
//
// The alternatives were considered and rejected for stated reasons, not taste:
//
//   * An in-process background task is a UWP concept; a full-trust desktop app
//     cannot host one.
//   * Windows App SDK's `PushNotificationManager` supports COM activation for
//     desktop apps, but it obtains channels against an AZURE/ENTRA APP
//     REGISTRATION and the server would have to authenticate to WNS as that
//     application. That abandons the Partner Center Package SID + secret the
//     backend already uses and the founder is configuring. Switching transport
//     credentials to gain a mechanism we already have would be a larger change
//     with a worse blast radius.
//   * A toast push would ring without any of this, and was explicitly refused:
//     a toast cannot be Aura's call UI.
//
// ── WHAT THE BACKGROUND TASK DOES, AND DELIBERATELY DOES NOT DO ─────────
//
// It does not draw anything and it decides nothing about the call. A task
// process has no Flutter engine and no UI, and giving it a second, cut-down
// idea of an incoming call would be the second implementation this codebase
// keeps removing. It records the payload and starts Aura, and Aura presents
// the call through the SAME incoming-call bridge every other platform uses —
// which is also where the liveness check lives, so a push that arrives after
// the caller gave up is retracted by the same authority on Windows as on
// Android and iOS.

#include "call_push.h"

#include <unknwn.h>  // Before any C++/WinRT header: enables classic COM in
                     // winrt::implements, which IClassFactory needs.

#include <windows.h>

#include <winrt/Windows.ApplicationModel.Background.h>
#include <winrt/Windows.ApplicationModel.Core.h>
#include <winrt/Windows.ApplicationModel.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Networking.PushNotifications.h>
#include <winrt/Windows.Storage.h>

#include <algorithm>
#include <fstream>
#include <sstream>

namespace aura {

namespace {

namespace background = winrt::Windows::ApplicationModel::Background;
namespace push = winrt::Windows::Networking::PushNotifications;
namespace storage = winrt::Windows::Storage;

/// The background task's class id. It appears in exactly two places — here and
/// in the package manifest the packaging tool writes — and they must match. A
/// mismatch is silent: Windows accepts the registration and then has nothing to
/// activate, which looks exactly like a push that never arrived.
///
/// {7A6C2C1E-3E5B-4C52-9E1A-2F6B1D5C7A90}
constexpr winrt::guid kCallPushTaskClsid{
    0x7a6c2c1e,
    0x3e5b,
    0x4c52,
    {0x9e, 0x1a, 0x2f, 0x6b, 0x1d, 0x5c, 0x7a, 0x90}};

/// The name the registration is stored under. Registrations persist across
/// launches, so this is also how an existing one is recognised.
constexpr wchar_t kTaskName[] = L"AuraCallPush";

/// Set when the task has finished, so the server process can retire instead of
/// lingering as an invisible background process on someone's machine.
HANDLE g_task_finished = nullptr;

std::string ToUtf8(const winrt::hstring& value) {
  return winrt::to_string(value);
}

/// Where a payload waits between the task recording it and Aura collecting it.
///
/// The package's own local folder, which is per-user, per-package, and already
/// where `share_intake` keeps the same kind of thing. Unpackaged there is no
/// such folder and there are no raw pushes either, so an empty path is the
/// honest answer rather than a fabricated temp file.
std::wstring PendingPath() {
  try {
    auto folder = storage::ApplicationData::Current().LocalFolder();
    std::wstring path{folder.Path()};
    path += L"\\aura_call_push.json";
    return path;
  } catch (...) {
    return std::wstring{};
  }
}

}  // namespace

const wchar_t* const kComServerArgument = L"-RegisterProcessAsComServer";

bool IsComServerLaunch(const std::vector<std::string>& arguments) {
  for (const auto& argument : arguments) {
    if (argument == "-RegisterProcessAsComServer") return true;
  }
  return false;
}

void WritePendingCallPush(const std::string& payload) {
  const std::wstring path = PendingPath();
  if (path.empty() || payload.empty()) return;
  std::ofstream out(path, std::ios::binary | std::ios::trunc);
  if (!out) return;
  out.write(payload.data(), static_cast<std::streamsize>(payload.size()));
}

std::string TakePendingCallPush() {
  const std::wstring path = PendingPath();
  if (path.empty()) return std::string{};

  std::ifstream in(path, std::ios::binary);
  if (!in) return std::string{};
  std::ostringstream buffer;
  buffer << in.rdbuf();
  in.close();

  // READ AND CLEAR. A ring is a moment, not a state: leaving the file behind
  // would present the same call again the next time Aura opened, which could
  // be the following morning.
  ::DeleteFileW(path.c_str());
  return buffer.str();
}

namespace {

/// The task itself. Records the payload, starts Aura, completes.
struct CallPushTask
    : winrt::implements<CallPushTask, background::IBackgroundTask> {
  void Run(background::IBackgroundTaskInstance const& instance) {
    // A deferral, because everything below is asynchronous and a task that
    // returns before its work is done is killed mid-flight.
    auto deferral = instance.GetDeferral();
    try {
      auto details = instance.TriggerDetails();
      auto raw = details.try_as<push::RawNotification>();
      if (raw) {
        WritePendingCallPush(ToUtf8(raw.Content()));
        LaunchAura();
      }
    } catch (...) {
      // A failed activation must not take the process down noisily; the
      // payload is already recorded, and Aura will collect it when next
      // opened rather than losing the record of the call entirely.
    }
    deferral.Complete();
    if (g_task_finished != nullptr) ::SetEvent(g_task_finished);
  }

 private:
  /// Start Aura the way the Start menu does.
  ///
  /// `AppListEntry::LaunchAsync` is the package's own entry point, so the app
  /// comes up as a normal launch with its identity, its protocol handlers and
  /// its single-instance behaviour intact — rather than a second bare process
  /// started behind the OS's back.
  static void LaunchAura() {
    auto entries =
        winrt::Windows::ApplicationModel::Package::Current().GetAppListEntriesAsync().get();
    if (entries.Size() == 0) return;
    entries.GetAt(0).LaunchAsync().get();
  }
};

struct CallPushTaskFactory : winrt::implements<CallPushTaskFactory, IClassFactory> {
  HRESULT STDMETHODCALLTYPE CreateInstance(IUnknown* outer, GUID const& iid,
                                           void** result) noexcept final {
    *result = nullptr;
    if (outer != nullptr) return CLASS_E_NOAGGREGATION;
    return winrt::make<CallPushTask>().as(iid, result);
  }

  HRESULT STDMETHODCALLTYPE LockServer(BOOL) noexcept final { return S_OK; }
};

}  // namespace

int RunComServer() {
  winrt::init_apartment();

  g_task_finished = ::CreateEventW(nullptr, TRUE, FALSE, nullptr);

  DWORD registration = 0;
  auto factory = winrt::make<CallPushTaskFactory>();
  const HRESULT registered = ::CoRegisterClassObject(
      kCallPushTaskClsid, factory.get(), CLSCTX_LOCAL_SERVER,
      REGCLS_MULTIPLEUSE, &registration);
  if (FAILED(registered)) return EXIT_FAILURE;

  // BOUNDED, so a push that never arrives cannot leave a process running on
  // somebody's machine forever. Windows starts this server when it has work;
  // if the work does not materialise within the window, there is none.
  constexpr DWORD kIdleTimeoutMs = 30'000;
  ::WaitForSingleObject(g_task_finished, kIdleTimeoutMs);

  ::CoRevokeClassObject(registration);
  if (g_task_finished != nullptr) {
    ::CloseHandle(g_task_finished);
    g_task_finished = nullptr;
  }
  return EXIT_SUCCESS;
}

bool RegisterCallPushTask(std::string* error) {
  try {
    // Already registered by a previous launch. Registrations survive restarts,
    // so re-registering every time would stack duplicates that each deliver
    // the same call.
    for (auto const& entry : background::BackgroundTaskRegistration::AllTasks()) {
      if (entry.Value().Name() == kTaskName) return true;
    }

    // Required before a background task may run at all. Returns the existing
    // answer when access was already granted, so this is not a prompt on every
    // launch.
    background::BackgroundExecutionManager::RequestAccessAsync().get();

    background::BackgroundTaskBuilder builder;
    builder.Name(kTaskName);
    builder.SetTrigger(background::PushNotificationTrigger());
    // The COM class, not a WinRT entry point string: a full-trust desktop app
    // has no in-process task host, so the class id is the whole mechanism.
    builder.SetTaskEntryPointClsid(kCallPushTaskClsid);
    builder.Register();
    return true;
  } catch (const winrt::hresult_error& e) {
    if (error != nullptr) *error = ToUtf8(e.message());
    return false;
  } catch (...) {
    if (error != nullptr) *error = "Unknown failure registering the call push task";
    return false;
  }
}

}  // namespace aura
