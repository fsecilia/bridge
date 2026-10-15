# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

cmake_minimum_required(VERSION 3.31.6)
project(BridgeIconColorFixture LANGUAGES NONE)
include("${BRIDGE_SOURCE_DIR}/cmake/BridgeApplication.cmake")

# Android needs the adaptive background color, so it is required everywhere.
bridge_add_sdl_application(
    TARGET game
    RUN_TARGET game_run
    MAIN_TARGET game_main
    LAUNCHER_SOURCES launcher.cpp
    SDL_TARGET sdl
    SDL_SOURCE_DIR sdl
    APPLICATION_ID org.bridge.fixture
    APPLICATION_NAME Fixture
    ICON_DIRECTORY icons
)
