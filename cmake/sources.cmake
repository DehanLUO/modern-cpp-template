# ==============================================================================
# CMake Module: Source File Configuration
# ==============================================================================
# SEPARATION RATIONALE:
# This module is deliberately isolated from the general directory configuration
# to facilitate maintenance and modification. Source file lists require frequent
# updates throughout the development lifecycle as files are added, removed, or
# renamed. By placing these definitions in a dedicated location, developers can:
#   1. Quickly locate and modify source file specifications
#   2. Maintain clear separation between static directory structure and dynamic
#      file listings
#   3. Avoid accidental modification of stable directory paths
#   4. Facilitate version control tracking of source file changes
#
# The paths defined here reference actual source files in the project directory
# structure. These placeholder values should be replaced with project-specific
# file lists, either through manual enumeration or automated discovery
# mechanisms.
# ==============================================================================

# ------------------------------------------------------------------------------
# Library Implementation Source Files
# ------------------------------------------------------------------------------
# Defines the C++ source files (.cpp, .cc, .cxx) that constitute the
# implementation of the library component. These files contain the compiled code
# for the library's functionality and are private to the library target (not
# exposed to consumers).
set(
  library_sources # OUTPUT: List of library implementation source files
  ${dir_src}/tmp.cpp
)

# ------------------------------------------------------------------------------
# Executable Entry Point Source File
# ------------------------------------------------------------------------------
# Defines the main application entry point source file that contains the main()
# function. This file is exclusive to executable targets and is conditionally
# included based on project configuration.
set(
  exe_sources # OUTPUT: Executable entry point source file(s)
  ${dir_src}/main.cpp
)

# ------------------------------------------------------------------------------
# Public API Header Files
# ------------------------------------------------------------------------------
# Defines the header files (.h, .hpp, .hxx) that constitute the public interface
# of the library. These headers define the API contract that consumers of the
# library will utilize and are distributed alongside the library binary during
# installation.
set(
  public_headers # OUTPUT: Public interface header files
  ${dir_include_${project_name_lowercase}}/tmp.hpp
)

# ------------------------------------------------------------------------------
# Unit Test Source Files
# ------------------------------------------------------------------------------
# Defines source files dedicated to unit testing the library's functionality.
# These files are typically compiled into a separate test executable and are
# excluded from production builds.
set(
  test_sources # OUTPUT: Unit test implementation source files
  ${dir_testsrc}/tmp_test.cpp
)
