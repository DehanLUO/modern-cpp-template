# ==============================================================================
# CMake Module: Clang-Tidy Configuration Block
# ==============================================================================
# This section configures the integration of the Clang-Tidy static analysis tool
# into the CMake build system. Clang-Tidy performs code quality checks and
# enforces coding standards on C++ source files during compilation.
#
# TODO: CMAKE_CXX_CLANG_TIDY init?
# TODO: set_property(TARGET ${PROJECT_NAME} PROPERTY CXX_CLANG_TIDY "")
# ==============================================================================

# Conditional check: If Clang-Tidy has already been explicitly disabled
# for this specific project via the ${PROJECT_NAME}_ENABLE_CLANG_TIDY variable,
# exit this configuration block immediately to avoid redundant setup.
if(NOT ${PROJECT_NAME}_ENABLE_CLANG_TIDY)
  # Early return statement prevents reconfiguration if already active
  return()
endif()

# Locate the Clang-Tidy executable within the system's PATH environment variable
# or in standard installation directories. The find_program command searches
# for an executable named 'clang-tidy' and stores the full path in the
# variable CLANGTIDY if found.
find_program(CLANGTIDY clang-tidy)

# Validation check: If the find_program command failed to locate the Clang-Tidy
# executable (resulting in CLANGTIDY being evaluated as NOT TRUE), issue a fatal
# error message and terminate configuration.
if(NOT CLANGTIDY)
  # The SEND_ERROR severity level halts configuration generation but allows
  # CMake to continue processing other parts of the script
  message(
    SEND_ERROR
    "Clang-Tidy was requested but the executable could not be found."
  )

  # Exit the configuration block since the required tool is unavailable
  return()
endif()

# Initialize a temporary CMake list variable that will accumulate regular
# expression patterns for directory filtering. The variable is explicitly set to
# an empty string to ensure clean state.
set(_tidy_regex_parts "")

# Iterate through each directory path provided in the specified list variables:
# dir_include (source header directories), dir_src (source file directories),
# dir_binary_include (generated header directories), and dir_binary_src
# (generated source directories). This ensures both original and build-generated
# files are included in analysis.
foreach(path IN LISTS dir_include dir_src dir_binary_include dir_binary_src)
  # Regular expression processing: Escape literal dot characters ('.') in
  # directory paths by replacing them with '\.'. This is necessary because
  # dots have special meaning in regular expressions (matching any character),
  # but we need to treat them as literal path separators.
  string(REGEX REPLACE "\\." "\\\\." _escaped_path "${path}")

  # Append a regular expression pattern that matches any file within the current
  # directory. The '/.*' suffix ensures all files and subdirectories under this
  # path are included in the filter.
  list(APPEND _tidy_regex_parts "${_escaped_path}/.*")
endforeach()

# Transform the list of regular expression patterns into a single string where
# each pattern is separated by the logical OR operator '|'. The string command
# with REPLACE semantics converts the CMake list separator ';' to the pipe
# character, creating a disjunction of patterns.
string(REPLACE ";" "|" _tidy_regex_joined "${_tidy_regex_parts}")

# Construct the final header filter regular expression by enclosing the joined
# patterns within parentheses to create a capture group. This expression will be
# passed to Clang-Tidy's --header-filter option, limiting analysis to headers
# matching any of the specified directory patterns.
set(_header_filter_regex "(${_tidy_regex_joined})")

# Configuration of the CMake C++ Clang-Tidy integration:
# The CMAKE_CXX_CLANG_TIDY variable is a special CMake property that, when set,
# automatically invokes Clang-Tidy during C++ source compilation. Each argument
# following the executable will be passed to Clang-Tidy.
set(
  CMAKE_CXX_CLANG_TIDY
  # The full path to the Clang-Tidy executable discovered earlier
  ${CLANGTIDY}
  # Compiler compatibility argument: Suppresses warnings about unrecognized
  # warning options that may be present in compilation commands but not
  # supported by Clang-Tidy's internal parser
  "-extra-arg=-Wno-unknown-warning-option"
  # Header filter argument restricts analysis to files matching the constructed
  # regular expression, improving performance and reducing noise
  "-header-filter=${_header_filter_regex}"
  # Quiet mode reduces verbose output, showing only diagnostics and errors
  "--quiet"
)

# Informational message confirming successful configuration completion.
# This appears during CMake configuration phase to provide user feedback.
message("Clang-Tidy finished setting up.")
