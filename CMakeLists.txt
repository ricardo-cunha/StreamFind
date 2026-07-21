cmake_minimum_required(VERSION 3.20)
project(streamfind LANGUAGES CXX)

option(STREAMFIND_BUILD_CORE
       "Build the standalone streamfind core"
       ON)
option(STREAMFIND_BUILD_TESTS
       "Build native tests"
       ON)
option(STREAMFIND_BUILD_SHARED
       "Build shared native libraries"
       OFF)
option(STREAMFIND_BUILD_CF_STREAMFIND
       "Build the relocated Cogniflow integration"
       OFF)

if(STREAMFIND_BUILD_TESTS)
  enable_testing()
endif()

if(STREAMFIND_BUILD_CORE)
  add_subdirectory(core)
endif()

if(STREAMFIND_BUILD_CF_STREAMFIND)
  add_subdirectory(integrations/cf-streamfind)
endif()
