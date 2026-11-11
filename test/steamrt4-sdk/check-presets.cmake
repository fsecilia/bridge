# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

# The Steam configure, build, and test presets are offered only inside the SDK
# container, where the runner sets BRIDGE_STEAMRT4_CONTAINER=1. Workflow presets
# cannot carry a condition; on the host they remain listed and fail when used.
if(NOT BRIDGE_PRESET_ROOT)
    message(FATAL_ERROR "Steam preset visibility test requires BRIDGE_PRESET_ROOT")
endif()

function(_bridge_list_presets KIND CONTAINER OUT)
    if(CONTAINER)
        set(_environment "BRIDGE_STEAMRT4_CONTAINER=1")
    else()
        set(_environment "--unset=BRIDGE_STEAMRT4_CONTAINER")
    endif()
    execute_process(
        COMMAND "${CMAKE_COMMAND}" -E env ${_environment} "${CMAKE_COMMAND}" "--list-presets=${KIND}"
        WORKING_DIRECTORY "${BRIDGE_PRESET_ROOT}"
        RESULT_VARIABLE _result OUTPUT_VARIABLE _output ERROR_VARIABLE _error
    )
    if(NOT "${_result}" STREQUAL "0")
        message(FATAL_ERROR "Listing ${KIND} presets failed (${_result}):\n${_output}${_error}")
    endif()
    set("${OUT}" "${_output}" PARENT_SCOPE)
endfunction()

foreach(_kind IN ITEMS configure build test)
    _bridge_list_presets("${_kind}" FALSE _host)
    _bridge_list_presets("${_kind}" TRUE _container)
    foreach(_preset IN ITEMS steam-gcc-debug steam-gcc-release)
        if("${_host}" MATCHES "\"${_preset}\"")
            message(FATAL_ERROR "Host lists SDK-only ${_kind} preset ${_preset}:\n${_host}")
        endif()
        if(NOT "${_container}" MATCHES "\"${_preset}\"")
            message(FATAL_ERROR "SDK container does not list ${_kind} preset ${_preset}:\n${_container}")
        endif()
    endforeach()
endforeach()

# Selecting a hidden preset on the host must still fail loudly rather than configure against host libraries.
execute_process(
    COMMAND "${CMAKE_COMMAND}" -E env --unset=BRIDGE_STEAMRT4_CONTAINER
        "${CMAKE_COMMAND}" --preset steam-gcc-release -N
    WORKING_DIRECTORY "${BRIDGE_PRESET_ROOT}"
    RESULT_VARIABLE _result OUTPUT_VARIABLE _output ERROR_VARIABLE _error
)
if("${_result}" STREQUAL "0" OR NOT "${_error}" MATCHES "disabled configure preset")
    message(FATAL_ERROR "Host accepted the SDK-only configure preset (${_result}):\n${_output}${_error}")
endif()
