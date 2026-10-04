# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

include("${CMAKE_CURRENT_LIST_DIR}/../cmake/BridgeWin32Environment.cmake")

list(APPEND CMAKE_TRY_COMPILE_PLATFORM_VARIABLES BRIDGE_LLVM_MINGW_ROOT)

_bridge_find_win32_environment(
    _bridge_win32_available
    _bridge_llvm_mingw_root
    _bridge_c_compiler
    _bridge_cxx_compiler
    _bridge_runtime_dir
    _bridge_wine
    _bridge_winepath
    _bridge_win32_reason
)
if (NOT _bridge_win32_available)
    message(FATAL_ERROR "Bridge Win32 environment is unavailable: ${_bridge_win32_reason}")
endif()

set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_PROCESSOR AMD64)
set(CMAKE_C_COMPILER "${_bridge_c_compiler}")
set(CMAKE_CXX_COMPILER "${_bridge_cxx_compiler}")

set(_bridge_win32_runner "${CMAKE_CURRENT_LIST_DIR}/../runner/bridge-win32.sh")
if (NOT EXISTS "${_bridge_win32_runner}")
    message(FATAL_ERROR "Bridge Win32 runner not found: ${_bridge_win32_runner}")
endif()

set(
    CMAKE_CROSSCOMPILING_EMULATOR
    "${_bridge_win32_runner};${_bridge_wine};${_bridge_winepath};${_bridge_runtime_dir}"
)
