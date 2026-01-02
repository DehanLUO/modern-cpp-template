# ==============================================================================
# CMake Module: Project Configuration and Build Options
# ==============================================================================
# Centralized configuration module defining build targets, compiler options,
# tool integrations, and quality assurance features. All options are namespaced
# with project prefix to avoid conflicts.
# ==============================================================================

# ------------------------------------------------------------------------------
# Primary Build Target Configuration
# ------------------------------------------------------------------------------
# Defines project type via cache variable with constrained values.
set(
  ${PROJECT_NAME}_BUILD_TARGET
  "LIBRARY" # Default value (static/shared library)
  CACHE STRING
  "EXECUTABLE;LIBRARY;INTERFACE" #< Description
)
# Constrains GUI selection to predefined values in cmake-gui/ccmake.
set_property(
  CACHE ${PROJECT_NAME}_BUILD_TARGET
  PROPERTY STRINGS "EXECUTABLE;LIBRARY;INTERFACE"
)

# Normalize input to uppercase for case-insensitive validation.
string(TOUPPER "${${PROJECT_NAME}_BUILD_TARGET}" ${PROJECT_NAME}_BUILD_TARGET)

# Map target type to internal configuration variables.
if("EXECUTABLE" STREQUAL ${PROJECT_NAME}_BUILD_TARGET)
  set(${PROJECT_NAME}_build_executable ON) # Build executable target
elseif("INTERFACE" STREQUAL ${PROJECT_NAME}_BUILD_TARGET)
  set(${PROJECT_NAME}_build_headers_only ON) # Header-only interface library
elseif(NOT "LIBRARY" STREQUAL ${PROJECT_NAME}_BUILD_TARGET)
  # Validation failure: invalid selection
  message(
    FATAL_ERROR
    "Invalid build target selection. Use ccmake to choose from valid options."
  )
endif()

# ------------------------------------------------------------------------------
# Compiler Warnings Configuration
# ------------------------------------------------------------------------------
# Enforces strict warning policy by treating warnings as fatal errors.
option(
  ${PROJECT_NAME}_WARNINGS_AS_ERRORS
  "Treat all compiler warnings as errors, causing build failure on warnings." #< Description
  OFF # Default: warnings do not fail build
)

# ------------------------------------------------------------------------------
# Dependency Management System Selection
# ------------------------------------------------------------------------------
# Package manager integration options (mutually exclusive recommended).
option(
  ${PROJECT_NAME}_ENABLE_CONAN
  "Enable Conan C/C++ package manager for dependency resolution."
  OFF
)
option(
  ${PROJECT_NAME}_ENABLE_VCPKG
  "Enable vcpkg C++ library manager from Microsoft."
  OFF
)
# TODO: Implement CPM.cmake (CMake Package Manager) support

# ------------------------------------------------------------------------------
# Unit Testing Framework Configuration
# ------------------------------------------------------------------------------
# Master switch for unit test infrastructure.
option(
  ${PROJECT_NAME}_ENABLE_UNIT_TESTING
  "Build and execute unit tests from project's test directory."
  ON # Default: testing enabled
)

# Testing framework selection (Google Test preferred).
option(${PROJECT_NAME}_USE_GTEST "Use GoogleTest framework for unit tests." ON)
option(
  ${PROJECT_NAME}_USE_GOOGLE_MOCK
  "Enable GoogleMock extension for mocking capabilities."
  OFF
)
option(${PROJECT_NAME}_USE_CATCH2 "Use Catch2 framework for unit tests." OFF)

# ------------------------------------------------------------------------------
# Code Formatting Configuration
# ------------------------------------------------------------------------------
# Master switch for Code Formatting.
option(
  ${PROJECT_NAME}_ENABLE_CODE_FORMAT
  "Enable automated code formatting tools and targets (e.g., clang-format)."
  ON # Default value: formatting enabled
)

# ------------------------------------------------------------------------------
# Static Analysis Tool Integration
# ------------------------------------------------------------------------------
# Code quality analysis tools (can be combined).
option(
  ${PROJECT_NAME}_ENABLE_CLANG_TIDY
  "Enable Clang-Tidy for C++ static analysis and style checks."
  OFF
)
option(
  ${PROJECT_NAME}_ENABLE_CPPCHECK
  "Enable Cppcheck for static analysis of C/C++ code."
  OFF
) # TODO:

# ------------------------------------------------------------------------------
# Code Coverage Instrumentation
# ------------------------------------------------------------------------------
# Test coverage measurement via GCC's gcov.
option(
  ${PROJECT_NAME}_ENABLE_CODE_COVERAGE
  "Instrument code for test coverage analysis using GCC gcov."
  OFF
)

# ------------------------------------------------------------------------------
# Documentation Generation
# ------------------------------------------------------------------------------
# API documentation via Doxygen.
option(
  ${PROJECT_NAME}_ENABLE_DOXYGEN
  "Generate HTML documentation from source code comments."
  OFF
)

# ------------------------------------------------------------------------------
# Development and Tooling Support
# ------------------------------------------------------------------------------
# Generate compilation database for IDE/tool integration.
set(CMAKE_EXPORT_COMPILE_COMMANDS ON) # Creates compile_commands.json

# Enable colored diagnostic output for build logs.
set(CMAKE_COLOR_DIAGNOSTICS ON)

# Verbose output control for debugging.
option(
  ${PROJECT_NAME}_VERBOSE_OUTPUT
  "Display detailed configuration messages for debugging."
  ON
)

# Symbol export header generation for shared libraries.
option(
  ${PROJECT_NAME}_GENERATE_EXPORT_HEADER
  "Generate export header for controlling symbol visibility."
  ON
)

# ------------------------------------------------------------------------------
# Shared Library Symbol Visibility
# ------------------------------------------------------------------------------
# Control symbol visibility when building shared libraries.
if(BUILD_SHARED_LIBS)
  set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS OFF) # Manual export control
  set(CMAKE_CXX_VISIBILITY_PRESET hidden) # Hide symbols by default
  set(CMAKE_VISIBILITY_INLINES_HIDDEN 1) # Hide inline function symbols
endif()

# ------------------------------------------------------------------------------
# Link-Time Optimization (LTO)
# ------------------------------------------------------------------------------
# Whole-program optimization across translation units.
option(
  ${PROJECT_NAME}_ENABLE_LTO
  "Enable interprocedural optimization during linking."
  OFF
) # TODO:

if(${PROJECT_NAME}_ENABLE_LTO)
  include(CheckIPOSupported) # CMake module for LTO detection
  check_ipo_supported(RESULT result OUTPUT output) # Test compiler support

  if(result)
    set(CMAKE_INTERPROCEDURAL_OPTIMIZATION TRUE) # Enable globally
  else()
    message(SEND_ERROR "LTO unsupported by compiler: ${output}")
  endif()
endif()

# ------------------------------------------------------------------------------
# Compilation Caching with Ccache
# ------------------------------------------------------------------------------
# Accelerate rebuilds using compilation cache.
option(
  ${PROJECT_NAME}_ENABLE_CCACHE
  "Use Ccache to cache compilation results for faster rebuilds."
  ON
) # TODO:

find_program(CCACHE_FOUND ccache) # Detect ccache installation

if(CCACHE_FOUND)
  # Intercept compile and link commands globally
  set_property(GLOBAL PROPERTY RULE_LAUNCH_COMPILE ccache)
  set_property(GLOBAL PROPERTY RULE_LAUNCH_LINK ccache)
endif()

# ------------------------------------------------------------------------------
# Memory Sanitizer Integration
# ------------------------------------------------------------------------------
# Runtime memory error detection via AddressSanitizer.
option(
  ${PROJECT_NAME}_ENABLE_ASAN
  "Enable AddressSanitizer for detecting memory corruption errors."
  OFF
) # TODO:

if(${PROJECT_NAME}_ENABLE_ASAN)
  add_compile_options(-fsanitize=address) # Compile with ASan instrumentation
  add_link_options(-fsanitize=address) # Link with ASan runtime
endif()
