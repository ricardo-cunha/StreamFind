#include <cmath>
#include <iostream>

#include "streamfind/mass_spec/reader.hpp"

#ifndef STREAMFIND_AGILENT_POS_D_FIXTURE
#error STREAMFIND_AGILENT_POS_D_FIXTURE is required
#endif
#ifndef STREAMFIND_AGILENT_NEG_D_FIXTURE
#error STREAMFIND_AGILENT_NEG_D_FIXTURE is required
#endif

int main()
{
  try
  {
    for (const auto &item : {std::pair{STREAMFIND_AGILENT_POS_D_FIXTURE, 1},
                             std::pair{STREAMFIND_AGILENT_NEG_D_FIXTURE, -1}})
    {
      mass_spec::reader::MASS_SPEC_FILE file(item.first);
      const auto headers = file.get_spectra_headers({0});
      if (headers.size() != 1 || headers.polarity[0] != item.second)
        return 1;
      const auto spectrum = file.get_spectrum(0);
      if (spectrum.polarity != item.second)
        return 2;
      if (item.second == 1)
      {
        const auto dda = file.get_spectra_headers({26});
        if (dda.size() != 1 || dda.level[0] != 2 || std::fabs(dda.precursor_mz[0] - 237.0522f) > 0.001f || std::fabs(dda.precursor_intensity[0] - 528.0f) > 0.001f || std::fabs(dda.activation_ce[0] - 10.0f) > 0.001f)
          return 4;
      }
    }
    return 0;
  }
  catch (const std::exception &error)
  {
    std::cerr << error.what() << '\n';
    return 3;
  }
}
