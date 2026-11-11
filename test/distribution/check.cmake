# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

function(_distribution_run)
    execute_process(COMMAND ${ARGN} RESULT_VARIABLE _result OUTPUT_VARIABLE _stdout ERROR_VARIABLE _stderr)
    if(NOT "${_result}" STREQUAL "0")
        message(FATAL_ERROR "Distribution command failed (${_result}): ${ARGN}\n${_stdout}\n${_stderr}")
    endif()
endfunction()

set(_fixture "${BRIDGE_SOURCE_DIR}/test/distribution/fixture")
set(_producer "${BRIDGE_TEST_BINARY_DIR}/producer")
set(_coordinator "${BRIDGE_TEST_BINARY_DIR}/coordinator")
set(_collected "${BRIDGE_TEST_BINARY_DIR}/collected")
file(REMOVE_RECURSE "${BRIDGE_TEST_BINARY_DIR}")
_distribution_run("${CMAKE_COMMAND}" -S "${_fixture}" -B "${_producer}" -G Ninja
    "-DBRIDGE_SOURCE_DIR=${BRIDGE_SOURCE_DIR}" -DFIXTURE_ROLE=producer -DFIXTURE_PAYLOAD=first)
_distribution_run("${CMAKE_COMMAND}" -S "${_fixture}" -B "${_coordinator}" -G Ninja
    "-DBRIDGE_SOURCE_DIR=${BRIDGE_SOURCE_DIR}" -DFIXTURE_ROLE=coordinator
    "-DFIXTURE_PRODUCER_DIR=${_producer}" "-DFIXTURE_OUTPUT_DIR=${_collected}")
# Files left in the producer directory do not become release artifacts.
file(MAKE_DIRECTORY "${_producer}/dist")
file(WRITE "${_producer}/dist/unrequested.exe" "stale package")
_distribution_run("${CMAKE_COMMAND}" --build "${_coordinator}" --target fixture_distribution)
set(_artifact "${_collected}/windows-x64/example.zip")
if(NOT EXISTS "${_artifact}")
    message(FATAL_ERROR "Collected artifact is missing: ${_artifact}")
endif()
file(READ "${_artifact}" _contents)
if(NOT "${_contents}" STREQUAL "first")
    message(FATAL_ERROR "Collected artifact differs from its producer")
endif()
file(READ "${_collected}/manifest.json" _manifest)
string(JSON _count LENGTH "${_manifest}" artifacts)
if(NOT _count EQUAL 1 OR EXISTS "${_collected}/windows-x64/unrequested.exe")
    message(FATAL_ERROR "Collector included an unrequested or stale artifact")
endif()
string(JSON _relative GET "${_manifest}" artifacts 0 path)
string(JSON _validation GET "${_manifest}" artifacts 0 validation)
string(JSON _checksum GET "${_manifest}" artifacts 0 sha256)
file(SHA256 "${_artifact}" _actual)
if(NOT "${_relative}" STREQUAL "windows-x64/example.zip" OR
   NOT "${_checksum}" STREQUAL "${_actual}" OR NOT "${_validation}" STREQUAL "not_run")
    message(FATAL_ERROR "Collected manifest identity, checksum, or validation status is incorrect")
endif()

# Updating the producer and rebuilding through the coordinator must copy the
# changed package instead of reusing the previously published artifact.
_distribution_run("${CMAKE_COMMAND}" -S "${_fixture}" -B "${_producer}" -G Ninja
    "-DBRIDGE_SOURCE_DIR=${BRIDGE_SOURCE_DIR}" -DFIXTURE_ROLE=producer -DFIXTURE_PAYLOAD=second)
_distribution_run("${CMAKE_COMMAND}" --build "${_coordinator}" --target fixture_distribution)
file(READ "${_artifact}" _contents)
if(NOT "${_contents}" STREQUAL "second")
    message(FATAL_ERROR "Coordinator did not collect the updated distribution")
endif()

# A build-tree recursion error is distinct from an unconfigured tree error.
_distribution_run("${CMAKE_COMMAND}" -S "${_fixture}" -B "${_coordinator}" -G Ninja
    "-DBRIDGE_SOURCE_DIR=${BRIDGE_SOURCE_DIR}" -DFIXTURE_ROLE=coordinator
    "-DFIXTURE_PRODUCER_DIR=${_coordinator}" "-DFIXTURE_OUTPUT_DIR=${_collected}")
execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_coordinator}" --target fixture_distribution
    RESULT_VARIABLE _result OUTPUT_VARIABLE _stdout ERROR_VARIABLE _stderr)
if("${_result}" STREQUAL "0" OR NOT "${_stdout}${_stderr}" MATCHES "cannot recursively build its own active tree")
    message(FATAL_ERROR "Recursive distribution build was not rejected:\n${_stdout}${_stderr}")
endif()

_distribution_run("${CMAKE_COMMAND}" -S "${_fixture}" -B "${_coordinator}" -G Ninja
    "-DBRIDGE_SOURCE_DIR=${BRIDGE_SOURCE_DIR}" -DFIXTURE_ROLE=coordinator
    "-DFIXTURE_PRODUCER_DIR=${BRIDGE_TEST_BINARY_DIR}/unconfigured" "-DFIXTURE_OUTPUT_DIR=${_collected}")
execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_coordinator}" --target fixture_distribution
    RESULT_VARIABLE _result OUTPUT_VARIABLE _stdout ERROR_VARIABLE _stderr)
if("${_result}" STREQUAL "0" OR NOT "${_stdout}${_stderr}" MATCHES "not configured")
    message(FATAL_ERROR "Missing distribution tree was not rejected:\n${_stdout}${_stderr}")
endif()

# A configured build tree from the wrong source must also fail before building.
_distribution_run("${CMAKE_COMMAND}" -S "${_fixture}" -B "${_coordinator}" -G Ninja
    "-DBRIDGE_SOURCE_DIR=${BRIDGE_SOURCE_DIR}" -DFIXTURE_ROLE=coordinator
    "-DFIXTURE_PRODUCER_DIR=${_producer}" "-DFIXTURE_OUTPUT_DIR=${_collected}"
    "-DFIXTURE_EXPECTED_SOURCE=${BRIDGE_TEST_BINARY_DIR}/not-the-fixture")
execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_coordinator}" --target fixture_distribution
    RESULT_VARIABLE _result OUTPUT_VARIABLE _stdout ERROR_VARIABLE _stderr)
if("${_result}" STREQUAL "0" OR NOT "${_stdout}${_stderr}" MATCHES "different source")
    message(FATAL_ERROR "Source identity mismatch was not rejected:
${_stdout}${_stderr}")
endif()

# Writing a release manifest must fail when its explicitly declared artifact
# is missing, even if other unrelated files are present.
set(_missing_recipe "${BRIDGE_TEST_BINARY_DIR}/missing-recipe.cmake")
file(WRITE "${_missing_recipe}"
    "set(BRIDGE_DISTRIBUTION_DIRECTORY [==[${_producer}/dist]==])\n"
    "set(BRIDGE_DISTRIBUTION_PLATFORM windows-x64)\n"
    "set(BRIDGE_DISTRIBUTION_VERSION 0.1.0)\n"
    "set(BRIDGE_DISTRIBUTION_ARTIFACTS [==[windows-installer|missing.exe]==])\n")
execute_process(COMMAND "${CMAKE_COMMAND}" "-DBRIDGE_DISTRIBUTION_RECIPE=${_missing_recipe}"
    -P "${BRIDGE_SOURCE_DIR}/scripts/bridge_distribution_manifest.cmake"
    RESULT_VARIABLE _result OUTPUT_VARIABLE _stdout ERROR_VARIABLE _stderr)
if("${_result}" STREQUAL "0" OR NOT "${_stdout}${_stderr}" MATCHES "does not exist")
    message(FATAL_ERROR "Missing distribution artifact was not rejected:
${_stdout}${_stderr}")
endif()

# Validation is collected as evidence, not authored by the app into the final
# manifest. Missing results and failed validators must not publish a manifest.
set(_validator "${BRIDGE_TEST_BINARY_DIR}/validate.sh")
file(WRITE "${_validator}" [=[#!/usr/bin/env bash
set -euo pipefail
while (($#)); do
    case "$1" in
        --manifest) manifest=$2; shift 2 ;;
        --report) report=$2; shift 2 ;;
        --mode) mode=$2; shift 2 ;;
        *) exit 12 ;;
    esac
done
[[ -f "$manifest" ]] || exit 13
case "$mode" in
    success) echo '{"schema_version":1,"artifacts":{"windows-x64/example.zip":{"package":"passed","loader":"not_run"}}}' > "$report" ;;
    missing) echo '{"schema_version":1,"artifacts":{}}' > "$report" ;;
    wrong-state) echo '{"schema_version":1,"artifacts":{"windows-x64/example.zip":{"package":"unknown"}}}' > "$report" ;;
    fail) exit 27 ;;
    *) exit 14 ;;
esac
]=])
file(CHMOD "${_validator}" PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
foreach(_mode IN ITEMS success missing wrong-state fail)
    _distribution_run("${CMAKE_COMMAND}" -S "${_fixture}" -B "${_coordinator}" -G Ninja
        "-DBRIDGE_SOURCE_DIR=${BRIDGE_SOURCE_DIR}" -DFIXTURE_ROLE=coordinator
        "-DFIXTURE_PRODUCER_DIR=${_producer}" "-DFIXTURE_OUTPUT_DIR=${_collected}"
        "-DFIXTURE_VALIDATOR=${_validator}" "-DFIXTURE_VALIDATOR_MODE=${_mode}"
        "-DFIXTURE_EXPECTED_SOURCE=${_fixture}")
    execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_coordinator}" --target fixture_distribution
        RESULT_VARIABLE _result OUTPUT_VARIABLE _stdout ERROR_VARIABLE _stderr)
    if(_mode STREQUAL "success")
        if(NOT "${_result}" STREQUAL "0")
            message(FATAL_ERROR "Validated collection failed: ${_stdout} ${_stderr}")
        endif()
        file(READ "${_collected}/manifest.json" _validated)
        string(JSON _schema GET "${_validated}" schema_version)
        string(JSON _package GET "${_validated}" artifacts 0 validation package)
        string(JSON _loader GET "${_validated}" artifacts 0 validation loader)
        if(NOT _schema EQUAL 2 OR NOT _package STREQUAL "passed" OR NOT _loader STREQUAL "not_run")
            message(FATAL_ERROR "Incorrect validated manifest: ${_validated}")
        endif()
    else()
        if("${_result}" STREQUAL "0" OR EXISTS "${_collected}/manifest.json")
            message(FATAL_ERROR "${_mode}: validation failure published a manifest: ${_stdout} ${_stderr}")
        endif()
    endif()
endforeach()

# A workflow producer starts without a CMake cache. One launched workflow
# configures it and builds its distribution target, producing the manifest.
set(_workflow_producer "${BRIDGE_TEST_BINARY_DIR}/workflow-producer")
set(_workflow_launcher "${BRIDGE_TEST_BINARY_DIR}/launch-workflow.sh")
set(_workflow_log "${BRIDGE_TEST_BINARY_DIR}/workflow-calls.log")
set(_launcher_template [=[#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> '@_workflow_log@'
if [[ "$1" != 'cmake' ]]; then
    echo 'unexpected SDK launcher command' >&2
    exit 18
fi
shift
if [[ "${1-}" == '--workflow' && "${2-}" == '--preset' && "${3-}" == 'fixture-release' ]]; then
    if [[ -f '@BRIDGE_TEST_BINARY_DIR@/fail-workflow' ]]; then exit 29; fi
    '@CMAKE_COMMAND@' -S '@_fixture@' -B '@_workflow_producer@' -G Ninja \
        '-DBRIDGE_SOURCE_DIR=@BRIDGE_SOURCE_DIR@' -DFIXTURE_ROLE=producer -DFIXTURE_PAYLOAD=workflow
    if [[ -f '@BRIDGE_TEST_BINARY_DIR@/skip-package' ]]; then exit 0; fi
    '@CMAKE_COMMAND@' --build '@_workflow_producer@' --target fixture_distribution
else
    echo 'unexpected SDK launcher phase' >&2
    exit 17
fi
]=])
string(CONFIGURE "${_launcher_template}" _launcher_script @ONLY)
file(WRITE "${_workflow_launcher}" "${_launcher_script}")
file(CHMOD "${_workflow_launcher}" PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
file(REMOVE_RECURSE "${_workflow_producer}" "${_collected}")
_distribution_run("${CMAKE_COMMAND}" -S "${_fixture}" -B "${_coordinator}" -G Ninja
    "-DBRIDGE_SOURCE_DIR=${BRIDGE_SOURCE_DIR}" -DFIXTURE_ROLE=coordinator
    "-DFIXTURE_PRODUCER_DIR=${_workflow_producer}" "-DFIXTURE_OUTPUT_DIR=${_collected}"
    "-DFIXTURE_WORKFLOW_LAUNCHER=${_workflow_launcher}" -DFIXTURE_VALIDATOR=)
_distribution_run("${CMAKE_COMMAND}" --build "${_coordinator}" --target fixture_distribution)
file(READ "${_collected}/windows-x64/example.zip" _result)
if(NOT _result STREQUAL "workflow")
    message(FATAL_ERROR "Workflow producer was not configured and collected correctly")
endif()
file(STRINGS "${_workflow_log}" _calls)
list(LENGTH _calls _call_count)
if(NOT _call_count EQUAL 1)
    message(FATAL_ERROR "Expected exactly one launched workflow: ${_calls}")
endif()
list(GET _calls 0 _workflow_call)
if(NOT _workflow_call STREQUAL "cmake --workflow --preset fixture-release")
    message(FATAL_ERROR "Incorrect launched workflow: ${_calls}")
endif()

file(WRITE "${BRIDGE_TEST_BINARY_DIR}/fail-workflow" "fail")
execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_coordinator}" --target fixture_distribution
    RESULT_VARIABLE _result OUTPUT_VARIABLE _stdout ERROR_VARIABLE _stderr)
if("${_result}" STREQUAL "0" OR EXISTS "${_collected}/manifest.json" OR
   NOT "${_stdout}${_stderr}" MATCHES "Distribution workflow failed")
    message(FATAL_ERROR "Failed workflow published a distribution:\n${_stdout}${_stderr}")
endif()
file(REMOVE "${BRIDGE_TEST_BINARY_DIR}/fail-workflow")

# A workflow that succeeds without packaging must not be satisfied by the
# manifest an earlier successful run left in the producer tree.
if(NOT EXISTS "${_workflow_producer}/dist/manifest.json")
    file(MAKE_DIRECTORY "${_workflow_producer}/dist")
    file(WRITE "${_workflow_producer}/dist/manifest.json" "{}")
endif()
file(WRITE "${BRIDGE_TEST_BINARY_DIR}/skip-package" "skip")
execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_coordinator}" --target fixture_distribution
    RESULT_VARIABLE _result OUTPUT_VARIABLE _stdout ERROR_VARIABLE _stderr)
if("${_result}" STREQUAL "0" OR EXISTS "${_collected}/manifest.json" OR
   NOT "${_stdout}${_stderr}" MATCHES "did not produce its manifest")
    message(FATAL_ERROR "A stale producer manifest satisfied a workflow that did not package:\n${_stdout}${_stderr}")
endif()
file(REMOVE "${BRIDGE_TEST_BINARY_DIR}/skip-package")

# Without a launcher, the coordinator's own CMake runs the producer's workflow preset
# from the expected source directory.
set(_host_producer "${BRIDGE_TEST_BINARY_DIR}/host-workflow-producer")
file(REMOVE_RECURSE "${_host_producer}" "${_collected}")
_distribution_run("${CMAKE_COMMAND}" -S "${_fixture}" -B "${_coordinator}" -G Ninja
    "-DBRIDGE_SOURCE_DIR=${BRIDGE_SOURCE_DIR}" -DFIXTURE_ROLE=coordinator
    "-DFIXTURE_PRODUCER_DIR=${_host_producer}" "-DFIXTURE_OUTPUT_DIR=${_collected}"
    -DFIXTURE_WORKFLOW_LAUNCHER= -DFIXTURE_HOST_WORKFLOW=ON -DFIXTURE_VALIDATOR=)
_distribution_run("${CMAKE_COMMAND}" -E env "FIXTURE_WORKFLOW_BINARY_DIR=${_host_producer}"
    "${CMAKE_COMMAND}" --build "${_coordinator}" --target fixture_distribution)
file(READ "${_collected}/windows-x64/example.zip" _result)
if(NOT _result STREQUAL "host-workflow")
    message(FATAL_ERROR "Host workflow producer was not configured and collected correctly: ${_result}")
endif()
