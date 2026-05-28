cmake_minimum_required(VERSION 3.20)
project(cf_streamfind_steps LANGUAGES CXX)

find_package(Python3 REQUIRED COMPONENTS Interpreter Development)

include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/Repackaged.cmake OPTIONAL RESULT_VARIABLE _skbuild_cmake_repkg)
if(_skbuild_cmake_repkg STREQUAL "_skbuild_cmake_repkg")
  unset(_skbuild_cmake_repkg)
  set(_SKBUILD_REPACKAGED FALSE)
else()
  set(_SKBUILD_REPACKAGED TRUE)
endif()

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# -----------------------------------------------------------------------------
# Locate CogniFlow contract headers
# -----------------------------------------------------------------------------
if(NOT DEFINED CF_CONTRACTS_INCLUDE OR CF_CONTRACTS_INCLUDE STREQUAL "")
  execute_process(
    COMMAND ${Python3_EXECUTABLE} -c "import cf_package_contracts as c; p = getattr(c, 'cf_contracts_include_path', lambda: '')(); print(p if p else '')"
    OUTPUT_VARIABLE _CF_PY_INCLUDE
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET
  )
  if(NOT _CF_PY_INCLUDE STREQUAL "" AND EXISTS "${_CF_PY_INCLUDE}/cf_step_abi.h")
    set(CF_CONTRACTS_INCLUDE "${_CF_PY_INCLUDE}")
  endif()
endif()

if(NOT DEFINED CF_CONTRACTS_INCLUDE OR CF_CONTRACTS_INCLUDE STREQUAL "")
  message(FATAL_ERROR "cf_package_contracts include path not found. Install cf-package-contracts.")
endif()

if(NOT EXISTS "${CF_CONTRACTS_INCLUDE}/cf_step_abi.h")
  message(FATAL_ERROR "cf_step_abi.h not found in '${CF_CONTRACTS_INCLUDE}'")
endif()

# -----------------------------------------------------------------------------
# Vendored zlib for Python/native builds
# -----------------------------------------------------------------------------
set(CF_STREAMFIND_ZLIB_SOURCE_DIR
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core/external/zlib/zlib-develop
)

if(NOT EXISTS "${CF_STREAMFIND_ZLIB_SOURCE_DIR}/zlib.h")
  message(FATAL_ERROR
    "Vendored zlib source not found at '${CF_STREAMFIND_ZLIB_SOURCE_DIR}'."
  )
endif()

add_subdirectory(
  ${CF_STREAMFIND_ZLIB_SOURCE_DIR}
  ${CMAKE_CURRENT_BINARY_DIR}/vendored-zlib
)

set(CF_STREAMFIND_HAS_ZLIB TRUE)

# -----------------------------------------------------------------------------
# OpenMP
# -----------------------------------------------------------------------------
find_package(OpenMP QUIET)

# -----------------------------------------------------------------------------
# Generate CogniFlow signature hash header from steps.nq
# -----------------------------------------------------------------------------
set(GENERATED_DIR ${CMAKE_CURRENT_BINARY_DIR}/generated)
file(MAKE_DIRECTORY ${GENERATED_DIR})

set(STEPS_DOCUMENT ${CMAKE_CURRENT_SOURCE_DIR}/python/cf_streamfind/steps.nq)
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
  VERBATIM
)

# -----------------------------------------------------------------------------
# Shared StreamFind sources
# -----------------------------------------------------------------------------
file(GLOB JSON_SCHEMA_VALIDATOR_SOURCES CONFIGURE_DEPENDS
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core/external/json-schema-validator/src/*.cpp
)
file(GLOB JSON_CORE_SOURCES CONFIGURE_DEPENDS
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core/json_core/*.cpp
)
file(GLOB ASM_SOURCES CONFIGURE_DEPENDS
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core/asm/*.cpp
)
file(GLOB PROJECT_SOURCES CONFIGURE_DEPENDS
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core/project/*.cpp
)
file(GLOB NTA_SOURCES CONFIGURE_DEPENDS
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core/nta/*.cpp
)
file(GLOB MASS_SPEC_SOURCES CONFIGURE_DEPENDS
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core/mass_spec/*.cpp
)

set(STREAMFIND_CORE_SOURCES
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core/external/simdutf_wrapper.cpp
  ${JSON_SCHEMA_VALIDATOR_SOURCES}
  ${JSON_CORE_SOURCES}
  ${ASM_SOURCES}
  ${PROJECT_SOURCES}
  ${NTA_SOURCES}
  ${MASS_SPEC_SOURCES}
)

# -----------------------------------------------------------------------------
# Vendored DuckDB
# -----------------------------------------------------------------------------
if(WIN32)
  set(CF_STREAMFIND_DUCKDB_INCLUDE ${CMAKE_CURRENT_SOURCE_DIR}/src/core/external/duckdb/windows)
  set(CF_STREAMFIND_DUCKDB_LIB ${CMAKE_CURRENT_SOURCE_DIR}/src/core/external/duckdb/windows/duckdb.lib)
elseif(APPLE)
  message(FATAL_ERROR "Vendored DuckDB linkage is not configured for macOS yet.")
else()
  set(CF_STREAMFIND_DUCKDB_INCLUDE ${CMAKE_CURRENT_SOURCE_DIR}/src/core/external/duckdb/linux)
  set(CF_STREAMFIND_DUCKDB_LIB ${CMAKE_CURRENT_SOURCE_DIR}/src/core/external/duckdb/linux/libduckdb_static.a)
endif()

add_library(cf_streamfind_steps SHARED
  ${CMAKE_CURRENT_SOURCE_DIR}/python/cf_streamfind/cpp/steps.cpp
  ${STREAMFIND_CORE_SOURCES}
  ${SIG_HEADER}
)

target_include_directories(cf_streamfind_steps PRIVATE
  ${CF_CONTRACTS_INCLUDE}
  ${GENERATED_DIR}
  ${CMAKE_CURRENT_SOURCE_DIR}/python/cf_streamfind/cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core/asm
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core/external
  ${CF_STREAMFIND_ZLIB_SOURCE_DIR}
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core/external/simdutf
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core/external/nlohmann
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core/external/json-schema-validator/src
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core/external/pugixml-1.14/src
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core/json_core
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core/mass_spec
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core/nta
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core/project
  ${CF_STREAMFIND_DUCKDB_INCLUDE}
)

target_link_libraries(cf_streamfind_steps PRIVATE ${CF_STREAMFIND_DUCKDB_LIB})

target_link_libraries(cf_streamfind_steps PRIVATE StreamFind::zlib)
target_compile_definitions(cf_streamfind_steps PRIVATE CF_STREAMFIND_HAS_ZLIB=1)

if(OpenMP_CXX_FOUND)
  target_link_libraries(cf_streamfind_steps PRIVATE OpenMP::OpenMP_CXX)
endif()

target_compile_definitions(cf_streamfind_steps PRIVATE
  CF_STEP_ABI_EXPORTS
  _USE_MATH_DEFINES
)

if(WIN32)
  target_compile_definitions(cf_streamfind_steps PRIVATE __USE_MINGW_ANSI_STDIO=1)
endif()

# -----------------------------------------------------------------------------
# Output name and wheel installation
# -----------------------------------------------------------------------------
set_target_properties(cf_streamfind_steps PROPERTIES
  PREFIX ""
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/cf_streamfind/bin"
  LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/cf_streamfind/bin"
  ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/cf_streamfind/bin"
)

if(WIN32)
  set(_CF_STREAMFIND_NATIVE_NAME libcf_streamfind_steps.dll)
elseif(APPLE)
  set(_CF_STREAMFIND_NATIVE_NAME libcf_streamfind_steps.dylib)
else()
  set(_CF_STREAMFIND_NATIVE_NAME libcf_streamfind_steps.so)
endif()

add_custom_command(TARGET cf_streamfind_steps POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_CURRENT_BINARY_DIR}/cf_streamfind/bin
  COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:cf_streamfind_steps> ${CMAKE_CURRENT_BINARY_DIR}/cf_streamfind/bin/${_CF_STREAMFIND_NATIVE_NAME}
)

install(DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/cf_streamfind/bin/
        DESTINATION cf_streamfind/bin
        FILES_MATCHING
        PATTERN "*.dll"
        PATTERN "*.so"
        PATTERN "*.dylib")

install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/python/cf_streamfind/steps.nq
        DESTINATION cf_streamfind)

install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/python/cf_streamfind/__init__.py
        DESTINATION cf_streamfind)
