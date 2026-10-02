# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

# Setting the target system explicitly makes CMake exercise its cross-compiling
# execution path while retaining the host ABI for this focused plumbing test.
set(CMAKE_SYSTEM_NAME "${CMAKE_HOST_SYSTEM_NAME}")
set(CMAKE_SYSTEM_VERSION "${CMAKE_HOST_SYSTEM_VERSION}")
set(CMAKE_SYSTEM_PROCESSOR "${CMAKE_HOST_SYSTEM_PROCESSOR}")
set(
    CMAKE_CROSSCOMPILING_EMULATOR
    "${CMAKE_COMMAND};-P;${CMAKE_CURRENT_LIST_DIR}/emulator.cmake;--"
)
