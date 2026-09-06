#include "window_placement.h"

#include <dwmapi.h>

namespace aura {

namespace {

constexpr wchar_t kKey[] = L"Software\\Aura Platform LLC\\Aura";
constexpr wchar_t kX[] = L"WindowX";
constexpr wchar_t kY[] = L"WindowY";
constexpr wchar_t kW[] = L"WindowWidth";
constexpr wchar_t kH[] = L"WindowHeight";
constexpr wchar_t kMax[] = L"WindowMaximized";

bool ReadDword(HKEY key, const wchar_t* name, DWORD* out) {
  DWORD type = 0;
  DWORD size = sizeof(DWORD);
  return ::RegQueryValueExW(key, name, nullptr, &type,
                            reinterpret_cast<LPBYTE>(out), &size) ==
             ERROR_SUCCESS &&
         type == REG_DWORD;
}

void WriteDword(HKEY key, const wchar_t* name, DWORD value) {
  ::RegSetValueExW(key, name, 0, REG_DWORD,
                   reinterpret_cast<const BYTE*>(&value), sizeof(value));
}

// A remembered rectangle is only useful if a display still covers it. A
// laptop undocked from a second monitor would otherwise reopen Aura at
// coordinates no screen contains -- the window exists, and nobody can see it.
bool IsOnSomeDisplay(const RECT& frame) {
  HMONITOR monitor = ::MonitorFromRect(&frame, MONITOR_DEFAULTTONULL);
  return monitor != nullptr;
}

}  // namespace

bool RestoreWindowPlacement(POINT* origin, SIZE* size, bool* maximized) {
  HKEY key = nullptr;
  if (::RegOpenKeyExW(HKEY_CURRENT_USER, kKey, 0, KEY_READ, &key) !=
      ERROR_SUCCESS) {
    return false;
  }

  DWORD x = 0, y = 0, w = 0, h = 0, m = 0;
  const bool have = ReadDword(key, kX, &x) && ReadDword(key, kY, &y) &&
                    ReadDword(key, kW, &w) && ReadDword(key, kH, &h);
  ReadDword(key, kMax, &m);
  ::RegCloseKey(key);

  if (!have || w == 0 || h == 0) {
    return false;
  }

  RECT frame{static_cast<LONG>(x), static_cast<LONG>(y),
             static_cast<LONG>(x + w), static_cast<LONG>(y + h)};
  if (!IsOnSomeDisplay(frame)) {
    return false;
  }

  origin->x = static_cast<LONG>(x);
  origin->y = static_cast<LONG>(y);
  size->cx = static_cast<LONG>(w);
  size->cy = static_cast<LONG>(h);
  *maximized = m != 0;
  return true;
}

void SaveWindowPlacement(HWND window) {
  if (window == nullptr) {
    return;
  }

  WINDOWPLACEMENT placement{};
  placement.length = sizeof(WINDOWPLACEMENT);
  if (!::GetWindowPlacement(window, &placement)) {
    return;
  }

  // rcNormalPosition is the RESTORED rectangle even while maximised, which is
  // the whole reason for using WINDOWPLACEMENT here: somebody who maximises
  // Aura and quits should reopen maximised AND still have their previous
  // restored size waiting behind it.
  const RECT& r = placement.rcNormalPosition;
  const LONG w = r.right - r.left;
  const LONG h = r.bottom - r.top;
  if (w <= 0 || h <= 0) {
    return;
  }

  HKEY key = nullptr;
  if (::RegCreateKeyExW(HKEY_CURRENT_USER, kKey, 0, nullptr,
                        REG_OPTION_NON_VOLATILE, KEY_WRITE, nullptr, &key,
                        nullptr) != ERROR_SUCCESS) {
    return;
  }

  WriteDword(key, kX, static_cast<DWORD>(r.left));
  WriteDword(key, kY, static_cast<DWORD>(r.top));
  WriteDword(key, kW, static_cast<DWORD>(w));
  WriteDword(key, kH, static_cast<DWORD>(h));
  WriteDword(key, kMax,
             placement.showCmd == SW_SHOWMAXIMIZED ? 1u : 0u);
  ::RegCloseKey(key);
}

}  // namespace aura
