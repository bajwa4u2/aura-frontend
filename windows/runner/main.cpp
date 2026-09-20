#include "window_placement.h"
#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "call_push.h"
#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  // A CALL ARRIVING WHILE AURA IS CLOSED STARTS THIS SAME EXECUTABLE.
  //
  // Windows launches the package's COM server to service the push background
  // task. That process must not build a window, an engine or a UI: it records
  // the payload, starts Aura properly, and exits. Checked before COM is
  // initialised because `RunComServer` owns the apartment it needs.
  if (aura::IsComServerLaunch(command_line_arguments)) {
    return aura::RunComServer();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);

  // OPEN WHERE THIS PERSON LEFT IT.
  //
  // Aura opened at 1280x720 in the corner on every launch, discarding
  // whatever the person had chosen the last time. On a desktop that reads as
  // an application that does not live there.
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  POINT saved_origin{};
  SIZE saved_size{};
  bool saved_maximized = false;
  const bool restored =
      aura::RestoreWindowPlacement(&saved_origin, &saved_size, &saved_maximized);
  if (restored) {
    origin = Win32Window::Point(saved_origin.x, saved_origin.y);
    size = Win32Window::Size(saved_size.cx, saved_size.cy);
  }

  if (restored && saved_maximized) {
    window.SetStartMaximized(true);
  }
  if (!window.Create(L"aura", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
