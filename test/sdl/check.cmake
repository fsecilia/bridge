# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

foreach(_required IN ITEMS BRIDGE_SOURCE_DIR BRIDGE_TEST_BINARY_DIR BRIDGE_SDL_CASE BRIDGE_GENERATOR BRIDGE_MAKE_PROGRAM)
    if(NOT DEFINED ${_required} OR "${${_required}}" STREQUAL "")
        message(FATAL_ERROR "SDL requirement fixture needs ${_required}")
    endif()
endforeach()

set(_expected)
if(BRIDGE_SDL_CASE STREQUAL "too-new" OR BRIDGE_SDL_CASE STREQUAL "upper-exclusive")
    set(_expected "does not meet required version")
elseif(BRIDGE_SDL_CASE STREQUAL "changed-source")
    set(_expected "SDL was already resolved from")
elseif(BRIDGE_SDL_CASE STREQUAL "invalid-provider")
    set(_expected "BRIDGE_SDL_PROVIDER must be")
elseif(BRIDGE_SDL_CASE STREQUAL "invalid-runtime")
    set(_expected "BRIDGE_SDL_RUNTIME must be")
elseif(BRIDGE_SDL_CASE STREQUAL "missing-canon")
    set(_expected "load Canon before resolving SDL")
elseif(BRIDGE_SDL_CASE STREQUAL "missing-provider")
    set(_expected "installed dependency 'SDL3'")
elseif(BRIDGE_SDL_CASE STREQUAL "preprovided-installed")
    set(_expected "cannot require provider 'installed' because their provenance is unknown")
elseif(BRIDGE_SDL_CASE STREQUAL "missing-vendored")
    set(_expected "vendored dependency 'sdl' is unavailable")
elseif(BRIDGE_SDL_CASE STREQUAL "android-installed")
    set(_expected "Android requires vendored SDL")
elseif(BRIDGE_SDL_CASE STREQUAL "android-missing-source")
    set(_expected "Android requires SDL source and matching Java glue")
elseif(NOT BRIDGE_SDL_CASE STREQUAL "valid")
    message(FATAL_ERROR "Unexpected SDL requirement case: ${BRIDGE_SDL_CASE}")
endif()

file(REMOVE_RECURSE "${BRIDGE_TEST_BINARY_DIR}")
execute_process(
    COMMAND "${CMAKE_COMMAND}"
        -S "${BRIDGE_SOURCE_DIR}/test/sdl/fixture"
        -B "${BRIDGE_TEST_BINARY_DIR}"
        -G "${BRIDGE_GENERATOR}"
        "-DCMAKE_MAKE_PROGRAM=${BRIDGE_MAKE_PROGRAM}"
        "-DBRIDGE_CANON_MODULE=${BRIDGE_CANON_MODULE}"
        "-DBRIDGE_SOURCE_DIR=${BRIDGE_SOURCE_DIR}"
        "-DBRIDGE_SDL_CASE=${BRIDGE_SDL_CASE}"
    RESULT_VARIABLE _result OUTPUT_VARIABLE _stdout ERROR_VARIABLE _stderr
)
string(REGEX REPLACE "[ \t\r\n]+" " " _error "${_stderr}")
if("${_expected}" STREQUAL "")
    if(NOT "${_result}" STREQUAL "0")
        message(FATAL_ERROR "SDL requirement ${BRIDGE_SDL_CASE} should succeed:\n${_stdout}\n${_stderr}")
    endif()
elseif("${_result}" STREQUAL "0" OR NOT _error MATCHES "${_expected}")
    message(FATAL_ERROR "SDL requirement ${BRIDGE_SDL_CASE} failed incorrectly: ${_result}\n${_stdout}\n${_stderr}")
endif()
