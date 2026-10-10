# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

include("${PROJECT_SOURCE_DIR}/cmake/BridgeWin32Runtime.cmake")

add_library(bridge_win32_runtime_dependency SHARED dependency.cpp)
set_target_properties(
    bridge_win32_runtime_dependency
    PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/dependencies"
)

add_executable(bridge_win32_runtime_consumer main.cpp)
target_link_libraries(bridge_win32_runtime_consumer PRIVATE bridge_win32_runtime_dependency)
set_target_properties(
    bridge_win32_runtime_consumer
    PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/consumer"
)
bridge_stage_win32_runtime(TARGET bridge_win32_runtime_consumer)

set(_bridge_expected_compiler_dlls "")
set(_bridge_expected_compiler_dir "")
get_filename_component(_bridge_compiler_name "${CMAKE_CXX_COMPILER}" NAME)
if(_bridge_compiler_name MATCHES "^([A-Za-z0-9_]+-w64-mingw32)-clang\\+\\+$")
    list(APPEND _bridge_expected_compiler_dlls libc++.dll libunwind.dll)
    set(_bridge_compiler_triplet "${CMAKE_MATCH_1}")
    cmake_path(GET CMAKE_CXX_COMPILER PARENT_PATH _bridge_compiler_bin)
    cmake_path(GET _bridge_compiler_bin PARENT_PATH _bridge_toolchain_root)
    set(_bridge_expected_compiler_dir "${_bridge_toolchain_root}/${_bridge_compiler_triplet}/bin")
endif()

add_test(
    NAME bridge.win32.runtime.staging
    COMMAND "${CMAKE_COMMAND}"
        "-DBRIDGE_RUNTIME_DESTINATION=$<TARGET_FILE_DIR:bridge_win32_runtime_consumer>"
        "-DBRIDGE_RUNTIME_DEPENDENCY=$<TARGET_FILE:bridge_win32_runtime_dependency>"
        "-DBRIDGE_RUNTIME_COMPILER_DLLS=${_bridge_expected_compiler_dlls}"
        "-DBRIDGE_RUNTIME_COMPILER_DIR=${_bridge_expected_compiler_dir}"
        -P "${CMAKE_CURRENT_SOURCE_DIR}/check.cmake"
)
set_tests_properties(bridge.win32.runtime.staging PROPERTIES LABELS "win32;runtime")
