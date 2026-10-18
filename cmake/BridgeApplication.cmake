# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

include_guard(GLOBAL)

# Platform-neutral application targets. Each function chooses the Android,
# Windows, or host implementation, so consumers do not branch on the platform.
include("${CMAKE_CURRENT_LIST_DIR}/BridgeAndroidPackaging.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/BridgeAndroidRun.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/BridgeApplicationIcons.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/BridgeWin32Run.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/BridgeWin32Runtime.cmake")

# Fails on arguments cmake_parse_arguments() could not assign and on missing
# required keywords. Reads the caller's ARG_* variables.
function(_bridge_check_arguments FUNCTION)
    if(ARG_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "${FUNCTION}(): unknown arguments: ${ARG_UNPARSED_ARGUMENTS}")
    endif()
    if(ARG_KEYWORDS_MISSING_VALUES)
        message(FATAL_ERROR "${FUNCTION}(): missing values for: ${ARG_KEYWORDS_MISSING_VALUES}")
    endif()
    foreach(_required IN LISTS ARGN)
        if(NOT ARG_${_required})
            message(FATAL_ERROR "${FUNCTION}(): ${_required} is required")
        endif()
    endforeach()
endfunction()

# Fails unless TARGET names an executable target.
function(_bridge_require_executable FUNCTION ROLE TARGET)
    if(NOT TARGET "${TARGET}")
        message(FATAL_ERROR "${FUNCTION}(): ${ROLE} '${TARGET}' does not exist")
    endif()
    get_target_property(_type "${TARGET}" TYPE)
    if(NOT _type STREQUAL "EXECUTABLE")
        message(FATAL_ERROR "${FUNCTION}(): ${ROLE} '${TARGET}' must be an executable")
    endif()
endfunction()

# Makes a desktop executable runnable from the build tree. On Windows, its DLLs
# and compiler runtime are staged beside it. ASSET_DIRECTORY's contents are
# staged beside it, and ICON_DIRECTORY is staged as icons/ beside it: the same
# layout bridge_install_linux_desktop_application() installs.
#
# Executables that share an output directory share one staging target, named
# <first target>_runtime_assets, so the build never copies into one directory
# concurrently. Every executable in the directory depends on it, and it stages
# everything any of them requested. Files removed from a source directory are
# removed from the staged copy on the next build; nothing else there is touched. Each place it fills (the directory itself,
# and icons/) comes from one source directory; requesting a different one for
# the same place is an error. The output directory is identified by the
# RUNTIME_OUTPUT_DIRECTORY property, or by the target's binary directory when
# that property is unset.
#
#   bridge_stage_runtime(TARGET <executable> [ASSET_DIRECTORY <dir>] [ICON_DIRECTORY <dir>])
function(bridge_stage_runtime)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "" "TARGET;ASSET_DIRECTORY;ICON_DIRECTORY" "")
    _bridge_check_arguments(bridge_stage_runtime TARGET)
    if(ANDROID)
        message(
            FATAL_ERROR
            "bridge_stage_runtime(): Android executables run through bridge_add_native_test() "
            "or ship in an APK through bridge_add_sdl_application()"
        )
    endif()
    _bridge_require_executable(bridge_stage_runtime TARGET "${ARG_TARGET}")

    if(WIN32)
        bridge_stage_win32_runtime(TARGET "${ARG_TARGET}")
    endif()
    if(NOT ARG_ASSET_DIRECTORY AND NOT ARG_ICON_DIRECTORY)
        return()
    endif()

    get_target_property(_output_directory "${ARG_TARGET}" RUNTIME_OUTPUT_DIRECTORY)
    if(NOT _output_directory)
        get_target_property(_output_directory "${ARG_TARGET}" BINARY_DIR)
    endif()
    string(SHA256 _key "${_output_directory}")
    set(_target_property "_BRIDGE_RUNTIME_STAGING_TARGET_${_key}")
    get_property(_staging_target GLOBAL PROPERTY "${_target_property}")
    if(NOT _staging_target)
        # The first executable stands for the directory. Its file directory also
        # carries the per-configuration subdirectory of multi-config generators.
        set(_staging_target "${ARG_TARGET}_runtime_assets")
        add_custom_target("${_staging_target}" COMMENT "Staging runtime assets beside ${ARG_TARGET}" VERBATIM)
        set_property(GLOBAL PROPERTY "${_target_property}" "${_staging_target}")
        set_property(GLOBAL PROPERTY "_BRIDGE_RUNTIME_STAGING_DESTINATION_${_key}" "$<TARGET_FILE_DIR:${ARG_TARGET}>")
        set_property(
            GLOBAL PROPERTY "_BRIDGE_RUNTIME_STAGING_MANIFESTS_${_key}" "${CMAKE_CURRENT_BINARY_DIR}/${_staging_target}"
        )
    endif()
    get_property(_destination GLOBAL PROPERTY "_BRIDGE_RUNTIME_STAGING_DESTINATION_${_key}")
    get_property(_manifests GLOBAL PROPERTY "_BRIDGE_RUNTIME_STAGING_MANIFESTS_${_key}")

    foreach(_place IN ITEMS ASSET_DIRECTORY ICON_DIRECTORY)
        if(NOT ARG_${_place})
            continue()
        endif()
        set(_source "${ARG_${_place}}")
        cmake_path(ABSOLUTE_PATH _source BASE_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}" NORMALIZE)
        set(_source_property "_BRIDGE_RUNTIME_STAGING_${_place}_${_key}")
        get_property(_staged_source GLOBAL PROPERTY "${_source_property}")
        if(_staged_source)
            if(NOT "${_staged_source}" STREQUAL "${_source}")
                message(
                    FATAL_ERROR
                    "bridge_stage_runtime(): '${ARG_TARGET}' shares output directory ${_output_directory} "
                    "with '${_staging_target}', which already stages ${_place} from ${_staged_source}; "
                    "'${ARG_TARGET}' requested ${_source}"
                )
            endif()
            continue()
        endif()

        if(_place STREQUAL "ASSET_DIRECTORY")
            if(NOT IS_DIRECTORY "${_source}")
                message(FATAL_ERROR "bridge_stage_runtime(): ASSET_DIRECTORY is not a directory: ${_source}")
            endif()
            set(_place_destination "${_destination}")
        else()
            _bridge_validate_icon_directory("${_source}" _source _python _icon_files)
            set(_place_destination "${_destination}/icons")
        endif()
        # A manifest per place and configuration lets the copy remove files
        # that were staged before but have since left the source directory.
        add_custom_command(
            TARGET "${_staging_target}" POST_BUILD
            COMMAND
                "${CMAKE_COMMAND}"
                "-DSOURCE=${_source}"
                "-DDESTINATION=${_place_destination}"
                "-DMANIFEST=${_manifests}/${_place}-$<CONFIG>.manifest"
                -P "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/../scripts/bridge_stage_directory.cmake"
            VERBATIM
        )
        set_property(GLOBAL PROPERTY "${_source_property}" "${_source}")
    endforeach()
    add_dependencies("${ARG_TARGET}" "${_staging_target}")
endfunction()

# Adds a target that builds an application and starts it on the target
# platform: it installs and launches an APK on Android, runs an executable under
# Bridge's Wine runner on Windows, and runs it directly on the host otherwise.
#
#   bridge_add_run_target(TARGET <name> APPLICATION_TARGET <application>)
function(bridge_add_run_target)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "" "TARGET;APPLICATION_TARGET" "")
    _bridge_check_arguments(bridge_add_run_target TARGET APPLICATION_TARGET)

    if(ANDROID)
        bridge_add_android_run_target(TARGET "${ARG_TARGET}" APPLICATION_TARGET "${ARG_APPLICATION_TARGET}")
        return()
    endif()
    if(WIN32)
        bridge_add_win32_run_target(TARGET "${ARG_TARGET}" APPLICATION_TARGET "${ARG_APPLICATION_TARGET}")
        return()
    endif()
    if(NOT CMAKE_SYSTEM_NAME STREQUAL CMAKE_HOST_SYSTEM_NAME)
        message(FATAL_ERROR "bridge_add_run_target(): Bridge cannot run ${CMAKE_SYSTEM_NAME} programs on this host")
    endif()
    if(TARGET "${ARG_TARGET}")
        message(FATAL_ERROR "bridge_add_run_target(): target '${ARG_TARGET}' already exists")
    endif()
    _bridge_require_executable(bridge_add_run_target APPLICATION_TARGET "${ARG_APPLICATION_TARGET}")
    add_custom_target(
        "${ARG_TARGET}"
        COMMAND "$<TARGET_FILE:${ARG_APPLICATION_TARGET}>"
        DEPENDS "${ARG_APPLICATION_TARGET}"
        COMMENT "Running ${ARG_APPLICATION_TARGET}"
        USES_TERMINAL
        VERBATIM
    )
endfunction()

# Turns a shared library that exports an SDL entry point into the application
# TARGET, and adds RUN_TARGET to build and start it.
#
# On Android, TARGET packages MAIN_TARGET as an APK through bridge_add_sdl_android_application().
# ALL, OUTPUT, VERSION_NAME, VERSION_CODE, MIN_API, and DEBUGGABLE apply only there.
# DEBUGGABLE is opt-in, including for optimized Release builds; never enable it implicitly.
#
# Elsewhere, TARGET is an executable built from LAUNCHER_SOURCES, a main() that
# forwards to MAIN_TARGET, linked with MAIN_TARGET and SDL_TARGET under Canon's
# build policy. bridge_stage_runtime() makes it runnable from the build tree.
#
# ICON_DIRECTORY adds the application icon: launcher resources in the APK, an
# embedded resource on Windows, and an installed desktop entry with
# DESKTOP_CATEGORIES on Linux. Its arguments are validated on every platform,
# so a project that configures on one platform does not fail later on another.
#
# RUNTIME_TARGETS lists additional shared libraries the application loads. They
# ship in the APK and are installed with the Linux desktop application.
#
#   bridge_add_sdl_application(
#       TARGET <name> RUN_TARGET <name> MAIN_TARGET <library>
#       LAUNCHER_SOURCES <source>... SDL_TARGET <target> SDL_SOURCE_DIR <dir>
#       APPLICATION_ID <id> APPLICATION_NAME <name>
#       [ALL] [DEBUGGABLE] [OUTPUT <apk>] [VERSION_NAME <name>] [VERSION_CODE <code>] [MIN_API <level>]
#       [ASSET_DIRECTORY <dir>] [RUNTIME_TARGETS <library>...]
#       [ICON_DIRECTORY <dir> ADAPTIVE_ICON_BACKGROUND_COLOR <color> [DESKTOP_CATEGORIES <categories>]])
function(bridge_add_sdl_application)
    set(one_value_args
        TARGET
        RUN_TARGET
        MAIN_TARGET
        SDL_TARGET
        SDL_SOURCE_DIR
        APPLICATION_ID
        APPLICATION_NAME
        OUTPUT
        VERSION_NAME
        VERSION_CODE
        MIN_API
        ASSET_DIRECTORY
        ICON_DIRECTORY
        ADAPTIVE_ICON_BACKGROUND_COLOR
        DESKTOP_CATEGORIES
    )
    cmake_parse_arguments(PARSE_ARGV 0 ARG "ALL;DEBUGGABLE" "${one_value_args}" "LAUNCHER_SOURCES;RUNTIME_TARGETS")
    _bridge_check_arguments(
        bridge_add_sdl_application
        TARGET RUN_TARGET MAIN_TARGET LAUNCHER_SOURCES SDL_TARGET SDL_SOURCE_DIR APPLICATION_ID APPLICATION_NAME
    )
    if(ARG_ICON_DIRECTORY AND NOT ARG_ADAPTIVE_ICON_BACKGROUND_COLOR)
        message(FATAL_ERROR "bridge_add_sdl_application(): ICON_DIRECTORY requires ADAPTIVE_ICON_BACKGROUND_COLOR")
    endif()
    if(NOT ARG_ICON_DIRECTORY AND (ARG_ADAPTIVE_ICON_BACKGROUND_COLOR OR ARG_DESKTOP_CATEGORIES))
        message(
            FATAL_ERROR
            "bridge_add_sdl_application(): ADAPTIVE_ICON_BACKGROUND_COLOR and DESKTOP_CATEGORIES require ICON_DIRECTORY"
        )
    endif()
    foreach(_role IN ITEMS MAIN_TARGET SDL_TARGET)
        if(NOT TARGET "${ARG_${_role}}")
            message(FATAL_ERROR "bridge_add_sdl_application(): ${_role} '${ARG_${_role}}' does not exist")
        endif()
    endforeach()
    get_target_property(_main_type "${ARG_MAIN_TARGET}" TYPE)
    if(NOT _main_type STREQUAL "SHARED_LIBRARY")
        message(
            FATAL_ERROR
            "bridge_add_sdl_application(): MAIN_TARGET '${ARG_MAIN_TARGET}' must be a shared library on every "
            "platform, because Android loads it as libmain.so"
        )
    endif()

    if(ANDROID)
        set(_optional "")
        if(ARG_ALL)
            list(APPEND _optional ALL)
        endif()
        if(ARG_DEBUGGABLE)
            list(APPEND _optional DEBUGGABLE)
        endif()
        foreach(_argument IN ITEMS OUTPUT VERSION_NAME VERSION_CODE MIN_API ASSET_DIRECTORY ICON_DIRECTORY
                ADAPTIVE_ICON_BACKGROUND_COLOR)
            if(ARG_${_argument})
                list(APPEND _optional "${_argument}" "${ARG_${_argument}}")
            endif()
        endforeach()
        if(ARG_RUNTIME_TARGETS)
            list(APPEND _optional RUNTIME_TARGETS ${ARG_RUNTIME_TARGETS})
        endif()
        bridge_add_sdl_android_application(
            ${_optional}
            TARGET "${ARG_TARGET}"
            APPLICATION_ID "${ARG_APPLICATION_ID}"
            APPLICATION_NAME "${ARG_APPLICATION_NAME}"
            MAIN_TARGET "${ARG_MAIN_TARGET}"
            SDL_TARGET "${ARG_SDL_TARGET}"
            SDL_SOURCE_DIR "${ARG_SDL_SOURCE_DIR}"
        )
        bridge_add_run_target(TARGET "${ARG_RUN_TARGET}" APPLICATION_TARGET "${ARG_TARGET}")
        return()
    endif()

    if(NOT COMMAND canon_apply_target)
        message(FATAL_ERROR "bridge_add_sdl_application(): load Canon first; desktop executables use its build policy")
    endif()
    add_executable("${ARG_TARGET}" ${ARG_LAUNCHER_SOURCES})
    target_link_libraries("${ARG_TARGET}" PRIVATE "${ARG_MAIN_TARGET}" "${ARG_SDL_TARGET}")
    canon_apply_target("${ARG_TARGET}")

    if(ARG_ICON_DIRECTORY)
        if(WIN32)
            bridge_add_win32_application_icon(TARGET "${ARG_TARGET}" ICON_DIRECTORY "${ARG_ICON_DIRECTORY}")
        elseif(CMAKE_SYSTEM_NAME STREQUAL "Linux")
            set(_optional "")
            foreach(_argument IN ITEMS ASSET_DIRECTORY)
                if(ARG_${_argument})
                    list(APPEND _optional "${_argument}" "${ARG_${_argument}}")
                endif()
            endforeach()
            if(ARG_DESKTOP_CATEGORIES)
                # One list-valued argument; keep its separators.
                string(REPLACE ";" "\\;" _categories "${ARG_DESKTOP_CATEGORIES}")
                list(APPEND _optional CATEGORIES "${_categories}")
            endif()
            bridge_install_linux_desktop_application(
                ${_optional}
                TARGET "${ARG_TARGET}"
                APPLICATION_ID "${ARG_APPLICATION_ID}"
                APPLICATION_NAME "${ARG_APPLICATION_NAME}"
                RUNTIME_TARGETS "${ARG_MAIN_TARGET}" "${ARG_SDL_TARGET}" ${ARG_RUNTIME_TARGETS}
                ICON_DIRECTORY "${ARG_ICON_DIRECTORY}"
            )
        else()
            message(
                WARNING
                "bridge_add_sdl_application(): ${CMAKE_SYSTEM_NAME} has no Bridge icon integration; "
                "'${ARG_TARGET}' is built without an embedded or installed application icon"
            )
        endif()
    endif()

    set(_staging "")
    foreach(_argument IN ITEMS ASSET_DIRECTORY ICON_DIRECTORY)
        if(ARG_${_argument})
            list(APPEND _staging "${_argument}" "${ARG_${_argument}}")
        endif()
    endforeach()
    bridge_stage_runtime(TARGET "${ARG_TARGET}" ${_staging})
    bridge_add_run_target(TARGET "${ARG_RUN_TARGET}" APPLICATION_TARGET "${ARG_TARGET}")
endfunction()
