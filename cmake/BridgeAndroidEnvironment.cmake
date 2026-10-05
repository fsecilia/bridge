# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

include_guard(GLOBAL)

function(_bridge_find_android_sdk_root OUT_ROOT OUT_REASON)
    if (DEFINED BRIDGE_ANDROID_SDK_ROOT AND NOT "${BRIDGE_ANDROID_SDK_ROOT}" STREQUAL "")
        set(_sdk_root "${BRIDGE_ANDROID_SDK_ROOT}")
        cmake_path(NORMAL_PATH _sdk_root OUTPUT_VARIABLE _sdk_root)
        if (NOT IS_DIRECTORY "${_sdk_root}")
            set(${OUT_ROOT} "" PARENT_SCOPE)
            set(${OUT_REASON} "BRIDGE_ANDROID_SDK_ROOT is not a directory: ${_sdk_root}" PARENT_SCOPE)
            return()
        endif()

        set(${OUT_ROOT} "${_sdk_root}" PARENT_SCOPE)
        set(${OUT_REASON} "" PARENT_SCOPE)
        return()
    endif()

    if (DEFINED ENV{BRIDGE_ANDROID_SDK_ROOT} AND NOT "$ENV{BRIDGE_ANDROID_SDK_ROOT}" STREQUAL "")
        set(_sdk_root "$ENV{BRIDGE_ANDROID_SDK_ROOT}")
        cmake_path(NORMAL_PATH _sdk_root OUTPUT_VARIABLE _sdk_root)
        if (NOT IS_DIRECTORY "${_sdk_root}")
            set(${OUT_ROOT} "" PARENT_SCOPE)
            set(${OUT_REASON} "BRIDGE_ANDROID_SDK_ROOT environment variable is not a directory: ${_sdk_root}" PARENT_SCOPE)
            return()
        endif()

        set(${OUT_ROOT} "${_sdk_root}" PARENT_SCOPE)
        set(${OUT_REASON} "" PARENT_SCOPE)
        return()
    endif()

    set(_candidates)
    if (DEFINED ENV{ANDROID_HOME} AND NOT "$ENV{ANDROID_HOME}" STREQUAL "")
        list(APPEND _candidates "$ENV{ANDROID_HOME}")
    endif()
    if (DEFINED ENV{ANDROID_SDK_ROOT} AND NOT "$ENV{ANDROID_SDK_ROOT}" STREQUAL "")
        list(APPEND _candidates "$ENV{ANDROID_SDK_ROOT}")
    endif()
    if (DEFINED ENV{HOME} AND NOT "$ENV{HOME}" STREQUAL "")
        list(APPEND _candidates
            "$ENV{HOME}/Android/Sdk"
            "$ENV{HOME}/Library/Android/sdk"
        )
    endif()
    list(APPEND _candidates "/opt/android-sdk")
    list(REMOVE_DUPLICATES _candidates)

    foreach(_candidate IN LISTS _candidates)
        if (IS_DIRECTORY "${_candidate}")
            cmake_path(NORMAL_PATH _candidate OUTPUT_VARIABLE _candidate)
            set(${OUT_ROOT} "${_candidate}" PARENT_SCOPE)
            set(${OUT_REASON} "" PARENT_SCOPE)
            return()
        endif()
    endforeach()

    set(${OUT_ROOT} "" PARENT_SCOPE)
    set(${OUT_REASON} "" PARENT_SCOPE)
endfunction()

function(_bridge_find_android_environment OUT_AVAILABLE OUT_SDK_ROOT OUT_ADB OUT_REASON)
    _bridge_find_android_sdk_root(_sdk_root _sdk_reason)
    if (NOT "${_sdk_reason}" STREQUAL "")
        set(${OUT_AVAILABLE} FALSE PARENT_SCOPE)
        set(${OUT_SDK_ROOT} "" PARENT_SCOPE)
        set(${OUT_ADB} "" PARENT_SCOPE)
        set(${OUT_REASON} "${_sdk_reason}" PARENT_SCOPE)
        return()
    endif()

    set(_adb "")
    if (NOT "${_sdk_root}" STREQUAL "" AND EXISTS "${_sdk_root}/platform-tools/adb")
        set(_adb "${_sdk_root}/platform-tools/adb")
    else()
        find_program(
            _adb
            NAMES adb
            NO_CACHE
            NO_CMAKE_FIND_ROOT_PATH
        )
    endif()

    if (NOT _adb)
        set(${OUT_AVAILABLE} FALSE PARENT_SCOPE)
        set(${OUT_SDK_ROOT} "${_sdk_root}" PARENT_SCOPE)
        set(${OUT_ADB} "" PARENT_SCOPE)
        set(${OUT_REASON}
            "adb was not found; install Android SDK platform-tools or set BRIDGE_ANDROID_SDK_ROOT"
            PARENT_SCOPE
        )
        return()
    endif()

    cmake_path(NORMAL_PATH _adb OUTPUT_VARIABLE _adb)

    set(${OUT_AVAILABLE} TRUE PARENT_SCOPE)
    set(${OUT_SDK_ROOT} "${_sdk_root}" PARENT_SCOPE)
    set(${OUT_ADB} "${_adb}" PARENT_SCOPE)
    set(${OUT_REASON} "" PARENT_SCOPE)
endfunction()

function(_bridge_find_android_device ADB ABI OUT_AVAILABLE OUT_SERIAL OUT_REASON)
    if (DEFINED ENV{BRIDGE_ANDROID_SERIAL} AND NOT "$ENV{BRIDGE_ANDROID_SERIAL}" STREQUAL "")
        set(_requested_serial "$ENV{BRIDGE_ANDROID_SERIAL}")
        execute_process(
            COMMAND "${ADB}" -s "${_requested_serial}" get-state
            RESULT_VARIABLE _state_result
            OUTPUT_VARIABLE _state
            ERROR_VARIABLE _state_error
            OUTPUT_STRIP_TRAILING_WHITESPACE
            ERROR_STRIP_TRAILING_WHITESPACE
        )
        if (NOT "${_state_result}" STREQUAL "0" OR NOT "${_state}" STREQUAL "device")
            set(${OUT_AVAILABLE} FALSE PARENT_SCOPE)
            set(${OUT_SERIAL} "" PARENT_SCOPE)
            set(${OUT_REASON}
                "BRIDGE_ANDROID_SERIAL=${_requested_serial} is not an online adb device: ${_state_error}"
                PARENT_SCOPE
            )
            return()
        endif()
        set(_serials "${_requested_serial}")
    else()
        execute_process(
            COMMAND "${ADB}" devices
            RESULT_VARIABLE _devices_result
            OUTPUT_VARIABLE _devices_output
            ERROR_VARIABLE _devices_error
            OUTPUT_STRIP_TRAILING_WHITESPACE
            ERROR_STRIP_TRAILING_WHITESPACE
        )
        if (NOT "${_devices_result}" STREQUAL "0")
            set(${OUT_AVAILABLE} FALSE PARENT_SCOPE)
            set(${OUT_SERIAL} "" PARENT_SCOPE)
            set(${OUT_REASON} "adb devices failed: ${_devices_error}" PARENT_SCOPE)
            return()
        endif()

        string(REPLACE "\r\n" "\n" _devices_output "${_devices_output}")
        string(REPLACE "\r" "\n" _devices_output "${_devices_output}")
        string(REPLACE "\n" ";" _device_lines "${_devices_output}")
        set(_serials)
        foreach(_line IN LISTS _device_lines)
            if (_line MATCHES "^([^\t]+)\tdevice$")
                list(APPEND _serials "${CMAKE_MATCH_1}")
            endif()
        endforeach()
    endif()

    set(_compatible)
    foreach(_serial IN LISTS _serials)
        execute_process(
            COMMAND "${ADB}" -s "${_serial}" shell getprop ro.product.cpu.abilist
            RESULT_VARIABLE _abi_result
            OUTPUT_VARIABLE _abi_list
            ERROR_QUIET
            OUTPUT_STRIP_TRAILING_WHITESPACE
        )
        string(REPLACE "\r" "" _abi_list "${_abi_list}")
        if (NOT "${_abi_result}" STREQUAL "0" OR "${_abi_list}" STREQUAL "")
            execute_process(
                COMMAND "${ADB}" -s "${_serial}" shell getprop ro.product.cpu.abi
                RESULT_VARIABLE _abi_result
                OUTPUT_VARIABLE _abi_list
                ERROR_QUIET
                OUTPUT_STRIP_TRAILING_WHITESPACE
            )
            string(REPLACE "\r" "" _abi_list "${_abi_list}")
        endif()

        string(REPLACE "," ";" _abis "${_abi_list}")
        list(FIND _abis "${ABI}" _abi_index)
        if (NOT _abi_index EQUAL -1)
            list(APPEND _compatible "${_serial}")
        endif()
    endforeach()

    list(LENGTH _compatible _compatible_count)
    if (_compatible_count EQUAL 1)
        list(GET _compatible 0 _serial)
        set(${OUT_AVAILABLE} TRUE PARENT_SCOPE)
        set(${OUT_SERIAL} "${_serial}" PARENT_SCOPE)
        set(${OUT_REASON} "" PARENT_SCOPE)
        return()
    endif()

    if (_compatible_count EQUAL 0)
        set(_reason "no online adb device supports Android ABI ${ABI}")
    else()
        list(JOIN _compatible ", " _compatible_text)
        set(_reason
            "multiple adb devices support Android ABI ${ABI}: ${_compatible_text}; set BRIDGE_ANDROID_SERIAL"
        )
    endif()

    set(${OUT_AVAILABLE} FALSE PARENT_SCOPE)
    set(${OUT_SERIAL} "" PARENT_SCOPE)
    set(${OUT_REASON} "${_reason}" PARENT_SCOPE)
endfunction()
