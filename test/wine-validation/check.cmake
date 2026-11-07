# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

cmake_minimum_required(VERSION 3.31.6)
foreach(_required IN ITEMS BRIDGE_WINE_VALIDATION_SCRIPT BRIDGE_WINE_VALIDATION_FIXTURE BRIDGE_WINE_VALIDATION_DIRECTORY BRIDGE_WINE_VALIDATION_CASE)
    if(NOT DEFINED ${_required} OR "${${_required}}" STREQUAL "")
        message(FATAL_ERROR "${_required} is required")
    endif()
endforeach()

set(_root "${BRIDGE_WINE_VALIDATION_DIRECTORY}/${BRIDGE_WINE_VALIDATION_CASE}")
file(REMOVE_RECURSE "${_root}")
file(MAKE_DIRECTORY "${_root}/bin" "${_root}/state")
set(_socket "${_root}/state/bridge-wayland-test")
execute_process(COMMAND "${BRIDGE_WINE_VALIDATION_FIXTURE}" "${_socket}" RESULT_VARIABLE _socket_result)
if(NOT "${_socket_result}" STREQUAL "0")
    message(FATAL_ERROR "Could not create the test Wayland socket: ${_socket_result}")
endif()

file(WRITE "${_root}/bin/wine" [=[#!/usr/bin/env bash
set -euo pipefail
printf 'wine %s %s\n' "$*" "$WINEPREFIX" >>"$BRIDGE_MOCK_LOG"
[[ -z "${DISPLAY:-}" ]] || { printf '%s\n' 'DISPLAY must be unset' >&2; exit 13; }
case "$*" in
    'reg add '* ) exit 0 ;;
    'reg query '* )
        if [[ "${BRIDGE_MOCK_INVALID_REGISTRY:-}" == 1 ]]; then
            printf '    Graphics    REG_SZ    x11\n'
        else
            printf '    Graphics    REG_SZ    wayland\n'
        fi
        ;;
    *) exit 14 ;;
esac
]=])
file(WRITE "${_root}/bin/wineboot" [=[#!/usr/bin/env bash
set -euo pipefail
[[ "$1" == --init ]] || exit 15
printf 'wineboot %s\n' "$WINEPREFIX" >>"$BRIDGE_MOCK_LOG"
]=])
file(WRITE "${_root}/bin/wineserver" [=[#!/usr/bin/env bash
set -euo pipefail
printf 'wineserver %s %s\n' "$1" "$WINEPREFIX" >>"$BRIDGE_MOCK_LOG"
]=])
file(WRITE "${_root}/bin/scenario" [=[#!/usr/bin/env bash
set -euo pipefail
printf 'scenario %s\n' "$WINEPREFIX" >>"$BRIDGE_MOCK_LOG"
[[ "$WINEPREFIX" == "$BRIDGE_EXPECT_PREFIX_ROOT"/prefixes/session-* ]] || exit 16
[[ -z "${DISPLAY:-}" ]] || exit 17
if [[ "${BRIDGE_MOCK_FAIL_SCENARIO:-}" == 1 ]]; then exit 23; fi
]=])
file(CHMOD "${_root}/bin/wine" "${_root}/bin/wineboot" "${_root}/bin/wineserver" "${_root}/bin/scenario"
    PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)

set(_args "--output" "${_root}/output")
if(BRIDGE_WINE_VALIDATION_CASE STREQUAL "keep")
    list(APPEND _args "--keep-prefix")
endif()
list(APPEND _args "--" "${_root}/bin/scenario")
set(_display "bridge-wayland-test")
if(BRIDGE_WINE_VALIDATION_CASE STREQUAL "no-wayland")
    set(_display "")
endif()
set(_scenario_fails 0)
if(BRIDGE_WINE_VALIDATION_CASE STREQUAL "failure")
    set(_scenario_fails 1)
endif()
set(_invalid_registry 0)
if(BRIDGE_WINE_VALIDATION_CASE STREQUAL "wrong-driver")
    set(_invalid_registry 1)
endif()
execute_process(
    COMMAND "${CMAKE_COMMAND}" -E env
        "PATH=${_root}/bin:$ENV{PATH}"
        "XDG_RUNTIME_DIR=${_root}/state"
        "WAYLAND_DISPLAY=${_display}"
        "DISPLAY=:5"
        "BRIDGE_MOCK_LOG=${_root}/commands.log"
        "BRIDGE_EXPECT_PREFIX_ROOT=${_root}/output"
        "BRIDGE_MOCK_FAIL_SCENARIO=${_scenario_fails}"
        "BRIDGE_MOCK_INVALID_REGISTRY=${_invalid_registry}"
        "${BRIDGE_WINE_VALIDATION_SCRIPT}" ${_args}
    RESULT_VARIABLE _result OUTPUT_VARIABLE _stdout ERROR_VARIABLE _stderr
)

file(GLOB _prefixes LIST_DIRECTORIES TRUE "${_root}/output/prefixes/session-*")
file(GLOB _logs "${_root}/output/logs/*")
file(GLOB _results "${_root}/output/results/*")
if(BRIDGE_WINE_VALIDATION_CASE STREQUAL "no-wayland")
    if("${_result}" STREQUAL "0" OR NOT _stderr MATCHES "native Wayland is required" OR _logs OR _prefixes OR _results)
        message(FATAL_ERROR "Missing Wayland must fail before creating a prefix: ${_result}\n${_stderr}")
    endif()
    return()
endif()

list(LENGTH _logs _log_count)
list(LENGTH _results _result_count)
list(LENGTH _prefixes _prefix_count)
if(NOT _log_count EQUAL 1 OR NOT _result_count EQUAL 1)
    message(FATAL_ERROR "Expected one log and result: logs=${_logs} results=${_results}")
endif()
list(GET _results 0 _result_file)
file(READ "${_result_file}" _report)
file(READ "${_root}/commands.log" _commands)

if(BRIDGE_WINE_VALIDATION_CASE STREQUAL "success")
    if(NOT "${_result}" STREQUAL "0" OR _prefix_count OR NOT _report MATCHES "result=passed")
        message(FATAL_ERROR "Successful session did not clean its prefix: ${_result}\n${_report}\n${_stderr}")
    endif()
elseif(BRIDGE_WINE_VALIDATION_CASE STREQUAL "keep")
    if(NOT "${_result}" STREQUAL "0" OR NOT _prefix_count EQUAL 1 OR NOT _report MATCHES "result=passed")
        message(FATAL_ERROR "Keep-prefix session did not retain its prefix: ${_result}\n${_report}\n${_stderr}")
    endif()
elseif(BRIDGE_WINE_VALIDATION_CASE STREQUAL "failure")
    if(NOT "${_result}" STREQUAL "23" OR NOT _prefix_count EQUAL 1 OR NOT _report MATCHES "result=failed")
        message(FATAL_ERROR "Failed session did not retain its prefix and status: ${_result}\n${_report}\n${_stderr}")
    endif()
elseif(BRIDGE_WINE_VALIDATION_CASE STREQUAL "wrong-driver")
    if("${_result}" STREQUAL "0" OR NOT _prefix_count EQUAL 1 OR NOT _report MATCHES "result=failed" OR _commands MATCHES "scenario ")
        message(FATAL_ERROR "Invalid registry did not fail before executing tests: ${_result}\n${_report}\n${_stderr}")
    endif()
else()
    message(FATAL_ERROR "Unknown Wine session case: ${BRIDGE_WINE_VALIDATION_CASE}")
endif()
if(NOT _commands MATCHES "wineboot " OR NOT _commands MATCHES "wineserver -k " OR NOT _commands MATCHES "wineserver -w " OR
   NOT _commands MATCHES "reg add " OR NOT _commands MATCHES "reg query ")
    message(FATAL_ERROR "Wine session did not execute all lifecycle operations:\n${_commands}")
endif()
if(NOT BRIDGE_WINE_VALIDATION_CASE STREQUAL "wrong-driver" AND NOT _commands MATCHES "scenario ")
    message(FATAL_ERROR "Wine session did not execute its test command: ${_commands}")
endif()
