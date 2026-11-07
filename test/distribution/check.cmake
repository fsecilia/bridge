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
