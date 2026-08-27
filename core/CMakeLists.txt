cmake_minimum_required(VERSION 3.20)
project(streamfind_core LANGUAGES C CXX)

option(STREAMFIND_BUILD_TESTS "Build native tests" ON)
option(STREAMFIND_BUILD_SHARED "Build shared native libraries" OFF)

if(STREAMFIND_BUILD_TESTS)
    enable_testing()
endif()

include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/streamfind_dependencies.cmake)
streamfind_configure_dependencies(${CMAKE_CURRENT_SOURCE_DIR}/vendor)

set(STREAMFIND_SEMANTIC_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../semantic/generated")

set(STREAMFIND_CORE_SOURCES
    src/version.cpp
    src/api.cpp
    src/project.cpp
    src/mcp.cpp
    src/catalogue.cpp
)

if(STREAMFIND_BUILD_SHARED)
    add_library(streamfind_core SHARED ${STREAMFIND_CORE_SOURCES})
    target_compile_definitions(streamfind_core PRIVATE STREAMFIND_CORE_BUILDING_SHARED)
else()
    add_library(streamfind_core STATIC ${STREAMFIND_CORE_SOURCES})
endif()

add_library(streamfind::core ALIAS streamfind_core)

set_target_properties(streamfind_core PROPERTIES
    CXX_STANDARD 20
    CXX_STANDARD_REQUIRED ON
    CXX_EXTENSIONS OFF
    EXPORT_NAME core
)

# Compile-time install prefix so the catalogue search chain can resolve the
# installed share/streamfind data directory when STREAMFIND_CATALOGUE is unset.
target_compile_definitions(streamfind_core PRIVATE
    STREAMFIND_INSTALL_PREFIX="${CMAKE_INSTALL_PREFIX}"
)

target_compile_features(streamfind_core PUBLIC cxx_std_20)

target_link_libraries(streamfind_core
    PUBLIC
        streamfind::duckdb
        streamfind::openbabel
        streamfind::zlib
)

target_include_directories(streamfind_core
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<INSTALL_INTERFACE:include>
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/vendor>
)

if(STREAMFIND_BUILD_SHARED)
    target_compile_definitions(streamfind_core INTERFACE STREAMFIND_CORE_USING_SHARED)
endif()

install(
    TARGETS streamfind_core
    EXPORT streamfind-core-targets
    ARCHIVE DESTINATION lib
    LIBRARY DESTINATION lib
    RUNTIME DESTINATION bin
)

install(
    TARGETS streamfind_inchi streamfind_openbabel streamfind_zlib
    EXPORT streamfind-core-targets
    ARCHIVE DESTINATION lib
    LIBRARY DESTINATION lib
    RUNTIME DESTINATION bin
)

install(
    DIRECTORY include/
    DESTINATION include
)

install(
    EXPORT streamfind-core-targets
    FILE streamfind-core-targets.cmake
    NAMESPACE streamfind::
    DESTINATION lib/cmake/streamfind
)

if(STREAMFIND_DUCKDB_RUNTIME AND EXISTS "${STREAMFIND_DUCKDB_RUNTIME}")
    if(WIN32)
        install(FILES "${STREAMFIND_DUCKDB_RUNTIME}" DESTINATION bin)
    else()
        install(FILES "${STREAMFIND_DUCKDB_RUNTIME}" DESTINATION lib)
    endif()
endif()

if(STREAMFIND_DUCKDB_IMPORT_LIBRARY AND EXISTS "${STREAMFIND_DUCKDB_IMPORT_LIBRARY}")
    install(FILES "${STREAMFIND_DUCKDB_IMPORT_LIBRARY}" DESTINATION lib)
endif()

# catalogue.duckdb is a required installation artifact (the runtime knowledge
# base of the MCP servers); install it next to the DuckDB runtime under share.
install(FILES "${STREAMFIND_SEMANTIC_DIR}/catalogue.duckdb" DESTINATION share/streamfind)

add_subdirectory(domains)

install(
    DIRECTORY "${STREAMFIND_OPENBABEL_DATA_DIR}/"
    DESTINATION share/streamfind/openbabel/data
)

if(STREAMFIND_BUILD_TESTS)
    enable_testing()
    add_subdirectory(tests)
endif()

add_executable(streamfind_mcp tools/streamfind-mcp.cpp)
target_link_libraries(streamfind_mcp PRIVATE streamfind::core streamfind_mass_spec streamfind_raman streamfind_sensors)
if(WIN32)
    add_custom_command(TARGET streamfind_mcp POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "$<TARGET_FILE:streamfind::duckdb>"
            "$<TARGET_FILE_DIR:streamfind_mcp>"
    )
endif()
# Dev-tree catalogue: keep catalogue.duckdb next to the built MCP server so the
# search chain (env -> next-to-binary -> install data dir) resolves in builds.
add_custom_command(TARGET streamfind_mcp POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${STREAMFIND_SEMANTIC_DIR}/catalogue.duckdb"
        "$<TARGET_FILE_DIR:streamfind_mcp>"
)
