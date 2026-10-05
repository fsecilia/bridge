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

function(_bridge_find_android_ndk OUT_AVAILABLE OUT_ROOT OUT_REVISION OUT_REASON)
    if (DEFINED CMAKE_ANDROID_NDK AND NOT "${CMAKE_ANDROID_NDK}" STREQUAL "")
        cmake_path(NORMAL_PATH CMAKE_ANDROID_NDK OUTPUT_VARIABLE _ndk_root)
        _bridge_validate_android_ndk_root(
            "${_ndk_root}"
            _valid
            _revision
            _reason
        )
        if (NOT _valid)
            set(${OUT_AVAILABLE} FALSE PARENT_SCOPE)
            set(${OUT_ROOT} "" PARENT_SCOPE)
            set(${OUT_REVISION} "" PARENT_SCOPE)
            set(${OUT_REASON} "${_reason}" PARENT_SCOPE)
            return()
        endif()

        set(${OUT_AVAILABLE} TRUE PARENT_SCOPE)
        set(${OUT_ROOT} "${_ndk_root}" PARENT_SCOPE)
        set(${OUT_REVISION} "${_revision}" PARENT_SCOPE)
        set(${OUT_REASON} "" PARENT_SCOPE)
        return()
    endif()

    foreach(_environment_variable IN ITEMS ANDROID_NDK_ROOT ANDROID_NDK_HOME)
        if (DEFINED ENV{${_environment_variable}} AND NOT "$ENV{${_environment_variable}}" STREQUAL "")
            set(_ndk_root "$ENV{${_environment_variable}}")
            cmake_path(NORMAL_PATH _ndk_root OUTPUT_VARIABLE _ndk_root)
            _bridge_validate_android_ndk_root(
                "${_ndk_root}"
                _valid
                _revision
                _reason
            )
            if (NOT _valid)
                set(${OUT_AVAILABLE} FALSE PARENT_SCOPE)
                set(${OUT_ROOT} "" PARENT_SCOPE)
                set(${OUT_REVISION} "" PARENT_SCOPE)
                set(${OUT_REASON} "${_environment_variable} points to an unusable NDK: ${_reason}" PARENT_SCOPE)
                return()
            endif()

            set(${OUT_AVAILABLE} TRUE PARENT_SCOPE)
            set(${OUT_ROOT} "${_ndk_root}" PARENT_SCOPE)
            set(${OUT_REVISION} "${_revision}" PARENT_SCOPE)
            set(${OUT_REASON} "" PARENT_SCOPE)
            return()
        endif()
    endforeach()

    set(_sdk_candidates)
    if (DEFINED ENV{ANDROID_HOME} AND NOT "$ENV{ANDROID_HOME}" STREQUAL "")
        list(APPEND _sdk_candidates "$ENV{ANDROID_HOME}")
    endif()
    if (DEFINED ENV{ANDROID_SDK_ROOT} AND NOT "$ENV{ANDROID_SDK_ROOT}" STREQUAL "")
        list(APPEND _sdk_candidates "$ENV{ANDROID_SDK_ROOT}")
    endif()
    if (DEFINED ENV{HOME} AND NOT "$ENV{HOME}" STREQUAL "")
        list(APPEND _sdk_candidates
            "$ENV{HOME}/Android/Sdk"
            "$ENV{HOME}/Library/Android/sdk"
        )
    endif()
    list(APPEND _sdk_candidates "/opt/android-sdk")
    list(REMOVE_DUPLICATES _sdk_candidates)

    foreach(_sdk_root IN LISTS _sdk_candidates)
        if (NOT IS_DIRECTORY "${_sdk_root}")
            continue()
        endif()

        _bridge_find_latest_android_ndk("${_sdk_root}" _ndk_root _revision)
        if (NOT "${_ndk_root}" STREQUAL "")
            set(${OUT_AVAILABLE} TRUE PARENT_SCOPE)
            set(${OUT_ROOT} "${_ndk_root}" PARENT_SCOPE)
            set(${OUT_REVISION} "${_revision}" PARENT_SCOPE)
            set(${OUT_REASON} "" PARENT_SCOPE)
            return()
        endif()
    endforeach()

    set(${OUT_AVAILABLE} FALSE PARENT_SCOPE)
    set(${OUT_ROOT} "" PARENT_SCOPE)
    set(${OUT_REVISION} "" PARENT_SCOPE)
    set(${OUT_REASON}
        "Android NDK was not found; set CMAKE_ANDROID_NDK or install an NDK under a discoverable Android SDK"
        PARENT_SCOPE
    )
endfunction()
