# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

# Runs one packaged artifact from a Bridge distribution manifest under Steam
# Linux Runtime 4, the way Steam launches it: from the top of the installed
# package, through the runtime's `run` entry point. With BRIDGE_RUN_GDBSERVER,
# the runtime's own gdbserver starts the game paused and waits for a debugger;
# a gdb command file is written for attaching from the host.
#
#   cmake -DBRIDGE_RUN_MANIFEST=<manifest.json> -DBRIDGE_RUN_ARTIFACT_TYPE=<type>
#         -DBRIDGE_RUN_EXECUTABLE=<path inside the package> -DBRIDGE_RUN_DIRECTORY=<scratch dir>
#         -DBRIDGE_RUN_RUNTIME=<SteamLinuxRuntime_4 directory>
#         [-DBRIDGE_RUN_GDBSERVER=<address:port> -DBRIDGE_RUN_GDB_INIT=<file>]
#         [-DBRIDGE_RUN_ARGUMENTS=<argument;...>]
#         -P bridge_steamrt4_run.cmake
#
# The scratch directory is recreated from the archive on every run, so the
# executed files are exactly the verified artifact.

cmake_minimum_required(VERSION 3.31.6)

foreach(_required IN ITEMS BRIDGE_RUN_MANIFEST BRIDGE_RUN_ARTIFACT_TYPE BRIDGE_RUN_EXECUTABLE
        BRIDGE_RUN_DIRECTORY BRIDGE_RUN_RUNTIME)
    if(NOT DEFINED ${_required} OR "${${_required}}" STREQUAL "")
        message(FATAL_ERROR "bridge_steamrt4_run: ${_required} is required")
    endif()
endforeach()
if(DEFINED BRIDGE_RUN_GDBSERVER AND NOT "${BRIDGE_RUN_GDBSERVER}" STREQUAL "")
    if(NOT "${BRIDGE_RUN_GDBSERVER}" MATCHES "^[^:]+:[0-9]+$")
        message(FATAL_ERROR "bridge_steamrt4_run: BRIDGE_RUN_GDBSERVER must be <address>:<port>: ${BRIDGE_RUN_GDBSERVER}")
    endif()
    if(NOT DEFINED BRIDGE_RUN_GDB_INIT OR "${BRIDGE_RUN_GDB_INIT}" STREQUAL "")
        message(FATAL_ERROR "bridge_steamrt4_run: BRIDGE_RUN_GDBSERVER requires BRIDGE_RUN_GDB_INIT")
    endif()
    set(_gdbserver "${BRIDGE_RUN_GDBSERVER}")
else()
    set(_gdbserver "")
endif()
if(IS_ABSOLUTE "${BRIDGE_RUN_EXECUTABLE}" OR "${BRIDGE_RUN_EXECUTABLE}" MATCHES "(^|/)\\.\\.(/|$)")
    message(FATAL_ERROR "bridge_steamrt4_run: BRIDGE_RUN_EXECUTABLE must be relative to the package: ${BRIDGE_RUN_EXECUTABLE}")
endif()

# Select the artifact by type from the manifest and verify it before extracting anything.
if(NOT EXISTS "${BRIDGE_RUN_MANIFEST}")
    message(FATAL_ERROR "Distribution manifest is missing: ${BRIDGE_RUN_MANIFEST}\n"
        "Build the distribution that produces it first.")
endif()
file(READ "${BRIDGE_RUN_MANIFEST}" _manifest)
string(JSON _schema ERROR_VARIABLE _json_error GET "${_manifest}" schema_version)
if(_json_error OR NOT "${_schema}" MATCHES "^[12]$")
    message(FATAL_ERROR "Unsupported distribution manifest: ${BRIDGE_RUN_MANIFEST}")
endif()
string(JSON _count LENGTH "${_manifest}" artifacts)
set(_matches "")
if(_count GREATER 0)
    math(EXPR _last "${_count} - 1")
    foreach(_index RANGE 0 ${_last})
        string(JSON _type GET "${_manifest}" artifacts ${_index} type)
        if(_type STREQUAL "${BRIDGE_RUN_ARTIFACT_TYPE}")
            list(APPEND _matches ${_index})
        endif()
    endforeach()
endif()
list(LENGTH _matches _match_count)
if(NOT _match_count EQUAL 1)
    message(FATAL_ERROR "Expected exactly one '${BRIDGE_RUN_ARTIFACT_TYPE}' artifact in ${BRIDGE_RUN_MANIFEST}; "
        "found ${_match_count}")
endif()
string(JSON _relative GET "${_manifest}" artifacts ${_matches} path)
string(JSON _expected_hash GET "${_manifest}" artifacts ${_matches} sha256)
string(JSON _version GET "${_manifest}" artifacts ${_matches} version)
get_filename_component(_manifest_dir "${BRIDGE_RUN_MANIFEST}" DIRECTORY)
set(_archive "${_manifest_dir}/${_relative}")
if(NOT EXISTS "${_archive}")
    message(FATAL_ERROR "Manifest references a missing artifact: ${_archive}")
endif()
file(SHA256 "${_archive}" _actual_hash)
if(NOT _actual_hash STREQUAL _expected_hash)
    message(FATAL_ERROR "Artifact checksum does not match its manifest: ${_archive}")
endif()

set(_run "${BRIDGE_RUN_RUNTIME}/run")
if(NOT EXISTS "${_run}" OR IS_DIRECTORY "${_run}" OR NOT IS_EXECUTABLE "${_run}")
    message(FATAL_ERROR "Steam Linux Runtime 4 launcher not found: ${_run}\n"
        "Install it with `steam steam://install/4183110`, or point the run target at its directory.")
endif()

file(REMOVE_RECURSE "${BRIDGE_RUN_DIRECTORY}")
file(MAKE_DIRECTORY "${BRIDGE_RUN_DIRECTORY}")
file(ARCHIVE_EXTRACT INPUT "${_archive}" DESTINATION "${BRIDGE_RUN_DIRECTORY}")
file(GLOB _top_level LIST_DIRECTORIES TRUE "${BRIDGE_RUN_DIRECTORY}/*")
list(LENGTH _top_level _top_level_count)
if(NOT _top_level_count EQUAL 1 OR NOT IS_DIRECTORY "${_top_level}")
    message(FATAL_ERROR "Expected one package directory at the top of ${_archive}; found: ${_top_level}")
endif()
set(_package "${_top_level}")
set(_executable "${_package}/${BRIDGE_RUN_EXECUTABLE}")
if(NOT EXISTS "${_executable}" OR NOT IS_EXECUTABLE "${_executable}")
    message(FATAL_ERROR "Packaged executable is missing or not executable: ${_executable}")
endif()

# Steam starts a game from its install folder; the runtime shares the working directory with the container.
set(_command "${_run}" --)
if(_gdbserver)
    # The host gdb loads symbols from the extracted files. A nonexistent sysroot keeps
    # it from substituting the host's own libraries for the runtime's.
    file(WRITE "${BRIDGE_RUN_GDB_INIT}"
        "# Generated by Bridge for ${_relative} (${_version}); attach after gdbserver starts.\n"
        "set sysroot /nonexistent\n"
        "set solib-search-path ${_package}/lib\n"
        "file ${_executable}\n"
        "target remote ${_gdbserver}\n"
    )
    list(APPEND _command gdbserver "${_gdbserver}")
    message(STATUS "gdbserver will wait on ${_gdbserver} before the game starts.")
    message(STATUS "Attach with: gdb -x ${BRIDGE_RUN_GDB_INIT}   (then `continue`)")
endif()
list(APPEND _command "./${BRIDGE_RUN_EXECUTABLE}" ${BRIDGE_RUN_ARGUMENTS})
message(STATUS "Running ${_relative} (${_version}, sha256 ${_actual_hash}) under ${BRIDGE_RUN_RUNTIME}")
execute_process(
    COMMAND ${_command}
    WORKING_DIRECTORY "${_package}"
    RESULT_VARIABLE _result
    COMMAND_ECHO STDOUT
)
if(NOT "${_result}" STREQUAL "0")
    message(FATAL_ERROR "Game under Steam Linux Runtime 4 exited with ${_result}: ${_relative}")
endif()
