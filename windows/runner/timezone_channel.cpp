#include "timezone_channel.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <windows.h>

#include <memory>
#include <string>

namespace {

using flutter::EncodableValue;

/// ICU'S OWN WINDOWS-TO-IANA MAPPING, LOADED AT RUNTIME.
///
/// Windows 10 1903 and later ship ICU as `icu.dll`, which carries the CLDR
/// `windowsZones` table. `ucal_getTimeZoneIDForWindowsID` is the function that
/// table exists for.
///
/// Resolved with LoadLibrary/GetProcAddress rather than linked, deliberately:
/// linking would make the whole Windows build depend on an ICU import library
/// and refuse to start on a Windows version that has no `icu.dll`. Loaded this
/// way, an older Windows simply returns nothing — which is a truthful "I do not
/// know", and the one answer this whole area was missing.
///
/// The alternative was to embed a copy of the CLDR table in the app. That is
/// what the code being replaced did in miniature, with two dozen United States
/// entries, and it is why a person in Karachi was shown a wrong meeting time
/// while a person in New York was shown the right one. A table the app carries
/// is a table the app has to keep correct; ICU's is maintained by the OS.
using UCalGetTimeZoneIDForWindowsID = int32_t(__cdecl*)(const wchar_t* winid,
                                                        int32_t len,
                                                        const char* region,
                                                        wchar_t* id,
                                                        int32_t capacity,
                                                        int* status);

std::string ToUtf8(const std::wstring& value) {
  if (value.empty()) return {};
  const int size = ::WideCharToMultiByte(CP_UTF8, 0, value.data(),
                                         static_cast<int>(value.size()),
                                         nullptr, 0, nullptr, nullptr);
  if (size <= 0) return {};
  std::string out(static_cast<size_t>(size), '\0');
  ::WideCharToMultiByte(CP_UTF8, 0, value.data(), static_cast<int>(value.size()),
                        out.data(), size, nullptr, nullptr);
  return out;
}

/// The IANA zone id, or an empty string when this machine cannot say.
std::string ResolveZoneId() {
  DYNAMIC_TIME_ZONE_INFORMATION dtzi{};
  if (::GetDynamicTimeZoneInformation(&dtzi) == TIME_ZONE_ID_INVALID) return {};

  // e.g. L"Pakistan Standard Time" — a Windows zone key, not an IANA id.
  const std::wstring windows_id(dtzi.TimeZoneKeyName);
  if (windows_id.empty()) return {};

  HMODULE icu = ::LoadLibraryW(L"icu.dll");
  if (icu == nullptr) return {};

  auto fn = reinterpret_cast<UCalGetTimeZoneIDForWindowsID>(
      ::GetProcAddress(icu, "ucal_getTimeZoneIDForWindowsID"));
  if (fn == nullptr) {
    ::FreeLibrary(icu);
    return {};
  }

  wchar_t buffer[128] = {};
  int status = 0;  // U_ZERO_ERROR
  const int32_t length =
      fn(windows_id.c_str(), static_cast<int32_t>(windows_id.size()),
         // No region hint. A region would let ICU pick a country-specific zone
         // for an ambiguous Windows id; without one it returns the canonical
         // zone, which is the honest answer when the country is unknown.
         nullptr, buffer, static_cast<int32_t>(std::size(buffer)), &status);
  ::FreeLibrary(icu);

  // status > 0 is a U_*_ERROR in ICU's convention; warnings are negative.
  if (status > 0 || length <= 0) return {};
  return ToUtf8(std::wstring(buffer, static_cast<size_t>(length)));
}

}  // namespace

void RegisterTimezoneChannel(flutter::FlutterViewController* controller) {
  auto channel = std::make_shared<flutter::MethodChannel<EncodableValue>>(
      controller->engine()->messenger(), "org.auraplatform.app/timezone",
      &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [](const flutter::MethodCall<EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
        if (call.method_name() != "zoneId") {
          result->NotImplemented();
          return;
        }
        const std::string zone = ResolveZoneId();
        if (zone.empty()) {
          // Nothing is substituted here. A caller that receives null omits the
          // zone rather than sending a guess, and the backend refuses a guess
          // rather than turning it into UTC.
          result->Success(EncodableValue());
          return;
        }
        result->Success(EncodableValue(zone));
      });

  // Held for the process lifetime, matching the other runner channels.
  static std::shared_ptr<flutter::MethodChannel<EncodableValue>> retained;
  retained = channel;
}
