# This script is invoked via `cmake -P` from ./cmake/codecov.cmake.
# Its purpose is to locate all LLVM raw profiling files (.profraw) generated
# during test execution and merge them into a single indexed profile database
# (coverage.profdata) for use with llvm-cov.

# Discovers all .profraw files matching the pattern 'default-*.profraw' in the
# specified output directory. These files are produced by instrumented binaries
# when the LLVM_PROFILE_FILE environment variable is set (e.g., to default-%p).
file(GLOB profraw_files ${DIR}/default-*.profraw)

# If no .profraw files are found, issue a warning and exit gracefully.
# This may occur if tests were not run, failed to execute, or instrumentation
# was not properly enabled.
if(NOT profraw_files)
  message(WARNING "No profraw files found in ${DIR}")
  return()
endif()

# Invokes llvm-profdata to merge multiple raw profiling files into a single,
# indexed profile data file (coverage.profdata). The -sparse flag reduces disk
# usage by storing only non-zero counters, which is sufficient for reporting.
execute_process(
  COMMAND
    ${LLVM_PROFDATA} merge # Subcommand to combine multiple profiles.
    -sparse ${profraw_files} # Use sparse format; list all input .profraw files.
    -o ${DIR}/coverage.profdata # Output path for the merged profile database.
  RESULT_VARIABLE
    res # Captures the exit code of the process.
  ERROR_VARIABLE
    err # Captures stderr output for diagnostics.
  OUTPUT_VARIABLE
    out # Captures stdout (typically minimal here).
)

# Checks the result of the merge operation. A non-zero exit code indicates
# failure (e.g., corrupted input files, missing tool, or I/O error).
if(res)
  message(FATAL_ERROR "Failed to merge coverage: ${err}")
else()
  message(STATUS "Coverage merged successfully")
endif()
