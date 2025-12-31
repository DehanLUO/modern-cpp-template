# ------------------------------------------------------------------------------
# Macro: apply_coverage_compile_flags
# ------------------------------------------------------------------------------
# Applies compiler instrumentation flags required for source-level code coverage
# analysis using gcov-compatible toolchains (e.g., GCC or Clang). These flags
# disable optimizations and enable debug symbol generation to ensure accurate
# mapping between execution counts and source lines.
#
# The flags are applied PRIVATEly to avoid propagating coverage-specific
# compilation settings to downstream consumers, which is essential for
# maintaining clean public interfaces in library targets.
#
# Arguments:
#   target - The name of the CMake target to which coverage compile flags will
#            be applied. Must refer to a valid executable or library target.
macro(apply_coverage_compile_flags target)
  target_compile_options(
    ${target}
    PRIVATE
      -O0 # Disable optimizations for accurate line mapping
      -g # Include debug symbols for source correlation
      -fprofile-arcs # Generate arc profiling data for branch coverage
      -ftest-coverage # Emit coverage counters for each source line
  )
endmacro()

# ------------------------------------------------------------------------------
# Macro: apply_coverage_link_flags
# ------------------------------------------------------------------------------
# Applies linker flags necessary to resolve runtime dependencies introduced by
# coverage instrumentation (e.g., references to _llvm_gcda_* or __gcov_* symbols).
# These flags instruct the linker to include the appropriate profiling runtime
# library (e.g., libclang_rt.profile or libgcov).
#
# The visibility specifier (e.g., PRIVATE, PUBLIC, or INTERFACE) must be provided
# explicitly by the caller to control dependency propagation semantics. This
# design supports context-sensitive linkage strategies:
#   - PRIVATE: for executables or shared libraries that encapsulate the runtime
#   - PUBLIC: for static libraries in internal test builds where automatic
#             propagation to all consumers is desired and safe
#
# Arguments:
#   target     - The name of the CMake target to receive the link flags.
#   visibility - The visibility scope for the link options (typically PRIVATE or
#              PUBLIC).
macro(apply_coverage_link_flags target visibility)
  target_link_options(
    ${target}
    ${visibility}
    -fprofile-arcs
    -ftest-coverage # Link against gcov (or clang) coverage runtime
  )
endmacro()

# ------------------------------------------------------------------------------
# Function: configure_code_coverage_instrumentation
# ------------------------------------------------------------------------------
# Configures compiler and linker instrumentation for code coverage analysis
# using GCC or Clang's gcov-compatible profiling infrastructure. This function
# tailors the instrumentation strategy based on the library type (header-only,
# static, or shared) to ensure correct symbol resolution and runtime behaviour.
#
# For header-only (INTERFACE) libraries, coverage flags are applied exclusively
# to the test executable, as all implementation resides in headers and is
# instantiated during test compilation.
#
# For compiled libraries:
#   - Static libraries receive PUBLIC linker flags to propagate the coverage
#     runtime dependency to all consumers. This avoids requiring manual
#     instrumentation of every downstream executable in internal testing
#     contexts where coverage is explicitly enabled.
#   - Shared libraries receive PRIVATE linker flags, as they undergo final
#     linking and must resolve coverage symbols at library build time.
#
# The function is a no-op unless the project-specific option
# ${project_name_copy}_ENABLE_CODE_COVERAGE is set to ON, ensuring that
# coverage instrumentation remains opt-in and isolated to dedicated test builds.
#
# Preconditions:
#   - The variables `project_name_copy` and `test_name` must be defined in the
#     caller's scope.
#   - The macros `apply_coverage_compile_flags` and `apply_coverage_link_flags`
#     must be defined prior to invocation.
#
# Side effects:
#   - Modifies compile and link properties of `${project_name_copy}` and/or
#     `${test_name}_Tests` targets when coverage is enabled.
function(configure_code_coverage_instrumentation)
  if(NOT ${project_name_copy}_ENABLE_CODE_COVERAGE)
    return()
  endif()

  if(${project_name_copy}_build_headers_only)
    # For header-only (INTERFACE) libraries, implementation resides entirely in
    # headers. Instrumentation must be applied to the test executable, which
    # instantiates inline and template code during compilation.
    apply_coverage_compile_flags(${test_name}_Tests)
    apply_coverage_link_flags(${test_name}_Tests PRIVATE)
  else()
    # For compiled libraries (STATIC or SHARED), instrument the library itself.
    apply_coverage_compile_flags(${project_name_copy})

    # Link-time flags are handled differently based on library type:
    if(BUILD_SHARED_LIBS)
      # SHARED libraries undergo final linking and require the coverage runtime
      # at build time to resolve symbols like _llvm_gcda_*.
      apply_coverage_link_flags(${project_name_copy} PRIVATE)
    else()
      # STATIC libraries do not perform linking; they archive object files.
      # Therefore, coverage runtime linkage must be deferred to consumers.
      # In internal testing contexts with coverage enabled, propagating this
      # dependency via PUBLIC ensures all linking executables automatically
      # satisfy symbol requirements without manual configuration.
      apply_coverage_link_flags(${project_name_copy} PUBLIC)
    endif()
  endif()
endfunction()
