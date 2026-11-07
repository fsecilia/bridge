// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Frank Secilia

extern "C" int bridge_install_marker();

auto main() -> int {
    return bridge_install_marker() == 8 ? 0 : 1;
}
