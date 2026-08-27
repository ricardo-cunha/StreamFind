set(STREAMFIND_TEST_DATA_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../tests/data" CACHE PATH "Path to StreamFind test data")

add_subdirectory(mass_spec)

add_executable(streamfind_mass_spec_reader_tests mass_spec/tests/reader_smoke.cpp)
target_link_libraries(streamfind_mass_spec_reader_tests PRIVATE streamfind_mass_spec)
target_compile_definitions(streamfind_mass_spec_reader_tests PRIVATE
    STREAMFIND_MZML_FIXTURE="${STREAMFIND_TEST_DATA_ROOT}/mass_spec/wastewater/03_tof_ww_is_pos_o3sw_effluent-r001.mzML"
)
add_test(NAME streamfind_mass_spec_reader_tests COMMAND streamfind_mass_spec_reader_tests)

add_executable(streamfind_mass_spec_load_features_tests mass_spec/tests/load_features_test.cpp)
target_link_libraries(streamfind_mass_spec_load_features_tests PRIVATE streamfind_mass_spec)
target_compile_definitions(streamfind_mass_spec_load_features_tests PRIVATE
    STREAMFIND_BASIC_TOF_DATA_ROOT="${STREAMFIND_TEST_DATA_ROOT}/mass_spec/basic_tof"
)
add_test(NAME streamfind_mass_spec_load_features_tests COMMAND streamfind_mass_spec_load_features_tests)
# Test binaries consume the runtime knowledge base via the next-to-binary hop
# of the catalogue search chain.
add_custom_command(TARGET streamfind_mass_spec_load_features_tests POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${STREAMFIND_SEMANTIC_DIR}/catalogue.duckdb"
        "$<TARGET_FILE_DIR:streamfind_mass_spec_load_features_tests>"
)
if(WIN32)
    add_custom_command(TARGET streamfind_mass_spec_load_features_tests POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "$<TARGET_FILE:streamfind::duckdb>"
            "$<TARGET_FILE_DIR:streamfind_mass_spec_load_features_tests>"
    )
endif()

add_executable(streamfind_mass_spec_nta_processing_tests mass_spec/tests/nta_processing_test.cpp)
target_link_libraries(streamfind_mass_spec_nta_processing_tests PRIVATE streamfind_mass_spec)
target_compile_definitions(streamfind_mass_spec_nta_processing_tests PRIVATE
    STREAMFIND_BASIC_TOF_DATA_ROOT="${STREAMFIND_TEST_DATA_ROOT}/mass_spec/basic_tof"
)
add_test(NAME streamfind_mass_spec_nta_processing_tests COMMAND streamfind_mass_spec_nta_processing_tests)
add_custom_command(TARGET streamfind_mass_spec_nta_processing_tests POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${STREAMFIND_SEMANTIC_DIR}/catalogue.duckdb"
        "$<TARGET_FILE_DIR:streamfind_mass_spec_nta_processing_tests>"
)
if(WIN32)
    add_custom_command(TARGET streamfind_mass_spec_nta_processing_tests POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "$<TARGET_FILE:streamfind::duckdb>"
            "$<TARGET_FILE_DIR:streamfind_mass_spec_nta_processing_tests>"
    )
endif()

add_executable(streamfind_mass_spec_nta_wastewater_conformance mass_spec/tests/nta_wastewater_conformance.cpp)
target_link_libraries(streamfind_mass_spec_nta_wastewater_conformance PRIVATE streamfind_mass_spec)
target_compile_definitions(streamfind_mass_spec_nta_wastewater_conformance PRIVATE
    STREAMFIND_WASTEWATER_DATA_ROOT="${STREAMFIND_TEST_DATA_ROOT}/mass_spec/wastewater"
)
add_test(NAME streamfind_mass_spec_nta_wastewater_conformance COMMAND streamfind_mass_spec_nta_wastewater_conformance)
add_custom_command(TARGET streamfind_mass_spec_nta_wastewater_conformance POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${STREAMFIND_SEMANTIC_DIR}/catalogue.duckdb"
        "$<TARGET_FILE_DIR:streamfind_mass_spec_nta_wastewater_conformance>"
)
if(WIN32)
    add_custom_command(TARGET streamfind_mass_spec_nta_wastewater_conformance POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "$<TARGET_FILE:streamfind::duckdb>"
            "$<TARGET_FILE_DIR:streamfind_mass_spec_nta_wastewater_conformance>"
    )
endif()

# Fast CI regression variant: small positive-mode subset + narrow RT window.
# Reuses the same executable with --quantized; guarded by a timeout so a
# misbuild cannot hang CI. The full 18-file suite (default no-arg run, ~3h)
# remains available for full-depth validation.
add_test(NAME streamfind_mass_spec_nta_wastewater_quantized
    COMMAND streamfind_mass_spec_nta_wastewater_conformance --quantized)
set_tests_properties(streamfind_mass_spec_nta_wastewater_quantized PROPERTIES TIMEOUT 900)

# Sciex reader smoke tests (only when a WIFF fixture is supplied).
set(STREAMFIND_SCIEX_WIFF_FIXTURE "" CACHE FILEPATH "Path to a Sciex WIFF fixture")
if(STREAMFIND_SCIEX_WIFF_FIXTURE AND EXISTS "${STREAMFIND_SCIEX_WIFF_FIXTURE}")
    add_executable(streamfind_mass_spec_sciex_reader_tests mass_spec/tests/reader_sciex_smoke.cpp)
    target_link_libraries(streamfind_mass_spec_sciex_reader_tests PRIVATE streamfind_mass_spec)
    target_compile_definitions(streamfind_mass_spec_sciex_reader_tests PRIVATE
        STREAMFIND_SCIEX_WIFF_FIXTURE="${STREAMFIND_SCIEX_WIFF_FIXTURE}"
    )
    add_test(NAME streamfind_mass_spec_sciex_reader_tests COMMAND streamfind_mass_spec_sciex_reader_tests)
endif()

set(STREAMFIND_SCIEX_MULTI_WIFF_FIXTURE "" CACHE FILEPATH "Path to a multi-experiment Sciex WIFF fixture")
if(STREAMFIND_SCIEX_MULTI_WIFF_FIXTURE AND EXISTS "${STREAMFIND_SCIEX_MULTI_WIFF_FIXTURE}")
    add_executable(streamfind_mass_spec_sciex_multi_reader_tests mass_spec/tests/reader_sciex_multi_smoke.cpp)
    target_link_libraries(streamfind_mass_spec_sciex_multi_reader_tests PRIVATE streamfind_mass_spec)
    target_compile_definitions(streamfind_mass_spec_sciex_multi_reader_tests PRIVATE
        STREAMFIND_SCIEX_WIFF_FIXTURE="${STREAMFIND_SCIEX_MULTI_WIFF_FIXTURE}"
    )
    add_test(NAME streamfind_mass_spec_sciex_multi_reader_tests COMMAND streamfind_mass_spec_sciex_multi_reader_tests)
endif()

set(STREAMFIND_SCIEX_NITRO_WIFF_FIXTURE "" CACHE FILEPATH "Path to a sparse-tagged Sciex WIFF fixture")
if(STREAMFIND_SCIEX_NITRO_WIFF_FIXTURE AND EXISTS "${STREAMFIND_SCIEX_NITRO_WIFF_FIXTURE}")
    add_executable(streamfind_mass_spec_sciex_nitro_reader_tests mass_spec/tests/reader_sciex_nitro_smoke.cpp)
    target_link_libraries(streamfind_mass_spec_sciex_nitro_reader_tests PRIVATE streamfind_mass_spec)
    target_compile_definitions(streamfind_mass_spec_sciex_nitro_reader_tests PRIVATE
        STREAMFIND_SCIEX_WIFF_FIXTURE="${STREAMFIND_SCIEX_NITRO_WIFF_FIXTURE}"
    )
    add_test(NAME streamfind_mass_spec_sciex_nitro_reader_tests COMMAND streamfind_mass_spec_sciex_nitro_reader_tests)
endif()

add_subdirectory(raman)
add_subdirectory(sensors)
