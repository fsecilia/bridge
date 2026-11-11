# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

# Drives bridge_steamrt4_run.cmake against a real ZIP and a fake SteamLinuxRuntime_4/run
# that records its working directory and arguments, then runs the command after `--`.
if(NOT BRIDGE_SOURCE_DIR OR NOT BRIDGE_TEST_BINARY_DIR)
    message(FATAL_ERROR "Steam Linux Runtime run test requires the Bridge source and test directories")
endif()

set(_script "${BRIDGE_SOURCE_DIR}/scripts/bridge_steamrt4_run.cmake")
set(_root "${BRIDGE_TEST_BINARY_DIR}")
file(REMOVE_RECURSE "${_root}")
set(_executable_permissions OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)

# Package: game-1.0-steam-linux-x64/{bin/game,lib/libgame.so}
set(_stage "${_root}/stage/game-1.0-steam-linux-x64")
file(MAKE_DIRECTORY "${_stage}/bin" "${_stage}/lib")
file(WRITE "${_stage}/bin/game" [=[#!/usr/bin/env bash
printf '%s\n' "$PWD" "$@" > "$BRIDGE_TEST_GAME_LOG"
exit "${BRIDGE_TEST_GAME_EXIT:-0}"
]=])
file(CHMOD "${_stage}/bin/game" PERMISSIONS ${_executable_permissions})
file(WRITE "${_stage}/lib/libgame.so" "library")
file(MAKE_DIRECTORY "${_root}/dist/steam-linux-x64")
set(_archive "${_root}/dist/steam-linux-x64/game-1.0-steam-linux-x64.zip")
execute_process(
    COMMAND "${CMAKE_COMMAND}" -E tar cf "${_archive}" --format=zip game-1.0-steam-linux-x64
    WORKING_DIRECTORY "${_root}/stage"
    RESULT_VARIABLE _result
)
if(NOT "${_result}" STREQUAL "0")
    message(FATAL_ERROR "Unable to create the run fixture ZIP")
endif()
file(SHA256 "${_archive}" _hash)
function(_write_manifest HASH)
    file(WRITE "${_root}/dist/manifest.json"
        "{\"schema_version\": 2, \"artifacts\": [\n"
        "  {\"type\": \"windows-zip\", \"platform\": \"windows-x64\", \"version\": \"1.0\", "
        "\"path\": \"windows-x64/unused.zip\", \"sha256\": \"${HASH}\", \"validation\": {\"package\": \"passed\"}},\n"
        "  {\"type\": \"steam-linux-zip\", \"platform\": \"steam-linux-x64\", \"version\": \"1.0\", "
        "\"path\": \"steam-linux-x64/game-1.0-steam-linux-x64.zip\", \"sha256\": \"${HASH}\", "
        "\"validation\": {\"package\": \"passed\"}}\n]}\n")
endfunction()
_write_manifest("${_hash}")

set(_runtime "${_root}/SteamLinuxRuntime_4")
file(MAKE_DIRECTORY "${_runtime}")
file(WRITE "${_runtime}/run" [=[#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$PWD" "$@" > "$BRIDGE_TEST_RUNTIME_LOG"
[[ "$1" == '--' ]] || exit 40
shift
if [[ "$1" == 'gdbserver' ]]; then
    exit 0
fi
exec "$@"
]=])
file(CHMOD "${_runtime}/run" PERMISSIONS ${_executable_permissions})

set(_run_dir "${_root}/run")
set(_package "${_run_dir}/game-1.0-steam-linux-x64")
set(_runtime_log "${_root}/runtime.log")
set(_game_log "${_root}/game.log")
function(_run_case OUT_RESULT OUT_OUTPUT)
    execute_process(
        COMMAND "${CMAKE_COMMAND}" -E env
            "BRIDGE_TEST_RUNTIME_LOG=${_runtime_log}" "BRIDGE_TEST_GAME_LOG=${_game_log}" ${BRIDGE_TEST_EXTRA_ENV}
            "${CMAKE_COMMAND}"
            "-DBRIDGE_RUN_MANIFEST=${_root}/dist/manifest.json"
            -DBRIDGE_RUN_ARTIFACT_TYPE=steam-linux-zip
            -DBRIDGE_RUN_EXECUTABLE=bin/game
            "-DBRIDGE_RUN_DIRECTORY=${_run_dir}"
            "-DBRIDGE_RUN_RUNTIME=${_runtime}"
            ${ARGN}
            -P "${_script}"
        RESULT_VARIABLE _result OUTPUT_VARIABLE _stdout ERROR_VARIABLE _stderr
    )
    set("${OUT_RESULT}" "${_result}" PARENT_SCOPE)
    set("${OUT_OUTPUT}" "${_stdout}${_stderr}" PARENT_SCOPE)
endfunction()

# A plain run starts from the package root through `run --`, with game arguments, from a fresh extraction.
file(MAKE_DIRECTORY "${_run_dir}")
file(WRITE "${_run_dir}/stale.txt" "left from an earlier run")
_run_case(_result _output "-DBRIDGE_RUN_ARGUMENTS=--windowed\;two words")
if(NOT "${_result}" STREQUAL "0")
    message(FATAL_ERROR "Run failed (${_result}):\n${_output}")
endif()
file(STRINGS "${_runtime_log}" _runtime_call)
if(NOT "${_runtime_call}" STREQUAL "${_package};--;./bin/game;--windowed;two words")
    message(FATAL_ERROR "Runtime was not invoked from the package root as Steam would: ${_runtime_call}")
endif()
file(STRINGS "${_game_log}" _game_call)
if(NOT "${_game_call}" STREQUAL "${_package};--windowed;two words")
    message(FATAL_ERROR "Game did not receive its arguments: ${_game_call}")
endif()
if(EXISTS "${_run_dir}/stale.txt")
    message(FATAL_ERROR "Run directory was reused instead of extracted fresh")
endif()

# gdbserver runs inside the runtime ahead of the game, and the host gdb gets a matching command file.
file(REMOVE "${_root}/gdbinit")
_run_case(_result _output -DBRIDGE_RUN_GDBSERVER=127.0.0.1:12345 "-DBRIDGE_RUN_GDB_INIT=${_root}/gdbinit")
if(NOT "${_result}" STREQUAL "0")
    message(FATAL_ERROR "gdbserver run failed (${_result}):\n${_output}")
endif()
file(STRINGS "${_runtime_log}" _runtime_call)
if(NOT "${_runtime_call}" STREQUAL "${_package};--;gdbserver;127.0.0.1:12345;./bin/game")
    message(FATAL_ERROR "gdbserver was not placed ahead of the game: ${_runtime_call}")
endif()
file(READ "${_root}/gdbinit" _gdbinit)
foreach(_line IN ITEMS
    "set sysroot /nonexistent\n"
    "set solib-search-path ${_package}/lib\n"
    "file ${_package}/bin/game\n"
    "target remote 127.0.0.1:12345\n"
)
    string(FIND "${_gdbinit}" "${_line}" _found)
    if(_found EQUAL -1)
        message(FATAL_ERROR "gdb command file is missing '${_line}':\n${_gdbinit}")
    endif()
endforeach()

# The game's exit status is reported rather than swallowed.
set(BRIDGE_TEST_EXTRA_ENV "BRIDGE_TEST_GAME_EXIT=3")
_run_case(_result _output)
set(BRIDGE_TEST_EXTRA_ENV "")
if("${_result}" STREQUAL "0" OR NOT "${_output}" MATCHES "exited with 3")
    message(FATAL_ERROR "Game failure was not reported (${_result}):\n${_output}")
endif()

# A missing runtime is named, with how to install it.
_run_case(_result _output "-DBRIDGE_RUN_RUNTIME=${_root}/missing-runtime")
if("${_result}" STREQUAL "0" OR NOT "${_output}" MATCHES "launcher not found.*4183110")
    message(FATAL_ERROR "Missing runtime was not reported (${_result}):\n${_output}")
endif()

# An archive that no longer matches its manifest is never run.
string(REPEAT "0" 64 _wrong)
_write_manifest("${_wrong}")
_run_case(_result _output)
if("${_result}" STREQUAL "0" OR NOT "${_output}" MATCHES "checksum does not match")
    message(FATAL_ERROR "Checksum mismatch was not rejected (${_result}):\n${_output}")
endif()
_write_manifest("${_hash}")

# The artifact type must select exactly one entry.
_run_case(_result _output -DBRIDGE_RUN_ARTIFACT_TYPE=steam-linux-tarball)
if("${_result}" STREQUAL "0" OR NOT "${_output}" MATCHES "found 0")
    message(FATAL_ERROR "Missing artifact type was not rejected (${_result}):\n${_output}")
endif()

# Without a published manifest the run explains what to build.
file(REMOVE "${_root}/dist/manifest.json")
_run_case(_result _output)
if("${_result}" STREQUAL "0" OR NOT "${_output}" MATCHES "manifest is missing")
    message(FATAL_ERROR "Missing manifest was not reported (${_result}):\n${_output}")
endif()
