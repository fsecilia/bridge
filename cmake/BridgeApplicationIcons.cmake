# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

include_guard(GLOBAL)

# Shared by Android, Windows, and Linux packaging. Rendering remains the
# consumer's responsibility; Bridge only validates and packages PNGs.
function(_bridge_validate_icon_directory DIRECTORY OUT_DIRECTORY OUT_PYTHON OUT_DEPENDENCIES)
    set(_directory "${DIRECTORY}")
    cmake_path(ABSOLUTE_PATH _directory BASE_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}" NORMALIZE)
    if(NOT IS_DIRECTORY "${_directory}")
        message(FATAL_ERROR "Bridge icon directory does not exist: ${_directory}")
    endif()
    find_package(Python3 REQUIRED COMPONENTS Interpreter)
    set(_script "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/../scripts/bridge_icons.py")
    execute_process(
        COMMAND "${Python3_EXECUTABLE}" "${_script}" validate --source "${_directory}"
        RESULT_VARIABLE _result
        OUTPUT_VARIABLE _stdout
        ERROR_VARIABLE _stderr
    )
    if(NOT _result EQUAL 0)
        message(FATAL_ERROR "Bridge icon validation failed:\n${_stdout}${_stderr}")
    endif()
    file(GLOB _dependencies CONFIGURE_DEPENDS LIST_DIRECTORIES FALSE "${_directory}/*.png")
    set(${OUT_DIRECTORY} "${_directory}" PARENT_SCOPE)
    set(${OUT_PYTHON} "${Python3_EXECUTABLE}" PARENT_SCOPE)
    set(${OUT_DEPENDENCIES} "${_dependencies}" PARENT_SCOPE)
endfunction()

# Embed a multi-resolution .ico in an existing consumer-owned Windows executable.
# CMake must enable languages in the caller's directory scope, not from a
# function's local variable scope. The public macro keeps this transparent.
macro(bridge_add_win32_application_icon)
    if(NOT WIN32)
        message(FATAL_ERROR "bridge_add_win32_application_icon() requires Windows")
    endif()
    enable_language(RC)
    _bridge_add_win32_application_icon(${ARGN})
endmacro()

function(_bridge_add_win32_application_icon)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "" "TARGET;ICON_DIRECTORY" "")
    if(ARG_UNPARSED_ARGUMENTS OR ARG_KEYWORDS_MISSING_VALUES)
        message(FATAL_ERROR "bridge_add_win32_application_icon(): invalid arguments")
    endif()
    if(NOT WIN32)
        message(FATAL_ERROR "bridge_add_win32_application_icon() requires Windows")
    endif()
    if(NOT TARGET "${ARG_TARGET}" OR NOT ARG_ICON_DIRECTORY)
        message(FATAL_ERROR "bridge_add_win32_application_icon(): TARGET and ICON_DIRECTORY are required")
    endif()
    get_target_property(_type "${ARG_TARGET}" TYPE)
    if(NOT _type STREQUAL "EXECUTABLE")
        message(FATAL_ERROR "bridge_add_win32_application_icon(): '${ARG_TARGET}' must be an executable")
    endif()
    _bridge_validate_icon_directory("${ARG_ICON_DIRECTORY}" _directory _python _dependencies)

    set(_generated "${CMAKE_CURRENT_BINARY_DIR}/bridge-icons/${ARG_TARGET}")
    set(_ico "${_generated}/application.ico")
    set(_rc "${_generated}/application.rc")
    file(MAKE_DIRECTORY "${_generated}")
    file(WRITE "${_rc}" "1 ICON \"${_ico}\"\n")

    add_custom_command(
        OUTPUT "${_ico}"
        COMMAND "${_python}" "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/../scripts/bridge_icons.py"
            ico --source "${_directory}" --output "${_ico}"
        DEPENDS ${_dependencies} "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/../scripts/bridge_icons.py"
        COMMENT "Generating ${ARG_TARGET} Windows application icon"
        VERBATIM
    )
    set(_icon_target "${ARG_TARGET}_bridge_icon")
    add_custom_target("${_icon_target}" DEPENDS "${_ico}")
    add_dependencies("${ARG_TARGET}" "${_icon_target}")
    set_source_files_properties("${_rc}" PROPERTIES OBJECT_DEPENDS "${_ico}")
    target_sources("${ARG_TARGET}" PRIVATE "${_rc}")
endfunction()

# Install the desktop file and themed icons alongside a Linux executable.
function(bridge_install_linux_desktop_application)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "" "TARGET;APPLICATION_ID;APPLICATION_NAME;ICON_DIRECTORY;ASSET_DIRECTORY;CATEGORIES" "RUNTIME_TARGETS")
    if(ARG_UNPARSED_ARGUMENTS OR ARG_KEYWORDS_MISSING_VALUES)
        message(FATAL_ERROR "bridge_install_linux_desktop_application(): invalid arguments")
    endif()
    if(NOT CMAKE_SYSTEM_NAME STREQUAL "Linux")
        message(FATAL_ERROR "bridge_install_linux_desktop_application() requires Linux")
    endif()
    foreach(_required IN ITEMS TARGET APPLICATION_ID APPLICATION_NAME ICON_DIRECTORY)
        if(NOT ARG_${_required})
            message(FATAL_ERROR "bridge_install_linux_desktop_application(): ${_required} is required")
        endif()
    endforeach()
    if(NOT TARGET "${ARG_TARGET}")
        message(FATAL_ERROR "bridge_install_linux_desktop_application(): target '${ARG_TARGET}' does not exist")
    endif()
    get_target_property(_type "${ARG_TARGET}" TYPE)
    if(NOT _type STREQUAL "EXECUTABLE")
        message(FATAL_ERROR "bridge_install_linux_desktop_application(): '${ARG_TARGET}' must be an executable")
    endif()
    if(NOT ARG_APPLICATION_ID MATCHES "^[A-Za-z][A-Za-z0-9_-]*([.][A-Za-z][A-Za-z0-9_-]*)+$")
        message(FATAL_ERROR "bridge_install_linux_desktop_application(): invalid APPLICATION_ID: ${ARG_APPLICATION_ID}")
    endif()
    if(ARG_APPLICATION_NAME MATCHES "[\r\n]")
        message(FATAL_ERROR "bridge_install_linux_desktop_application(): APPLICATION_NAME cannot contain newlines")
    endif()
    if(ARG_CATEGORIES AND NOT ARG_CATEGORIES MATCHES "^[A-Za-z0-9_-]+(;[A-Za-z0-9_-]+)*$")
        message(FATAL_ERROR "bridge_install_linux_desktop_application(): invalid CATEGORIES: ${ARG_CATEGORIES}")
    endif()
    _bridge_validate_icon_directory("${ARG_ICON_DIRECTORY}" _directory _python _dependencies)
    include(GNUInstallDirs)
    if(ARG_ASSET_DIRECTORY)
        set(_asset_directory "${ARG_ASSET_DIRECTORY}")
        cmake_path(ABSOLUTE_PATH _asset_directory BASE_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}" NORMALIZE)
        if(NOT IS_DIRECTORY "${_asset_directory}")
            message(FATAL_ERROR "bridge_install_linux_desktop_application(): ASSET_DIRECTORY does not exist: ${_asset_directory}")
        endif()
    endif()

    get_target_property(_output "${ARG_TARGET}" OUTPUT_NAME)
    if(NOT _output)
        set(_output "${ARG_TARGET}")
    endif()
    set(_desktop "${CMAKE_CURRENT_BINARY_DIR}/${ARG_APPLICATION_ID}.desktop")
    set(_categories "")
    if(ARG_CATEGORIES)
        set(_categories "Categories=${ARG_CATEGORIES};\n")
    endif()
    file(WRITE "${_desktop}"
        "[Desktop Entry]\nType=Application\nName=${ARG_APPLICATION_NAME}\n"
        "Exec=${_output}\nIcon=${ARG_APPLICATION_ID}\nTerminal=false\n${_categories}"
    )
    set_property(TARGET "${ARG_TARGET}" APPEND PROPERTY INSTALL_RPATH "$ORIGIN/../${CMAKE_INSTALL_LIBDIR}")
    install(TARGETS "${ARG_TARGET}" RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}")
    set(_seen_targets "${ARG_TARGET}")
    foreach(_runtime_target IN LISTS ARG_RUNTIME_TARGETS)
        if(NOT TARGET "${_runtime_target}")
            message(FATAL_ERROR "bridge_install_linux_desktop_application(): runtime target '${_runtime_target}' does not exist")
        endif()
        get_target_property(_alias "${_runtime_target}" ALIASED_TARGET)
        if(_alias)
            set(_target "${_alias}")
        else()
            set(_target "${_runtime_target}")
        endif()
        list(FIND _seen_targets "${_target}" _seen_index)
        if(NOT _seen_index EQUAL -1)
            message(FATAL_ERROR "bridge_install_linux_desktop_application(): duplicate runtime target '${_runtime_target}'")
        endif()
        list(APPEND _seen_targets "${_target}")
        get_target_property(_runtime_type "${_target}" TYPE)
        if(NOT _runtime_type STREQUAL "SHARED_LIBRARY")
            message(FATAL_ERROR "bridge_install_linux_desktop_application(): '${_runtime_target}' must be a shared library")
        endif()
        get_target_property(_imported "${_target}" IMPORTED)
        if(_imported)
            install(IMPORTED_RUNTIME_ARTIFACTS "${_target}" LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}")
        else()
            set_property(TARGET "${_target}" APPEND PROPERTY INSTALL_RPATH "$ORIGIN")
            install(TARGETS "${_target}" LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}")
        endif()
    endforeach()
    if(_asset_directory)
        install(DIRECTORY "${_asset_directory}/" DESTINATION "${CMAKE_INSTALL_BINDIR}")
    endif()
    # SDL title storage reads icons beside the application binary.
    install(DIRECTORY "${_directory}/" DESTINATION "${CMAKE_INSTALL_BINDIR}/icons")
    install(FILES "${_desktop}" DESTINATION share/applications)
    foreach(_size IN ITEMS 16 24 32 48 64 128 256 512)
        install(
            FILES "${_directory}/icon-${_size}.png"
            DESTINATION "share/icons/hicolor/${_size}x${_size}/apps"
            RENAME "${ARG_APPLICATION_ID}.png"
        )
    endforeach()
endfunction()
