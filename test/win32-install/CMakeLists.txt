# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

include("${PROJECT_SOURCE_DIR}/cmake/BridgeWin32Install.cmake")

# Exercise Windows install mechanics with native-built fixture targets. This
# checks CMake component and file layout without claiming Windows execution.
add_library(bridge_win32_install_runtime SHARED runtime.cpp)
add_executable(bridge_win32_install_fixture main.cpp)
target_link_libraries(bridge_win32_install_fixture PRIVATE bridge_win32_install_runtime)

set(_assets "${CMAKE_CURRENT_BINARY_DIR}/assets")
set(_icons "${CMAKE_CURRENT_BINARY_DIR}/icons")
file(MAKE_DIRECTORY "${_assets}/audio" "${_icons}/transparent")
file(WRITE "${_assets}/audio/replaceable.wav" "replaceable fixture audio\n")
file(WRITE "${_icons}/transparent/32.png" "fixture icon\n")

# Supply fixture compiler runtime DLLs. Only the install-helper's discovery
# sees the synthetic compiler path; real targets retain the configured compiler.
set(_toolchain "${CMAKE_CURRENT_BINARY_DIR}/fake-toolchain")
file(MAKE_DIRECTORY "${_toolchain}/bin" "${_toolchain}/x86_64-w64-mingw32/bin")
foreach(_dll IN ITEMS libc++.dll libunwind.dll)
    file(WRITE "${_toolchain}/x86_64-w64-mingw32/bin/${_dll}" "${_dll} fixture\n")
endforeach()
set(_compiler "${CMAKE_CXX_COMPILER}")
set(_system "${CMAKE_SYSTEM_NAME}")
set(CMAKE_CXX_COMPILER "${_toolchain}/bin/x86_64-w64-mingw32-clang++")
set(CMAKE_SYSTEM_NAME Windows)
bridge_install_win32_application(
    TARGET bridge_win32_install_fixture
    COMPONENT standalone
    RUNTIME_TARGETS bridge_win32_install_runtime
    ASSET_DIRECTORY "${_assets}"
    ICON_DIRECTORY "${_icons}"
)
set(CMAKE_CXX_COMPILER "${_compiler}")
set(CMAKE_SYSTEM_NAME "${_system}")

file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/not-standalone.txt" "separate component\n")
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/not-standalone.txt" DESTINATION "." COMPONENT steam)

add_test(
    NAME bridge.win32.install.component
    COMMAND "${CMAKE_COMMAND}"
        "-DBRIDGE_INSTALL_BUILD=${PROJECT_BINARY_DIR}"
        "-DBRIDGE_INSTALL_STAGE=${CMAKE_CURRENT_BINARY_DIR}/installed"
        "-DBRIDGE_INSTALL_EXECUTABLE=$<TARGET_FILE_NAME:bridge_win32_install_fixture>"
        "-DBRIDGE_INSTALL_LIBRARY=$<TARGET_FILE_NAME:bridge_win32_install_runtime>"
        "-DBRIDGE_INSTALL_ASSETS=${_assets}"
        "-DBRIDGE_INSTALL_TOOLCHAIN=${_toolchain}"
        -P "${CMAKE_CURRENT_SOURCE_DIR}/check.cmake"
)
set_tests_properties(bridge.win32.install.component PROPERTIES LABELS "win32;packaging;install")

# CPack must stage this component itself. No pre-install step is part of the
# package target, so the test can catch accidental reliance on DESTDIR.
set(CPACK_GENERATOR ZIP)
set(CPACK_PACKAGE_NAME BridgeWin32Fixture)
set(CPACK_PACKAGE_VERSION 1.0.0)
set(CPACK_PACKAGE_FILE_NAME BridgeWin32Fixture-1.0.0)
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "Bridge Windows component test")
set(CPACK_INSTALL_CMAKE_PROJECTS "${PROJECT_BINARY_DIR};${PROJECT_NAME};standalone;/")
set(CPACK_OUTPUT_CONFIG_FILE "${CMAKE_CURRENT_BINARY_DIR}/CPackTestConfig.cmake")
include(CPack)
add_test(
    NAME bridge.win32.install.cpack-zip
    COMMAND "${CMAKE_COMMAND}"
        "-DBRIDGE_CPACK_CONFIG=${CPACK_OUTPUT_CONFIG_FILE}"
        "-DBRIDGE_CPACK_BINARY=${CMAKE_CPACK_COMMAND}"
        "-DBRIDGE_CPACK_TEST_DIR=${CMAKE_CURRENT_BINARY_DIR}/cpack-test"
        -P "${CMAKE_CURRENT_SOURCE_DIR}/check-zip.cmake"
)
set_tests_properties(bridge.win32.install.cpack-zip PROPERTIES LABELS "win32;packaging;install")
