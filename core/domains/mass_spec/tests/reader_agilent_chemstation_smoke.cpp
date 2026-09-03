#include "streamfind/mass_spec/reader.hpp"
#include "streamfind/mass_spec/reader_agilent_chemstation.hpp"

#include <algorithm>
#include <cmath>
#include <iostream>
#include <cstdlib>
#include <filesystem>

int main()
{
  try
  {
    const char *fixture = std::getenv("STREAMFIND_AGILENT_CHEMSTATION_MS_FIXTURE");
    if (fixture == nullptr || *fixture == '\0')
      return 11;
    const std::string path = fixture;
    const auto data = mass_spec::reader::agilent_chemstation::read_data_file(path);

    if (data.record_count != 672 || data.index.size() != 672 || data.retention_time_start_ms != 4602 || data.retention_time_end_ms != 418140)
      return 1;
    const auto first = mass_spec::reader::agilent_chemstation::read_spectrum(data, 0);

    if (first.mz.size() != 20 || first.intensity.size() != 20 || first.retention_time_ms != 4602)
      return 2;
    if (std::fabs(first.mz.front() - 120.1f) > 1e-6f || first.intensity.front() != 3091.0f)
      return 3;
    auto public_file = mass_spec::reader::MASS_SPEC_FILE(std::filesystem::path(path).parent_path().string());
    if (public_file.get_format() != "AgilentChemStationD" || public_file.get_number_spectra() != 672 ||
        public_file.get_number_chromatograms() != 1)
      return 4;
    const auto headers = public_file.get_spectra_headers({0});
    if (headers.size() != 1 || headers.scan[0] != 1 || headers.array_length[0] != 20)
      return 5;
    const auto public_spectrum = public_file.get_spectrum(0);
    if (public_spectrum.binary_arrays_count != 2 || public_spectrum.binary_data[0].size() != 20 || public_spectrum.binary_data[1][0] != 3091.0f)
      return 6;
    const auto chromatogram_headers = public_file.get_chromatograms_headers();

    if (chromatogram_headers.size() != 1 || chromatogram_headers.array_length[0] != 33601 ||
        std::fabs(chromatogram_headers.wavelength_nm[0] - 192.0f) > 1e-6f ||
        chromatogram_headers.units[0] != "mAU")
      return 7;
    const auto chromatograms = public_file.get_chromatograms({0});

    if (chromatograms.size() != 1 || chromatograms[0].size() != 2 || chromatograms[0][0].size() != 33601 ||
        std::fabs(chromatograms[0][0][0] - 0.0001f) > 1e-7f ||
        std::fabs(chromatograms[0][1][0] - 5.5530071f) > 1e-5f)
      return 8;
    return 0;
  }
  catch (const std::exception &error)
  {
    std::cerr << error.what() << std::endl;
    return 10;
  }
}
