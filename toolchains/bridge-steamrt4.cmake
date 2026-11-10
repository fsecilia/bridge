# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

include("${CMAKE_CURRENT_LIST_DIR}/../cmake/BridgeSteamRT4.cmake")
_bridge_require_steamrt4_sdk("/etc/os-release")

# Consumers can use this identity to choose which host-side development tools to build.
# The target remains native Linux; this toolchain does not enable cross-compilation.
set(BRIDGE_STEAMRT4_SDK TRUE)
