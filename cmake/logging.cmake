# ==============================================================================
# CMake Module: Hierarchical Logging System
# ==============================================================================
# Provides a leveled logging system (DEBUG, INFO, WARN, ERR, FATAL) for CMake
# configuration scripts. This module must be included AFTER project() is called
# but BEFORE any module that uses log_* functions.
# ==============================================================================

# ------------------------------------------------------------------------------
# Logging Level Definitions
# ------------------------------------------------------------------------------
set(LOG_LEVEL_DEBUG 0)
set(LOG_LEVEL_INFO  1)
set(LOG_LEVEL_WARN  2)
set(LOG_LEVEL_ERR   3)
set(LOG_LEVEL_FATAL 4)

set(
  ${PROJECT_NAME}_LOG_LEVEL
  "INFO"
  CACHE STRING
  "Minimum log level to emit (DEBUG, INFO, WARN, ERR, FATAL)."
)
set_property(
  CACHE ${PROJECT_NAME}_LOG_LEVEL
  PROPERTY STRINGS "DEBUG;INFO;WARN;ERR;FATAL"
)

string(TOUPPER "${${PROJECT_NAME}_LOG_LEVEL}" _log_level_upper)
if("DEBUG" STREQUAL _log_level_upper)
  set(_log_level_threshold ${LOG_LEVEL_DEBUG})
elseif("INFO" STREQUAL _log_level_upper)
  set(_log_level_threshold ${LOG_LEVEL_INFO})
elseif("WARN" STREQUAL _log_level_upper)
  set(_log_level_threshold ${LOG_LEVEL_WARN})
elseif("ERR" STREQUAL _log_level_upper)
  set(_log_level_threshold ${LOG_LEVEL_ERR})
elseif("FATAL" STREQUAL _log_level_upper)
  set(_log_level_threshold ${LOG_LEVEL_FATAL})
else()
  message(WARNING "[WARN] Unknown log level '${${PROJECT_NAME}_LOG_LEVEL}', defaulting to INFO")
  set(_log_level_threshold ${LOG_LEVEL_INFO})
endif()

# ------------------------------------------------------------------------------
# Core Logging Function
# ------------------------------------------------------------------------------
function(log_message level label msg)
  if(${level} LESS ${_log_level_threshold})
    return()
  endif()
  if(${level} GREATER_EQUAL ${LOG_LEVEL_ERR})
    message(${label} "${msg}")
  else()
    message(STATUS "${msg}")
  endif()
endfunction()

function(log_debug msg)
  log_message(${LOG_LEVEL_DEBUG} STATUS "[DEBUG] ${msg}")
endfunction()

function(log_info msg)
  log_message(${LOG_LEVEL_INFO} STATUS "[INFO] ${msg}")
endfunction()

function(log_warn msg)
  log_message(${LOG_LEVEL_WARN} WARNING "[WARN] ${msg}")
endfunction()

function(log_err msg)
  log_message(${LOG_LEVEL_ERR} SEND_ERROR "[ERR] ${msg}")
endfunction()

function(log_fatal msg)
  log_message(${LOG_LEVEL_FATAL} FATAL_ERROR "[ERR] ${msg}")
endfunction()
