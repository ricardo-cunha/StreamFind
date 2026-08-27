#include "streamfind/mass_spec/reader_agilent.hpp"

#include <algorithm>
#include <cmath>
#include <iostream>

#ifndef STREAMFIND_AGILENT_D_FIXTURE
#error STREAMFIND_AGILENT_D_FIXTURE is required
#endif

int main()
{
  try
  {
    if (!mass_spec::reader::agilent::is_agilent_mass_hunter_directory(STREAMFIND_AGILENT_D_FIXTURE))
      return 1;
    const auto records = mass_spec::reader::agilent::read_scan_records(STREAMFIND_AGILENT_D_FIXTURE);
    if (records.size() != 7870)
      return 2;
    if (records.front().scan_id != 182612 || records[1].scan_id != 182812)
      return 3;
    if (std::fabs(records.front().scan_time_minutes - 3.0434) > 1e-9 ||
        std::fabs(records[1].scan_time_minutes - 3.04673333333333) > 1e-9)
      return 4;
    if (records.front().ms_level != 1 || records.front().tic != 29486.0 ||
        std::fabs(records.front().base_peak_mz - 959.961571698238) > 1e-9 ||
        records.front().base_peak_value != 302.0)
      return 5;
    if (records.front().spectrum_format_id != 1 || records.front().spectrum_offset != 68 ||
        records.front().spectrum_byte_count != 18814 ||
        records.front().spectrum_point_count != 165344 ||
        records.front().spectrum_uncompressed_byte_count != 661392 ||
        std::fabs(records.front().spectrum_min_x - 50.00131445032414) > 1e-9 ||
        std::fabs(records.front().spectrum_max_x - 1199.3268123619305) > 1e-9)
      return 6;
    const auto profile = mass_spec::reader::agilent::read_profile_spectrum(STREAMFIND_AGILENT_D_FIXTURE, records.front());
    if (profile.mz.size() != 165344 || profile.intensity.size() != profile.mz.size() ||
        std::fabs(profile.mz.front() - 50.00131445032414f) > 1e-5f ||
        std::fabs(profile.mz.back() - 1199.3268123619305f) > 1e-4f)
      return 7;
    float sum = 0.0f, maximum = 0.0f;
    for (const auto value : profile.intensity) { sum += value; maximum = std::max(maximum, value); }
    if (sum != 29486.0f || maximum != 302.0f)
      return 8;
    for (const auto index : {0u, 1u, 2u})
    {
      const auto check = mass_spec::reader::agilent::read_profile_spectrum(STREAMFIND_AGILENT_D_FIXTURE, records[index]);
      double check_sum = 0.0;
      float check_maximum = 0.0f;
      for (const auto value : check.intensity) { check_sum += value; check_maximum = std::max(check_maximum, value); }
      if (std::fabs(check_sum - records[index].tic) > 0.5 || std::fabs(check_maximum - records[index].base_peak_value) > 0.5f)
        return 9;
    }
    const auto reader = mass_spec::reader::agilent::create_reader(STREAMFIND_AGILENT_D_FIXTURE);
    if (reader->get_number_spectra() != 7870 || reader->get_type() != "MS")
      return 10;
    const auto headers = reader->get_spectra_headers({0});
    if (headers.size() != 1 || headers.scan[0] != 182612 || headers.array_length[0] != 165344)
      return 11;
    const auto spectrum = reader->get_spectrum(0);
    if (spectrum.binary_data.size() != 2 || spectrum.binary_data[0].size() != 165344 ||
        spectrum.binary_data[1].size() != 165344)
      return 12;
    mass_spec::reader::MASS_SPEC_FILE file(STREAMFIND_AGILENT_D_FIXTURE);
    if (file.get_format() != "AgilentMassHunterD" || file.get_number_spectra() != 7870 ||
        file.get_spectra_headers({0}).scan[0] != 182612)
      return 13;
    if (file.get_spectrum(0).binary_data[1].size() != 165344)
      return 14;
    return 0;
  }
  catch (const std::exception &error)
  {
    std::cerr << error.what() << '\n';
    return 6;
  }
}
