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
    } catch (const std::exception &error) {
        std::cerr << error.what() << "\n";
        return 1;
    }
}
