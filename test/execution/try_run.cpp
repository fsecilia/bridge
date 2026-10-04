// SPDX-License-Identifier: MIT

/// \file
/// \copyright Copyright (C) 2026 Frank Secilia

#include <cstdlib>
#include <iostream>

int main()
{
    if (std::getenv("BRIDGE_TEST_EMULATOR") != nullptr) {
        std::cout << "bridge test emulator marker\n";
    }
    return 0;
}
