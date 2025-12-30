# ==============================================================================
# CMake Script: Generate Build Information Header File
# ==============================================================================
# This script generates a C/C++ header file containing comprehensive build-time
# metadata. The metadata includes timestamp, build type, compiler details,
# platform information, and optional Git version control data. This header file
# can be included in the project's source code to provide runtime access to
# build characteristics, which is useful for debugging, logging, and version
# reporting.
#
# IMPORTANT USAGE NOTE:
# This script is designed to be invoked as a CMake script file via `cmake -P`
# from a parent CMakeLists.txt. It expects the following CMake variables to be
# explicitly passed via -D command-line arguments:
#
# REQUIRED VARIABLES (must be passed with -D flag):
#   - NAME   : Project name in uppercase for header guard
#   - OUTPUT : Full path to output header file
#
# OPTIONAL BUT RECOMMENDED VARIABLES (if not passed, defaults will be used):
#   - CMAKE_BUILD_TYPE           : Build configuration (Debug/Release/etc.)
#   - CMAKE_CXX_COMPILER_ID      : Compiler vendor (GNU/Clang/MSVC/etc.)
#   - CMAKE_CXX_COMPILER_VERSION : Compiler version string
#   - CMAKE_HOST_SYSTEM          : Build host system description
#   - CMAKE_HOST_SYSTEM_NAME     : Build host OS name
#   - CMAKE_SYSTEM_NAME          : Target system OS name
#   - CMAKE_SYSTEM_PROCESSOR     : Target processor architecture
#
# Example invocation from parent CMakeLists.txt:
#   execute_process(
#     COMMAND ${CMAKE_COMMAND}
#       -DNAME=MYPROJECT
#       -DOUTPUT=${CMAKE_BINARY_DIR}/buildinfo.h
#       -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
#       -DCMAKE_CXX_COMPILER_ID=${CMAKE_CXX_COMPILER_ID}
#       -DCMAKE_CXX_COMPILER_VERSION=${CMAKE_CXX_COMPILER_VERSION}
#       -DCMAKE_HOST_SYSTEM=${CMAKE_HOST_SYSTEM}
#       -DCMAKE_HOST_SYSTEM_NAME=${CMAKE_HOST_SYSTEM_NAME}
#       -DCMAKE_SYSTEM_NAME=${CMAKE_SYSTEM_NAME}
#       -DCMAKE_SYSTEM_PROCESSOR=${CMAKE_SYSTEM_PROCESSOR}
#       -P ${CMAKE_CURRENT_LIST_FILE}
#     WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
#   )
#
# Rationale for explicit variable passing:
# When invoked via `cmake -P`, this script runs in a separate CMake process that
# does NOT inherit the parent process's CMake variables. All necessary context
# must be explicitly passed via -D arguments.
# ==============================================================================

# Generates a human-readable timestamp string representing the exact moment of
# CMake configuration. The format follows ISO 8601-like convention with timezone
# information for precise traceability.
string(TIMESTAMP _timestamp "%Y-%m-%d %H:%M:%S %Z")

# Standardizes the build type string to uppercase for consistency (e.g., "DEBUG",
# "RELEASE"). If CMAKE_BUILD_TYPE is undefined (common in single-configuration
# generators like Unix Makefiles), it defaults to "UNKNOWN" to ensure safe
# string usage.
string(TOUPPER "${CMAKE_BUILD_TYPE}" _build_type_upper)
if(NOT _build_type_upper)
  set(_build_type_upper "UNKNOWN")
endif()

# Retrieves the compiler vendor (e.g., "GNU", "Clang", "MSVC") and its full
# version string. These variables are pre-defined by CMake during language
# enablement (e.g., via `project()` or `enable_language()`).
set(_compiler_id "${CMAKE_CXX_COMPILER_ID}")
set(_compiler_version "${CMAKE_CXX_COMPILER_VERSION}")

# Records the operating system and processor architecture of the *target*
# platform (where the compiled binaries will execute). This is particularly
# critical for cross-compilation scenarios.
set(_system_name "${CMAKE_SYSTEM_NAME}") # e.g., "Linux", "Windows", "Darwin"
set(_system_processor "${CMAKE_SYSTEM_PROCESSOR}") # e.g., "x86_64", "ARM64", "aarch64"
set(_host_system "${CMAKE_HOST_SYSTEM_NAME}") # Build machine system (for cross-compilation context)

# Attempts to extract version control information from the Git repository
# located at the project source root. This provides precise source code
# versioning for traceability. The `QUIET` option suppresses warnings if Git is
# not found.
find_package(Git QUIET)

# Verify both Git executable availability and repository existence
if(GIT_FOUND AND EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/.git")
  # Execute Git command to obtain the abbreviated commit hash (7 characters)
  execute_process(
    COMMAND ${GIT_EXECUTABLE} rev-parse --short HEAD
    WORKING_DIRECTORY
      ${CMAKE_CURRENT_SOURCE_DIR} # Ensure commands run in correct repo
    OUTPUT_VARIABLE _git_hash
    OUTPUT_STRIP_TRAILING_WHITESPACE
  )
  # Execute Git command to obtain a human-readable description (prefers tags,
  # falls back to commit hash, marks dirty working tree)
  execute_process(
    COMMAND ${GIT_EXECUTABLE} describe --tags --always --dirty
    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
    OUTPUT_VARIABLE _git_describe
    OUTPUT_STRIP_TRAILING_WHITESPACE
  )
else()
  # Fallback values when Git is unavailable or no repository exists
  set(_git_hash "unknown")
  set(_git_describe "no-git")
endif()

# Captures the username of the user who initiated the build process. Checks
# environment variables in order of Unix (`USER`) the Windows (`USERNAME`)
# conventions.
if(DEFINED ENV{USER})
  set(_build_user "$ENV{USER}")
elseif(DEFINED ENV{USERNAME})
  set(_build_user "$ENV{USERNAME}")
else()
  set(_build_user "unknown")
endif()

# Retrieves a string describing the build host system (combining ystem name,
# version, and processor). This is pre-defined by CMake and useful for
# distinguishing build environments.
set(_build_host "${CMAKE_HOST_SYSTEM}")

# Writes all collected metadata into a properly formatted C/C++ header file. The
# output filename and header guard macro name are controlled by caller-provided
# variables `OUTPUT` and `NAME`.
file(
  WRITE
    ${OUTPUT} # Output file path (must be provided by caller)
  "/*
 * This file is auto-generated by
 * ${CMAKE_CURRENT_SOURCE_DIR}/cmake/buildinfo.script.cmake
 * DO NOT EDIT IT DIRECTLY!
 */

#ifndef ${NAME}_BUILDINFO_H_
#define ${NAME}_BUILDINFO_H_

/*
 * Build Metadata - Captured at CMake configuration time
 */

// Timestamp of this build configuration (ISO 8601 format with timezone)
#define BUILD_TIMESTAMP \"${_timestamp}\"

// Build configuration type (e.g., DEBUG, RELEASE, RELWITHDEBINFO)
#define BUILD_TYPE      \"${_build_type_upper}\"

// User account that executed the CMake configuration
#define BUILD_USER      \"${_build_user}\"

// System identification of the build host machine
#define BUILD_HOST      \"${_build_host}\"

/*
 * Platform Architecture Information
 */

// Target operating system (where compiled binaries will run)
#define TARGET_SYSTEM       \"${_system_name}\"

// Target CPU architecture (e.g., x86_64, ARM64)
#define TARGET_ARCHITECTURE \"${_system_processor}\"

// Host operating system (where compilation is performed)
// Differs from TARGET_SYSTEM in cross-compilation scenarios
#define HOST_SYSTEM         \"${CMAKE_HOST_SYSTEM_NAME}\"

/*
 * Compiler Toolchain Information
 */

// Compiler vendor identification (e.g., GNU, Clang, MSVC)
#define COMPILER_ID      \"${_compiler_id}\"

/*
 * Version Control Information (Git)
 */

// Abbreviated Git commit hash (7 characters) or \"unknown\"
#define COMPILER_VERSION \"${_compiler_version}\"

// Git description (tag with commit count, or commit hash)
// Includes \"-dirty\" suffix if working tree has uncommitted changes
#define GIT_COMMIT_HASH \"${_git_hash}\"
#define GIT_DESCRIBE    \"${_git_describe}\"

#endif // ${NAME}_BUILDINFO_H_
"
)
