cmake_minimum_required(VERSION 3.10)
project(anitomy_wrapper LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Source files from anitomy library
set(ANITOMY_SOURCES
    ${CMAKE_CURRENT_SOURCE_DIR}/../anitomy/anitomy/anitomy.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/../anitomy/anitomy/element.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/../anitomy/anitomy/keyword.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/../anitomy/anitomy/parser.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/../anitomy/anitomy/parser_helper.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/../anitomy/anitomy/parser_number.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/../anitomy/anitomy/string.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/../anitomy/anitomy/token.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/../anitomy/anitomy/tokenizer.cpp
)

# Define the shared library that Flutter will load
add_library(anitomy_wrapper SHARED 
    anitomy_wrapper.cpp
    ${ANITOMY_SOURCES}
)

# Point to the library's include folder
target_include_directories(anitomy_wrapper PRIVATE 
    ${CMAKE_CURRENT_SOURCE_DIR}/../anitomy
)

# Ensure symbols are exported
set_target_properties(anitomy_wrapper PROPERTIES
    CXX_VISIBILITY_PRESET default
    VISIBILITY_INLINES_HIDDEN OFF
)

# On Linux/Android, ensure symbols are visible
set_target_properties(anitomy_wrapper PROPERTIES
    C_VISIBILITY_PRESET default
    CXX_VISIBILITY_PRESET default
    VISIBILITY_INLINES_HIDDEN OFF
)