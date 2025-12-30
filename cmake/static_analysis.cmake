# Configure Clang-Tidy if enabled.
if(${PROJECT_NAME}_ENABLE_CLANG_TIDY)
  find_program(CLANGTIDY clang-tidy)
  if(CLANGTIDY)
    # Suppress warnings about unknown warning options to avoid noise from compiler mismatches.
    set(
      CMAKE_CXX_CLANG_TIDY
      ${CLANGTIDY}
      -extra-arg=-Wno-unknown-warning-option
    )
    message("Clang-Tidy finished setting up.")
  else()
    message(
      SEND_ERROR
      "Clang-Tidy was requested but the executable could not be found."
    )
  endif()
endif()

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
