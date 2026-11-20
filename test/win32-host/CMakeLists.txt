# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

cmake_minimum_required(VERSION 3.31.6)
project(BridgeWin32HostFixture LANGUAGES CXX)

# The fixture is compiled for the local test host. Only Bridge's host/target selection is simulated.
set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_HOST_WIN32 TRUE)
set(CMAKE_CROSSCOMPILING FALSE)
include("${BRIDGE_SOURCE_DIR}/cmake/BridgeWin32Run.cmake")

add_executable(bridge_win32_host_fixture main.cpp)
bridge_add_win32_run_target(TARGET bridge_win32_host_launch APPLICATION_TARGET bridge_win32_host_fixture)
