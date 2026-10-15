# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

include("${PROJECT_SOURCE_DIR}/cmake/BridgeAndroidPackaging.cmake")

# Canon resolves Bridge's optional SDL test dependency from external/sdl3.
# The Android APK also requires SDL Java sources, so the test needs the subtree.
set(_bridge_sdl_source_dir "${PROJECT_SOURCE_DIR}/external/sdl3")
if(DEFINED BRIDGE_SDL_SOURCE_DIR AND NOT "${BRIDGE_SDL_SOURCE_DIR}" STREQUAL "")
    message(FATAL_ERROR
        "BRIDGE_SDL_SOURCE_DIR is no longer supported; initialize the SDL "
        "submodule at ${_bridge_sdl_source_dir}"
    )
endif()

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

function(_bridge_add_android_app_runner_test NAME MODE)
    add_test(
        NAME "bridge.runner.android-app.${NAME}"
        COMMAND
            "${CMAKE_COMMAND}"
            "-DBRIDGE_ANDROID_APP_RUNNER=${PROJECT_SOURCE_DIR}/runner/bridge-android-app.sh"
            "-DBRIDGE_ANDROID_APP_RUNNER_TEST_BINARY_DIR=${CMAKE_CURRENT_BINARY_DIR}/android-app-runner-${NAME}"
            "-DBRIDGE_ANDROID_APP_RUNNER_TEST_MODE=${MODE}"
            -P "${PROJECT_SOURCE_DIR}/runner/android-app-test.cmake"
    )
    set_tests_properties(
        "bridge.runner.android-app.${NAME}"
        PROPERTIES LABELS "runner;android"
    )
endfunction()

function(_bridge_add_android_activity_runner_test NAME MODE)
    add_test(
        NAME "bridge.runner.android-activity.${NAME}"
        COMMAND "${CMAKE_COMMAND}"
            "-DBRIDGE_ANDROID_ACTIVITY_RUNNER=${PROJECT_SOURCE_DIR}/runner/bridge-android-activity-test.sh"
            "-DBRIDGE_ACTIVITY_TEST_BINARY_DIR=${CMAKE_CURRENT_BINARY_DIR}/android-activity-${NAME}"
            "-DBRIDGE_ACTIVITY_TEST_MODE=${MODE}"
            -P "${PROJECT_SOURCE_DIR}/runner/android-activity-test.cmake"
    )
    set_tests_properties("bridge.runner.android-activity.${NAME}" PROPERTIES LABELS "runner;android")
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

function(_bridge_add_execution_specimen PROFILE)
    set(options REMOTE)
    set(one_value_args ANDROID_SERIAL)
    cmake_parse_arguments(PARSE_ARGV 1 ARG "${options}" "${one_value_args}" "")

    set(BRIDGE_EXECUTION_PROFILE "${PROFILE}")
    set(BRIDGE_EXPECT_TEST_EMULATOR FALSE)
    if(ARG_REMOTE)
        set(BRIDGE_REMOTE_EXECUTION TRUE)
    else()
        set(BRIDGE_REMOTE_EXECUTION FALSE)
    endif()
    set(BRIDGE_EXECUTION_ANDROID_SERIAL "${ARG_ANDROID_SERIAL}")
    add_subdirectory(execution)
endfunction()

function(_bridge_add_emulated_execution_specimen)
    # This probe needs a second toolchain context. Build that tree from the
    # normal build graph so CTest only executes already-built artifacts.
    set(_bridge_binary_dir "${CMAKE_CURRENT_BINARY_DIR}/execution-emulated")
    set(_bridge_configure_command
        "${CMAKE_COMMAND}"
        -S "${CMAKE_CURRENT_SOURCE_DIR}/execution"
        -B "${_bridge_binary_dir}"
        -G "${CMAKE_GENERATOR}"
        "--toolchain=${CMAKE_CURRENT_SOURCE_DIR}/execution/emulated-toolchain.cmake"
        "-DBRIDGE_EXECUTION_PROFILE=emulated"
        "-DBRIDGE_EXPECT_TEST_EMULATOR=TRUE"
        "-DBRIDGE_REMOTE_EXECUTION=FALSE"
        "-DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}"
    )
    if(NOT "${CMAKE_BUILD_TYPE}" STREQUAL "")
        list(APPEND _bridge_configure_command "-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}")
    endif()

    get_property(_bridge_multi_config GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
    if(_bridge_multi_config)
        set(_bridge_build_config --config "$<CONFIG>")
    else()
        set(_bridge_build_config)
    endif()

    add_custom_target(
        bridge_execution_emulated ALL
        COMMAND ${_bridge_configure_command}
        COMMAND "${CMAKE_COMMAND}" --build "${_bridge_binary_dir}" ${_bridge_build_config}
        COMMENT "Building Bridge synthetic cross-execution specimen"
        VERBATIM
    )

    add_test(
        NAME bridge.integration.execution.emulated
        COMMAND
            "${CMAKE_COMMAND}"
            "-DBRIDGE_EMULATED_BINARY_DIR=${_bridge_binary_dir}"
            "-DBRIDGE_EMULATED_CONFIG=$<CONFIG>"
            -P "${CMAKE_CURRENT_SOURCE_DIR}/execution/verify-emulated.cmake"
    )
    set_tests_properties(
        bridge.integration.execution.emulated
        PROPERTIES
            LABELS "integration;execution;emulated"
            TIMEOUT 120
    )
endfunction()

enable_language(CXX)

if(WIN32)
    add_subdirectory(win32-runtime)
endif()

add_subdirectory(canon)
add_subdirectory(native-test)

_bridge_add_win32_runner_test(output output)
_bridge_add_win32_runner_test(exit-status exit)
_bridge_add_win32_runner_test(anchor-reuse anchor)

# The Wayland selection tests use a real Unix-domain socket inode. Build the
# fixture in the native Linux graph, never from inside CTest.
if(CMAKE_HOST_SYSTEM_NAME STREQUAL "Linux" AND NOT CMAKE_CROSSCOMPILING)
    add_executable(bridge_win32_wayland_socket_fixture win32-wayland-socket.cpp)
    target_compile_features(bridge_win32_wayland_socket_fixture PRIVATE cxx_std_26)

    function(_bridge_add_win32_wayland_runner_test NAME MODE)
        add_test(
            NAME "bridge.runner.win32.${NAME}"
            COMMAND
                "${CMAKE_COMMAND}"
                "-DBRIDGE_RUNNER=${PROJECT_SOURCE_DIR}/runner/bridge-win32.sh"
                "-DBRIDGE_RUNNER_TEST_BINARY_DIR=${CMAKE_CURRENT_BINARY_DIR}/runner-${NAME}"
                "-DBRIDGE_RUNNER_TEST_MODE=${MODE}"
                "-DBRIDGE_RUNNER_TEST_SOCKET_FIXTURE=$<TARGET_FILE:bridge_win32_wayland_socket_fixture>"
                -P "${PROJECT_SOURCE_DIR}/runner/test.cmake"
        )
        set_tests_properties(
            "bridge.runner.win32.${NAME}"
            PROPERTIES LABELS "runner;win32;wayland"
        )
    endfunction()

    _bridge_add_win32_wayland_runner_test(wayland wayland)
    _bridge_add_win32_wayland_runner_test(wayland-absolute wayland-absolute)
    _bridge_add_win32_wayland_runner_test(wayland-native-only wayland-native-only)
    _bridge_add_win32_wayland_runner_test(wayland-unavailable wayland-unavailable)
    _bridge_add_win32_wayland_runner_test(wayland-missing-runtime wayland-missing-runtime)
    _bridge_add_win32_wayland_runner_test(wayland-unavailable-no-x11 wayland-unavailable-no-x11)
endif()

_bridge_add_android_runner_test(output output)
_bridge_add_android_runner_test(arguments arguments)
_bridge_add_android_runner_test(exit-status exit)
_bridge_add_android_runner_test(device-selection selection)
_bridge_add_android_runner_test(staging staging)

foreach(_mode IN ITEMS pass fail no-start duplicate timeout install-failure)
    _bridge_add_android_activity_runner_test("${_mode}" "${_mode}")
endforeach()

_bridge_add_android_app_runner_test(run run)
_bridge_add_android_app_runner_test(install-failure install-failure)
_bridge_add_android_app_runner_test(device-selection selection)

if(ANDROID)
    if(BRIDGE_ANDROID_RUNTIME_AVAILABLE)
        _bridge_find_android_device(
            "${BRIDGE_ADB_EXECUTABLE}"
            "${CMAKE_ANDROID_ARCH_ABI}"
            _bridge_android_execution_available
            _bridge_android_execution_serial
            _bridge_android_execution_reason
        )
    else()
        set(_bridge_android_execution_available FALSE)
        set(_bridge_android_execution_reason "${BRIDGE_ANDROID_RUNTIME_UNAVAILABLE_REASON}")
    endif()

    if(_bridge_android_execution_available)
        if(CMAKE_ANDROID_ARCH_ABI STREQUAL "arm64-v8a")
            set(_bridge_android_execution_profile arm64)
        else()
            set(_bridge_android_execution_profile "${CMAKE_ANDROID_ARCH_ABI}")
        endif()
        message(
            STATUS
            "Bridge Android ${CMAKE_ANDROID_ARCH_ABI} execution integration: enabled "
            "(${_bridge_android_execution_serial})"
        )
        _bridge_add_execution_specimen(
            "android-${_bridge_android_execution_profile}"
            REMOTE
            ANDROID_SERIAL "${_bridge_android_execution_serial}"
        )
    else()
        message(
            STATUS
            "Bridge Android ${CMAKE_ANDROID_ARCH_ABI} execution integration: disabled"
        )
        message(STATUS "  ${_bridge_android_execution_reason}")
    endif()
elseif(WIN32 AND CMAKE_CROSSCOMPILING)
    message(STATUS "Bridge Win32 execution integration: enabled")
    _bridge_add_execution_specimen(win32)
elseif(CMAKE_CROSSCOMPILING)
    message(
        STATUS
        "Bridge execution integration: disabled for unsupported cross target ${CMAKE_SYSTEM_NAME}"
    )
else()
    message(STATUS "Bridge native execution integration: enabled")
    _bridge_add_execution_specimen(native)
    _bridge_add_emulated_execution_specimen()
endif()

if(ANDROID AND CMAKE_ANDROID_ARCH_ABI MATCHES "^(x86_64|arm64-v8a)$")
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

    if(_bridge_android_packaging_available AND EXISTS "${_bridge_sdl_source_dir}/CMakeLists.txt")
        message(STATUS "Bridge Android graphics APK: enabled")
        set(BRIDGE_ANDROID_GRAPHICS_SDL_SOURCE_DIR "${_bridge_sdl_source_dir}")
        add_subdirectory(android-graphics)

        if(BRIDGE_ANDROID_RUNTIME_AVAILABLE)
            _bridge_find_android_device(
                "${BRIDGE_ADB_EXECUTABLE}"
                "${CMAKE_ANDROID_ARCH_ABI}"
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
            if(CMAKE_ANDROID_ARCH_ABI STREQUAL "arm64-v8a")
                set(_bridge_android_graphics_profile arm64)
            else()
                set(_bridge_android_graphics_profile "${CMAKE_ANDROID_ARCH_ABI}")
            endif()
            _bridge_add_android_graphics_test(
                "android-${_bridge_android_graphics_profile}"
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
        if(NOT EXISTS "${_bridge_sdl_source_dir}/CMakeLists.txt")
            message(STATUS "  SDL source tree not found at ${_bridge_sdl_source_dir}; initialize its submodule")
        endif()
        message(STATUS "Bridge Android graphics integration test: disabled")
    endif()
endif()

# Host-only icon validation and packaging checks do not need platform SDKs.
find_package(Python3 COMPONENTS Interpreter QUIET)
if(Python3_Interpreter_FOUND)
    add_test(
        NAME bridge.icons.packaging
        COMMAND "${Python3_EXECUTABLE}" "${CMAKE_CURRENT_SOURCE_DIR}/icons/test_icons.py"
    )
    set_tests_properties(bridge.icons.packaging PROPERTIES LABELS "icons;packaging")
else()
    message(WARNING "Bridge icon packaging tests unavailable: host Python 3 was not found")
endif()

# Platform-neutral applications. The desktop fixture builds and runs real
# programs; Android applications are APKs, which the graphics test covers.
if(NOT ANDROID)
    if(Python3_Interpreter_FOUND)
        add_subdirectory(application)
    else()
        message(WARNING "Bridge application tests unavailable: host Python 3 was not found for icon fixtures")
    endif()
endif()

# Configures a fixture that must fail. Argument checks do not depend on the
# target, so fixtures configure for the host by default and need no compiler.
# TARGET_PLATFORM fixtures configure with this build's toolchain and compiler,
# for checks that only exist on the target platform.
function(_bridge_add_configure_failure_test NAME EXPECTED_ERROR)
    cmake_parse_arguments(PARSE_ARGV 2 ARG "TARGET_PLATFORM" "" "")
    set(_platform_arguments "")
    if(ARG_TARGET_PLATFORM)
        set(_platform_arguments
            "-DBRIDGE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}"
            "-DBRIDGE_CXX_COMPILER=${CMAKE_CXX_COMPILER}"
        )
    endif()
    add_test(
        NAME "bridge.application.errors.${NAME}"
        COMMAND
            "${CMAKE_COMMAND}"
            "-DBRIDGE_SOURCE_DIR=${PROJECT_SOURCE_DIR}"
            "-DBRIDGE_FIXTURE=${CMAKE_CURRENT_SOURCE_DIR}/application/errors/${NAME}"
            "-DBRIDGE_TEST_BINARY_DIR=${CMAKE_CURRENT_BINARY_DIR}/application-errors/${NAME}"
            "-DBRIDGE_GENERATOR=${CMAKE_GENERATOR}"
            "-DBRIDGE_MAKE_PROGRAM=${CMAKE_MAKE_PROGRAM}"
            ${_platform_arguments}
            "-DBRIDGE_EXPECTED_ERROR=${EXPECTED_ERROR}"
            -P "${CMAKE_CURRENT_SOURCE_DIR}/application/configure-failure.cmake"
    )
    set_tests_properties("bridge.application.errors.${NAME}" PROPERTIES LABELS "application;configure")
endfunction()

_bridge_add_configure_failure_test(
    icon-color
    "bridge_add_sdl_application(): ICON_DIRECTORY requires ADAPTIVE_ICON_BACKGROUND_COLOR"
)
_bridge_add_configure_failure_test(
    main-static
    "MAIN_TARGET 'game_main' must be a shared library on every platform"
)
_bridge_add_configure_failure_test(
    missing-canon
    "bridge_add_sdl_application(): load Canon first"
)
if(NOT ANDROID)
    _bridge_add_configure_failure_test(
        shared-directory
        "'second' shares output directory"
        TARGET_PLATFORM
    )
endif()
if(WIN32)
    _bridge_add_configure_failure_test(
        win32-icon-in-function
        "RC is not enabled, and it cannot be enabled from inside add_icon()"
        TARGET_PLATFORM
    )
endif()
