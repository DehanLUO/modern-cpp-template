set(DOXYGEN_CALLER_GRAPH YES)
set(DOXYGEN_CALL_GRAPH YES)
set(DOXYGEN_EXTRACT_ALL YES)
set(DOXYGEN_OUTPUT_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/docs)

find_package(Doxygen REQUIRED dot)
if(DOXYGEN_FOUND)
  log_info("Doxygen found: ${DOXYGEN_EXECUTABLE}")
else()
  log_warn("Doxygen not found; documentation target may fail")
endif()

doxygen_add_docs(doxygen-docs ${PROJECT_SOURCE_DIR})

verbose_message("Doxygen has been setup and documentation is now available.")
