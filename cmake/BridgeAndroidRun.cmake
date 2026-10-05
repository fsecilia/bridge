# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

include_guard(GLOBAL)

include("${CMAKE_CURRENT_LIST_DIR}/BridgeAndroidEnvironment.cmake")

function(bridge_add_android_run_target)
    set(one_value_args TARGET APPLICATION_TARGET)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "" "${one_value_args}" "")

    if(ARG_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "bridge_add_android_run_target(): unknown arguments: ${ARG_UNPARSED_ARGUMENTS}")
    endif()
    if(ARG_KEYWORDS_MISSING_VALUES)
        message(FATAL_ERROR "bridge_add_android_run_target(): missing values for: ${ARG_KEYWORDS_MISSING_VALUES}")
    endif()
    foreach(_required IN ITEMS TARGET APPLICATION_TARGET)
        if(NOT ARG_${_required})
            message(FATAL_ERROR "bridge_add_android_run_target(): ${_required} is required")
        endif()
    endforeach()

    if(NOT ANDROID)
        message(FATAL_ERROR "bridge_add_android_run_target() requires an Android target")
    endif()
    if(NOT DEFINED CMAKE_ANDROID_ARCH_ABI OR "${CMAKE_ANDROID_ARCH_ABI}" STREQUAL "")
        message(FATAL_ERROR "bridge_add_android_run_target(): CMAKE_ANDROID_ARCH_ABI is unavailable")
    endif()
    if(TARGET "${ARG_TARGET}")
        message(FATAL_ERROR "bridge_add_android_run_target(): target '${ARG_TARGET}' already exists")
    endif()
    if(NOT TARGET "${ARG_APPLICATION_TARGET}")
        message(
            FATAL_ERROR
            "bridge_add_android_run_target(): APPLICATION_TARGET '${ARG_APPLICATION_TARGET}' does not exist"
        )
    endif()

    get_target_property(_apk "${ARG_APPLICATION_TARGET}" BRIDGE_ANDROID_APK)
    get_target_property(_application_id "${ARG_APPLICATION_TARGET}" BRIDGE_ANDROID_APPLICATION_ID)
    get_target_property(_activity "${ARG_APPLICATION_TARGET}" BRIDGE_ANDROID_ACTIVITY)
    foreach(_property IN ITEMS _apk _application_id _activity)
        if("${${_property}}" STREQUAL "" OR "${${_property}}" MATCHES "-NOTFOUND$")
            message(
                FATAL_ERROR
                "bridge_add_android_run_target(): APPLICATION_TARGET '${ARG_APPLICATION_TARGET}' is not a Bridge Android application target"
            )
        endif()
    endforeach()

    set(_runner "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/../runner/bridge-android-app.sh")
    if(NOT EXISTS "${_runner}")
        message(FATAL_ERROR "Bridge Android application runner not found: ${_runner}")
    endif()

    _bridge_find_android_environment(_runtime_available _sdk_root _adb _runtime_reason)
    if(NOT _runtime_available)
        set(_adb --adb-unavailable)
    endif()

    add_custom_target(
        "${ARG_TARGET}"
        COMMAND
            "${_runner}"
            "${_adb}"
            "${CMAKE_ANDROID_ARCH_ABI}"
            "${_apk}"
            "${_application_id}"
            "${_activity}"
        DEPENDS "${ARG_APPLICATION_TARGET}"
        COMMENT "Installing and launching ${_application_id}"
        USES_TERMINAL
        VERBATIM
    )
endfunction()
