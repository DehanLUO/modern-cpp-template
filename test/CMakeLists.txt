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
  add_executable(${test_name}_Tests ${file})

  # Enforces C++17 standard compliance for all test executables, ensuring
  # consistency with the main project's language requirements. The PUBLIC
  # visibility propagates this requirement to any dependent targets (though test
  # executables typically have no dependents).
  target_compile_features(${test_name}_Tests PUBLIC cxx_std_17)

  # Applies the project-wide compiler warning configuration (defined in
  # compiler_warnings.cmake) to the test executable. This ensures test code
  # maintains the same quality standards as production code.
  set_project_warnings("${test_name}_Tests")

  # Enables GCC-based code coverage instrumentation when requested by the parent
  # project configuration. Coverage data is collected from the main library code
  # exercised by tests, not from the test harness itself.
  #
  # IMPORTANT: Instrumentation flags are applied to the main library target
  # (${project_name_copy}), not the test executable, because coverage metrics
  # measure the code under test, not the testing code.
  if(${project_name_copy}_ENABLE_CODE_COVERAGE)
    # Apply compilation flags to the main library target:
    target_compile_options(
      ${project_name_copy}
      PUBLIC
        -O0 # Disable optimizations to preserve accurate line mapping
        -g # Include debugging symbols for source-level correlation
        -fprofile-arcs # Generate arc profiling information for branch coverage
        -ftest-coverage # Instrument code for test coverage measurement
    )

    # Apply linking flags to ensure coverage runtime linkage:
    target_link_options(
      ${project_name_copy}
      PUBLIC -fprofile-arcs -ftest-coverage
    )

    # Provide developer feedback about coverage configuration status.
    verbose_message(
      "Code coverage instrumentation enabled via GCC gcov for library: "
      "${project_name_copy}"
    )
  endif()

  # ----------------------------------------------------------------------------
  # Testing Framework Selection and Integration
  # ----------------------------------------------------------------------------
  # Configures the appropriate testing framework based on project configuration
  # variables. This conditional structure allows flexible framework selection
  # while maintaining consistent integration patterns.

  if(${project_name_copy}_USE_GTEST) # Google Test Framework Configuration
    # Locate and validate GoogleTest package installation.
    find_package(GTest REQUIRED)

    # Optional GoogleMock integration for mocking capabilities.
    if(${project_name_copy}_USE_GOOGLE_MOCK)
      set(_google_mock_libraries GTest::gmock GTest::gmock_main)
    endif()

    # Link test executable against required libraries:
    target_link_libraries(
      ${test_name}_Tests
      PUBLIC
        GTest::GTest # GoogleTest core framework
        ${_google_mock_libraries} # Optional GoogleMock libraries
        ${project_name_copy} # Main project library under test
    )
  elseif(${project_name_copy}_USE_CATCH2) # Catch2 Framework Configuration
    # TODO: This branch is documented as untested in the current implementation
    # but provides architectural support for alternative frameworks.
    find_package(Catch2 REQUIRED)
    target_link_libraries(
      ${test_name}_Tests
      PUBLIC
        Catch2::Catch2 # Catch2 testing framework
        ${project_name_copy} # Main project library under test
    )
  else()
    # Configuration validation: Ensure at least one testing framework is selected.
    message(
      FATAL_ERROR
      "No valid testing framework configured for project ${project_name_copy}. "
      "Please select a testing framework by setting either "
      "${project_name_copy}_USE_GTEST or ${project_name_copy}_USE_CATCH2 to ON."
      ""
    )
  endif()

  # ----------------------------------------------------------------------------
  # CTest Integration Registration
  # ----------------------------------------------------------------------------
  # Registers the test executable with CMake's CTest system, enabling test
  # execution via `ctest` command or IDE test runners. The NAME parameter
  # defines the test label in CTest reports, while COMMAND specifies the
  # executable to execute.
  add_test(NAME ${test_name} COMMAND ${test_name}_Tests)
endforeach()

# Configuration Completion Notification
verbose_message(
  "Unit test configuration completed for project: ${project_name_copy}()"
)
