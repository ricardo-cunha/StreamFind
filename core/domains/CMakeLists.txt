set(STREAMFIND_TEST_DATA_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../tests/data" CACHE PATH "Path to StreamFind test data")

add_subdirectory(mass_spec)

add_executable(streamfind_mass_spec_reader_tests mass_spec/tests/reader_smoke.cpp)
target_link_libraries(streamfind_mass_spec_reader_tests PRIVATE streamfind_mass_spec)
target_compile_definitions(streamfind_mass_spec_reader_tests PRIVATE
    STREAMFIND_MZML_FIXTURE="${STREAMFIND_TEST_DATA_ROOT}/mass_spec/wastewater/03_tof_ww_is_pos_o3sw_effluent-r001.mzML"
)
add_test(NAME streamfind_mass_spec_reader_tests COMMAND streamfind_mass_spec_reader_tests)
set_tests_properties(streamfind_mass_spec_reader_tests PROPERTIES LABELS "reader-interface")

add_executable(streamfind_mass_spec_bruker_tsf_reader_tests mass_spec/tests/reader_bruker_tsf_smoke.cpp)
target_link_libraries(streamfind_mass_spec_bruker_tsf_reader_tests PRIVATE streamfind_mass_spec)
add_test(NAME streamfind_mass_spec_bruker_tsf_reader_tests COMMAND streamfind_mass_spec_bruker_tsf_reader_tests)
set_tests_properties(streamfind_mass_spec_bruker_tsf_reader_tests PROPERTIES LABELS "reader-interface")

add_executable(streamfind_mass_spec_bruker_baf_reader_tests mass_spec/tests/reader_bruker_baf_smoke.cpp)
target_link_libraries(streamfind_mass_spec_bruker_baf_reader_tests PRIVATE streamfind_mass_spec)
add_test(NAME streamfind_mass_spec_bruker_baf_reader_tests COMMAND streamfind_mass_spec_bruker_baf_reader_tests)
set_tests_properties(streamfind_mass_spec_bruker_baf_reader_tests PROPERTIES LABELS "reader-interface")

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
    set_tests_properties(streamfind_mass_spec_sciex_reader_tests PROPERTIES LABELS "reader-interface")
endif()

set(STREAMFIND_AGILENT_D_FIXTURE "" CACHE PATH "Path to an Agilent MassHunter .d directory")
if(STREAMFIND_AGILENT_D_FIXTURE AND EXISTS "${STREAMFIND_AGILENT_D_FIXTURE}")
    add_executable(streamfind_mass_spec_agilent_reader_tests mass_spec/tests/reader_agilent_smoke.cpp)
    target_link_libraries(streamfind_mass_spec_agilent_reader_tests PRIVATE streamfind_mass_spec)
    target_compile_definitions(streamfind_mass_spec_agilent_reader_tests PRIVATE
        STREAMFIND_AGILENT_D_FIXTURE="${STREAMFIND_AGILENT_D_FIXTURE}"
    )
    add_test(NAME streamfind_mass_spec_agilent_reader_tests COMMAND streamfind_mass_spec_agilent_reader_tests)
    set_tests_properties(streamfind_mass_spec_agilent_reader_tests PROPERTIES LABELS "reader-interface")
endif()

set(STREAMFIND_AGILENT_CHEMSTATION_MS_FIXTURE "" CACHE FILEPATH "Path to an Agilent ChemStation MSD1.MS file")
if(STREAMFIND_AGILENT_CHEMSTATION_MS_FIXTURE AND EXISTS "${STREAMFIND_AGILENT_CHEMSTATION_MS_FIXTURE}")
    add_executable(streamfind_mass_spec_agilent_chemstation_reader_tests mass_spec/tests/reader_agilent_chemstation_smoke.cpp)
    target_link_libraries(streamfind_mass_spec_agilent_chemstation_reader_tests PRIVATE streamfind_mass_spec)
    add_test(NAME streamfind_mass_spec_agilent_chemstation_reader_tests COMMAND streamfind_mass_spec_agilent_chemstation_reader_tests)
    set_tests_properties(streamfind_mass_spec_agilent_chemstation_reader_tests PROPERTIES LABELS "reader-interface")
    set_tests_properties(streamfind_mass_spec_agilent_chemstation_reader_tests PROPERTIES
        ENVIRONMENT "STREAMFIND_AGILENT_CHEMSTATION_MS_FIXTURE=${STREAMFIND_AGILENT_CHEMSTATION_MS_FIXTURE}"
    )
    if(WIN32)
        add_custom_command(TARGET streamfind_mass_spec_agilent_chemstation_reader_tests POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "$<TARGET_FILE:streamfind::duckdb>"
                "$<TARGET_FILE_DIR:streamfind_mass_spec_agilent_chemstation_reader_tests>"
        )
    endif()
endif()

set(STREAMFIND_AGILENT_WIDE_FIXTURE "" CACHE PATH "Path to a wider-range Agilent MassHunter .d directory")
if(STREAMFIND_AGILENT_WIDE_FIXTURE AND EXISTS "${STREAMFIND_AGILENT_WIDE_FIXTURE}")
    add_executable(streamfind_mass_spec_agilent_wide_reader_tests mass_spec/tests/reader_agilent_wide_smoke.cpp)
    target_link_libraries(streamfind_mass_spec_agilent_wide_reader_tests PRIVATE streamfind_mass_spec)
    add_test(NAME streamfind_mass_spec_agilent_wide_reader_tests COMMAND streamfind_mass_spec_agilent_wide_reader_tests)
    set_tests_properties(streamfind_mass_spec_agilent_wide_reader_tests PROPERTIES LABELS "reader-interface")
    set_tests_properties(streamfind_mass_spec_agilent_wide_reader_tests PROPERTIES
        ENVIRONMENT "STREAMFIND_AGILENT_WIDE_FIXTURE=${STREAMFIND_AGILENT_WIDE_FIXTURE}"
    )
    if(WIN32)
        add_custom_command(TARGET streamfind_mass_spec_agilent_wide_reader_tests POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "$<TARGET_FILE:streamfind::duckdb>"
                "$<TARGET_FILE_DIR:streamfind_mass_spec_agilent_wide_reader_tests>"
        )
    endif()
endif()

set(STREAMFIND_AGILENT_IMS_FIXTURE "" CACHE PATH "Path to a MassHunter ion-mobility .d directory")
if(STREAMFIND_AGILENT_IMS_FIXTURE AND EXISTS "${STREAMFIND_AGILENT_IMS_FIXTURE}")
    add_executable(streamfind_mass_spec_agilent_ims_reader_tests mass_spec/tests/reader_agilent_ims_smoke.cpp)
    target_link_libraries(streamfind_mass_spec_agilent_ims_reader_tests PRIVATE streamfind_mass_spec)
    add_test(NAME streamfind_mass_spec_agilent_ims_reader_tests COMMAND streamfind_mass_spec_agilent_ims_reader_tests)
    set_tests_properties(streamfind_mass_spec_agilent_ims_reader_tests PROPERTIES LABELS "reader-interface")
    set_tests_properties(streamfind_mass_spec_agilent_ims_reader_tests PROPERTIES
        ENVIRONMENT "STREAMFIND_AGILENT_IMS_FIXTURE=${STREAMFIND_AGILENT_IMS_FIXTURE}"
    )
    if(WIN32)
        add_custom_command(TARGET streamfind_mass_spec_agilent_ims_reader_tests POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "$<TARGET_FILE:streamfind::duckdb>"
                "$<TARGET_FILE_DIR:streamfind_mass_spec_agilent_ims_reader_tests>"
        )
    endif()
endif()

if(STREAMFIND_AGILENT_IMS_FIXTURE AND EXISTS "${STREAMFIND_AGILENT_IMS_FIXTURE}")
    add_executable(streamfind_mass_spec_agilent_ims_public_reader_tests mass_spec/tests/reader_agilent_ims_public_smoke.cpp)
    target_link_libraries(streamfind_mass_spec_agilent_ims_public_reader_tests PRIVATE streamfind_mass_spec)
    add_test(NAME streamfind_mass_spec_agilent_ims_public_reader_tests COMMAND streamfind_mass_spec_agilent_ims_public_reader_tests)
    set_tests_properties(streamfind_mass_spec_agilent_ims_public_reader_tests PROPERTIES LABELS "reader-interface")
    set_tests_properties(streamfind_mass_spec_agilent_ims_public_reader_tests PROPERTIES
        ENVIRONMENT "STREAMFIND_AGILENT_IMS_FIXTURE=${STREAMFIND_AGILENT_IMS_FIXTURE}"
    )
    if(WIN32)
        add_custom_command(TARGET streamfind_mass_spec_agilent_ims_public_reader_tests POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "$<TARGET_FILE:streamfind::duckdb>"
                "$<TARGET_FILE_DIR:streamfind_mass_spec_agilent_ims_public_reader_tests>"
        )
    endif()
endif()

set(STREAMFIND_AGILENT_PROJECT_MASS_HUNTER_FIXTURE "" CACHE FILEPATH "Path to an Agilent MassHunter .d project fixture")
set(STREAMFIND_AGILENT_PROJECT_CHEMSTATION_FIXTURE "" CACHE PATH "Path to an Agilent ChemStation .D project fixture")
if(STREAMFIND_AGILENT_PROJECT_MASS_HUNTER_FIXTURE AND EXISTS "${STREAMFIND_AGILENT_PROJECT_MASS_HUNTER_FIXTURE}" AND STREAMFIND_AGILENT_PROJECT_CHEMSTATION_FIXTURE AND EXISTS "${STREAMFIND_AGILENT_PROJECT_CHEMSTATION_FIXTURE}")
    add_executable(streamfind_mass_spec_agilent_project_parity_tests mass_spec/tests/agilent_project_parity.cpp)
    target_link_libraries(streamfind_mass_spec_agilent_project_parity_tests PRIVATE streamfind_mass_spec)
    target_compile_definitions(streamfind_mass_spec_agilent_project_parity_tests PRIVATE
        STREAMFIND_AGILENT_MASS_HUNTER_PROJECT_FIXTURE="${STREAMFIND_AGILENT_PROJECT_MASS_HUNTER_FIXTURE}"
        STREAMFIND_AGILENT_CHEMSTATION_PROJECT_FIXTURE="${STREAMFIND_AGILENT_PROJECT_CHEMSTATION_FIXTURE}"
    )
    add_test(NAME streamfind_mass_spec_agilent_project_parity_tests COMMAND streamfind_mass_spec_agilent_project_parity_tests)
    set_tests_properties(streamfind_mass_spec_agilent_project_parity_tests PROPERTIES LABELS "reader-interface")
endif()

set(STREAMFIND_MZML_PARITY_FIXTURE "" CACHE FILEPATH "Path to an mzML parity fixture")
set(STREAMFIND_MZXML_PARITY_FIXTURE "" CACHE FILEPATH "Path to an mzXML parity fixture")
if(STREAMFIND_MZML_PARITY_FIXTURE AND EXISTS "${STREAMFIND_MZML_PARITY_FIXTURE}" AND STREAMFIND_MZXML_PARITY_FIXTURE AND EXISTS "${STREAMFIND_MZXML_PARITY_FIXTURE}")
    add_executable(streamfind_mass_spec_mzml_mzxml_project_parity_tests mass_spec/tests/mzml_mzxml_project_parity.cpp)
    target_link_libraries(streamfind_mass_spec_mzml_mzxml_project_parity_tests PRIVATE streamfind_mass_spec)
    target_compile_definitions(streamfind_mass_spec_mzml_mzxml_project_parity_tests PRIVATE
        STREAMFIND_MZML_PARITY_FIXTURE="${STREAMFIND_MZML_PARITY_FIXTURE}"
        STREAMFIND_MZXML_PARITY_FIXTURE="${STREAMFIND_MZXML_PARITY_FIXTURE}"
    )
    add_test(NAME streamfind_mass_spec_mzml_mzxml_project_parity_tests COMMAND streamfind_mass_spec_mzml_mzxml_project_parity_tests)
    set_tests_properties(streamfind_mass_spec_mzml_mzxml_project_parity_tests PROPERTIES LABELS "reader-interface")
    if(WIN32)
        add_custom_command(TARGET streamfind_mass_spec_mzml_mzxml_project_parity_tests POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "$<TARGET_FILE:streamfind::duckdb>"
                "$<TARGET_FILE_DIR:streamfind_mass_spec_mzml_mzxml_project_parity_tests>"
        )
    endif()
endif()

set(STREAMFIND_AGILENT_UV_FIXTURE "" CACHE FILEPATH "Path to an Agilent ChemStation .UV file")
if(STREAMFIND_AGILENT_UV_FIXTURE AND EXISTS "${STREAMFIND_AGILENT_UV_FIXTURE}")
    add_executable(streamfind_mass_spec_agilent_uv_reader_tests mass_spec/tests/reader_agilent_uv_smoke.cpp)
    target_link_libraries(streamfind_mass_spec_agilent_uv_reader_tests PRIVATE streamfind_mass_spec)
    add_test(NAME streamfind_mass_spec_agilent_uv_reader_tests COMMAND streamfind_mass_spec_agilent_uv_reader_tests)
    set_tests_properties(streamfind_mass_spec_agilent_uv_reader_tests PROPERTIES LABELS "reader-interface")
    set_tests_properties(streamfind_mass_spec_agilent_uv_reader_tests PROPERTIES
        ENVIRONMENT "STREAMFIND_AGILENT_UV_FIXTURE=${STREAMFIND_AGILENT_UV_FIXTURE}"
    )
    if(WIN32)
        add_custom_command(TARGET streamfind_mass_spec_agilent_uv_reader_tests POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "$<TARGET_FILE:streamfind::duckdb>"
                "$<TARGET_FILE_DIR:streamfind_mass_spec_agilent_uv_reader_tests>"
        )
    endif()
endif()

set(STREAMFIND_SCIEX_MULTI_WIFF_FIXTURE "" CACHE FILEPATH "Path to a multi-experiment Sciex WIFF fixture")
if(STREAMFIND_SCIEX_MULTI_WIFF_FIXTURE AND EXISTS "${STREAMFIND_SCIEX_MULTI_WIFF_FIXTURE}")
    add_executable(streamfind_mass_spec_sciex_multi_reader_tests mass_spec/tests/reader_sciex_multi_smoke.cpp)
    target_link_libraries(streamfind_mass_spec_sciex_multi_reader_tests PRIVATE streamfind_mass_spec)
    target_compile_definitions(streamfind_mass_spec_sciex_multi_reader_tests PRIVATE
        STREAMFIND_SCIEX_WIFF_FIXTURE="${STREAMFIND_SCIEX_MULTI_WIFF_FIXTURE}"
    )
    add_test(NAME streamfind_mass_spec_sciex_multi_reader_tests COMMAND streamfind_mass_spec_sciex_multi_reader_tests)
    set_tests_properties(streamfind_mass_spec_sciex_multi_reader_tests PROPERTIES LABELS "reader-interface")
endif()

set(STREAMFIND_SCIEX_NITRO_WIFF_FIXTURE "" CACHE FILEPATH "Path to a sparse-tagged Sciex WIFF fixture")
if(STREAMFIND_SCIEX_NITRO_WIFF_FIXTURE AND EXISTS "${STREAMFIND_SCIEX_NITRO_WIFF_FIXTURE}")
    add_executable(streamfind_mass_spec_sciex_nitro_reader_tests mass_spec/tests/reader_sciex_nitro_smoke.cpp)
    target_link_libraries(streamfind_mass_spec_sciex_nitro_reader_tests PRIVATE streamfind_mass_spec)
    target_compile_definitions(streamfind_mass_spec_sciex_nitro_reader_tests PRIVATE
        STREAMFIND_SCIEX_WIFF_FIXTURE="${STREAMFIND_SCIEX_NITRO_WIFF_FIXTURE}"
    )
    add_test(NAME streamfind_mass_spec_sciex_nitro_reader_tests COMMAND streamfind_mass_spec_sciex_nitro_reader_tests)
    set_tests_properties(streamfind_mass_spec_sciex_nitro_reader_tests PROPERTIES LABELS "reader-interface")
endif()

set(STREAMFIND_SCIEX_MIX1_HOLDOUT_WIFF_FIXTURE "" CACHE FILEPATH "Path to a holdout SCIEX Mix1 WIFF fixture")
if(STREAMFIND_SCIEX_MIX1_HOLDOUT_WIFF_FIXTURE AND EXISTS "${STREAMFIND_SCIEX_MIX1_HOLDOUT_WIFF_FIXTURE}")
    add_executable(streamfind_mass_spec_sciex_mix1_holdout_reader_tests mass_spec/tests/reader_sciex_mix1_holdout_smoke.cpp)
    target_link_libraries(streamfind_mass_spec_sciex_mix1_holdout_reader_tests PRIVATE streamfind_mass_spec)
    target_compile_definitions(streamfind_mass_spec_sciex_mix1_holdout_reader_tests PRIVATE
        STREAMFIND_SCIEX_WIFF_FIXTURE="${STREAMFIND_SCIEX_MIX1_HOLDOUT_WIFF_FIXTURE}"
    )
    add_test(NAME streamfind_mass_spec_sciex_mix1_holdout_reader_tests COMMAND streamfind_mass_spec_sciex_mix1_holdout_reader_tests)
    set_tests_properties(streamfind_mass_spec_sciex_mix1_holdout_reader_tests PROPERTIES LABELS "reader-interface")
endif()

set(STREAMFIND_SCIEX_TOF_WIFF_FIXTURE "" CACHE FILEPATH "Path to a SCIEX TOF WIFF fixture")
if(STREAMFIND_SCIEX_TOF_WIFF_FIXTURE AND EXISTS "${STREAMFIND_SCIEX_TOF_WIFF_FIXTURE}")
    add_executable(streamfind_mass_spec_sciex_tof_reader_tests mass_spec/tests/reader_sciex_tof_smoke.cpp)
    target_link_libraries(streamfind_mass_spec_sciex_tof_reader_tests PRIVATE streamfind_mass_spec)
    target_compile_definitions(streamfind_mass_spec_sciex_tof_reader_tests PRIVATE
        STREAMFIND_SCIEX_WIFF_FIXTURE="${STREAMFIND_SCIEX_TOF_WIFF_FIXTURE}"
    )
    add_test(NAME streamfind_mass_spec_sciex_tof_reader_tests COMMAND streamfind_mass_spec_sciex_tof_reader_tests)
    set_tests_properties(streamfind_mass_spec_sciex_tof_reader_tests PROPERTIES LABELS "reader-interface")
endif()

add_subdirectory(raman)
add_subdirectory(sensors)
