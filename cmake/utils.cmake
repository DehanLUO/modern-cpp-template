# ------------------------------------------------------------------------------
# Function: verbose_message
# ------------------------------------------------------------------------------
# Conditionally outputs a status message to the CMake console when verbose
# logging mode is enabled for the project.
#
# Parameters:
#   content : String message to display (required)
#
# The message will be prefixed with CMake's STATUS indicator (typically "-- ").
function(verbose_message content)
  # Early Exit Condition: Verbose Mode Disabled
  if(NOT ${project_name_copy}_VERBOSE_OUTPUT)
    return() # Silent exit: no message generated
  endif()

  # Message Emission
  message(STATUS ${content})
endfunction()

# ------------------------------------------------------------------------------
# Function: verbose_list_message
# ------------------------------------------------------------------------------
# Conditionally displays the contents of a CMake list variable in a formatted,
# human-readable manner when verbose logging is enabled. This function is
# specifically designed to inspect list variables that contain file paths,
# target names, or other structured data during build configuration.
#
# IMPORTANT DESIGN CONSTRAINT:
#   The parameter `list_items` must be the LITERAL NAME of an existing CMake
#   list variable (e.g., "public_headers"), NOT its expanded value. This allows
#   the function to both display the variable name contextually and iterate over
#   its contents via variable indirection.
#
# Parameters:
#   list_items : String name of a CMake list variable (required)
function(verbose_list_message list_items)
  # Early Exit Condition: Verbose Mode Disabled
  if(NOT ${project_name_copy}_VERBOSE_OUTPUT)
    return() # Silent exit: no message generated
  endif()

  # List Header Announcement
  message(STATUS "Found the following ${list_items}:") #< literal name

  # Iterates over the contents of the variable whose name matches the
  # `list_items` parameter. The `IN LISTS ${list_items}` syntax uses variable
  # indirection: ${list_items} is evaluated to get the variable name, then that
  # variable's contents are expanded for iteration.
  foreach(item IN LISTS ${list_items})
    # Display each list element with uniform formatting
    message(STATUS "* ${item}")
  endforeach()
endfunction()
