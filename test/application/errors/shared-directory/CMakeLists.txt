# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

cmake_minimum_required(VERSION 3.31.6)
project(BridgeSharedDirectoryFixture LANGUAGES CXX)
include("${BRIDGE_SOURCE_DIR}/cmake/BridgeApplication.cmake")

file(MAKE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/first" "${CMAKE_CURRENT_BINARY_DIR}/second")
add_executable(first main.cpp)
add_executable(second main.cpp)
bridge_stage_runtime(TARGET first ASSET_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/first")
bridge_stage_runtime(TARGET second ASSET_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/second")
