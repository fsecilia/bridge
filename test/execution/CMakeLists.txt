# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    cmake_minimum_required(VERSION 3.31.6)
    project(BridgeExecutionSpecimen LANGUAGES CXX)
    include(CTest)
endif()

foreach(_required IN ITEMS
    BRIDGE_EXECUTION_PROFILE
    BRIDGE_EXPECT_TEST_EMULATOR
    BRIDGE_REMOTE_EXECUTION
)
    if(NOT DEFINED ${_required})
        message(FATAL_ERROR "${_required} is required")
    endif()
endforeach()

try_run(
    _bridge_try_run_result
    _bridge_try_compile_result
    SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/try_run.cpp"
    RUN_OUTPUT_STDOUT_VARIABLE _bridge_try_run_stdout
    RUN_OUTPUT_STDERR_VARIABLE _bridge_try_run_stderr
)
if(NOT _bridge_try_compile_result)
    message(FATAL_ERROR "Bridge execution try_run probe failed to compile")
endif()
if(NOT "${_bridge_try_run_result}" STREQUAL "0")
    message(
        FATAL_ERROR
        "Bridge execution try_run probe failed with status ${_bridge_try_run_result}\n"
        "stdout:\n${_bridge_try_run_stdout}\n"
        "stderr:\n${_bridge_try_run_stderr}"
    )
endif()

string(FIND "${_bridge_try_run_stdout}" "bridge test emulator marker" _bridge_marker_position)
if(BRIDGE_EXPECT_TEST_EMULATOR)
    if(_bridge_marker_position LESS 0)
        message(FATAL_ERROR "Bridge try_run probe did not use the configured test emulator")
    endif()
else()
    if(NOT _bridge_marker_position LESS 0)
        message(FATAL_ERROR "Bridge execution unexpectedly used the test emulator")
    endif()
endif()

add_executable(bridge_execution_specimen execution.cpp)
target_compile_features(bridge_execution_specimen PRIVATE cxx_std_26)

function(_bridge_add_execution_case NAME)
    add_test(
        NAME "bridge.integration.execution.${BRIDGE_EXECUTION_PROFILE}.${NAME}"
        COMMAND bridge_execution_specimen ${ARGN}
    )

    set(_bridge_labels integration execution "${BRIDGE_EXECUTION_PROFILE}")
    if(BRIDGE_REMOTE_EXECUTION)
        list(APPEND _bridge_labels android)
    endif()
    set_tests_properties(
        "bridge.integration.execution.${BRIDGE_EXECUTION_PROFILE}.${NAME}"
        PROPERTIES
            LABELS "${_bridge_labels}"
            TIMEOUT 120
    )
    if(DEFINED BRIDGE_EXECUTION_ANDROID_SERIAL AND NOT "${BRIDGE_EXECUTION_ANDROID_SERIAL}" STREQUAL "")
        set_tests_properties(
            "bridge.integration.execution.${BRIDGE_EXECUTION_PROFILE}.${NAME}"
            PROPERTIES ENVIRONMENT "BRIDGE_ANDROID_SERIAL=${BRIDGE_EXECUTION_ANDROID_SERIAL}"
        )
    endif()
endfunction()

_bridge_add_execution_case(arguments arguments "two words")

if(NOT BRIDGE_REMOTE_EXECUTION)
    _bridge_add_execution_case(environment environment)
    set_tests_properties(
        "bridge.integration.execution.${BRIDGE_EXECUTION_PROFILE}.environment"
        PROPERTIES ENVIRONMENT "BRIDGE_SPECIMEN_VALUE=from-ctest"
    )

    set(_bridge_working_directory "${CMAKE_CURRENT_BINARY_DIR}/working-directory")
    file(MAKE_DIRECTORY "${_bridge_working_directory}")
    file(WRITE "${_bridge_working_directory}/bridge-working-directory-marker" "")
    _bridge_add_execution_case(
        working-directory
        working-directory
        bridge-working-directory-marker
    )
    set_tests_properties(
        "bridge.integration.execution.${BRIDGE_EXECUTION_PROFILE}.working-directory"
        PROPERTIES WORKING_DIRECTORY "${_bridge_working_directory}"
    )
endif()

_bridge_add_execution_case(output output)
set_tests_properties(
    "bridge.integration.execution.${BRIDGE_EXECUTION_PROFILE}.output"
    PROPERTIES PASS_REGULAR_EXPRESSION "bridge specimen output"
)

_bridge_add_execution_case(failure failure)
set_tests_properties(
    "bridge.integration.execution.${BRIDGE_EXECUTION_PROFILE}.failure"
    PROPERTIES WILL_FAIL TRUE
)
