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
  # Guard clause: Ensure this function executes only at the project root. This
  # prevents accidental invocation from subdirectories, which would create
  # redundant targets and potential conflicts.
  if(NOT CMAKE_CURRENT_SOURCE_DIR STREQUAL CMAKE_SOURCE_DIR)
    message(
      VERBOSE
      "add_clang_format_target should always be called at the ROOT project level!"
    )

    # Exit the function prematurely to avoid creating a target in a subdirectory.
    return()
  endif()

  # Validation: Check if the clang-format executable was successfully located
  # during the initial CMake configuration phase. If not found, the target
  # cannot function, so we exit gracefully with a status message.
  if(NOT CLANG_FORMAT_BINARY)
    message(
      STATUS
      "clang-format executable not found; skipping clang-format target generation."
    )
    return()
  endif()

  # Retrieve the globally accumulated list of source files registered for
  # formatting. The `format_files` property is populated by calls to this module
  # in various subdirectories during the configuration process.
  get_property(all_format_files GLOBAL PROPERTY format_files)

  # Check if any files have been registered. An empty list indicates that no
  # source files were marked for formatting, making the target unnecessary.
  if(NOT all_format_files)
    message(
      STATUS
      "No source files have been registered for formatting with clang-format."
    )
    return()
  endif()

  # Perform deduplication on the file list. The same file might be appended
  # multiple times if its path is referenced in different subdirectories or
  # variable sets. Removing duplicates ensures each file is formatted only once,
  # improving efficiency and avoiding potential conflicts.
  list(REMOVE_DUPLICATES all_format_files)

  # Create the custom CMake target named `clang-format`.
  # It must be explicitly invoked via `cmake --build <dir> --target clang-format`.
  add_custom_target(
    clang-format # Target name exposed to the build system.
    # Command to execute: clang-format in-place (`-i`) on all registered files.
    COMMAND ${CLANG_FORMAT_BINARY} -i ${all_format_files}
    # Set the working directory to the project root.
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    # User-friendly message displayed when the target is executed.
    COMMENT "Formatting ${CMAKE_PROJECT_NAME} codebase with clang-format"
    # VERBATIM instructs CMake to pass the command arguments exactly as
    # specified, preventing any unintended shell expansions or escaping issues.
    VERBATIM
  )

  # Confirm to the user that the target has been successfully added.
  message(STATUS "Added 'clang-format' target for ${CMAKE_PROJECT_NAME}")
endfunction()

# This block executes only when the current source directory is the project
# root (i.e., the top-level CMakeLists.txt directory). Its purpose is to perform
# one-time setup tasks.
if(CMAKE_CURRENT_SOURCE_DIR STREQUAL CMAKE_SOURCE_DIR)
  # Safety check: Ensure the global property `format_files` is initially empty.
  # A non-empty state at this point suggests a previous module inclusion or
  # property pollution, which could lead to incorrect file aggregation.
  get_property(all_format_files GLOBAL PROPERTY format_files)
  if(all_format_files)
    # Halt configuration with a fatal error to prevent undefined behavior.
    message(
      FATAL_ERROR
      "Global property 'format_files' is not empty at initialization."
    )
  endif()

  # Locate the clang-format executable in the system's PATH. The `find_program`
  # command searches for the binary and stores the full path in the variable
  # `CLANG_FORMAT_BINARY`. If not found, the variable is set to
  # `CLANG_FORMAT_BINARY-NOTFOUND`.
  find_program(CLANG_FORMAT_BINARY clang-format)
endif()

# If the clang-format executable was not found (determined either in the root
# block above or from a previous inclusion), there is no point in proceeding
# with file registration. The module exits here to avoid unnecessary processing.
if(NOT CLANG_FORMAT_BINARY)
  # This return statement exits the current module file but does not affect the
  # overall CMake configuration process for the project.
  return()
endif()

if(${PROJECT_NAME}_build_executable)
  # Condition: Project is configured to build an executable. This typically
  # means it contains a `add_executable()` call.

  # Append all relevant file categories for an executable project:
  set_property(
    GLOBAL
    APPEND
    PROPERTY
      format_files
        ${header_version} # Path to a version header file.
        ${public_headers} # List of public header files.
        ${library_sources} #  List of library source files.
        ${exe_sources} # List of application-specific source files.
  )
  # Condition: Project is configured as a header-only library.
  # Such projects contain only header files and no compilation units.
elseif(${PROJECT_NAME}_build_headers_only)
  # Condition: Project is configured as a header-only library. Such projects
  # contain only header files and no compilation units.

  # Append only header files, as there are no source files to compile.
  set_property(
    GLOBAL
    APPEND
    PROPERTY
      format_files
        ${header_version} #
        ${public_headers} #
  )
else()
  # Default Condition: Project builds a static or shared library (not
  # header-only). This is the fallback for library projects that contain both
  # headers and sources.
  set_property(
    GLOBAL
    APPEND
    PROPERTY
      format_files
        ${header_version} #
        ${public_headers} #
        ${library_sources} #
  )
endif()
