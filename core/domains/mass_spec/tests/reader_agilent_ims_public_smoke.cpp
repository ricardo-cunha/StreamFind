#include "streamfind/mass_spec/reader.hpp"

#include <cmath>
#include <cstdlib>
#include <iostream>

int main()
{
  const char *fixture = std::getenv("STREAMFIND_AGILENT_IMS_FIXTURE");
  if (!fixture)
    return 0;
  try
  {
    mass_spec::reader::MASS_SPEC_FILE file(fixture);
    if (file.get_format() != "AgilentMassHunterD" || file.get_number_spectra() != 37801 ||
        file.get_number_chromatograms() != 15 || !file.has_ion_mobility())
      return 2;
    const auto headers = file.get_spectra_headers({0, 1});
    if (headers.mobility.size() != 2 || std::fabs(headers.mobility[0]) > 1e-6f ||
        std::fabs(headers.mobility[1] - 0.163904f) > 1e-6f)
      return 3;
    const auto spectrum = file.get_spectrum(1);
    if (spectrum.mobility < 0.163903f || spectrum.mobility > 0.163905f ||
        spectrum.binary_data.size() != 2 || spectrum.binary_data[0].size() != 179808 ||
        spectrum.binary_data[0].size() != spectrum.binary_data[1].size())
      return 4;
    std::cout << "spectra=" << file.get_number_spectra() << " points="
              << spectrum.binary_data[0].size() << " mobility=" << spectrum.mobility << '\n';
    return 0;
  }
  catch (const std::exception &error)
  {
    std::cerr << error.what() << '\n';
    return 5;
  }
}
