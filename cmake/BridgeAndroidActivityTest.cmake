# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

include_guard(GLOBAL)

include("${CMAKE_CURRENT_LIST_DIR}/BridgeAndroidEnvironment.cmake")

# Runs an SDL Activity-backed test APK as a normal CTest test. The APK must log
# BRIDGE_ACTIVITY_TEST_STARTED followed by exactly one
# BRIDGE_ACTIVITY_TEST_RESULT PASS/FAIL terminal record. The runner treats a
# launch without a terminal record as a failure, even when am start succeeds.
function(bridge_add_android_activity_test)
    set(one_value_args NAME APPLICATION_TARGET)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "" "${one_value_args}" "")
    if(ARG_UNPARSED_ARGUMENTS OR ARG_KEYWORDS_MISSING_VALUES)
        message(FATAL_ERROR "bridge_add_android_activity_test(): invalid arguments")
    endif()
    foreach(_required IN ITEMS NAME APPLICATION_TARGET)
        if(NOT ARG_${_required})
            message(FATAL_ERROR "bridge_add_android_activity_test(): ${_required} is required")
        endif()
    endforeach()
    if(NOT ANDROID)
        message(FATAL_ERROR "bridge_add_android_activity_test() requires an Android target")
    endif()
    if(NOT TARGET "${ARG_APPLICATION_TARGET}")
        message(FATAL_ERROR "bridge_add_android_activity_test(): missing APPLICATION_TARGET '${ARG_APPLICATION_TARGET}'")
    endif()
    foreach(_field IN ITEMS APK APPLICATION_ID ACTIVITY)
        get_target_property(_${_field} "${ARG_APPLICATION_TARGET}" "BRIDGE_ANDROID_${_field}")
        if(NOT _${_field})
            message(FATAL_ERROR
                "bridge_add_android_activity_test(): '${ARG_APPLICATION_TARGET}' is not a Bridge Android application")
        endif()
    endforeach()
    if(NOT DEFINED CMAKE_ANDROID_ARCH_ABI OR CMAKE_ANDROID_ARCH_ABI STREQUAL "")
        message(FATAL_ERROR "bridge_add_android_activity_test(): CMAKE_ANDROID_ARCH_ABI is unavailable")
    endif()
    _bridge_find_android_environment(_available _sdk _adb _reason)
    if(NOT _available)
        message(STATUS "Bridge Android Activity test '${ARG_NAME}': device unavailable at configure (${_reason})")
        set(_adb --adb-unavailable)
    endif()
    set(_runner "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/../runner/bridge-android-activity-test.sh")
    if(NOT EXISTS "${_runner}")
        message(FATAL_ERROR "Bridge Android Activity test runner not found: ${_runner}")
    endif()
    # CTest deploys and executes only. Building the APK remains the normal build graph's responsibility.
    add_test(
        NAME "${ARG_NAME}"
        COMMAND "${_runner}"
            "${_adb}" "${CMAKE_ANDROID_ARCH_ABI}" "${_APK}" "${_APPLICATION_ID}" "${_ACTIVITY}"
    )
    set_tests_properties("${ARG_NAME}" PROPERTIES LABELS "integration;android" TIMEOUT 90 RUN_SERIAL TRUE)
endfunction()
