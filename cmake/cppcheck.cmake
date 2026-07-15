# Configure Cppcheck if enabled.
if(${PROJECT_NAME}_ENABLE_CPPCHECK)
  find_program(CPPCHECK cppcheck)
  if(CPPCHECK)
    set(
      CMAKE_CXX_CPPCHECK
      ${CPPCHECK}
      --suppress=missingInclude
      --enable=all
      --inline-suppr
      --inconclusive
      -i
      ${CMAKE_SOURCE_DIR}/imgui/lib
    )
    log_info("Cppcheck successfully configured: ${CPPCHECK}")
  else()
    log_err("Cppcheck was requested but the executable could not be found.")
  endif()
endif()
