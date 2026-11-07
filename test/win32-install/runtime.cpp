// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Frank Secilia

#if defined(_WIN32)
#define BRIDGE_EXPORT __declspec(dllexport)
#else
#define BRIDGE_EXPORT __attribute__((visibility("default")))
#endif

extern "C" BRIDGE_EXPORT auto bridge_install_marker() -> int {
    return 8;
}
