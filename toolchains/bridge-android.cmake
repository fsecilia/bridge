# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

include("${CMAKE_CURRENT_LIST_DIR}/../cmake/BridgeAndroidNdk.cmake")

if (NOT DEFINED CMAKE_ANDROID_ARCH_ABI OR "${CMAKE_ANDROID_ARCH_ABI}" STREQUAL "")
    message(
        FATAL_ERROR
        "CMAKE_ANDROID_ARCH_ABI is required by the Bridge Android toolchain. "
        "Use an Android Bridge preset or set CMAKE_ANDROID_ARCH_ABI explicitly."
    )
endif()
if (
    NOT CMAKE_ANDROID_ARCH_ABI STREQUAL "x86_64"
    AND NOT CMAKE_ANDROID_ARCH_ABI STREQUAL "arm64-v8a"
)
    message(FATAL_ERROR "Unsupported Bridge Android ABI: ${CMAKE_ANDROID_ARCH_ABI}")
endif()

if (NOT DEFINED BRIDGE_ANDROID_PLATFORM OR "${BRIDGE_ANDROID_PLATFORM}" STREQUAL "")
    set(BRIDGE_ANDROID_PLATFORM android-21)
endif()

_bridge_find_android_ndk(
    _bridge_android_ndk_available
    _bridge_android_ndk_root
    _bridge_android_ndk_revision
    _bridge_android_ndk_reason
)
if (NOT _bridge_android_ndk_available)
    message(FATAL_ERROR "Bridge Android NDK is unavailable: ${_bridge_android_ndk_reason}")
endif()

set(
    CMAKE_ANDROID_NDK
    "${_bridge_android_ndk_root}"
    CACHE PATH "Android NDK used by the Bridge Android toolchain"
)
set(ANDROID_ABI "${CMAKE_ANDROID_ARCH_ABI}")
set(ANDROID_PLATFORM "${BRIDGE_ANDROID_PLATFORM}")

include("${CMAKE_ANDROID_NDK}/build/cmake/android.toolchain.cmake")

# The NDK toolchain establishes its own try-compile propagation list. Append
# Bridge inputs afterward so nested compiler checks see the same target.
list(APPEND CMAKE_TRY_COMPILE_PLATFORM_VARIABLES
    CMAKE_ANDROID_ARCH_ABI
    BRIDGE_ANDROID_PLATFORM
    CMAKE_ANDROID_NDK
)
list(REMOVE_DUPLICATES CMAKE_TRY_COMPILE_PLATFORM_VARIABLES)

set(_bridge_android_runtime "${CMAKE_CURRENT_LIST_DIR}/../cmake/BridgeAndroidRuntime.cmake")
list(APPEND CMAKE_PROJECT_TOP_LEVEL_INCLUDES "${_bridge_android_runtime}")
list(REMOVE_DUPLICATES CMAKE_PROJECT_TOP_LEVEL_INCLUDES)
