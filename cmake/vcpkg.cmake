if(${PROJECT_NAME}_ENABLE_VCPKG)
  #
  # If `vcpkg.cmake` (from https://github.com/microsoft/vcpkg) does not exist, download it.
  #
  if(NOT EXISTS "${CMAKE_BINARY_DIR}/vcpkg.cmake")
    log_info("Downloading vcpkg.cmake from https://github.com/microsoft/vcpkg...")
    file(
      DOWNLOAD
        "https://github.com/microsoft/vcpkg/raw/master/scripts/buildsystems/vcpkg.cmake"
      "${CMAKE_BINARY_DIR}/vcpkg.cmake"
    )
    log_info("vcpkg config downloaded successfully")
  endif()

  if(${PROJECT_NAME}_VERBOSE_OUTPUT)
    set(VCPKG_VERBOSE ON)
  endif()
  set(
    CMAKE_TOOLCHAIN_FILE
    "${CMAKE_TOOLCHAIN_FILE}"
    "${CMAKE_BINARY_DIR}/vcpkg.cmake"
  )
  log_info("vcpkg toolchain file configured")
else()
  log_debug("vcpkg integration disabled")
endif()
