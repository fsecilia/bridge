# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

include_guard(GLOBAL)

# Stages a Windows executable's CMake-managed DLLs and recognized llvm-mingw
# compiler runtimes beside it for build-tree execution. Call from the directory
# that created the executable, after add_executable(). Wine is not required.
function(bridge_stage_win32_runtime)
    set(one_value_args TARGET)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "" "${one_value_args}" "")

    if(ARG_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "bridge_stage_win32_runtime(): unknown arguments: ${ARG_UNPARSED_ARGUMENTS}")
    endif()
    if(ARG_KEYWORDS_MISSING_VALUES)
        message(FATAL_ERROR "bridge_stage_win32_runtime(): missing values for: ${ARG_KEYWORDS_MISSING_VALUES}")
    endif()
    if(NOT ARG_TARGET)
        message(FATAL_ERROR "bridge_stage_win32_runtime(): TARGET is required")
    endif()
    if(NOT CMAKE_SYSTEM_NAME STREQUAL "Windows")
        message(FATAL_ERROR "bridge_stage_win32_runtime() requires a Windows target")
    endif()
    if(NOT TARGET "${ARG_TARGET}")
        message(FATAL_ERROR "bridge_stage_win32_runtime(): TARGET '${ARG_TARGET}' does not exist")
    endif()
    get_target_property(_type "${ARG_TARGET}" TYPE)
    if(NOT _type STREQUAL "EXECUTABLE")
        message(FATAL_ERROR "bridge_stage_win32_runtime(): TARGET '${ARG_TARGET}' must be an executable")
    endif()

    set(_compiler_runtime_dlls "")
    get_filename_component(_compiler_name "${CMAKE_CXX_COMPILER}" NAME)
    if(_compiler_name MATCHES "^([A-Za-z0-9_]+-w64-mingw32)-clang\\+\\+$")
        set(_target_triplet "${CMAKE_MATCH_1}")
        cmake_path(GET CMAKE_CXX_COMPILER PARENT_PATH _compiler_bin)
        cmake_path(GET _compiler_bin PARENT_PATH _toolchain_root)

        foreach(_dll IN ITEMS libc++.dll libunwind.dll)
            set(_path "${_toolchain_root}/${_target_triplet}/bin/${_dll}")
            if(NOT EXISTS "${_path}")
                message(FATAL_ERROR "LLVM-MinGW runtime DLL is missing: ${_path}")
            endif()
            list(APPEND _compiler_runtime_dlls "${_path}")
        endforeach()
    endif()

    add_custom_command(
        TARGET "${ARG_TARGET}"
        POST_BUILD
        COMMAND
            "${CMAKE_COMMAND}" -E copy -t
            "$<TARGET_FILE_DIR:${ARG_TARGET}>"
            "$<TARGET_RUNTIME_DLLS:${ARG_TARGET}>"
            ${_compiler_runtime_dlls}
        COMMAND_EXPAND_LISTS
        VERBATIM
    )
endfunction()
