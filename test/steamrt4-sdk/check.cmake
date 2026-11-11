# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

if(NOT BRIDGE_STEAMRT4_RUNNER OR NOT BRIDGE_TEST_BINARY_DIR OR NOT BRIDGE_STEAMRT4_CASE)
    message(FATAL_ERROR "Steam Runtime SDK runner test requires the runner, test directory, and case")
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
string(REPEAT "a" 64 _digest)
set(_image "registry.gitlab.steamos.cloud/steamrt/steamrt4/sdk@sha256:${_digest}")
set(_runner "${CMAKE_COMMAND}" -E env "BRIDGE_FAKE_PODMAN_LOG=${_log}" "BRIDGE_PODMAN_EXECUTABLE=${_podman}")
set(_args "${BRIDGE_STEAMRT4_RUNNER}" --image "${_image}" --workspace "${BRIDGE_TEST_BINARY_DIR}/workspace")

if(BRIDGE_STEAMRT4_CASE STREQUAL "arguments")
    execute_process(
        COMMAND ${_runner} ${_args} --dependency-prefix "${BRIDGE_TEST_BINARY_DIR}/dependencies" -- /bin/echo "two words"
        RESULT_VARIABLE _result ERROR_VARIABLE _error
    )
    if(NOT "${_result}" STREQUAL "0")
        message(FATAL_ERROR "Steam Runtime SDK runner rejected valid arguments: ${_result}\n${_error}")
    endif()
    file(READ "${_log}" _actual)
    foreach(_required IN ITEMS
        "run\n--rm\n--pull=missing\n--userns=keep-id\n"
        "--mount\ntype=bind,source=${BRIDGE_TEST_BINARY_DIR}/workspace,target=${BRIDGE_TEST_BINARY_DIR}/workspace\n"
        "--workdir\n${BRIDGE_TEST_BINARY_DIR}/workspace\n"
        "--env\nXDG_CACHE_HOME=${BRIDGE_TEST_BINARY_DIR}/workspace/build/.cache/steamrt4\n"
        "--env\nCCACHE_DIR=${BRIDGE_TEST_BINARY_DIR}/workspace/build/.cache/steamrt4/ccache\n"
        "--mount\ntype=bind,source=${BRIDGE_TEST_BINARY_DIR}/dependencies,target=${BRIDGE_TEST_BINARY_DIR}/dependencies\n"
        "--env\nCMAKE_PREFIX_PATH=${BRIDGE_TEST_BINARY_DIR}/dependencies\n"
        "${_image}\n/bin/echo\ntwo words\n"
    )
        string(FIND "${_actual}" "${_required}" _found)
        if(_found EQUAL -1)
            message(FATAL_ERROR "SDK runner did not preserve expected Podman arguments: ${_required}\nActual:\n${_actual}")
        endif()
    endforeach()
elseif(BRIDGE_STEAMRT4_CASE STREQUAL "shell")
    execute_process(COMMAND ${_runner} ${_args} --shell RESULT_VARIABLE _result ERROR_VARIABLE _error)
    if(NOT "${_result}" STREQUAL "0")
        message(FATAL_ERROR "Steam Runtime SDK runner rejected an interactive shell: ${_result}\n${_error}")
    endif()
    file(READ "${_log}" _actual)
    string(FIND "${_actual}" "--interactive\n--tty\n--env\nHISTFILE=/dev/null\n--env\nLESSHISTFILE=-\n${_image}\n/bin/bash\n" _found)
    if(_found EQUAL -1)
        message(FATAL_ERROR "SDK runner did not request an interactive SDK shell:\n${_actual}")
    endif()
elseif(BRIDGE_STEAMRT4_CASE STREQUAL "floating-image")
    execute_process(
        COMMAND ${_runner} "${BRIDGE_STEAMRT4_RUNNER}" --image "registry.gitlab.steamos.cloud/steamrt/steamrt4/sdk:latest"
            --workspace "${BRIDGE_TEST_BINARY_DIR}/workspace" -- /bin/true
        RESULT_VARIABLE _result ERROR_VARIABLE _error
    )
    if(NOT "${_result}" STREQUAL "2" OR NOT "${_error}" MATCHES "must be pinned")
        message(FATAL_ERROR "Floating SDK image was not rejected: ${_result}\n${_error}")
    endif()
elseif(BRIDGE_STEAMRT4_CASE STREQUAL "missing-podman")
    execute_process(
        COMMAND "${CMAKE_COMMAND}" -E env "BRIDGE_PODMAN_EXECUTABLE=${BRIDGE_TEST_BINARY_DIR}/missing-podman"
            ${_args} -- /bin/true
        RESULT_VARIABLE _result ERROR_VARIABLE _error
    )
    if(NOT "${_result}" STREQUAL "1" OR NOT "${_error}" MATCHES "requires Podman")
        message(FATAL_ERROR "Missing Podman was not reported: ${_result}\n${_error}")
    endif()
elseif(BRIDGE_STEAMRT4_CASE STREQUAL "podman-error")
    execute_process(
        COMMAND "${CMAKE_COMMAND}" -E env "BRIDGE_FAKE_PODMAN_EXIT=19" "BRIDGE_FAKE_PODMAN_LOG=${_log}"
            "BRIDGE_PODMAN_EXECUTABLE=${_podman}" ${_args} -- /bin/true
        RESULT_VARIABLE _result
    )
    if(NOT "${_result}" STREQUAL "19")
        message(FATAL_ERROR "SDK runner suppressed the Podman failure: ${_result}")
    endif()
elseif(BRIDGE_STEAMRT4_CASE STREQUAL "prefix-contains-workspace")
    execute_process(
        COMMAND ${_runner} ${_args} --dependency-prefix "${BRIDGE_TEST_BINARY_DIR}" -- /bin/true
        RESULT_VARIABLE _result ERROR_VARIABLE _error
    )
    if(NOT "${_result}" STREQUAL "2" OR NOT "${_error}" MATCHES "contain or be contained")
        message(FATAL_ERROR "SDK runner accepted a prefix containing the workspace: ${_result}\n${_error}")
    endif()
elseif(BRIDGE_STEAMRT4_CASE STREQUAL "prefix-inside-workspace")
    execute_process(
        COMMAND ${_runner} ${_args} --dependency-prefix "${BRIDGE_TEST_BINARY_DIR}/workspace" -- /bin/true
        RESULT_VARIABLE _result ERROR_VARIABLE _error
    )
    if(NOT "${_result}" STREQUAL "2" OR NOT "${_error}" MATCHES "contain or be contained")
        message(FATAL_ERROR "SDK runner accepted an in-tree dependency prefix: ${_result}\n${_error}")
    endif()
else()
    message(FATAL_ERROR "Unknown Steam Runtime SDK runner test case: ${BRIDGE_STEAMRT4_CASE}")
endif()
