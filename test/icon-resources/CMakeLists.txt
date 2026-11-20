# SPDX-License-Identifier: MIT

cmake_minimum_required(VERSION 3.31.6)
project(BridgeIconResourcesProbe LANGUAGES C RC)

if(NOT WIN32)
    message(FATAL_ERROR "The Windows icon resource probe must be built for Windows")
endif()
if(NOT IS_DIRECTORY "${BRIDGE_ICON_PROBE_DIRECTORY}")
    message(FATAL_ERROR "Set BRIDGE_ICON_PROBE_DIRECTORY to a populated icon source directory")
endif()

include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/BridgeApplicationIcons.cmake")
add_executable(bridge_icon_probe main.c)
bridge_embed_win32_application_icon(TARGET bridge_icon_probe ICON_DIRECTORY "${BRIDGE_ICON_PROBE_DIRECTORY}")
