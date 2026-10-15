// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Frank Secilia

// Stands in for an application's main library. It checks that the runtime
// assets and icons were staged beside the running executable.

#include <filesystem>
#include <fstream>
#include <iostream>
#include <iterator>
#include <string>

#if defined(_WIN32)
#include <windows.h>
#define BRIDGE_APPLICATION_EXPORT __declspec(dllexport)
#else
#define BRIDGE_APPLICATION_EXPORT __attribute__((visibility("default")))
#endif

extern "C" int bridge_application_sdl_marker();

namespace {

auto executableDirectory() -> std::filesystem::path {
#if defined(_WIN32)
    wchar_t buffer[32768]{};
    auto const length = GetModuleFileNameW(nullptr, buffer, static_cast<DWORD>(std::size(buffer)));
    return std::filesystem::path{std::wstring{buffer, length}}.parent_path();
#else
    return std::filesystem::read_symlink("/proc/self/exe").parent_path();
#endif
}

} // namespace

extern "C" BRIDGE_APPLICATION_EXPORT int bridge_application_entry() {
    if (bridge_application_sdl_marker() != 42) {
        std::cerr << "Bridge application: SDL stand-in is not linked\n";
        return 1;
    }
    auto const directory = executableDirectory();
    auto input = std::ifstream{directory / "fixtures" / "expected.txt"};
    auto const content = std::string{std::istreambuf_iterator<char>{input}, std::istreambuf_iterator<char>{}};
    if (content != "Bridge application asset\n") {
        std::cerr << "Bridge application: runtime assets were not staged beside " << directory << "\n";
        return 1;
    }
    if (!std::filesystem::is_regular_file(directory / "icons" / "icon-32.png")) {
        std::cerr << "Bridge application: icons were not staged beside " << directory << "\n";
        return 1;
    }
    return 0;
}
