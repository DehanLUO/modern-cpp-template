# ------------------------------------------------------------------------------
# Variable: project_name_copy
# ------------------------------------------------------------------------------
# Creates a stable, immutable copy of the CMake project name to prevent
# accidental modification of the built-in ${PROJECT_NAME} variable.
#
# Rationale:
# 1. ${PROJECT_NAME} is a CMake-managed variable that should generally remain
#    constant throughout the configuration process.
# 2. Using a copy provides insulation against unintended side effects if
#    ${PROJECT_NAME} were to be reassigned elsewhere in the build scripts.
# 3. This copy serves as a consistent identifier for creating project-specific
#    variable names and file paths throughout the build system.
#
# The variable name follows the convention of suffixing "_copy" to indicate it
# is a deliberate duplicate of the original value.
set(
  project_name_copy # Output variable name: stable project identifier
  "${PROJECT_NAME}" # Source value: CMake's built-in project name variable
)

# ------------------------------------------------------------------------------
# Variable:
#   ${project_name_copy}_build_executable
#   ${project_name_copy}_build_headers_only
# ------------------------------------------------------------------------------
# Defines a project-specific boolean configuration option indicating whether the
# project should build an executable/interface target in addition to any library
# components.
#
# Default Value: OFF
#   The conservative default assumes library-only projects unless explicitly
#   configured otherwise.
#
# Naming Convention:
#   The variable uses the project name as a prefix (${project_name_copy}_)
#   to create a unique namespace, preventing collisions with variables from
#   other projects in a multi-project CMake configuration.
#
# This variable will typically be reset by the project's main CMakeLists.txt
# based on project requirements, and may be queried by other CMake modules
# to conditionally configure executable-specific build rules.
set(
  ${project_name_copy}_build_executable #< Build as an executable
  OFF # Default state: do not build an executable target
)
set(
  ${project_name_copy}_build_headers_only #< Build as a header-only library
  OFF # Default state: project contains source files requiring compilation
)

# ------------------------------------------------------------------------------
# Variable: project_name_lowercase
# ------------------------------------------------------------------------------
# Creates a lowercase transformation of the project name for use in contexts
# where case-insensitive or normalized naming is required.
#
# Common Use Cases:
# 1. Generating lowercase file names and directory paths
# 2. Creating consistent package names for package managers
# 3. Forming library names that follow lowercase conventions (e.g., Unix libraries)
# 4. Creating case-insensitive identifiers for cross-platform compatibility
string(TOLOWER ${PROJECT_NAME} project_name_lowercase)

# ------------------------------------------------------------------------------
# Variable: project_name_uppercase
# ------------------------------------------------------------------------------
# Creates an uppercase transformation of the project name for use in contexts
# where uppercase naming conventions are standard.
#
# Common Use Cases:
# 1. Generating C/C++ preprocessor macro names (header guards, feature macros)
# 2. Creating environment variable names (often uppercase by convention)
# 3. Forming CMake cache variable names (often uppercase for visibility)
# 4. Defining library export/import macros in cross-platform code
string(TOUPPER ${PROJECT_NAME} project_name_uppercase)

# ==============================================================================
# CMake Module: Directory Structure and Path Configuration
# ==============================================================================
# This module defines the complete directory hierarchy for the build system,
# establishing consistent paths for source files, generated artifacts,
# and configuration scripts. The structure follows standard CMake conventions
# while providing organization suitable for both development and installation.
#
# The directory layout is organized into two main categories:
# 1. Source directories: Locations of original source files (read-only)
# 2. Binary directories: Locations of generated files during build (writeable)
#
# All paths are constructed relative to either the project root or build
# directory to ensure portability across different build environments.
# ==============================================================================

# ------------------------------------------------------------------------------
# Project Root Directory Determination
# ------------------------------------------------------------------------------
# Resolves the absolute path to the project root directory (parent of the
# current script's location). This provides a stable reference point for all
# subsequent relative path constructions.
file(
  REAL_PATH
    "../" # Relative path to parent directory
  dir_root # Output variable: absolute project root path
  BASE_DIRECTORY
    "${CMAKE_CURRENT_LIST_DIR}" # Start from this script's directory
  EXPAND_TILDE # Expand ~ to home directory if present in path (CMake ≥3.28)
)

# ==============================================================================
# Binary (Build) Directory Structure
# ==============================================================================
# Defines the directory hierarchy within the build output directory
# (CMAKE_BINARY_DIR). This structure organizes generated artifacts by type and
# includes project/version namespacing to support simultaneous builds of
# multiple projects or versions.
# ------------------------------------------------------------------------------

# Base binary directory: Project-version namespaced build root
# Format: <build_dir>/<project_name>/<project_version>/
set(dir_binary ${CMAKE_BINARY_DIR}/${project_name_copy}/${PROJECT_VERSION})

# Executable output directory: Contains compiled binary executables
set(dir_binary_bin ${dir_binary}/bin)

# Library output directory: Contains compiled static/shared libraries
set(dir_binary_lib ${dir_binary}/lib)

# Coverage output directory: Contains coverage reports
set(dir_codecov ${CMAKE_BINARY_DIR}/coverage/${project_name_copy})

# ------------------------------------------------------------------------------
# Header File Directories (Build-time)
# ------------------------------------------------------------------------------
# Directory structure for generated header files that will be used during
# compilation. These headers are created during the build process (e.g., version
# headers, build info headers).

# Root include directory for generated headers
set(dir_binary_include ${dir_binary}/include)

# Project-specific generated include directory
# Format: <build_dir>/include/<project_name_lowercase>
set(
  dir_binary_include_${project_name_lowercase}
  ${dir_binary_include}/${project_name_lowercase}
)

# Generated version header file path
set(header_version ${dir_binary_include_${project_name_lowercase}}/version.hpp)

# ------------------------------------------------------------------------------
# Data and Source Code Directories (Build-time)
# ------------------------------------------------------------------------------
# Additional directories for build artifacts and generated source files.

# Shared data directory: For architecture-independent data files
set(dir_binary_share ${dir_binary}/share)

# Generated source directory: For build-time generated C++ source files
set(dir_binary_src ${dir_binary}/src)

# Build information header files (separate for library and executable targets)
set(header_buildinfo_lib ${dir_binary_src}/buildinfo_lib.hpp) # Library build info
set(header_buildinfo_bin ${dir_binary_src}/buildinfo_bin.hpp) # Executable build info

# ==============================================================================
# Source Directory: CMake Script Modules
# ==============================================================================
# Defines paths to CMake module files located in the project's
# `cmake/` directory. These modules provide reusable functionality for various
# aspects of the build system configuration.
# ------------------------------------------------------------------------------

# Base directory for CMake module files
set(dir_cmake ${dir_root}/cmake)

# Individual CMake module file paths with descriptive comments:

# Build information generation module
set(cmake_buildinfo ${dir_cmake}/buildinfo.cmake)

# Build information script (executed as separate process)
set(cmake_buildinfo_script ${dir_cmake}/buildinfo.script.cmake)

# Clang-Tidy configuration module
set(cmake_clang_tidy ${dir_cmake}/clang_tidy.cmake)

# Code coverage module
set(cmake_codecov ${dir_cmake}/codecov.cmake)

# Compiler warning configuration module
set(cmake_compiler_warnings ${dir_cmake}/compiler_warnings.cmake)

# Conan package manager integration
set(cmake_conan ${dir_cmake}/conan.cmake)

# Project configuration module
set(cmake_config ${dir_cmake}/config.cmake)

# Cppcheck configuration module
set(cmake_cppcheck ${dir_cmake}/cppcheck.cmake)

# Doxygen documentation generation
set(cmake_doxygen ${dir_cmake}/doxygen.cmake)

# Code formatting tools integration (clang-format, etc.)
set(cmake_format ${dir_cmake}/format.cmake)

# CMake package configuration template
set(cmake_packageconfig ${dir_cmake}/PackageConfig.cmake.in)

# Clang-generated .profraw files merge script (executed as separate process)
set(cmake_profraw_script ${dir_cmake}/profraw.script.cmake)

# Source file management and organization
set(cmake_sources ${dir_cmake}/sources.cmake)

# General utility functions
set(cmake_utils ${dir_cmake}/utils.cmake)

# vcpkg package manager integration
set(cmake_vcpkg ${dir_cmake}/vcpkg.cmake)

# Version header template file
set(hppin_version ${dir_cmake}/version.hpp.in)

# ==============================================================================
# Source Code Directories (Original Source Files)
# ==============================================================================
# Defines directories containing the project's original source code. These
# directories are read-only from CMake's perspective and contain the
# developer-authored source files.
# ------------------------------------------------------------------------------

# Main source code directory: Contains C++ implementation files (.cpp, .cc)
set(dir_src ${dir_root}/src)

# Header file directory: Contains public header files (.h, .hpp, .hxx)
set(dir_include ${dir_root}/include)

# Project-specific public header directory
# Format: include/<project_name_lowercase>/
set(
  dir_include_${project_name_lowercase}
  ${dir_include}/${project_name_lowercase}
)

# Test source directory: Contains unit test implementation files
set(dir_testsrc ${dir_root}/test/src)
