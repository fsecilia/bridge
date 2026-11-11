# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

cmake_minimum_required(VERSION 3.31.6)
project(BridgeLinuxInstallFixture LANGUAGES CXX)

if(NOT BRIDGE_SOURCE_DIR OR NOT BRIDGE_INSTALL_FIXTURE_ASSETS OR NOT BRIDGE_INSTALL_FIXTURE_ICONS)
    message(FATAL_ERROR "Linux install fixture requires Bridge source, assets, and icons")
endif()
if(NOT BRIDGE_SDL_KIND MATCHES "^(built|imported)$")
    message(FATAL_ERROR "Linux install fixture requires BRIDGE_SDL_KIND=built or imported")
endif()
include("${BRIDGE_SOURCE_DIR}/test/canon/load.cmake")
include("${BRIDGE_SOURCE_DIR}/cmake/BridgeApplication.cmake")

add_library(bridge_linux_install_sdl SHARED sdl.cpp)
add_library(bridge_linux_install_extra SHARED extra.cpp)
add_library(bridge_linux_install_imported_sdl SHARED IMPORTED)
add_library(bridge_linux_install_imported_extra SHARED IMPORTED)
set_target_properties(bridge_linux_install_imported_sdl PROPERTIES
    IMPORTED_LOCATION "${CMAKE_CURRENT_BINARY_DIR}/libbridge_linux_install_sdl.so")
set_target_properties(bridge_linux_install_imported_extra PROPERTIES
    IMPORTED_LOCATION "${CMAKE_CURRENT_BINARY_DIR}/libbridge_linux_install_extra.so")

set(_sdl_target bridge_linux_install_sdl)
if(BRIDGE_SDL_KIND STREQUAL "imported")
    set(_sdl_target bridge_linux_install_imported_sdl)
endif()
add_library(SDL3::SDL3 ALIAS "${_sdl_target}")
set_property(TARGET "${_sdl_target}" PROPERTY SDL_FULL_VERSION "3.4.18")
bridge_require_sdl(VERSION "3.2.0...<4.0")
add_library(bridge_linux_install_main SHARED main.cpp)
target_link_libraries(bridge_linux_install_main PRIVATE "${_sdl_target}")

set(_install_options)
if(BRIDGE_SDL_APPLICATION_RUNTIME)
    list(APPEND _install_options SDL_RUNTIME "${BRIDGE_SDL_APPLICATION_RUNTIME}")
endif()
if(BRIDGE_APPLICATION_DESKTOP_INTEGRATION)
    list(APPEND _install_options DESKTOP_INTEGRATION "${BRIDGE_APPLICATION_DESKTOP_INTEGRATION}")
endif()
if(BRIDGE_APPLICATION_INSTALL_COMPONENT)
    list(APPEND _install_options INSTALL_COMPONENT "${BRIDGE_APPLICATION_INSTALL_COMPONENT}")
    # A package that selects the application component must leave this out.
    install(FILES extra.cpp DESTINATION share/unrelated COMPONENT unrelated)
endif()
set(_runtime_targets bridge_linux_install_imported_extra)
if(BRIDGE_DUPLICATE_SDL_RUNTIME)
    list(APPEND _runtime_targets "${_sdl_target}")
endif()
bridge_add_sdl_application(
    ${_install_options}
    TARGET bridge_linux_install_game
    RUN_TARGET bridge_linux_install_run
    MAIN_TARGET bridge_linux_install_main
    LAUNCHER_SOURCES launcher.cpp
    APPLICATION_ID org.bridge.linuxinstall
    APPLICATION_NAME "Bridge Linux Install"
    ICON_DIRECTORY "${BRIDGE_INSTALL_FIXTURE_ICONS}"
    ADAPTIVE_ICON_BACKGROUND_COLOR "#08090B"
    ASSET_DIRECTORY "${BRIDGE_INSTALL_FIXTURE_ASSETS}"
    RUNTIME_TARGETS ${_runtime_targets}
)
