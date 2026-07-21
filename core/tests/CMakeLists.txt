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
    add_custom_command(TARGET streamfind_vendor_tests POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "$<TARGET_FILE:streamfind::duckdb>"
            "$<TARGET_FILE_DIR:streamfind_vendor_tests>"
    )
endif()
