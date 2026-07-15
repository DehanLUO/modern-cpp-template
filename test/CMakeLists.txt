# ==============================================================================
# CMake Module: Unit Test Configuration and Management
# ==============================================================================
# This module provides comprehensive unit test infrastructure for C++ projects,
# supporting multiple testing frameworks and integration with CMake's CTest
# system. The module creates individual test executables for each test source
# file, applies consistent build policies, and optionally enables code coverage
# instrumentation for quality assurance metrics.
#
# Supported Testing Frameworks:
#   - Google Test
#   - Catch2
# ==============================================================================
cmake_minimum_required(VERSION 3.15)

# This redefines `${PROJECT_NAME}` within this scope to `${PROJECT_NAME}Tests`.
project(${PROJECT_NAME}Tests LANGUAGES CXX)

# Log initiation of test configuration process for developer visibility.
verbose_message(
  "Configuring unit test infrastructure for project: ${project_name_copy}"
)

# Includes the code coverage configuration module, which defines macros and
# functions for instrumenting builds with profiling support (e.g., gcov/llvm-cov).
include(${cmake_codecov})

# Processes each test source file provided by the parent project's test_sources
# variable. This loop architecture supports scalable test suites where each test
# file becomes an independent executable.
foreach(file ${test_sources})
  # Extracts the base filename without directory path or extension to generate
  # a clean test identifier. The regular expression:
  #   (.*/)            - Captures directory path (discarded)
  #   ([a-zA-Z0-9_ ]+) - Captures filename (letters, numbers, underscores, spaces)
  #   (\.cpp)$         - Captures .cpp extension (discarded)
  # Example transformation: "/test/src/algorithm_test.cpp" → "algorithm_test"
  string(REGEX REPLACE "(.*/)([a-zA-Z0-9_ ]+)(\.cpp)$" "\\2" test_name ${file})

  # Creates a dedicated executable target for each test file.
  add_executable(${project_name_copy}_${test_name}_Tests ${file})

  # Enforces C++17 standard compliance for all test executables, ensuring
  # consistency with the main project's language requirements. The PUBLIC
  # visibility propagates this requirement to any dependent targets (though test
  # executables typically have no dependents).
  target_compile_features(
    ${project_name_copy}_${test_name}_Tests
    PUBLIC cxx_std_17
  )

  # Applies the project-wide compiler warning configuration (defined in
  # compiler_warnings.cmake) to the test executable. This ensures test code
  # maintains the same quality standards as production code.
  set_project_warnings("${project_name_copy}_${test_name}_Tests")

  # ----------------------------------------------------------------------------
  # Testing Framework Selection and Integration
  # ----------------------------------------------------------------------------
  # Configures the appropriate testing framework based on project configuration
  # variables. This conditional structure allows flexible framework selection
  # while maintaining consistent integration patterns.

  # Validate mutually exclusive framework selection
  if(${project_name_copy}_USE_GTEST AND ${project_name_copy}_USE_CATCH2)
    log_warn(
      "Both USE_GTEST and USE_CATCH2 are enabled. Defaulting to GoogleTest. "
      "Explicitly disable one to avoid ambiguity."
    )
  endif()

  if(${project_name_copy}_USE_GTEST)
    log_info("Configuring test '${test_name}' with GoogleTest framework")
    find_package(GTest REQUIRED)

    if(${project_name_copy}_USE_GOOGLE_MOCK)
      set(_google_mock_libraries GTest::gmock GTest::gmock_main)
      log_info("GoogleMock integration enabled for '${test_name}'")
    endif()

    target_link_libraries(
      ${project_name_copy}_${test_name}_Tests
      PUBLIC
        GTest::GTest
        ${_google_mock_libraries}
        ${project_name_copy}
    )
  elseif(${project_name_copy}_USE_CATCH2)
    log_info("Configuring test '${test_name}' with Catch2 framework")
    find_package(Catch2 REQUIRED)
    target_link_libraries(
      ${project_name_copy}_${test_name}_Tests
      PUBLIC
        Catch2::Catch2
        ${project_name_copy}
    )
  else()
    log_fatal(
      "No valid testing framework configured for project ${project_name_copy}. "
      "Please select a testing framework by setting either "
      "${project_name_copy}_USE_GTEST or ${project_name_copy}_USE_CATCH2 to ON."
    )
  endif()

  # ----------------------------------------------------------------------------
  # CTest Integration Registration
  # ----------------------------------------------------------------------------
  # Registers the test executable with CMake's CTest system, enabling test
  # execution via `ctest` command or IDE test runners. The NAME parameter
  # defines the test label in CTest reports, while COMMAND specifies the
  # executable to execute.
  add_test(
    NAME ${project_name_copy}_${test_name}
    COMMAND ${project_name_copy}_${test_name}_Tests
  )
  log_info("Registered CTest entry: ${project_name_copy}_${test_name}")

  configure_code_coverage_instrumentation()
endforeach()

set_coverage_target()

verbose_message(
  "Unit test configuration completed for project: ${project_name_copy}"
)
