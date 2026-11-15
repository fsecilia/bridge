// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Frank Secilia

extern "C" int bridge_application_entry();

#if defined _WIN32
#include <windows.h>

int WINAPI WinMain(HINSTANCE, HINSTANCE, LPSTR, int) {
    return bridge_application_entry();
}
#endif

int main() {
    return bridge_application_entry();
}
