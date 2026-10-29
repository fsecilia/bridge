# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

cmake_minimum_required(VERSION 3.31.6)
project(BridgeApplicationCategoryFixture LANGUAGES NONE)
include("${BRIDGE_SOURCE_DIR}/cmake/BridgeApplication.cmake")

# Only the APK uses the category, so a misspelled one must fail on the host too.
bridge_add_sdl_application(
    TARGET game
    RUN_TARGET game_run
    MAIN_TARGET game_main
    LAUNCHER_SOURCES launcher.cpp
    SDL_TARGET sdl
    SDL_SOURCE_DIR sdl
    APPLICATION_ID org.bridge.fixture
    APPLICATION_NAME Fixture
    APPLICATION_CATEGORY games
)
