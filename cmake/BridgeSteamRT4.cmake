# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

# Requires Valve's Steam Linux Runtime 4 SDK, not its runtime-only image or a host distribution.
# The path is an argument so the identity check can be exercised with real os-release-format fixtures.
function(_bridge_require_steamrt4_sdk OS_RELEASE)
    if(NOT EXISTS "${OS_RELEASE}")
        message(FATAL_ERROR "Steam Linux Runtime 4 SDK requires ${OS_RELEASE}; configure inside the SDK container")
    endif()

    file(STRINGS "${OS_RELEASE}" _entries REGEX "^(ID|VERSION_ID|VARIANT)=")
    foreach(_entry IN LISTS _entries)
        if("${_entry}" MATCHES "^([A-Z_]+)=(.*)$")
            set(_key "${CMAKE_MATCH_1}")
            set(_value "${CMAKE_MATCH_2}")
            if("${_value}" MATCHES "^\"(.*)\"$")
                set(_value "${CMAKE_MATCH_1}")
            endif()
            set("_bridge_steamrt4_${_key}" "${_value}")
        endif()
    endforeach()

    if(NOT "${_bridge_steamrt4_ID}" STREQUAL "steamrt"
        OR NOT "${_bridge_steamrt4_VERSION_ID}" STREQUAL "4"
        OR NOT "${_bridge_steamrt4_VARIANT}" STREQUAL "SDK")
        message(FATAL_ERROR
            "The Steam presets require Steam Linux Runtime 4 SDK (ID=steamrt, VERSION_ID=4, VARIANT=SDK); "
            "found ID='${_bridge_steamrt4_ID}', VERSION_ID='${_bridge_steamrt4_VERSION_ID}', "
            "VARIANT='${_bridge_steamrt4_VARIANT}' in ${OS_RELEASE}. "
            "Configure from inside the Bridge Steam SDK container."
        )
    endif()
endfunction()
