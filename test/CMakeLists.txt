# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

function(_bridge_add_execution_test NAME)
    set(options EMULATED)
    set(one_value_args TOOLCHAIN LLVM_MINGW_ROOT LABEL)
    cmake_parse_arguments(PARSE_ARGV 1 ARG "${options}" "${one_value_args}" "")

    set(_bridge_binary_dir "${CMAKE_CURRENT_BINARY_DIR}/${NAME}")
    set(_bridge_arguments
        "-DBRIDGE_SOURCE_DIR=${PROJECT_SOURCE_DIR}"
        "-DBRIDGE_BINARY_DIR=${_bridge_binary_dir}"
        "-DBRIDGE_GENERATOR=${CMAKE_GENERATOR}"
    )

    if (ARG_TOOLCHAIN)
        list(APPEND _bridge_arguments "-DBRIDGE_TOOLCHAIN_FILE=${ARG_TOOLCHAIN}")
    endif()
    if (ARG_LLVM_MINGW_ROOT)
        list(APPEND _bridge_arguments "-DBRIDGE_LLVM_MINGW_ROOT=${ARG_LLVM_MINGW_ROOT}")
    endif()

    if (ARG_EMULATED)
        list(APPEND _bridge_arguments -DBRIDGE_EXPECT_TEST_EMULATOR=TRUE)
    else()
        list(APPEND _bridge_arguments -DBRIDGE_EXPECT_TEST_EMULATOR=FALSE)
    endif()

    add_test(
        NAME "bridge.integration.execution.${NAME}"
        COMMAND
            "${CMAKE_COMMAND}"
            ${_bridge_arguments}
            -P "${CMAKE_CURRENT_SOURCE_DIR}/execution/test.cmake"
    )

    set(_bridge_labels integration)
    if (ARG_LABEL)
        list(APPEND _bridge_labels "${ARG_LABEL}")
    endif()
    set_tests_properties(
        "bridge.integration.execution.${NAME}"
        PROPERTIES
            LABELS "${_bridge_labels}"
            TIMEOUT 120
    )
endfunction()

function(_bridge_add_win32_runner_test NAME MODE)
    add_test(
        NAME "bridge.runner.win32.${NAME}"
        COMMAND
            "${CMAKE_COMMAND}"
            "-DBRIDGE_RUNNER=${PROJECT_SOURCE_DIR}/runner/bridge-win32.sh"
            "-DBRIDGE_RUNNER_TEST_BINARY_DIR=${CMAKE_CURRENT_BINARY_DIR}/runner-${NAME}"
            "-DBRIDGE_RUNNER_TEST_MODE=${MODE}"
            -P "${PROJECT_SOURCE_DIR}/runner/test.cmake"
    )
    set_tests_properties(
        "bridge.runner.win32.${NAME}"
        PROPERTIES LABELS "runner;win32"
    )
endfunction()

enable_language(CXX)

add_subdirectory(canon)

_bridge_add_win32_runner_test(output output)
_bridge_add_win32_runner_test(exit-status exit)
_bridge_add_win32_runner_test(anchor-reuse anchor)

_bridge_add_execution_test(native)
_bridge_add_execution_test(
    emulated
    EMULATED
    TOOLCHAIN "${CMAKE_CURRENT_SOURCE_DIR}/execution/emulated-toolchain.cmake"
)

if (BRIDGE_WIN32_AVAILABLE)
    message(STATUS "Bridge Win32 integration tests: enabled")
    _bridge_add_execution_test(
        win32
        TOOLCHAIN "${PROJECT_SOURCE_DIR}/toolchains/bridge-win32.cmake"
        LLVM_MINGW_ROOT "${BRIDGE_LLVM_MINGW_DISCOVERED_ROOT}"
        LABEL win32
    )
else()
    message(STATUS "Bridge Win32 integration tests: disabled")
endif()
