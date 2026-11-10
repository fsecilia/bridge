# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

include("${BRIDGE_SOURCE_DIR}/test/canon/load.cmake")
include("${BRIDGE_SOURCE_DIR}/cmake/BridgeSDL.cmake")
add_library(sdl SHARED IMPORTED)
add_library(SDL3::SDL3 ALIAS sdl)
set_property(TARGET sdl PROPERTY SDL_FULL_VERSION "3.4.18")
bridge_require_sdl(VERSION "3.2.0...<4.0")
