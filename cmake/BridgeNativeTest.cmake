# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

include_guard(GLOBAL)

# Registers a CTest executable with platform-specific runtime and asset staging.
# Android deploys to a device; Windows stages DLLs; native hosts run locally.
function(bridge_add_native_test)
    set(one_value_args NAME TARGET ASSET_DIRECTORY)
    set(multi_value_args RUNTIME_TARGETS ARGS)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "" "${one_value_args}" "${multi_value_args}")

    if(ARG_UNPARSED_ARGUMENTS OR ARG_KEYWORDS_MISSING_VALUES)
        message(FATAL_ERROR "bridge_add_native_test(): invalid arguments")
    endif()
    foreach(_required IN ITEMS NAME TARGET)
        if(NOT ARG_${_required})
            message(FATAL_ERROR "bridge_add_native_test(): ${_required} is required")
        endif()
    endforeach()
    if(NOT TARGET "${ARG_TARGET}")
        message(FATAL_ERROR "bridge_add_native_test(): target '${ARG_TARGET}' does not exist")
    endif()
    get_target_property(_target_type "${ARG_TARGET}" TYPE)
    if(NOT _target_type STREQUAL "EXECUTABLE")
        message(FATAL_ERROR "bridge_add_native_test(): TARGET must be an executable")
    endif()

    foreach(_runtime_target IN LISTS ARG_RUNTIME_TARGETS)
        if(NOT TARGET "${_runtime_target}")
            message(FATAL_ERROR "bridge_add_native_test(): runtime target '${_runtime_target}' does not exist")
        endif()
        get_target_property(_runtime_type "${_runtime_target}" TYPE)
        if(NOT _runtime_type STREQUAL "SHARED_LIBRARY")
            message(FATAL_ERROR
                "bridge_add_native_test(): runtime target '${_runtime_target}' must be a shared library")
        endif()
    endforeach()

    if(ANDROID)
        if(NOT CMAKE_CROSSCOMPILING OR NOT CMAKE_CROSSCOMPILING_EMULATOR)
            message(FATAL_ERROR "bridge_add_native_test(): Bridge Android execution is not configured")
        endif()
        set(_emulator ${CMAKE_CROSSCOMPILING_EMULATOR})
        foreach(_runtime_target IN LISTS ARG_RUNTIME_TARGETS)
            list(APPEND _emulator --library "$<TARGET_FILE:${_runtime_target}>")
        endforeach()
        if(ARG_ASSET_DIRECTORY)
            list(APPEND _emulator --assets "${ARG_ASSET_DIRECTORY}")
        endif()
        list(APPEND _emulator --)
        set_property(TARGET "${ARG_TARGET}" PROPERTY CROSSCOMPILING_EMULATOR "${_emulator}")
    elseif(WIN32)
        include("${CMAKE_CURRENT_FUNCTION_LIST_DIR}/BridgeWin32Runtime.cmake")
        bridge_stage_win32_runtime(TARGET "${ARG_TARGET}")
        # Explicit runtime targets also cover DLLs opened dynamically rather than
        # discovered through the test executable's CMake link dependencies.
        if(ARG_RUNTIME_TARGETS)
            set(_explicit_libraries "")
            foreach(_runtime_target IN LISTS ARG_RUNTIME_TARGETS)
                list(APPEND _explicit_libraries "$<TARGET_FILE:${_runtime_target}>")
            endforeach()
            add_custom_command(
                TARGET "${ARG_TARGET}" POST_BUILD
                COMMAND "${CMAKE_COMMAND}" -E copy_if_different
                    ${_explicit_libraries} "$<TARGET_FILE_DIR:${ARG_TARGET}>"
                COMMAND_EXPAND_LISTS
                VERBATIM
            )
        endif()
        if(CMAKE_CROSSCOMPILING)
            if(NOT CMAKE_CROSSCOMPILING_EMULATOR)
                message(FATAL_ERROR "bridge_add_native_test(): Bridge Win32 execution is not configured")
            endif()
            set_property(TARGET "${ARG_TARGET}" PROPERTY CROSSCOMPILING_EMULATOR "${CMAKE_CROSSCOMPILING_EMULATOR}")
        endif()
    elseif(NOT CMAKE_SYSTEM_NAME STREQUAL CMAKE_HOST_SYSTEM_NAME)
        message(FATAL_ERROR "bridge_add_native_test(): unsupported cross-compilation target '${CMAKE_SYSTEM_NAME}'")
    endif()

    add_test(NAME "${ARG_NAME}" COMMAND "${ARG_TARGET}" ${ARG_ARGS})
    if(ARG_ASSET_DIRECTORY)
        set_tests_properties("${ARG_NAME}" PROPERTIES WORKING_DIRECTORY "${ARG_ASSET_DIRECTORY}")
    endif()
endfunction()
