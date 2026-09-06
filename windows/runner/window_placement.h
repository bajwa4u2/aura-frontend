#ifndef RUNNER_WINDOW_PLACEMENT_H_
#define RUNNER_WINDOW_PLACEMENT_H_

#include <windows.h>

// REMEMBERING THE WINDOW.
//
// A desktop application that opens at 1280x720 in the top-left corner every
// single time is one that has not noticed it is a desktop application. Somebody
// who maximises Aura, or sizes it to half their display beside something else,
// has told it where they want it; reverting on the next launch throws that away
// and makes them say it again.
//
// Stored in HKCU rather than in a file: it is per-user, per-machine, tiny, and
// wants no lifecycle of its own. Nothing here is content, identity or
// preference in the product sense -- it is where a window sat.
//
// Every function is best-effort. A machine that refuses the registry gets the
// default placement, which is exactly what it gets today.
namespace aura {

// Restores the last placement into |origin| and |size| (logical pixels) and
// reports whether the window was maximised. Returns false when there is
// nothing remembered, or when what is remembered would put the window off
// every current display -- a monitor that has been unplugged must not take the
// window with it.
bool RestoreWindowPlacement(POINT* origin, SIZE* size, bool* maximized);

// Records the window's current placement. Called as the window is destroyed.
void SaveWindowPlacement(HWND window);

}  // namespace aura

#endif  // RUNNER_WINDOW_PLACEMENT_H_
