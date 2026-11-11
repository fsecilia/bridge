# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

if(NOT BRIDGE_STEAMRT4_LAUNCHER OR NOT BRIDGE_TEST_BINARY_DIR OR NOT BRIDGE_STEAMRT4_CASE)
    message(FATAL_ERROR "Steam Runtime SDK launcher test requires the launcher, test directory, and case")
endif()

file(MAKE_DIRECTORY "${BRIDGE_TEST_BINARY_DIR}/workspace" "${BRIDGE_TEST_BINARY_DIR}/dependencies")
set(_podman "${BRIDGE_TEST_BINARY_DIR}/podman")
set(_log "${BRIDGE_TEST_BINARY_DIR}/podman-arguments.txt")
file(WRITE "${_podman}" [=[#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" > "$BRIDGE_FAKE_PODMAN_LOG"
exit "${BRIDGE_FAKE_PODMAN_EXIT:-0}"
]=])
file(CHMOD "${_podman}" PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
string(REPEAT "b" 64 _digest)
set(_image "registry.gitlab.steamos.cloud/steamrt/steamrt4/sdk@sha256:${_digest}")
set(_runner "${CMAKE_COMMAND}" -E env
    "BRIDGE_STEAMRT4_SDK_IMAGE=${_image}"
    "BRIDGE_FAKE_PODMAN_LOG=${_log}"
    "BRIDGE_PODMAN_EXECUTABLE=${_podman}"
)

set(_image_file "${BRIDGE_TEST_BINARY_DIR}/workspace/steamrt4-sdk.image")
file(REMOVE "${_image_file}")

if(BRIDGE_STEAMRT4_CASE STREQUAL "missing-image")
    execute_process(
        COMMAND "${CMAKE_COMMAND}" -E env "BRIDGE_STEAMRT4_SDK_IMAGE="
            "${BRIDGE_STEAMRT4_LAUNCHER}" /bin/true
        WORKING_DIRECTORY "${BRIDGE_TEST_BINARY_DIR}/workspace"
        RESULT_VARIABLE _result ERROR_VARIABLE _error
    )
    if(NOT "${_result}" STREQUAL "2" OR NOT "${_error}" MATCHES "commit .*steamrt4-sdk.image or set BRIDGE_STEAMRT4_SDK_IMAGE")
        message(FATAL_ERROR "SDK launcher failed to report missing image: ${_result}\n${_error}")
    endif()
    return()
endif()

# The committed image file is the default source; comments and blank lines are ignored.
string(REPEAT "c" 64 _file_digest)
set(_file_image "registry.gitlab.steamos.cloud/steamrt/steamrt4/sdk@sha256:${_file_digest}")
if(BRIDGE_STEAMRT4_CASE STREQUAL "invalid-image-file")
    file(WRITE "${_image_file}" "# two references are ambiguous\n${_file_image}\n${_image}\n")
    execute_process(
        COMMAND "${CMAKE_COMMAND}" -E env "BRIDGE_STEAMRT4_SDK_IMAGE=" "BRIDGE_PODMAN_EXECUTABLE=${_podman}"
            "BRIDGE_FAKE_PODMAN_LOG=${_log}" "${BRIDGE_STEAMRT4_LAUNCHER}" /bin/true
        WORKING_DIRECTORY "${BRIDGE_TEST_BINARY_DIR}/workspace"
        RESULT_VARIABLE _result ERROR_VARIABLE _error
    )
    if(NOT "${_result}" STREQUAL "2" OR NOT "${_error}" MATCHES "exactly one image reference; found 2")
        message(FATAL_ERROR "SDK launcher accepted an ambiguous image file: ${_result}\n${_error}")
    endif()
    return()
endif()
if(BRIDGE_STEAMRT4_CASE MATCHES "^(image-file|override)$")
    file(WRITE "${_image_file}" "# SPDX-License-Identifier: MIT\n\n  ${_file_image}  \n")
endif()
if(BRIDGE_STEAMRT4_CASE STREQUAL "image-file")
    set(_runner "${CMAKE_COMMAND}" -E env
        "BRIDGE_STEAMRT4_SDK_IMAGE="
        "BRIDGE_FAKE_PODMAN_LOG=${_log}"
        "BRIDGE_PODMAN_EXECUTABLE=${_podman}"
    )
    set(_image "${_file_image}")
endif()

set(_command /bin/echo "two words")
if(BRIDGE_STEAMRT4_CASE STREQUAL "shell")
    set(_command)
elseif(BRIDGE_STEAMRT4_CASE MATCHES "^(image-file|override)$")
    # The environment image, when set, wins over the file and says so.
elseif(BRIDGE_STEAMRT4_CASE STREQUAL "prefix")
    list(APPEND _runner "BRIDGE_STEAMRT4_PREFIX=${BRIDGE_TEST_BINARY_DIR}/dependencies")
elseif(BRIDGE_STEAMRT4_CASE STREQUAL "podman-error")
    list(APPEND _runner "BRIDGE_FAKE_PODMAN_EXIT=17")
elseif(NOT BRIDGE_STEAMRT4_CASE STREQUAL "command")
    message(FATAL_ERROR "Unknown Steam SDK launcher test case: ${BRIDGE_STEAMRT4_CASE}")
endif()

execute_process(
    COMMAND ${_runner} "${BRIDGE_STEAMRT4_LAUNCHER}" ${_command}
    WORKING_DIRECTORY "${BRIDGE_TEST_BINARY_DIR}/workspace"
    RESULT_VARIABLE _result ERROR_VARIABLE _error
)
if(BRIDGE_STEAMRT4_CASE STREQUAL "podman-error")
    if(NOT "${_result}" STREQUAL "17")
        message(FATAL_ERROR "SDK launcher suppressed Podman failure: ${_result}\n${_error}")
    endif()
    return()
endif()
if(NOT "${_result}" STREQUAL "0")
    message(FATAL_ERROR "SDK launcher rejected valid invocation: ${_result}\n${_error}")
endif()
if(BRIDGE_STEAMRT4_CASE STREQUAL "override" AND NOT "${_error}" MATCHES "BRIDGE_STEAMRT4_SDK_IMAGE override")
    message(FATAL_ERROR "SDK launcher did not announce the image override:\n${_error}")
endif()
if(BRIDGE_STEAMRT4_CASE STREQUAL "image-file" AND "${_error}" MATCHES "override")
    message(FATAL_ERROR "SDK launcher reported an override for the committed image:\n${_error}")
endif()
file(READ "${_log}" _actual)
set(_expected "--workdir\n${BRIDGE_TEST_BINARY_DIR}/workspace\n")
string(FIND "${_actual}" "${_expected}" _found)
if(_found EQUAL -1)
    message(FATAL_ERROR "SDK launcher did not preserve the workspace:\n${_actual}")
endif()
if(BRIDGE_STEAMRT4_CASE STREQUAL "shell")
    set(_expected "--interactive\n--tty\n--env\nHISTFILE=/dev/null\n--env\nLESSHISTFILE=-\n${_image}\n/bin/bash\n")
else()
    set(_expected "${_image}\n/bin/echo\ntwo words\n")
endif()
string(FIND "${_actual}" "${_expected}" _found)
if(_found EQUAL -1)
    message(FATAL_ERROR "SDK launcher forwarded an unexpected command:\nExpected:\n${_expected}Actual:\n${_actual}")
endif()
if(BRIDGE_STEAMRT4_CASE STREQUAL "prefix")
    foreach(_required IN ITEMS
        "--mount\ntype=bind,source=${BRIDGE_TEST_BINARY_DIR}/dependencies,target=${BRIDGE_TEST_BINARY_DIR}/dependencies\n"
        "--env\nCMAKE_PREFIX_PATH=${BRIDGE_TEST_BINARY_DIR}/dependencies\n"
    )
        string(FIND "${_actual}" "${_required}" _found)
        if(_found EQUAL -1)
            message(FATAL_ERROR "SDK launcher lost dependency prefix configuration: ${_required}\n${_actual}")
        endif()
    endforeach()
endif()
