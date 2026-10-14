# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

foreach(_required IN ITEMS BRIDGE_ANDROID_ACTIVITY_RUNNER BRIDGE_ACTIVITY_TEST_BINARY_DIR BRIDGE_ACTIVITY_TEST_MODE)
    if(NOT DEFINED ${_required})
        message(FATAL_ERROR "${_required} is required")
    endif()
endforeach()

file(REMOVE_RECURSE "${BRIDGE_ACTIVITY_TEST_BINARY_DIR}")
file(MAKE_DIRECTORY "${BRIDGE_ACTIVITY_TEST_BINARY_DIR}")
set(_fake_adb "${BRIDGE_ACTIVITY_TEST_BINARY_DIR}/adb")
set(_state "${BRIDGE_ACTIVITY_TEST_BINARY_DIR}/state")
set(_apk "${BRIDGE_ACTIVITY_TEST_BINARY_DIR}/activity.apk")
file(MAKE_DIRECTORY "${_state}")
file(WRITE "${_apk}" "apk")
file(WRITE "${_fake_adb}" [=[#!/bin/sh
set -eu
state=$BRIDGE_FAKE_ADB_STATE
if [ "$#" -eq 1 ] && [ "$1" = devices ]; then
    printf '%s\n' 'List of devices attached' 'emulator-5554 device'
    exit 0
fi
if [ "$1" != -s ] || [ "$2" != emulator-5554 ]; then
    exit 2
fi
shift 2
case $1 in
    get-state) printf 'device\n'; exit 0 ;;
    install)
        if [ "${BRIDGE_FAKE_TEST_MODE:-}" = install-failure ]; then
            exit 1
        fi
        printf '%s\n' 'install' >>"$state/actions"
        printf '%s\n' 'Success'
        exit 0
        ;;
    uninstall) printf '%s\n' 'uninstall' >>"$state/actions"; exit 0 ;;
    logcat)
        if [ "$2" = -c ]; then
            printf '%s\n' 'clear' >>"$state/actions"
            exit 0
        fi
        case ${BRIDGE_FAKE_TEST_MODE:-pass} in
            pass) printf '%s\n' 'I SDL: BRIDGE_ACTIVITY_TEST_STARTED' \
                'I SDL: BRIDGE_ACTIVITY_TEST_CASE PASS MyTest.Test' \
                'I SDL: BRIDGE_ACTIVITY_TEST_RESULT PASS passed=1 failed=0' ;;
            fail) printf '%s\n' 'I SDL: BRIDGE_ACTIVITY_TEST_STARTED' \
                'E SDL: BRIDGE_ACTIVITY_TEST_ASSERT a.cpp:9 failed' \
                'I SDL: BRIDGE_ACTIVITY_TEST_RESULT FAIL passed=0 failed=1' ;;
            no-start) printf '%s\n' 'I SDL: BRIDGE_ACTIVITY_TEST_RESULT PASS passed=1 failed=0' ;;
            duplicate) printf '%s\n' 'I SDL: BRIDGE_ACTIVITY_TEST_STARTED' \
                'I SDL: BRIDGE_ACTIVITY_TEST_RESULT PASS passed=1 failed=0' \
                'I SDL: BRIDGE_ACTIVITY_TEST_RESULT PASS passed=1 failed=0' ;;
            timeout) printf '%s\n' 'I SDL: BRIDGE_ACTIVITY_TEST_STARTED' ;;
        esac
        exit 0
        ;;
    shell)
        shift
        if [ "$1" = getprop ]; then
            printf '%s\n' arm64-v8a
            exit 0
        fi
        if [ "$1" = am ] && [ "$2" = force-stop ]; then
            printf '%s\n' 'force-stop' >>"$state/actions"
            exit 0
        fi
        if [ "$1" = am ] && [ "$2" = start ] && [ "$3" = -n ]; then
            printf '%s\n' 'start' >>"$state/actions"
            exit 0
        fi
        ;;
esac
exit 2
]=])
file(CHMOD "${_fake_adb}" PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
execute_process(
    COMMAND "${CMAKE_COMMAND}" -E env
        "BRIDGE_FAKE_ADB_STATE=${_state}"
        "BRIDGE_FAKE_TEST_MODE=${BRIDGE_ACTIVITY_TEST_MODE}"
        "BRIDGE_ANDROID_TEST_TIMEOUT_SECONDS=1"
        "${BRIDGE_ANDROID_ACTIVITY_RUNNER}"
        "${_fake_adb}" arm64-v8a "${_apk}" com.example.tests org.libsdl.app.SDLActivity
    RESULT_VARIABLE _result
    OUTPUT_VARIABLE _output
    ERROR_VARIABLE _error
)
if(BRIDGE_ACTIVITY_TEST_MODE STREQUAL pass)
    if(NOT "${_result}" STREQUAL "0" OR NOT _output MATCHES "BRIDGE_ACTIVITY_TEST_CASE PASS")
        message(FATAL_ERROR "Successful Activity tests were rejected:\n${_output}\n${_error}")
    endif()
else()
    if("${_result}" STREQUAL "0" OR NOT _error MATCHES "bridge-android-activity-test")
        message(FATAL_ERROR "Activity test runner hid ${BRIDGE_ACTIVITY_TEST_MODE} failure:\n${_output}\n${_error}")
    endif()
endif()
if(EXISTS "${_state}/actions")
    file(READ "${_state}/actions" _actions)
    if(BRIDGE_ACTIVITY_TEST_MODE STREQUAL install-failure)
        if(_actions MATCHES "uninstall")
            message(FATAL_ERROR "Runner uninstalled a package that was never installed")
        endif()
    elseif(NOT _actions MATCHES "start" OR NOT _actions MATCHES "uninstall")
        message(FATAL_ERROR "Activity runner did not launch and clean up:\n${_actions}")
    endif()
endif()
