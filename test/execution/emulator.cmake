# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

set(_bridge_separator_index -1)
math(EXPR _bridge_last_argument "${CMAKE_ARGC} - 1")
foreach(_bridge_index RANGE 0 "${_bridge_last_argument}")
    if ("${CMAKE_ARGV${_bridge_index}}" STREQUAL "--")
        set(_bridge_separator_index "${_bridge_index}")
        break()
    endif()
endforeach()

if (_bridge_separator_index LESS 0)
    message(FATAL_ERROR "Bridge test emulator did not receive an executable separator")
endif()

math(EXPR _bridge_first_command_argument "${_bridge_separator_index} + 1")
if (_bridge_first_command_argument GREATER _bridge_last_argument)
    message(FATAL_ERROR "Bridge test emulator did not receive an executable")
endif()

set(_bridge_command)
foreach(_bridge_index RANGE "${_bridge_first_command_argument}" "${_bridge_last_argument}")
    list(APPEND _bridge_command "${CMAKE_ARGV${_bridge_index}}")
endforeach()

message(STATUS "bridge test emulator")
execute_process(
    COMMAND "${CMAKE_COMMAND}" -E env BRIDGE_TEST_EMULATOR=1 ${_bridge_command}
    RESULT_VARIABLE _bridge_result
)
if (NOT "${_bridge_result}" STREQUAL "0")
    message(FATAL_ERROR "Bridge test emulator target failed with status ${_bridge_result}")
endif()
