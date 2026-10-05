# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

cmake_minimum_required(VERSION 3.31.6)

project(Bridge VERSION 0.1.0 LANGUAGES NONE)

if (PROJECT_IS_TOP_LEVEL)
    include(CTest)
endif()

if (NOT COMMAND canon_apply_target)
    if (EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/external/canon/CMakeLists.txt")
        add_subdirectory(external/canon EXCLUDE_FROM_ALL)
    else()
        find_package(Canon 0.1 CONFIG REQUIRED)
    endif()
endif()

include(cmake/BridgeWin32Environment.cmake)
_bridge_find_win32_environment(
    BRIDGE_WIN32_AVAILABLE
    BRIDGE_LLVM_MINGW_DISCOVERED_ROOT
    BRIDGE_WIN32_C_COMPILER
    BRIDGE_WIN32_CXX_COMPILER
    BRIDGE_WIN32_RUNTIME_DIR
    BRIDGE_WINE_EXECUTABLE
    BRIDGE_WINEPATH_EXECUTABLE
    BRIDGE_WIN32_UNAVAILABLE_REASON
)
if (BRIDGE_WIN32_AVAILABLE)
    message(STATUS "Bridge Win32 environment: available (${BRIDGE_LLVM_MINGW_DISCOVERED_ROOT})")
else()
    message(STATUS "Bridge Win32 environment: unavailable")
    message(STATUS "  ${BRIDGE_WIN32_UNAVAILABLE_REASON}")
endif()

include(cmake/BridgeAndroidNdk.cmake)
_bridge_find_android_ndk(
    BRIDGE_ANDROID_NDK_AVAILABLE
    BRIDGE_ANDROID_DISCOVERED_NDK_ROOT
    BRIDGE_ANDROID_NDK_REVISION
    BRIDGE_ANDROID_NDK_UNAVAILABLE_REASON
)
if (BRIDGE_ANDROID_NDK_AVAILABLE)
    message(STATUS "Bridge Android NDK: available (${BRIDGE_ANDROID_DISCOVERED_NDK_ROOT})")
else()
    message(STATUS "Bridge Android NDK: unavailable")
    message(STATUS "  ${BRIDGE_ANDROID_NDK_UNAVAILABLE_REASON}")
endif()

include(cmake/BridgeAndroidEnvironment.cmake)
_bridge_find_android_environment(
    BRIDGE_ANDROID_RUNTIME_AVAILABLE
    BRIDGE_ANDROID_DISCOVERED_SDK_ROOT
    BRIDGE_ADB_EXECUTABLE
    BRIDGE_ANDROID_RUNTIME_UNAVAILABLE_REASON
)
if (BRIDGE_ANDROID_RUNTIME_AVAILABLE)
    message(STATUS "Bridge Android execution: available (${BRIDGE_ADB_EXECUTABLE})")
else()
    message(STATUS "Bridge Android execution: unavailable")
    message(STATUS "  ${BRIDGE_ANDROID_RUNTIME_UNAVAILABLE_REASON}")
endif()

if (BUILD_TESTING)
    add_subdirectory(test)
endif()
