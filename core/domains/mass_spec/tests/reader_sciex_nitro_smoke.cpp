#include <iostream>
#include "streamfind/mass_spec/reader.hpp"
#include "streamfind/mass_spec/reader_sciex.hpp"
#ifndef STREAMFIND_SCIEX_WIFF_FIXTURE
#error STREAMFIND_SCIEX_WIFF_FIXTURE is required
#endif
int main() {
    try {
        mass_spec::reader::MASS_SPEC_FILE reader(STREAMFIND_SCIEX_WIFF_FIXTURE);
        if (reader.get_format() != "SciexWIFF") return 1;
        if (reader.get_number_chromatograms() <= 2) return 2;
        const auto headers = reader.get_chromatograms_headers();
        if (headers.size() != static_cast<std::size_t>(reader.get_number_chromatograms()) || headers.chromatogram_id[0] != "TIC" || headers.chromatogram_id[1] != "BPC") return 3;
        const auto arrays = reader.get_chromatograms();
        if (arrays.size() != static_cast<std::size_t>(reader.get_number_chromatograms())) return 4;
        for (const auto &array : arrays)
            if (array.size() != 2 || array[0].size() != array[1].size()) return 5;
        const auto sample_nine = mass_spec::reader::sciex::read_sparse_tagged_mrm_series(STREAMFIND_SCIEX_WIFF_FIXTURE, 9, -33.01f, 33);
        if (sample_nine.intensities.size() != 33 || sample_nine.intensities[0].size() != 3366) return 6;
        reader.select_analysis(8);
        if (reader.get_number_chromatograms() != 35) { std::cerr << "selected=" << reader.get_number_chromatograms() << std::endl; return 7; }
        const auto selected_arrays = reader.get_chromatograms();
        if (selected_arrays.size() != 35 || selected_arrays[2][0].size() != 3366) return 8;
        return 0;
    } catch (const std::exception &error) { std::cerr << error.what() << std::endl; return 6; }
}
