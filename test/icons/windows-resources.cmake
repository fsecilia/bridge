# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

if(NOT DEFINED BRIDGE_ICON_SOURCE OR NOT DEFINED BRIDGE_GENERATED_RC)
    message(FATAL_ERROR "Set BRIDGE_ICON_SOURCE and BRIDGE_GENERATED_RC")
endif()

# Exercise the Windows branch of the icon validator on any host without requiring a compiler or Python.
set(WIN32 TRUE)
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/BridgeApplicationIcons.cmake")
_bridge_validate_icon_directory("${BRIDGE_ICON_SOURCE}" _icons _python _dependencies)
if(NOT "${_python}" STREQUAL "")
    message(FATAL_ERROR "Windows icon validation unexpectedly requires Python: ${_python}")
endif()
_bridge_write_png_icon_resources("${_icons}" "${BRIDGE_GENERATED_RC}" _pngs)
