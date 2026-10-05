# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

foreach(_required IN ITEMS
    BRIDGE_ANDROID_APP_RUNNER
    BRIDGE_ANDROID_APP_RUNNER_TEST_BINARY_DIR
    BRIDGE_ANDROID_APP_RUNNER_TEST_MODE
)
    if(NOT DEFINED ${_required})
        message(FATAL_ERROR "${_required} is required")
    endif()
endforeach()

file(REMOVE_RECURSE "${BRIDGE_ANDROID_APP_RUNNER_TEST_BINARY_DIR}")
file(MAKE_DIRECTORY "${BRIDGE_ANDROID_APP_RUNNER_TEST_BINARY_DIR}")

set(_fake_adb "${BRIDGE_ANDROID_APP_RUNNER_TEST_BINARY_DIR}/adb")
set(_apk "${BRIDGE_ANDROID_APP_RUNNER_TEST_BINARY_DIR}/game.apk")
set(_state "${BRIDGE_ANDROID_APP_RUNNER_TEST_BINARY_DIR}/state")
file(MAKE_DIRECTORY "${_state}")
file(WRITE "${_apk}" "apk")

file(WRITE "${_fake_adb}" [=[#!/bin/sh
set -eu

state_dir=$BRIDGE_FAKE_ADB_STATE

if [ "$#" -eq 1 ] && [ "$1" = devices ]; then
    printf '%s\n' 'List of devices attached'
    printf '%s\t%s\n' emulator-5554 device
    if [ "${BRIDGE_FAKE_ADB_MULTIPLE:-0}" = 1 ]; then
        printf '%s\t%s\n' device-7 device
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
    install)
        if [ "${BRIDGE_FAKE_ADB_INSTALL_FAIL:-0}" = 1 ]; then
            exit 9
        fi
        printf '%s\n' "$serial|install|$2|$3" >>"$state_dir/operations"
        printf '%s\n' Success
        exit 0
        ;;
    shell)
        shift
        if [ "$1" = getprop ]; then
            case $2 in
                ro.product.cpu.abilist) printf '%s\n' arm64-v8a,armeabi-v7a ;;
                ro.product.cpu.abi) printf '%s\n' arm64-v8a ;;
                *) exit 2 ;;
            esac
            exit 0
        fi
        if [ "$1" = am ] && [ "$2" = force-stop ]; then
            printf '%s\n' "$serial|force-stop|$3" >>"$state_dir/operations"
            exit 0
        fi
        if [ "$1" = am ] && [ "$2" = start ] && [ "$3" = -n ]; then
            printf '%s\n' "$serial|start|$4" >>"$state_dir/operations"
            printf '%s\n' 'Starting: Intent'
            exit 0
        fi
        ;;
esac

exit 2
]=])

file(
    CHMOD "${_fake_adb}"
    PERMISSIONS
        OWNER_READ OWNER_WRITE OWNER_EXECUTE
        GROUP_READ GROUP_EXECUTE
        WORLD_READ WORLD_EXECUTE
)

set(_runner_command
    "${CMAKE_COMMAND}" -E env
    "BRIDGE_FAKE_ADB_STATE=${_state}"
    "${BRIDGE_ANDROID_APP_RUNNER}"
    "${_fake_adb}"
    arm64-v8a
    "${_apk}"
    com.example.game
    org.libsdl.app.SDLActivity
)

if(BRIDGE_ANDROID_APP_RUNNER_TEST_MODE STREQUAL "run")
    execute_process(
        COMMAND ${_runner_command}
        RESULT_VARIABLE _result
        OUTPUT_QUIET
        ERROR_VARIABLE _error
    )
    if(NOT "${_result}" STREQUAL "0")
        message(FATAL_ERROR "Bridge Android app runner failed: ${_error}")
    endif()

    file(READ "${_state}/operations" _operations)
    string(
        CONCAT _expected
        "emulator-5554|install|-r|${_apk}\n"
        "emulator-5554|force-stop|com.example.game\n"
        "emulator-5554|start|com.example.game/org.libsdl.app.SDLActivity\n"
    )
    if(NOT "${_operations}" STREQUAL "${_expected}")
        message(FATAL_ERROR "Bridge Android app runner changed install/launch behavior:\n${_operations}")
    endif()
elseif(BRIDGE_ANDROID_APP_RUNNER_TEST_MODE STREQUAL "install-failure")
    execute_process(
        COMMAND
            "${CMAKE_COMMAND}" -E env
            "BRIDGE_FAKE_ADB_STATE=${_state}"
            BRIDGE_FAKE_ADB_INSTALL_FAIL=1
            "${BRIDGE_ANDROID_APP_RUNNER}"
            "${_fake_adb}"
            arm64-v8a
            "${_apk}"
            com.example.game
            org.libsdl.app.SDLActivity
        RESULT_VARIABLE _result
        OUTPUT_QUIET
        ERROR_QUIET
    )
    if("${_result}" STREQUAL "0" OR EXISTS "${_state}/operations")
        message(FATAL_ERROR "Bridge Android app runner hid an APK install failure")
    endif()
elseif(BRIDGE_ANDROID_APP_RUNNER_TEST_MODE STREQUAL "selection")
    execute_process(
        COMMAND
            "${CMAKE_COMMAND}" -E env
            "BRIDGE_FAKE_ADB_STATE=${_state}"
            BRIDGE_FAKE_ADB_MULTIPLE=1
            "${BRIDGE_ANDROID_APP_RUNNER}"
            "${_fake_adb}"
            arm64-v8a
            "${_apk}"
            com.example.game
            org.libsdl.app.SDLActivity
        RESULT_VARIABLE _ambiguous_result
        ERROR_VARIABLE _ambiguous_error
        OUTPUT_QUIET
    )
    if("${_ambiguous_result}" STREQUAL "0" OR NOT _ambiguous_error MATCHES "set BRIDGE_ANDROID_SERIAL")
        message(FATAL_ERROR "Bridge Android app runner did not reject ambiguous device selection")
    endif()

    file(REMOVE "${_state}/operations")
    execute_process(
        COMMAND
            "${CMAKE_COMMAND}" -E env
            "BRIDGE_FAKE_ADB_STATE=${_state}"
            BRIDGE_FAKE_ADB_MULTIPLE=1
            BRIDGE_ANDROID_SERIAL=device-7
            "${BRIDGE_ANDROID_APP_RUNNER}"
            "${_fake_adb}"
            arm64-v8a
            "${_apk}"
            com.example.game
            org.libsdl.app.SDLActivity
        RESULT_VARIABLE _selected_result
        OUTPUT_QUIET
        ERROR_QUIET
    )
    if(NOT "${_selected_result}" STREQUAL "0")
        message(FATAL_ERROR "Bridge Android app runner rejected explicit compatible device selection")
    endif()

    file(READ "${_state}/operations" _operations)
    if(NOT _operations MATCHES "^device-7[|]install")
        message(FATAL_ERROR "Bridge Android app runner ignored BRIDGE_ANDROID_SERIAL")
    endif()
else()
    message(FATAL_ERROR "Unknown Bridge Android app runner test mode: ${BRIDGE_ANDROID_APP_RUNNER_TEST_MODE}")
endif()
