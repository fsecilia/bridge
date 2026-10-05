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

function(_bridge_android_xml_escape INPUT OUT_VALUE)
    set(_value "${INPUT}")
    string(REPLACE "&" "&amp;" _value "${_value}")
    string(REPLACE "\"" "&quot;" _value "${_value}")
    string(REPLACE "<" "&lt;" _value "${_value}")
    string(REPLACE ">" "&gt;" _value "${_value}")
    set(${OUT_VALUE} "${_value}" PARENT_SCOPE)
endfunction()

function(_bridge_android_require_shared_target TARGET_NAME ROLE OUT_TARGET)
    if(NOT TARGET "${TARGET_NAME}")
        message(FATAL_ERROR "bridge_add_sdl_android_application(): ${ROLE} target '${TARGET_NAME}' does not exist")
    endif()

    get_target_property(_aliased_target "${TARGET_NAME}" ALIASED_TARGET)
    if(_aliased_target)
        set(_target "${_aliased_target}")
    else()
        set(_target "${TARGET_NAME}")
    endif()

    get_target_property(_target_type "${_target}" TYPE)
    if(NOT _target_type STREQUAL "SHARED_LIBRARY")
        message(
            FATAL_ERROR
            "bridge_add_sdl_android_application(): ${ROLE} target '${TARGET_NAME}' must be a shared library; got ${_target_type}"
        )
    endif()

    set(${OUT_TARGET} "${_target}" PARENT_SCOPE)
endfunction()

function(bridge_add_sdl_android_application)
    set(options ALL)
    set(
        one_value_args
        TARGET
        APPLICATION_ID
        APPLICATION_NAME
        MAIN_TARGET
        SDL_TARGET
        SDL_SOURCE_DIR
        OUTPUT
        MIN_API
        VERSION_CODE
        VERSION_NAME
        ASSET_DIRECTORY
    )
    set(multi_value_args RUNTIME_TARGETS)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "${options}" "${one_value_args}" "${multi_value_args}")

    if(ARG_UNPARSED_ARGUMENTS)
        message(
            FATAL_ERROR
            "bridge_add_sdl_android_application(): unknown arguments: ${ARG_UNPARSED_ARGUMENTS}"
        )
    endif()
    if(ARG_KEYWORDS_MISSING_VALUES)
        message(
            FATAL_ERROR
            "bridge_add_sdl_android_application(): missing values for: ${ARG_KEYWORDS_MISSING_VALUES}"
        )
    endif()

    foreach(_required IN ITEMS TARGET APPLICATION_ID APPLICATION_NAME MAIN_TARGET SDL_TARGET SDL_SOURCE_DIR)
        if(NOT ARG_${_required})
            message(FATAL_ERROR "bridge_add_sdl_android_application(): ${_required} is required")
        endif()
    endforeach()
    if(TARGET "${ARG_TARGET}")
        message(FATAL_ERROR "bridge_add_sdl_android_application(): target '${ARG_TARGET}' already exists")
    endif()
    if(NOT ANDROID)
        message(FATAL_ERROR "bridge_add_sdl_android_application() requires an Android target")
    endif()
    if(NOT DEFINED CMAKE_ANDROID_ARCH_ABI OR "${CMAKE_ANDROID_ARCH_ABI}" STREQUAL "")
        message(FATAL_ERROR "bridge_add_sdl_android_application(): CMAKE_ANDROID_ARCH_ABI is unavailable")
    endif()
    if(NOT ARG_APPLICATION_ID MATCHES "^[A-Za-z][A-Za-z0-9_]*([.][A-Za-z][A-Za-z0-9_]*)+$")
        message(
            FATAL_ERROR
            "bridge_add_sdl_android_application(): APPLICATION_ID '${ARG_APPLICATION_ID}' is not a valid Android application ID"
        )
    endif()

    if(ARG_MIN_API)
        set(_min_api "${ARG_MIN_API}")
    else()
        set(_min_api "${CMAKE_SYSTEM_VERSION}")
    endif()
    if(NOT _min_api MATCHES "^[0-9]+$")
        message(
            FATAL_ERROR
            "bridge_add_sdl_android_application(): MIN_API must be a numeric Android API level; got '${_min_api}'"
        )
    endif()

    if(ARG_VERSION_CODE)
        set(_version_code "${ARG_VERSION_CODE}")
    else()
        set(_version_code 1)
    endif()
    if(NOT _version_code MATCHES "^[1-9][0-9]*$" OR _version_code GREATER 2100000000)
        message(
            FATAL_ERROR
            "bridge_add_sdl_android_application(): VERSION_CODE must be an integer from 1 through 2100000000"
        )
    endif()
    if(ARG_VERSION_NAME)
        set(_version_name "${ARG_VERSION_NAME}")
    else()
        set(_version_name "1.0")
    endif()

    _bridge_android_require_shared_target("${ARG_MAIN_TARGET}" "MAIN_TARGET" _main_target)
    _bridge_android_require_shared_target("${ARG_SDL_TARGET}" "SDL_TARGET" _sdl_target)

    set(_runtime_targets "")
    set(_seen_targets "${_main_target};${_sdl_target}")
    foreach(_runtime_target IN LISTS ARG_RUNTIME_TARGETS)
        _bridge_android_require_shared_target("${_runtime_target}" "RUNTIME_TARGETS" _resolved_runtime_target)
        list(FIND _seen_targets "${_resolved_runtime_target}" _existing_index)
        if(NOT _existing_index EQUAL -1)
            message(
                FATAL_ERROR
                "bridge_add_sdl_android_application(): runtime target '${_runtime_target}' duplicates another packaged target"
            )
        endif()
        list(APPEND _seen_targets "${_resolved_runtime_target}")
        list(APPEND _runtime_targets "${_resolved_runtime_target}")
    endforeach()

    set(_sdl_source_dir "${ARG_SDL_SOURCE_DIR}")
    cmake_path(ABSOLUTE_PATH _sdl_source_dir BASE_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}" NORMALIZE)
    set(_sdl_java_root "${_sdl_source_dir}/android-project/app/src/main/java")
    if(NOT IS_DIRECTORY "${_sdl_java_root}/org/libsdl/app")
        message(
            FATAL_ERROR
            "bridge_add_sdl_android_application(): SDL Android Java glue was not found under ${_sdl_java_root}"
        )
    endif()
    file(GLOB_RECURSE _sdl_java_sources CONFIGURE_DEPENDS "${_sdl_java_root}/org/libsdl/app/*.java")
    if(NOT _sdl_java_sources)
        message(FATAL_ERROR "bridge_add_sdl_android_application(): SDL Android Java glue is empty")
    endif()

    set(_asset_directory "")
    set(_asset_dependencies "")
    set(_asset_manifest "")
    if(ARG_ASSET_DIRECTORY)
        set(_asset_directory "${ARG_ASSET_DIRECTORY}")
        cmake_path(ABSOLUTE_PATH _asset_directory BASE_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}" NORMALIZE)
        if(NOT IS_DIRECTORY "${_asset_directory}")
            message(
                FATAL_ERROR
                "bridge_add_sdl_android_application(): ASSET_DIRECTORY is not a directory: ${_asset_directory}"
            )
        endif()
        file(
            GLOB_RECURSE _asset_relative_paths
            CONFIGURE_DEPENDS
            LIST_DIRECTORIES FALSE
            RELATIVE "${_asset_directory}"
            "${_asset_directory}/*"
        )
        foreach(_asset_relative_path IN LISTS _asset_relative_paths)
            list(APPEND _asset_dependencies "${_asset_directory}/${_asset_relative_path}")
        endforeach()
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
    if(NOT _packaging_available)
        message(FATAL_ERROR "Bridge Android packaging is unavailable: ${_packaging_reason}")
    endif()
    if(_min_api GREATER _target_api)
        message(
            FATAL_ERROR
            "bridge_add_sdl_android_application(): MIN_API ${_min_api} exceeds installed target API ${_target_api}"
        )
    endif()

    if(ARG_OUTPUT)
        set(_output "${ARG_OUTPUT}")
    else()
        set(_output "${ARG_TARGET}.apk")
    endif()
    cmake_path(ABSOLUTE_PATH _output BASE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}" NORMALIZE)
    cmake_path(GET _output PARENT_PATH _output_directory)

    set(_package_dir "${CMAKE_CURRENT_BINARY_DIR}/${ARG_TARGET}-package")
    set(_manifest "${_package_dir}/AndroidManifest.xml")
    set(_classes_dir "${_package_dir}/classes")
    set(_classes_jar "${_package_dir}/classes.jar")
    set(_dex_dir "${_package_dir}/dex")
    set(_stage_dir "${_package_dir}/stage")
    set(_stage_script "${_package_dir}/stage-$<CONFIG>.cmake")
    set(_resource_apk "${_package_dir}/resources.apk")
    set(_unaligned_apk "${_package_dir}/unaligned.apk")
    set(_aligned_apk "${_package_dir}/aligned.apk")
    set(_keystore "${_package_dir}/debug.keystore")

    _bridge_android_xml_escape("${ARG_APPLICATION_NAME}" BRIDGE_ANDROID_APPLICATION_NAME)
    _bridge_android_xml_escape("${_version_name}" BRIDGE_ANDROID_VERSION_NAME)
    set(BRIDGE_ANDROID_APPLICATION_ID "${ARG_APPLICATION_ID}")
    set(BRIDGE_ANDROID_VERSION_CODE "${_version_code}")
    set(BRIDGE_ANDROID_MIN_API "${_min_api}")
    set(BRIDGE_ANDROID_TARGET_API "${_target_api}")
    file(MAKE_DIRECTORY "${_package_dir}")
    configure_file(
        "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/BridgeAndroidManifest.xml.in"
        "${_manifest}"
        @ONLY
    )

    if(_asset_directory)
        string(JOIN "\n" _asset_manifest_content ${_asset_relative_paths})
        string(APPEND _asset_manifest_content "\n")
        set(_asset_manifest "${_package_dir}/assets.list")
        file(GENERATE OUTPUT "${_asset_manifest}" CONTENT "${_asset_manifest_content}")
    endif()

    set(_stage_script_content [=[
cmake_minimum_required(VERSION 3.31.6)

if(NOT DEFINED BRIDGE_STAGE_DIR OR "${BRIDGE_STAGE_DIR}" STREQUAL "")
    message(FATAL_ERROR "BRIDGE_STAGE_DIR is required")
endif()
if(NOT DEFINED BRIDGE_ANDROID_ABI OR "${BRIDGE_ANDROID_ABI}" STREQUAL "")
    message(FATAL_ERROR "BRIDGE_ANDROID_ABI is required")
endif()
if(NOT DEFINED BRIDGE_CLASSES_DEX OR "${BRIDGE_CLASSES_DEX}" STREQUAL "")
    message(FATAL_ERROR "BRIDGE_CLASSES_DEX is required")
endif()

file(REMOVE_RECURSE "${BRIDGE_STAGE_DIR}")
file(MAKE_DIRECTORY "${BRIDGE_STAGE_DIR}/lib/${BRIDGE_ANDROID_ABI}")
file(COPY_FILE "${BRIDGE_CLASSES_DEX}" "${BRIDGE_STAGE_DIR}/classes.dex" ONLY_IF_DIFFERENT)

function(_bridge_stage_library SOURCE NAME)
    if(NOT EXISTS "${SOURCE}")
        message(FATAL_ERROR "Android runtime library does not exist: ${SOURCE}")
    endif()

    set(_destination "${BRIDGE_STAGE_DIR}/lib/${BRIDGE_ANDROID_ABI}/${NAME}")
    if(EXISTS "${_destination}")
        message(FATAL_ERROR "Android runtime library name collision: ${NAME}")
    endif()
    file(COPY_FILE "${SOURCE}" "${_destination}" ONLY_IF_DIFFERENT)
endfunction()
]=])
    string(APPEND _stage_script_content
        "\n_bridge_stage_library([==[$<TARGET_FILE:${_main_target}>]==] \"libmain.so\")\n"
        "_bridge_stage_library([==[$<TARGET_FILE:${_sdl_target}>]==] \"libSDL3.so\")\n"
    )
    foreach(_runtime_target IN LISTS _runtime_targets)
        string(APPEND _stage_script_content
            "_bridge_stage_library([==[$<TARGET_FILE:${_runtime_target}>]==] [==[$<TARGET_FILE_NAME:${_runtime_target}>]==])\n"
        )
    endforeach()
    if(_asset_directory)
        string(APPEND _stage_script_content
            "file(MAKE_DIRECTORY \"\${BRIDGE_STAGE_DIR}/assets\")\n"
            "file(COPY [==[${_asset_directory}/]==] DESTINATION \"\${BRIDGE_STAGE_DIR}/assets\")\n"
        )
    endif()
    file(GENERATE OUTPUT "${_stage_script}" CONTENT "${_stage_script_content}")

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
        OUTPUT "${_output}"
        COMMAND "${CMAKE_COMMAND}" -E rm -rf "${_classes_dir}" "${_dex_dir}"
        COMMAND "${CMAKE_COMMAND}" -E make_directory "${_output_directory}"
        COMMAND
            "${CMAKE_COMMAND}" -E rm -f
            "${_classes_jar}"
            "${_resource_apk}"
            "${_unaligned_apk}"
            "${_aligned_apk}"
            "${_output}"
        COMMAND "${CMAKE_COMMAND}" -E make_directory "${_classes_dir}" "${_dex_dir}"
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
            --min-api "${_min_api}"
            --output "${_dex_dir}"
            "${_classes_jar}"
        COMMAND
            "${_aapt2}"
            link
            -o "${_resource_apk}"
            -I "${_android_jar}"
            --manifest "${_manifest}"
            --min-sdk-version "${_min_api}"
            --target-sdk-version "${_target_api}"
        COMMAND "${CMAKE_COMMAND}" -E copy "${_resource_apk}" "${_unaligned_apk}"
        COMMAND
            "${CMAKE_COMMAND}"
            "-DBRIDGE_STAGE_DIR=${_stage_dir}"
            "-DBRIDGE_ANDROID_ABI=${CMAKE_ANDROID_ARCH_ABI}"
            "-DBRIDGE_CLASSES_DEX=${_dex_dir}/classes.dex"
            -P "${_stage_script}"
        COMMAND
            "${CMAKE_COMMAND}" -E chdir "${_stage_dir}"
            "${_zip}" -q -0 -r -u "${_unaligned_apk}" .
        COMMAND "${_zipalign}" -P 16 -f 4 "${_unaligned_apk}" "${_aligned_apk}"
        COMMAND
            "${_apksigner}"
            sign
            --ks "${_keystore}"
            --ks-key-alias androiddebugkey
            --ks-pass pass:android
            --key-pass pass:android
            --out "${_output}"
            "${_aligned_apk}"
        COMMAND "${_apksigner}" verify "${_output}"
        DEPENDS
            "${_keystore}"
            "${_manifest}"
            "${_stage_script}"
            ${_asset_manifest}
            ${_asset_dependencies}
            ${_sdl_java_sources}
            "${_main_target}"
            "${_sdl_target}"
            ${_runtime_targets}
        VERBATIM
    )

    if(ARG_ALL)
        add_custom_target("${ARG_TARGET}" ALL DEPENDS "${_output}")
    else()
        add_custom_target("${ARG_TARGET}" DEPENDS "${_output}")
    endif()
    set_property(TARGET "${ARG_TARGET}" PROPERTY BRIDGE_ANDROID_APK "${_output}")
    set_property(TARGET "${ARG_TARGET}" PROPERTY BRIDGE_ANDROID_APPLICATION_ID "${ARG_APPLICATION_ID}")
endfunction()
