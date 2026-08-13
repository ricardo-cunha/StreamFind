add_executable(streamfind_core_tests
    unit/core_smoke.cpp
)

target_link_libraries(streamfind_core_tests PRIVATE
    streamfind::core
    streamfind::duckdb
    streamfind::openbabel
)

target_include_directories(streamfind_core_tests PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/../external
    ${CMAKE_CURRENT_SOURCE_DIR}/../external/openbabel/openbabel-3-2-0/include
)

target_compile_definitions(streamfind_core_tests PRIVATE
    STREAMFIND_OPENBABEL_TEST_DATA_DIR="${STREAMFIND_OPENBABEL_DATA_DIR}"
)

add_test(NAME streamfind_core_tests COMMAND streamfind_core_tests)

add_executable(streamfind_project_tests unit/project_smoke.cpp)
target_link_libraries(streamfind_project_tests PRIVATE streamfind::core)
add_test(NAME streamfind_project_tests COMMAND streamfind_project_tests)

add_executable(streamfind_mcp_tests unit/mcp_smoke.cpp)
target_link_libraries(streamfind_mcp_tests PRIVATE streamfind::core)
target_compile_definitions(streamfind_mcp_tests PRIVATE
    STREAMFIND_MCP_FIXTURE="${CMAKE_CURRENT_SOURCE_DIR}/../../semantic/fixtures/mcp_catalogue.json"
)
add_test(NAME streamfind_mcp_tests COMMAND streamfind_mcp_tests)

add_executable(streamfind_domain_tests unit/domain_smoke.cpp)
target_link_libraries(streamfind_domain_tests PRIVATE streamfind::core streamfind_mass_spec streamfind_raman streamfind_sensors)
target_compile_definitions(streamfind_domain_tests PRIVATE
    STREAMFIND_MASS_SPEC_DATA_ROOT="${STREAMFIND_DATA_ROOT}/inst/extdata/data/mass_spec"
)
add_test(NAME streamfind_domain_tests COMMAND streamfind_domain_tests)

add_executable(streamfind_conformance_tests unit/conformance.cpp)
target_link_libraries(streamfind_conformance_tests PRIVATE streamfind::core)
target_compile_definitions(streamfind_conformance_tests PRIVATE
    STREAMFIND_CONFORMANCE_FIXTURE="${CMAKE_CURRENT_SOURCE_DIR}/fixtures/project_conformance.json"
)
add_test(NAME streamfind_conformance_tests COMMAND streamfind_conformance_tests)

add_executable(streamfind_vendor_tests unit/vendor_smoke.cpp)
target_link_libraries(streamfind_vendor_tests PRIVATE
    streamfind::duckdb
    streamfind::openbabel
)
target_include_directories(streamfind_vendor_tests PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/../external
    ${CMAKE_CURRENT_SOURCE_DIR}/../external/openbabel/openbabel-3-2-0/include
)
if(MSVC)
    target_link_options(streamfind_vendor_tests PRIVATE
        "/WHOLEARCHIVE:$<TARGET_FILE:streamfind_openbabel>"
    )
endif()
add_test(NAME streamfind_vendor_tests COMMAND streamfind_vendor_tests)
set_tests_properties(streamfind_vendor_tests PROPERTIES
    WORKING_DIRECTORY "${STREAMFIND_OPENBABEL_DATA_DIR}"
)

if(WIN32)
    add_custom_command(TARGET streamfind_project_tests POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "$<TARGET_FILE:streamfind::duckdb>"
            "$<TARGET_FILE_DIR:streamfind_project_tests>"
    )
    add_custom_command(TARGET streamfind_vendor_tests POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "$<TARGET_FILE:streamfind::duckdb>"
            "$<TARGET_FILE_DIR:streamfind_vendor_tests>"
    )
endif()
