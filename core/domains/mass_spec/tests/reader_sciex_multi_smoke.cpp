#include <iostream>
#include <stdexcept>
#include "streamfind/mass_spec/reader.hpp"

#ifndef STREAMFIND_SCIEX_WIFF_FIXTURE
#error STREAMFIND_SCIEX_WIFF_FIXTURE is required
#endif

int main() {
    try {
        mass_spec::reader::MASS_SPEC_FILE reader(STREAMFIND_SCIEX_WIFF_FIXTURE);
        if (reader.get_format() != "SciexWIFF") return 1;
        if (reader.get_number_chromatograms() != 16) return 2;
        const auto headers = reader.get_chromatograms_headers();
        if (headers.size() != 16 || headers.chromatogram_id.size() != 16 || headers.chromatogram_id[0] != "TIC" || headers.chromatogram_id[1] != "BPC") return 3;
        const auto arrays = reader.get_chromatograms();
        if (arrays.size() != 16) return 4;
        if (arrays[0][0].size() != 1700 || arrays[0][1].size() != 1700) return 5;
        if (arrays[2][0].size() != 800 || arrays[12][0].size() != 900) return 6;
        for (const auto &array : arrays)
            if (array.size() != 2 || array[0].size() != array[1].size()) return 7;
        return 0;
    } catch (const std::exception &error) {
        std::cerr << error.what() << "\n";
        return 8;
    }
}
