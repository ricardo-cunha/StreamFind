set(STREAMFIND_TEST_DATA_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../tests/data" CACHE PATH "Path to StreamFind test data")

add_subdirectory(mass_spec)

add_executable(streamfind_mass_spec_reader_tests mass_spec/tests/reader_smoke.cpp)
target_link_libraries(streamfind_mass_spec_reader_tests PRIVATE streamfind_mass_spec)
target_compile_definitions(streamfind_mass_spec_reader_tests PRIVATE
    STREAMFIND_MZML_FIXTURE="${STREAMFIND_TEST_DATA_ROOT}/mass_spec/wastewater/03_tof_ww_is_pos_o3sw_effluent-r001.mzML"
)
add_test(NAME streamfind_mass_spec_reader_tests COMMAND streamfind_mass_spec_reader_tests)
add_subdirectory(raman)
add_subdirectory(sensors)
