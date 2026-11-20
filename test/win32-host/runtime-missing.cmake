# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

include("${BRIDGE_SOURCE_DIR}/cmake/BridgeWin32Runtime.cmake")
set(CMAKE_CXX_COMPILER_ID Clang)
set(CMAKE_CXX_COMPILER "${BRIDGE_RUNTIME_MISSING_DIR}/clang++.exe")
_bridge_win32_compiler_runtime_dlls(_dlls)
