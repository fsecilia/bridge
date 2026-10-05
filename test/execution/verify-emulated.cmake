# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

if(NOT DEFINED BRIDGE_EMULATED_BINARY_DIR OR "${BRIDGE_EMULATED_BINARY_DIR}" STREQUAL "")
    message(FATAL_ERROR "BRIDGE_EMULATED_BINARY_DIR is required")
endif()

set(
    _bridge_test_command
    "${CMAKE_CTEST_COMMAND}"
    --test-dir "${BRIDGE_EMULATED_BINARY_DIR}"
    --verbose
)
if(DEFINED BRIDGE_EMULATED_CONFIG AND NOT "${BRIDGE_EMULATED_CONFIG}" STREQUAL "")
    list(APPEND _bridge_test_command -C "${BRIDGE_EMULATED_CONFIG}")
endif()

execute_process(
    COMMAND ${_bridge_test_command}
    RESULT_VARIABLE _bridge_test_result
    OUTPUT_VARIABLE _bridge_test_output
    ERROR_VARIABLE _bridge_test_error
)
message("${_bridge_test_output}")
if(NOT "${_bridge_test_error}" STREQUAL "")
    message("${_bridge_test_error}")
endif()
if(NOT "${_bridge_test_result}" STREQUAL "0")
    message(FATAL_ERROR "Bridge emulated execution specimen tests failed")
endif()

string(FIND "${_bridge_test_output}" "bridge test emulator" _bridge_emulator_position)
if(_bridge_emulator_position LESS 0)
    message(FATAL_ERROR "Bridge emulated execution specimen did not use the configured emulator")
endif()
