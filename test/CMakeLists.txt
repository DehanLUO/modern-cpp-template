cmake_minimum_required(VERSION 3.15)

#
# Project details
#

# !这将在该作用域里改变${PROJECT_NAME}的值
project(${PROJECT_NAME}Tests LANGUAGES CXX)

# NOREFLOW
# !创建${PROJECT_NAME}_VERBOSE_OUTPUT变量让verbose_message能正常工作
# !否则verbose_message将恒不输出任何信息
set(${PROJECT_NAME}_VERBOSE_OUTPUT
    "${USER_PROJECT_NAME}_VERBOSE_OUTPUT"
)

verbose_message("Adding tests under ${USER_PROJECT_NAME}...")

# !启用编译告警
include(../cmake/CompilerWarnings.cmake)

foreach(file ${test_sources})
  string(REGEX REPLACE "(.*/)([a-zA-Z0-9_ ]+)(\.cpp)" "\\2" test_name ${file})
  add_executable(${test_name}_Tests ${file})

  #
  # Set the compiler standard
  #

  target_compile_features(${test_name}_Tests PUBLIC cxx_std_17)

  # ! 设置编译器告警
  set_project_warnings("${test_name}_Tests")

  #
  # Setup code coverage if enabled
  #

  # TODO 弄清楚这里是做什么的？为什么要作用到父项目而非当前项目上
  if(${USER_PROJECT_NAME}_ENABLE_CODE_COVERAGE)
    target_compile_options(
      ${USER_PROJECT_NAME} PUBLIC -O0 -g -fprofile-arcs -ftest-coverage
    )
    target_link_options(
      ${USER_PROJECT_NAME} PUBLIC -fprofile-arcs -ftest-coverage
    )
    verbose_message("Code coverage is enabled and provided with GCC.")
  endif()

  #
  # Load the desired unit testing framework
  #
  # Currently supported: GoogleTest (and GoogleMock), Catch2.
  if(${USER_PROJECT_NAME}_USE_GTEST)
    find_package(GTest REQUIRED)

    if(${USER_PROJECT_NAME}_USE_GOOGLE_MOCK)
      set(GOOGLE_MOCK_LIBRARIES GTest::gmock GTest::gmock_main)
    endif()

    target_link_libraries(
      ${test_name}_Tests PUBLIC ${USER_PROJECT_NAME} GTest::GTest
                                ${GOOGLE_MOCK_LIBRARIES}
    )
  elseif(${USER_PROJECT_NAME}_USE_CATCH2)
    # ! 没测过，暂时也不想用
    find_package(Catch2 REQUIRED)
    target_link_libraries(
      ${test_name}_Tests PUBLIC Catch2::Catch2 ${USER_PROJECT_NAME}
    )
  else()
    message(
      FATAL_ERROR
        "Unknown testing library. Please setup your desired unit testing library by using `target_link_libraries`."
    )
  endif()

  #
  # Add the unit tests
  #

  add_test(NAME ${test_name} COMMAND ${test_name}_Tests)
endforeach()

verbose_message("Finished adding unit tests for ${USER_PROJECT_NAME}.")
