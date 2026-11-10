# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

if(NOT DEFINED BRIDGE_CANON_MODULE OR NOT EXISTS "${BRIDGE_CANON_MODULE}")
    message(FATAL_ERROR "Bridge test fixture requires BRIDGE_CANON_MODULE to name an existing Canon.cmake")
endif()
include("${BRIDGE_CANON_MODULE}")
