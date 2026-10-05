# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

include_guard(GLOBAL)

include("${CMAKE_CURRENT_LIST_DIR}/BridgeAndroidEnvironment.cmake")

function(
    _bridge_find_android_packaging_environment
    OUT_AVAILABLE
    OUT_ANDROID_JAR
    OUT_TARGET_API
    OUT_AAPT2
    OUT_D8
    OUT_ZIPALIGN
    OUT_APKSIGNER
    OUT_JAVAC
    OUT_JAR
    OUT_KEYTOOL
    OUT_ZIP
    OUT_REASON
)
    foreach(_out IN ITEMS
        "${OUT_ANDROID_JAR}"
        "${OUT_TARGET_API}"
        "${OUT_AAPT2}"
        "${OUT_D8}"
        "${OUT_ZIPALIGN}"
        "${OUT_APKSIGNER}"
        "${OUT_JAVAC}"
        "${OUT_JAR}"
        "${OUT_KEYTOOL}"
        "${OUT_ZIP}"
    )
        set(${_out} "" PARENT_SCOPE)
    endforeach()
    set(${OUT_AVAILABLE} FALSE PARENT_SCOPE)
    set(${OUT_REASON} "" PARENT_SCOPE)

    _bridge_find_android_sdk_root(_sdk_root _sdk_reason)
    if (NOT "${_sdk_reason}" STREQUAL "")
        set(${OUT_REASON} "${_sdk_reason}" PARENT_SCOPE)
        return()
    endif()
    if ("${_sdk_root}" STREQUAL "")
        set(${OUT_REASON}
            "Android SDK was not found; install an SDK or set BRIDGE_ANDROID_SDK_ROOT"
            PARENT_SCOPE
        )
        return()
    endif()

    file(GLOB _platform_directories LIST_DIRECTORIES TRUE "${_sdk_root}/platforms/android-*")
    set(_android_jar "")
    set(_target_api -1)
    foreach(_platform_directory IN LISTS _platform_directories)
        cmake_path(GET _platform_directory FILENAME _platform_name)
        if (NOT _platform_name MATCHES "^android-([0-9]+)$")
            continue()
        endif()

        set(_candidate_api "${CMAKE_MATCH_1}")
        if (
            EXISTS "${_platform_directory}/android.jar"
            AND _candidate_api GREATER _target_api
        )
            set(_target_api "${_candidate_api}")
            set(_android_jar "${_platform_directory}/android.jar")
        endif()
    endforeach()
    if ("${_android_jar}" STREQUAL "")
        set(${OUT_REASON}
            "no installed Android SDK platform with android.jar was found under ${_sdk_root}/platforms"
            PARENT_SCOPE
        )
        return()
    endif()

    file(GLOB _build_tool_directories LIST_DIRECTORIES TRUE "${_sdk_root}/build-tools/*")
    set(_build_tools_root "")
    set(_build_tools_version "")
    foreach(_candidate IN LISTS _build_tool_directories)
        if (
            NOT EXISTS "${_candidate}/aapt2"
            OR NOT EXISTS "${_candidate}/d8"
            OR NOT EXISTS "${_candidate}/zipalign"
            OR NOT EXISTS "${_candidate}/apksigner"
        )
            continue()
        endif()

        cmake_path(GET _candidate FILENAME _candidate_version)
        if (
            "${_build_tools_root}" STREQUAL ""
            OR _candidate_version VERSION_GREATER _build_tools_version
        )
            set(_build_tools_root "${_candidate}")
            set(_build_tools_version "${_candidate_version}")
        endif()
    endforeach()
    if ("${_build_tools_root}" STREQUAL "")
        set(${OUT_REASON}
            "no complete Android SDK build-tools installation was found under ${_sdk_root}/build-tools; "
            "aapt2, d8, zipalign, and apksigner are required"
            PARENT_SCOPE
        )
        return()
    endif()

    find_program(_javac NAMES javac NO_CACHE NO_CMAKE_FIND_ROOT_PATH)
    find_program(_jar NAMES jar NO_CACHE NO_CMAKE_FIND_ROOT_PATH)
    find_program(_keytool NAMES keytool NO_CACHE NO_CMAKE_FIND_ROOT_PATH)
    find_program(_zip NAMES zip NO_CACHE NO_CMAKE_FIND_ROOT_PATH)

    foreach(_tool IN ITEMS javac jar keytool zip)
        if (NOT _${_tool})
            set(${OUT_REASON} "host ${_tool} executable was not found" PARENT_SCOPE)
            return()
        endif()
    endforeach()

    set(${OUT_AVAILABLE} TRUE PARENT_SCOPE)
    set(${OUT_ANDROID_JAR} "${_android_jar}" PARENT_SCOPE)
    set(${OUT_TARGET_API} "${_target_api}" PARENT_SCOPE)
    set(${OUT_AAPT2} "${_build_tools_root}/aapt2" PARENT_SCOPE)
    set(${OUT_D8} "${_build_tools_root}/d8" PARENT_SCOPE)
    set(${OUT_ZIPALIGN} "${_build_tools_root}/zipalign" PARENT_SCOPE)
    set(${OUT_APKSIGNER} "${_build_tools_root}/apksigner" PARENT_SCOPE)
    set(${OUT_JAVAC} "${_javac}" PARENT_SCOPE)
    set(${OUT_JAR} "${_jar}" PARENT_SCOPE)
    set(${OUT_KEYTOOL} "${_keytool}" PARENT_SCOPE)
    set(${OUT_ZIP} "${_zip}" PARENT_SCOPE)
    set(${OUT_REASON} "" PARENT_SCOPE)
endfunction()

function(_bridge_add_sdl_android_apk)
    set(options ALL)
    set(
        one_value_args
        TARGET
        APPLICATION_ID
        APPLICATION_NAME
        NATIVE_TARGET
        SDL_TARGET
        SDL_SOURCE_DIR
        OUTPUT
        MIN_API
    )
    cmake_parse_arguments(PARSE_ARGV 0 ARG "${options}" "${one_value_args}" "")

    foreach(_required IN ITEMS TARGET APPLICATION_ID APPLICATION_NAME NATIVE_TARGET SDL_TARGET SDL_SOURCE_DIR OUTPUT MIN_API)
        if (NOT ARG_${_required})
            message(FATAL_ERROR "_bridge_add_sdl_android_apk(): ${_required} is required")
        endif()
    endforeach()
    if (NOT ANDROID)
        message(FATAL_ERROR "_bridge_add_sdl_android_apk() requires an Android target")
    endif()
    if (NOT DEFINED CMAKE_ANDROID_ARCH_ABI OR "${CMAKE_ANDROID_ARCH_ABI}" STREQUAL "")
        message(FATAL_ERROR "_bridge_add_sdl_android_apk(): CMAKE_ANDROID_ARCH_ABI is unavailable")
    endif()
    if (NOT TARGET "${ARG_NATIVE_TARGET}")
        message(FATAL_ERROR "_bridge_add_sdl_android_apk(): native target '${ARG_NATIVE_TARGET}' does not exist")
    endif()
    if (NOT TARGET "${ARG_SDL_TARGET}")
        message(FATAL_ERROR "_bridge_add_sdl_android_apk(): SDL target '${ARG_SDL_TARGET}' does not exist")
    endif()

    set(_sdl_java_root "${ARG_SDL_SOURCE_DIR}/android-project/app/src/main/java")
    if (NOT IS_DIRECTORY "${_sdl_java_root}/org/libsdl/app")
        message(
            FATAL_ERROR
            "_bridge_add_sdl_android_apk(): SDL Android Java glue was not found under ${_sdl_java_root}"
        )
    endif()
    file(GLOB_RECURSE _sdl_java_sources CONFIGURE_DEPENDS "${_sdl_java_root}/org/libsdl/app/*.java")
    if (NOT _sdl_java_sources)
        message(FATAL_ERROR "_bridge_add_sdl_android_apk(): SDL Android Java glue is empty")
    endif()

    _bridge_find_android_packaging_environment(
        _packaging_available
        _android_jar
        _target_api
        _aapt2
        _d8
        _zipalign
        _apksigner
        _javac
        _jar
        _keytool
        _zip
        _packaging_reason
    )
    if (NOT _packaging_available)
        message(FATAL_ERROR "Bridge Android packaging is unavailable: ${_packaging_reason}")
    endif()
    if (NOT ARG_MIN_API MATCHES "^[0-9]+$")
        message(FATAL_ERROR "_bridge_add_sdl_android_apk(): MIN_API must be a numeric Android API level")
    endif()
    if (ARG_MIN_API GREATER _target_api)
        message(
            FATAL_ERROR
            "_bridge_add_sdl_android_apk(): MIN_API ${ARG_MIN_API} exceeds installed target API ${_target_api}"
        )
    endif()

    set(_package_dir "${CMAKE_CURRENT_BINARY_DIR}/${ARG_TARGET}-package")
    set(_manifest "${_package_dir}/AndroidManifest.xml")
    set(_classes_dir "${_package_dir}/classes")
    set(_classes_jar "${_package_dir}/classes.jar")
    set(_dex_dir "${_package_dir}/dex")
    set(_stage_dir "${_package_dir}/stage")
    set(_resource_apk "${_package_dir}/resources.apk")
    set(_unaligned_apk "${_package_dir}/unaligned.apk")
    set(_aligned_apk "${_package_dir}/aligned.apk")
    set(_keystore "${_package_dir}/debug.keystore")

    set(BRIDGE_ANDROID_APPLICATION_ID "${ARG_APPLICATION_ID}")
    set(BRIDGE_ANDROID_APPLICATION_NAME "${ARG_APPLICATION_NAME}")
    set(BRIDGE_ANDROID_MIN_API "${ARG_MIN_API}")
    set(BRIDGE_ANDROID_TARGET_API "${_target_api}")
    file(MAKE_DIRECTORY "${_package_dir}")
    configure_file(
        "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/BridgeAndroidManifest.xml.in"
        "${_manifest}"
        @ONLY
    )

    add_custom_command(
        OUTPUT "${_keystore}"
        COMMAND
            "${_keytool}"
            -genkeypair
            -keystore "${_keystore}"
            -storetype JKS
            -storepass android
            -keypass android
            -alias androiddebugkey
            -keyalg RSA
            -keysize 2048
            -validity 10000
            -dname "CN=Android Debug,O=Android,C=US"
            -noprompt
        VERBATIM
    )

    add_custom_command(
        OUTPUT "${ARG_OUTPUT}"
        COMMAND "${CMAKE_COMMAND}" -E rm -rf "${_classes_dir}" "${_dex_dir}" "${_stage_dir}"
        COMMAND
            "${CMAKE_COMMAND}" -E rm -f
            "${_classes_jar}"
            "${_resource_apk}"
            "${_unaligned_apk}"
            "${_aligned_apk}"
            "${ARG_OUTPUT}"
        COMMAND "${CMAKE_COMMAND}" -E make_directory "${_classes_dir}" "${_dex_dir}"
        COMMAND "${CMAKE_COMMAND}" -E make_directory "${_stage_dir}/lib/${CMAKE_ANDROID_ARCH_ABI}"
        COMMAND
            "${_javac}"
            -encoding UTF-8
            -source 8
            -target 8
            -classpath "${_android_jar}"
            -d "${_classes_dir}"
            ${_sdl_java_sources}
        COMMAND "${_jar}" cf "${_classes_jar}" -C "${_classes_dir}" .
        COMMAND
            "${_d8}"
            --lib "${_android_jar}"
            --min-api "${ARG_MIN_API}"
            --output "${_dex_dir}"
            "${_classes_jar}"
        COMMAND
            "${_aapt2}"
            link
            -o "${_resource_apk}"
            -I "${_android_jar}"
            --manifest "${_manifest}"
            --min-sdk-version "${ARG_MIN_API}"
            --target-sdk-version "${_target_api}"
        COMMAND "${CMAKE_COMMAND}" -E copy "${_resource_apk}" "${_unaligned_apk}"
        COMMAND "${CMAKE_COMMAND}" -E copy "${_dex_dir}/classes.dex" "${_stage_dir}/classes.dex"
        COMMAND
            "${CMAKE_COMMAND}" -E copy
            "$<TARGET_FILE:${ARG_SDL_TARGET}>"
            "${_stage_dir}/lib/${CMAKE_ANDROID_ARCH_ABI}/libSDL3.so"
        COMMAND
            "${CMAKE_COMMAND}" -E copy
            "$<TARGET_FILE:${ARG_NATIVE_TARGET}>"
            "${_stage_dir}/lib/${CMAKE_ANDROID_ARCH_ABI}/libmain.so"
        COMMAND
            "${CMAKE_COMMAND}" -E chdir "${_stage_dir}"
            "${_zip}" -q -0 -u "${_unaligned_apk}"
            classes.dex
            "lib/${CMAKE_ANDROID_ARCH_ABI}/libSDL3.so"
            "lib/${CMAKE_ANDROID_ARCH_ABI}/libmain.so"
        COMMAND "${_zipalign}" -P 16 -f 4 "${_unaligned_apk}" "${_aligned_apk}"
        COMMAND
            "${_apksigner}"
            sign
            --ks "${_keystore}"
            --ks-key-alias androiddebugkey
            --ks-pass pass:android
            --key-pass pass:android
            --out "${ARG_OUTPUT}"
            "${_aligned_apk}"
        COMMAND "${_apksigner}" verify "${ARG_OUTPUT}"
        DEPENDS
            "${_keystore}"
            "${_manifest}"
            ${_sdl_java_sources}
            "${ARG_NATIVE_TARGET}"
            "${ARG_SDL_TARGET}"
        VERBATIM
    )

    if(ARG_ALL)
        add_custom_target("${ARG_TARGET}" ALL DEPENDS "${ARG_OUTPUT}")
    else()
        add_custom_target("${ARG_TARGET}" DEPENDS "${ARG_OUTPUT}")
    endif()
endfunction()
