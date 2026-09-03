add_library(streamfind_mass_spec STATIC
    src/register.cpp
    src/reader.cpp
    src/reader_agilent.cpp
    src/reader_agilent_ims.cpp
    src/reader_agilent_chemstation.cpp
    src/reader_bruker.cpp
    src/reader_sciex.cpp
    src/mass_spec.cpp
    src/processing_methods_chromatograms.cpp
    src/processing_methods_nta.cpp
    src/nta_deconvolution.cpp
    src/nta.cpp
    src/nta_annotation.cpp
    src/nta_componentization.cpp
    src/nta_blank_subtraction.cpp
    src/nta_filters.cpp
    src/nta_gap_filling.cpp
    src/nta_alignment.cpp
    src/nta_suspect_screening.cpp
    src/nta_assign_transformation_products.cpp
    src/nta_metfrag_runner.cpp
    src/nta_correction_algorithms.cpp
    src/openbabel_adapter.cpp
    src/openbabel_c_api.cpp
    "${CMAKE_CURRENT_SOURCE_DIR}/../../vendor/simdutf/simdutf.cpp"
)
target_include_directories(streamfind_mass_spec PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)
target_link_libraries(streamfind_mass_spec PUBLIC streamfind::core streamfind::zstd)
target_include_directories(streamfind_mass_spec PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/../../vendor/pugixml-1.14/src"
    "${CMAKE_CURRENT_SOURCE_DIR}/../../vendor/simdutf"
    "${CMAKE_CURRENT_SOURCE_DIR}/../../vendor/openbabel/openbabel-3-2-0/include"
)
if(MSVC)
    target_compile_definitions(streamfind_mass_spec PRIVATE
        NOMINMAX
        strcasecmp=_stricmp
        strncasecmp=_strnicmp
    )
endif()