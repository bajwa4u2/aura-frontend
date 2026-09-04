#include "share_intake.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <winrt/Windows.ApplicationModel.Activation.h>
#include <winrt/Windows.ApplicationModel.DataTransfer.ShareTarget.h>
#include <winrt/Windows.ApplicationModel.DataTransfer.h>
#include <winrt/Windows.ApplicationModel.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Storage.FileProperties.h>
#include <winrt/Windows.Storage.h>

#include <chrono>
#include <memory>
#include <string>
#include <vector>

namespace {

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;

namespace winrt_app = winrt::Windows::ApplicationModel;
namespace winrt_transfer = winrt::Windows::ApplicationModel::DataTransfer;
namespace winrt_storage = winrt::Windows::Storage;

std::string ToUtf8(const winrt::hstring& value) {
  return winrt::to_string(value);
}

/// The same ceiling as every other door into Aura, mirroring `MediaCapacity`
/// and the backend's `maxBytesFor`. A second, smaller number here would mean a
/// file Aura accepts from the picker is refused from the share sheet, for a
/// reason nobody could work out.
constexpr uint64_t kMaxItemBytes = 150ull * 1024 * 1024;

/// Aura's own copy of shared content, inside the package's local storage.
///
/// The share operation's files are the SENDING application's, and they are not
/// guaranteed to outlive the operation. Copying while it is alive is the same
/// judgement Android makes about an intent-scoped read grant: deferring the
/// read until the person has chosen a destination is a share that works in
/// testing and fails minutes later in someone's hand.
winrt_storage::StorageFolder ShareFolder() {
  auto local = winrt_storage::ApplicationData::Current().LocalFolder();
  return local
      .CreateFolderAsync(
          L"share_intake",
          winrt_storage::CreationCollisionOption::OpenIfExists)
      .get();
}

int64_t NowMilliseconds() {
  using namespace std::chrono;
  return duration_cast<milliseconds>(system_clock::now().time_since_epoch())
      .count();
}

/// Everything waiting, built once at activation and handed over once.
///
/// Held in a process-lifetime slot for the same reason Android and iOS hold
/// one: activation happens before Dart is listening, and a push into a
/// listener that does not exist yet is a share that silently never happened.
EncodableValue* g_pending = nullptr;

void CopyFilesInto(const winrt_transfer::DataPackageView& data,
                   EncodableList* payloads,
                   EncodableList* refusals) {
  if (!data.Contains(winrt_transfer::StandardDataFormats::StorageItems())) {
    return;
  }

  auto items = data.GetStorageItemsAsync().get();
  auto folder = ShareFolder();

  for (auto const& item : items) {
    auto file = item.try_as<winrt_storage::StorageFile>();
    if (!file) continue;  // A shared folder is not content Aura takes in.

    std::string name = ToUtf8(file.Name());

    try {
      auto properties = file.GetBasicPropertiesAsync().get();
      // Refused BEFORE it is copied. An enormous file should cost a message
      // rather than fill someone's disk on the way to being rejected.
      if (properties.Size() > kMaxItemBytes) {
        refusals->push_back(
            EncodableValue(name + " is too large to share into Aura."));
        continue;
      }
    } catch (winrt::hresult_error const&) {
      // A file that will not describe itself may still copy.
    }

    try {
      auto copy = file.CopyAsync(
                          folder, file.Name(),
                          winrt_storage::NameCollisionOption::GenerateUniqueName)
                      .get();

      EncodableMap payload;
      payload[EncodableValue("kind")] = EncodableValue("file");
      payload[EncodableValue("filePath")] = EncodableValue(ToUtf8(copy.Path()));
      payload[EncodableValue("fileName")] = EncodableValue(name);
      // WHAT THE SENDING APPLICATION CLAIMED. A hint for tie-breaking only;
      // Aura decides what something is by reading the bytes, in Dart, through
      // the same intake door a picker or a paste uses.
      payload[EncodableValue("declaredMimeType")] =
          EncodableValue(ToUtf8(copy.ContentType()));
      payloads->push_back(EncodableValue(payload));
    } catch (winrt::hresult_error const&) {
      refusals->push_back(EncodableValue(
          name + " could not be read from the app that shared it."));
    }
  }
}

void ReadTextInto(const winrt_transfer::DataPackageView& data,
                  EncodableList* payloads) {
  // A shared link and a shared sentence arrive on different formats, and the
  // distinction is a SHAPE rather than a judgement: it decides whether Aura
  // offers a link preview, nothing more.
  if (data.Contains(winrt_transfer::StandardDataFormats::WebLink())) {
    try {
      auto uri = data.GetWebLinkAsync().get();
      EncodableMap payload;
      payload[EncodableValue("kind")] = EncodableValue("url");
      payload[EncodableValue("text")] =
          EncodableValue(ToUtf8(uri.AbsoluteUri()));
      payloads->push_back(EncodableValue(payload));
      return;
    } catch (winrt::hresult_error const&) {
    }
  }

  if (data.Contains(winrt_transfer::StandardDataFormats::Text())) {
    try {
      auto text = ToUtf8(data.GetTextAsync().get());
      if (!text.empty()) {
        EncodableMap payload;
        payload[EncodableValue("kind")] = EncodableValue("text");
        payload[EncodableValue("text")] = EncodableValue(text);
        payloads->push_back(EncodableValue(payload));
      }
    } catch (winrt::hresult_error const&) {
    }
  }
}

/// Read the activation, if this launch was one.
///
/// Never throws out. An unpackaged run has no activation args at all and that
/// is the ordinary case during development — it is answered with "nothing was
/// shared", which is true, rather than with a crash.
void CaptureActivation() {
  try {
    auto args = winrt_app::AppInstance::GetActivatedEventArgs();
    if (!args) return;
    if (args.Kind() != winrt_app::Activation::ActivationKind::ShareTarget) {
      return;
    }

    auto shared =
        args.try_as<winrt_app::Activation::ShareTargetActivatedEventArgs>();
    if (!shared) return;

    auto operation = shared.ShareOperation();
    auto data = operation.Data();

    EncodableList payloads;
    EncodableList refusals;
    ReadTextInto(data, &payloads);
    CopyFilesInto(data, &payloads, &refusals);

    std::string subject;
    try {
      subject = ToUtf8(data.Properties().Title());
    } catch (winrt::hresult_error const&) {
    }

    // Windows expects to be told the share is done with. Reporting completion
    // is what dismisses the sharing UI; leaving it open would strand the
    // person in the other application's sheet.
    try {
      operation.ReportCompleted();
    } catch (winrt::hresult_error const&) {
    }

    if (payloads.empty() && refusals.empty()) return;

    EncodableMap envelope;
    envelope[EncodableValue("platform")] = EncodableValue("windows");
    envelope[EncodableValue("payloads")] = EncodableValue(payloads);
    envelope[EncodableValue("refusals")] = EncodableValue(refusals);
    envelope[EncodableValue("receivedAt")] = EncodableValue(NowMilliseconds());
    if (!subject.empty()) {
      envelope[EncodableValue("subject")] = EncodableValue(subject);
    }

    g_pending = new EncodableValue(envelope);
  } catch (winrt::hresult_error const&) {
    // No package identity: this executable is not a share target. Nothing is
    // pending, which is the honest answer.
  } catch (...) {
  }
}

/// Content someone shared and then abandoned should not sit on their machine.
void ClearLocal() {
  try {
    auto folder = ShareFolder();
    for (auto const& file : folder.GetFilesAsync().get()) {
      try {
        file.DeleteAsync(winrt_storage::StorageDeleteOption::PermanentDelete)
            .get();
      } catch (winrt::hresult_error const&) {
      }
    }
  } catch (...) {
  }
}

}  // namespace

void RegisterShareIntake(flutter::FlutterViewController* controller) {
  if (controller == nullptr) return;

  CaptureActivation();

  auto channel = std::make_shared<flutter::MethodChannel<EncodableValue>>(
      controller->engine()->messenger(), "org.auraplatform.app/share_intake",
      &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [](const flutter::MethodCall<EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
        if (call.method_name() == "consumePendingShare") {
          // Handed over at most once. Returning it twice would mean the same
          // content presented twice, which on that surface means publishing
          // it twice.
          if (g_pending == nullptr) {
            result->Success();
            return;
          }
          EncodableValue pending = *g_pending;
          delete g_pending;
          g_pending = nullptr;
          result->Success(pending);
          return;
        }

        if (call.method_name() == "releaseSharedContent") {
          ClearLocal();
          result->Success();
          return;
        }

        result->NotImplemented();
      });

  // The handler outlives this call by design: the channel is owned by the
  // process, like the engine it is registered on.
  static std::shared_ptr<flutter::MethodChannel<EncodableValue>> retained;
  retained = channel;
}
