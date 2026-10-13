# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

include("${PROJECT_SOURCE_DIR}/cmake/BridgeNativeTest.cmake")

set(_bridge_assets "${CMAKE_CURRENT_BINARY_DIR}/runtime assets")
file(MAKE_DIRECTORY "${_bridge_assets}/fixtures")
file(WRITE "${_bridge_assets}/fixtures/expected.txt" "Bridge native asset\n")

add_executable(bridge_native_test_specimen specimen.cpp)
target_compile_features(bridge_native_test_specimen PRIVATE cxx_std_26)
canon_apply_target(bridge_native_test_specimen)

bridge_add_native_test(
    NAME bridge.native-test.assets
    TARGET bridge_native_test_specimen
    ASSET_DIRECTORY "${_bridge_assets}"
    ARGS "two words" "single'quote"
)
set_tests_properties(bridge.native-test.assets PROPERTIES LABELS "runner;native-test")
