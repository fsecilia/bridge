# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

cmake_minimum_required(VERSION 3.31.6)

if(NOT DEFINED BRIDGE_DISTRIBUTION_RECIPE OR NOT EXISTS "${BRIDGE_DISTRIBUTION_RECIPE}")
    message(FATAL_ERROR "Bridge distribution manifest recipe is missing")
endif()
include("${BRIDGE_DISTRIBUTION_RECIPE}")

if(NOT "${BRIDGE_DISTRIBUTION_PLATFORM}" MATCHES "^[a-z0-9-]+$" OR
   NOT "${BRIDGE_DISTRIBUTION_VERSION}" MATCHES "^[0-9A-Za-z.+-]+$")
    message(FATAL_ERROR "Bridge distribution platform or version is invalid")
endif()

file(REMOVE "${BRIDGE_DISTRIBUTION_DIRECTORY}/manifest.json")
set(_json "{\n  \"schema_version\": 1,\n  \"artifacts\": [\n")
set(_separator "")
foreach(_artifact IN LISTS BRIDGE_DISTRIBUTION_ARTIFACTS)
    if(NOT "${_artifact}" MATCHES "^([a-z0-9-]+)\\|([A-Za-z0-9_.+-]+)$")
        message(FATAL_ERROR "Invalid Bridge distribution artifact: '${_artifact}' (expected type|filename)")
    endif()
    set(_type "${CMAKE_MATCH_1}")
    set(_filename "${CMAKE_MATCH_2}")
    if("${_filename}" STREQUAL "." OR "${_filename}" STREQUAL "..")
        message(FATAL_ERROR "Invalid distribution artifact filename: '${_filename}'")
    endif()
    set(_path "${BRIDGE_DISTRIBUTION_DIRECTORY}/${_filename}")
    if(NOT EXISTS "${_path}")
        message(FATAL_ERROR "Requested distribution artifact does not exist: ${_path}")
    endif()
    file(SHA256 "${_path}" _sha256)
    string(APPEND _json "${_separator}    {\"type\": \"${_type}\", \"platform\": \"${BRIDGE_DISTRIBUTION_PLATFORM}\", \"version\": \"${BRIDGE_DISTRIBUTION_VERSION}\", \"path\": \"${_filename}\", \"sha256\": \"${_sha256}\", \"validation\": \"not_run\"}")
    set(_separator ",\n")
endforeach()
string(APPEND _json "\n  ]\n}\n")
file(MAKE_DIRECTORY "${BRIDGE_DISTRIBUTION_DIRECTORY}")
file(WRITE "${BRIDGE_DISTRIBUTION_DIRECTORY}/manifest.json" "${_json}")
