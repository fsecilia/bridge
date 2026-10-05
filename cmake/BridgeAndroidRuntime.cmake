# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

include_guard(GLOBAL)

include("${CMAKE_CURRENT_LIST_DIR}/BridgeAndroidEnvironment.cmake")

if (NOT DEFINED CMAKE_ANDROID_ARCH_ABI OR "${CMAKE_ANDROID_ARCH_ABI}" STREQUAL "")
    message(FATAL_ERROR "CMAKE_ANDROID_ARCH_ABI is unavailable during Bridge Android runtime initialization")
endif()

set(_bridge_android_runner "${CMAKE_CURRENT_LIST_DIR}/../runner/bridge-android.sh")
if (NOT EXISTS "${_bridge_android_runner}")
    message(FATAL_ERROR "Bridge Android runner not found: ${_bridge_android_runner}")
endif()

_bridge_find_android_environment(
    _bridge_android_runtime_available
    _bridge_android_sdk_root
    _bridge_adb
    _bridge_android_runtime_reason
)

if (_bridge_android_runtime_available)
    set(
        CMAKE_CROSSCOMPILING_EMULATOR
        "${_bridge_android_runner};${_bridge_adb};${CMAKE_ANDROID_ARCH_ABI}"
    )
    message(STATUS "Bridge Android execution: available (${_bridge_adb})")
else()
    set(
        CMAKE_CROSSCOMPILING_EMULATOR
        "${_bridge_android_runner};--adb-unavailable;${CMAKE_ANDROID_ARCH_ABI}"
    )
    message(STATUS "Bridge Android execution: unavailable")
    message(STATUS "  ${_bridge_android_runtime_reason}")
endif()
