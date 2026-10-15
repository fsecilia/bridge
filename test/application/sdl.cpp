// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Frank Secilia

// Stands in for SDL: the application must link and load the SDL target.

#if defined(_WIN32)
#define BRIDGE_APPLICATION_SDL_EXPORT __declspec(dllexport)
#else
#define BRIDGE_APPLICATION_SDL_EXPORT __attribute__((visibility("default")))
#endif

extern "C" BRIDGE_APPLICATION_SDL_EXPORT int bridge_application_sdl_marker() {
    return 42;
}
