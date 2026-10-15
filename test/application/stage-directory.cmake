# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

# Checks that bridge_stage_directory.cmake mirrors a source directory into a
# shared destination: it adds and updates files, removes files that left the
# source, and leaves everything else in the destination alone.

foreach(_required IN ITEMS BRIDGE_SOURCE_DIR BRIDGE_TEST_BINARY_DIR)
    if(NOT DEFINED ${_required} OR "${${_required}}" STREQUAL "")
        message(FATAL_ERROR "Bridge stage-directory test requires ${_required}")
    endif()
endforeach()

set(_root "${BRIDGE_TEST_BINARY_DIR}")
set(_source "${_root}/source tree")
set(_destination "${_root}/destination")
set(_manifest "${_root}/manifests/ASSET_DIRECTORY.manifest")
file(REMOVE_RECURSE "${_root}")
file(WRITE "${_source}/kept.txt" "kept\n")
file(WRITE "${_source}/nested/changed.txt" "before\n")
file(WRITE "${_source}/nested/removed.txt" "removed\n")
file(WRITE "${_destination}/program.exe" "not staged\n")

function(_stage)
    execute_process(
        COMMAND "${CMAKE_COMMAND}"
            "-DSOURCE=${_source}" "-DDESTINATION=${_destination}" "-DMANIFEST=${_manifest}"
            -P "${BRIDGE_SOURCE_DIR}/scripts/bridge_stage_directory.cmake"
        RESULT_VARIABLE _result
        ERROR_VARIABLE _error
    )
    if(NOT _result EQUAL 0)
        message(FATAL_ERROR "Staging failed:\n${_error}")
    endif()
endfunction()

function(_expect_content PATH CONTENT)
    if(NOT EXISTS "${_destination}/${PATH}")
        message(FATAL_ERROR "Expected staged file is missing: ${PATH}")
    endif()
    file(READ "${_destination}/${PATH}" _actual)
    if(NOT _actual STREQUAL CONTENT)
        message(FATAL_ERROR "Staged ${PATH} has '${_actual}', expected '${CONTENT}'")
    endif()
endfunction()

_stage()
_expect_content(kept.txt "kept\n")
_expect_content(nested/changed.txt "before\n")
_expect_content(nested/removed.txt "removed\n")
_expect_content(program.exe "not staged\n")
file(TIMESTAMP "${_destination}/kept.txt" _kept_before "%s")

execute_process(COMMAND "${CMAKE_COMMAND}" -E sleep 1.1)
file(WRITE "${_source}/nested/changed.txt" "after\n")
file(REMOVE "${_source}/nested/removed.txt")
file(WRITE "${_source}/added.txt" "added\n")
_stage()

_expect_content(kept.txt "kept\n")
_expect_content(nested/changed.txt "after\n")
_expect_content(added.txt "added\n")
_expect_content(program.exe "not staged\n")
if(EXISTS "${_destination}/nested/removed.txt")
    message(FATAL_ERROR "A file removed from the source was left in the staged copy")
endif()
file(TIMESTAMP "${_destination}/kept.txt" _kept_after "%s")
if(NOT _kept_before STREQUAL _kept_after)
    message(FATAL_ERROR "An unchanged staged file was rewritten")
endif()
