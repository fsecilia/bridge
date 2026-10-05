# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

include("${CMAKE_CURRENT_LIST_DIR}/../cmake/BridgeAndroidEnvironment.cmake")

list(APPEND CMAKE_TRY_COMPILE_PLATFORM_VARIABLES
    BRIDGE_ANDROID_ABI
    BRIDGE_ANDROID_NDK_ROOT
    BRIDGE_ANDROID_PLATFORM
    BRIDGE_ANDROID_SDK_ROOT
)

if (NOT DEFINED BRIDGE_ANDROID_ABI OR "${BRIDGE_ANDROID_ABI}" STREQUAL "")
    message(FATAL_ERROR "BRIDGE_ANDROID_ABI is required by the Bridge Android toolchain")
endif()
if (NOT BRIDGE_ANDROID_ABI STREQUAL "x86_64" AND NOT BRIDGE_ANDROID_ABI STREQUAL "arm64-v8a")
    message(FATAL_ERROR "Unsupported Bridge Android ABI: ${BRIDGE_ANDROID_ABI}")
endif()

if (NOT DEFINED BRIDGE_ANDROID_PLATFORM OR "${BRIDGE_ANDROID_PLATFORM}" STREQUAL "")
    set(BRIDGE_ANDROID_PLATFORM android-21)
endif()

_bridge_find_android_environment(
    _bridge_android_available
    _bridge_android_sdk_root
    _bridge_android_ndk_root
    _bridge_android_ndk_revision
    _bridge_adb
    _bridge_android_reason
)
if (NOT _bridge_android_available)
    message(FATAL_ERROR "Bridge Android environment is unavailable: ${_bridge_android_reason}")
endif()

set(ANDROID_ABI "${BRIDGE_ANDROID_ABI}")
set(ANDROID_NDK "${_bridge_android_ndk_root}")
set(ANDROID_PLATFORM "${BRIDGE_ANDROID_PLATFORM}")

include("${_bridge_android_ndk_root}/build/cmake/android.toolchain.cmake")

set(_bridge_android_runner "${CMAKE_CURRENT_LIST_DIR}/../runner/bridge-android.sh")
if (NOT EXISTS "${_bridge_android_runner}")
    message(FATAL_ERROR "Bridge Android runner not found: ${_bridge_android_runner}")
endif()

set(
    CMAKE_CROSSCOMPILING_EMULATOR
    "${_bridge_android_runner};${_bridge_adb};${BRIDGE_ANDROID_ABI}"
)
