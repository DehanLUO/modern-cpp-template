# ==============================================================================
# CMake Module: Build Information Header Generation System
# ==============================================================================
# This module provides a comprehensive mechanism for generating and maintaining
# build information header files within a CMake project. It supports multiple
# targets (library, executable) and ensures that build metadata is properly
# integrated into the build system dependency graph. The system consists of
# three key components:
#   1. Configuration of a static version header via `configure_file`
#   2. Dynamic generation of build information headers via external CMake script
#      execution
#   3. Integration of generated headers into target source sets with proper
#      dependency management
# ==============================================================================

# ------------------------------------------------------------------------------
# Macro: generate_commands_to_buildinfo_header
# ------------------------------------------------------------------------------
# Constructs the command line invocation for executing the external build
# information generation script. This macro centralizes the command construction
# to ensure consistency across different invocation contexts.
#
# WARNING: This macro creates a LOCAL variable `_commands` in the caller's scope
# containing the complete command list. Callers must be aware that:
# 1. `_commands` will be overwritten if it already exists in the caller's scope
# 2. The variable persists in the caller's scope after macro execution
# 3. The caller is responsible for using `_commands` before it goes out of scope
#
# PRECONDITION: The caller must define the following variables before invocation:
#   - `output`: Path to the output header file
#   - `project_name_uppercase`: Uppercase project name for header guard
#   - `cmake_buildinfo_script`: Path to the build info generation script
#
# POSTCONDITION: Variable `_commands` contains a list suitable for passing to
#                execute_process() or add_custom_command()
macro(generate_commands_to_buildinfo_header)
  # Creates/overwrites the variable `_commands` in the caller's scope
  set(
    _commands # Local variable storing the complete command list
    "${CMAKE_COMMAND}" # Path to CMake executable
    # Pass essential CMake context variables to the script process:
    "-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}" # Current build configuration
    "-DCMAKE_CXX_COMPILER_ID=${CMAKE_CXX_COMPILER_ID}" # Compiler vendor
    "-DCMAKE_CXX_COMPILER_VERSION=${CMAKE_CXX_COMPILER_VERSION}" # Compiler version
    "-DCMAKE_HOST_SYSTEM=${CMAKE_HOST_SYSTEM}" # Full host system description
    "-DCMAKE_HOST_SYSTEM_NAME=${CMAKE_HOST_SYSTEM_NAME}" # Host OS name
    "-DCMAKE_SYSTEM_NAME=${CMAKE_SYSTEM_NAME}" # Target OS name
    "-DCMAKE_SYSTEM_PROCESSOR=${CMAKE_SYSTEM_PROCESSOR}" # Target architecture
    # Project-specific parameters:
    "-DNAME_LOWERCASE=${project_name_lowercase}" # for namespace
    "-DNAME_UPPERCASE=${project_name_uppercase}" # for header guard
    "-DOUTPUT=${output}" # Output file path (must be defined before macro call)
    # Script execution directive:
    "-P ${cmake_buildinfo_script}" # Execute the specified CMake script file
  )
endmacro()

# ------------------------------------------------------------------------------
# Function: generate_buildinfo_header
# ------------------------------------------------------------------------------
# Primary function for initial generation of build information headers.
# Implements a conditional execution pattern: the header is generated only if it
# does not already exist, preventing unnecessary rebuilds during initial
# configuration.
function(generate_buildinfo_header output)
  # Check for existence of the output file to avoid redundant generation
  if(NOT EXISTS ${output})
    message(STATUS "Generating initial build information header: ${output}")

    # Invoke the command construction macro. Note: this relies on the
    # variable `output` being defined in the function's scope.
    generate_commands_to_buildinfo_header() #< _commands

    # Execute the generated command sequence as a separate process.
    execute_process(
      COMMAND ${_commands}
      # The working directory is set to the current source directory to ensure
      # proper Git repository detection (if applicable).
      WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
    )
  endif()
endfunction()

# ------------------------------------------------------------------------------
# Function: update_version_header
# ------------------------------------------------------------------------------
# Creates a custom command rule for regenerating build information headers when
# dependencies change. This function integrates the header generation into
# CMake's dependency tracking system, ensuring headers are updated when source
# files are modified.
function(update_version_header output)
  # Construct the command sequence (same as initial generation)
  generate_commands_to_buildinfo_header() #< _commands

  # Define a custom command that will be executed during the build phase when
  # the output is out-of-date relative to its dependencies.
  add_custom_command(
    OUTPUT
      ${output} # The file this command produces
    DEPENDS
      ${ARGN} # Variable list of source files that trigger regeneration
    COMMAND
      ${_commands} # Command to execute when regeneration is needed
    COMMENT
      "Regenerating build information header: ${output}" # Build log message
  )
endfunction()

################################################################################
#                 Library Target Build Information Integration                 #
################################################################################

# Generate the initial build information header for the library target (executed
# during CMake configuration phase).
generate_buildinfo_header(${header_buildinfo_lib})

# Establish a dependency relationship: the library target depends on the header
# being generated before compilation can proceed.
add_dependencies(${project_name_copy} ${project_name_copy}_header_buildinfo_lib)

# Integrate the generated header into the library target's source set. The
# FILE_SET mechanism organizes headers logically within the project structure,
# with BASE_DIRS specifying the search path for inclusion.
add_custom_target(
  ${project_name_copy}_header_buildinfo_lib
  DEPENDS ${header_buildinfo_lib}
)

target_sources(
  ${PROJECT_NAME} # The library target name
  PRIVATE # Header visibility scope (internal to this target)
    FILE_SET
      buildinfo # Logical grouping name for these headers
      TYPE
        HEADERS # CMake 3.23+ feature for header classification
      BASE_DIRS
        ${dir_binary_src} # Base directory for header inclusion
      FILES
        ${header_buildinfo_lib} # The actual header file
)

# Only generate executable-specific build information if the project configures
# an executable target.
if(${PROJECT_NAME}_build_executable)
  # Generate initial header for the executable target
  generate_buildinfo_header(${header_buildinfo_bin})

  # Establish dependency: executable target requires header generation
  add_dependencies(
    ${project_name_copy}_exe
    ${project_name_copy}_header_buildinfo_bin
  )

  # Create custom target for explicit executable header building
  add_custom_target(
    ${project_name_copy}_header_buildinfo_bin
    DEPENDS ${header_buildinfo_bin}
  )

  # Integrate header into executable target's source set
  target_sources(
    ${PROJECT_NAME}_exe # Executable target name
    PRIVATE
      FILE_SET buildinfo
        TYPE HEADERS
        BASE_DIRS ${dir_binary_src}
        FILES ${header_buildinfo_bin}
  )
endif()

# Configures automatic regeneration of build information headers when source
# files change. The dependency structure varies based on  project type
# (header-only vs. library vs. executable).
if(${project_name_copy}_build_headers_only)
  # Header-only library configuration: header regeneration depends only on
  # public header files, as there are no implementation sources.
  update_version_header(
    ${header_buildinfo_lib} # Output header file
    ${public_headers} # Dependency: public interface headers
  )
else()
  # Static or shared library configuration: header regeneration depends on both
  # public headers and library implementation sources.
  update_version_header(
    ${header_buildinfo_lib}
    ${public_headers}
    ${library_sources} # Additional dependency: implementation files
  )

  # If an executable is also being built, configure its separate header
  # regeneration with executable-specific source dependencies.
  if(${project_name_copy}_build_executable)
    # Executable target
    update_version_header(
      ${header_buildinfo_bin} # Executable-specific header
      ${exe_sources} # Dependency: executable source files only
    )
  endif()
endif()
