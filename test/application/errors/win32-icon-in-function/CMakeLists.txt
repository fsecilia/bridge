# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

# CMake enables RC for Windows projects with C or C++, so only a project
# without them can reach the icon helper with RC disabled.
cmake_minimum_required(VERSION 3.31.6)
project(BridgeWin32IconInFunctionFixture LANGUAGES NONE)
include("${BRIDGE_SOURCE_DIR}/cmake/BridgeApplicationIcons.cmake")

add_executable(game IMPORTED)

function(add_icon)
    bridge_add_win32_application_icon(TARGET game ICON_DIRECTORY icons)
endfunction()
add_icon()
