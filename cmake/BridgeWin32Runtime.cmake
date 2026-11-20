# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

include_guard(GLOBAL)

# Resolves the LLVM-MinGW compiler DLLs needed by both cross-compiled and native Windows applications.
# Native LLVM-MinGW keeps its target DLLs under <root>/x86_64-w64-mingw32/bin; MSYS2 CLANG64 keeps them
# beside clang++. Never assume the developer shell's PATH will be present when running from an IDE.
function(_bridge_win32_compiler_runtime_dlls OUT_DLLS)
    set(_compiler_runtime_dlls "")
    get_filename_component(_compiler_name "${CMAKE_CXX_COMPILER}" NAME)
    cmake_path(GET CMAKE_CXX_COMPILER PARENT_PATH _compiler_bin)
    cmake_path(GET _compiler_bin PARENT_PATH _toolchain_root)

    if(_compiler_name MATCHES "^([A-Za-z0-9_]+-w64-mingw32)-clang\\+\\+(\\.exe)?$")
        set(_runtime_dir "${_toolchain_root}/${CMAKE_MATCH_1}/bin")
    elseif(_compiler_name MATCHES "^clang\\+\\+(\\.exe)?$" AND CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
        set(_llvm_mingw_dir "${_toolchain_root}/x86_64-w64-mingw32/bin")
        if(EXISTS "${_llvm_mingw_dir}/libc++.dll")
            set(_runtime_dir "${_llvm_mingw_dir}")
        else()
            set(_runtime_dir "${_compiler_bin}")
        endif()
    elseif(CMAKE_CXX_COMPILER_ID STREQUAL "Clang" AND CMAKE_SYSTEM_NAME STREQUAL "Windows")
        message(FATAL_ERROR
            "Unsupported Windows Clang driver '${_compiler_name}'; Bridge cannot locate its runtime DLLs"
        )
    else()
        set(${OUT_DLLS} "" PARENT_SCOPE)
        return()
    endif()

    foreach(_dll IN ITEMS libc++.dll libunwind.dll)
        set(_path "${_runtime_dir}/${_dll}")
        if(NOT EXISTS "${_path}")
            message(FATAL_ERROR "LLVM-MinGW runtime DLL is missing: ${_path}")
        endif()
        list(APPEND _compiler_runtime_dlls "${_path}")
    endforeach()

    set(${OUT_DLLS} "${_compiler_runtime_dlls}" PARENT_SCOPE)
endfunction()

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

    _bridge_win32_compiler_runtime_dlls(_compiler_runtime_dlls)

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
