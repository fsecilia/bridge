# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

# Desktop applications built through BridgeApplication.cmake. Each program
# checks, when it runs, that its assets and icons were staged beside it.

include("${PROJECT_SOURCE_DIR}/cmake/BridgeApplication.cmake")
include("${PROJECT_SOURCE_DIR}/cmake/BridgeNativeTest.cmake")

set(_bridge_assets "${CMAKE_CURRENT_BINARY_DIR}/runtime assets")
file(MAKE_DIRECTORY "${_bridge_assets}/fixtures")
file(WRITE "${_bridge_assets}/fixtures/expected.txt" "Bridge application asset\n")

set(_bridge_icons "${CMAKE_CURRENT_BINARY_DIR}/icons")
execute_process(
    COMMAND "${Python3_EXECUTABLE}" "${CMAKE_CURRENT_SOURCE_DIR}/make_icons.py" "${_bridge_icons}"
    RESULT_VARIABLE _bridge_icons_result
    ERROR_VARIABLE _bridge_icons_error
)
if(NOT _bridge_icons_result EQUAL 0)
    message(FATAL_ERROR "Bridge application fixture icons could not be generated:\n${_bridge_icons_error}")
endif()

# All programs share one output directory, so they share one staging target.
# Each requests only part of the runtime tree, and each still finds all of it.
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/programs")
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/programs")

add_library(bridge_application_sdl SHARED sdl.cpp)
add_library(bridge_application_main SHARED main.cpp)
target_compile_features(bridge_application_main PRIVATE cxx_std_26)
target_link_libraries(bridge_application_main PRIVATE bridge_application_sdl)

bridge_add_sdl_application(
    TARGET bridge_application_game
    RUN_TARGET bridge_application_game_run
    MAIN_TARGET bridge_application_main
    LAUNCHER_SOURCES launcher.cpp
    SDL_TARGET bridge_application_sdl
    SDL_SOURCE_DIR "${PROJECT_SOURCE_DIR}/external/sdl3"
    APPLICATION_ID org.bridge.application.game
    APPLICATION_NAME "Bridge Application Game"
    ASSET_DIRECTORY "${_bridge_assets}"
    ICON_DIRECTORY "${_bridge_icons}"
    ADAPTIVE_ICON_BACKGROUND_COLOR "#102030"
    DESKTOP_CATEGORIES "Game;Utility"
)
bridge_add_sdl_application(
    TARGET bridge_application_second
    RUN_TARGET bridge_application_second_run
    MAIN_TARGET bridge_application_main
    LAUNCHER_SOURCES launcher.cpp
    SDL_TARGET bridge_application_sdl
    SDL_SOURCE_DIR "${PROJECT_SOURCE_DIR}/external/sdl3"
    APPLICATION_ID org.bridge.application.second
    APPLICATION_NAME "Bridge Application Second"
    ASSET_DIRECTORY "${_bridge_assets}"
)
add_executable(bridge_application_tool launcher.cpp)
target_link_libraries(bridge_application_tool PRIVATE bridge_application_main)
bridge_stage_runtime(TARGET bridge_application_tool ICON_DIRECTORY "${_bridge_icons}")

foreach(_bridge_target IN ITEMS bridge_application_game_run bridge_application_second_run)
    if(NOT TARGET "${_bridge_target}")
        message(FATAL_ERROR "Bridge application fixture: run target '${_bridge_target}' was not created")
    endif()
endforeach()
foreach(_bridge_target IN ITEMS bridge_application_game bridge_application_second bridge_application_tool)
    get_target_property(_bridge_dependencies "${_bridge_target}" MANUALLY_ADDED_DEPENDENCIES)
    if(NOT "bridge_application_game_runtime_assets" IN_LIST _bridge_dependencies)
        message(
            FATAL_ERROR
            "Bridge application fixture: '${_bridge_target}' does not use the shared staging target; "
            "dependencies: ${_bridge_dependencies}"
        )
    endif()
endforeach()
if(TARGET bridge_application_second_runtime_assets OR TARGET bridge_application_tool_runtime_assets)
    message(FATAL_ERROR "Bridge application fixture: a shared output directory got a second staging target")
endif()
if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    file(READ "${CMAKE_CURRENT_BINARY_DIR}/org.bridge.application.game.desktop" _bridge_desktop)
    if(NOT _bridge_desktop MATCHES "\nCategories=Game;Utility;\n")
        message(FATAL_ERROR "Bridge application fixture: desktop entry lost its categories:\n${_bridge_desktop}")
    endif()
endif()

foreach(_bridge_program IN ITEMS game second tool)
    bridge_add_native_test(
        NAME "bridge.application.${_bridge_program}"
        TARGET "bridge_application_${_bridge_program}"
        RUNTIME_TARGETS bridge_application_main bridge_application_sdl
    )
    set_tests_properties("bridge.application.${_bridge_program}" PROPERTIES LABELS "application")
endforeach()
