# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

include_guard(GLOBAL)

function(_bridge_validate_android_ndk_root ROOT OUT_VALID OUT_REVISION OUT_REASON)
    if (NOT IS_ABSOLUTE "${ROOT}")
        set(${OUT_VALID} FALSE PARENT_SCOPE)
        set(${OUT_REVISION} "" PARENT_SCOPE)
        set(${OUT_REASON} "Android NDK root must be an absolute path: ${ROOT}" PARENT_SCOPE)
        return()
    endif()

    set(_toolchain "${ROOT}/build/cmake/android.toolchain.cmake")
    if (NOT EXISTS "${_toolchain}")
        set(${OUT_VALID} FALSE PARENT_SCOPE)
        set(${OUT_REVISION} "" PARENT_SCOPE)
        set(${OUT_REASON} "Android NDK CMake toolchain not found: ${_toolchain}" PARENT_SCOPE)
        return()
    endif()

    set(_revision "unknown")
    if (EXISTS "${ROOT}/source.properties")
        file(STRINGS "${ROOT}/source.properties" _revision_line REGEX "^Pkg\\.Revision[ \t]*=")
        if (_revision_line)
            list(GET _revision_line 0 _revision_line)
            string(REGEX REPLACE "^Pkg\\.Revision[ \t]*=[ \t]*" "" _revision "${_revision_line}")
        endif()
    endif()

    set(${OUT_VALID} TRUE PARENT_SCOPE)
    set(${OUT_REVISION} "${_revision}" PARENT_SCOPE)
    set(${OUT_REASON} "" PARENT_SCOPE)
endfunction()

function(_bridge_find_android_sdk_root OUT_ROOT)
    set(_candidates)

    if (DEFINED BRIDGE_ANDROID_SDK_ROOT AND NOT "${BRIDGE_ANDROID_SDK_ROOT}" STREQUAL "")
        list(APPEND _candidates "${BRIDGE_ANDROID_SDK_ROOT}")
    endif()
    if (DEFINED ENV{BRIDGE_ANDROID_SDK_ROOT} AND NOT "$ENV{BRIDGE_ANDROID_SDK_ROOT}" STREQUAL "")
        list(APPEND _candidates "$ENV{BRIDGE_ANDROID_SDK_ROOT}")
    endif()
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

    foreach(_candidate IN LISTS _candidates)
        if (IS_DIRECTORY "${_candidate}")
            cmake_path(NORMAL_PATH _candidate OUTPUT_VARIABLE _candidate)
            set(${OUT_ROOT} "${_candidate}" PARENT_SCOPE)
            return()
        endif()
    endforeach()

    set(${OUT_ROOT} "" PARENT_SCOPE)
endfunction()

function(_bridge_find_latest_android_ndk SDK_ROOT OUT_ROOT OUT_REVISION)
    set(_best_root "")
    set(_best_revision "")

    if (IS_DIRECTORY "${SDK_ROOT}/ndk")
        file(GLOB _ndk_candidates LIST_DIRECTORIES TRUE "${SDK_ROOT}/ndk/*")
        foreach(_candidate IN LISTS _ndk_candidates)
            if (NOT IS_DIRECTORY "${_candidate}")
                continue()
            endif()

            _bridge_validate_android_ndk_root(
                "${_candidate}"
                _valid
                _revision
                _reason
            )
            if (NOT _valid OR "${_revision}" STREQUAL "unknown")
                continue()
            endif()

            if ("${_best_root}" STREQUAL "" OR _revision VERSION_GREATER _best_revision)
                set(_best_root "${_candidate}")
                set(_best_revision "${_revision}")
            endif()
        endforeach()
    endif()

    if ("${_best_root}" STREQUAL "" AND IS_DIRECTORY "${SDK_ROOT}/ndk-bundle")
        _bridge_validate_android_ndk_root(
            "${SDK_ROOT}/ndk-bundle"
            _valid
            _revision
            _reason
        )
        if (_valid)
            set(_best_root "${SDK_ROOT}/ndk-bundle")
            set(_best_revision "${_revision}")
        endif()
    endif()

    set(${OUT_ROOT} "${_best_root}" PARENT_SCOPE)
    set(${OUT_REVISION} "${_best_revision}" PARENT_SCOPE)
endfunction()

function(_bridge_find_android_environment
    OUT_AVAILABLE
    OUT_SDK_ROOT
    OUT_NDK_ROOT
    OUT_NDK_REVISION
    OUT_ADB
    OUT_REASON)
    _bridge_find_android_sdk_root(_sdk_root)

    set(_ndk_root "")
    set(_ndk_revision "")
    set(_ndk_reason "")

    if (DEFINED BRIDGE_ANDROID_NDK_ROOT AND NOT "${BRIDGE_ANDROID_NDK_ROOT}" STREQUAL "")
        set(_ndk_root "${BRIDGE_ANDROID_NDK_ROOT}")
    elseif (DEFINED ENV{BRIDGE_ANDROID_NDK_ROOT} AND NOT "$ENV{BRIDGE_ANDROID_NDK_ROOT}" STREQUAL "")
        set(_ndk_root "$ENV{BRIDGE_ANDROID_NDK_ROOT}")
    elseif (DEFINED ENV{ANDROID_NDK_ROOT} AND NOT "$ENV{ANDROID_NDK_ROOT}" STREQUAL "")
        set(_ndk_root "$ENV{ANDROID_NDK_ROOT}")
    elseif (DEFINED ENV{ANDROID_NDK_HOME} AND NOT "$ENV{ANDROID_NDK_HOME}" STREQUAL "")
        set(_ndk_root "$ENV{ANDROID_NDK_HOME}")
    elseif (NOT "${_sdk_root}" STREQUAL "")
        _bridge_find_latest_android_ndk("${_sdk_root}" _ndk_root _ndk_revision)
    endif()

    if ("${_ndk_root}" STREQUAL "")
        set(${OUT_AVAILABLE} FALSE PARENT_SCOPE)
        set(${OUT_SDK_ROOT} "${_sdk_root}" PARENT_SCOPE)
        set(${OUT_NDK_ROOT} "" PARENT_SCOPE)
        set(${OUT_NDK_REVISION} "" PARENT_SCOPE)
        set(${OUT_ADB} "" PARENT_SCOPE)
        set(${OUT_REASON}
            "Android NDK was not found; set BRIDGE_ANDROID_NDK_ROOT or install an NDK under ANDROID_HOME"
            PARENT_SCOPE)
        return()
    endif()

    cmake_path(NORMAL_PATH _ndk_root OUTPUT_VARIABLE _ndk_root)
    _bridge_validate_android_ndk_root(
        "${_ndk_root}"
        _ndk_valid
        _validated_revision
        _ndk_reason
    )
    if (NOT _ndk_valid)
        set(${OUT_AVAILABLE} FALSE PARENT_SCOPE)
        set(${OUT_SDK_ROOT} "${_sdk_root}" PARENT_SCOPE)
        set(${OUT_NDK_ROOT} "" PARENT_SCOPE)
        set(${OUT_NDK_REVISION} "" PARENT_SCOPE)
        set(${OUT_ADB} "" PARENT_SCOPE)
        set(${OUT_REASON} "${_ndk_reason}" PARENT_SCOPE)
        return()
    endif()
    set(_ndk_revision "${_validated_revision}")

    set(_adb "")
    if (NOT "${_sdk_root}" STREQUAL "" AND EXISTS "${_sdk_root}/platform-tools/adb")
        set(_adb "${_sdk_root}/platform-tools/adb")
    else()
        find_program(_adb NAMES adb NO_CACHE)
    endif()

    if (NOT _adb)
        set(${OUT_AVAILABLE} FALSE PARENT_SCOPE)
        set(${OUT_SDK_ROOT} "${_sdk_root}" PARENT_SCOPE)
        set(${OUT_NDK_ROOT} "${_ndk_root}" PARENT_SCOPE)
        set(${OUT_NDK_REVISION} "${_ndk_revision}" PARENT_SCOPE)
        set(${OUT_ADB} "" PARENT_SCOPE)
        set(${OUT_REASON}
            "adb was not found; install Android SDK platform-tools or make adb available on PATH"
            PARENT_SCOPE)
        return()
    endif()

    cmake_path(NORMAL_PATH _adb OUTPUT_VARIABLE _adb)

    set(${OUT_AVAILABLE} TRUE PARENT_SCOPE)
    set(${OUT_SDK_ROOT} "${_sdk_root}" PARENT_SCOPE)
    set(${OUT_NDK_ROOT} "${_ndk_root}" PARENT_SCOPE)
    set(${OUT_NDK_REVISION} "${_ndk_revision}" PARENT_SCOPE)
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
                PARENT_SCOPE)
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
