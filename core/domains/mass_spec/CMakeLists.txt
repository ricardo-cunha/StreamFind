add_library(streamfind_mass_spec STATIC
    src/register.cpp
    src/reader.cpp
    src/mass_spec.cpp
    src/processing_methods_chromatograms.cpp
    "${CMAKE_CURRENT_SOURCE_DIR}/../../vendor/simdutf/simdutf.cpp"
)
target_include_directories(streamfind_mass_spec PUBLIC include)
target_link_libraries(streamfind_mass_spec PUBLIC streamfind::core)
target_include_directories(streamfind_mass_spec PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/../../vendor/pugixml-1.14/src"
    "${CMAKE_CURRENT_SOURCE_DIR}/../../vendor/simdutf"
)
