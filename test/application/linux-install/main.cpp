// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Frank Secilia

extern "C" int bridge_linux_install_sdl();
extern "C" int bridge_linux_install_entry() {
    return bridge_linux_install_sdl() == 7 ? 0 : 1;
}
