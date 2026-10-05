# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

foreach(_required IN ITEMS
    BRIDGE_APK
    BRIDGE_ADB_EXECUTABLE
    BRIDGE_ANDROID_SERIAL
)
    if(NOT DEFINED ${_required} OR "${${_required}}" STREQUAL "")
        message(FATAL_ERROR "${_required} is required")
    endif()
endforeach()

if(NOT EXISTS "${BRIDGE_APK}")
    message(
        FATAL_ERROR
        "Bridge Android graphics APK does not exist: ${BRIDGE_APK}\n"
        "Build bridge_android_graphics_apk before running this test."
    )
endif()

set(_bridge_package com.bonkheavy.bridge.graphics)
set(_bridge_activity org.libsdl.app.SDLActivity)
set(_bridge_marker "bridge android graphics ready")

function(_bridge_uninstall_package_if_present)
    execute_process(
        COMMAND
            "${BRIDGE_ADB_EXECUTABLE}" -s "${BRIDGE_ANDROID_SERIAL}"
            shell pm list packages "${_bridge_package}"
        RESULT_VARIABLE _query_result
        OUTPUT_VARIABLE _query_output
        ERROR_VARIABLE _query_error
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_STRIP_TRAILING_WHITESPACE
    )
    if(NOT "${_query_result}" STREQUAL "0")
        message(
            FATAL_ERROR
            "Bridge Android graphics package query failed (${_query_result})\n"
            "stdout:\n${_query_output}\n"
            "stderr:\n${_query_error}"
        )
    endif()

    string(REPLACE "\r" "" _query_output "${_query_output}")
    string(REPLACE "\n" ";" _query_lines "${_query_output}")
    list(FIND _query_lines "package:${_bridge_package}" _package_index)
    if(_package_index EQUAL -1)
        return()
    endif()

    execute_process(
        COMMAND
            "${BRIDGE_ADB_EXECUTABLE}" -s "${BRIDGE_ANDROID_SERIAL}"
            shell am force-stop "${_bridge_package}"
        RESULT_VARIABLE _stop_result
        OUTPUT_VARIABLE _stop_output
        ERROR_VARIABLE _stop_error
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_STRIP_TRAILING_WHITESPACE
    )
    if(NOT "${_stop_result}" STREQUAL "0")
        message(
            FATAL_ERROR
            "Bridge Android graphics package force-stop failed (${_stop_result})\n"
            "stdout:\n${_stop_output}\n"
            "stderr:\n${_stop_error}"
        )
    endif()

    execute_process(
        COMMAND
            "${BRIDGE_ADB_EXECUTABLE}" -s "${BRIDGE_ANDROID_SERIAL}"
            uninstall "${_bridge_package}"
        RESULT_VARIABLE _uninstall_result
        OUTPUT_VARIABLE _uninstall_output
        ERROR_VARIABLE _uninstall_error
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_STRIP_TRAILING_WHITESPACE
    )
    if(NOT "${_uninstall_result}" STREQUAL "0")
        message(
            FATAL_ERROR
            "Bridge Android graphics package uninstall failed (${_uninstall_result})\n"
            "stdout:\n${_uninstall_output}\n"
            "stderr:\n${_uninstall_error}"
        )
    endif()
endfunction()

_bridge_uninstall_package_if_present()

execute_process(
    COMMAND
        "${BRIDGE_ADB_EXECUTABLE}" -s "${BRIDGE_ANDROID_SERIAL}"
        install "${BRIDGE_APK}"
    RESULT_VARIABLE _install_result
    OUTPUT_VARIABLE _install_output
    ERROR_VARIABLE _install_error
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_STRIP_TRAILING_WHITESPACE
)
if(NOT "${_install_result}" STREQUAL "0")
    message(
        FATAL_ERROR
        "Bridge Android graphics APK install failed\nstdout:\n${_install_output}\nstderr:\n${_install_error}"
    )
endif()

execute_process(
    COMMAND "${BRIDGE_ADB_EXECUTABLE}" -s "${BRIDGE_ANDROID_SERIAL}" logcat -c
    RESULT_VARIABLE _log_clear_result
)
if(NOT "${_log_clear_result}" STREQUAL "0")
    message(FATAL_ERROR "Bridge Android graphics logcat clear failed")
endif()

execute_process(
    COMMAND
        "${BRIDGE_ADB_EXECUTABLE}" -s "${BRIDGE_ANDROID_SERIAL}"
        shell am start -n "${_bridge_package}/${_bridge_activity}"
    RESULT_VARIABLE _launch_result
    OUTPUT_VARIABLE _launch_output
    ERROR_VARIABLE _launch_error
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_STRIP_TRAILING_WHITESPACE
    TIMEOUT 10
)
if(NOT "${_launch_result}" STREQUAL "0")
    message(
        FATAL_ERROR
        "Bridge Android graphics activity launch failed\nstdout:\n${_launch_output}\nstderr:\n${_launch_error}"
    )
endif()

set(_graphics_ready FALSE)
foreach(_attempt RANGE 1 20)
    execute_process(
        COMMAND "${BRIDGE_ADB_EXECUTABLE}" -s "${BRIDGE_ANDROID_SERIAL}" logcat -d
        RESULT_VARIABLE _log_result
        OUTPUT_VARIABLE _log_output
        ERROR_VARIABLE _log_error
    )
    if(NOT "${_log_result}" STREQUAL "0")
        message(FATAL_ERROR "Bridge Android graphics logcat read failed: ${_log_error}")
    endif()

    string(FIND "${_log_output}" "${_bridge_marker}" _marker_position)
    if(NOT _marker_position LESS 0)
        set(_graphics_ready TRUE)
        break()
    endif()

    execute_process(COMMAND "${CMAKE_COMMAND}" -E sleep 0.25)
endforeach()

if(NOT _graphics_ready)
    execute_process(
        COMMAND "${BRIDGE_ADB_EXECUTABLE}" -s "${BRIDGE_ANDROID_SERIAL}" logcat -d -v threadtime -t 200
        OUTPUT_VARIABLE _failure_log
        ERROR_VARIABLE _failure_log_error
    )
    message(
        FATAL_ERROR
        "Bridge Android graphics app did not report a completed GLES frame\n"
        "launch output:\n${_launch_output}\n"
        "logcat:\n${_failure_log}\n${_failure_log_error}"
    )
endif()

# Keep the verified frame visible long enough to make this milestone observable
# during an interactive emulator run, then clean up the installed test package.
execute_process(COMMAND "${CMAKE_COMMAND}" -E sleep 1)

_bridge_uninstall_package_if_present()

message(STATUS "Bridge Android graphics APK rendered a GLES frame on ${BRIDGE_ANDROID_SERIAL}")
