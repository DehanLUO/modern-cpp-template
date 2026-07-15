# ==============================================================================
# CMake Main Build Configuration
# ==============================================================================
# Primary CMakeLists.txt file defining the complete build system for a C++
# project. This orchestrates all configuration modules, defines build targets,
# and establishes installation rules. The structure follows a logical flow:
# initialization, configuration, target definition, dependency resolution, and
# finalization.
#
# TODO Notes:
# 1. Review and enhance module documentation where needed
# 2. Consider symbolic link installation on Unix systems
# 3. Verify CMake feature compatibility across versions
# ==============================================================================

cmake_minimum_required(VERSION 3.28)

# NOTE: If you change the project name below (e.g., from "Project" to "MyLib"),
# be sure to update all related references throughout the codebase:
# - Rename the include directory: ./include/Project/ → ./include/mylib/
# - Update the PROJECT_NAME variable in ./Makefile (e.g., PROJECT_NAME := MyLib)
# Failure to synchronize these will break builds, tests, and documentation
# generation.

# ------------------------------------------------------------------------------
# MSVC Runtime Library Configuration (MUST precede project() call)
# ------------------------------------------------------------------------------
# Per CMake policy CMP0091, this must be set before the first project()
# call to take effect. Controls the C runtime library linkage for MSVC.
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>DLL")

project("Project" VERSION 0.1.0 LANGUAGES CXX)

# ------------------------------------------------------------------------------
# Build Directory Sanity Check
# ------------------------------------------------------------------------------
# Prevents in-source builds which would pollute the source directory
# with generated files. Requires separate build directory.
if(PROJECT_SOURCE_DIR STREQUAL PROJECT_BINARY_DIR)
  message(
    FATAL_ERROR
    "In-source builds are prohibited. Create and use a separate build directory."
  )
endif()

# ------------------------------------------------------------------------------
# Project Configuration Initialization
# ------------------------------------------------------------------------------
# Loads core configuration modules in logical sequence:
# 1. logging.cmake: Hierarchical logging system (must load first)
# 2. setup.cmake: Project variables, directory structure, source lists
# 3. utils.cmake: Helper functions (verbose_message, etc.)
# 4. config.cmake: Compiler flags, policies, build options
# 5. static_analysis.cmake: Code analysis tool integration
include(cmake/logging.cmake) # Hierarchical logging system
log_info("Logging system initialized — level: ${${PROJECT_NAME}_LOG_LEVEL}")
log_info("Build directory sanity check passed")

include(cmake/setup.cmake) # Project foundation setup
log_info("Loaded module: setup.cmake")

include(${cmake_utils}) # Utility functions
log_info("Loaded module: utils.cmake")

include(${cmake_config}) # Compiler and policy configuration
log_info("Loaded module: config.cmake")

# Static analysis tools
include(${cmake_clang_tidy})
log_info("Loaded module: clang_tidy.cmake")

include(${cmake_cppcheck})
log_info("Loaded module: cppcheck.cmake")

verbose_message("Configuration modules loaded successfully")

# ------------------------------------------------------------------------------
# Build Type Default Configuration
# ------------------------------------------------------------------------------
# Sets default build type to Debug if not specified via command line
# or cache. Single-configuration generators require explicit type.
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE "Debug")
  log_info("Default build type set to: ${CMAKE_BUILD_TYPE}")
else()
  log_info("Build type: ${CMAKE_BUILD_TYPE}")
endif()

log_info("Project: ${PROJECT_NAME} v${PROJECT_VERSION}")

# ------------------------------------------------------------------------------
# Platform-Specific Debug Macro
# ------------------------------------------------------------------------------
# Defines _DEBUG macro on Unix platforms when in Debug configuration,
# providing parity with MSVC's automatic _DEBUG definition.
if(UNIX)
  add_compile_options("$<$<CONFIG:DEBUG>:-D_DEBUG>")
  log_info("Platform: UNIX — enabled _DEBUG macro for Debug configuration")
endif(UNIX)

# ------------------------------------------------------------------------------
# Package Manager Integration
# ------------------------------------------------------------------------------
# Conditionally includes package manager modules based on configuration.
# These modules handle dependency resolution via Conan or vcpkg.
include(${cmake_conan}) # Conan package manager support
if(${PROJECT_NAME}_ENABLE_CONAN)
  log_info("Package manager: Conan enabled")
endif()

include(${cmake_vcpkg}) # vcpkg package manager support
if(${PROJECT_NAME}_ENABLE_VCPKG)
  log_info("Package manager: vcpkg enabled")
endif()

# ------------------------------------------------------------------------------
# Source File Discovery and Registration
# ------------------------------------------------------------------------------
# Loads module that defines source file variables (library_sources,
# exe_sources, public_headers, test_sources).
include(${cmake_sources})

verbose_message("Source file variables defined")

# ------------------------------------------------------------------------------
# Target Creation Based on Project Type
# ------------------------------------------------------------------------------
# Creates appropriate CMake targets according to configured build type:
# - Header-only library (INTERFACE target)
# - Static/shared library
# - Optional executable target
if(${PROJECT_NAME}_build_headers_only)
  # Header-only INTERFACE library: contains only headers, no compiled code
  add_library(${PROJECT_NAME} INTERFACE)
  log_info("Created INTERFACE library target: ${PROJECT_NAME}")

  # List headers for developer visibility in verbose mode
  verbose_list_message(public_headers)

  # Associate headers with target using FILE_SET for proper installation
  target_sources(
    ${PROJECT_NAME}
    PUBLIC
      FILE_SET headers
        TYPE HEADERS
        BASE_DIRS
          ${dir_include} # Source headers
          ${dir_binary_include} # Generated headers
        FILES
          ${public_headers} # Public API headers
          ${header_version} # Generated version header
          ${header_export} # Generated export header
  )
else()
  # Static or shared library with compiled implementation
  add_library(${PROJECT_NAME})
  log_info("Created library target: ${PROJECT_NAME}")

  # Display source file listings for verification
  verbose_list_message(public_headers)
  verbose_list_message(library_sources)

  # Configure target sources: headers (PUBLIC) and implementation (PRIVATE)
  target_sources(
    ${PROJECT_NAME}
    PUBLIC
      FILE_SET headers
        TYPE HEADERS
        BASE_DIRS
          ${dir_include} # Source headers
          ${dir_binary_include} # Generated headers
        FILES
          ${public_headers} # Public API headers
          ${header_version} # Generated version header
          ${header_export} # Generated export header
    PRIVATE
      ${library_sources} # Implementation sources
  )
  log_info("Configured target sources for library: ${PROJECT_NAME}")

  # Create executable target if configured
  if(${PROJECT_NAME}_build_executable)
    add_executable(${PROJECT_NAME}_exe)
    log_info("Created executable target: ${PROJECT_NAME}_exe")

    verbose_list_message(exe_sources)
    target_sources(${PROJECT_NAME}_exe PRIVATE ${exe_sources})
    log_info("Configured target sources for executable: ${PROJECT_NAME}_exe")
  endif()
endif()

# ------------------------------------------------------------------------------
# Target Output Configuration
# ------------------------------------------------------------------------------
# Sets output directories and naming conventions for library targets
set_target_properties(
  ${PROJECT_NAME}
  PROPERTIES
    ARCHIVE_OUTPUT_DIRECTORY
      ${dir_binary_lib} # Static libraries
    LIBRARY_OUTPUT_DIRECTORY
      ${dir_binary_lib} # Shared libraries
    # Versioned output name with debug suffix: libProject[_d].0.1.0
    OUTPUT_NAME ${PROJECT_NAME}$<$<CONFIG:Debug>:_d>.${PROJECT_VERSION}
)

# Configure executable output if applicable
if(${PROJECT_NAME}_build_executable)
  set_target_properties(
    ${PROJECT_NAME}_exe
    PROPERTIES
      RUNTIME_OUTPUT_DIRECTORY
        ${dir_binary_bin} # Executable directory
      # Versioned output name with debug suffix: Project[_d].0.1.0
      OUTPUT_NAME ${PROJECT_NAME}$<$<CONFIG:Debug>:_d>.${PROJECT_VERSION}
  )
endif()

verbose_message("Target output directories configured")

# ------------------------------------------------------------------------------
# C++ Language Standard Enforcement
# ------------------------------------------------------------------------------
# Sets C++17 standard requirement for all targets
if(${PROJECT_NAME}_build_headers_only)
  # INTERFACE targets propagate requirements to consumers
  target_compile_features(${PROJECT_NAME} INTERFACE cxx_std_17)
else()
  # Regular libraries require C++17 for themselves and consumers
  target_compile_features(${PROJECT_NAME} PUBLIC cxx_std_17)

  if(${PROJECT_NAME}_build_executable)
    target_compile_features(${PROJECT_NAME}_exe PUBLIC cxx_std_17)
  endif()
endif()

log_info("C++17 standard enforced for all targets")

# ------------------------------------------------------------------------------
# Static Library Build Macro
# ------------------------------------------------------------------------------
# Defines PROJECT_STATIC_DEFINE when the library is built as a static library
# (i.e., when BUILD_SHARED_LIBS is OFF and the target contains compiled sources).
# This macro informs the export header that symbol import/export specifiers
# (such as __declspec or visibility attributes) should be disabled, ensuring
# correct compilation and linking in static library mode across all platforms.
#
# Note: This definition is intentionally skipped for INTERFACE libraries as such
# targets do not produce object code and are never linked directly. Consequently,
# they do not participate in symbol export/import logic and should not define
# PROJECT_STATIC_DEFINE.
if(NOT ${PROJECT_NAME}_build_headers_only)
  target_compile_definitions(
    ${PROJECT_NAME}
    PUBLIC "$<$<NOT:$<BOOL:${BUILD_SHARED_LIBS}>>:PROJECT_STATIC_DEFINE>"
  )
endif()

# ------------------------------------------------------------------------------
# Compiler Warning Configuration
# ------------------------------------------------------------------------------
# Applies project-specific warning flags to targets
include(${cmake_compiler_warnings})
set_project_warnings(${PROJECT_NAME})

verbose_message("Compiler warnings applied to targets")

# ------------------------------------------------------------------------------
# Dependency Linking
# ------------------------------------------------------------------------------
# TODO: Insert project-specific dependency resolution here
# Example pattern:
# find_package(SomeLib 1.0 REQUIRED)
# target_link_libraries(${PROJECT_NAME} PUBLIC SomeLib::SomeLib)

# Link executable to library if both exist
if(${PROJECT_NAME}_build_executable)
  target_link_libraries(${PROJECT_NAME}_exe PRIVATE ${PROJECT_NAME})
endif()

verbose_message("Dependencies linked successfully")

# ------------------------------------------------------------------------------
# Installation Configuration
# ------------------------------------------------------------------------------
# Defines rules for installing targets, headers, and CMake package files
include(GNUInstallDirs) # Standard installation directory variables
log_info("GNUInstallDirs loaded: prefix=${CMAKE_INSTALL_PREFIX}")

# Install library target with export set for downstream consumption
install(
  TARGETS ${PROJECT_NAME}
  EXPORT
    ${PROJECT_NAME}Targets # Creates export set
  LIBRARY
    DESTINATION
      ${CMAKE_INSTALL_LIBDIR} # Shared libraries
  RUNTIME
    DESTINATION
      ${CMAKE_INSTALL_BINDIR} # Executables / DLLs on Windows
  ARCHIVE
    DESTINATION
      ${CMAKE_INSTALL_LIBDIR} # Static libraries
  FILE_SET headers
    DESTINATION
      include # Install headers
)
log_info("Installation rules configured for library target")

# Install executable if present
if(${PROJECT_NAME}_build_executable)
  install(
    TARGETS ${PROJECT_NAME}_exe
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
  )
  log_info("Installation rules configured for executable target")
endif()

# Install export set for find_package() compatibility
install(
  EXPORT ${PROJECT_NAME}Targets
  FILE ${PROJECT_NAME}Targets.cmake
  NAMESPACE
    ${PROJECT_NAME}:: # Namespace for imported targets
  DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/${PROJECT_NAME}
)
log_info("Export set installed to: ${CMAKE_INSTALL_LIBDIR}/cmake/${PROJECT_NAME}")

verbose_message("Installation rules configured")

# ------------------------------------------------------------------------------
# CMake Package Configuration Files
# ------------------------------------------------------------------------------
# Generates Config.cmake and ConfigVersion.cmake for downstream projects
include(CMakePackageConfigHelpers)

# Version compatibility file (SameMajorVersion: compatible within major version)
write_basic_package_version_file(
  ${PROJECT_NAME}ConfigVersion.cmake
  VERSION ${PROJECT_VERSION}
  COMPATIBILITY SameMajorVersion
)
log_info("Generated package version file: ${PROJECT_NAME}ConfigVersion.cmake")

# Main package configuration file from template
configure_package_config_file(
  ${cmake_packageconfig} # Input template
  ${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}Config.cmake # Output file
  INSTALL_DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/${PROJECT_NAME}
)
log_info("Generated package config file: ${PROJECT_NAME}Config.cmake")

# Install both package configuration files
install(
  FILES
    ${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}Config.cmake
    ${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}ConfigVersion.cmake
  DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/${PROJECT_NAME}
)
log_info("Package config files installed")

verbose_message("Package configuration files generated")

# ------------------------------------------------------------------------------
# Build Information Header Generation
# ------------------------------------------------------------------------------
# Uses CMake's `configure_file` command to process a template file containing
# version information (e.g., major/minor/patch numbers). The `@ONLY` parameter
# restricts variable substitution to variables marked with `@VARIABLE@` syntax
# in the template, providing precise control over the substitution process.
configure_file(${hppin_version} ${header_version} @ONLY)
log_info("Generated version header: ${header_version}")

# Generates build-time metadata headers (timestamp, compiler, git info)
include(${cmake_buildinfo})
log_info("Loaded module: buildinfo.cmake")

# ------------------------------------------------------------------------------
# Export Header Generation (Optional)
# ------------------------------------------------------------------------------
# The generated header is only created if ${PROJECT_NAME}_GENERATE_EXPORT_HEADER
# is enabled (typically ON for libraries with compiled sources, OFF for
# header-only or INTERFACE targets).
if(${PROJECT_NAME}_GENERATE_EXPORT_HEADER)
  # Conditionally generates a platform-aware export header (e.g., project_export.h)
  # using CMake's GenerateExportHeader module. This header defines macros such as
  # PROJECT_EXPORT to handle symbol visibility on Windows (__declspec) and
  # Unix-like systems (__attribute__((visibility(...)))), enabling correct
  # import/export behavior for shared libraries.
  include(GenerateExportHeader)
  generate_export_header(${PROJECT_NAME})
  log_info("Generated export header via GenerateExportHeader")

  # Avoid unnecessary file I/O by checking if the destination header already
  # exists. This is especially useful in iterative development where CMake
  # re-runs frequently.
  if(NOT EXISTS ${header_export})
    # Copy the auto-generated export header to the designated output path. Using
    # execute_process ensures the copy occurs at configure time (not generate
    # time), aligning with the timing of generate_export_header's output.
    execute_process(
      COMMAND
        ${CMAKE_COMMAND} -E copy
        ${CMAKE_CURRENT_BINARY_DIR}/${project_name_lowercase}_export.h
        ${header_export}
      WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    )

    log_info("Export header copied to: ${header_export}")
  else()
    log_debug("Export header already exists, skipping copy: ${header_export}")
  endif()
else()
  log_debug("Export header generation disabled")
endif()

# ------------------------------------------------------------------------------
# Documentation Generation (Optional)
# ------------------------------------------------------------------------------
# Configures Doxygen if enabled in project options
if(${PROJECT_NAME}_ENABLE_DOXYGEN)
  include(${cmake_doxygen})
  log_info("Doxygen documentation generation enabled")
else()
  log_debug("Doxygen documentation generation disabled")
endif()

# ------------------------------------------------------------------------------
# Unit Testing Infrastructure
# ------------------------------------------------------------------------------
# Enables and configures unit testing if requested
if(${PROJECT_NAME}_ENABLE_UNIT_TESTING)
  enable_testing() # Activates CMake's testing subsystem
  log_info("Unit testing enabled — CTest subsystem activated")
  add_subdirectory(test) # Recursively process test/CMakeLists.txt
  log_info("Added test subdirectory")
else()
  log_debug("Unit testing disabled")
endif()

# ------------------------------------------------------------------------------
# Code Formatting Target
# ------------------------------------------------------------------------------
# Adds clang-format target for code formatting:
#   `cmake --build build --target clang-format`
if(${PROJECT_NAME}_ENABLE_CODE_FORMAT)
  include(${cmake_format})
  add_clang_format_target()
  log_info("Code formatting target 'clang-format' registered")
else()
  log_debug("Code formatting disabled")
endif()
