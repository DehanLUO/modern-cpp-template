#
# Print a message only if the `VERBOSE_OUTPUT` option is on
#

function(verbose_message content)
  if(${PROJECT_NAME}_VERBOSE_OUTPUT)
    message(STATUS ${content})
  endif()
endfunction()

# 定义宏：打印文件列表（支持任意名称的列表）
macro(print_verbose_list list_items)
  if(${PROJECT_NAME}_VERBOSE_OUTPUT)
    verbose_message("Found the following ${list_items}:")
    foreach(item IN LISTS ${list_items})
      verbose_message("* ${item}")
    endforeach()
  endif()
endmacro()

#
# Add a target for formating the project using `clang-format` (i.e: cmake
# --build build --target clang-format)
#

function(add_clang_format_target)
  # ! 如果没有定义变量，就在系统环境里找clang-forat存入
  if(NOT ${PROJECT_NAME}_CLANG_FORMAT_BINARY)
    find_program(${PROJECT_NAME}_CLANG_FORMAT_BINARY clang-format)
  endif()

  # !有clang-format，执行格式化
  if(${PROJECT_NAME}_CLANG_FORMAT_BINARY)
    if(${PROJECT_NAME}_BUILD_EXECUTABLE)
      add_custom_target(
        clang-format
        COMMAND ${${PROJECT_NAME}_CLANG_FORMAT_BINARY} -i ${exe_sources}
                ${headers} ${sources} ${headers}
        WORKING_DIRECTORY ${CMAKE_CURRENT_LIST_DIR}
      )
    elseif(${PROJECT_NAME}_BUILD_HEADERS_ONLY)
      add_custom_target(
        clang-format
        COMMAND ${${PROJECT_NAME}_CLANG_FORMAT_BINARY} -i ${headers}
        WORKING_DIRECTORY ${CMAKE_CURRENT_LIST_DIR}
      )
    else()
      add_custom_target(
        clang-format
        COMMAND ${${PROJECT_NAME}_CLANG_FORMAT_BINARY} -i ${sources} ${headers}
        WORKING_DIRECTORY ${CMAKE_CURRENT_LIST_DIR}
      )
    endif()

    message(
      STATUS
        "Format the project using the `clang-format` target (i.e: cmake --build build --target clang-format).\n"
    )
  endif()
endfunction()
