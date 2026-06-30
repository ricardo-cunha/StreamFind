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

include(${CMAKE_CURRENT_SOURCE_DIR}/src/core/cmake/ExternalDependencies.cmake)
streamfind_configure_duckdb(${CMAKE_CURRENT_SOURCE_DIR})

# -----------------------------------------------------------------------------
# Locate CogniFlow contract headers
# -----------------------------------------------------------------------------
if(NOT DEFINED Python3_EXECUTABLE OR Python3_EXECUTABLE STREQUAL "")
  find_package(Python3 REQUIRED COMPONENTS Interpreter)
endif()

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

function(streamfind_enable_openbabel target repo_root)
  set(_sf_ob_root "${repo_root}/src/core/external/openbabel/openbabel-3-2-0")
  set(_sf_ob_data "${_sf_ob_root}/data")
  set(_sf_manifests "${repo_root}/src/core/external/openbabel/build_manifest")
  set(_sf_inchi_upstream "${repo_root}/src/core/external/openbabel/inchi-iupac-1.07.5")
  set(_sf_inchi_base "${repo_root}/src/core/external/openbabel/INCHI_BASE")

  set(_sf_ob_includes
    ${_sf_ob_root}/include
    ${_sf_ob_root}/include/inchi
    ${_sf_ob_root}/src
    ${_sf_ob_data}
    ${_sf_ob_root}/src/formats/libinchi
    ${_sf_inchi_upstream}/src
    ${_sf_inchi_base}/src
  )

  file(STRINGS "${_sf_manifests}/openbabel_cpp.txt" _sf_ob_cpp_entries)
  foreach(_sf_entry ${_sf_ob_cpp_entries})
    list(APPEND _sf_ob_cpp_sources ${repo_root}/${_sf_entry})
  endforeach()
  list(APPEND _sf_ob_cpp_sources ${repo_root}/src/core/external/openbabel/openbabel_c_api.cpp)

  file(STRINGS "${_sf_manifests}/inchi_c.txt" _sf_ob_c_entries)
  foreach(_sf_entry ${_sf_ob_c_entries})
    if(_sf_entry MATCHES "\\*")
      file(GLOB _sf_globbed ${repo_root}/${_sf_entry})
      list(APPEND _sf_ob_c_sources ${_sf_globbed})
    else()
      list(APPEND _sf_ob_c_sources ${repo_root}/${_sf_entry})
    endif()
  endforeach()

  set(_sf_ob_c_flags -w -O2)
  set(_sf_ob_cxx_flags -w -O2 -std=c++17)
  if(WIN32)
    list(APPEND _sf_ob_c_flags -DHAVE_ISFINITE=1 -D__USE_MINGW_ANSI_STDIO=1)
    list(APPEND _sf_ob_cxx_flags -DHAVE_ISFINITE=1 -D__USE_MINGW_ANSI_STDIO=1)
  else()
    list(APPEND _sf_ob_c_flags -fPIC)
    list(APPEND _sf_ob_cxx_flags -fPIC)
  endif()

  if(WIN32)
    add_library(streamfind_openbabel SHARED ${_sf_ob_cpp_sources} ${_sf_ob_c_sources})
    target_compile_definitions(streamfind_openbabel PRIVATE
      streamfind_OPENBABEL_BUILD_DLL
      TARGET_API_LIB
    )
    set_target_properties(streamfind_openbabel PROPERTIES
      OUTPUT_NAME openbabel_streamfind
      CXX_STANDARD 17
      CXX_STANDARD_REQUIRED ON
    )
    target_compile_options(streamfind_openbabel PRIVATE
      $<$<COMPILE_LANGUAGE:CXX>:${_sf_ob_cxx_flags}>
      $<$<COMPILE_LANGUAGE:C>:${_sf_ob_c_flags}>
    )
    target_include_directories(streamfind_openbabel PRIVATE ${_sf_ob_includes})

    add_custom_command(TARGET streamfind_openbabel POST_BUILD
      COMMAND ${CMAKE_COMMAND} -E make_directory $<TARGET_FILE_DIR:${target}>
      COMMAND ${CMAKE_COMMAND} -E copy_if_different
        $<TARGET_FILE:streamfind_openbabel>
        $<TARGET_FILE_DIR:${target}>
      COMMAND ${CMAKE_COMMAND} -E copy_if_different
        $<TARGET_FILE:streamfind_openbabel>
        ${repo_root}/python/cf_streamfind/libs/openbabel_streamfind.dll
      COMMAND ${CMAKE_COMMAND} -E copy_directory
        ${_sf_ob_data}
        ${repo_root}/python/cf_streamfind/resources/openbabel/data
    )

    target_include_directories(${target} PRIVATE ${_sf_ob_includes})
    target_include_directories(${target} PRIVATE ${repo_root}/src/core/external/openbabel)
    add_dependencies(${target} streamfind_openbabel)
  else()
    add_library(streamfind_openbabel STATIC ${_sf_ob_cpp_sources})
    add_library(streamfind_inchi STATIC ${_sf_ob_c_sources})

    set_target_properties(streamfind_openbabel PROPERTIES
      CXX_STANDARD 17
      CXX_STANDARD_REQUIRED ON
      POSITION_INDEPENDENT_CODE ON
    )
    set_target_properties(streamfind_inchi PROPERTIES
      POSITION_INDEPENDENT_CODE ON
    )
    target_compile_definitions(streamfind_openbabel PRIVATE TARGET_API_LIB)
    target_compile_definitions(streamfind_inchi PRIVATE TARGET_API_LIB)
    target_compile_options(streamfind_openbabel PRIVATE
      $<$<COMPILE_LANGUAGE:CXX>:${_sf_ob_cxx_flags}>
    )
    target_compile_options(streamfind_inchi PRIVATE ${_sf_ob_c_flags})
    target_include_directories(streamfind_openbabel PRIVATE ${_sf_ob_includes})
    target_include_directories(streamfind_inchi PRIVATE ${_sf_ob_includes})

    target_link_libraries(${target} PRIVATE
      -Wl,--whole-archive
      $<TARGET_FILE:streamfind_openbabel>
      -Wl,--no-whole-archive
      streamfind_inchi
    )
    target_include_directories(${target} PRIVATE ${_sf_ob_includes})
    target_include_directories(${target} PRIVATE ${repo_root}/src/core/external/openbabel)
    add_dependencies(${target} streamfind_openbabel streamfind_inchi)
  endif()
endfunction()

# -----------------------------------------------------------------------------
# Vendored zlib for Python/native builds
# -----------------------------------------------------------------------------
set(CF_streamfind_ZLIB_SOURCE_DIR
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core/external/zlib/zlib-develop
)

if(NOT EXISTS "${CF_streamfind_ZLIB_SOURCE_DIR}/zlib.h")
  message(FATAL_ERROR
    "Vendored zlib source not found at '${CF_streamfind_ZLIB_SOURCE_DIR}'."
  )
endif()

add_subdirectory(
  ${CF_streamfind_ZLIB_SOURCE_DIR}
  ${CMAKE_CURRENT_BINARY_DIR}/vendored-zlib
)

set(CF_streamfind_HAS_ZLIB TRUE)

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
# Shared streamfind sources
# -----------------------------------------------------------------------------
file(GLOB JSON_SCHEMA_VALIDATOR_SOURCES CONFIGURE_DEPENDS
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core/external/json-schema-validator/src/*.cpp
)
file(GLOB JSON_CORE_SOURCES CONFIGURE_DEPENDS
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core/json/*.cpp
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

set(streamfind_CORE_SOURCES
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core/external/simdutf_wrapper.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core/external/openbabel_adapter.cpp
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
add_library(cf_streamfind_steps SHARED
  ${CMAKE_CURRENT_SOURCE_DIR}/python/cf_streamfind/cpp/steps.cpp
  ${streamfind_CORE_SOURCES}
  ${SIG_HEADER}
)

target_include_directories(cf_streamfind_steps PRIVATE
  ${CF_CONTRACTS_INCLUDE}
  ${GENERATED_DIR}
  ${CMAKE_CURRENT_SOURCE_DIR}/python/cf_streamfind/cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core/asm
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core/external
  ${CF_streamfind_ZLIB_SOURCE_DIR}
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core/external/simdutf
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core/external/nlohmann
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core/external/json-schema-validator/src
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core/external/pugixml-1.14/src
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core/json
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core/mass_spec
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core/nta
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core/project
  ${STREAMFIND_DUCKDB_INCLUDE_DIR}
)

streamfind_enable_openbabel(cf_streamfind_steps ${CMAKE_CURRENT_SOURCE_DIR})
target_link_libraries(cf_streamfind_steps PRIVATE streamfind_duckdb)

target_link_libraries(cf_streamfind_steps PRIVATE streamfind::zlib)
target_compile_definitions(cf_streamfind_steps PRIVATE CF_streamfind_HAS_ZLIB=1)

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
  OUTPUT_NAME libcf_streamfind_steps
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/cf_streamfind/bin"
  LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/cf_streamfind/bin"
  ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/cf_streamfind/bin"
)

if(CMAKE_CONFIGURATION_TYPES)
  foreach(_cfg ${CMAKE_CONFIGURATION_TYPES})
    string(TOUPPER "${_cfg}" _cfg_upper)
    set_target_properties(cf_streamfind_steps PROPERTIES
      RUNTIME_OUTPUT_DIRECTORY_${_cfg_upper} "${CMAKE_CURRENT_BINARY_DIR}/cf_streamfind/bin"
      LIBRARY_OUTPUT_DIRECTORY_${_cfg_upper} "${CMAKE_CURRENT_BINARY_DIR}/cf_streamfind/bin"
      ARCHIVE_OUTPUT_DIRECTORY_${_cfg_upper} "${CMAKE_CURRENT_BINARY_DIR}/cf_streamfind/bin"
    )
  endforeach()
endif()

set(CF_streamfind_RUNTIME_DLLS)
if(WIN32)
  if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/inst/libs/x64/duckdb.dll")
    list(APPEND CF_streamfind_RUNTIME_DLLS ${CMAKE_CURRENT_SOURCE_DIR}/inst/libs/x64/duckdb.dll)
  elseif(EXISTS "${STREAMFIND_DUCKDB_RUNTIME_LIBRARY}")
    list(APPEND CF_streamfind_RUNTIME_DLLS ${STREAMFIND_DUCKDB_RUNTIME_LIBRARY})
  endif()
endif()

if(CF_streamfind_RUNTIME_DLLS)
  add_custom_command(TARGET cf_streamfind_steps POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_CURRENT_BINARY_DIR}/cf_streamfind/bin
    COMMAND ${CMAKE_COMMAND} -E copy_if_different ${CF_streamfind_RUNTIME_DLLS} ${CMAKE_CURRENT_BINARY_DIR}/cf_streamfind/bin
  )
endif()

install(DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/cf_streamfind/bin/
        DESTINATION cf_streamfind/bin
        FILES_MATCHING
        PATTERN "*.dll"
        PATTERN "*.so"
        PATTERN "*.dylib")

if(EXISTS "${STREAMFIND_DUCKDB_RUNTIME_LIBRARY}")
  install(FILES ${STREAMFIND_DUCKDB_RUNTIME_LIBRARY}
          DESTINATION cf_streamfind/libs)
elseif(EXISTS "${STREAMFIND_DUCKDB_LIBRARY}")
  install(FILES ${STREAMFIND_DUCKDB_LIBRARY}
          DESTINATION cf_streamfind/libs)
endif()

install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/python/cf_streamfind/resources/
        DESTINATION cf_streamfind/resources)

install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/src/core/external/openbabel/openbabel-3-2-0/data/
        DESTINATION cf_streamfind/resources/openbabel/data)

install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/python/cf_streamfind/steps.nq
        DESTINATION cf_streamfind)

install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/python/cf_streamfind/__init__.py
        DESTINATION cf_streamfind)

install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/python/cf_streamfind/external_tools.py
        DESTINATION cf_streamfind)
