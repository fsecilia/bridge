# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

file(REMOVE_RECURSE "${BRIDGE_INSTALL_STAGE}")
execute_process(
    COMMAND "${CMAKE_COMMAND}" --install "${BRIDGE_INSTALL_BUILD}" --component standalone
        --prefix "${BRIDGE_INSTALL_STAGE}"
    RESULT_VARIABLE _result
    OUTPUT_VARIABLE _output
    ERROR_VARIABLE _error
)
if(NOT _result EQUAL 0)
    message(FATAL_ERROR "Windows fixture component install failed:\n${_output}${_error}")
endif()

foreach(_file IN ITEMS
    "${BRIDGE_INSTALL_EXECUTABLE}"
    "${BRIDGE_INSTALL_LIBRARY}"
    "libc++.dll"
    "libunwind.dll"
    "audio/replaceable.wav"
    "icons/transparent/32.png"
)
    if(NOT EXISTS "${BRIDGE_INSTALL_STAGE}/${_file}")
        message(FATAL_ERROR "Windows component is missing: ${_file}")
    endif()
endforeach()

foreach(_dll IN ITEMS libc++.dll libunwind.dll)
    file(SHA256 "${BRIDGE_INSTALL_STAGE}/${_dll}" _installed_hash)
    file(SHA256 "${BRIDGE_INSTALL_TOOLCHAIN}/x86_64-w64-mingw32/bin/${_dll}" _source_hash)
    if(NOT _installed_hash STREQUAL _source_hash)
        message(FATAL_ERROR "Compiler runtime differs from its source: ${_dll}")
    endif()
endforeach()
file(SHA256 "${BRIDGE_INSTALL_STAGE}/audio/replaceable.wav" _installed_hash)
file(SHA256 "${BRIDGE_INSTALL_ASSETS}/audio/replaceable.wav" _source_hash)
if(NOT _installed_hash STREQUAL _source_hash)
    message(FATAL_ERROR "Replaceable audio differs from the source")
endif()
if(EXISTS "${BRIDGE_INSTALL_STAGE}/not-standalone.txt")
    message(FATAL_ERROR "Standalone install included an unrelated Steam component")
endif()
