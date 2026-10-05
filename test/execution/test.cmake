# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

if (NOT DEFINED BRIDGE_SOURCE_DIR)
    message(FATAL_ERROR "BRIDGE_SOURCE_DIR is required")
endif()
if (NOT DEFINED BRIDGE_BINARY_DIR)
    message(FATAL_ERROR "BRIDGE_BINARY_DIR is required")
endif()
if (NOT DEFINED BRIDGE_GENERATOR)
    message(FATAL_ERROR "BRIDGE_GENERATOR is required")
endif()
if (NOT DEFINED BRIDGE_EXPECT_TEST_EMULATOR)
    message(FATAL_ERROR "BRIDGE_EXPECT_TEST_EMULATOR is required")
endif()

file(REMOVE_RECURSE "${BRIDGE_BINARY_DIR}")

set(_bridge_configure_command
    "${CMAKE_COMMAND}"
    -S "${BRIDGE_SOURCE_DIR}/test/execution"
    -B "${BRIDGE_BINARY_DIR}"
    -G "${BRIDGE_GENERATOR}"
)
if (DEFINED BRIDGE_TOOLCHAIN_FILE)
    list(APPEND _bridge_configure_command --toolchain "${BRIDGE_TOOLCHAIN_FILE}")
endif()
if (DEFINED BRIDGE_LLVM_MINGW_ROOT)
    list(APPEND _bridge_configure_command
        "-DBRIDGE_LLVM_MINGW_ROOT:PATH=${BRIDGE_LLVM_MINGW_ROOT}")
endif()
if (DEFINED BRIDGE_ANDROID_NDK_ROOT)
    list(APPEND _bridge_configure_command
        "-DBRIDGE_ANDROID_NDK_ROOT:PATH=${BRIDGE_ANDROID_NDK_ROOT}")
endif()
if (DEFINED BRIDGE_ANDROID_SDK_ROOT AND NOT "${BRIDGE_ANDROID_SDK_ROOT}" STREQUAL "")
    list(APPEND _bridge_configure_command
        "-DBRIDGE_ANDROID_SDK_ROOT:PATH=${BRIDGE_ANDROID_SDK_ROOT}")
endif()
if (DEFINED BRIDGE_ANDROID_ABI)
    list(APPEND _bridge_configure_command
        "-DBRIDGE_ANDROID_ABI:STRING=${BRIDGE_ANDROID_ABI}")
endif()
list(APPEND _bridge_configure_command
    "-DBRIDGE_EXPECT_TEST_EMULATOR:BOOL=${BRIDGE_EXPECT_TEST_EMULATOR}"
    "-DBRIDGE_REMOTE_EXECUTION:BOOL=${BRIDGE_REMOTE_EXECUTION}"
)

execute_process(
    COMMAND ${_bridge_configure_command}
    RESULT_VARIABLE _bridge_configure_result
)
if (NOT "${_bridge_configure_result}" STREQUAL "0")
    message(FATAL_ERROR "Bridge execution specimen configure failed")
endif()

execute_process(
    COMMAND "${CMAKE_COMMAND}" --build "${BRIDGE_BINARY_DIR}"
    RESULT_VARIABLE _bridge_build_result
)
if (NOT "${_bridge_build_result}" STREQUAL "0")
    message(FATAL_ERROR "Bridge execution specimen build failed")
endif()

execute_process(
    COMMAND "${CMAKE_CTEST_COMMAND}" --test-dir "${BRIDGE_BINARY_DIR}" --verbose
    RESULT_VARIABLE _bridge_test_result
    OUTPUT_VARIABLE _bridge_test_output
    ERROR_VARIABLE _bridge_test_error
)
message("${_bridge_test_output}")
if (NOT "${_bridge_test_error}" STREQUAL "")
    message("${_bridge_test_error}")
endif()
if (NOT "${_bridge_test_result}" STREQUAL "0")
    message(FATAL_ERROR "Bridge execution specimen tests failed")
endif()

string(FIND "${_bridge_test_output}" "bridge test emulator" _bridge_emulator_position)
if (BRIDGE_EXPECT_TEST_EMULATOR)
    if (_bridge_emulator_position LESS 0)
        message(FATAL_ERROR "Bridge execution specimen did not use the configured emulator")
    endif()
else()
    if (NOT _bridge_emulator_position LESS 0)
        message(FATAL_ERROR "Bridge native execution unexpectedly used the test emulator")
    endif()
endif()
