# ==============================================================================
# CMake Module: Utility Functions
# ==============================================================================
# Provides helper utilities that wrap the hierarchical logging system defined
# in logging.cmake. This module should be included AFTER logging.cmake and
# setup.cmake so that log_* functions and project_name_copy are available.
# ==============================================================================

# ------------------------------------------------------------------------------
# Function: verbose_message
# ------------------------------------------------------------------------------
# Conditionally outputs a status message to the CMake console when verbose
# logging mode is enabled for the project.
# ------------------------------------------------------------------------------
function(verbose_message)
  if(NOT ${project_name_copy}_VERBOSE_OUTPUT)
    return()
  endif()
  log_debug("${ARGN}")
endfunction()

# ------------------------------------------------------------------------------
# Function: verbose_list_message
# ------------------------------------------------------------------------------
# Conditionally displays the contents of a CMake list variable in a formatted,
# human-readable manner when verbose logging is enabled.
#
# IMPORTANT DESIGN CONSTRAINT:
#   The parameter `list_items` must be the LITERAL NAME of an existing CMake
#   list variable (e.g., "public_headers"), NOT its expanded value.
# ------------------------------------------------------------------------------
function(verbose_list_message list_items)
  if(NOT ${project_name_copy}_VERBOSE_OUTPUT)
    return()
  endif()
  log_debug("Found the following ${list_items}:")
  foreach(item IN LISTS ${list_items})
    log_debug("  * ${item}")
  endforeach()
endfunction()
