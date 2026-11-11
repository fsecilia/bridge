# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

foreach(_required IN ITEMS BRIDGE_SOURCE_DIR BRIDGE_TEST_BINARY_DIR BRIDGE_GENERATOR BRIDGE_MAKE_PROGRAM BRIDGE_PYTHON3)
    if(NOT DEFINED ${_required} OR "${${_required}}" STREQUAL "")
        message(FATAL_ERROR "Linux install integration test requires ${_required}")
    endif()
endforeach()

set(_fixture "${BRIDGE_SOURCE_DIR}/test/application/linux-install")
set(_assets "${BRIDGE_TEST_BINARY_DIR}/assets")
set(_icons "${BRIDGE_TEST_BINARY_DIR}/icons")
file(REMOVE_RECURSE "${BRIDGE_TEST_BINARY_DIR}")
file(MAKE_DIRECTORY "${_assets}/fixtures")
file(WRITE "${_assets}/fixtures/expected.txt" "Bridge install fixture\n")
execute_process(
    COMMAND "${BRIDGE_PYTHON3}" "${BRIDGE_SOURCE_DIR}/test/application/make_icons.py" "${_icons}"
    RESULT_VARIABLE _result ERROR_VARIABLE _stderr
)
if(NOT "${_result}" STREQUAL "0")
    message(FATAL_ERROR "Linux install fixture icon generation failed: ${_result}\n${_stderr}")
endif()
file(WRITE "${_icons}/README.md" "Source-only icon documentation\n")

# Exercise desktop integration independently of whether SDL comes from the build tree or an imported target.
foreach(_case IN ITEMS built imported-default imported-excluded imported-policy built-policy built-no-desktop imported-no-desktop-override built-component)
    set(_build "${BRIDGE_TEST_BINARY_DIR}/${_case}")
    set(_prefix "${_build}/installed")
    set(_sdl_kind built)
    set(_application_runtime "")
    set(_install_sdl bundle)
    set(_desktop_integration install)
    set(_application_desktop_integration "")
    set(_install_component "")
    if(_case STREQUAL "built-component")
        set(_install_component game)
    endif()
    if(_case MATCHES "^imported-")
        set(_sdl_kind imported)
    endif()
    if(_case STREQUAL "built-no-desktop")
        set(_desktop_integration none)
    elseif(_case STREQUAL "imported-no-desktop-override")
        set(_application_desktop_integration none)
    endif()
    if(_case STREQUAL "imported-excluded")
        set(_application_runtime system)
    elseif(_case MATCHES "-policy$")
        set(_install_sdl system)
    endif()
    execute_process(
        COMMAND "${CMAKE_COMMAND}"
            -S "${_fixture}" -B "${_build}" -G "${BRIDGE_GENERATOR}"
            "-DCMAKE_MAKE_PROGRAM=${BRIDGE_MAKE_PROGRAM}"
            "-DBRIDGE_CANON_MODULE=${BRIDGE_CANON_MODULE}"
            "-DBRIDGE_SOURCE_DIR=${BRIDGE_SOURCE_DIR}"
            "-DBRIDGE_INSTALL_FIXTURE_ASSETS=${_assets}"
            "-DBRIDGE_INSTALL_FIXTURE_ICONS=${_icons}"
            "-DBRIDGE_SDL_KIND=${_sdl_kind}"
            "-DBRIDGE_SDL_APPLICATION_RUNTIME=${_application_runtime}"
            "-DBRIDGE_SDL_RUNTIME=${_install_sdl}"
            "-DBRIDGE_LINUX_DESKTOP_INTEGRATION=${_desktop_integration}"
            "-DBRIDGE_APPLICATION_DESKTOP_INTEGRATION=${_application_desktop_integration}"
            "-DBRIDGE_APPLICATION_INSTALL_COMPONENT=${_install_component}"
        RESULT_VARIABLE _result OUTPUT_VARIABLE _stdout ERROR_VARIABLE _stderr
    )
    if(NOT "${_result}" STREQUAL "0")
        message(FATAL_ERROR "Linux install ${_case} configure failed: ${_result}\n${_stdout}\n${_stderr}")
    endif()
    execute_process(
        COMMAND "${CMAKE_COMMAND}" --build "${_build}"
        RESULT_VARIABLE _result OUTPUT_VARIABLE _stdout ERROR_VARIABLE _stderr
    )
    if(NOT "${_result}" STREQUAL "0")
        message(FATAL_ERROR "Linux install ${_case} build failed: ${_result}\n${_stdout}\n${_stderr}")
    endif()
    # A component install must contain the whole application and nothing from other components.
    set(_component_arguments)
    if(_install_component)
        set(_component_arguments --component "${_install_component}")
    endif()
    execute_process(
        COMMAND "${CMAKE_COMMAND}" --install "${_build}" --prefix "${_prefix}" ${_component_arguments}
        RESULT_VARIABLE _result OUTPUT_VARIABLE _stdout ERROR_VARIABLE _stderr
    )
    if(NOT "${_result}" STREQUAL "0")
        message(FATAL_ERROR "Linux install ${_case} failed: ${_result}\n${_stdout}\n${_stderr}")
    endif()

    foreach(_required_file IN ITEMS
        bin/bridge_linux_install_game
        lib/libbridge_linux_install_main.so
        lib/libbridge_linux_install_extra.so
        bin/fixtures/expected.txt
    )
        if(NOT EXISTS "${_prefix}/${_required_file}")
            message(FATAL_ERROR "Linux install ${_case} omitted ${_required_file}")
        endif()
    endforeach()
    set(_desktop_expected TRUE)
    if(_desktop_integration STREQUAL "none" OR _application_desktop_integration STREQUAL "none")
        set(_desktop_expected FALSE)
    endif()
    set(_desktop_entry "${_prefix}/share/applications/org.bridge.linuxinstall.desktop")
    if(_desktop_expected AND NOT EXISTS "${_desktop_entry}")
        message(FATAL_ERROR "Linux install ${_case} omitted desktop entry")
    elseif(NOT _desktop_expected AND EXISTS "${_desktop_entry}")
        message(FATAL_ERROR "Linux install ${_case} unexpectedly installed desktop entry")
    endif()
    set(_icon_sizes 16 24 32 48 64 72 96 128 144 192 256 512)
    set(_expected_icons "")
    foreach(_size IN LISTS _icon_sizes)
        list(APPEND _expected_icons "${_size}.png")
        set(_desktop_icon "${_prefix}/share/icons/hicolor/${_size}x${_size}/apps/org.bridge.linuxinstall.png")
        if(_desktop_expected AND NOT EXISTS "${_desktop_icon}")
            message(FATAL_ERROR "Linux install ${_case} omitted ${_desktop_icon}")
        elseif(NOT _desktop_expected AND EXISTS "${_desktop_icon}")
            message(FATAL_ERROR "Linux install ${_case} unexpectedly installed ${_desktop_icon}")
        endif()
        set(_runtime_icons "${_prefix}/bin/icons/${_size}.png")
        if(_desktop_expected)
            list(APPEND _runtime_icons "${_desktop_icon}")
        endif()
        foreach(_installed_icon IN LISTS _runtime_icons)
            if(NOT EXISTS "${_installed_icon}")
                message(FATAL_ERROR "Linux install ${_case} omitted ${_installed_icon}")
            endif()
            file(SHA256 "${_installed_icon}" _installed_hash)
            file(SHA256 "${_icons}/transparent/${_size}.png" _source_hash)
            if(NOT _installed_hash STREQUAL _source_hash)
                message(FATAL_ERROR "Linux install ${_case} changed transparent icon ${_size}.png")
            endif()
        endforeach()
    endforeach()
    if(NOT _desktop_expected AND EXISTS "${_prefix}/share")
        file(GLOB_RECURSE _unexpected_desktop_files LIST_DIRECTORIES FALSE "${_prefix}/share/*")
        if(_unexpected_desktop_files)
            message(FATAL_ERROR "Linux install ${_case} unexpectedly installed desktop files: ${_unexpected_desktop_files}")
        endif()
    endif()
    file(GLOB_RECURSE _installed_icons RELATIVE "${_prefix}/bin/icons" LIST_DIRECTORIES FALSE
        "${_prefix}/bin/icons/*")
    list(SORT _installed_icons)
    list(SORT _expected_icons)
    if(NOT "${_installed_icons}" STREQUAL "${_expected_icons}")
        message(FATAL_ERROR "Linux install ${_case} has unexpected icons: ${_installed_icons}")
    endif()

    if(_install_component AND EXISTS "${_prefix}/share/unrelated")
        message(FATAL_ERROR "Linux install ${_case} included another component's files")
    endif()
    set(_installed_sdl "${_prefix}/lib/libbridge_linux_install_sdl.so")
    if(_application_runtime STREQUAL "system" OR _install_sdl STREQUAL "system")
        if(EXISTS "${_installed_sdl}")
            message(FATAL_ERROR "Linux install ${_case} bundled SDL despite runtime exclusion")
        endif()
    elseif(NOT EXISTS "${_installed_sdl}")
        message(FATAL_ERROR "Linux install ${_case} did not bundle SDL by default")
    endif()
endforeach()

# Neither a per-application nor a global system-runtime policy can be bypassed through RUNTIME_TARGETS.
foreach(_case IN ITEMS explicit policy)
    set(_options -DBRIDGE_SDL_RUNTIME=bundle)
    if(_case STREQUAL "explicit")
        list(APPEND _options -DBRIDGE_SDL_APPLICATION_RUNTIME=system)
    else()
        list(APPEND _options -DBRIDGE_SDL_RUNTIME=system)
    endif()
    execute_process(
        COMMAND "${CMAKE_COMMAND}"
            -S "${_fixture}" -B "${BRIDGE_TEST_BINARY_DIR}/excluded-duplicate-${_case}" -G "${BRIDGE_GENERATOR}"
            "-DCMAKE_MAKE_PROGRAM=${BRIDGE_MAKE_PROGRAM}"
            "-DBRIDGE_CANON_MODULE=${BRIDGE_CANON_MODULE}"
            "-DBRIDGE_SOURCE_DIR=${BRIDGE_SOURCE_DIR}"
            "-DBRIDGE_INSTALL_FIXTURE_ASSETS=${_assets}"
            "-DBRIDGE_INSTALL_FIXTURE_ICONS=${_icons}"
            -DBRIDGE_SDL_KIND=imported
            -DBRIDGE_DUPLICATE_SDL_RUNTIME=ON
            ${_options}
        RESULT_VARIABLE _result OUTPUT_VARIABLE _stdout ERROR_VARIABLE _stderr
    )
    string(REGEX REPLACE "[ \t\r\n]+" " " _error_message "${_stderr}")
    if("${_result}" STREQUAL "0" OR NOT _error_message MATCHES "is both bundled and system-provided")
        message(FATAL_ERROR
            "Linux install accepted conflicting runtime target selection (${_case}): ${_result}\n${_stdout}\n${_stderr}")
    endif()
endforeach()
