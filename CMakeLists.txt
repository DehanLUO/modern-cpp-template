cmake_minimum_required(VERSION 3.15)

# NOREFLOW
# TODO 1. 检查 执行程序 和 interface只能二选一
# TODO 2. unix系统采用symbolic的形式安装
# TODO 3. cmake配置文件带版本号
# TODO 4. unix上的库带版本尾号
# TODO 5. unix上的安装采用symbolic替代实体复制？

#
# Project details #! 项目名称
#
project(
  "Project" #< 项目名称
  VERSION 0.1.0 #< 版本号
  LANGUAGES CXX #< 项目语言
)

# ! 缓存一份。该项目唯一
set(USER_PROJECT_NAME
    "${PROJECT_NAME}"
)

#
# Set project options
#
include(cmake/StandardSettings.cmake) # !环境变量设置（开关）
include(cmake/StaticAnalyzers.cmake) # !静态分析工具（Clang-Tidy / Cppcheck)
include(cmake/Utils.cmake) # !工具函数（如 verbose_message）

if(NOT CMAKE_BUILD_TYPE) # !如果用户未指定 -DCMAKE_BUILD_TYPE=...
  set(CMAKE_BUILD_TYPE "Debug") # !默认设置为Debug
endif()

message(STATUS "Started CMake for ${PROJECT_NAME} v${PROJECT_VERSION}...\n")

# NOREFLOW
# !在 Linux/macOS 的 Debug 构建中定义 _DEBUG（Windows MSVC 默认有）。
# !这样你可以在代码中统一用#ifdef _DEBUG 写调试逻辑。
if(UNIX)
  add_compile_options(
    "$<$<CONFIG:DEBUG>:-D_DEBUG>"
  ) # this will allow to use same _DEBUG macro available in both Linux as well
    # as Windows - MSCV environment. Easy to put Debug specific code.
endif(UNIX)

#
# Setup alternative names
#
if(${PROJECT_NAME}_USE_ALT_NAMES)
  # NOREFLOW
  # !开启${PROJECT_NAME}_USE_ALT_NAMES
  # !PROJECT_NAME_LOWERCASE存项目名称的全小写
  # !PROJECT_NAME_UPPERCASE存项目名称的全大写
  string(TOLOWER ${PROJECT_NAME} PROJECT_NAME_LOWERCASE)
  string(TOUPPER ${PROJECT_NAME} PROJECT_NAME_UPPERCASE)
else()
  # NOREFLOW
  # !关闭{PROJECT_NAME}_USE_ALT_NAMES
  # !PROJECT_NAME_LOWERCASE 和 PROJECT_NAME_UPPERCASE都是原始的项目名称大小写
  set(PROJECT_NAME_LOWERCASE ${PROJECT_NAME})
  set(PROJECT_NAME_UPPERCASE ${PROJECT_NAME})
endif()

#
# Prevent building in the source directory
#
# !禁止源码内构建（in-source build）
if(PROJECT_SOURCE_DIR STREQUAL PROJECT_BINARY_DIR)
  message(
    FATAL_ERROR
      "In-source builds not allowed. Please make a new directory (called a build directory) and run CMake from there."
  )
endif()

#
# Enable package managers
#
include(cmake/Conan.cmake)
include(cmake/Vcpkg.cmake)

#
# Add version header
#
configure_file(
  ${CMAKE_CURRENT_LIST_DIR}/cmake/version.hpp.in include/version.hpp @ONLY
)

#
# Create library, setup header and source files
#

# Find all headers and implementation files
include(cmake/SourcesAndHeaders.cmake) # !搜集源文件 & 创建目标（核心逻辑分支）

if(${PROJECT_NAME}_BUILD_HEADERS_ONLY)
  # !头文件INTERFACE库（无编译产物）
  add_library(${PROJECT_NAME} INTERFACE)

  print_verbose_list(headers) # !打印文件列表
else()
  # !普通库（目标名称：${PROJECT_NAME}）供链接（含测试）使用
  add_library(${PROJECT_NAME} ${headers} ${sources})

  print_verbose_list(headers) # !打印头文件列表。
  print_verbose_list(sources) # !打印库文件列表

  if(${PROJECT_NAME}_BUILD_EXECUTABLE)
    # !可执行程序
    add_executable(${PROJECT_NAME}_EXE ${exe_sources})

    print_verbose_list(exe_sources) # !打印执行文件列表
  endif()
endif()

# !设置目标文件（普通库、头文件库）的输出路径
set_target_properties(
  ${PROJECT_NAME}
  PROPERTIES ARCHIVE_OUTPUT_DIRECTORY
             "${CMAKE_BINARY_DIR}/lib/${CMAKE_BUILD_TYPE}"
             LIBRARY_OUTPUT_DIRECTORY
             "${CMAKE_BINARY_DIR}/lib/${CMAKE_BUILD_TYPE}"
             PUBLIC_HEADER "${headers}"
)

# !设置执行文件（目标名称：${PROJECT_NAME}_EXE）的输出路径
if(${PROJECT_NAME}_BUILD_EXECUTABLE)
  set_target_properties(
    ${PROJECT_NAME}_EXE
    PROPERTIES RUNTIME_OUTPUT_DIRECTORY
               "${CMAKE_BINARY_DIR}/bin/${CMAKE_BUILD_TYPE}"
               OUTPUT_NAME ${PROJECT_NAME} # ! 将其重命名回 ${PROJECT_NAME}
  )
endif()

message(STATUS "Added all header and implementation files.\n")

#
# Set the project standard and warnings
#
if(${PROJECT_NAME}_BUILD_HEADERS_ONLY)
  target_compile_features(${PROJECT_NAME} INTERFACE cxx_std_17)
else()
  target_compile_features(${PROJECT_NAME} PUBLIC cxx_std_17)

  if(${PROJECT_NAME}_BUILD_EXECUTABLE)
    target_compile_features(${PROJECT_NAME}_EXE PUBLIC cxx_std_17)
  endif()
endif()

# ! 设置编译器告警
include(cmake/CompilerWarnings.cmake)
set_project_warnings(${PROJECT_NAME})

verbose_message(
  "Applied compiler warnings. Using standard ${CMAKE_CXX_STANDARD}.\n"
)

#
# Enable Doxygen
#
include(cmake/Doxygen.cmake)

# NOREFLOW
#
# Model project dependencies
#
# Identify and link with the specific "packages" the project uses
#find_package(package_name package_version REQUIRED package_type [other_options])
#target_link_libraries(
#  ${PROJECT_NAME}
#  PUBLIC
#    dependency1 ...
#  PRIVATE
#    dependency2 ...
#    ${PROJECT_NAME}_PROJECT_OPTIONS
#    ${PROJECT_NAME}_PROJECT_WARNINGS
#)
#if(${PROJECT_NAME}_BUILD_EXECUTABLE AND ${PROJECT_NAME}_ENABLE_UNIT_TESTING)
#  target_link_libraries(
#    ${PROJECT_NAME}_LIB
#    PUBLIC
#      dependency1 ...
#  )
#endif()
if(${PROJECT_NAME}_BUILD_EXECUTABLE)
  target_link_libraries(${PROJECT_NAME}_EXE PRIVATE ${PROJECT_NAME})
endif()

# For Windows, it is necessary to link with the MultiThreaded library. Depending
# on how the rest of the project's dependencies are linked, it might be
# necessary to change the line to statically link with the library.
#
# This is done as follows:
#
# set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
#
# On Linux and Mac this variable is ignored. If any issues rise from it, try
# commenting it out and letting CMake decide how to link with it.
set(CMAKE_MSVC_RUNTIME_LIBRARY
    "MultiThreaded$<$<CONFIG:Debug>:Debug>DLL"
)

verbose_message("Successfully added all dependencies and linked against them.")

#
# Set the build/user include directories
#

# Allow usage of header files in the `src` directory, but only for utilities
if(${PROJECT_NAME}_BUILD_HEADERS_ONLY)
  # !头文件INTERFACE库（无编译产物）
  target_include_directories(
    ${PROJECT_NAME}
    INTERFACE $<INSTALL_INTERFACE:include>
              $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
              $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/include>
  )
else()
  # ! 普通库（默认） 或 可执行程序
  target_include_directories(
    ${PROJECT_NAME}
    PUBLIC $<INSTALL_INTERFACE:include>
           $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
           $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/include>
    PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src
  )

  if(${PROJECT_NAME}_BUILD_EXECUTABLE)
    # ! 执行文件
    target_include_directories(
      ${PROJECT_NAME}_EXE PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src
    )
  endif()
endif()

message(STATUS "Finished setting up include directories.")

#
# Provide alias to library for
#

#[[
if(${PROJECT_NAME}_BUILD_EXECUTABLE)
  # add_executable(${PROJECT_NAME}::${PROJECT_NAME} ALIAS ${PROJECT_NAME})
  add_library(${PROJECT_NAME}::${PROJECT_NAME} ALIAS ${PROJECT_NAME}_LIB)
else()
  add_library(${PROJECT_NAME}::${PROJECT_NAME} ALIAS ${PROJECT_NAME})
endif()

verbose_message("Project is now aliased as ${PROJECT_NAME}::${PROJECT_NAME}.\n")
]]
# ! 这段逻辑就完全多余了？ 也没地方用别名

#
# Format the project using the `clang-format` target (i.e: cmake --build build
# --target clang-format)
#
add_clang_format_target() # !格式化

#
# Install library for easy downstream inclusion
#
include(GNUInstallDirs)
install(
  TARGETS ${PROJECT_NAME}
  EXPORT ${PROJECT_NAME}Targets
  LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
  RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
  ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
  PUBLIC_HEADER DESTINATION include/${PROJECT_NAME_LOWERCASE}
)

if(${PROJECT_NAME}_BUILD_EXECUTABLE)
  install(TARGETS ${PROJECT_NAME}_EXE
          RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
  )
endif()

install(
  EXPORT ${PROJECT_NAME}Targets
  FILE ${PROJECT_NAME}Targets.cmake
  NAMESPACE ${PROJECT_NAME}::
  DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/${PROJECT_NAME}
)

verbose_message(
  "Install targets successfully built. Install with `cmake --build <build_directory> --target install --config <build_config>`."
)

#
# Quick `ConfigVersion.cmake` creation
#
include(CMakePackageConfigHelpers)
write_basic_package_version_file(
  ${PROJECT_NAME}ConfigVersion.cmake
  VERSION ${PROJECT_VERSION}
  COMPATIBILITY SameMajorVersion
)

configure_package_config_file(
  ${CMAKE_CURRENT_LIST_DIR}/cmake/${PROJECT_NAME}Config.cmake.in
  ${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}Config.cmake
  INSTALL_DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/${PROJECT_NAME}
)

install(FILES ${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}Config.cmake
              ${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}ConfigVersion.cmake
        DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/${PROJECT_NAME}
)

#
# Generate export header if specified
#
if(${PROJECT_NAME}_GENERATE_EXPORT_HEADER)
  include(GenerateExportHeader)
  generate_export_header(${PROJECT_NAME})
  install(FILES ${PROJECT_BINARY_DIR}/${PROJECT_NAME_LOWERCASE}_export.h
          DESTINATION include
  )

  message(
    STATUS
      "Generated the export header `${PROJECT_NAME_LOWERCASE}_export.h` and installed it."
  )
endif()

message(STATUS "Finished building requirements for installing the package.\n")

#
# Unit testing setup
#
if(${PROJECT_NAME}_ENABLE_UNIT_TESTING)
  enable_testing()
  message(
    STATUS
      "Build unit tests for the project. Tests should always be found in the test folder\n"
  )
  add_subdirectory(test)
endif()
