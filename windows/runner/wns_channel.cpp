#include "wns_channel.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Networking.PushNotifications.h>

#include <memory>
#include <string>

namespace {

using flutter::EncodableMap;
using flutter::EncodableValue;

std::string ToUtf8(const winrt::hstring& value) {
  return winrt::to_string(value);
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
    auto manager = winrt::Windows::Networking::PushNotifications::
        PushNotificationChannelManager::CreatePushNotificationChannelForApplicationAsync();
    auto channel = manager.get();

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
        if (call.method_name() == "createChannel") {
          CreateChannel(std::move(result));
          return;
        }
        result->NotImplemented();
      });

  // Kept alive for the process lifetime; the runner owns exactly one engine.
  static std::shared_ptr<flutter::MethodChannel<EncodableValue>> retained;
  retained = channel;
}
