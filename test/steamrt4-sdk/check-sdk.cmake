# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

if(NOT BRIDGE_STEAMRT4_MODULE OR NOT BRIDGE_TEST_BINARY_DIR OR NOT BRIDGE_STEAMRT4_CASE)
    message(FATAL_ERROR "Steam SDK identity test requires the module, test directory, and case")
endif()

include("${BRIDGE_STEAMRT4_MODULE}")
if(BRIDGE_STEAMRT4_PROBE)
    _bridge_require_steamrt4_sdk("${BRIDGE_STEAMRT4_OS_RELEASE}")
    return()
endif()

file(MAKE_DIRECTORY "${BRIDGE_TEST_BINARY_DIR}")
set(_release "${BRIDGE_TEST_BINARY_DIR}/os-release")
if(BRIDGE_STEAMRT4_CASE STREQUAL "sdk")
    file(WRITE "${_release}" "ID=steamrt\nVERSION_ID=\"4\"\nVARIANT=SDK\nBUILD_ID=\"4.0.20261007.263973\"\n")
elseif(BRIDGE_STEAMRT4_CASE STREQUAL "host")
    file(WRITE "${_release}" "ID=arch\nVERSION_ID=rolling\n")
elseif(BRIDGE_STEAMRT4_CASE STREQUAL "runtime")
    file(WRITE "${_release}" "ID=steamrt\nVERSION_ID=4\nVARIANT=Platform\n")
elseif(BRIDGE_STEAMRT4_CASE STREQUAL "wrong-version")
    file(WRITE "${_release}" "ID=steamrt\nVERSION_ID=3\nVARIANT=SDK\n")
elseif(BRIDGE_STEAMRT4_CASE STREQUAL "missing-variant")
    file(WRITE "${_release}" "ID=steamrt\nVERSION_ID=4\n")
elseif(BRIDGE_STEAMRT4_CASE STREQUAL "missing-file")
    file(REMOVE "${_release}")
else()
    message(FATAL_ERROR "Unknown Steam SDK identity test case: ${BRIDGE_STEAMRT4_CASE}")
endif()
execute_process(
    COMMAND "${CMAKE_COMMAND}"
        "-DBRIDGE_STEAMRT4_MODULE=${BRIDGE_STEAMRT4_MODULE}"
        "-DBRIDGE_STEAMRT4_PROBE=ON"
        "-DBRIDGE_STEAMRT4_OS_RELEASE=${_release}"
        "-DBRIDGE_TEST_BINARY_DIR=${BRIDGE_TEST_BINARY_DIR}"
        "-DBRIDGE_STEAMRT4_CASE=${BRIDGE_STEAMRT4_CASE}"
        -P "${CMAKE_CURRENT_LIST_FILE}"
    RESULT_VARIABLE _result ERROR_VARIABLE _error
)
if(BRIDGE_STEAMRT4_CASE STREQUAL "sdk")
    if(NOT "${_result}" STREQUAL "0")
        message(FATAL_ERROR "Valid SDK metadata was rejected: ${_result}\n${_error}")
    endif()
elseif("${_result}" STREQUAL "0" OR NOT "${_error}" MATCHES "Steam Linux Runtime 4 SDK")
    message(FATAL_ERROR "Invalid SDK metadata was accepted or failed unclearly: ${_result}\n${_error}")
endif()
