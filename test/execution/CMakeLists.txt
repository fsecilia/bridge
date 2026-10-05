# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

cmake_minimum_required(VERSION 3.31.6)

project(BridgeExecutionSpecimen LANGUAGES CXX)

include(CTest)

if (NOT DEFINED BRIDGE_EXPECT_TEST_EMULATOR)
    message(FATAL_ERROR "BRIDGE_EXPECT_TEST_EMULATOR is required")
endif()
if (NOT DEFINED BRIDGE_REMOTE_EXECUTION)
    set(BRIDGE_REMOTE_EXECUTION FALSE)
endif()

try_run(
    _bridge_try_run_result
    _bridge_try_compile_result
    SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/try_run.cpp"
    RUN_OUTPUT_STDOUT_VARIABLE _bridge_try_run_stdout
    RUN_OUTPUT_STDERR_VARIABLE _bridge_try_run_stderr
)
if (NOT _bridge_try_compile_result)
    message(FATAL_ERROR "Bridge execution try_run probe failed to compile")
endif()
if (NOT "${_bridge_try_run_result}" STREQUAL "0")
    message(
        FATAL_ERROR
        "Bridge execution try_run probe failed with status ${_bridge_try_run_result}\n"
        "stdout:\n${_bridge_try_run_stdout}\n"
        "stderr:\n${_bridge_try_run_stderr}"
    )
endif()

string(FIND "${_bridge_try_run_stdout}" "bridge test emulator marker" _bridge_marker_position)
if (BRIDGE_EXPECT_TEST_EMULATOR)
    if (_bridge_marker_position LESS 0)
        message(FATAL_ERROR "Bridge try_run probe did not use the configured test emulator")
    endif()
else()
    if (NOT _bridge_marker_position LESS 0)
        message(FATAL_ERROR "Bridge try_run probe unexpectedly used the test emulator")
    endif()
endif()

add_executable(bridge_execution_specimen execution.cpp)
target_compile_features(bridge_execution_specimen PRIVATE cxx_std_26)

add_test(
    NAME bridge.specimen.arguments
    COMMAND bridge_execution_specimen arguments "two words"
)

if (NOT BRIDGE_REMOTE_EXECUTION)
    add_test(
        NAME bridge.specimen.environment
        COMMAND bridge_execution_specimen environment
    )
    set_tests_properties(
        bridge.specimen.environment
        PROPERTIES ENVIRONMENT "BRIDGE_SPECIMEN_VALUE=from-ctest"
    )

    set(_bridge_working_directory "${CMAKE_CURRENT_BINARY_DIR}/working-directory")
    file(MAKE_DIRECTORY "${_bridge_working_directory}")
    file(WRITE "${_bridge_working_directory}/bridge-working-directory-marker" "")
    add_test(
        NAME bridge.specimen.working-directory
        COMMAND bridge_execution_specimen working-directory bridge-working-directory-marker
    )
    set_tests_properties(
        bridge.specimen.working-directory
        PROPERTIES WORKING_DIRECTORY "${_bridge_working_directory}"
    )
endif()

add_test(
    NAME bridge.specimen.output
    COMMAND bridge_execution_specimen output
)
set_tests_properties(
    bridge.specimen.output
    PROPERTIES PASS_REGULAR_EXPRESSION "bridge specimen output"
)

add_test(
    NAME bridge.specimen.failure
    COMMAND bridge_execution_specimen failure
)
set_tests_properties(bridge.specimen.failure PROPERTIES WILL_FAIL TRUE)
