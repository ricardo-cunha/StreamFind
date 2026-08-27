#ifndef STREAMFIND_MASS_SPEC_READER_AGILENT_HPP
#define STREAMFIND_MASS_SPEC_READER_AGILENT_HPP

#include "streamfind/mass_spec/reader.hpp"

#include <cstdint>
#include <string>
#include <vector>

namespace mass_spec::reader::agilent
{
struct ScanRecord
{
  std::uint32_t scan_id = 0;
  std::uint32_t scan_method_id = 0;
  std::uint32_t time_segment_id = 0;
  double scan_time_minutes = 0.0;
  std::int32_t ms_level = 0;
  std::int32_t scan_type = 0;
  double tic = 0.0;
  double base_peak_mz = 0.0;
  double base_peak_value = 0.0;
  std::int32_t calibration_id = 0;
  std::int32_t cycle_number = 0;
  std::uint32_t spectrum_format_id = 0;
  std::uint64_t spectrum_offset = 0;
  std::uint32_t spectrum_byte_count = 0;
  std::uint32_t spectrum_point_count = 0;
  std::uint32_t spectrum_uncompressed_byte_count = 0;
  double spectrum_min_x = 0.0;
  double spectrum_max_x = 0.0;
  double spectrum_min_y = 0.0;
  double spectrum_max_y = 0.0;
  double spectrum_measured_noise = 0.0;
};

struct ProfileSpectrum
{
  std::vector<float> mz;
  std::vector<float> intensity;
};

bool is_agilent_mass_hunter_directory(const std::string &path);
std::vector<ScanRecord> read_scan_records(const std::string &path);
ProfileSpectrum read_profile_spectrum(const std::string &path, const ScanRecord &record);
std::unique_ptr<MASS_SPEC_READER> create_reader(const std::string &file);
}

#endif
