# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

if (NOT DEFINED BRIDGE_ANDROID_RUNNER)
    message(FATAL_ERROR "BRIDGE_ANDROID_RUNNER is required")
endif()
if (NOT DEFINED BRIDGE_ANDROID_RUNNER_TEST_BINARY_DIR)
    message(FATAL_ERROR "BRIDGE_ANDROID_RUNNER_TEST_BINARY_DIR is required")
endif()
if (NOT DEFINED BRIDGE_ANDROID_RUNNER_TEST_MODE)
    message(FATAL_ERROR "BRIDGE_ANDROID_RUNNER_TEST_MODE is required")
endif()

file(REMOVE_RECURSE "${BRIDGE_ANDROID_RUNNER_TEST_BINARY_DIR}")
file(MAKE_DIRECTORY "${BRIDGE_ANDROID_RUNNER_TEST_BINARY_DIR}")

set(_fake_adb "${BRIDGE_ANDROID_RUNNER_TEST_BINARY_DIR}/adb")
set(_target "${BRIDGE_ANDROID_RUNNER_TEST_BINARY_DIR}/target")
set(_state "${BRIDGE_ANDROID_RUNNER_TEST_BINARY_DIR}/state")
file(MAKE_DIRECTORY "${_state}")

file(WRITE "${_fake_adb}" [=[#!/bin/sh
set -eu

state=$BRIDGE_FAKE_ADB_STATE

if [ "$#" -eq 1 ] && [ "$1" = devices ]; then
    printf '%s\n' 'List of devices attached'
    printf '%s\t%s\n' emulator-5554 device
    if [ "${BRIDGE_FAKE_ADB_MULTIPLE:-0}" = 1 ]; then
        printf '%s\t%s\n' emulator-5556 device
    fi
    exit 0
fi

if [ "$1" != -s ]; then
    exit 2
fi
serial=$2
shift 2

case $1 in
    get-state)
        printf '%s\n' device
        exit 0
        ;;
    push)
        if [ "${BRIDGE_FAKE_ADB_PUSH_FAIL:-0}" = 1 ]; then
            exit 1
        fi
        case $3 in
            */program) cp "$2" "$state/deployed" ;;
            */assets) cp -R "$2" "$state/assets" ;;
            *) cp "$2" "$state/${3##*/}" ;;
        esac
        printf '%s\n' "$serial" >"$state/serial"
        exit 0
        ;;
    shell)
        shift
        if [ "$1" = getprop ]; then
            case $2 in
                ro.product.cpu.abilist) printf '%s\n' x86_64,x86 ;;
                ro.product.cpu.abi) printf '%s\n' x86_64 ;;
                *) exit 2 ;;
            esac
            exit 0
        fi
        if [ "$1" = mkdir ] || [ "$1" = chmod ] || [ "$1" = rm ]; then
            exit 0
        fi
        command=$1
        shift
        for argument in "$@"; do
            command="$command $argument"
        done
        if [ "${BRIDGE_FAKE_ADB_RECORD_COMMAND:-0}" = 1 ]; then
            printf '%s\n' "$command" >"$state/command"
            exit 0
        fi
        case $command in
            "cd "*) command=${command#*' && '} ;;
        esac
        case $command in
            "LD_LIBRARY_PATH="*) command=${command#*' '} ;;
        esac
        eval "set -- $command"
        shift
        shift
        exec /bin/sh "$state/deployed" "$@"
        ;;
esac

exit 2
]=])

file(WRITE "${_target}" [=[#!/bin/sh
set -eu

case $1 in
    arguments)
        [ "$2" = "two words" ]
        [ "$3" = "single'quote" ]
        [ "$4" = '$dollar' ]
        [ "$5" = 'back\slash' ]
        [ "$6" = '' ]
        printf '%s\n' argument-marker
        ;;
    output)
        printf '%s\n' stdout-marker
        printf '%s\n' stderr-marker >&2
        ;;
    exit)
        exit "$2"
        ;;
esac
]=])

file(
    CHMOD "${_fake_adb}" "${_target}"
    PERMISSIONS
        OWNER_READ OWNER_WRITE OWNER_EXECUTE
        GROUP_READ GROUP_EXECUTE
        WORLD_READ WORLD_EXECUTE
)

set(_runner_command
    "${CMAKE_COMMAND}" -E env
    "BRIDGE_FAKE_ADB_STATE=${_state}"
    "${BRIDGE_ANDROID_RUNNER}"
    "${_fake_adb}"
    x86_64
    "${_target}"
)

if ("${BRIDGE_ANDROID_RUNNER_TEST_MODE}" STREQUAL "output")
    execute_process(
        COMMAND ${_runner_command} output
        RESULT_VARIABLE _result
        OUTPUT_VARIABLE _stdout
        ERROR_VARIABLE _stderr
    )
    if (NOT "${_result}" STREQUAL "0")
        message(FATAL_ERROR "Bridge Android runner output probe failed with status ${_result}")
    endif()
    if (NOT "${_stdout}" STREQUAL "stdout-marker\n")
        message(FATAL_ERROR "Bridge Android runner changed stdout: ${_stdout}")
    endif()
    if (NOT "${_stderr}" STREQUAL "stderr-marker\n")
        message(FATAL_ERROR "Bridge Android runner changed stderr: ${_stderr}")
    endif()
elseif("${BRIDGE_ANDROID_RUNNER_TEST_MODE}" STREQUAL "arguments")
    execute_process(
        COMMAND
            ${_runner_command}
            arguments
            "two words"
            "single'quote"
            "$dollar"
            "back\\slash"
            ""
        RESULT_VARIABLE _result
        OUTPUT_VARIABLE _stdout
        ERROR_VARIABLE _stderr
    )
    if (NOT "${_result}" STREQUAL "0" OR NOT "${_stdout}" STREQUAL "argument-marker\n")
        message(FATAL_ERROR "Bridge Android runner changed target arguments")
    endif()
elseif("${BRIDGE_ANDROID_RUNNER_TEST_MODE}" STREQUAL "exit")
    execute_process(
        COMMAND ${_runner_command} exit 17
        RESULT_VARIABLE _result
    )
    if (NOT "${_result}" STREQUAL "17")
        message(FATAL_ERROR "Bridge Android runner changed target exit status: ${_result}")
    endif()
elseif("${BRIDGE_ANDROID_RUNNER_TEST_MODE}" STREQUAL "selection")
    execute_process(
        COMMAND
            "${CMAKE_COMMAND}" -E env
            "BRIDGE_FAKE_ADB_STATE=${_state}"
            BRIDGE_FAKE_ADB_MULTIPLE=1
            "${BRIDGE_ANDROID_RUNNER}"
            "${_fake_adb}"
            x86_64
            "${_target}"
            output
        RESULT_VARIABLE _ambiguous_result
        ERROR_VARIABLE _ambiguous_error
        OUTPUT_QUIET
    )
    if ("${_ambiguous_result}" STREQUAL "0")
        message(FATAL_ERROR "Bridge Android runner accepted multiple compatible devices")
    endif()
    if (NOT _ambiguous_error MATCHES "set BRIDGE_ANDROID_SERIAL")
        message(FATAL_ERROR "Bridge Android runner did not explain ambiguous device selection")
    endif()

    execute_process(
        COMMAND
            "${CMAKE_COMMAND}" -E env
            "BRIDGE_FAKE_ADB_STATE=${_state}"
            BRIDGE_FAKE_ADB_MULTIPLE=1
            BRIDGE_ANDROID_SERIAL=emulator-5556
            "${BRIDGE_ANDROID_RUNNER}"
            "${_fake_adb}"
            x86_64
            "${_target}"
            output
        RESULT_VARIABLE _selected_result
        OUTPUT_QUIET
        ERROR_QUIET
    )
    if (NOT "${_selected_result}" STREQUAL "0")
        message(FATAL_ERROR "Bridge Android runner rejected explicit compatible device selection")
    endif()
elseif("${BRIDGE_ANDROID_RUNNER_TEST_MODE}" STREQUAL "staging")
    set(_library "${BRIDGE_ANDROID_RUNNER_TEST_BINARY_DIR}/libtest.so")
    file(WRITE "${_library}" "library-content")
    set(_assets "${BRIDGE_ANDROID_RUNNER_TEST_BINARY_DIR}/test assets")
    file(MAKE_DIRECTORY "${_assets}/audio" "${_assets}/fonts")
    file(WRITE "${_assets}/audio/sound.wav" "audio-content")
    file(WRITE "${_assets}/fonts/font.arfont" "font-content")

    execute_process(
        COMMAND
            "${CMAKE_COMMAND}" -E env
            "BRIDGE_FAKE_ADB_STATE=${_state}"
            BRIDGE_FAKE_ADB_RECORD_COMMAND=1
            "${BRIDGE_ANDROID_RUNNER}"
            "${_fake_adb}" x86_64
            --library "${_library}"
            --assets "${_assets}"
            -- "${_target}" output
        RESULT_VARIABLE _result
        ERROR_VARIABLE _error
    )
    if(NOT "${_result}" STREQUAL "0")
        message(FATAL_ERROR "Bridge Android staging failed: ${_error}")
    endif()
    file(READ "${_state}/libtest.so" _staged_library)
    file(READ "${_state}/assets/audio/sound.wav" _staged_audio)
    file(READ "${_state}/assets/fonts/font.arfont" _staged_font)
    file(READ "${_state}/command" _remote_command)
    if(NOT _staged_library STREQUAL "library-content" OR NOT _staged_audio STREQUAL "audio-content"
        OR NOT _staged_font STREQUAL "font-content")
        message(FATAL_ERROR "Bridge Android staging corrupted runtime files")
    endif()
    if(NOT _remote_command MATCHES "^cd .*assets.* && LD_LIBRARY_PATH=.* exec .*program.*output")
        message(FATAL_ERROR "Bridge Android staging did not set working directory and library path: ${_remote_command}")
    endif()

    execute_process(
        COMMAND "${CMAKE_COMMAND}" -E env "BRIDGE_FAKE_ADB_STATE=${_state}"
            "${BRIDGE_ANDROID_RUNNER}" "${_fake_adb}" x86_64
            --library "${_library}" --library "${_library}" -- "${_target}"
        RESULT_VARIABLE _duplicate_result
        ERROR_VARIABLE _duplicate_error
        OUTPUT_QUIET
    )
    if("${_duplicate_result}" STREQUAL "0" OR NOT _duplicate_error MATCHES "duplicate Android staged file name")
        message(FATAL_ERROR "Bridge Android runner did not reject colliding deployed file names")
    endif()
    execute_process(
        COMMAND "${CMAKE_COMMAND}" -E env "BRIDGE_FAKE_ADB_STATE=${_state}"
            "${BRIDGE_ANDROID_RUNNER}" "${_fake_adb}" x86_64
            --assets "${_state}/absent" -- "${_target}"
        RESULT_VARIABLE _missing_result
        ERROR_VARIABLE _missing_error
        OUTPUT_QUIET
    )
    if("${_missing_result}" STREQUAL "0" OR NOT _missing_error MATCHES "asset directory does not exist")
        message(FATAL_ERROR "Bridge Android runner did not report missing assets")
    endif()
    execute_process(
        COMMAND
            "${CMAKE_COMMAND}" -E env
            "BRIDGE_FAKE_ADB_STATE=${_state}"
            BRIDGE_FAKE_ADB_PUSH_FAIL=1
            "${BRIDGE_ANDROID_RUNNER}" "${_fake_adb}" x86_64
            --assets "${_assets}" -- "${_target}"
        RESULT_VARIABLE _push_result
        ERROR_VARIABLE _push_error
        OUTPUT_QUIET
    )
    if("${_push_result}" STREQUAL "0" OR NOT _push_error MATCHES "could not deploy target executable")
        message(FATAL_ERROR "Bridge Android runner did not report a failed deployment")
    endif()
else()
    message(FATAL_ERROR "Unknown Bridge Android runner test mode: ${BRIDGE_ANDROID_RUNNER_TEST_MODE}")
endif()
