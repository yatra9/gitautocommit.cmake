get_filename_component(MODULE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../.." ABSOLUTE)
list(APPEND CMAKE_MODULE_PATH ${MODULE_DIR})
include(GitAutoCommit RESULT_VARIABLE)
 
cmake_minimum_required(VERSION 2.8.3)
project(test)

include_directories( ${CMAKE_CURRENT_BINARY_DIR} )

add_executable(test1 test.c)
GIT_AUTOCOMMIT(test1
               CONFIGURE_ONLY
               CONFIGURE_FILE config.h.in config.h @ONLY NEWLINE_STYLE UNIX)
#configure_file(config.h.in config.h)


