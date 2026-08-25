#include "streamfind/mass_spec/reader_sciex.hpp"
#include "streamfind/mass_spec/reader.hpp"

#include <algorithm>
#include <array>
#include <cmath>
#include <cctype>
#include <cstdio>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iterator>
#include <set>
#include <stdexcept>

namespace mass_spec::reader::sciex
{
namespace detail
{
std::uint32_t read_u32_le(const std::vector<std::uint8_t> &bytes, std::size_t offset)
{
  if (offset > bytes.size() || bytes.size() - offset < 4)
    throw std::runtime_error("Sciex WIFF scan block header is truncated at offset " + std::to_string(offset) + " of " + std::to_string(bytes.size()) + ".");
  return static_cast<std::uint32_t>(bytes[offset]) |
         (static_cast<std::uint32_t>(bytes[offset + 1]) << 8) |
         (static_cast<std::uint32_t>(bytes[offset + 2]) << 16) |
         (static_cast<std::uint32_t>(bytes[offset + 3]) << 24);
}

float read_f32_le(const std::vector<std::uint8_t> &bytes, std::size_t offset)
{
  const std::uint32_t bits = read_u32_le(bytes, offset);
  float value = 0.0f;
  std::memcpy(&value, &bits, sizeof(value));
  return value;
}

bool approximately(float value, float expected)
{
  return std::fabs(value - expected) < 0.001f;
}

float read_f32_unaligned(const std::vector<std::uint8_t> &bytes, std::size_t offset)
{
  if (offset + sizeof(float) > bytes.size())
    return 0.0f;
  float value = 0.0f;
  std::memcpy(&value, bytes.data() + offset, sizeof(value));
  return value;
}

double read_f64_le(const std::vector<std::uint8_t> &bytes, std::size_t offset)
{
  if (offset + sizeof(double) > bytes.size())
    throw std::runtime_error("Sciex WIFF index record is truncated.");
  double value = 0.0;
  std::memcpy(&value, bytes.data() + offset, sizeof(value));
  return value;
}

std::vector<std::uint8_t> read_file(const std::string &path)
{
  std::ifstream input(path, std::ios::binary);
  if (!input)
    throw std::runtime_error("Unable to open Sciex WIFF scan file: " + path);
  return std::vector<std::uint8_t>(std::istreambuf_iterator<char>(input), std::istreambuf_iterator<char>());
}

std::size_t sample_block_offset(const std::vector<std::uint8_t> &bytes, std::uint32_t sample_number)
{
  constexpr std::uint32_t marker = 0x11111111u;
  for (std::size_t offset = 0; offset + 12 <= bytes.size(); offset += 4)
  {
    if (read_u32_le(bytes, offset) == marker && read_u32_le(bytes, offset + 8) == sample_number)
      return offset;
  }
  throw std::runtime_error("Sciex WIFF sample block is missing from the scan file.");
}
}

std::string scan_path_for_wiff(const std::string &wiff_path)
{
  std::filesystem::path path(wiff_path);
  path.replace_extension(".wiff.scan");
  return path.string();
}

std::vector<IdxRecord> read_idx_records(const std::string &wiff_path, int source_analysis_number)
{
  const auto bytes = ole::read_stream(
      wiff_path, "SampleSubtree/Sample" + std::to_string(source_analysis_number) + "/Idx");
  constexpr std::size_t header_size = 32;
  constexpr std::size_t record_size = 54;
  if (bytes.size() < header_size)
    throw std::runtime_error("Sciex WIFF Idx stream is shorter than its header.");
  std::vector<IdxRecord> records;
  for (std::size_t offset = header_size; offset + record_size <= bytes.size(); offset += record_size)
  {
    const auto scan_size = detail::read_u32_le(bytes, offset + 4);
    if (scan_size <= 56)
      continue;
    IdxRecord record;
    record.sample_number = static_cast<std::uint32_t>(source_analysis_number);
    record.scan_offset = detail::read_u32_le(bytes, offset);
    record.scan_size = scan_size;
    record.retention_time_minutes = detail::read_f32_le(bytes, offset + 12);
    record.ms_level_flag = bytes[offset + 16];
    record.tic = detail::read_f64_le(bytes, offset + 18);
    record.grid_field = detail::read_f64_le(bytes, offset + 26);
    records.push_back(record);
  }
  if (records.empty())
    throw std::runtime_error("Sciex WIFF Idx stream contains no valid scan records.");
  return records;
}

std::vector<IndexedFloatRecord> read_idx_float_records(const std::string &wiff_path,
                                                        int source_analysis_number)
{
  const auto index_bytes = ole::read_stream(
      wiff_path, "SampleSubtree/Sample" + std::to_string(source_analysis_number) + "/Idx");
  const auto scan_bytes = detail::read_file(scan_path_for_wiff(wiff_path));
  const auto sample_base = detail::sample_block_offset(scan_bytes, static_cast<std::uint32_t>(source_analysis_number));
  constexpr std::size_t header_size = 32;
  constexpr std::size_t record_size = 54;
  if (index_bytes.size() < header_size)
    throw std::runtime_error("Sciex WIFF Idx stream is shorter than its header.");
  std::vector<IndexedFloatRecord> records;
  for (std::size_t offset = header_size; offset + record_size <= index_bytes.size(); offset += record_size)
  {
    const auto scan_offset = detail::read_u32_le(index_bytes, offset);
    const auto scan_size = detail::read_u32_le(index_bytes, offset + 4);
    const auto global_offset = sample_base + scan_offset;
    if (global_offset + scan_size > scan_bytes.size() || scan_size % 4 != 0)
      continue;
    IdxRecord index;
    index.sample_number = static_cast<std::uint32_t>(source_analysis_number);
    index.scan_offset = scan_offset;
    index.scan_size = scan_size;
    index.retention_time_minutes = detail::read_f32_le(index_bytes, offset + 12);
    index.ms_level_flag = index_bytes[offset + 16];
    index.tic = detail::read_f64_le(index_bytes, offset + 18);
    index.grid_field = detail::read_f64_le(index_bytes, offset + 26);
    IndexedFloatRecord record{index, {}};
    for (std::size_t field = global_offset; field < global_offset + scan_size; field += 4)
      record.fields.push_back(detail::read_f32_le(scan_bytes, field));
    records.push_back(std::move(record));
  }
  if (records.empty())
    throw std::runtime_error("Sciex WIFF contains no valid indexed float records.");
  return records;
}

std::vector<EventRecord> read_idx_event_records(const std::string &wiff_path,
                                                int source_analysis_number)
{
  const auto fragments = read_idx_float_records(wiff_path, source_analysis_number);
  std::vector<EventRecord> records;
  EventRecord *current = nullptr;
  for (const auto &fragment : fragments)
  {
    for (float value : fragment.fields)
    {
      if (detail::approximately(value, -59.01f))
      {
        records.push_back({records.size(), fragment.index.retention_time_minutes, {}});
        current = &records.back();
      }
      else if (current != nullptr)
      {
        current->fields.push_back(value);
      }
    }
  }
  return records;
}

std::vector<CompactMrmPair> read_compact_mrm_pairs(const std::string &wiff_path,
                                                   int source_analysis_number)
{
  const auto fragments = read_idx_float_records(wiff_path, source_analysis_number);
  if (fragments.size() < 4)
    throw std::runtime_error("Sciex compact MRM payload has no data records.");
  for (const auto &fragment : fragments)
    if (fragment.fields.size() != 2)
      throw std::runtime_error("Sciex compact MRM payload is not a two-channel record stream.");
  std::vector<CompactMrmPair> pairs;
  pairs.reserve(fragments.size() - 3);
  for (std::size_t i = 3; i < fragments.size(); ++i)
    pairs.push_back({fragments[i].fields[0], fragments[i].fields[1]});
  return pairs;
}

MrmExperimentSeries build_compact_mrm_series(const std::string &, int, int experiment_index,
                                             const std::vector<Transition> &transitions,
                                             const std::vector<CompactMrmPair> &pairs)
{
  if (transitions.size() != 2)
    throw std::runtime_error("Compact MRM series requires exactly two transitions.");
  MrmExperimentSeries series;
  series.experiment_index = experiment_index;
  series.transitions = transitions;
  series.intensities = {{}, {}};
  series.retention_times = {{}, {}};
  series.intensities[0].insert(series.intensities[0].end(), 3, 0.0f);
  series.intensities[1].insert(series.intensities[1].end(), 3, 0.0f);
  for (const auto &pair : pairs)
  {
    series.intensities[0].push_back(pair.first_intensity);
    series.intensities[1].push_back(pair.second_intensity);
  }
  for (std::size_t i = 0; i < transitions.size(); ++i)
  {
    const auto count = series.intensities[i].size();
    series.retention_times[i].resize(count);
    for (std::size_t point = 0; point < count; ++point)
    {
      if (transitions[i].start_time == transitions[i].end_time)
        series.retention_times[i][point] = static_cast<float>(point) * (0.110f / 60.0f);
      else
      {
        const float fraction = count <= 1 ? 0.0f : static_cast<float>(point) / static_cast<float>(count - 1);
        series.retention_times[i][point] = transitions[i].start_time + fraction * (transitions[i].end_time - transitions[i].start_time);
      }
    }
  }
  return series;
}

std::vector<ScanPoint> decode_scan_payload(const std::vector<std::uint8_t> &payload)
{
  std::vector<ScanPoint> points;
  std::uint32_t mz_bin = 0;
  std::size_t offset = 0;
  while (offset < payload.size())
  {
    const auto token = payload[offset];
    if (token == 0xff && offset + 3 < payload.size() && payload[offset + 1] == 0xff &&
        payload[offset + 2] == 0xff && payload[offset + 3] == 0xff)
      break;
    if (token <= 0x7f)
    {
      mz_bin += token;
      ++offset;
      continue;
    }
    std::uint32_t intensity = 0;
    std::size_t width = 0;
    if (token <= 0xfb) { intensity = token & 0x7f; width = 1; }
    else if (token == 0xfc) { width = 2; if (offset + width > payload.size()) break; intensity = payload[offset + 1]; }
    else if (token == 0xfd) { width = 3; if (offset + width > payload.size()) break; intensity = static_cast<std::uint32_t>(payload[offset + 1]) | (static_cast<std::uint32_t>(payload[offset + 2]) << 8); }
    else if (token == 0xfe) { width = 4; if (offset + width > payload.size()) break; intensity = static_cast<std::uint32_t>(payload[offset + 1]) | (static_cast<std::uint32_t>(payload[offset + 2]) << 8) | (static_cast<std::uint32_t>(payload[offset + 3]) << 16); }
    else { width = 5; if (offset + width > payload.size()) break; intensity = static_cast<std::uint32_t>(payload[offset + 1]) | (static_cast<std::uint32_t>(payload[offset + 2]) << 8) | (static_cast<std::uint32_t>(payload[offset + 3]) << 16) | (static_cast<std::uint32_t>(payload[offset + 4]) << 24); }
    points.push_back({mz_bin, intensity});
    offset += width;
  }
  return points;
}

std::vector<ScanPoint> read_scan_points(const std::string &wiff_path, const IdxRecord &record,
                                        const IdxRecord *next_record)
{
  const auto bytes = detail::read_file(scan_path_for_wiff(wiff_path));
  const auto sample_base = detail::sample_block_offset(bytes, record.sample_number);
  const std::size_t payload_start = sample_base + static_cast<std::size_t>(record.scan_offset) + 56;
  const std::size_t next_end = next_record == nullptr ? bytes.size() : sample_base + static_cast<std::size_t>(next_record->scan_offset) + 64;
  const std::size_t own_end = sample_base + static_cast<std::size_t>(record.scan_offset) + record.scan_size + 64;
  const std::size_t end = std::min({next_end, own_end, bytes.size()});
  if (end <= payload_start)
    return {};
  return decode_scan_payload(std::vector<std::uint8_t>(bytes.begin() + payload_start, bytes.begin() + end));
}

std::vector<ScanBlock> read_scan_blocks(const std::string &wiff_path)
{
  const auto bytes = detail::read_file(scan_path_for_wiff(wiff_path));
  constexpr std::uint32_t marker = 0x11111111u;
  std::vector<std::size_t> offsets;
  for (std::size_t i = 0; i + 4 <= bytes.size(); i += 4)
  {
    if (detail::read_u32_le(bytes, i) == marker)
      offsets.push_back(i);
  }
  if (offsets.empty())
    throw std::runtime_error("Sciex WIFF scan file contains no sample blocks.");

  std::vector<ScanBlock> blocks;
  blocks.reserve(offsets.size());
  for (std::size_t i = 0; i < offsets.size(); ++i)
  {
    const std::size_t begin = offsets[i];
    const std::size_t end = i + 1 < offsets.size() ? offsets[i + 1] : bytes.size();
    if (end <= begin + 12)
      throw std::runtime_error("Sciex WIFF scan sample block is truncated.");
    ScanBlock block;
    block.sample_number = detail::read_u32_le(bytes, begin + 8);
    block.offset = begin;
    block.bytes.assign(bytes.begin() + begin, bytes.begin() + end);
    blocks.push_back(std::move(block));
  }
  return blocks;
}

std::vector<MASS_SPEC_ANALYSIS> read_analysis_catalog(const std::string &wiff_path)
{
  const auto blocks = read_scan_blocks(wiff_path);
  std::vector<MASS_SPEC_ANALYSIS> out;
  out.reserve(blocks.size());
  const int count = static_cast<int>(blocks.size());
  for (std::size_t i = 0; i < blocks.size(); ++i)
  {
    const int source_number = static_cast<int>(blocks[i].sample_number);
    std::string name = "sample_" + std::to_string(source_number);
    try
    {
      const auto data = ole::read_stream(
          wiff_path,
          "SampleSubtree/Sample" + std::to_string(source_number) + "/SampleDABE/DATA");
      std::string candidate;
      for (std::size_t pos = 0; pos + 1 < data.size(); pos += 2)
      {
        const auto c = data[pos];
        const auto high = data[pos + 1];
        if (c == 0 && high == 0)
        {
          if (candidate.size() >= 2)
            break;
          continue;
        }
        if (high != 0 || c < 32 || c > 126)
        {
          if (!candidate.empty())
            break;
          continue;
        }
        candidate.push_back(static_cast<char>(c));
      }
      if (!candidate.empty() && candidate != "none")
        name = candidate;
    }
    catch (const std::exception &)
    {
    }
    out.push_back({static_cast<int>(i), source_number, name, count});
  }
  return out;
}

std::vector<EventRecord> read_event_records(const ScanBlock &block)
{
  std::vector<std::size_t> markers;
  for (std::size_t offset = 24; offset + 4 <= block.bytes.size(); offset += 4)
  {
    if (detail::approximately(detail::read_f32_le(block.bytes, offset), -59.01f))
      markers.push_back(offset);
  }
  std::vector<EventRecord> records;
  records.reserve(markers.size());
  for (std::size_t i = 0; i < markers.size(); ++i)
  {
    const std::size_t begin = markers[i] + 4;
    const std::size_t end = i + 1 < markers.size() ? markers[i + 1] : block.bytes.size();
    EventRecord record;
    record.ordinal = i;
    for (std::size_t offset = begin; offset + 4 <= end; offset += 4)
      record.fields.push_back(detail::read_f32_le(block.bytes, offset));
    records.push_back(std::move(record));
  }
  return records;
}

std::vector<IntensityGroup> decode_intensity_groups(const EventRecord &record)
{
  std::vector<IntensityGroup> groups;
  IntensityGroup *current = nullptr;
  for (float value : record.fields)
  {
    if (value < 0.0f)
    {
      const int code = static_cast<int>(std::lround(value));
      groups.push_back({code, {}});
      current = &groups.back();
    }
    else if (current != nullptr)
    {
      current->intensities.push_back(value);
    }
  }
  groups.erase(std::remove_if(groups.begin(), groups.end(), [](const IntensityGroup &group)
                              { return group.intensities.empty(); }),
               groups.end());
  return groups;
}

TracePair decode_tic_bpc(const ScanBlock &block)
{
  constexpr float tic_marker = -59.01f;
  constexpr float tic_value_marker = -38.01f;
  constexpr float bpc_marker = -19.01f;
  constexpr float end_marker = -20.01f;


  TracePair out;
  std::size_t offset = 24;
  while (offset + 12 <= block.bytes.size())
  {
    const float marker = detail::read_f32_le(block.bytes, offset);
    if (!detail::approximately(marker, tic_marker))
    {
      offset += 4;
      continue;
    }
    if (!detail::approximately(detail::read_f32_le(block.bytes, offset + 4), tic_value_marker))
    {
      offset += 4;
      continue;
    }

    const float tic = detail::read_f32_le(block.bytes, offset + 8);
    std::size_t next = offset + 12;
    float bpc = tic;
    if (next + 8 <= block.bytes.size())
    {
      const float value = detail::read_f32_le(block.bytes, next);
      const float end = detail::read_f32_le(block.bytes, next + 4);
      if (value >= 0.0f && detail::approximately(end, bpc_marker))
      {
        bpc = value;
        next += 8;
      }
      else if (detail::approximately(value, end_marker))
      {
        next += 4;
      }
    }
    out.tic.push_back(tic);
    out.bpc.push_back(bpc);
    offset = next;
  }
  return out;
}

std::vector<Transition> read_transitions_for_experiment(const std::string &wiff_path, int source_analysis_number, int period, int experiment)
{
  const auto bytes = ole::read_stream(
      wiff_path,
      "MethodSubtree/Method1/DeviceMethod0/Period" + std::to_string(period) + "/Experiment" + std::to_string(experiment) + "/MassRangeEx/MassRangeEx");
  std::vector<Transition> out;
  std::set<std::string> seen;
  for (std::size_t pos = 0; pos + 4 < bytes.size(); pos += 2)
  {
    if (pos < 2 || bytes[pos + 1] != 0 || bytes[pos - 2] >= 32)
      continue;
    std::string name;
    std::size_t cursor = pos;
    while (cursor + 1 < bytes.size())
    {
      const auto c = bytes[cursor];
      const auto high = bytes[cursor + 1];
      if (c == 0 && high == 0)
        break;
      if (high != 0 || c < 32 || c > 126 || name.size() >= 128)
      {
        if (name.empty())
          name.clear();
        break;
      }
      name.push_back(static_cast<char>(c));
      cursor += 2;
    }
    if (name.size() < 3 || cursor + 1 >= bytes.size() || pos < 22)
      continue;
    const bool quoted = !name.empty() && name.front() == '"';
    const bool prefixed = !name.empty() && (name.front() == '*' || name.front() == '&');
    while (!name.empty() && (name.front() == '"' || name.front() == '*' || name.front() == '&' || std::isspace(static_cast<unsigned char>(name.front()))))
      name.erase(name.begin());
    if (name.empty() || !seen.insert(name).second)
      continue;
    const std::size_t offset = quoted || prefixed ? 20 : 22;
    if (pos < offset)
      continue;
    const float precursor = detail::read_f32_unaligned(bytes, pos - offset);
    const float product = detail::read_f32_unaligned(bytes, pos - offset + 8);
    const std::array<std::uint8_t, 6> ce_marker = {'C', 0, 'E', 0, 0, 0};
    const auto ce_it = std::search(bytes.begin() + static_cast<std::ptrdiff_t>(cursor),
                                   bytes.begin() + std::min(bytes.size(), cursor + 80),
                                   ce_marker.begin(), ce_marker.end());
    const float collision_energy = ce_it == bytes.end()
                                       ? 0.0f
                                       : detail::read_f32_unaligned(bytes, static_cast<std::size_t>(ce_it - bytes.begin()) + 8);
    if (ce_it == bytes.end())
      continue;
    out.push_back({name,
                   precursor > 0.0f && precursor <= 5000.0f ? precursor : 0.0f,
                   product > 0.0f && product <= 5000.0f ? product : 0.0f,
                   0.0f,
                   0.0f,
                   collision_energy});
  }
  const std::string times_path = "SampleSubtree/Sample" + std::to_string(source_analysis_number) + "/SampleDAM/sMRMPro_adw1/sMRMPro_adw_Times";
  std::vector<std::uint8_t> times;
  try { times = ole::read_stream(wiff_path, times_path); }
  catch (const std::exception &) { return out; }
  const auto available_pairs = times.size() >= 16 ? (times.size() - 16) / 8 : 0;
  const auto transition_pair_offset = available_pairs == out.size() ? 0 : 2;
  if (times.size() >= 16 && available_pairs >= out.size() + transition_pair_offset)
  {
    for (std::size_t i = 0; i < out.size(); ++i)
    {
      const std::size_t offset = 16 + (i + transition_pair_offset) * 8;
      const auto start = detail::read_u32_le(times, offset);
      const auto end = detail::read_u32_le(times, offset + 4);
      out[i].start_time = static_cast<float>(start) / 60000.0f;
      out[i].end_time = static_cast<float>(end) / 60000.0f;
    }
  }
  return out;
}

std::vector<Transition> read_transitions(const std::string &wiff_path, int source_analysis_number)
{
  return read_transitions_for_experiment(wiff_path, source_analysis_number, 0, 0);
}

std::vector<MrmExperimentSeries> read_compact_mrm_experiments(const std::string &wiff_path,
                                                              int source_analysis_number)
{
  const auto fragments = read_idx_float_records(wiff_path, source_analysis_number);
  std::vector<std::vector<IndexedFloatRecord>> groups;
  for (const auto &fragment : fragments)
  {
    if (!groups.empty() && groups.back().front().fields.size() == fragment.fields.size())
      groups.back().push_back(fragment);
    else
      groups.push_back({fragment});
  }
  std::vector<MrmExperimentSeries> out;
  for (std::size_t index = 0; index < groups.size(); ++index)
  {
    const auto width = groups[index].front().fields.size();
    if (width == 0) continue;
    const auto transitions = read_transitions_for_experiment(wiff_path, source_analysis_number, static_cast<int>(index), 0);
    if (transitions.size() < width)
      throw std::runtime_error("SCIEX compact experiment " + std::to_string(index) + " channel count " + std::to_string(width) + " does not match method transitions " + std::to_string(transitions.size()) + ".");
    auto active_transitions = transitions;
    active_transitions.resize(width);
    MrmExperimentSeries series;
    series.experiment_index = static_cast<int>(index);
    series.transitions = active_transitions;
    series.intensities.resize(width);
    series.retention_times.resize(width);
    for (std::size_t column = 0; column < width; ++column)
    {
      for (const auto &fragment : groups[index])
        series.intensities[column].push_back(fragment.fields[column]);
      const auto count = series.intensities[column].size();
      series.retention_times[column].resize(count);
      for (std::size_t point = 0; point < count; ++point)
      {
        const float fraction = count <= 1 ? 0.0f : static_cast<float>(point) / static_cast<float>(count - 1);
        series.retention_times[column][point] = active_transitions[column].start_time + fraction * (active_transitions[column].end_time - active_transitions[column].start_time);
      }
    }
    out.push_back(std::move(series));
  }
  return out;
}

MrmExperimentSeries read_sparse_tagged_mrm_series(const std::string &wiff_path, int source_analysis_number,
                                                  float record_marker, int transition_count)
{
  const auto fragments = read_idx_float_records(wiff_path, source_analysis_number);
  std::vector<float> flat;
  for (const auto &fragment : fragments) flat.insert(flat.end(), fragment.fields.begin(), fragment.fields.end());
  std::vector<std::size_t> starts;
  for (std::size_t i = 0; i < flat.size(); ++i) if (detail::approximately(flat[i], record_marker)) starts.push_back(i);
  auto transitions = read_transitions(wiff_path, source_analysis_number);
  if (static_cast<int>(transitions.size()) < transition_count) throw std::runtime_error("SCIEX sparse MRM method has fewer transitions than its payload.");
  transitions.resize(static_cast<std::size_t>(transition_count));
  MrmExperimentSeries series; series.experiment_index = 0; series.transitions = transitions; series.intensities.assign(transition_count, {}); series.retention_times.assign(transition_count, {});
  std::size_t maximum_channel = 0;
  for (std::size_t record = 0; record < starts.size(); ++record) {
    const auto end = record + 1 < starts.size() ? starts[record + 1] : flat.size();
    std::vector<float> values(static_cast<std::size_t>(transition_count), 0.0f); std::size_t position = 0;
    for (std::size_t i = starts[record] + 1; i < end; ++i) {
      const float value = flat[i];
      if (value < 0.0f) position += static_cast<std::size_t>(std::lround(-value));
      else if (position < values.size()) { values[position++] = value; maximum_channel = std::max(maximum_channel, position); }
    }
    for (int channel = 0; channel < transition_count; ++channel) series.intensities[channel].push_back(values[channel]);
  }
  const auto active_count = std::min<std::size_t>(transition_count, maximum_channel);
  series.transitions.resize(active_count);
  series.intensities.resize(active_count);
  series.retention_times.resize(active_count);
  for (std::size_t channel = 0; channel < active_count; ++channel) {
    const auto count = series.intensities[channel].size(); series.retention_times[channel].resize(count);
    for (std::size_t point = 0; point < count; ++point) series.retention_times[channel][point] = static_cast<float>(point);
  }
  return series;
}

class SciexReader final : public MASS_SPEC_READER
{
public:
  explicit SciexReader(const std::string &file, int source_analysis_number) : MASS_SPEC_READER(file)
  {
    const auto catalog = read_analysis_catalog(file);
    if (catalog.empty()) throw std::runtime_error("SCIEX WIFF has no analyses.");
    std::vector<MrmExperimentSeries> series_list;
    try {
      const auto transitions = read_transitions(file, source_analysis_number);
      const auto pairs = read_compact_mrm_pairs(file, source_analysis_number);
      series_list.push_back(build_compact_mrm_series(file, source_analysis_number, 0, transitions, pairs));
    } catch (const std::exception &) {
      try {
        series_list = read_compact_mrm_experiments(file, source_analysis_number);
      } catch (const std::exception &) {
        const auto transitions = read_transitions(file, source_analysis_number);
        const auto fragments = read_idx_float_records(file, source_analysis_number);
        const bool sparse_tagged = std::any_of(fragments.begin(), fragments.end(), [](const auto &fragment) { return std::any_of(fragment.fields.begin(), fragment.fields.end(), [](float value) { return detail::approximately(value, -33.01f); }); });
        if (!sparse_tagged) throw;
        series_list.push_back(read_sparse_tagged_mrm_series(file, source_analysis_number, -33.01f, static_cast<int>(transitions.size())));
      }
    }
    if (series_list.empty()) throw std::runtime_error("Unsupported native SCIEX MRM payload grammar.");
    std::vector<float> tic;
    std::vector<float> bpc;
    std::vector<float> combined_time;
    for (const auto &series : series_list)
    {
      if (!series.retention_times.empty())
        combined_time.insert(combined_time.end(), series.retention_times.front().begin(), series.retention_times.front().end());
      for (std::size_t point = 0; point < series.intensities.front().size(); ++point) {
        float sum = 0.0f, maximum = 0.0f;
        for (const auto &trace : series.intensities) { sum += trace[point]; maximum = std::max(maximum, trace[point]); }
        tic.push_back(sum); bpc.push_back(maximum);
      }
    }
    const auto count = 2 + std::accumulate(series_list.begin(), series_list.end(), std::size_t{0}, [](std::size_t total, const auto &s) { return total + s.transitions.size(); });
    headers_.resize_all(count);
    arrays_.resize(count);
    for (std::size_t i = 0; i < count; ++i) headers_.index[i] = static_cast<int>(i);
    headers_.chromatogram_id[0] = "TIC"; headers_.chromatogram_id[1] = "BPC";
    headers_.array_length[0] = static_cast<int>(tic.size()); headers_.array_length[1] = static_cast<int>(bpc.size());
    headers_.signal_type[0] = "MS"; headers_.signal_type[1] = "MS";
    headers_.chromatogram_type[0] = "TIC"; headers_.chromatogram_type[1] = "BPC";
    headers_.detector[0] = "SCIEX"; headers_.detector[1] = "SCIEX";
    headers_.units[0] = "counts"; headers_.units[1] = "counts";
    arrays_[0] = {combined_time, tic}; arrays_[1] = {combined_time, bpc};
    std::size_t output = 2;
    for (const auto &series : series_list) for (std::size_t i = 0; i < series.transitions.size(); ++i, ++output) {
      const auto &transition = series.transitions[i]; headers_.chromatogram_id[output] = transition.name; headers_.array_length[output] = static_cast<int>(series.intensities[i].size()); headers_.signal_type[output] = "MS"; headers_.chromatogram_type[output] = "SRM"; headers_.detector[output] = "SCIEX"; headers_.units[output] = "counts"; headers_.precursor_mz[output] = transition.precursor_mz; headers_.product_mz[output] = transition.product_mz; headers_.activation_ce[output] = transition.collision_energy; arrays_[output] = {series.retention_times[i], series.intensities[i]};
    }
  }
  ~SciexReader() override = default;
  int get_number_spectra() override { return 0; }
  int get_number_chromatograms() override { return static_cast<int>(arrays_.size()); }
  int get_number_spectra_binary_arrays() override { return 0; }
  std::string get_format() override { return "SciexWIFF"; }
  std::string get_type() override { return "chromatogram"; }
  std::string get_time_stamp() override { return {}; }
  std::vector<int> get_polarity() override { return std::vector<int>(arrays_.size(), 0); }
  std::vector<int> get_mode() override { return std::vector<int>(arrays_.size(), 0); }
  std::vector<int> get_level() override { return std::vector<int>(arrays_.size(), 0); }
  std::vector<int> get_configuration() override { return std::vector<int>(arrays_.size(), 0); }
  float get_min_mz() override { return 0.0f; } float get_max_mz() override { return 0.0f; }
  float get_start_rt() override { return arrays_[0][0].front(); } float get_end_rt() override { return arrays_[0][0].back(); }
  bool has_ion_mobility() override { return false; }
  MASS_SPEC_SUMMARY get_summary() override { MASS_SPEC_SUMMARY s{}; s.number_spectra = 0; s.number_chromatograms = static_cast<int>(arrays_.size()); s.start_rt = get_start_rt(); s.end_rt = get_end_rt(); return s; }
  std::vector<int> get_spectra_index(std::vector<int> = {}) override { return {}; } std::vector<int> get_spectra_scan_number(std::vector<int> = {}) override { return {}; }
  std::vector<int> get_spectra_array_length(std::vector<int> = {}) override { return {}; } std::vector<int> get_spectra_level(std::vector<int> = {}) override { return {}; }
  std::vector<int> get_spectra_configuration(std::vector<int> = {}) override { return {}; } std::vector<int> get_spectra_mode(std::vector<int> = {}) override { return {}; }
  std::vector<int> get_spectra_polarity(std::vector<int> = {}) override { return {}; } std::vector<float> get_spectra_lowmz(std::vector<int> = {}) override { return {}; }
  std::vector<float> get_spectra_highmz(std::vector<int> = {}) override { return {}; } std::vector<float> get_spectra_bpmz(std::vector<int> = {}) override { return {}; }
  std::vector<float> get_spectra_bpint(std::vector<int> = {}) override { return {}; } std::vector<float> get_spectra_tic(std::vector<int> = {}) override { return {}; }
  std::vector<float> get_spectra_rt(std::vector<int> = {}) override { return {}; } std::vector<float> get_spectra_mobility(std::vector<int> = {}) override { return {}; }
  std::vector<int> get_spectra_precursor_scan(std::vector<int> = {}) override { return {}; } std::vector<float> get_spectra_precursor_mz(std::vector<int> = {}) override { return {}; }
  std::vector<float> get_spectra_precursor_window_mz(std::vector<int> = {}) override { return {}; } std::vector<float> get_spectra_precursor_window_mzlow(std::vector<int> = {}) override { return {}; }
  std::vector<float> get_spectra_precursor_window_mzhigh(std::vector<int> = {}) override { return {}; } std::vector<float> get_spectra_collision_energy(std::vector<int> = {}) override { return {}; }
  MASS_SPEC_SPECTRA_HEADERS get_spectra_headers(std::vector<int> = {}, bool = false) override { return {}; }
  MASS_SPEC_CHROMATOGRAMS_HEADERS get_chromatograms_headers(std::vector<int> = {}) override { return headers_; }
  std::vector<std::vector<std::vector<float>>> get_spectra(std::vector<int> = {}) override { return {}; }
  std::vector<std::vector<std::vector<float>>> get_chromatograms(std::vector<int> indices = {}) override { std::vector<std::vector<std::vector<float>>> out; if (indices.empty()) { for (std::size_t i = 0; i < arrays_.size(); ++i) indices.push_back(static_cast<int>(i)); } for (int i: indices) out.push_back(arrays_.at(i)); return out; }
  std::vector<std::vector<std::string>> get_software() override { return {}; } std::vector<std::vector<std::string>> get_hardware() override { return {}; }
  MASS_SPEC_SPECTRUM get_spectrum(const int &) override { return {}; }
private:
  MASS_SPEC_CHROMATOGRAMS_HEADERS headers_;
  std::vector<std::vector<std::vector<float>>> arrays_;
};

std::unique_ptr<MASS_SPEC_READER> create_reader(const std::string &file, int source_analysis_number)
{
  return std::make_unique<SciexReader>(file, source_analysis_number);
}
}
