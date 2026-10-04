# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

if (NOT DEFINED BRIDGE_RUNNER)
    message(FATAL_ERROR "BRIDGE_RUNNER is required")
endif()
if (NOT DEFINED BRIDGE_RUNNER_TEST_BINARY_DIR)
    message(FATAL_ERROR "BRIDGE_RUNNER_TEST_BINARY_DIR is required")
endif()
if (NOT DEFINED BRIDGE_RUNNER_TEST_MODE)
    message(FATAL_ERROR "BRIDGE_RUNNER_TEST_MODE is required")
endif()

file(REMOVE_RECURSE "${BRIDGE_RUNNER_TEST_BINARY_DIR}")
file(MAKE_DIRECTORY "${BRIDGE_RUNNER_TEST_BINARY_DIR}/runtime")

set(_fake_wine "${BRIDGE_RUNNER_TEST_BINARY_DIR}/wine")
set(_fake_winepath "${BRIDGE_RUNNER_TEST_BINARY_DIR}/winepath")
set(_target "${BRIDGE_RUNNER_TEST_BINARY_DIR}/target")
set(_log "${BRIDGE_RUNNER_TEST_BINARY_DIR}/wine.log")

file(WRITE "${_fake_wine}" [=[#!/bin/sh
set -eu

if [ "$#" -ge 3 ] && [ "$1" = "cmd" ] && [ "$2" = "/c" ]; then
    case $3 in
        ping*)
            printf '%s\n' anchor >>"$BRIDGE_FAKE_WINE_LOG"
            sleep 3
            exit 0
            ;;
        exit)
            printf '%s\n' ready >>"$BRIDGE_FAKE_WINE_LOG"
            exit 0
            ;;
    esac
fi

exec "$@"
]=])
file(WRITE "${_fake_winepath}" [=[#!/bin/sh
set -eu

if [ "$#" -ne 2 ] || [ "$1" != "-w" ]; then
    exit 2
fi
printf '%s\n' 'Z:\bridge-runtime'
]=])
file(WRITE "${_target}" [=[#!/bin/sh
set -eu

case $1 in
    output)
        printf 'stdout-marker:%s\n' "$WINEPATH"
        printf '%s\n' stderr-marker >&2
        ;;
    exit)
        exit "$2"
        ;;
esac
]=])
file(
    CHMOD "${_fake_wine}" "${_fake_winepath}" "${_target}"
    PERMISSIONS
        OWNER_READ OWNER_WRITE OWNER_EXECUTE
        GROUP_READ GROUP_EXECUTE
        WORLD_READ WORLD_EXECUTE
)

set(_runner_command
    "${CMAKE_COMMAND}" -E env
    "BRIDGE_FAKE_WINE_LOG=${_log}"
    "WINEPREFIX=${BRIDGE_RUNNER_TEST_BINARY_DIR}/prefix"
    "XDG_RUNTIME_DIR=${BRIDGE_RUNNER_TEST_BINARY_DIR}/state"
    "WINEPATH=C:\\existing"
    "${BRIDGE_RUNNER}"
    "${_fake_wine}"
    "${_fake_winepath}"
    "${BRIDGE_RUNNER_TEST_BINARY_DIR}/runtime"
    "${_target}"
)

if ("${BRIDGE_RUNNER_TEST_MODE}" STREQUAL "output")
    execute_process(
        COMMAND ${_runner_command} output
        RESULT_VARIABLE _result
        OUTPUT_VARIABLE _stdout
        ERROR_VARIABLE _stderr
    )
    if (NOT "${_result}" STREQUAL "0")
        message(FATAL_ERROR "Bridge Win32 runner output probe failed with status ${_result}")
    endif()
    if (NOT "${_stdout}" STREQUAL "stdout-marker:Z:\\bridge-runtime;C:\\existing\n")
        message(FATAL_ERROR "Bridge Win32 runner changed stdout or WINEPATH: ${_stdout}")
    endif()
    if (NOT "${_stderr}" STREQUAL "stderr-marker\n")
        message(FATAL_ERROR "Bridge Win32 runner changed stderr: ${_stderr}")
    endif()
elseif("${BRIDGE_RUNNER_TEST_MODE}" STREQUAL "exit")
    execute_process(
        COMMAND ${_runner_command} exit 17
        RESULT_VARIABLE _result
    )
    if (NOT "${_result}" STREQUAL "17")
        message(FATAL_ERROR "Bridge Win32 runner changed target exit status: ${_result}")
    endif()
elseif("${BRIDGE_RUNNER_TEST_MODE}" STREQUAL "anchor")
    execute_process(
        COMMAND ${_runner_command} output
        RESULT_VARIABLE _first_result
        OUTPUT_QUIET
        ERROR_QUIET
    )
    execute_process(
        COMMAND ${_runner_command} output
        RESULT_VARIABLE _second_result
        OUTPUT_QUIET
        ERROR_QUIET
    )
    if (NOT "${_first_result}" STREQUAL "0" OR NOT "${_second_result}" STREQUAL "0")
        message(FATAL_ERROR "Bridge Win32 runner anchor probe could not execute the target")
    endif()

    file(STRINGS "${_log}" _log_lines REGEX "^anchor$")
    list(LENGTH _log_lines _anchor_count)
    if (NOT _anchor_count EQUAL 1)
        message(FATAL_ERROR "Bridge Win32 runner started ${_anchor_count} anchors; expected one")
    endif()
else()
    message(FATAL_ERROR "Unknown Bridge Win32 runner test mode: ${BRIDGE_RUNNER_TEST_MODE}")
endif()
