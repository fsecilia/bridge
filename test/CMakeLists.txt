# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

function(_bridge_add_execution_test NAME)
    set(options EMULATED REMOTE)
    set(one_value_args TOOLCHAIN LLVM_MINGW_ROOT CMAKE_ANDROID_NDK ANDROID_SDK_ROOT ANDROID_ARCH_ABI ANDROID_SERIAL LABEL)
    cmake_parse_arguments(PARSE_ARGV 1 ARG "${options}" "${one_value_args}" "")

    set(_bridge_binary_dir "${CMAKE_CURRENT_BINARY_DIR}/${NAME}")
    set(_bridge_arguments
        "-DBRIDGE_SOURCE_DIR=${PROJECT_SOURCE_DIR}"
        "-DBRIDGE_BINARY_DIR=${_bridge_binary_dir}"
        "-DBRIDGE_GENERATOR=${CMAKE_GENERATOR}"
    )

    if (ARG_TOOLCHAIN)
        list(APPEND _bridge_arguments "-DBRIDGE_TOOLCHAIN_FILE=${ARG_TOOLCHAIN}")
    endif()
    if (ARG_LLVM_MINGW_ROOT)
        list(APPEND _bridge_arguments "-DBRIDGE_LLVM_MINGW_ROOT=${ARG_LLVM_MINGW_ROOT}")
    endif()
    if (ARG_CMAKE_ANDROID_NDK)
        list(APPEND _bridge_arguments "-DCMAKE_ANDROID_NDK=${ARG_CMAKE_ANDROID_NDK}")
    endif()
    if (ARG_ANDROID_SDK_ROOT)
        list(APPEND _bridge_arguments "-DBRIDGE_ANDROID_SDK_ROOT=${ARG_ANDROID_SDK_ROOT}")
    endif()
    if (ARG_ANDROID_ARCH_ABI)
        list(APPEND _bridge_arguments "-DCMAKE_ANDROID_ARCH_ABI=${ARG_ANDROID_ARCH_ABI}")
    endif()
    if (ARG_REMOTE)
        list(APPEND _bridge_arguments -DBRIDGE_REMOTE_EXECUTION=TRUE)
    else()
        list(APPEND _bridge_arguments -DBRIDGE_REMOTE_EXECUTION=FALSE)
    endif()

    if (ARG_EMULATED)
        list(APPEND _bridge_arguments -DBRIDGE_EXPECT_TEST_EMULATOR=TRUE)
    else()
        list(APPEND _bridge_arguments -DBRIDGE_EXPECT_TEST_EMULATOR=FALSE)
    endif()

    add_test(
        NAME "bridge.integration.execution.${NAME}"
        COMMAND
            "${CMAKE_COMMAND}"
            ${_bridge_arguments}
            -P "${CMAKE_CURRENT_SOURCE_DIR}/execution/test.cmake"
    )

    set(_bridge_labels integration)
    if (ARG_LABEL)
        list(APPEND _bridge_labels "${ARG_LABEL}")
    endif()
    set_tests_properties(
        "bridge.integration.execution.${NAME}"
        PROPERTIES
            LABELS "${_bridge_labels}"
            TIMEOUT 120
    )
    if (ARG_ANDROID_SERIAL)
        set_tests_properties(
            "bridge.integration.execution.${NAME}"
            PROPERTIES ENVIRONMENT "BRIDGE_ANDROID_SERIAL=${ARG_ANDROID_SERIAL}"
        )
    endif()
endfunction()

function(_bridge_add_android_runner_test NAME MODE)
    add_test(
        NAME "bridge.runner.android.${NAME}"
        COMMAND
            "${CMAKE_COMMAND}"
            "-DBRIDGE_ANDROID_RUNNER=${PROJECT_SOURCE_DIR}/runner/bridge-android.sh"
            "-DBRIDGE_ANDROID_RUNNER_TEST_BINARY_DIR=${CMAKE_CURRENT_BINARY_DIR}/android-runner-${NAME}"
            "-DBRIDGE_ANDROID_RUNNER_TEST_MODE=${MODE}"
            -P "${PROJECT_SOURCE_DIR}/runner/android-test.cmake"
    )
    set_tests_properties(
        "bridge.runner.android.${NAME}"
        PROPERTIES LABELS "runner;android"
    )
endfunction()

function(_bridge_add_win32_runner_test NAME MODE)
    add_test(
        NAME "bridge.runner.win32.${NAME}"
        COMMAND
            "${CMAKE_COMMAND}"
            "-DBRIDGE_RUNNER=${PROJECT_SOURCE_DIR}/runner/bridge-win32.sh"
            "-DBRIDGE_RUNNER_TEST_BINARY_DIR=${CMAKE_CURRENT_BINARY_DIR}/runner-${NAME}"
            "-DBRIDGE_RUNNER_TEST_MODE=${MODE}"
            -P "${PROJECT_SOURCE_DIR}/runner/test.cmake"
    )
    set_tests_properties(
        "bridge.runner.win32.${NAME}"
        PROPERTIES LABELS "runner;win32"
    )
endfunction()

enable_language(CXX)

add_subdirectory(canon)

_bridge_add_win32_runner_test(output output)
_bridge_add_win32_runner_test(exit-status exit)
_bridge_add_win32_runner_test(anchor-reuse anchor)

_bridge_add_android_runner_test(output output)
_bridge_add_android_runner_test(arguments arguments)
_bridge_add_android_runner_test(exit-status exit)
_bridge_add_android_runner_test(device-selection selection)

_bridge_add_execution_test(native)
_bridge_add_execution_test(
    emulated
    EMULATED
    TOOLCHAIN "${CMAKE_CURRENT_SOURCE_DIR}/execution/emulated-toolchain.cmake"
)

if (BRIDGE_WIN32_AVAILABLE)
    message(STATUS "Bridge Win32 integration tests: enabled")
    _bridge_add_execution_test(
        win32
        TOOLCHAIN "${PROJECT_SOURCE_DIR}/toolchains/bridge-win32.cmake"
        LLVM_MINGW_ROOT "${BRIDGE_LLVM_MINGW_DISCOVERED_ROOT}"
        LABEL win32
    )
else()
    message(STATUS "Bridge Win32 integration tests: disabled")
endif()

if (BRIDGE_ANDROID_NDK_AVAILABLE AND BRIDGE_ANDROID_RUNTIME_AVAILABLE)
    foreach(_bridge_android_abi IN ITEMS x86_64 arm64-v8a)
        _bridge_find_android_device(
            "${BRIDGE_ADB_EXECUTABLE}"
            "${_bridge_android_abi}"
            _bridge_android_device_available
            _bridge_android_serial
            _bridge_android_device_reason
        )
        if (_bridge_android_device_available)
            if (_bridge_android_abi STREQUAL "arm64-v8a")
                set(_bridge_android_profile arm64)
            else()
                set(_bridge_android_profile "${_bridge_android_abi}")
            endif()
            message(
                STATUS
                "Bridge Android ${_bridge_android_abi} integration tests: enabled (${_bridge_android_serial})"
            )
            _bridge_add_execution_test(
                "android-${_bridge_android_profile}"
                REMOTE
                TOOLCHAIN "${PROJECT_SOURCE_DIR}/toolchains/bridge-android.cmake"
                CMAKE_ANDROID_NDK "${BRIDGE_ANDROID_DISCOVERED_NDK_ROOT}"
                ANDROID_SDK_ROOT "${BRIDGE_ANDROID_DISCOVERED_SDK_ROOT}"
                ANDROID_ARCH_ABI "${_bridge_android_abi}"
                ANDROID_SERIAL "${_bridge_android_serial}"
                LABEL android
            )
        else()
            message(
                STATUS
                "Bridge Android ${_bridge_android_abi} integration tests: disabled"
            )
            message(STATUS "  ${_bridge_android_device_reason}")
        endif()
    endforeach()
else()
    message(STATUS "Bridge Android integration tests: disabled")
    if (NOT BRIDGE_ANDROID_NDK_AVAILABLE)
        message(STATUS "  ${BRIDGE_ANDROID_NDK_UNAVAILABLE_REASON}")
    endif()
    if (NOT BRIDGE_ANDROID_RUNTIME_AVAILABLE)
        message(STATUS "  ${BRIDGE_ANDROID_RUNTIME_UNAVAILABLE_REASON}")
    endif()
endif()
