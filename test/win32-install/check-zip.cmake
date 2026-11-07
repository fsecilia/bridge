# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

file(REMOVE_RECURSE "${BRIDGE_CPACK_TEST_DIR}")
file(MAKE_DIRECTORY "${BRIDGE_CPACK_TEST_DIR}")
execute_process(
    COMMAND "${BRIDGE_CPACK_BINARY}" --config "${BRIDGE_CPACK_CONFIG}" -G ZIP
        -B "${BRIDGE_CPACK_TEST_DIR}"
    RESULT_VARIABLE _result
    OUTPUT_VARIABLE _output
    ERROR_VARIABLE _error
)
if(NOT _result EQUAL 0)
    message(FATAL_ERROR "CPack ZIP failed:\n${_output}${_error}")
endif()
set(_zip "${BRIDGE_CPACK_TEST_DIR}/BridgeWin32Fixture-1.0.0.zip")
if(NOT EXISTS "${_zip}")
    message(FATAL_ERROR "CPack did not create ${_zip}")
endif()
set(_extracted "${BRIDGE_CPACK_TEST_DIR}/unpacked")
file(MAKE_DIRECTORY "${_extracted}")
file(ARCHIVE_EXTRACT INPUT "${_zip}" DESTINATION "${_extracted}")
set(_package "${_extracted}/BridgeWin32Fixture-1.0.0")
foreach(_item IN ITEMS
    "audio/replaceable.wav"
    "icons/transparent/32.png"
    "libc++.dll"
    "libunwind.dll"
)
    if(NOT EXISTS "${_package}/${_item}")
        message(FATAL_ERROR "CPack ZIP is missing: ${_item}")
    endif()
endforeach()
if(EXISTS "${_package}/not-standalone.txt")
    message(FATAL_ERROR "CPack ZIP included the unrelated Steam component")
endif()
