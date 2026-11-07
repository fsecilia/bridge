# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

if(NOT DEFINED BRIDGE_EXECUTION_REASON OR BRIDGE_EXECUTION_REASON STREQUAL "")
    set(BRIDGE_EXECUTION_REASON "no Windows execution backend was configured")
endif()
message(FATAL_ERROR "Bridge Win32 test execution unavailable: ${BRIDGE_EXECUTION_REASON}")
