# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

# Mirrors the files of SOURCE into DESTINATION without disturbing anything else
# there, such as the executables the files are staged beside. MANIFEST records
# what the previous run staged, so files that were staged before but are no
# longer in SOURCE are removed. Unchanged files are not rewritten.
#
#   cmake -DSOURCE=<dir> -DDESTINATION=<dir> -DMANIFEST=<file> -P bridge_stage_directory.cmake

cmake_minimum_required(VERSION 3.31.6)

foreach(_required IN ITEMS SOURCE DESTINATION MANIFEST)
    if(NOT DEFINED ${_required} OR "${${_required}}" STREQUAL "")
        message(FATAL_ERROR "bridge_stage_directory: ${_required} is required")
    endif()
endforeach()
if(NOT IS_DIRECTORY "${SOURCE}")
    message(FATAL_ERROR "bridge_stage_directory: SOURCE is not a directory: ${SOURCE}")
endif()

file(GLOB_RECURSE _files RELATIVE "${SOURCE}" LIST_DIRECTORIES FALSE "${SOURCE}/*")
list(SORT _files)

set(_previous "")
if(EXISTS "${MANIFEST}")
    file(STRINGS "${MANIFEST}" _previous)
endif()
foreach(_file IN LISTS _previous)
    if(NOT _file IN_LIST _files)
        file(REMOVE "${DESTINATION}/${_file}")
    endif()
endforeach()

foreach(_file IN LISTS _files)
    cmake_path(GET _file PARENT_PATH _parent)
    file(MAKE_DIRECTORY "${DESTINATION}/${_parent}")
    file(COPY_FILE "${SOURCE}/${_file}" "${DESTINATION}/${_file}" ONLY_IF_DIFFERENT)
endforeach()

cmake_path(GET MANIFEST PARENT_PATH _manifest_directory)
file(MAKE_DIRECTORY "${_manifest_directory}")
list(JOIN _files "\n" _manifest)
file(WRITE "${MANIFEST}" "${_manifest}\n")
