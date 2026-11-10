# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

include_guard(GLOBAL)

set(BRIDGE_SDL_PROVIDER auto CACHE STRING "SDL dependency provider: auto, vendored, or installed")
set_property(CACHE BRIDGE_SDL_PROVIDER PROPERTY STRINGS auto vendored installed)
set(BRIDGE_SDL_RUNTIME bundle CACHE STRING "SDL runtime delivery on Linux: bundle or system")
set_property(CACHE BRIDGE_SDL_RUNTIME PROPERTY STRINGS bundle system)

# Validates a requested SDL version against the version actually resolved. Canon's installed-package search checks its
# version at resolution time; this additional check also covers vendored SDL and subsequent requirements.
function(_bridge_check_sdl_version ACTUAL REQUESTED)
    if(NOT "${REQUESTED}" MATCHES "^([0-9]+(\\.[0-9]+)*)(\\.\\.\\.(<)?([0-9]+(\\.[0-9]+)*))?$")
        message(FATAL_ERROR "bridge_require_sdl(): unsupported CMake version requirement '${REQUESTED}'")
    endif()
    set(_minimum "${CMAKE_MATCH_1}")
    set(_maximum "${CMAKE_MATCH_5}")
    set(_maximum_exclusive "${CMAKE_MATCH_4}")
    if("${ACTUAL}" VERSION_LESS "${_minimum}")
        message(FATAL_ERROR "bridge_require_sdl(): SDL ${ACTUAL} does not meet required version '${REQUESTED}'")
    endif()
    if(NOT "${_maximum}" STREQUAL "")
        if(("${_maximum_exclusive}" STREQUAL "<" AND NOT "${ACTUAL}" VERSION_LESS "${_maximum}") OR
           ("${_maximum_exclusive}" STREQUAL "" AND "${ACTUAL}" VERSION_GREATER "${_maximum}"))
            message(FATAL_ERROR "bridge_require_sdl(): SDL ${ACTUAL} does not meet required version '${REQUESTED}'")
        endif()
    endif()
endfunction()

# Resolves an opt-in SDL dependency through Canon, then records the one SDL installation used by this project.
# EXTERNAL_NAME identifies the relative project/external directory; it defaults to sdl. Multiple compatible version
# requests are supported, but switching source directories or providers after resolution is an error.
#
#   bridge_require_sdl(VERSION <CMake version or range> [EXTERNAL_NAME <external relative path>])
function(bridge_require_sdl)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "" "VERSION;EXTERNAL_NAME" "")
    if(ARG_UNPARSED_ARGUMENTS OR ARG_KEYWORDS_MISSING_VALUES OR NOT ARG_VERSION)
        message(FATAL_ERROR "bridge_require_sdl(): VERSION is required; optional EXTERNAL_NAME selects the source tree")
    endif()
    if(NOT "${BRIDGE_SDL_PROVIDER}" MATCHES "^(auto|vendored|installed)$")
        message(FATAL_ERROR "bridge_require_sdl(): BRIDGE_SDL_PROVIDER must be auto, vendored, or installed")
    endif()
    if(NOT "${BRIDGE_SDL_RUNTIME}" MATCHES "^(bundle|system)$")
        message(FATAL_ERROR "bridge_require_sdl(): BRIDGE_SDL_RUNTIME must be bundle or system")
    endif()
    if(BRIDGE_SDL_RUNTIME STREQUAL "system" AND NOT CMAKE_SYSTEM_NAME STREQUAL "Linux")
        message(FATAL_ERROR "bridge_require_sdl(): system-provided SDL runtime is supported only on Linux")
    endif()
    if(NOT ARG_EXTERNAL_NAME)
        set(ARG_EXTERNAL_NAME sdl)
    endif()
    get_property(_existing_name GLOBAL PROPERTY _BRIDGE_SDL_EXTERNAL_NAME)
    if(_existing_name AND NOT "${_existing_name}" STREQUAL "${ARG_EXTERNAL_NAME}")
        message(FATAL_ERROR "bridge_require_sdl(): SDL was already resolved from '${_existing_name}', not '${ARG_EXTERNAL_NAME}'")
    endif()
    if(NOT COMMAND canon_resolve_dependency)
        message(FATAL_ERROR "bridge_require_sdl(): load Canon before resolving SDL")
    endif()

    set(_provider "${BRIDGE_SDL_PROVIDER}")
    if(ANDROID)
        if(_provider STREQUAL "installed")
            message(FATAL_ERROR "bridge_require_sdl(): Android requires vendored SDL for its matching Java glue")
        endif()
        set(_provider vendored)
        set(_source_dir "${PROJECT_SOURCE_DIR}/external/${ARG_EXTERNAL_NAME}")
        if(NOT EXISTS "${_source_dir}/CMakeLists.txt" OR
           NOT IS_DIRECTORY "${_source_dir}/android-project/app/src/main/java/org/libsdl/app")
            message(FATAL_ERROR "bridge_require_sdl(): Android requires SDL source and matching Java glue at ${_source_dir}")
        endif()
        # Android must package libSDL3.so, not a static library or SDL's optional test binaries.
        set(SDL_SHARED ON CACHE BOOL "" FORCE)
        set(SDL_STATIC OFF CACHE BOOL "" FORCE)
        set(SDL_TEST_LIBRARY OFF CACHE BOOL "" FORCE)
        set(SDL_TESTS OFF CACHE BOOL "" FORCE)
        set(SDL_EXAMPLES OFF CACHE BOOL "" FORCE)
        set(SDL_INSTALL OFF CACHE BOOL "" FORCE)
    endif()

    # The called Canon function uses PROJECT_SOURCE_DIR, so the dependency path belongs to the consumer.
    block()
        if(NOT DEFINED CMAKE_MESSAGE_LOG_LEVEL)
            set(CMAKE_MESSAGE_LOG_LEVEL WARNING)
        endif()
        canon_resolve_dependency(
            "${ARG_EXTERNAL_NAME}"
            PACKAGE SDL3
            VERSION "${ARG_VERSION}"
            CONFIG
            TARGETS SDL3::SDL3
            PROVIDER "${_provider}"
        )
    endblock()

    get_target_property(_real_sdl SDL3::SDL3 ALIASED_TARGET)
    if(NOT _real_sdl)
        set(_real_sdl SDL3::SDL3)
    endif()
    get_target_property(_version "${_real_sdl}" SDL_FULL_VERSION)
    if(NOT _version)
        # An imported SDL target normally has no SDL_FULL_VERSION property. Re-read its package config for an exact
        # version; do not infer it from a soname, and never accept an unverified version requirement.
        find_package(SDL3 "${ARG_VERSION}" CONFIG QUIET GLOBAL)
        if(NOT SDL3_FOUND OR NOT SDL3_VERSION)
            message(FATAL_ERROR "bridge_require_sdl(): cannot verify the version of SDL3::SDL3")
        endif()
        set(_version "${SDL3_VERSION}")
    endif()
    _bridge_check_sdl_version("${_version}" "${ARG_VERSION}")
    get_property(_existing_version GLOBAL PROPERTY _BRIDGE_SDL_VERSION)
    if(_existing_version AND NOT "${_existing_version}" STREQUAL "${_version}")
        message(FATAL_ERROR "bridge_require_sdl(): SDL version changed from ${_existing_version} to ${_version}")
    endif()

    # SDL3Config sometimes removes SYSTEM from its header target, even for installed packages.
    foreach(_target IN ITEMS SDL3::SDL3 SDL3::Headers)
        if(TARGET "${_target}")
            get_target_property(_real "${_target}" ALIASED_TARGET)
            if(NOT _real)
                set(_real "${_target}")
            endif()
            set_property(TARGET "${_real}" PROPERTY SYSTEM TRUE)
        endif()
    endforeach()
    set_property(GLOBAL PROPERTY _BRIDGE_SDL_EXTERNAL_NAME "${ARG_EXTERNAL_NAME}")
    set_property(GLOBAL PROPERTY _BRIDGE_SDL_VERSION "${_version}")
    if(ANDROID)
        set_property(GLOBAL PROPERTY _BRIDGE_SDL_SOURCE_DIR "${_source_dir}")
    endif()
endfunction()

# Internal accessor for application and Android packaging helpers. Never silently resolve a default SDL version.
function(_bridge_get_sdl OUT_TARGET OUT_SOURCE_DIR)
    get_property(_version GLOBAL PROPERTY _BRIDGE_SDL_VERSION)
    if(NOT _version OR NOT TARGET SDL3::SDL3)
        message(FATAL_ERROR "Bridge SDL application requires bridge_require_sdl(VERSION ...) first")
    endif()
    get_property(_source_dir GLOBAL PROPERTY _BRIDGE_SDL_SOURCE_DIR)
    set(${OUT_TARGET} SDL3::SDL3 PARENT_SCOPE)
    set(${OUT_SOURCE_DIR} "${_source_dir}" PARENT_SCOPE)
endfunction()
