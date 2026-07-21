cmake_minimum_required(VERSION 3.20)
project(streamfind LANGUAGES CXX)

option(STREAMFIND_BUILD_CF_STREAMFIND
       "Build the relocated Cogniflow integration"
       OFF)

if(STREAMFIND_BUILD_CF_STREAMFIND)
  add_subdirectory(integrations/cf-streamfind)
endif()
