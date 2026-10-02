# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

cmake_minimum_required(VERSION 3.31.6)

project(BridgeExecutionSpecimen LANGUAGES CXX)

include(CTest)

add_executable(bridge_execution_specimen execution.cpp)
target_compile_features(bridge_execution_specimen PRIVATE cxx_std_26)

add_test(
    NAME bridge.specimen.arguments
    COMMAND bridge_execution_specimen arguments "two words"
)

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
add_test(
    NAME bridge.specimen.working-directory
    COMMAND bridge_execution_specimen working-directory "${_bridge_working_directory}"
)
set_tests_properties(
    bridge.specimen.working-directory
    PROPERTIES WORKING_DIRECTORY "${_bridge_working_directory}"
)

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
