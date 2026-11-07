# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

include("${BRIDGE_SOURCE_DIR}/cmake/BridgeWin32Environment.cmake")

set(_root "${BRIDGE_TEST_BINARY_DIR}/llvm-mingw")
file(REMOVE_RECURSE "${BRIDGE_TEST_BINARY_DIR}")
file(MAKE_DIRECTORY "${_root}/bin" "${_root}/x86_64-w64-mingw32/bin")
file(WRITE "${_root}/x86_64-w64-mingw32/bin/crt2.o" "fixture CRT\n")
foreach(_dll IN ITEMS libc++.dll libunwind.dll)
    file(WRITE "${_root}/x86_64-w64-mingw32/bin/${_dll}" "fixture ${_dll}\n")
endforeach()
file(WRITE "${_root}/bin/x86_64-w64-mingw32-clang" "#!/bin/sh\nexit 0\n")
file(WRITE "${_root}/bin/x86_64-w64-mingw32-clang++"
    "#!/bin/sh\nprintf '%s\\n' '${_root}/x86_64-w64-mingw32/bin/crt2.o'\n")
file(CHMOD "${_root}/bin/x86_64-w64-mingw32-clang"
    "${_root}/bin/x86_64-w64-mingw32-clang++"
    PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)

set(BRIDGE_LLVM_MINGW_ROOT "${_root}")
# A macOS coordinator must be able to discover the compiler even without Wine.
set(CMAKE_HOST_SYSTEM_NAME Darwin)
_bridge_find_win32_environment(_available _found_root _cc _cxx _runtime _wine _winepath _reason)
if(NOT _available OR NOT _found_root STREQUAL _root OR NOT _reason STREQUAL "")
    message(FATAL_ERROR "LLVM-MinGW toolchain discovery unexpectedly failed on macOS: ${_reason}")
endif()
if(_wine OR _winepath)
    message(FATAL_ERROR "Toolchain discovery unexpectedly tied compiler availability to Wine")
endif()

# Reject a broken toolchain rather than accepting a plausible-looking compiler.
file(REMOVE "${_root}/x86_64-w64-mingw32/bin/libunwind.dll")
_bridge_find_win32_environment(_available _found_root _cc _cxx _runtime _wine _winepath _reason)
if(_available OR NOT _reason MATCHES "libunwind.dll")
    message(FATAL_ERROR "Broken LLVM-MinGW did not fail clearly: ${_reason}")
endif()

# Wine is a separate capability. Test both absence and presence without using
# the machine's PATH, so the fixture is deterministic on developer machines.
set(CMAKE_FIND_USE_SYSTEM_ENVIRONMENT_PATH FALSE)
set(CMAKE_FIND_USE_CMAKE_SYSTEM_PATH FALSE)
set(CMAKE_PROGRAM_PATH "${_root}/bin")
_bridge_find_win32_execution_environment(_can_run _wine _winepath _reason)
if(_can_run OR NOT _reason MATCHES "Wine was not found")
    message(FATAL_ERROR "Missing Wine should prevent execution, not compilation: ${_reason}")
endif()
foreach(_program IN ITEMS wine winepath)
    file(WRITE "${_root}/bin/${_program}" "#!/bin/sh\nexit 0\n")
    file(CHMOD "${_root}/bin/${_program}"
        PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
endforeach()
_bridge_find_win32_execution_environment(_can_run _wine _winepath _reason)
if(NOT _can_run OR NOT _wine OR NOT _winepath OR _reason)
    message(FATAL_ERROR "Complete Wine backend was not discovered: ${_reason}")
endif()
