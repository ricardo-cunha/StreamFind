#include "streamfind/mass_spec/reader_agilent.hpp"

#include <algorithm>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iterator>
#include <limits>
#include <numeric>
#include <stdexcept>

namespace mass_spec::reader::agilent
{
namespace detail
{
constexpr std::size_t scan_preamble_size = 228;
constexpr std::size_t scan_record_size = 220;
constexpr std::size_t profile_block_preamble_size = 16;
constexpr std::size_t maximum_profile_uncompressed_size = 512 * 1024 * 1024;

std::vector<std::uint8_t> read_file(const std::filesystem::path &path)
{
  std::ifstream input(path, std::ios::binary);
  if (!input)
    throw std::runtime_error("Unable to open Agilent MassHunter file: " + path.string());
  return {std::istreambuf_iterator<char>(input), std::istreambuf_iterator<char>()};
}

std::uint32_t u32(const std::vector<std::uint8_t> &bytes, std::size_t offset)
{
  if (offset + 4 > bytes.size())
    throw std::runtime_error("Agilent binary record is truncated.");
  return static_cast<std::uint32_t>(bytes[offset]) |
         (static_cast<std::uint32_t>(bytes[offset + 1]) << 8) |
         (static_cast<std::uint32_t>(bytes[offset + 2]) << 16) |
         (static_cast<std::uint32_t>(bytes[offset + 3]) << 24);
}

std::uint64_t u64(const std::vector<std::uint8_t> &bytes, std::size_t offset)
{
  if (offset + 8 > bytes.size())
    throw std::runtime_error("Agilent binary 64-bit field is truncated.");
  std::uint64_t value = 0;
  std::memcpy(&value, bytes.data() + offset, sizeof(value));
  return value;
}

double f64(const std::vector<std::uint8_t> &bytes, std::size_t offset)
{
  if (offset + sizeof(double) > bytes.size())
    throw std::runtime_error("Agilent binary double field is truncated.");
  double value = 0.0;
  std::memcpy(&value, bytes.data() + offset, sizeof(value));
  return value;
}

std::vector<std::uint8_t> read_slice(const std::filesystem::path &path, std::uint64_t offset, std::size_t size)
{
  const auto file_size = std::filesystem::file_size(path);
  if (offset > file_size || size > file_size - offset)
    throw std::runtime_error("Agilent profile block is outside MSProfile.bin.");
  std::ifstream input(path, std::ios::binary);
  if (!input)
    throw std::runtime_error("Unable to open Agilent MSProfile.bin: " + path.string());
  input.seekg(static_cast<std::streamoff>(offset));
  std::vector<std::uint8_t> bytes(size);
  input.read(reinterpret_cast<char *>(bytes.data()), static_cast<std::streamsize>(bytes.size()));
  if (static_cast<std::size_t>(input.gcount()) != bytes.size())
    throw std::runtime_error("Agilent MSProfile.bin profile block is truncated.");
  return bytes;
}

std::vector<std::uint8_t> decompress_lzf(const std::vector<std::uint8_t> &input, std::size_t maximum_size)
{
  if (maximum_size > maximum_profile_uncompressed_size)
    throw std::runtime_error("Agilent LZF profile block exceeds the decompression safety limit.");
  std::vector<std::uint8_t> output(maximum_size);
  std::size_t in = 0, out = 0;
  while (in < input.size() && out < output.size())
  {
    std::size_t control = input[in++];
    if (control < 32)
    {
      const std::size_t length = control + 1;
      if (in + length > input.size() || out + length > output.size())
        throw std::runtime_error("Agilent LZF literal run is outside the profile block.");
      std::copy_n(input.begin() + static_cast<std::ptrdiff_t>(in), length,
                  output.begin() + static_cast<std::ptrdiff_t>(out));
      in += length;
      out += length;
      continue;
    }

    std::size_t length = control >> 5;
    if (out < ((control & 31) << 8) + 1)
      throw std::runtime_error("Agilent LZF back reference precedes profile output.");
    std::size_t reference = out - ((control & 31) << 8) - 1;
    if (length == 7)
    {
      if (in >= input.size())
        throw std::runtime_error("Agilent LZF profile block has a truncated length.");
      length += input[in++];
    }
    if (in >= input.size())
      throw std::runtime_error("Agilent LZF profile block has a truncated distance.");
    const auto distance = input[in++];
    if (reference < distance)
      throw std::runtime_error("Agilent LZF profile block has an invalid distance.");
    reference -= distance;
    length += 2;
    if (out + length > output.size())
      throw std::runtime_error("Agilent LZF match run exceeds profile output.");
    for (std::size_t index = 0; index < length; ++index)
      output[out++] = output[reference++];
  }
  output.resize(out);
  return output;
}
}

bool is_agilent_mass_hunter_directory(const std::string &path)
{
  const std::filesystem::path root(path);
  const auto acq = root / "AcqData";
  return std::filesystem::is_directory(root) &&
         std::filesystem::is_regular_file(acq / "Contents.xml") &&
         std::filesystem::is_regular_file(acq / "MSScan.bin") &&
         std::filesystem::is_regular_file(acq / "MSProfile.bin");
}

std::vector<ScanRecord> read_scan_records(const std::string &path)
{
  if (!is_agilent_mass_hunter_directory(path))
    throw std::runtime_error("Not an Agilent MassHunter .d directory: " + path);
  const auto bytes = detail::read_file(std::filesystem::path(path) / "AcqData" / "MSScan.bin");
  if (bytes.size() < detail::scan_preamble_size ||
      (bytes.size() - detail::scan_preamble_size) % detail::scan_record_size != 0)
    throw std::runtime_error("Agilent MSScan.bin has an unsupported record layout.");

  std::vector<ScanRecord> records;
  records.reserve((bytes.size() - detail::scan_preamble_size) / detail::scan_record_size);
  for (std::size_t offset = detail::scan_preamble_size; offset < bytes.size(); offset += detail::scan_record_size)
  {
    ScanRecord record;
    record.scan_id = detail::u32(bytes, offset);
    record.scan_method_id = detail::u32(bytes, offset + 4);
    record.time_segment_id = detail::u32(bytes, offset + 8);
    record.scan_time_minutes = detail::f64(bytes, offset + 12);
    record.ms_level = static_cast<std::int32_t>(detail::u32(bytes, offset + 20));
    record.scan_type = static_cast<std::int32_t>(detail::u32(bytes, offset + 24));
    record.tic = detail::f64(bytes, offset + 28);
    record.base_peak_mz = detail::f64(bytes, offset + 36);
    record.base_peak_value = detail::f64(bytes, offset + 44);
    record.calibration_id = static_cast<std::int32_t>(detail::u32(bytes, offset + 52));
    record.cycle_number = static_cast<std::int32_t>(detail::u32(bytes, offset + 56));
    record.spectrum_format_id = detail::u32(bytes, offset + 156);
    record.spectrum_offset = detail::u64(bytes, offset + 160);
    record.spectrum_byte_count = detail::u32(bytes, offset + 168);
    record.spectrum_point_count = detail::u32(bytes, offset + 172);
    record.spectrum_uncompressed_byte_count = detail::u32(bytes, offset + 176);
    record.spectrum_min_x = detail::f64(bytes, offset + 180);
    record.spectrum_max_x = detail::f64(bytes, offset + 188);
    record.spectrum_min_y = detail::f64(bytes, offset + 196);
    record.spectrum_max_y = detail::f64(bytes, offset + 204);
    record.spectrum_measured_noise = detail::f64(bytes, offset + 212);
    records.push_back(record);
  }
  return records;
}

ProfileSpectrum read_profile_spectrum(const std::string &path, const ScanRecord &record)
{
  if (record.spectrum_format_id != 1)
    throw std::runtime_error("Agilent scan does not contain a SpectrumFormatID=1 profile block.");
  if (record.spectrum_byte_count < detail::profile_block_preamble_size)
    throw std::runtime_error("Agilent profile block is shorter than its preamble.");
  if (record.spectrum_point_count == 0)
    return {};
  const std::size_t point_bytes = static_cast<std::size_t>(record.spectrum_point_count) * sizeof(std::uint32_t);
  if (record.spectrum_uncompressed_byte_count < point_bytes)
    throw std::runtime_error("Agilent profile uncompressed byte count is smaller than its point array.");

  const auto block = detail::read_slice(std::filesystem::path(path) / "AcqData" / "MSProfile.bin",
                                        record.spectrum_offset, record.spectrum_byte_count);
  std::vector<std::uint8_t> decoded;
  try
  {
    decoded = detail::decompress_lzf(block, record.spectrum_uncompressed_byte_count);
  }
  catch (const std::exception &)
  {
    const std::vector<std::uint8_t> compressed(block.begin() + detail::profile_block_preamble_size, block.end());
    decoded = detail::decompress_lzf(compressed, record.spectrum_uncompressed_byte_count);
  }
  const std::size_t data_offset = decoded.size() == point_bytes ? 0 : detail::profile_block_preamble_size;
  if (data_offset > decoded.size() || decoded.size() - data_offset < point_bytes)
    throw std::runtime_error("Agilent LZF profile block is shorter than its declared point count.");

  ProfileSpectrum spectrum;
  spectrum.mz.reserve(record.spectrum_point_count);
  spectrum.intensity.reserve(record.spectrum_point_count);
  const double step = record.spectrum_point_count > 1
                          ? (record.spectrum_max_x - record.spectrum_min_x) / (record.spectrum_point_count - 1)
                          : 0.0;
  for (std::size_t index = 0; index < record.spectrum_point_count; ++index)
  {
    spectrum.mz.push_back(static_cast<float>(record.spectrum_min_x + index * step));
    spectrum.intensity.push_back(static_cast<float>(detail::u32(decoded, data_offset + index * 4)));
  }
  return spectrum;
}

class AgilentReader final : public MASS_SPEC_READER
{
public:
  explicit AgilentReader(const std::string &file) : MASS_SPEC_READER(file), records_(read_scan_records(file)) {}

  int get_number_spectra() override { return static_cast<int>(records_.size()); }
  int get_number_chromatograms() override { return 0; }
  int get_number_spectra_binary_arrays() override { return static_cast<int>(records_.size() * 2); }
  std::string get_format() override { return "AgilentMassHunterD"; }
  std::string get_type() override { return "MS"; }
  std::string get_time_stamp() override { return {}; }
  std::vector<int> get_polarity() override { return std::vector<int>(records_.size(), 0); }
  std::vector<int> get_mode() override { return std::vector<int>(records_.size(), 0); }
  std::vector<int> get_level() override
  {
    std::vector<int> out;
    for (const auto &record : records_) out.push_back(record.ms_level);
    return out;
  }
  std::vector<int> get_configuration() override { return {}; }
  float get_min_mz() override
  {
    float value = std::numeric_limits<float>::infinity();
    for (const auto &record : records_) value = std::min(value, static_cast<float>(record.spectrum_min_x));
    return std::isfinite(value) ? value : 0.0f;
  }
  float get_max_mz() override
  {
    float value = 0.0f;
    for (const auto &record : records_) value = std::max(value, static_cast<float>(record.spectrum_max_x));
    return value;
  }
  float get_start_rt() override { return records_.empty() ? 0.0f : static_cast<float>(records_.front().scan_time_minutes); }
  float get_end_rt() override { return records_.empty() ? 0.0f : static_cast<float>(records_.back().scan_time_minutes); }
  bool has_ion_mobility() override { return false; }
  MASS_SPEC_SUMMARY get_summary() override
  {
    MASS_SPEC_SUMMARY summary{};
    summary.number_spectra = get_number_spectra();
    summary.number_spectra_binary_arrays = get_number_spectra_binary_arrays();
    summary.min_mz = get_min_mz();
    summary.max_mz = get_max_mz();
    summary.start_rt = get_start_rt();
    summary.end_rt = get_end_rt();
    return summary;
  }
  std::vector<int> get_spectra_index(std::vector<int> indices = {}) override
  {
    auto selected = normalize(indices); std::vector<int> out;
    for (const auto index : selected) out.push_back(index);
    return out;
  }
  std::vector<int> get_spectra_scan_number(std::vector<int> indices = {}) override
  {
    auto selected = normalize(indices); std::vector<int> out;
    for (const auto index : selected) out.push_back(static_cast<int>(records_.at(index).scan_id));
    return out;
  }
  std::vector<int> get_spectra_array_length(std::vector<int> indices = {}) override
  {
    auto selected = normalize(indices); std::vector<int> out;
    for (const auto index : selected) out.push_back(static_cast<int>(records_.at(index).spectrum_point_count));
    return out;
  }
  std::vector<int> get_spectra_level(std::vector<int> indices = {}) override
  {
    auto selected = normalize(indices); std::vector<int> out;
    for (const auto index : selected) out.push_back(records_.at(index).ms_level);
    return out;
  }
  std::vector<int> get_spectra_configuration(std::vector<int> = {}) override { return {}; }
  std::vector<int> get_spectra_mode(std::vector<int> = {}) override { return {}; }
  std::vector<int> get_spectra_polarity(std::vector<int> indices = {}) override
  {
    return std::vector<int>(normalize(indices).size(), 0);
  }
  std::vector<float> get_spectra_lowmz(std::vector<int> indices = {}) override { return metadata_float(indices, [](const ScanRecord &r) { return static_cast<float>(r.spectrum_min_x); }); }
  std::vector<float> get_spectra_highmz(std::vector<int> indices = {}) override { return metadata_float(indices, [](const ScanRecord &r) { return static_cast<float>(r.spectrum_max_x); }); }
  std::vector<float> get_spectra_bpmz(std::vector<int> indices = {}) override { return metadata_float(indices, [](const ScanRecord &r) { return static_cast<float>(r.base_peak_mz); }); }
  std::vector<float> get_spectra_bpint(std::vector<int> indices = {}) override { return metadata_float(indices, [](const ScanRecord &r) { return static_cast<float>(r.base_peak_value); }); }
  std::vector<float> get_spectra_tic(std::vector<int> indices = {}) override { return metadata_float(indices, [](const ScanRecord &r) { return static_cast<float>(r.tic); }); }
  std::vector<float> get_spectra_rt(std::vector<int> indices = {}) override { return metadata_float(indices, [](const ScanRecord &r) { return static_cast<float>(r.scan_time_minutes); }); }
  std::vector<float> get_spectra_mobility(std::vector<int> = {}) override { return {}; }
  std::vector<int> get_spectra_precursor_scan(std::vector<int> = {}) override { return {}; }
  std::vector<float> get_spectra_precursor_mz(std::vector<int> = {}) override { return {}; }
  std::vector<float> get_spectra_precursor_window_mz(std::vector<int> = {}) override { return {}; }
  std::vector<float> get_spectra_precursor_window_mzlow(std::vector<int> = {}) override { return {}; }
  std::vector<float> get_spectra_precursor_window_mzhigh(std::vector<int> = {}) override { return {}; }
  std::vector<float> get_spectra_collision_energy(std::vector<int> = {}) override { return {}; }
  MASS_SPEC_SPECTRA_HEADERS get_spectra_headers(std::vector<int> indices = {}, bool = false) override
  {
    auto selected = normalize(indices); MASS_SPEC_SPECTRA_HEADERS out; out.resize_all(selected.size());
    for (std::size_t output = 0; output < selected.size(); ++output)
    {
      const auto &record = records_.at(selected[output]);
      out.index[output] = static_cast<int>(selected[output]); out.scan[output] = static_cast<int>(record.scan_id);
      out.array_length[output] = static_cast<int>(record.spectrum_point_count); out.level[output] = record.ms_level;
      out.lowmz[output] = static_cast<float>(record.spectrum_min_x); out.highmz[output] = static_cast<float>(record.spectrum_max_x);
      out.bpmz[output] = static_cast<float>(record.base_peak_mz); out.bpint[output] = static_cast<float>(record.base_peak_value);
      out.tic[output] = static_cast<float>(record.tic); out.rt[output] = static_cast<float>(record.scan_time_minutes);
    }
    return out;
  }
  MASS_SPEC_CHROMATOGRAMS_HEADERS get_chromatograms_headers(std::vector<int> = {}) override { return {}; }
  std::vector<std::vector<std::vector<float>>> get_spectra(std::vector<int> indices = {}) override
  {
    auto selected = normalize(indices); std::vector<std::vector<std::vector<float>>> out;
    for (const auto index : selected) { const auto spectrum = get_spectrum(static_cast<int>(index)); out.push_back(spectrum.binary_data); }
    return out;
  }
  std::vector<std::vector<std::vector<float>>> get_chromatograms(std::vector<int> = {}) override { return {}; }
  std::vector<std::vector<std::string>> get_software() override { return {}; }
  std::vector<std::vector<std::string>> get_hardware() override { return {}; }
  MASS_SPEC_SPECTRUM get_spectrum(const int &index) override
  {
    const auto &record = records_.at(static_cast<std::size_t>(index));
    const auto profile = read_profile_spectrum(file_, record);
    MASS_SPEC_SPECTRUM spectrum{};
    spectrum.index = index; spectrum.scan = static_cast<int>(record.scan_id); spectrum.array_length = static_cast<int>(profile.mz.size());
    spectrum.level = record.ms_level; spectrum.polarity = 0; spectrum.lowmz = static_cast<float>(record.spectrum_min_x);
    spectrum.highmz = static_cast<float>(record.spectrum_max_x); spectrum.bpmz = static_cast<float>(record.base_peak_mz);
    spectrum.bpint = static_cast<float>(record.base_peak_value); spectrum.tic = static_cast<float>(record.tic);
    spectrum.rt = static_cast<float>(record.scan_time_minutes); spectrum.binary_arrays_count = 2;
    spectrum.binary_names = {"m/z", "intensity"}; spectrum.binary_data = {std::move(profile.mz), std::move(profile.intensity)};
    return spectrum;
  }

private:
  std::vector<int> normalize(std::vector<int> indices) const
  {
    if (indices.empty()) { indices.resize(records_.size()); std::iota(indices.begin(), indices.end(), 0); }
    return indices;
  }
  template <typename Function>
  std::vector<float> metadata_float(const std::vector<int> &indices, Function function)
  {
    std::vector<float> out; for (const auto index : normalize(indices)) out.push_back(function(records_.at(index))); return out;
  }
  std::vector<ScanRecord> records_;
};

std::unique_ptr<MASS_SPEC_READER> create_reader(const std::string &file)
{
  return std::make_unique<AgilentReader>(file);
}
}
