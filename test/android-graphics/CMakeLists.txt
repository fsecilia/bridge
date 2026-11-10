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

# Bridge configures SDL and Java glue together from the vendored dependency.
include("${PROJECT_SOURCE_DIR}/cmake/BridgeSDL.cmake")
bridge_require_sdl(VERSION "3.2.0...<4.0" EXTERNAL_NAME sdl3)

add_library(bridge_android_graphics_runtime SHARED runtime.c)
target_compile_features(bridge_android_graphics_runtime PRIVATE c_std_17)

add_library(bridge_android_graphics_main SHARED main.c)
target_compile_features(bridge_android_graphics_main PRIVATE c_std_17)
target_link_libraries(
    bridge_android_graphics_main
    PRIVATE
        bridge_android_graphics_runtime
        SDL3::SDL3
        GLESv2
)

# Package through the platform-neutral API, so the on-device graphics test also
# covers bridge_add_sdl_application()'s Android path.
include("${PROJECT_SOURCE_DIR}/cmake/BridgeApplication.cmake")
set(_bridge_apk "${CMAKE_CURRENT_BINARY_DIR}/bridge-android-graphics.apk")
bridge_add_sdl_application(
    ALL
    DEBUGGABLE
    TARGET bridge_android_graphics_apk
    RUN_TARGET bridge_android_graphics_run
    MAIN_TARGET bridge_android_graphics_main
    LAUNCHER_SOURCES launcher.c
    APPLICATION_ID com.bonkheavy.bridge.graphics
    APPLICATION_NAME "Bridge Android Graphics"
    OUTPUT "${_bridge_apk}"
    MIN_API "${CMAKE_SYSTEM_VERSION}"
    ASSET_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/assets"
    RUNTIME_TARGETS bridge_android_graphics_runtime
)
get_target_property(_bridge_packaged_apk bridge_android_graphics_apk BRIDGE_ANDROID_APK)
if(NOT _bridge_packaged_apk STREQUAL _bridge_apk)
    message(FATAL_ERROR "bridge_add_sdl_application() packaged '${_bridge_packaged_apk}', expected '${_bridge_apk}'")
endif()

set(BRIDGE_ANDROID_GRAPHICS_APK "${_bridge_apk}" PARENT_SCOPE)
