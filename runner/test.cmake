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
            printf 'anchor-display:%s\n' "${DISPLAY-unset}" >>"$BRIDGE_FAKE_WINE_LOG"
            printf '%s\n' anchor >>"$BRIDGE_FAKE_WINE_LOG"
            sleep 3
            exit 0
            ;;
        exit)
            printf 'ready-display:%s\n' "${DISPLAY-unset}" >>"$BRIDGE_FAKE_WINE_LOG"
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
    display)
        printf 'display:%s\n' "${DISPLAY-unset}"
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

set(_display ":8")
set(_wayland_display "")
if(BRIDGE_RUNNER_TEST_MODE MATCHES "^wayland")
    if(NOT DEFINED BRIDGE_RUNNER_TEST_SOCKET_FIXTURE)
        message(FATAL_ERROR "BRIDGE_RUNNER_TEST_SOCKET_FIXTURE is required for Wayland tests")
    endif()
    set(_wayland_display "bridge-wayland-test")
    set(_socket_path "${BRIDGE_RUNNER_TEST_BINARY_DIR}/state/${_wayland_display}")
    file(MAKE_DIRECTORY "${BRIDGE_RUNNER_TEST_BINARY_DIR}/state")

    if(BRIDGE_RUNNER_TEST_MODE STREQUAL "wayland" OR
        BRIDGE_RUNNER_TEST_MODE STREQUAL "wayland-absolute" OR
        BRIDGE_RUNNER_TEST_MODE STREQUAL "wayland-native-only")
        execute_process(
            COMMAND "${BRIDGE_RUNNER_TEST_SOCKET_FIXTURE}" "${_socket_path}"
            RESULT_VARIABLE _socket_result
        )
        if(NOT "${_socket_result}" STREQUAL "0")
            message(FATAL_ERROR "Could not create the test Wayland socket: ${_socket_result}")
        endif()
        if(BRIDGE_RUNNER_TEST_MODE STREQUAL "wayland-absolute")
            set(_wayland_display "${_socket_path}")
        endif()
    else()
        file(WRITE "${_socket_path}" "not a socket")
        if(BRIDGE_RUNNER_TEST_MODE STREQUAL "wayland-unavailable-no-x11")
            set(_display "")
        endif()
    endif()
endif()
if(BRIDGE_RUNNER_TEST_MODE STREQUAL "wayland-native-only")
    set(_display "")
endif()
set(_runtime_dir "${BRIDGE_RUNNER_TEST_BINARY_DIR}/state")
if(BRIDGE_RUNNER_TEST_MODE STREQUAL "wayland-missing-runtime")
    set(_runtime_dir "")
endif()

set(_runner_command
    "${CMAKE_COMMAND}" -E env
    "DISPLAY=${_display}"
    "WAYLAND_DISPLAY=${_wayland_display}"
    "BRIDGE_FAKE_WINE_LOG=${_log}"
    "WINEPREFIX=${BRIDGE_RUNNER_TEST_BINARY_DIR}/prefix"
    "XDG_RUNTIME_DIR=${_runtime_dir}"
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
elseif(BRIDGE_RUNNER_TEST_MODE STREQUAL "wayland" OR
    BRIDGE_RUNNER_TEST_MODE STREQUAL "wayland-absolute" OR
    BRIDGE_RUNNER_TEST_MODE STREQUAL "wayland-native-only" OR
    BRIDGE_RUNNER_TEST_MODE STREQUAL "wayland-unavailable" OR
    BRIDGE_RUNNER_TEST_MODE STREQUAL "wayland-missing-runtime")
    execute_process(
        COMMAND ${_runner_command} display
        RESULT_VARIABLE _result
        OUTPUT_VARIABLE _stdout
        ERROR_VARIABLE _stderr
    )
    if(NOT "${_result}" STREQUAL "0")
        message(FATAL_ERROR "Bridge Win32 display probe failed: ${_result}\n${_stderr}")
    endif()
    if(BRIDGE_RUNNER_TEST_MODE STREQUAL "wayland-unavailable" OR
        BRIDGE_RUNNER_TEST_MODE STREQUAL "wayland-missing-runtime")
        if(NOT "${_stdout}" STREQUAL "display::8\n" OR
            NOT "${_stderr}" MATCHES "retaining DISPLAY for Wine X11")
            message(FATAL_ERROR "Bridge should retain X11 when Wayland is unavailable: ${_stdout} ${_stderr}")
        endif()
    else()
        if(NOT "${_stdout}" STREQUAL "display:unset\n" OR
            NOT "${_stderr}" MATCHES "using Wine Wayland display")
            message(FATAL_ERROR "Bridge did not select Wayland: ${_stdout} ${_stderr}")
        endif()

        file(STRINGS "${_log}" _anchor_displays REGEX "^anchor-display:")
        file(STRINGS "${_log}" _ready_displays REGEX "^ready-display:")
        if(NOT "${_anchor_displays}" STREQUAL "anchor-display:unset" OR
            NOT "${_ready_displays}" STREQUAL "ready-display:unset")
            message(FATAL_ERROR "Bridge did not apply Wayland to Wine startup: ${_anchor_displays};${_ready_displays}")
        endif()
    endif()
elseif(BRIDGE_RUNNER_TEST_MODE STREQUAL "wayland-unavailable-no-x11")
    execute_process(
        COMMAND ${_runner_command} display
        RESULT_VARIABLE _result
        ERROR_VARIABLE _stderr
    )
    if(NOT "${_result}" STREQUAL "1" OR
        NOT "${_stderr}" MATCHES "DISPLAY is also unset")
        message(FATAL_ERROR "Bridge did not report unusable display environment: ${_result} ${_stderr}")
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
