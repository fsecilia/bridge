# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

cmake_minimum_required(VERSION 3.31.6)

project(BridgeAndroidGraphicsSpecimen LANGUAGES C)

if (NOT ANDROID)
    message(FATAL_ERROR "Bridge Android graphics specimen requires an Android target")
endif()
if (NOT DEFINED BRIDGE_SOURCE_DIR OR "${BRIDGE_SOURCE_DIR}" STREQUAL "")
    message(FATAL_ERROR "BRIDGE_SOURCE_DIR is required")
endif()
if (NOT DEFINED BRIDGE_SDL_SOURCE_DIR OR "${BRIDGE_SDL_SOURCE_DIR}" STREQUAL "")
    message(FATAL_ERROR "BRIDGE_SDL_SOURCE_DIR is required")
endif()
if (NOT EXISTS "${BRIDGE_SDL_SOURCE_DIR}/CMakeLists.txt")
    message(FATAL_ERROR "BRIDGE_SDL_SOURCE_DIR is not an SDL source tree: ${BRIDGE_SDL_SOURCE_DIR}")
endif()

set(SDL_SHARED ON CACHE BOOL "" FORCE)
set(SDL_STATIC OFF CACHE BOOL "" FORCE)
set(SDL_TEST_LIBRARY OFF CACHE BOOL "" FORCE)
set(SDL_TESTS OFF CACHE BOOL "" FORCE)
set(SDL_EXAMPLES OFF CACHE BOOL "" FORCE)
set(SDL_INSTALL OFF CACHE BOOL "" FORCE)
add_subdirectory("${BRIDGE_SDL_SOURCE_DIR}" SDL EXCLUDE_FROM_ALL)

if (NOT TARGET SDL3-shared)
    message(FATAL_ERROR "SDL source tree did not provide the required SDL3-shared target")
endif()
if (NOT CMAKE_SYSTEM_VERSION MATCHES "^[0-9]+$")
    message(FATAL_ERROR "Android API level is unavailable from CMAKE_SYSTEM_VERSION: ${CMAKE_SYSTEM_VERSION}")
endif()

add_library(main SHARED main.c)
target_compile_features(main PRIVATE c_std_17)
target_link_libraries(main PRIVATE SDL3::SDL3-shared GLESv2)

include("${BRIDGE_SOURCE_DIR}/cmake/BridgeAndroidPackaging.cmake")
set(_bridge_apk "${CMAKE_CURRENT_BINARY_DIR}/bridge-android-graphics.apk")
_bridge_add_sdl_android_apk(
    TARGET bridge_android_graphics_apk
    APPLICATION_ID com.bonkheavy.bridge.graphics
    APPLICATION_NAME "Bridge Android Graphics"
    NATIVE_TARGET main
    SDL_TARGET SDL3-shared
    SDL_SOURCE_DIR "${BRIDGE_SDL_SOURCE_DIR}"
    OUTPUT "${_bridge_apk}"
    MIN_API "${CMAKE_SYSTEM_VERSION}"
)
