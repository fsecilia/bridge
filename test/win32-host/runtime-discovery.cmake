# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

foreach(_required IN ITEMS BRIDGE_SOURCE_DIR BRIDGE_TEST_BINARY_DIR)
    if(NOT DEFINED ${_required} OR "${${_required}}" STREQUAL "")
        message(FATAL_ERROR "${_required} is required")
    endif()
endforeach()
include("${BRIDGE_SOURCE_DIR}/cmake/BridgeWin32Runtime.cmake")

set(CMAKE_CXX_COMPILER_ID Clang)
set(_root "${BRIDGE_TEST_BINARY_DIR}/llvm-mingw")
set(_target_dir "${_root}/x86_64-w64-mingw32/bin")
file(MAKE_DIRECTORY "${_root}/bin" "${_target_dir}")
foreach(_dll IN ITEMS libc++.dll libunwind.dll)
    file(WRITE "${_target_dir}/${_dll}" "test runtime: ${_dll}\n")
endforeach()

foreach(_compiler IN ITEMS x86_64-w64-mingw32-clang++ x86_64-w64-mingw32-clang++.exe clang++.exe)
    set(CMAKE_CXX_COMPILER "${_root}/bin/${_compiler}")
    _bridge_win32_compiler_runtime_dlls(_actual)
    set(_expected "${_target_dir}/libc++.dll;${_target_dir}/libunwind.dll")
    if(NOT "${_actual}" STREQUAL "${_expected}")
        message(FATAL_ERROR "${_compiler}: expected '${_expected}', got '${_actual}'")
    endif()
endforeach()

set(_clang64_bin "${BRIDGE_TEST_BINARY_DIR}/clang64/bin")
file(MAKE_DIRECTORY "${_clang64_bin}")
foreach(_dll IN ITEMS libc++.dll libunwind.dll)
    file(WRITE "${_clang64_bin}/${_dll}" "test runtime: ${_dll}\n")
endforeach()
set(CMAKE_CXX_COMPILER "${_clang64_bin}/clang++.exe")
_bridge_win32_compiler_runtime_dlls(_actual)
set(_expected "${_clang64_bin}/libc++.dll;${_clang64_bin}/libunwind.dll")
if(NOT "${_actual}" STREQUAL "${_expected}")
    message(FATAL_ERROR "CLANG64: expected '${_expected}', got '${_actual}'")
endif()

# A supported compiler with missing libraries must fail rather than silently skip staging.
file(REMOVE "${_clang64_bin}/libunwind.dll")
execute_process(
    COMMAND "${CMAKE_COMMAND}" "-DBRIDGE_SOURCE_DIR=${BRIDGE_SOURCE_DIR}"
        "-DBRIDGE_RUNTIME_MISSING_DIR=${_clang64_bin}" -P "${CMAKE_CURRENT_LIST_DIR}/runtime-missing.cmake"
    RESULT_VARIABLE _result OUTPUT_VARIABLE _stdout ERROR_VARIABLE _stderr
)
if(_result EQUAL 0 OR NOT _stderr MATCHES "LLVM-MinGW runtime DLL is missing")
    message(FATAL_ERROR "Missing runtime did not produce the expected failure:\n${_stdout}${_stderr}")
endif()
