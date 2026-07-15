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
# ------------------------------------------------------------------------------
# Function: generate_commands_to_buildinfo_header
# ------------------------------------------------------------------------------
# Constructs the command line invocation for executing the external build
# information generation script. Returns the command list via an OUT parameter
# to avoid polluting the caller's scope with temporary variables.
#
# Parameters:
#   output_file : Path to the output header file
#   out_var     : Variable name to store the resulting command list
# ------------------------------------------------------------------------------
function(generate_commands_to_buildinfo_header output_file out_var)
  set(
    _cmd
    "${CMAKE_COMMAND}"
    "-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}"
    "-DCMAKE_CXX_COMPILER_ID=${CMAKE_CXX_COMPILER_ID}"
    "-DCMAKE_CXX_COMPILER_VERSION=${CMAKE_CXX_COMPILER_VERSION}"
    "-DCMAKE_HOST_SYSTEM=${CMAKE_HOST_SYSTEM}"
    "-DCMAKE_HOST_SYSTEM_NAME=${CMAKE_HOST_SYSTEM_NAME}"
    "-DCMAKE_SYSTEM_NAME=${CMAKE_SYSTEM_NAME}"
    "-DCMAKE_SYSTEM_PROCESSOR=${CMAKE_SYSTEM_PROCESSOR}"
    "-DNAME_LOWERCASE=${project_name_lowercase}"
    "-DNAME_UPPERCASE=${project_name_uppercase}"
    "-DOUTPUT=${output_file}"
    "-P ${cmake_buildinfo_script}"
  )
  set(${out_var} ${_cmd} PARENT_SCOPE)
endfunction()

# ------------------------------------------------------------------------------
# Function: generate_buildinfo_header
# ------------------------------------------------------------------------------
# Primary function for initial generation of build information headers.
# Implements a conditional execution pattern: the header is generated only if it
# does not already exist, preventing unnecessary rebuilds during initial
# configuration.
function(generate_buildinfo_header output)
  if(NOT EXISTS ${output})
    log_info("Generating initial build information header: ${output}")

    generate_commands_to_buildinfo_header("${output}" _commands)

    execute_process(
      COMMAND ${_commands}
      WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
      RESULT_VARIABLE _result
      OUTPUT_VARIABLE _output
      ERROR_VARIABLE _error
    )
    if(NOT _result EQUAL 0)
      log_warn("Build info header generation exited with code ${_result}")
      log_debug("stdout: ${_output}")
      log_debug("stderr: ${_error}")
    endif()
  else()
    log_debug("Build info header already exists, skipping generation: ${output}")
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
  generate_commands_to_buildinfo_header("${output}" _commands)

  add_custom_command(
    OUTPUT
      ${output}
    DEPENDS
      ${ARGN}
    COMMAND
      ${_commands}
    COMMENT
      "Regenerating build information header: ${output}"
  )
endfunction()

################################################################################
#                 Library Target Build Information Integration                 #
################################################################################

# ------------------------------------------------------------------------------
# Library Target Build Information Integration
# ------------------------------------------------------------------------------

# Step 1: Define custom target FIRST to establish build-graph node
generate_buildinfo_header(${header_buildinfo_lib})

add_custom_target(
  ${project_name_copy}_header_buildinfo_lib
  DEPENDS ${header_buildinfo_lib}
)
log_info("Registered custom target: ${project_name_copy}_header_buildinfo_lib")

# Step 2: Add target dependency AFTER custom target exists
add_dependencies(${project_name_copy} ${project_name_copy}_header_buildinfo_lib)
log_info("Added dependency: ${project_name_copy} → ${project_name_copy}_header_buildinfo_lib")

# Step 3: Integrate generated header into target sources
target_sources(
  ${PROJECT_NAME}
  PRIVATE
    FILE_SET
      buildinfo
      TYPE
        HEADERS
      BASE_DIRS
        ${dir_binary_src}
      FILES
        ${header_buildinfo_lib}
)
log_info("Integrated buildinfo header into library target sources")

# Only generate executable-specific build information if the project configures
# an executable target.
if(${PROJECT_NAME}_build_executable)
  generate_buildinfo_header(${header_buildinfo_bin})

  add_custom_target(
    ${project_name_copy}_header_buildinfo_bin
    DEPENDS ${header_buildinfo_bin}
  )
  log_info("Registered custom target: ${project_name_copy}_header_buildinfo_bin")

  add_dependencies(
    ${project_name_copy}_exe
    ${project_name_copy}_header_buildinfo_bin
  )
  log_info("Added dependency: ${project_name_copy}_exe → ${project_name_copy}_header_buildinfo_bin")

  target_sources(
    ${PROJECT_NAME}_exe
    PRIVATE
      FILE_SET buildinfo
        TYPE HEADERS
        BASE_DIRS ${dir_binary_src}
        FILES ${header_buildinfo_bin}
  )
  log_info("Integrated buildinfo header into executable target sources")
endif()

# Configures automatic regeneration of build information headers when source
# files change. The dependency structure varies based on project type.
if(${project_name_copy}_build_headers_only)
  update_version_header(
    ${header_buildinfo_lib}
    ${public_headers}
  )
  log_info("Buildinfo regeneration configured for header-only library")
else()
  update_version_header(
    ${header_buildinfo_lib}
    ${public_headers}
    ${library_sources}
  )
  log_info("Buildinfo regeneration configured for compiled library")

  if(${project_name_copy}_build_executable)
    update_version_header(
      ${header_buildinfo_bin}
      ${exe_sources}
    )
    log_info("Buildinfo regeneration configured for executable")
  endif()
endif()
