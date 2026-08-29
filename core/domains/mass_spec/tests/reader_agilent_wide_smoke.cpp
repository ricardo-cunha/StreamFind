#include "streamfind/mass_spec/reader_agilent.hpp"
#include "streamfind/mass_spec/reader.hpp"

#include <cmath>
#include <iostream>
#include <numeric>

int main()
{
  try
  {
    const char *fixture = std::getenv("STREAMFIND_AGILENT_WIDE_FIXTURE");
    if (fixture == nullptr || *fixture == '\0')
      return 11;
    const auto records = mass_spec::reader::agilent::read_scan_records(fixture);
    if (records.size() != 677)
      return 1;
    const auto &first = records.front();
    if (first.scan_id != 123482 || first.ms_level != 1 || std::fabs(first.scan_time_minutes - 2.0579) > 1e-9 ||
        first.spectrum_format_id != 1 || first.spectrum_offset != 68 || first.spectrum_byte_count != 58607 ||
        first.spectrum_point_count != 449536 || first.spectrum_uncompressed_byte_count != 1798160 ||
        std::fabs(first.spectrum_min_x - 499.993809519737) > 1e-9 ||
        std::fabs(first.spectrum_max_x - 5000.0125717940045) > 1e-9)
      return 2;
    if (first.centroid_format_id != 2 || first.centroid_offset != 68 ||
        first.centroid_byte_count != 564 || first.centroid_point_count != 47)
      return 5;
    const auto centroid = mass_spec::reader::agilent::read_centroid_spectrum(fixture, first);

    if (centroid.mz.size() != 47 || centroid.intensity.size() != 47 ||
        std::fabs(centroid.mz.front() - 517.379673f) > 1e-3f || centroid.intensity.front() != 285.0f)
      return 6;
    const auto profile = mass_spec::reader::agilent::read_profile_spectrum(fixture, first);
    if (profile.mz.size() != 449536 || profile.intensity.size() != profile.mz.size() ||
        std::fabs(profile.mz.front() - 499.9938f) > 1e-3f || std::fabs(profile.mz.back() - 5000.0127f) > 1e-3f)
      return 3;
    const auto maximum = *std::max_element(profile.intensity.begin(), profile.intensity.end());
    const auto sum = std::accumulate(profile.intensity.begin(), profile.intensity.end(), 0.0f);
    if (maximum != 8615.0f || std::fabs(sum - 464469.0f) > 0.5f)
      return 4;
    const auto public_reader = mass_spec::reader::agilent::create_reader(fixture);
    if (public_reader->get_spectra_headers({0}).array_length[0] != 47 ||
        public_reader->get_spectrum(0).binary_data[0].size() != 47)
      return 7;
    mass_spec::reader::MASS_SPEC_FILE public_file(fixture);
    const auto chromatogram_headers = public_file.get_chromatograms_headers();


    if (chromatogram_headers.size() != 16 || chromatogram_headers.chromatogram_id.front() != "DAD1A" ||
        chromatogram_headers.units.front() != "mAU" || chromatogram_headers.array_length.front() != 1501)
      return 9;
    const auto chromatograms = public_file.get_chromatograms({0});
    if (chromatograms.size() != 1 || chromatograms[0].size() != 2 || chromatograms[0][0].size() != 1501 ||
        std::fabs(chromatograms[0][1][0] - 0.97894669f) > 1e-5f)
      return 10;
    if (public_file.get_spectra_array_length({0})[0] != 47 ||
        public_file.get_spectrum(0).binary_data[0].size() != 47)
      return 8;
    return 0;
  }
  catch (const std::exception &error)
  {
    std::cerr << error.what() << '\n';
    return 10;
  }
}
