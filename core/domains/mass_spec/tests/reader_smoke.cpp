#include <cassert>
#include <iostream>

#include "streamfind/mass_spec/reader.hpp"

#ifndef STREAMFIND_MZML_FIXTURE
#error STREAMFIND_MZML_FIXTURE is required
#endif

int main() {
    try {
        mass_spec::reader::MASS_SPEC_FILE reader(STREAMFIND_MZML_FIXTURE);
        std::cout << reader.get_format() << " " << reader.get_number_spectra() << "\n";
        if (reader.get_format() != "mzML" || reader.get_number_spectra() == 0) return 1;
        const auto &catalog = reader.get_analysis_catalog();
        if (catalog.size() != 1 || catalog[0].analysis_index != 0 || catalog[0].analysis_count != 1) return 2;
        reader.select_analysis(0);
        if (reader.selected_analysis_index() != 0) return 3;
        try {
            reader.select_analysis(1);
            return 4;
        } catch (const std::out_of_range &) {
        }
    } catch (const std::exception &error) {
        std::cerr << error.what() << "\n";
        return 1;
    }
}
