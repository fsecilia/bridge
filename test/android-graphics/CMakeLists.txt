# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

if(NOT ANDROID)
    message(FATAL_ERROR "Bridge Android graphics specimen requires an Android target")
endif()
if(NOT CMAKE_ANDROID_ARCH_ABI MATCHES "^(x86_64|arm64-v8a)$")
    message(
        FATAL_ERROR
        "Bridge Android graphics specimen requires x86_64 or arm64-v8a, got ${CMAKE_ANDROID_ARCH_ABI}"
    )
endif()
if(NOT DEFINED BRIDGE_ANDROID_GRAPHICS_SDL_SOURCE_DIR OR "${BRIDGE_ANDROID_GRAPHICS_SDL_SOURCE_DIR}" STREQUAL "")
    message(FATAL_ERROR "BRIDGE_ANDROID_GRAPHICS_SDL_SOURCE_DIR is required")
endif()
if(NOT EXISTS "${BRIDGE_ANDROID_GRAPHICS_SDL_SOURCE_DIR}/CMakeLists.txt")
    message(FATAL_ERROR "BRIDGE_ANDROID_GRAPHICS_SDL_SOURCE_DIR is not an SDL source tree: ${BRIDGE_ANDROID_GRAPHICS_SDL_SOURCE_DIR}")
endif()
if(NOT CMAKE_SYSTEM_VERSION MATCHES "^[0-9]+$")
    message(FATAL_ERROR "Android API level is unavailable from CMAKE_SYSTEM_VERSION: ${CMAKE_SYSTEM_VERSION}")
endif()

enable_language(C)

set(SDL_SHARED ON CACHE BOOL "" FORCE)
set(SDL_STATIC OFF CACHE BOOL "" FORCE)
set(SDL_TEST_LIBRARY OFF CACHE BOOL "" FORCE)
set(SDL_TESTS OFF CACHE BOOL "" FORCE)
set(SDL_EXAMPLES OFF CACHE BOOL "" FORCE)
set(SDL_INSTALL OFF CACHE BOOL "" FORCE)
if(DEFINED CMAKE_MESSAGE_LOG_LEVEL)
    add_subdirectory("${BRIDGE_ANDROID_GRAPHICS_SDL_SOURCE_DIR}" SDL EXCLUDE_FROM_ALL)
else()
    block()
        set(CMAKE_MESSAGE_LOG_LEVEL WARNING)
        add_subdirectory("${BRIDGE_ANDROID_GRAPHICS_SDL_SOURCE_DIR}" SDL EXCLUDE_FROM_ALL)
    endblock()
endif()

if(NOT TARGET SDL3-shared)
    message(FATAL_ERROR "SDL source tree did not provide the required SDL3-shared target")
endif()

add_library(bridge_android_graphics_main SHARED main.c)
target_compile_features(bridge_android_graphics_main PRIVATE c_std_17)
target_link_libraries(bridge_android_graphics_main PRIVATE SDL3::SDL3-shared GLESv2)

include("${PROJECT_SOURCE_DIR}/cmake/BridgeAndroidPackaging.cmake")
set(_bridge_apk "${CMAKE_CURRENT_BINARY_DIR}/bridge-android-graphics.apk")
_bridge_add_sdl_android_apk(
    ALL
    TARGET bridge_android_graphics_apk
    APPLICATION_ID com.bonkheavy.bridge.graphics
    APPLICATION_NAME "Bridge Android Graphics"
    NATIVE_TARGET bridge_android_graphics_main
    SDL_TARGET SDL3-shared
    SDL_SOURCE_DIR "${BRIDGE_ANDROID_GRAPHICS_SDL_SOURCE_DIR}"
    OUTPUT "${_bridge_apk}"
    MIN_API "${CMAKE_SYSTEM_VERSION}"
)

set(BRIDGE_ANDROID_GRAPHICS_APK "${_bridge_apk}" PARENT_SCOPE)
