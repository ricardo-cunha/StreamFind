cmake_minimum_required(VERSION 3.20)
project(cf_streamfind_steps LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

get_filename_component(_CF_REPO_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../" ABSOLUTE)
include("${_CF_REPO_ROOT}/tools/cmake/cf_contracts_include.cmake")

set(GENERATED_DIR ${CMAKE_CURRENT_BINARY_DIR}/generated)
file(MAKE_DIRECTORY ${GENERATED_DIR})

set(STEPS_DOCUMENT ${CMAKE_CURRENT_SOURCE_DIR}/../steps.nq)
set(SIG_HEADER ${GENERATED_DIR}/cf_streamfind_signature_hashes.h)

set(CF_SIGGEN_COMMAND ${Python3_EXECUTABLE} -m cf_step_tooling.siggen)
execute_process(
  COMMAND ${Python3_EXECUTABLE} -c
          "import inspect, pathlib, cf_step_tooling.siggen as sig, cf_step_tooling._signatures as impl, cf_step_tooling._step_document as doc, cf_step_tooling._rdf as rdf; print(pathlib.Path(inspect.getsourcefile(sig)).resolve()); print(pathlib.Path(inspect.getsourcefile(impl)).resolve()); print(pathlib.Path(inspect.getsourcefile(doc)).resolve()); print(pathlib.Path(inspect.getsourcefile(rdf)).resolve())"
  OUTPUT_VARIABLE CF_SIGGEN_DEPENDENCY_OUTPUT
  OUTPUT_STRIP_TRAILING_WHITESPACE
)
string(REPLACE "\r\n" "\n" CF_SIGGEN_DEPENDENCY_OUTPUT "${CF_SIGGEN_DEPENDENCY_OUTPUT}")
string(REPLACE "\n" ";" CF_SIGGEN_DEPENDENCIES "${CF_SIGGEN_DEPENDENCY_OUTPUT}")

add_custom_command(
  OUTPUT ${SIG_HEADER}
  COMMAND ${CF_SIGGEN_COMMAND} --steps ${STEPS_DOCUMENT} --out ${SIG_HEADER} --scratch
  DEPENDS ${STEPS_DOCUMENT} ${CF_SIGGEN_DEPENDENCIES}
  COMMENT "Generating cf_streamfind signature hashes"
)

find_package(ZLIB QUIET)
if(ZLIB_FOUND)
  set(CF_streamfind_ZLIB_LIBS ZLIB::ZLIB)
  set(CF_streamfind_HAS_ZLIB TRUE)
else()
  find_library(ZLIB_LIBRARY z PATHS $ENV{ZLIB_ROOT}/lib)
  find_path(ZLIB_INCLUDE_DIR zlib.h PATHS $ENV{ZLIB_ROOT}/include)
  if(ZLIB_LIBRARY AND ZLIB_INCLUDE_DIR)
    set(CF_streamfind_ZLIB_LIBS ${ZLIB_LIBRARY})
    set(CF_streamfind_HAS_ZLIB TRUE)
  else()
    set(CF_streamfind_HAS_ZLIB FALSE)
    message(WARNING "zlib not found; mzML zlib decompression will not be available.")
  endif()
endif()

add_library(${PROJECT_NAME} SHARED
  ${CMAKE_CURRENT_SOURCE_DIR}/steps.cpp
  ${SIG_HEADER}
)

target_include_directories(${PROJECT_NAME} PRIVATE
  ${CF_CONTRACTS_INCLUDE}
  ${GENERATED_DIR}
  ${CMAKE_CURRENT_SOURCE_DIR}
)

if(CF_streamfind_HAS_ZLIB)
  target_include_directories(${PROJECT_NAME} PRIVATE ${ZLIB_INCLUDE_DIR})
  target_link_libraries(${PROJECT_NAME} PRIVATE ${CF_streamfind_ZLIB_LIBS})
  target_compile_definitions(${PROJECT_NAME} PRIVATE CF_streamfind_HAS_ZLIB=1)
endif()

target_compile_definitions(${PROJECT_NAME} PRIVATE CF_STEP_ABI_EXPORTS)

set_target_properties(${PROJECT_NAME} PROPERTIES
  PREFIX ""
  OUTPUT_NAME libcf_streamfind_steps
)

add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_CURRENT_SOURCE_DIR}/../bin
  COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:${PROJECT_NAME}> ${CMAKE_CURRENT_SOURCE_DIR}/../bin
)

if(DEFINED SKBUILD_PLATLIB_DIR AND NOT SKBUILD_PLATLIB_DIR STREQUAL "")
  add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory ${SKBUILD_PLATLIB_DIR}/cf_streamfind/bin
    COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:${PROJECT_NAME}> ${SKBUILD_PLATLIB_DIR}/cf_streamfind/bin
  )
endif()
