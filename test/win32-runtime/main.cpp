// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Frank Secilia

extern "C" __declspec(dllimport) int bridgeWin32RuntimeValue();

int main() {
    return bridgeWin32RuntimeValue() == 17 ? 0 : 1;
}
