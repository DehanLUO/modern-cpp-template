# ==============================================================================
# CMake Module: Compiler Warning Configuration
# ==============================================================================
# This module defines compiler-specific warning flags for three major C++
# compilers: Microsoft Visual C++ (MSVC), Clang/AppleClang, and GNU GCC. The
# configuration is adapted from industry best practices documented in "C++ Best
# Practices" by Jason Turner, specifically the section on utilizing compiler
# diagnostics effectively.
#
# Source reference:
#   https://github.com/lefticus/cppbestpractices/blob/master/02-Use_the_Tools_Available.md
#
# The module provides a function to apply these warnings to CMake targets, with
# conditional logic to handle different project types (libraries, executables,
# unit tests) and compilation modes (warnings vs. warnings-as-errors).
# ==============================================================================

# ------------------------------------------------------------------------------
# Function: set_project_warnings
# ------------------------------------------------------------------------------
# Applies the selected compiler warnings to a specified CMake target. This
# function handles conditional logic for different target types (libraries,
# executables, unit tests) and project configurations.
#
# Parameters:
#   project_name: Name of the CMake target to apply warnings to
function(set_project_warnings project_name)
  # Validate that the specified target exists before attempting configuration
  if(NOT TARGET ${project_name})
    message(
      AUTHOR_WARNING
      "Cannot apply compiler warnings: Target '${project_name}' does not exist. "
      "This may indicate a configuration error or missing target declaration."
    )

    return() # Exit function early to avoid CMake configuration errors
  endif()

  # Initialize unit test detection flag
  set(_is_unit_test FALSE) # Initialize unit test flag to false.

  # Determine if the target is a unit test by comparing against the main project
  # name Unit tests are typically named differently from the main
  # library/executable
  if(NOT "${project_name_copy}" STREQUAL "${project_name}")
    set(_is_unit_test TRUE)
  endif()

  # Apply warnings to appropriate targets based on project type:
  # 1. Always apply to unit test targets (for maximum diagnostic coverage)
  # 2. Apply to non-header-only library targets (libraries with implementation).
  #    Header-only libraries are excluded as they contain only declaration code
  if(${_is_unit_test} OR NOT ${PROJECT_NAME}_build_headers_only)
    target_compile_options(
      ${project_name} # Target receiving the warning flags
      PRIVATE # Apply flags only to this target, not to dependent targets
        ${project_warnings} # The selected compiler warning set
    )
  endif()

  # Special handling for executable targets in non-unit-test contexts
  # Executable targets may have a different naming convention (suffix _exe)
  if(NOT ${_is_unit_test} AND ${project_name_copy}_build_executable)
    target_compile_options(
      ${project_name}_exe # Executable target name (assumes _exe suffix convention)
      PRIVATE ${project_warnings}
    )
  endif()
endfunction()

# Defines a comprehensive set of warning flags for the MSVC compiler
# (/W4 provides a high warning level, supplemented with specific diagnostic codes)
set(
  _msvc_warnings # Variable storing MSVC-specific warning flags
  /W4 # Enable warning level 4 (highest general warning level before /Wall)
  # Specific warning codes with descriptive comments for developer reference:
  /w14242 # 'identifier': conversion from 'type1' to 'type1', possible loss of data
  /w14254 # 'operator': conversion from 'type1:field_bits' to 'type2:field_bits', possible loss of data
  /w14263 # 'function': member function does not override any base class virtual member function
  /w14265 # 'classname': class has virtual functions, but destructor is not virtual instances of this class may not be destructed correctly
  /w14287 # 'operator': unsigned/negative constant mismatch
  /we4289 # nonstandard extension used: 'variable': loop control variable declared in the for-loop is used outside the for-loop scope
  /w14296 # 'operator': expression is always 'boolean_value'
  /w14311 # 'variable': pointer truncation from 'type1' to 'type2'
  /w14545 # expression before comma evaluates to a function which is missing an argument list
  /w14546 # function call before comma missing argument list
  /w14547 # 'operator': operator before comma has no effect; expected operator with side-effect
  /w14549 # 'operator': operator before comma has no effect; did you intend 'operator'?
  /w14555 # expression has no effect; expected expression with side- effect
  /w14619 # pragma warning: there is no warning number 'number'
  /w14640 # Enable warning on thread un-safe static member initialization
  /w14826 # Conversion from 'type1' to 'type_2' is sign-extended. This may cause unexpected runtime behavior.
  /w14905 # wide string literal cast to 'LPSTR'
  /w14906 # string literal cast to 'LPWSTR'
  /w14928 # illegal copy-initialization; more than one user-defined conversion has been implicitly applied
  # Compiler conformance flag (not a warning but included for standards compliance):
  /permissive- # standards conformance mode for MSVC compiler.
)

# Defines warning flags compatible with Clang and AppleClang compilers. Clang's
# warning system is generally more granular than MSVC's, with many semantic
# checks beyond simple syntax validation.
set(
  _clang_warnings # Variable storing Clang-compatible warning flags
  -Wall # Enable all generally useful warnings (not literally "all" warnings)
  -Wextra # Enable additional reasonable warnings beyond -Wall
  # Semantic warning flags with explanatory comments:
  -Wshadow # Warn when variable declarations shadow identifiers from outer scopes
  -Wnon-virtual-dtor # Warn when classes with virtual functions have non-virtual destructors
  -Wold-style-cast # Flag C-style casts, encouraging use of C++ cast operators
  -Wcast-align # Warn about casts that may increase alignment requirements
  -Wunused # Enable warnings for unused variables, parameters, and labels
  -Woverloaded-virtual # Warn when virtual functions are overloaded (not overridden)
  -Wpedantic # Enforce strict ISO C++ standard compliance
  -Wconversion # Warn about implicit type conversions that may alter values
  -Wsign-conversion # Specifically warn about implicit sign conversions
  -Wnull-dereference # Enable static analysis for potential null pointer dereferences
  -Wdouble-promotion # Warn when float values are implicitly promoted to double
  -Wformat=2 # Enable enhanced format string checking for security vulnerabilities
)

# If the project configuration requests treating warnings as errors, append the
# appropriate compiler-specific flags to enforce this policy. This is typically
# used in CI/CD pipelines or strict development environments.
if(${project_name_copy}_WARNINGS_AS_ERRORS)
  # Append -Werror flag for Clang/GCC compilers
  set(_clang_warnings ${_clang_warnings} -Werror)
  # Append /WX flag for MSVC compiler (treat warnings as errors)
  set(_msvc_warnings ${_msvc_warnings} /WX)
endif()

# GCC shares many warning flags with Clang but has additional GCC-specific
# diagnostics. This set builds upon the Clang warnings, extending them with
# GCC-only options for enhanced diagnostics.
set(
  _gcc_warnings # Variable storing GCC-specific warning flags
  ${_clang_warnings} # Inherit all Clang-compatible warnings
  # GCC-exclusive warning flags:
  -Wmisleading-indentation # Warn when code indentation suggests incorrect block structure
  -Wduplicated-cond # Detect duplicated conditions in if-else-if chains
  -Wduplicated-branches # Identify duplicated code blocks in conditional branches
  -Wlogical-op # Warn about potential logical operator misuse (e.g., || instead of |)
  -Wuseless-cast # Flag unnecessary casts to the same type
)

# Determine the active C++ compiler and select the appropriate warning set.
# CMake provides built-in variables for compiler identification.
if(MSVC)
  # MSVC compiler detected (including Visual Studio 2015+ and cl.exe)
  set(project_warnings ${_msvc_warnings})
elseif(CMAKE_CXX_COMPILER_ID MATCHES ".*Clang")
  # Clang or AppleClang compiler detected (MATCHES handles both "Clang" and "AppleClang")
  set(project_warnings ${_clang_warnings})
elseif(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
  # GNU GCC compiler detected
  set(project_warnings ${_gcc_warnings})
else()
  # Unsupported compiler detected - issue developer warning but continue configuration
  message(
    AUTHOR_WARNING # Only shown during CMake configuration, not during builds
    "No compiler warnings configured for '${CMAKE_CXX_COMPILER_ID}' compiler."
  )
endif()

# Remove temporary warning set variables to prevent namespace pollution and
# potential variable shadowing in parent scopes.
unset(_msvc_warnings)
unset(_clang_warnings)
unset(_gcc_warnings)
