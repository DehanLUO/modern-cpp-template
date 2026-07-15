# ==============================================================================
# CMake Module: clang-format Target Configuration
# ==============================================================================
# This module provides a mechanism to register source files for automated code
# formatting using the clang-format tool. It creates a global custom build
# target (`clang-format`) that can be invoked to format the entire codebase
# consistently. The module employs a two-phase approach:
#   1. During configuration of each subdirectory, source files are appended
#      to a global CMake property (`format_files`).
#   2. At the root project level, a single custom target is generated that
#      operates on the aggregated and deduplicated file list.
# ==============================================================================

# ------------------------------------------------------------------------------
# Function: add_clang_format_target
# ------------------------------------------------------------------------------
# Purpose: Generates the global `clang-format` custom target at the root of the
# project. This function should be called only once from the main CMakeLists.txt
# file to avoid target duplication and ensure proper file list aggregation.
# ------------------------------------------------------------------------------
function(add_clang_format_target)
  # Guard clause: Ensure this function executes only at the project root.
  if(NOT CMAKE_CURRENT_SOURCE_DIR STREQUAL CMAKE_SOURCE_DIR)
    log_warn(
      "add_clang_format_target should always be called at the ROOT project level!"
    )
    return()
  endif()

  if(NOT CLANG_FORMAT_BINARY)
    log_warn(
      "clang-format executable not found; skipping clang-format target generation."
    )
    return()
  endif()

  get_property(all_format_files GLOBAL PROPERTY format_files)

  if(NOT all_format_files)
    log_warn(
      "No source files have been registered for formatting with clang-format."
    )
    return()
  endif()

  list(REMOVE_DUPLICATES all_format_files)
  list(LENGTH all_format_files _fmt_count)
  log_info("Registering ${_fmt_count} files for clang-format")

  add_custom_target(
    clang-format
    COMMAND ${CLANG_FORMAT_BINARY} -i ${all_format_files}
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    COMMENT "Formatting ${CMAKE_PROJECT_NAME} codebase with clang-format"
    VERBATIM
  )

  log_info("Added 'clang-format' target for ${CMAKE_PROJECT_NAME}")
endfunction()

# Root-level one-time setup
if(CMAKE_CURRENT_SOURCE_DIR STREQUAL CMAKE_SOURCE_DIR)
  get_property(all_format_files GLOBAL PROPERTY format_files)
  if(all_format_files)
    log_fatal(
      "Global property 'format_files' is not empty at initialization."
    )
  endif()

  find_program(CLANG_FORMAT_BINARY clang-format)
  if(CLANG_FORMAT_BINARY)
    log_info("Found clang-format: ${CLANG_FORMAT_BINARY}")
  else()
    log_warn("clang-format not found in PATH")
  endif()
endif()

if(NOT CLANG_FORMAT_BINARY)
  return()
endif()

if(${PROJECT_NAME}_build_executable)
  set_property(
    GLOBAL
    APPEND
    PROPERTY
      format_files
        ${header_version}
        ${public_headers}
        ${library_sources}
        ${exe_sources}
  )
  log_debug("Registered executable project files for formatting")
elseif(${PROJECT_NAME}_build_headers_only)
  set_property(
    GLOBAL
    APPEND
    PROPERTY
      format_files
        ${header_version}
        ${public_headers}
  )
  log_debug("Registered header-only project files for formatting")
else()
  set_property(
    GLOBAL
    APPEND
    PROPERTY
      format_files
        ${header_version}
        ${public_headers}
        ${library_sources}
  )
  log_debug("Registered library project files for formatting")
endif()
