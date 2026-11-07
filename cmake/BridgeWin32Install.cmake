# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

include_guard(GLOBAL)

include("${CMAKE_CURRENT_LIST_DIR}/BridgeWin32Runtime.cmake")

# Installs a complete, independently runnable Windows application in one directory.
# Assets and icons retain the layout used for development-time SDL title storage.
# Runtime DLL discovery is shared with build-tree staging. Explicit RUNTIME_TARGETS
# also support libraries opened dynamically rather than linked by the executable.
#
#   bridge_install_win32_application(TARGET <exe> COMPONENT <component>
#       [ASSET_DIRECTORY <directory>] [ICON_DIRECTORY <directory>]
#       [RUNTIME_TARGETS <shared-target>...])
function(bridge_install_win32_application)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "" "TARGET;COMPONENT;ASSET_DIRECTORY;ICON_DIRECTORY" "RUNTIME_TARGETS")
    if(ARG_UNPARSED_ARGUMENTS OR ARG_KEYWORDS_MISSING_VALUES)
        message(FATAL_ERROR "bridge_install_win32_application(): invalid arguments")
    endif()
    foreach(_required IN ITEMS TARGET COMPONENT)
        if(NOT ARG_${_required})
            message(FATAL_ERROR "bridge_install_win32_application(): ${_required} is required")
        endif()
    endforeach()
    if(NOT CMAKE_SYSTEM_NAME STREQUAL "Windows")
        message(FATAL_ERROR "bridge_install_win32_application() requires a Windows target")
    endif()
    if(NOT TARGET "${ARG_TARGET}")
        message(FATAL_ERROR "bridge_install_win32_application(): target '${ARG_TARGET}' does not exist")
    endif()
    get_target_property(_type "${ARG_TARGET}" TYPE)
    if(NOT _type STREQUAL "EXECUTABLE")
        message(FATAL_ERROR "bridge_install_win32_application(): '${ARG_TARGET}' must be an executable")
    endif()

    # Install directly at the package root. SDL_OpenTitleStorage() resolves its
    # files beside the .exe, and Windows searches that directory for DLLs.
    install(TARGETS "${ARG_TARGET}" RUNTIME DESTINATION "." COMPONENT "${ARG_COMPONENT}")
    install(FILES "$<TARGET_RUNTIME_DLLS:${ARG_TARGET}>" DESTINATION "." COMPONENT "${ARG_COMPONENT}")

    _bridge_win32_compiler_runtime_dlls(_compiler_dlls)
    if(_compiler_dlls)
        install(FILES ${_compiler_dlls} DESTINATION "." COMPONENT "${ARG_COMPONENT}")
    endif()

    set(_seen_targets "${ARG_TARGET}")
    foreach(_runtime_target IN LISTS ARG_RUNTIME_TARGETS)
        if(NOT TARGET "${_runtime_target}")
            message(FATAL_ERROR
                "bridge_install_win32_application(): runtime target '${_runtime_target}' does not exist")
        endif()
        get_target_property(_alias "${_runtime_target}" ALIASED_TARGET)
        if(_alias)
            set(_target "${_alias}")
        else()
            set(_target "${_runtime_target}")
        endif()
        if(_target IN_LIST _seen_targets)
            message(FATAL_ERROR "bridge_install_win32_application(): duplicate runtime target '${_runtime_target}'")
        endif()
        list(APPEND _seen_targets "${_target}")
        get_target_property(_runtime_type "${_target}" TYPE)
        if(NOT _runtime_type STREQUAL "SHARED_LIBRARY")
            message(FATAL_ERROR "bridge_install_win32_application(): '${_runtime_target}' must be a shared library")
        endif()
        # TARGET_FILE handles imported SDL packages and consumer-owned targets
        # alike, without shipping their import libraries.
        install(FILES "$<TARGET_FILE:${_runtime_target}>" DESTINATION "." COMPONENT "${ARG_COMPONENT}")
    endforeach()

    foreach(_place IN ITEMS ASSET_DIRECTORY ICON_DIRECTORY)
        if(NOT ARG_${_place})
            continue()
        endif()
        set(_source "${ARG_${_place}}")
        cmake_path(ABSOLUTE_PATH _source BASE_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}" NORMALIZE)
        if(NOT IS_DIRECTORY "${_source}")
            message(FATAL_ERROR "bridge_install_win32_application(): ${_place} is not a directory: ${_source}")
        endif()
        if(_place STREQUAL "ASSET_DIRECTORY")
            install(DIRECTORY "${_source}/" DESTINATION "." COMPONENT "${ARG_COMPONENT}")
        else()
            install(DIRECTORY "${_source}/" DESTINATION "icons" COMPONENT "${ARG_COMPONENT}")
        endif()
    endforeach()
endfunction()
