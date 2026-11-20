# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

foreach(_required IN ITEMS BRIDGE_SOURCE_DIR BRIDGE_TEST_BINARY_DIR BRIDGE_TEST_GENERATOR)
    if(NOT DEFINED ${_required} OR "${${_required}}" STREQUAL "")
        message(FATAL_ERROR "${_required} is required")
    endif()
endforeach()

execute_process(
    COMMAND "${CMAKE_COMMAND}" -S "${BRIDGE_SOURCE_DIR}/test/win32-host"
        -B "${BRIDGE_TEST_BINARY_DIR}" -G "${BRIDGE_TEST_GENERATOR}" "-DBRIDGE_SOURCE_DIR=${BRIDGE_SOURCE_DIR}"
    RESULT_VARIABLE _configure_result OUTPUT_VARIABLE _configure_out ERROR_VARIABLE _configure_err
)
if(NOT _configure_result EQUAL 0)
    message(FATAL_ERROR "Native Windows launch fixture did not configure:\n${_configure_out}${_configure_err}")
endif()
execute_process(
    COMMAND "${CMAKE_COMMAND}" --build "${BRIDGE_TEST_BINARY_DIR}"
        --target bridge_win32_host_launch --config "${BRIDGE_TEST_CONFIGURATION}"
    RESULT_VARIABLE _build_result OUTPUT_VARIABLE _build_out ERROR_VARIABLE _build_err
)
if(NOT _build_result EQUAL 0)
    message(FATAL_ERROR "Native Windows launch fixture did not execute:\n${_build_out}${_build_err}")
endif()
if(_build_out MATCHES "Wine|wine|Bridge Win32 execution unavailable")
    message(FATAL_ERROR "Native Windows launch unexpectedly selected the Wine runner:\n${_build_out}")
endif()
