# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

include("${PROJECT_SOURCE_DIR}/cmake/BridgeAndroidPackaging.cmake")

set(BRIDGE_SDL_SOURCE_DIR "" CACHE PATH "SDL source tree used by Bridge Android graphics integration tests")
if (NOT "${BRIDGE_SDL_SOURCE_DIR}" STREQUAL "")
    if (NOT EXISTS "${BRIDGE_SDL_SOURCE_DIR}/CMakeLists.txt")
        message(FATAL_ERROR "BRIDGE_SDL_SOURCE_DIR is not an SDL source tree: ${BRIDGE_SDL_SOURCE_DIR}")
    endif()
    set(_bridge_sdl_source_dir "${BRIDGE_SDL_SOURCE_DIR}")
elseif (EXISTS "${PROJECT_SOURCE_DIR}/external/sdl3/CMakeLists.txt")
    set(_bridge_sdl_source_dir "${PROJECT_SOURCE_DIR}/external/sdl3")
else()
    set(_bridge_sdl_source_dir "")
endif()

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


function(_bridge_add_android_graphics_test NAME)
    set(one_value_args APK ANDROID_SERIAL)
    cmake_parse_arguments(PARSE_ARGV 1 ARG "" "${one_value_args}" "")

    foreach(_required IN ITEMS APK ANDROID_SERIAL)
        if(NOT ARG_${_required})
            message(FATAL_ERROR "_bridge_add_android_graphics_test(): ${_required} is required")
        endif()
    endforeach()

    add_test(
        NAME "bridge.integration.graphics.${NAME}"
        COMMAND
            "${CMAKE_COMMAND}"
            "-DBRIDGE_APK=${ARG_APK}"
            "-DBRIDGE_ADB_EXECUTABLE=${BRIDGE_ADB_EXECUTABLE}"
            "-DBRIDGE_ANDROID_SERIAL=${ARG_ANDROID_SERIAL}"
            -P "${CMAKE_CURRENT_SOURCE_DIR}/android-graphics/test.cmake"
    )
    set_tests_properties(
        "bridge.integration.graphics.${NAME}"
        PROPERTIES
            LABELS "integration;android;graphics"
            TIMEOUT 120
    )
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

if(ANDROID AND CMAKE_ANDROID_ARCH_ABI STREQUAL "x86_64")
    _bridge_find_android_packaging_environment(
        _bridge_android_packaging_available
        _bridge_android_jar
        _bridge_android_target_api
        _bridge_aapt2
        _bridge_d8
        _bridge_zipalign
        _bridge_apksigner
        _bridge_javac
        _bridge_jar
        _bridge_keytool
        _bridge_zip
        _bridge_android_packaging_reason
    )

    if(_bridge_android_packaging_available AND NOT "${_bridge_sdl_source_dir}" STREQUAL "")
        message(STATUS "Bridge Android graphics APK: enabled")
        set(BRIDGE_ANDROID_GRAPHICS_SDL_SOURCE_DIR "${_bridge_sdl_source_dir}")
        add_subdirectory(android-graphics)

        if(BRIDGE_ANDROID_RUNTIME_AVAILABLE)
            _bridge_find_android_device(
                "${BRIDGE_ADB_EXECUTABLE}"
                x86_64
                _bridge_android_graphics_device_available
                _bridge_android_graphics_serial
                _bridge_android_graphics_device_reason
            )
        else()
            set(_bridge_android_graphics_device_available FALSE)
            set(_bridge_android_graphics_device_reason "${BRIDGE_ANDROID_RUNTIME_UNAVAILABLE_REASON}")
        endif()

        if(_bridge_android_graphics_device_available)
            message(
                STATUS
                "Bridge Android graphics integration test: enabled (${_bridge_android_graphics_serial})"
            )
            _bridge_add_android_graphics_test(
                android-x86_64
                APK "${BRIDGE_ANDROID_GRAPHICS_APK}"
                ANDROID_SERIAL "${_bridge_android_graphics_serial}"
            )
        else()
            message(STATUS "Bridge Android graphics integration test: disabled")
            message(STATUS "  ${_bridge_android_graphics_device_reason}")
        endif()
    else()
        message(STATUS "Bridge Android graphics APK: disabled")
        if(NOT _bridge_android_packaging_available)
            message(STATUS "  ${_bridge_android_packaging_reason}")
        endif()
        if("${_bridge_sdl_source_dir}" STREQUAL "")
            message(
                STATUS
                "  SDL source tree not found; set BRIDGE_SDL_SOURCE_DIR or place SDL under external/sdl3"
            )
        endif()
        message(STATUS "Bridge Android graphics integration test: disabled")
    endif()
endif()
