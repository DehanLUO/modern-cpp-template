# ------------------------------------------------------------------------------
# Macro: apply_coverage_compile_flags
# ------------------------------------------------------------------------------
# Applies compiler flags required to enable accurate source-level code coverage.
# These flags ensure debuggability and prevent optimization-induced distortion.
macro(apply_coverage_compile_flags target)
  target_compile_options(
    ${target}
    PRIVATE
      # Disables all compiler optimizations. This preservesa direct mapping
      # between source lines and emitted instructions, which is essential for
      # precise line coverage attribution.
      -O0
      # Embeds debugging symbols (e.g., DWARF) into object files, enabling
      # coverage tools to correlate runtime execution counts with specific
      # source locations.
      -g
      # Appends compiler-specific instrumentation flags (e.g., -fprofile-arcs
      # for GCC or -fprofile-instr- generate for Clang) that activate profiling
      # data emission during compilation.
      ${coverage_compile_options}
  )
endmacro()

# ------------------------------------------------------------------------------
# Macro: apply_coverage_link_flags
# ------------------------------------------------------------------------------
# Applies linker flags necessary to resolve runtime dependencies of the coverage
# instrumentation infrastructure. The visibility controls propagation semantics.
macro(apply_coverage_link_flags target visibility)
  # Links against the coverage runtime library (e.g., libgcov for GCC). The
  # chosen visibility determines whether dependent targets inherit this linkage:
  #   - PRIVATE: dependency is internal (suitable for shared libraries).
  #   - PUBLIC:  dependency is exported (required for static libraries, as they
  #              do not undergo final linking and cannot resolve symbols alone).
  target_link_options(${target} ${visibility} ${coverage_link_options})
endmacro()

# ------------------------------------------------------------------------------
# Function: configure_code_coverage_instrumentation
# ------------------------------------------------------------------------------
# Configures code coverage instrumentation tailored to the library type (header-
# only, static, or shared) using either GCC’s gcov or Clang’s llvm-cov backend.
# Ensures correct symbol resolution and minimizes manual configuration overhead.
function(configure_code_coverage_instrumentation)
  if(NOT ${project_name_copy}_ENABLE_CODE_COVERAGE)
    return() # Early exit if coverage is globally disabled.
  endif()

  if(${project_name_copy}_build_headers_only)
    # Header-only libraries contain no compiled object files; all implementation
    # resides in headers and is instantiated within the test executable’s
    # translation unit. Thus, instrumentation must be applied to the test target.
    apply_coverage_compile_flags(${test_name}_Tests)
    apply_coverage_link_flags(${test_name}_Tests PRIVATE)
  else()
    # Compiled libraries (STATIC/SHARED) contain actual object code and must be
    # instrumented directly at the library level.
    apply_coverage_compile_flags(${project_name_copy})

    # Linker flag visibility depends on library linkage model:
    if(BUILD_SHARED_LIBS)
      # Shared libraries are fully linked at build time and must resolve
      # coverage runtime symbols (e.g., __llvm_gcda_emit_function) internally.
      apply_coverage_link_flags(${project_name_copy} PRIVATE)
    else()
      # Static libraries are archives of unlinked objects. Final symbol
      # resolution occurs only when linked into an executable. Propagating the
      # coverage runtime dependency via PUBLIC ensures all consumers (e.g., test
      # runners) automatically satisfy symbol requirements without explicit
      # configuration.
      apply_coverage_link_flags(${project_name_copy} PUBLIC)
    endif()
  endif()

  # Configures the LLVM_PROFILE_FILE environment variable for Clang-based builds.
  # This directs profiling output to ${dir_codecov}/default-%p.profraw, where %p
  # is replaced by the process ID. This naming scheme prevents file collisions
  # during parallel or multi-process test execution.
  set_tests_properties(
    ${test_name}
    PROPERTIES ENVIRONMENT "LLVM_PROFILE_FILE=${dir_codecov}/default-%p.profraw"
  )
endfunction()

# ------------------------------------------------------------------------------
# Function: set_coverage_target
# ------------------------------------------------------------------------------
# Defines a top-level 'coverage' custom target that orchestrates test execution,
# data collection, merging, and reporting—adapted to the detected compiler.
function(set_coverage_target)
  if(NOT ${project_name_copy}_ENABLE_CODE_COVERAGE)
    return() # No-op if coverage is disabled.
  endif()

  if(CMAKE_CXX_COMPILER_ID MATCHES ".*Clang")
    # Matches both "Clang" and "AppleClang". Delegates to Clang-specific workflow.
    set_clang_coverage_target()
  elseif(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
    # GNU GCC detected. Delegates to GCC/gcov workflow.
    set_gcc_coverage_target()
  else()
    # Unsupported compiler. Emit a non-fatal warning to inform developers.
    message(
      AUTHOR_WARNING
      "No coverage configured for '${CMAKE_CXX_COMPILER_ID}' compiler."
    )
  endif()
endfunction()

# ------------------------------------------------------------------------------
# Function: set_clang_coverage_target
# ------------------------------------------------------------------------------
# Constructs a 'coverage' target for Clang-based toolchains using llvm-profdata
# and llvm-cov. Assumes instrumentation was enabled via -fprofile-instr-generate.
function(set_clang_coverage_target)
  find_program(LLVM_PROFDATA llvm-profdata)
  if(NOT LLVM_PROFDATA)
    message(WARNING "llvm-profdata not found; skipping Clang coverage target.")
    return()
  endif()

  find_program(LLVM_COV llvm-cov)
  if(NOT LLVM_COV)
    message(WARNING "llvm-cov not found; skipping Clang coverage target.")
    return()
  endif()

  add_custom_target(
    coverage
    # Ensures a clean output directory by recursively removing existing content.
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${dir_codecov}
    # Executes all registered tests in verbose mode to generate .profraw files.
    COMMAND ${CMAKE_CTEST_COMMAND} -C $<CONFIG> -VV
    # Invokes an external CMake script to merge multiple .profraw files into a
    # single indexed profile database (coverage.profdata) using llvm-profdata.
    COMMAND
      ${CMAKE_COMMAND} #
      "-DDIR=${dir_codecov}" #
      "-DLLVM_PROFDATA=${LLVM_PROFDATA}" #
      "-P ${cmake_profraw_script}"
    # Generates a human-readable summary report using the merged profile data.
    COMMAND
      ${LLVM_COV} report $<TARGET_FILE:tmp_test_Tests>
      -instr-profile=${dir_codecov}/coverage.profdata
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    COMMENT "Running all tests and generating LLVM coverage report"
    VERBATIM # Prevents CMake from adding shell quoting.
  )

  message(STATUS "Added LLVM-based coverage target")
endfunction()

# ------------------------------------------------------------------------------
# Function: set_gcc_coverage_target
# ------------------------------------------------------------------------------
# Constructs a 'coverage' target for GCC using gcov. Relies on .gcno/.gcda files
# generated during test execution.
function(set_gcc_coverage_target)
  find_program(GCOV gcov)
  if(NOT GCOV)
    message(WARNING "gcov not found; skipping GCC coverage target.")
    return()
  endif()

  find_program(FIND find)
  if(NOT FIND)
    message(WARNING "find utility not found; skipping GCC coverage target.")
    return()
  endif()

  find_program(BASH bash)
  if(NOT BASH)
    message(WARNING "bash not found; skipping GCC coverage target.")
    return()
  endif()

  add_custom_target(
    coverage
    # Removes any pre-existing coverage output directory.
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${dir_codecov}
    # Recreates the directory to hold generated .gcov files.
    COMMAND ${CMAKE_COMMAND} -E make_directory ${dir_codecov}
    # Runs all tests to produce .gcda runtime coverage data alongside .gcno.
    COMMAND ${CMAKE_CTEST_COMMAND} -C $<CONFIG> -VV
    # Changes into the output directory and invokes gcov on all .gcno files.
    # The -p flag preserves full paths (using # as separator); -b enables branch
    # coverage. The || true suppresses failure if no .gcno files exist.
    COMMAND
      ${BASH} -c
      "cd ${dir_codecov} && \
      ${FIND} ${CMAKE_BINARY_DIR} -type f -name '*.gcno' -exec ${GCOV} -pb {} +"
      || true
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    COMMENT "Running all tests and generating GCC coverage report"
    VERBATIM
  )

  message(STATUS "Added GCC-based coverage target")
endfunction()

# ------------------------------------------------------------------------------
# Compiler-Specific Coverage Flag Configuration
# ------------------------------------------------------------------------------
# Sets instrumentation flags based on the detected C++ compiler. This block must
# execute before any call to configure_code_coverage_instrumentation.
if(NOT ${project_name_copy}_ENABLE_CODE_COVERAGE)
  return() # Exit early if coverage is disabled.
endif()

# Clang requires two flags: one for compile-time instrumentation generation and
# another for coverage mapping metadata.
set(_clang_compile_options -fprofile-instr-generate -fcoverage-mapping)
set(_clang_link_options -fprofile-instr-generate)

# GCC uses distinct flags for arc profiling and coverage counter emission.
set(
  _gcc_compile_options
  -fprofile-arcs # Enables arc (edge) profiling for branch coverage.
  -ftest-coverage # Emits line execution counters and generates .gcno.
  #--coverage
)
# Linking with -fprofile-arcs and -ftest-coverage pulls in libgcov implicitly.
set(
  _gcc_link_options
  -fprofile-arcs
  -ftest-coverage
  #--coverage
)

if(CMAKE_CXX_COMPILER_ID MATCHES ".*Clang")
  # Clang or AppleClang compiler detected (MATCHES handles both "Clang" and
  # "AppleClang")
  set(coverage_compile_options ${_clang_compile_options})
  set(coverage_link_options ${_clang_link_options})
elseif(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
  # GNU GCC compiler detected
  set(coverage_compile_options ${_gcc_compile_options})
  set(coverage_link_options ${_gcc_link_options})
else()
  # Unsupported compiler detected - issue developer warning but continue
  # configuration
  message(
    AUTHOR_WARNING
    "No coverage configured for '${CMAKE_CXX_COMPILER_ID}' compiler."
  )
endif()

# Clean up temporary variables to avoid polluting global scope.
unset(_clang_compile_options)
unset(_clang_link_options)
unset(_gcc_compile_options)
unset(_gcc_link_options)
