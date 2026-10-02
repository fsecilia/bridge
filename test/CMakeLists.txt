# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

function(_bridge_add_execution_test NAME)
    set(options EMULATED)
    cmake_parse_arguments(PARSE_ARGV 1 ARG "${options}" "" "")

    set(_bridge_binary_dir "${CMAKE_CURRENT_BINARY_DIR}/${NAME}")
    set(_bridge_arguments
        "-DBRIDGE_SOURCE_DIR=${PROJECT_SOURCE_DIR}"
        "-DBRIDGE_BINARY_DIR=${_bridge_binary_dir}"
        "-DBRIDGE_GENERATOR=${CMAKE_GENERATOR}"
    )

    if (ARG_EMULATED)
        list(APPEND _bridge_arguments
            "-DBRIDGE_TOOLCHAIN_FILE=${CMAKE_CURRENT_SOURCE_DIR}/execution/emulated-toolchain.cmake"
            -DBRIDGE_EXPECT_EMULATOR=TRUE
        )
    else()
        list(APPEND _bridge_arguments -DBRIDGE_EXPECT_EMULATOR=FALSE)
    endif()

    add_test(
        NAME "bridge.integration.execution.${NAME}"
        COMMAND
            "${CMAKE_COMMAND}"
            ${_bridge_arguments}
            -P "${CMAKE_CURRENT_SOURCE_DIR}/execution/test.cmake"
    )
    set_tests_properties(
        "bridge.integration.execution.${NAME}"
        PROPERTIES
            LABELS integration
            TIMEOUT 120
    )
endfunction()

_bridge_add_execution_test(native)
_bridge_add_execution_test(emulated EMULATED)
