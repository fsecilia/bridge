# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

foreach(_required IN ITEMS
    BRIDGE_SOURCE_DIR
    BRIDGE_BINARY_DIR
    BRIDGE_GENERATOR
    BRIDGE_TOOLCHAIN_FILE
    CMAKE_ANDROID_NDK
    CMAKE_ANDROID_ARCH_ABI
    BRIDGE_ANDROID_SDK_ROOT
    BRIDGE_ADB_EXECUTABLE
    BRIDGE_ANDROID_SERIAL
    BRIDGE_SDL_SOURCE_DIR
)
    if (NOT DEFINED ${_required} OR "${${_required}}" STREQUAL "")
        message(FATAL_ERROR "${_required} is required")
    endif()
endforeach()

set(_bridge_package com.bonkheavy.bridge.graphics)
set(_bridge_activity org.libsdl.app.SDLActivity)
set(_bridge_marker "bridge android graphics ready")
set(_bridge_apk "${BRIDGE_BINARY_DIR}/bridge-android-graphics.apk")

file(REMOVE_RECURSE "${BRIDGE_BINARY_DIR}")

execute_process(
    COMMAND
        "${CMAKE_COMMAND}"
        -S "${BRIDGE_SOURCE_DIR}/test/android-graphics"
        -B "${BRIDGE_BINARY_DIR}"
        -G "${BRIDGE_GENERATOR}"
        --toolchain "${BRIDGE_TOOLCHAIN_FILE}"
        "-DBRIDGE_SOURCE_DIR:PATH=${BRIDGE_SOURCE_DIR}"
        "-DBRIDGE_SDL_SOURCE_DIR:PATH=${BRIDGE_SDL_SOURCE_DIR}"
        "-DBRIDGE_ANDROID_SDK_ROOT:PATH=${BRIDGE_ANDROID_SDK_ROOT}"
        "-DCMAKE_ANDROID_NDK:PATH=${CMAKE_ANDROID_NDK}"
        "-DCMAKE_ANDROID_ARCH_ABI:STRING=${CMAKE_ANDROID_ARCH_ABI}"
    RESULT_VARIABLE _configure_result
)
if (NOT "${_configure_result}" STREQUAL "0")
    message(FATAL_ERROR "Bridge Android graphics specimen configure failed")
endif()

execute_process(
    COMMAND "${CMAKE_COMMAND}" --build "${BRIDGE_BINARY_DIR}" --target bridge_android_graphics_apk
    RESULT_VARIABLE _build_result
)
if (NOT "${_build_result}" STREQUAL "0")
    message(FATAL_ERROR "Bridge Android graphics APK build failed")
endif()
if (NOT EXISTS "${_bridge_apk}")
    message(FATAL_ERROR "Bridge Android graphics APK was not produced: ${_bridge_apk}")
endif()

execute_process(
    COMMAND "${BRIDGE_ADB_EXECUTABLE}" -s "${BRIDGE_ANDROID_SERIAL}" install -r "${_bridge_apk}"
    RESULT_VARIABLE _install_result
    OUTPUT_VARIABLE _install_output
    ERROR_VARIABLE _install_error
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_STRIP_TRAILING_WHITESPACE
)
if (NOT "${_install_result}" STREQUAL "0")
    message(
        FATAL_ERROR
        "Bridge Android graphics APK install failed\nstdout:\n${_install_output}\nstderr:\n${_install_error}"
    )
endif()

execute_process(
    COMMAND "${BRIDGE_ADB_EXECUTABLE}" -s "${BRIDGE_ANDROID_SERIAL}" logcat -c
    RESULT_VARIABLE _log_clear_result
)
if (NOT "${_log_clear_result}" STREQUAL "0")
    message(FATAL_ERROR "Bridge Android graphics logcat clear failed")
endif()

# Keep the verified frame visible long enough to make this milestone observable
# during an interactive emulator run, then clean up deterministically.
execute_process(COMMAND "${CMAKE_COMMAND}" -E sleep 1)

execute_process(
    COMMAND "${BRIDGE_ADB_EXECUTABLE}" -s "${BRIDGE_ANDROID_SERIAL}" shell am force-stop "${_bridge_package}"
    RESULT_VARIABLE _stop_before_result
)
if (NOT "${_stop_before_result}" STREQUAL "0")
    message(FATAL_ERROR "Bridge Android graphics pre-launch force-stop failed")
endif()

execute_process(
    COMMAND
        "${BRIDGE_ADB_EXECUTABLE}" -s "${BRIDGE_ANDROID_SERIAL}"
        shell am start -W -n "${_bridge_package}/${_bridge_activity}"
    RESULT_VARIABLE _launch_result
    OUTPUT_VARIABLE _launch_output
    ERROR_VARIABLE _launch_error
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_STRIP_TRAILING_WHITESPACE
)
if (NOT "${_launch_result}" STREQUAL "0")
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
    if (NOT "${_log_result}" STREQUAL "0")
        message(FATAL_ERROR "Bridge Android graphics logcat read failed: ${_log_error}")
    endif()

    string(FIND "${_log_output}" "${_bridge_marker}" _marker_position)
    if (NOT _marker_position LESS 0)
        set(_graphics_ready TRUE)
        break()
    endif()

    execute_process(COMMAND "${CMAKE_COMMAND}" -E sleep 0.25)
endforeach()

if (NOT _graphics_ready)
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

execute_process(
    COMMAND "${BRIDGE_ADB_EXECUTABLE}" -s "${BRIDGE_ANDROID_SERIAL}" shell am force-stop "${_bridge_package}"
    RESULT_VARIABLE _stop_after_result
)
if (NOT "${_stop_after_result}" STREQUAL "0")
    message(FATAL_ERROR "Bridge Android graphics post-test force-stop failed")
endif()

message(STATUS "Bridge Android graphics APK rendered a GLES frame on ${BRIDGE_ANDROID_SERIAL}")
