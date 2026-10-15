# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

# Configures a fixture project that must fail, and checks the failure's message.
# CMake rewraps long messages, so whitespace is compared loosely. The parent's
# build program is passed on, because CTest's environment may not find it.

foreach(_required IN ITEMS
    BRIDGE_SOURCE_DIR BRIDGE_FIXTURE BRIDGE_TEST_BINARY_DIR BRIDGE_GENERATOR BRIDGE_MAKE_PROGRAM BRIDGE_EXPECTED_ERROR
)
    if(NOT DEFINED ${_required} OR "${${_required}}" STREQUAL "")
        message(FATAL_ERROR "Bridge configure-failure test requires ${_required}")
    endif()
endforeach()

set(_command
    "${CMAKE_COMMAND}"
    -S "${BRIDGE_FIXTURE}"
    -B "${BRIDGE_TEST_BINARY_DIR}"
    -G "${BRIDGE_GENERATOR}"
    "-DCMAKE_MAKE_PROGRAM=${BRIDGE_MAKE_PROGRAM}"
    "-DBRIDGE_SOURCE_DIR=${BRIDGE_SOURCE_DIR}"
)
if(DEFINED BRIDGE_TOOLCHAIN_FILE AND NOT "${BRIDGE_TOOLCHAIN_FILE}" STREQUAL "")
    list(APPEND _command "--toolchain=${BRIDGE_TOOLCHAIN_FILE}")
endif()
if(DEFINED BRIDGE_CXX_COMPILER AND NOT "${BRIDGE_CXX_COMPILER}" STREQUAL "")
    list(APPEND _command "-DCMAKE_CXX_COMPILER=${BRIDGE_CXX_COMPILER}")
endif()

file(REMOVE_RECURSE "${BRIDGE_TEST_BINARY_DIR}")
execute_process(COMMAND ${_command} RESULT_VARIABLE _result OUTPUT_VARIABLE _stdout ERROR_VARIABLE _stderr)
if(_result EQUAL 0)
    message(FATAL_ERROR "Fixture ${BRIDGE_FIXTURE} configured, but it must fail:\n${_stdout}\n${_stderr}")
endif()

string(REGEX REPLACE "[ \t\r\n]+" " " _actual "${_stderr}")
string(REGEX REPLACE "[ \t\r\n]+" " " _expected "${BRIDGE_EXPECTED_ERROR}")
string(FIND "${_actual}" "${_expected}" _position)
if(_position LESS 0)
    message(
        FATAL_ERROR
        "Fixture ${BRIDGE_FIXTURE} failed for the wrong reason.\n"
        "Expected: ${BRIDGE_EXPECTED_ERROR}\nActual:\n${_stderr}"
    )
endif()
