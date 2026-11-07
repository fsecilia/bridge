# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

cmake_minimum_required(VERSION 3.31.6)
project(BridgeDistributionFixture LANGUAGES NONE)
include("${BRIDGE_SOURCE_DIR}/cmake/BridgeDistribution.cmake")

if(FIXTURE_ROLE STREQUAL "producer")
    file(WRITE "${PROJECT_BINARY_DIR}/payload.txt" "${FIXTURE_PAYLOAD}")
    add_custom_target(fixture_package
        COMMAND "${CMAKE_COMMAND}" -E make_directory "${PROJECT_BINARY_DIR}/dist"
        COMMAND "${CMAKE_COMMAND}" -E copy_if_different
            "${PROJECT_BINARY_DIR}/payload.txt" "${PROJECT_BINARY_DIR}/dist/example.zip"
        VERBATIM
    )
    bridge_add_distribution_target(
        TARGET fixture_distribution
        OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/dist"
        PLATFORM windows-x64
        VERSION 0.1.0
        ARTIFACTS "windows-zip|example.zip"
        DEPENDS fixture_package
    )
elseif(FIXTURE_ROLE STREQUAL "coordinator")
    if(NOT DEFINED FIXTURE_EXPECTED_SOURCE)
        set(FIXTURE_EXPECTED_SOURCE "${PROJECT_SOURCE_DIR}")
    endif()
    set(_validation)
    if(FIXTURE_VALIDATOR)
        list(APPEND _validation VALIDATOR "${FIXTURE_VALIDATOR}"
            VALIDATION_ARGS --mode "${FIXTURE_VALIDATOR_MODE}")
    endif()
    bridge_add_distribution_collection(
        TARGET fixture_distribution
        OUTPUT_DIRECTORY "${FIXTURE_OUTPUT_DIR}"
        EXPECTED_SOURCE "${FIXTURE_EXPECTED_SOURCE}"
        BUILD_TREES "${FIXTURE_PRODUCER_DIR}|fixture_distribution"
        ${_validation}
    )
else()
    message(FATAL_ERROR "Unknown fixture role '${FIXTURE_ROLE}'")
endif()
