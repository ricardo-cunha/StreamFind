#include "streamfind/mass_spec/reader_agilent_chemstation.hpp"

#include <cmath>
#include <cstdlib>
#include <filesystem>
#include <iostream>

int main()
{
  try
  {
    const char *fixture = std::getenv("STREAMFIND_AGILENT_UV_FIXTURE");
    if (fixture == nullptr || *fixture == '\0')
      return 11;
    const auto chromatograms = mass_spec::reader::agilent_chemstation::read_chromatograms(
        std::filesystem::path(fixture).parent_path().string());
    std::vector<const mass_spec::reader::agilent_chemstation::Chromatogram *> uv;
    for (const auto &chromatogram : chromatograms)
      if (chromatogram.channel == "DAD1.UV")
        uv.push_back(&chromatogram);
    if (uv.size() != 106)
      return 1;
    if (uv.front()->time_minutes.size() != 12003 ||
        std::fabs(uv.front()->wavelength_nm - 190.0f) > 1e-6f ||
        std::fabs(uv.front()->time_minutes.front() - 0.0002f) > 1e-7f ||
        std::fabs(uv.front()->time_minutes.back() - 10.0018667f) > 1e-6f ||
        std::fabs(uv.front()->intensity.front() - (-4.0359497f)) > 1e-5f)
      return 2;
    if (std::fabs(uv[1]->wavelength_nm - 192.0f) > 1e-6f ||
        std::fabs(uv[1]->intensity.front() - (-32.4840546f)) > 1e-5f)
      return 3;
    mass_spec::reader::MASS_SPEC_FILE public_file(std::filesystem::path(fixture).parent_path().string());
    if (public_file.get_format() != "AgilentChemStationD" || public_file.get_number_spectra() != 0 ||
        public_file.get_number_chromatograms() != 110 ||
        public_file.get_chromatograms({0})[0].size() != 2)
      return 4;
    return 0;
  }
  catch (const std::exception &error)
  {
    std::cerr << error.what() << '\n';
    return 10;
  }
}
