# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

add_executable(bridge_canon_specimen canon.cpp)
canon_apply_target(bridge_canon_specimen)

add_test(
    NAME bridge.integration.canon
    COMMAND bridge_canon_specimen
)
set_tests_properties(bridge.integration.canon PROPERTIES LABELS integration)
