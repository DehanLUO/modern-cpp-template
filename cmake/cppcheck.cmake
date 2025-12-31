# Configure Cppcheck if enabled.
if(${PROJECT_NAME}_ENABLE_CPPCHECK)
  find_program(CPPCHECK cppcheck)
  if(CPPCHECK)
    # Enable comprehensive checks while suppressing non-critical issues:
    set(
      CMAKE_CXX_CPPCHECK
      ${CPPCHECK}
      --suppress=missingInclude #< Ignore missing system includes
      --enable=all #< Include inconclusive warnings,
      --inline-suppr #< Apply inline suppressions,
      --inconclusive
      -i
      ${CMAKE_SOURCE_DIR}/imgui/lib #< Exclude third-party directory
    )
    message("Cppcheck successfully configured.")
  else()
    message(
      SEND_ERROR
      "Cppcheck was requested but the executable could not be found."
    )
  endif()
endif()
