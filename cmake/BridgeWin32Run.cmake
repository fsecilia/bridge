# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

include_guard(GLOBAL)

include("${CMAKE_CURRENT_LIST_DIR}/BridgeWin32Environment.cmake")

function(bridge_add_win32_run_target)
    set(one_value_args TARGET APPLICATION_TARGET)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "" "${one_value_args}" "")

    if(ARG_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "bridge_add_win32_run_target(): unknown arguments: ${ARG_UNPARSED_ARGUMENTS}")
    endif()
    if(ARG_KEYWORDS_MISSING_VALUES)
        message(FATAL_ERROR "bridge_add_win32_run_target(): missing values for: ${ARG_KEYWORDS_MISSING_VALUES}")
    endif()
    foreach(_required IN ITEMS TARGET APPLICATION_TARGET)
        if(NOT ARG_${_required})
            message(FATAL_ERROR "bridge_add_win32_run_target(): ${_required} is required")
        endif()
    endforeach()

    if(NOT CMAKE_SYSTEM_NAME STREQUAL "Windows")
        message(FATAL_ERROR "bridge_add_win32_run_target() requires a Windows target")
    endif()
    if(TARGET "${ARG_TARGET}")
        message(FATAL_ERROR "bridge_add_win32_run_target(): target '${ARG_TARGET}' already exists")
    endif()
    if(NOT TARGET "${ARG_APPLICATION_TARGET}")
        message(FATAL_ERROR
            "bridge_add_win32_run_target(): APPLICATION_TARGET '${ARG_APPLICATION_TARGET}' does not exist"
        )
    endif()
    get_target_property(_type "${ARG_APPLICATION_TARGET}" TYPE)
    if(NOT _type STREQUAL "EXECUTABLE")
        message(FATAL_ERROR
            "bridge_add_win32_run_target(): APPLICATION_TARGET '${ARG_APPLICATION_TARGET}' must be an executable"
        )
    endif()

    set(_runner "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/../runner/bridge-win32.sh")
    if(NOT EXISTS "${_runner}")
        message(FATAL_ERROR "Bridge Win32 runner not found: ${_runner}")
    endif()

    _bridge_find_win32_environment(
        _available _root _cc _cxx _runtime_dir _wine _winepath _reason
    )
    if(_available)
        add_custom_target(
            "${ARG_TARGET}"
            COMMAND "${_runner}" "${_wine}" "${_winepath}" "${_runtime_dir}"
                "$<TARGET_FILE:${ARG_APPLICATION_TARGET}>"
            DEPENDS "${ARG_APPLICATION_TARGET}"
            COMMENT "Running ${ARG_APPLICATION_TARGET} through Bridge Wine"
            USES_TERMINAL
            VERBATIM
        )
    else()
        # Preserve cross-compilation when Wine is not installed. Explicitly fail
        # when someone invokes the run target instead of silently skipping it.
        add_custom_target(
            "${ARG_TARGET}"
            COMMAND "${CMAKE_COMMAND}" -E echo "Bridge Win32 execution unavailable: ${_reason}"
            COMMAND "${CMAKE_COMMAND}" -E false
            DEPENDS "${ARG_APPLICATION_TARGET}"
            USES_TERMINAL
            VERBATIM
        )
    endif()
endfunction()
