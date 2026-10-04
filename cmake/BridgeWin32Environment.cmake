# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

include_guard(GLOBAL)

function(_bridge_validate_llvm_mingw_root
    ROOT
    OUT_VALID
    OUT_C_COMPILER
    OUT_CXX_COMPILER
    OUT_RUNTIME_DIR
    OUT_REASON)
    if (NOT IS_ABSOLUTE "${ROOT}")
        set(${OUT_VALID} FALSE PARENT_SCOPE)
        set(${OUT_C_COMPILER} "" PARENT_SCOPE)
        set(${OUT_CXX_COMPILER} "" PARENT_SCOPE)
        set(${OUT_RUNTIME_DIR} "" PARENT_SCOPE)
        set(${OUT_REASON} "LLVM-MinGW root must be an absolute path: ${ROOT}" PARENT_SCOPE)
        return()
    endif()

    set(_c_compiler "${ROOT}/bin/x86_64-w64-mingw32-clang")
    set(_cxx_compiler "${ROOT}/bin/x86_64-w64-mingw32-clang++")
    if (NOT EXISTS "${_c_compiler}")
        set(${OUT_VALID} FALSE PARENT_SCOPE)
        set(${OUT_C_COMPILER} "" PARENT_SCOPE)
        set(${OUT_CXX_COMPILER} "" PARENT_SCOPE)
        set(${OUT_RUNTIME_DIR} "" PARENT_SCOPE)
        set(${OUT_REASON} "LLVM-MinGW C compiler not found: ${_c_compiler}" PARENT_SCOPE)
        return()
    endif()
    if (NOT EXISTS "${_cxx_compiler}")
        set(${OUT_VALID} FALSE PARENT_SCOPE)
        set(${OUT_C_COMPILER} "" PARENT_SCOPE)
        set(${OUT_CXX_COMPILER} "" PARENT_SCOPE)
        set(${OUT_RUNTIME_DIR} "" PARENT_SCOPE)
        set(${OUT_REASON} "LLVM-MinGW C++ compiler not found: ${_cxx_compiler}" PARENT_SCOPE)
        return()
    endif()

    execute_process(
        COMMAND "${_cxx_compiler}" -print-file-name=crt2.o
        RESULT_VARIABLE _crt_result
        OUTPUT_VARIABLE _crt_path
        ERROR_VARIABLE _crt_error
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_STRIP_TRAILING_WHITESPACE
    )
    if (NOT "${_crt_result}" STREQUAL "0")
        set(${OUT_VALID} FALSE PARENT_SCOPE)
        set(${OUT_C_COMPILER} "" PARENT_SCOPE)
        set(${OUT_CXX_COMPILER} "" PARENT_SCOPE)
        set(${OUT_RUNTIME_DIR} "" PARENT_SCOPE)
        set(${OUT_REASON}
            "LLVM-MinGW compiler could not locate its Windows CRT: ${_crt_error}"
            PARENT_SCOPE)
        return()
    endif()
    if ("${_crt_path}" STREQUAL "crt2.o" OR NOT EXISTS "${_crt_path}")
        set(${OUT_VALID} FALSE PARENT_SCOPE)
        set(${OUT_C_COMPILER} "" PARENT_SCOPE)
        set(${OUT_CXX_COMPILER} "" PARENT_SCOPE)
        set(${OUT_RUNTIME_DIR} "" PARENT_SCOPE)
        set(${OUT_REASON}
            "LLVM-MinGW target environment is incomplete; clang++ could not locate crt2.o"
            PARENT_SCOPE)
        return()
    endif()

    set(_runtime_dir "${ROOT}/x86_64-w64-mingw32/bin")
    foreach(_runtime_dll IN ITEMS libc++.dll libunwind.dll)
        if (NOT EXISTS "${_runtime_dir}/${_runtime_dll}")
            set(${OUT_VALID} FALSE PARENT_SCOPE)
            set(${OUT_C_COMPILER} "" PARENT_SCOPE)
            set(${OUT_CXX_COMPILER} "" PARENT_SCOPE)
            set(${OUT_RUNTIME_DIR} "" PARENT_SCOPE)
            set(${OUT_REASON}
                "LLVM-MinGW runtime DLL not found: ${_runtime_dir}/${_runtime_dll}"
                PARENT_SCOPE)
            return()
        endif()
    endforeach()

    set(${OUT_VALID} TRUE PARENT_SCOPE)
    set(${OUT_C_COMPILER} "${_c_compiler}" PARENT_SCOPE)
    set(${OUT_CXX_COMPILER} "${_cxx_compiler}" PARENT_SCOPE)
    set(${OUT_RUNTIME_DIR} "${_runtime_dir}" PARENT_SCOPE)
    set(${OUT_REASON} "" PARENT_SCOPE)
endfunction()

function(_bridge_find_win32_environment
    OUT_AVAILABLE
    OUT_ROOT
    OUT_C_COMPILER
    OUT_CXX_COMPILER
    OUT_RUNTIME_DIR
    OUT_WINE
    OUT_WINEPATH
    OUT_REASON)
    if (NOT "${CMAKE_HOST_SYSTEM_NAME}" STREQUAL "Linux")
        set(${OUT_AVAILABLE} FALSE PARENT_SCOPE)
        set(${OUT_ROOT} "" PARENT_SCOPE)
        set(${OUT_C_COMPILER} "" PARENT_SCOPE)
        set(${OUT_CXX_COMPILER} "" PARENT_SCOPE)
        set(${OUT_RUNTIME_DIR} "" PARENT_SCOPE)
        set(${OUT_WINE} "" PARENT_SCOPE)
        set(${OUT_WINEPATH} "" PARENT_SCOPE)
        set(${OUT_REASON}
            "Win32 cross execution is supported only from a Linux host in this prototype"
            PARENT_SCOPE)
        return()
    endif()

    set(_explicit_root "")
    if (DEFINED BRIDGE_LLVM_MINGW_ROOT AND NOT "${BRIDGE_LLVM_MINGW_ROOT}" STREQUAL "")
        set(_explicit_root "${BRIDGE_LLVM_MINGW_ROOT}")
    elseif(DEFINED ENV{BRIDGE_LLVM_MINGW_ROOT}
        AND NOT "$ENV{BRIDGE_LLVM_MINGW_ROOT}" STREQUAL "")
        set(_explicit_root "$ENV{BRIDGE_LLVM_MINGW_ROOT}")
    endif()

    set(_root "")
    set(_c_compiler "")
    set(_cxx_compiler "")
    set(_runtime_dir "")
    set(_reason "")

    if (NOT "${_explicit_root}" STREQUAL "")
        _bridge_validate_llvm_mingw_root(
            "${_explicit_root}"
            _valid
            _c_compiler
            _cxx_compiler
            _runtime_dir
            _reason
        )
        if (NOT _valid)
            set(${OUT_AVAILABLE} FALSE PARENT_SCOPE)
            set(${OUT_ROOT} "" PARENT_SCOPE)
            set(${OUT_C_COMPILER} "" PARENT_SCOPE)
            set(${OUT_CXX_COMPILER} "" PARENT_SCOPE)
            set(${OUT_RUNTIME_DIR} "" PARENT_SCOPE)
            set(${OUT_WINE} "" PARENT_SCOPE)
            set(${OUT_WINEPATH} "" PARENT_SCOPE)
            set(${OUT_REASON} "${_reason}" PARENT_SCOPE)
            return()
        endif()
        set(_root "${_explicit_root}")
    else()
        set(_candidate_roots /opt/llvm-mingw)

        find_program(
            _path_cxx_compiler
            NAMES x86_64-w64-mingw32-clang++
            NO_CACHE
        )
        if (_path_cxx_compiler)
            cmake_path(GET _path_cxx_compiler PARENT_PATH _path_bin)
            cmake_path(GET _path_bin PARENT_PATH _path_root)
            list(PREPEND _candidate_roots "${_path_root}")
        endif()

        foreach(_candidate_root IN LISTS _candidate_roots)
            _bridge_validate_llvm_mingw_root(
                "${_candidate_root}"
                _valid
                _candidate_c_compiler
                _candidate_cxx_compiler
                _candidate_runtime_dir
                _candidate_reason
            )
            if (_valid)
                set(_root "${_candidate_root}")
                set(_c_compiler "${_candidate_c_compiler}")
                set(_cxx_compiler "${_candidate_cxx_compiler}")
                set(_runtime_dir "${_candidate_runtime_dir}")
                break()
            endif()
        endforeach()

        if ("${_root}" STREQUAL "")
            set(${OUT_AVAILABLE} FALSE PARENT_SCOPE)
            set(${OUT_ROOT} "" PARENT_SCOPE)
            set(${OUT_C_COMPILER} "" PARENT_SCOPE)
            set(${OUT_CXX_COMPILER} "" PARENT_SCOPE)
            set(${OUT_RUNTIME_DIR} "" PARENT_SCOPE)
            set(${OUT_WINE} "" PARENT_SCOPE)
            set(${OUT_WINEPATH} "" PARENT_SCOPE)
            set(${OUT_REASON}
                "LLVM-MinGW was not found; set BRIDGE_LLVM_MINGW_ROOT or install it at /opt/llvm-mingw"
                PARENT_SCOPE)
            return()
        endif()
    endif()

    find_program(_wine NAMES wine NO_CACHE)
    if (NOT _wine)
        set(${OUT_AVAILABLE} FALSE PARENT_SCOPE)
        set(${OUT_ROOT} "${_root}" PARENT_SCOPE)
        set(${OUT_C_COMPILER} "${_c_compiler}" PARENT_SCOPE)
        set(${OUT_CXX_COMPILER} "${_cxx_compiler}" PARENT_SCOPE)
        set(${OUT_RUNTIME_DIR} "${_runtime_dir}" PARENT_SCOPE)
        set(${OUT_WINE} "" PARENT_SCOPE)
        set(${OUT_WINEPATH} "" PARENT_SCOPE)
        set(${OUT_REASON} "Wine was not found on PATH" PARENT_SCOPE)
        return()
    endif()

    find_program(_winepath NAMES winepath NO_CACHE)
    if (NOT _winepath)
        set(${OUT_AVAILABLE} FALSE PARENT_SCOPE)
        set(${OUT_ROOT} "${_root}" PARENT_SCOPE)
        set(${OUT_C_COMPILER} "${_c_compiler}" PARENT_SCOPE)
        set(${OUT_CXX_COMPILER} "${_cxx_compiler}" PARENT_SCOPE)
        set(${OUT_RUNTIME_DIR} "${_runtime_dir}" PARENT_SCOPE)
        set(${OUT_WINE} "${_wine}" PARENT_SCOPE)
        set(${OUT_WINEPATH} "" PARENT_SCOPE)
        set(${OUT_REASON} "winepath was not found on PATH" PARENT_SCOPE)
        return()
    endif()

    set(${OUT_AVAILABLE} TRUE PARENT_SCOPE)
    set(${OUT_ROOT} "${_root}" PARENT_SCOPE)
    set(${OUT_C_COMPILER} "${_c_compiler}" PARENT_SCOPE)
    set(${OUT_CXX_COMPILER} "${_cxx_compiler}" PARENT_SCOPE)
    set(${OUT_RUNTIME_DIR} "${_runtime_dir}" PARENT_SCOPE)
    set(${OUT_WINE} "${_wine}" PARENT_SCOPE)
    set(${OUT_WINEPATH} "${_winepath}" PARENT_SCOPE)
    set(${OUT_REASON} "" PARENT_SCOPE)
endfunction()
