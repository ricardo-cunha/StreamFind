#include <cmath>
#include <iostream>
#include <stdexcept>

#include "streamfind/mass_spec/reader.hpp"

#ifndef STREAMFIND_SCIEX_WIFF_FIXTURE
#error STREAMFIND_SCIEX_WIFF_FIXTURE is required
#endif

int main()
{
  try
  {
    mass_spec::reader::MASS_SPEC_FILE reader(STREAMFIND_SCIEX_WIFF_FIXTURE);
    reader.select_analysis(3);
    const auto headers = reader.get_chromatograms_headers();
    if (headers.size() != 61 || headers.array_length[0] != -1 || headers.array_length[40] != -1) return 1;
    const auto chromatograms = reader.get_chromatograms({40, 41});
    if (chromatograms.size() != 2) return 1;
    if (chromatograms[0][1].size() != 392 || chromatograms[1][1].size() != 392) return 2;
    if (std::fabs(chromatograms[0][0][0] - 0.7085667f) > 0.00001f) return 3;
    if (chromatograms[0][1][0] != 10074.0f || chromatograms[1][1][0] != 699.0f) return 4;
    return 0;
  }
  catch (const std::exception &error)
  {
    std::cerr << error.what() << "\n";
    return 5;
  }
}
