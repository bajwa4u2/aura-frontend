#include "wns_channel.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <windows.h>

#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Networking.PushNotifications.h>

#include <memory>
#include <mutex>
#include <queue>
#include <string>

#include "call_push.h"

namespace {

using flutter::EncodableMap;
using flutter::EncodableValue;

namespace push = winrt::Windows::Networking::PushNotifications;

std::string ToUtf8(const winrt::hstring& value) {
  return winrt::to_string(value);
}

/// The one channel object, kept for the process lifetime.
///
/// Both halves need it: Dart asks for its URI to register the device, and the
/// foreground receiver subscribes to its `PushReceived`. Creating a second
/// channel to listen on would not be listening on the one the server sends to.
std::shared_ptr<flutter::MethodChannel<EncodableValue>> g_channel;
push::PushNotificationChannel g_push_channel{nullptr};
winrt::event_token g_push_token{};

/// PUSHES ARRIVE ON A WINRT THREAD; FLUTTER IS SPOKEN TO ON THE PLATFORM ONE.
///
/// Invoking a method channel from the notification callback would be a
/// cross-thread call into the engine, which is undefined and fails in the way
/// that is hardest to diagnose: intermittently, under load, on someone else's
/// machine. So arrivals are queued and a message-only window — created on the
/// platform thread, so its WndProc runs there — drains them.
constexpr UINT kPushArrivedMessage = WM_APP + 0x51;
HWND g_marshal_window = nullptr;
std::mutex g_queue_mutex;
std::queue<std::string> g_queue;

void DeliverQueuedPushes() {
  for (;;) {
    std::string payload;
    {
      std::lock_guard<std::mutex> lock(g_queue_mutex);
      if (g_queue.empty()) return;
      payload = std::move(g_queue.front());
      g_queue.pop();
    }
    if (g_channel == nullptr) return;
    g_channel->InvokeMethod(
        "onCallPush",
        std::make_unique<EncodableValue>(EncodableValue(payload)));
  }
}

LRESULT CALLBACK MarshalWndProc(HWND window, UINT message, WPARAM wparam,
                                LPARAM lparam) {
  if (message == kPushArrivedMessage) {
    DeliverQueuedPushes();
    return 0;
  }
  return ::DefWindowProc(window, message, wparam, lparam);
}

HWND EnsureMarshalWindow() {
  if (g_marshal_window != nullptr) return g_marshal_window;

  static const wchar_t kClassName[] = L"AuraWnsMarshal";
  WNDCLASSW wc{};
  wc.lpfnWndProc = MarshalWndProc;
  wc.hInstance = ::GetModuleHandleW(nullptr);
  wc.lpszClassName = kClassName;
  ::RegisterClassW(&wc);

  g_marshal_window = ::CreateWindowExW(0, kClassName, L"", 0, 0, 0, 0, 0,
                                       HWND_MESSAGE, nullptr, wc.hInstance,
                                       nullptr);
  return g_marshal_window;
}

/// Ask the OS for this application's push channel.
///
/// `CreatePushNotificationChannelForApplicationAsync` is only meaningful for an
/// app with package identity. Run unpackaged — which is exactly what
/// `flutter run -d windows` and a bare Release build are — it throws, and the
/// honest answer is "no channel here", not a crash and not a fabricated value.
///
/// The call is awaited synchronously. Channel creation is a local OS operation
/// measured in milliseconds, and returning the URI on the same platform-thread
/// reply keeps the Dart side a plain `await` instead of a second callback path
/// that would have to be reconciled with device registration.
void CreateChannel(std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  try {
    auto manager = push::PushNotificationChannelManager::
        CreatePushNotificationChannelForApplicationAsync();
    auto channel = manager.get();

    // SUBSCRIBE WHILE AURA IS OPEN.
    //
    // This is the half that makes a call ring without waking a background
    // task at all, and it was missing: the channel was created, its URI was
    // registered with the server, and nothing was ever attached to it.
    if (g_push_channel != nullptr && g_push_token) {
      g_push_channel.PushNotificationReceived(g_push_token);
    }
    g_push_channel = channel;
    EnsureMarshalWindow();
    g_push_token = channel.PushNotificationReceived(
        [](push::PushNotificationChannel const&,
           push::PushNotificationReceivedEventArgs const& args) {
          if (args.NotificationType() != push::PushNotificationType::Raw) return;
          const std::string payload = ToUtf8(args.RawNotification().Content());
          if (payload.empty()) return;

          // Handled here, so the OS does not also start the background task
          // for the same notification and present the call twice.
          args.Cancel(true);

          {
            std::lock_guard<std::mutex> lock(g_queue_mutex);
            g_queue.push(payload);
          }
          if (g_marshal_window != nullptr) {
            ::PostMessageW(g_marshal_window, kPushArrivedMessage, 0, 0);
          }
        });

    EncodableMap out;
    out[EncodableValue("channelUri")] = EncodableValue(ToUtf8(channel.Uri()));
    // Carried so the client can re-register before the OS retires the channel
    // rather than discovering it from a 410 on the next call.
    out[EncodableValue("expiresAt")] = EncodableValue(
        static_cast<int64_t>(winrt::clock::to_time_t(channel.ExpirationTime())));
    result->Success(EncodableValue(out));
  } catch (const winrt::hresult_error& e) {
    result->Error("WNS_UNAVAILABLE", ToUtf8(e.message()));
  } catch (...) {
    result->Error("WNS_UNAVAILABLE", "Unknown failure creating a WNS channel");
  }
}

}  // namespace

void RegisterWnsChannel(flutter::FlutterViewController* controller) {
  if (controller == nullptr || controller->engine() == nullptr) {
    return;
  }

  auto channel = std::make_shared<flutter::MethodChannel<EncodableValue>>(
      controller->engine()->messenger(), "org.auraplatform.app/wns",
      &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [](const flutter::MethodCall<EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
        const auto& method = call.method_name();
        if (method == "createChannel") {
          CreateChannel(std::move(result));
          return;
        }
        if (method == "registerBackgroundTask") {
          std::string error;
          const bool ok = aura::RegisterCallPushTask(&error);
          if (ok) {
            result->Success(EncodableValue(true));
          } else {
            // Not an Error: a machine that cannot register background delivery
            // still rings while Aura is open, and collapsing that into a
            // failure would make the app look broken when it is degraded.
            result->Success(EncodableValue(false));
          }
          return;
        }
        if (method == "takePendingCallPush") {
          const std::string pending = aura::TakePendingCallPush();
          if (pending.empty()) {
            result->Success(EncodableValue());
          } else {
            result->Success(EncodableValue(pending));
          }
          return;
        }
        result->NotImplemented();
      });

  // Kept alive for the process lifetime; the runner owns exactly one engine.
  g_channel = channel;
}
