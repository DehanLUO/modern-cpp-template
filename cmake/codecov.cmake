# ------------------------------------------------------------------------------
# Macro: apply_coverage_compile_flags
# ------------------------------------------------------------------------------
# Applies compiler flags required to enable accurate source-level code coverage.
# These flags ensure debuggability and prevent optimization-induced distortion.
macro(apply_coverage_compile_flags target)
  log_debug("Applying coverage compile flags to target: ${target}")
  target_compile_options(
    ${target}
    PRIVATE
      -O0
      -g
      ${coverage_compile_options}
  )
endmacro()

# ------------------------------------------------------------------------------
# Macro: apply_coverage_link_flags
# ------------------------------------------------------------------------------
# Applies linker flags necessary to resolve runtime dependencies of the coverage
# instrumentation infrastructure. The visibility controls propagation semantics.
macro(apply_coverage_link_flags target visibility)
  log_debug(
    "Applying coverage link flags to target: ${target} (visibility: ${visibility})"
  )
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
    return()
  endif()

  if(${project_name_copy}_build_headers_only)
    log_debug("Applying coverage instrumentation to test target (header-only library)")
    apply_coverage_compile_flags(${project_name_copy}_${test_name}_Tests)
    apply_coverage_link_flags(${project_name_copy}_${test_name}_Tests PRIVATE)
  else()
    log_debug("Applying coverage instrumentation to library target")
    apply_coverage_compile_flags(${project_name_copy})

    if(BUILD_SHARED_LIBS)
      log_debug("Library is SHARED — coverage link flags applied as PRIVATE")
      apply_coverage_link_flags(${project_name_copy} PRIVATE)
    else()
      log_debug("Library is STATIC — coverage link flags applied as PUBLIC")
      apply_coverage_link_flags(${project_name_copy} PUBLIC)
    endif()
  endif()

  # Configures the LLVM_PROFILE_FILE environment variable for Clang-based builds.
  # This directs profiling output to ${dir_codecov}/default-%p.profraw, where %p
  # is replaced by the process ID. This naming scheme prevents file collisions
  # during parallel or multi-process test execution.
  set_tests_properties(
    ${project_name_copy}_${test_name}
    PROPERTIES ENVIRONMENT "LLVM_PROFILE_FILE=${dir_codecov}/default-%p.profraw"
  )

  # Appends the absolute path of the test executable to the list of binaries
  # that will later be analysed by llvm-cov. The path is represented as a
  # generator expression so that it is resolved at build time rather than at
  # configuration time.
  list(
    APPEND clang_coverage_executables
    $<TARGET_FILE:${project_name_copy}_${test_name}_Tests>
  )

  # Propagates the updated list of coverage executables to the parent scope.
  # This is required because list() operations are confined to the current
  # function scope by default.
  set(clang_coverage_executables "${clang_coverage_executables}" PARENT_SCOPE)
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
    set_clang_coverage_target()
  elseif(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
    set_gcc_coverage_target()
  else()
    log_warn("No coverage configured for '${CMAKE_CXX_COMPILER_ID}' compiler.")
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
    log_warn("llvm-profdata not found; skipping Clang coverage target.")
    return()
  endif()

  find_program(LLVM_COV llvm-cov)
  if(NOT LLVM_COV)
    log_warn("llvm-cov not found; skipping Clang coverage target.")
    return()
  endif()
  log_info("LLVM coverage tools found: llvm-profdata, llvm-cov")

  add_custom_target(
    ${project_name_copy}_coverage
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
    # Invokes llvm-cov to generate a human-readable coverage summary. The
    # command consumes the list of instrumented executables and correlates them
    # with the merged profiling data produced by llvm-profdata.
    COMMAND
      ${LLVM_COV} report ${clang_coverage_executables}
      #-ignore-filename-regex=
      -instr-profile=${dir_codecov}/coverage.profdata
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    COMMENT "Running all tests and generating LLVM coverage report"
    VERBATIM # Prevents CMake from adding shell quoting.
  )

  log_info("Added LLVM-based coverage target: ${project_name_copy}_coverage")
endfunction()

# ------------------------------------------------------------------------------
# Function: set_gcc_coverage_target
# ------------------------------------------------------------------------------
# Constructs a 'coverage' target for GCC using gcov. Relies on .gcno/.gcda files
# generated during test execution.
function(set_gcc_coverage_target)
  find_program(GCOV gcov)
  if(NOT GCOV)
    log_warn("gcov not found; skipping GCC coverage target.")
    return()
  endif()

  find_program(FIND find)
  if(NOT FIND)
    log_warn("find utility not found; skipping GCC coverage target.")
    return()
  endif()

  find_program(BASH bash)
  if(NOT BASH)
    log_warn("bash not found; skipping GCC coverage target.")
    return()
  endif()
  log_info("GCC coverage tools found: gcov, find, bash")

  add_custom_target(
    ${project_name_copy}_coverage
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

  log_info("Added GCC-based coverage target: ${project_name_copy}_coverage")
endfunction()

# ------------------------------------------------------------------------------
# Compiler-Specific Coverage Flag Configuration
# ------------------------------------------------------------------------------
# Sets instrumentation flags based on the detected C++ compiler. This block must
# execute before any call to configure_code_coverage_instrumentation.
if(NOT ${project_name_copy}_ENABLE_CODE_COVERAGE)
  log_debug("Code coverage instrumentation disabled")
  return()
endif()
log_info("Code coverage instrumentation enabled")

# Initialises the list of coverage executables to an empty value before any test
# targets append their corresponding executable paths.
set(clang_coverage_executables "")

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
  set(coverage_compile_options ${_clang_compile_options})
  set(coverage_link_options ${_clang_link_options})
  log_info("Coverage flags configured for Clang")
elseif(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
  set(coverage_compile_options ${_gcc_compile_options})
  set(coverage_link_options ${_gcc_link_options})
  log_info("Coverage flags configured for GCC")
else()
  log_warn("No coverage configured for '${CMAKE_CXX_COMPILER_ID}' compiler.")
endif()

# Clean up temporary variables to avoid polluting global scope.
unset(_clang_compile_options)
unset(_clang_link_options)
unset(_gcc_compile_options)
unset(_gcc_link_options)
