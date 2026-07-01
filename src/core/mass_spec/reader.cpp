#define PUGIXML_HEADER_ONLY
#include <pugixml.hpp>

#include "reader.h"
#include <simdutf.h>

#include <algorithm>
#include <cctype>
#include <cstdlib>
#include <fstream>
#include <limits>
#include <filesystem>
#include <cstring>
#include <stdexcept>
#include <array>
#include <string_view>
#include <sstream>
#include <zlib.h>

namespace mass_spec
{

  namespace reader
  {

    namespace utils
    {

      static const char kB64[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

      inline unsigned char b64_index(unsigned char c)
      {
        if (c >= 'A' && c <= 'Z')
          return c - 'A';
        if (c >= 'a' && c <= 'z')
          return c - 'a' + 26;
        if (c >= '0' && c <= '9')
          return c - '0' + 52;
        if (c == '+')
          return 62;
        if (c == '/')
          return 63;
        return 255;
      }

      std::string encode_little_endian_from_float(const std::vector<float> &input, int precision)
      {
        if (precision == 8)
        {
          std::vector<unsigned char> bytes(sizeof(double) * input.size());
          for (size_t i = 0; i < input.size(); ++i)
          {
            double v = static_cast<double>(input[i]);
            std::memcpy(bytes.data() + i * sizeof(double), &v, sizeof(double));
          }
          return std::string(bytes.begin(), bytes.end());
        }
        if (precision == 4)
        {
          std::vector<unsigned char> bytes(sizeof(float) * input.size());
          std::memcpy(bytes.data(), input.data(), bytes.size());
          return std::string(bytes.begin(), bytes.end());
        }
        throw std::runtime_error("Precision must be 4 or 8");
      }

      std::string encode_little_endian_from_double(const std::vector<double> &input, int precision)
      {
        if (precision == 8)
        {
          std::vector<unsigned char> bytes(sizeof(double) * input.size());
          std::memcpy(bytes.data(), input.data(), bytes.size());
          return std::string(bytes.begin(), bytes.end());
        }
        if (precision == 4)
        {
          std::vector<unsigned char> bytes(sizeof(float) * input.size());
          for (size_t i = 0; i < input.size(); ++i)
          {
            float v = static_cast<float>(input[i]);
            std::memcpy(bytes.data() + i * sizeof(float), &v, sizeof(float));
          }
          return std::string(bytes.begin(), bytes.end());
        }
        throw std::runtime_error("Precision must be 4 or 8");
      }

      std::vector<float> decode_little_endian_to_float(const std::string &str, int precision)
      {
        if (precision != 4 && precision != 8)
          throw std::invalid_argument("Precision must be 4 or 8");
        const size_t bytes_size = str.size() / precision;
        std::vector<float> result(bytes_size);
        for (size_t i = 0; i < bytes_size; ++i)
        {
          if (precision == 8)
          {
            double v;
            std::memcpy(&v, str.data() + i * precision, sizeof(double));
            result[i] = static_cast<float>(v);
          }
          else
          {
            float v;
            std::memcpy(&v, str.data() + i * precision, sizeof(float));
            result[i] = v;
          }
        }
        return result;
      }

      std::vector<double> decode_little_endian_to_double(const std::string &str, int precision)
      {
        if (precision != 4 && precision != 8)
          throw std::invalid_argument("Precision must be 4 or 8");
        const size_t bytes_size = str.size() / precision;
        std::vector<double> result(bytes_size);
        for (size_t i = 0; i < bytes_size; ++i)
        {
          if (precision == 8)
          {
            double v;
            std::memcpy(&v, str.data() + i * precision, sizeof(double));
            result[i] = v;
          }
          else
          {
            float v;
            std::memcpy(&v, str.data() + i * precision, sizeof(float));
            result[i] = static_cast<double>(v);
          }
        }
        return result;
      }

      std::vector<float> decode_big_endian_to_float(const std::string &str, int precision)
      {
        if (precision != 4 && precision != 8)
          throw std::invalid_argument("Precision must be 4 or 8");
        const size_t bytes_size = str.size() / precision;
        std::vector<float> result(bytes_size);
        for (size_t i = 0; i < bytes_size; ++i)
        {
          if (precision == 8)
          {
            std::uint64_t value = 0;
            for (int j = 0; j < precision; ++j)
            {
              value = (value << 8) | static_cast<unsigned char>(str[i * precision + j]);
            }
            double v;
            std::memcpy(&v, &value, sizeof(double));
            result[i] = static_cast<float>(v);
          }
          else
          {
            std::uint32_t value = 0;
            for (int j = 0; j < precision; ++j)
            {
              value = (value << 8) | static_cast<unsigned char>(str[i * precision + j]);
            }
            float v;
            std::memcpy(&v, &value, sizeof(float));
            result[i] = v;
          }
        }
        return result;
      }

      std::vector<double> decode_big_endian_to_double(const std::string &str, int precision)
      {
        if (precision != 4 && precision != 8)
          throw std::invalid_argument("Precision must be 4 or 8");
        const size_t bytes_size = str.size() / precision;
        std::vector<double> result(bytes_size);
        for (size_t i = 0; i < bytes_size; ++i)
        {
          if (precision == 8)
          {
            std::uint64_t value = 0;
            for (int j = 0; j < precision; ++j)
            {
              value = (value << 8) | static_cast<unsigned char>(str[i * precision + j]);
            }
            double v;
            std::memcpy(&v, &value, sizeof(double));
            result[i] = v;
          }
          else
          {
            std::uint32_t value = 0;
            for (int j = 0; j < precision; ++j)
            {
              value = (value << 8) | static_cast<unsigned char>(str[i * precision + j]);
            }
            float v;
            std::memcpy(&v, &value, sizeof(float));
            result[i] = static_cast<double>(v);
          }
        }
        return result;
      }

      std::string encode_base64(const std::string &input)
      {
        std::string out;
        out.reserve(((input.size() + 2) / 3) * 4);
        unsigned int val = 0;
        int valb = -6;
        for (unsigned char c : input)
        {
          val = (val << 8) | c;
          valb += 8;
          while (valb >= 0)
          {
            out.push_back(kB64[(val >> valb) & 0x3F]);
            valb -= 6;
          }
        }
        if (valb > -6)
          out.push_back(kB64[((val << 8) >> (valb + 8)) & 0x3F]);
        while (out.size() % 4)
          out.push_back('=');
        return out;
      }

      std::string decode_base64(const std::string &input)
      {
        std::string out;
        std::array<int, 256> T{};
        T.fill(-1);
        for (int i = 0; i < 64; ++i)
          T[static_cast<unsigned char>(kB64[i])] = i;
        unsigned int val = 0;
        int valb = -8;
        for (unsigned char c : input)
        {
          if (c == '=')
            break;
          int d = T[c];
          if (d == -1)
            continue;
          val = (val << 6) | static_cast<unsigned int>(d);
          valb += 6;
          if (valb >= 0)
          {
            out.push_back(static_cast<char>((val >> valb) & 0xFF));
            valb -= 8;
          }
        }
        return out;
      };

      std::string encode_base64_simduft(const std::string &input)
      {
        size_t out_len = simdutf::base64_length_from_binary(input.size(), simdutf::base64_default);
        std::vector<char> outbuf(out_len);
        size_t written = simdutf::binary_to_base64(input.data(), input.size(), outbuf.data(), simdutf::base64_default);
        return std::string(outbuf.data(), written);
      };

      std::string decode_base64_simduft(const std::string &encoded_string)
      {
        std::vector<uint8_t> buffer(
            simdutf::maximal_binary_length_from_base64(encoded_string.data(), encoded_string.size()));
        simdutf::result r = simdutf::base64_to_binary(
            encoded_string.data(), encoded_string.size(), (char *)buffer.data());
        if (r.error != simdutf::error_code::SUCCESS)
        {
          throw std::runtime_error("Base64 decoding failed with error code: " + std::to_string(static_cast<int>(r.error)));
        }
        else
        {
          buffer.resize(r.count);
        }
        return std::string(buffer.begin(), buffer.end());
      };

      std::string compress_zlib(const std::string &str)
      {
        std::vector<char> compressed_data;
        z_stream zs;
        memset(&zs, 0, sizeof(zs));
        if (deflateInit(&zs, Z_DEFAULT_COMPRESSION) != Z_OK)
        {
          throw std::runtime_error("deflateInit failed while initializing zlib for compression");
        }
        zs.next_in = reinterpret_cast<Bytef *>(const_cast<char *>(str.data()));
        zs.avail_in = str.size();
        int ret;
        char outbuffer[32768];
        do
        {
          zs.next_out = reinterpret_cast<Bytef *>(outbuffer);
          zs.avail_out = sizeof(outbuffer);
          ret = deflate(&zs, Z_FINISH);
          if (compressed_data.size() < zs.total_out)
          {
            compressed_data.insert(compressed_data.end(), outbuffer, outbuffer + (zs.total_out - compressed_data.size()));
          }
        } while (ret == Z_OK);
        deflateEnd(&zs);
        return std::string(compressed_data.begin(), compressed_data.end());
      };

      std::string decompress_zlib(const std::string &input)
      {
        if (input.empty())
          return {};
        uLongf out_size = static_cast<uLongf>(input.size() * 8 + 1024);
        std::string out(out_size, '\0');
        int rc = Z_BUF_ERROR;
        for (int i = 0; i < 8 && rc == Z_BUF_ERROR; ++i)
        {
          out_size = static_cast<uLongf>(out.size());
          rc = ::uncompress(reinterpret_cast<Bytef *>(&out[0]), &out_size,
                            reinterpret_cast<const Bytef *>(input.data()), static_cast<uLongf>(input.size()));
          if (rc == Z_BUF_ERROR)
            out.resize(out.size() * 2);
        }
        if (rc != Z_OK)
          return {};
        out.resize(out_size);
        return out;
      }

    } // namespace utils

    namespace text_chromatogram
    {
      struct Block
      {
        int index = 0;
        std::string id;
        std::string signal_type;
        std::string chromatogram_type;
        std::string detector;
        std::string channel;
        std::string units;
        int polarity = 0;
        float precursor_mz = std::numeric_limits<float>::quiet_NaN();
        float activation_ce = std::numeric_limits<float>::quiet_NaN();
        float product_mz = std::numeric_limits<float>::quiet_NaN();
        float wavelength_nm = std::numeric_limits<float>::quiet_NaN();
        float interval_ms = std::numeric_limits<float>::quiet_NaN();
        float start_time = std::numeric_limits<float>::quiet_NaN();
        float end_time = std::numeric_limits<float>::quiet_NaN();
        float intensity_multiplier = 1.0f;
        std::vector<float> time;
        std::vector<float> intensity;
      };

      std::string trim(const std::string &value)
      {
        const auto begin = std::find_if_not(value.begin(), value.end(), [](unsigned char c)
                                            { return std::isspace(c); });
        const auto end = std::find_if_not(value.rbegin(), value.rend(), [](unsigned char c)
                                          { return std::isspace(c); })
                             .base();
        return begin < end ? std::string(begin, end) : std::string();
      }

      std::vector<std::string> split_tab(const std::string &line)
      {
        std::vector<std::string> out;
        std::string item;
        std::stringstream ss(line);
        while (std::getline(ss, item, '\t'))
        {
          out.push_back(trim(item));
        }
        return out;
      }

      std::vector<std::string> split_numeric_line(const std::string &line)
      {
        std::string normalized = line;
        for (char &c : normalized)
        {
          if (c == ',' || c == ';' || c == '\t')
          {
            c = ' ';
          }
        }
        std::vector<std::string> out;
        std::string item;
        std::stringstream ss(normalized);
        while (ss >> item)
        {
          out.push_back(item);
        }
        return out;
      }

      bool parse_float(const std::string &value, float &out)
      {
        const std::string trimmed = trim(value);
        if (trimmed.empty())
        {
          return false;
        }
        char *end = nullptr;
        out = std::strtof(trimmed.c_str(), &end);
        return end != trimmed.c_str();
      }

      float parse_float_or_nan(const std::string &value)
      {
        float out = std::numeric_limits<float>::quiet_NaN();
        parse_float(value, out);
        return out;
      }

      std::string lowercase(std::string value)
      {
        std::transform(value.begin(), value.end(), value.begin(), [](unsigned char c)
                       { return static_cast<char>(std::tolower(c)); });
        return value;
      }

      bool starts_section(const std::string &line)
      {
        const std::string value = trim(line);
        return !value.empty() && value.front() == '[';
      }

      int parse_polarity(const std::string &label)
      {
        if (label.find("E+") != std::string::npos)
        {
          return 1;
        }
        if (label.find("E-") != std::string::npos)
        {
          return -1;
        }
        return 0;
      }

      std::string classify_ms_trace(const std::string &label)
      {
        const std::string lower = lowercase(label);
        if (lower.find("tic") != std::string::npos)
        {
          return "TIC";
        }
        if (label.find('>') != std::string::npos)
        {
          return "MRM";
        }
        if (lower.find("xic") != std::string::npos)
        {
          return "XIC";
        }
        return "MS Chromatogram";
      }

      void parse_transition(const std::string &label, float &precursor_mz, float &product_mz)
      {
        const std::size_t arrow = label.find('>');
        if (arrow == std::string::npos)
        {
          return;
        }
        std::size_t left = arrow;
        while (left > 0 && (std::isdigit(static_cast<unsigned char>(label[left - 1])) || label[left - 1] == '.'))
        {
          --left;
        }
        std::size_t right = arrow + 1;
        while (right < label.size() && !(std::isdigit(static_cast<unsigned char>(label[right])) || label[right] == '.'))
        {
          ++right;
        }
        std::size_t right_end = right;
        while (right_end < label.size() && (std::isdigit(static_cast<unsigned char>(label[right_end])) || label[right_end] == '.'))
        {
          ++right_end;
        }
        if (left < arrow)
        {
          precursor_mz = parse_float_or_nan(label.substr(left, arrow - left));
        }
        if (right < right_end)
        {
          product_mz = parse_float_or_nan(label.substr(right, right_end - right));
        }
      }

      std::vector<int> resolve_indices(std::vector<int> indices, std::size_t size)
      {
        if (indices.empty())
        {
          indices.resize(size);
          std::iota(indices.begin(), indices.end(), 0);
        }
        return indices;
      }

      float min_time(const std::vector<Block> &blocks)
      {
        float out = std::numeric_limits<float>::max();
        for (const auto &block : blocks)
        {
          for (float value : block.time)
          {
            if (value < out)
            {
              out = value;
            }
          }
        }
        return out == std::numeric_limits<float>::max() ? 0.0f : out;
      }

      float max_time(const std::vector<Block> &blocks)
      {
        float out = 0.0f;
        for (const auto &block : blocks)
        {
          for (float value : block.time)
          {
            if (value > out)
            {
              out = value;
            }
          }
        }
        return out;
      }

      MS_CHROMATOGRAMS_HEADERS make_headers(const std::vector<Block> &blocks, std::vector<int> indices)
      {
        indices = resolve_indices(std::move(indices), blocks.size());
        MS_CHROMATOGRAMS_HEADERS out;
        out.resize_all(static_cast<int>(indices.size()));
        int j = 0;
        for (int i : indices)
        {
          if (i < 0 || static_cast<std::size_t>(i) >= blocks.size())
          {
            continue;
          }
          const auto &block = blocks[static_cast<std::size_t>(i)];
          out.index[j] = block.index;
          out.id[j] = block.id;
          out.array_length[j] = static_cast<int>(std::min(block.time.size(), block.intensity.size()));
          out.polarity[j] = block.polarity;
          out.precursor_mz[j] = block.precursor_mz;
          out.activation_ce[j] = block.activation_ce;
          out.product_mz[j] = block.product_mz;
          out.signal_type[j] = block.signal_type;
          out.chromatogram_type[j] = block.chromatogram_type;
          out.detector[j] = block.detector;
          out.channel[j] = block.channel;
          out.units[j] = block.units;
          out.wavelength_nm[j] = block.wavelength_nm;
          out.interval_ms[j] = block.interval_ms;
          out.start_time[j] = block.start_time;
          out.end_time[j] = block.end_time;
          out.intensity_multiplier[j] = block.intensity_multiplier;
          ++j;
        }
        return out;
      }

      std::vector<std::vector<std::vector<float>>> make_arrays(const std::vector<Block> &blocks, std::vector<int> indices)
      {
        indices = resolve_indices(std::move(indices), blocks.size());
        std::vector<std::vector<std::vector<float>>> out;
        out.reserve(indices.size());
        for (int i : indices)
        {
          if (i < 0 || static_cast<std::size_t>(i) >= blocks.size())
          {
            continue;
          }
          const auto &block = blocks[static_cast<std::size_t>(i)];
          out.push_back({block.time, block.intensity});
        }
        return out;
      }

      MS_SUMMARY make_summary(const std::string &file_path, const std::string &format, const std::vector<Block> &blocks)
      {
        MS_SUMMARY out{};
        out.file_name = std::filesystem::path(file_path).filename().string();
        out.file_path = file_path;
        out.file_dir = std::filesystem::path(file_path).parent_path().string();
        out.file_extension = std::filesystem::path(file_path).extension().string();
        out.number_spectra = 0;
        out.number_chromatograms = static_cast<int>(blocks.size());
        out.number_spectra_binary_arrays = 0;
        out.format = format;
        out.type = "chromatogram";
        out.min_mz = 0.0f;
        out.max_mz = 0.0f;
        out.start_rt = min_time(blocks);
        out.end_rt = max_time(blocks);
        out.has_ion_mobility = false;
        return out;
      }

      std::vector<float> empty_float(std::vector<int> indices)
      {
        return std::vector<float>(indices.size(), 0.0f);
      }

      std::vector<int> empty_int(std::vector<int> indices)
      {
        return std::vector<int>(indices.size(), 0);
      }

    } // namespace text_chromatogram

    namespace mzxml
    {

      int parse_polarity(const pugi::xml_node &scan)
      {
        const std::string polarity = scan.attribute("polarity").as_string();
        if (polarity == "+" || polarity == "positive" || polarity == "1")
          return 1;
        if (polarity == "-" || polarity == "negative" || polarity == "-1")
          return -1;
        return 0;
      }

      float parse_rt(const std::string &rt)
      {
        if (rt.empty())
          return 0.0f;
        if (rt.rfind("PT", 0) == 0 && rt.back() == 'S')
        {
          return std::stof(rt.substr(2, rt.size() - 3));
        }
        return 0.0f;
      }

      std::vector<float> decode_peaks(const pugi::xml_node &peaks_node, int precision, bool compressed)
      {
        std::string encoded = peaks_node.child_value();
        if (encoded.empty())
          return {};
        if (precision == 32 || precision == 64)
        {
          precision /= 8;
        }
        const std::string byte_order = peaks_node.attribute("byteOrder").as_string();
        const bool big_endian = byte_order == "network" || byte_order == "big" || byte_order == "big endian";
        std::string decoded = utils::decode_base64(encoded);
        if (compressed)
          decoded = utils::decompress_zlib(decoded);
        if (decoded.empty())
          return {};
        return big_endian ? utils::decode_big_endian_to_float(decoded, precision)
                          : utils::decode_little_endian_to_float(decoded, precision);
      }

      void populate_spectrum_binary_data(const pugi::xml_node &scan, MS_SPECTRUM &s)
      {
        auto peaks = scan.child("peaks");
        if (!peaks)
        {
          s.binary_names.clear();
          s.binary_data.clear();
          s.binary_arrays_count = 0;
          return;
        }

        int precision = peaks.attribute("precision").as_int(32);
        bool compressed = std::string(peaks.attribute("compressionType").as_string()).find("zlib") != std::string::npos;
        std::vector<float> vals = decode_peaks(peaks, precision, compressed);
        std::vector<float> mz;
        std::vector<float> intensity;
        mz.reserve(vals.size() / 2);
        intensity.reserve(vals.size() / 2);
        for (size_t i = 0; i + 1 < vals.size(); i += 2)
        {
          mz.push_back(vals[i]);
          intensity.push_back(vals[i + 1]);
        }
        s.binary_names = {"mz", "intensity"};
        s.binary_data = {std::move(mz), std::move(intensity)};
        s.binary_arrays_count = static_cast<int>(s.binary_data.size());
      }

      MS_SPECTRUM make_spectrum(const pugi::xml_node &scan, bool decode_binary_arrays)
      {
        MS_SPECTRUM s{};
        s.index = scan.attribute("num").as_int();
        s.scan = s.index;
        s.array_length = scan.attribute("peaksCount").as_int();
        s.level = scan.attribute("msLevel").as_int(1);
        s.mode = 0;
        s.polarity = parse_polarity(scan);
        s.lowmz = scan.attribute("lowMz").as_float(0.0f);
        s.highmz = scan.attribute("highMz").as_float(0.0f);
        s.bpmz = scan.attribute("basePeakMz").as_float(0.0f);
        s.bpint = scan.attribute("basePeakIntensity").as_float(0.0f);
        s.tic = scan.attribute("totIonCurrent").as_float(0.0f);
        s.configuration = 0;
        s.rt = parse_rt(scan.attribute("retentionTime").as_string());
        s.mobility = 0.0f;

        auto prec = scan.child("precursorMz");
        if (prec)
        {
          s.precursor_mz = prec.text().as_float(0.0f);
          s.precursor_charge = prec.attribute("precursorCharge").as_int(0);
          s.activation_ce = prec.attribute("collisionEnergy").as_float(0.0f);
        }

        if (decode_binary_arrays)
        {
          populate_spectrum_binary_data(scan, s);
        }

        return s;
      }

      struct Impl
      {
        pugi::xml_document doc;
        std::string file_path;
        std::string file_name;
        std::vector<MS_SPECTRUM> spectra;
        std::vector<pugi::xml_node> scan_nodes;
        std::vector<bool> spectrum_binary_loaded;
        bool loaded = false;
      };

      void ensure_spectrum_binary_loaded(Impl &impl, std::size_t index)
      {
        if (index >= impl.spectra.size())
        {
          return;
        }

        if (!impl.spectrum_binary_loaded[index] && index < impl.scan_nodes.size())
        {
          populate_spectrum_binary_data(impl.scan_nodes[index], impl.spectra[index]);
          impl.spectrum_binary_loaded[index] = true;
        }
      }

      Reader::Reader(const std::string &file) : MS_READER(file), pimpl(std::make_unique<Impl>())
      {
        pimpl->file_path = file;
        pimpl->file_name = std::filesystem::path(file).filename().string();
        pugi::xml_parse_result result = pimpl->doc.load_file(file.c_str());
        if (!result)
          throw std::runtime_error(std::string("Failed to parse mzXML file: ") + result.description());

        auto root = pimpl->doc.document_element();
        for (auto msrun : root.children("msRun"))
        {
          for (auto scan : msrun.children("scan"))
          {
            pimpl->scan_nodes.push_back(scan);
            pimpl->spectra.push_back(make_spectrum(scan, false));
            pimpl->spectrum_binary_loaded.push_back(false);
          }
        }
        pimpl->loaded = true;
      }

      Reader::~Reader() = default;

      std::string Reader::get_format() { return "mzXML"; }
      std::string Reader::get_type() { return "MS"; }
      int Reader::get_number_spectra() { return static_cast<int>(pimpl->spectra.size()); }
      int Reader::get_number_chromatograms() { return 0; }
      int Reader::get_number_spectra_binary_arrays() { return static_cast<int>(pimpl->spectra.size() * 2); }
      std::string Reader::get_time_stamp() { return {}; }
      std::vector<int> Reader::get_polarity()
      {
        std::vector<int> out;
        for (const auto &s : pimpl->spectra)
          out.push_back(s.polarity);
        return out;
      }
      std::vector<int> Reader::get_mode() { return std::vector<int>(pimpl->spectra.size(), 0); }
      std::vector<int> Reader::get_level()
      {
        std::vector<int> out;
        for (const auto &s : pimpl->spectra)
          out.push_back(s.level);
        return out;
      }
      std::vector<int> Reader::get_configuration() { return std::vector<int>(pimpl->spectra.size(), 0); }
      float Reader::get_min_mz()
      {
        float out = std::numeric_limits<float>::max();
        for (const auto &s : pimpl->spectra)
        {
          if (s.lowmz > 0.0f && s.lowmz < out)
            out = s.lowmz;
        }
        return out == std::numeric_limits<float>::max() ? 0.0f : out;
      }
      float Reader::get_max_mz()
      {
        float out = 0.0f;
        for (const auto &s : pimpl->spectra)
        {
          if (s.highmz > out)
            out = s.highmz;
        }
        return out;
      }
      float Reader::get_start_rt()
      {
        float out = std::numeric_limits<float>::max();
        for (const auto &s : pimpl->spectra)
        {
          if (s.rt > 0.0f && s.rt < out)
            out = s.rt;
        }
        return out == std::numeric_limits<float>::max() ? 0.0f : out;
      }
      float Reader::get_end_rt()
      {
        float out = 0.0f;
        for (const auto &s : pimpl->spectra)
        {
          if (s.rt > out)
            out = s.rt;
        }
        return out;
      }
      bool Reader::has_ion_mobility() { return false; }

      MS_SUMMARY Reader::get_summary()
      {
        MS_SUMMARY s{};
        s.file_name = pimpl->file_name;
        s.file_path = pimpl->file_path;
        s.file_dir = std::filesystem::path(pimpl->file_path).parent_path().string();
        s.file_extension = std::filesystem::path(pimpl->file_path).extension().string();
        s.number_spectra = static_cast<int>(pimpl->spectra.size());
        s.number_chromatograms = 0;
        s.number_spectra_binary_arrays = get_number_spectra_binary_arrays();
        s.format = "mzXML";
        s.type = "MS";
        s.min_mz = get_min_mz();
        s.max_mz = get_max_mz();
        s.start_rt = get_start_rt();
        s.end_rt = get_end_rt();
        s.has_ion_mobility = false;
        return s;
      }

      std::vector<int> Reader::get_spectra_index(std::vector<int> indices)
      {
        if (indices.empty())
        {
          indices.resize(pimpl->spectra.size());
          std::iota(indices.begin(), indices.end(), 0);
        }
        std::vector<int> out;
        for (int i : indices)
          if (i >= 0 && static_cast<size_t>(i) < pimpl->spectra.size())
            out.push_back(pimpl->spectra[i].index);
        return out;
      }

      std::vector<int> Reader::get_spectra_scan_number(std::vector<int> indices) { return get_spectra_index(std::move(indices)); }
      std::vector<int> Reader::get_spectra_array_length(std::vector<int> indices)
      {
        if (indices.empty())
        {
          indices.resize(pimpl->spectra.size());
          std::iota(indices.begin(), indices.end(), 0);
        }
        std::vector<int> out;
        for (int i : indices)
          if (i >= 0 && static_cast<size_t>(i) < pimpl->spectra.size())
            out.push_back(pimpl->spectra[i].array_length);
        return out;
      }
      std::vector<int> Reader::get_spectra_level(std::vector<int> indices)
      {
        if (indices.empty())
        {
          indices.resize(pimpl->spectra.size());
          std::iota(indices.begin(), indices.end(), 0);
        }
        std::vector<int> out;
        for (int i : indices)
          if (i >= 0 && static_cast<size_t>(i) < pimpl->spectra.size())
            out.push_back(pimpl->spectra[i].level);
        return out;
      }
      std::vector<int> Reader::get_spectra_configuration(std::vector<int> indices) { return std::vector<int>(indices.empty() ? pimpl->spectra.size() : indices.size(), 0); }
      std::vector<int> Reader::get_spectra_mode(std::vector<int> indices) { return std::vector<int>(indices.empty() ? pimpl->spectra.size() : indices.size(), 0); }
      std::vector<int> Reader::get_spectra_polarity(std::vector<int> indices)
      {
        if (indices.empty())
        {
          indices.resize(pimpl->spectra.size());
          std::iota(indices.begin(), indices.end(), 0);
        }
        std::vector<int> out;
        for (int i : indices)
          if (i >= 0 && static_cast<size_t>(i) < pimpl->spectra.size())
            out.push_back(pimpl->spectra[i].polarity);
        return out;
      }
      std::vector<float> Reader::get_spectra_lowmz(std::vector<int> indices) { return std::vector<float>(indices.empty() ? pimpl->spectra.size() : indices.size(), 0.0f); }
      std::vector<float> Reader::get_spectra_highmz(std::vector<int> indices) { return std::vector<float>(indices.empty() ? pimpl->spectra.size() : indices.size(), 0.0f); }
      std::vector<float> Reader::get_spectra_bpmz(std::vector<int> indices) { return std::vector<float>(indices.empty() ? pimpl->spectra.size() : indices.size(), 0.0f); }
      std::vector<float> Reader::get_spectra_bpint(std::vector<int> indices) { return std::vector<float>(indices.empty() ? pimpl->spectra.size() : indices.size(), 0.0f); }
      std::vector<float> Reader::get_spectra_tic(std::vector<int> indices) { return std::vector<float>(indices.empty() ? pimpl->spectra.size() : indices.size(), 0.0f); }
      std::vector<float> Reader::get_spectra_rt(std::vector<int> indices)
      {
        if (indices.empty())
        {
          indices.resize(pimpl->spectra.size());
          std::iota(indices.begin(), indices.end(), 0);
        }
        std::vector<float> out;
        for (int i : indices)
          if (i >= 0 && static_cast<size_t>(i) < pimpl->spectra.size())
            out.push_back(pimpl->spectra[i].rt);
        return out;
      }
      std::vector<float> Reader::get_spectra_mobility(std::vector<int> indices) { return std::vector<float>(indices.empty() ? pimpl->spectra.size() : indices.size(), 0.0f); }
      std::vector<int> Reader::get_spectra_precursor_scan(std::vector<int> indices) { return std::vector<int>(indices.empty() ? pimpl->spectra.size() : indices.size(), 0); }
      std::vector<float> Reader::get_spectra_precursor_mz(std::vector<int> indices)
      {
        if (indices.empty())
        {
          indices.resize(pimpl->spectra.size());
          std::iota(indices.begin(), indices.end(), 0);
        }
        std::vector<float> out;
        for (int i : indices)
          if (i >= 0 && static_cast<size_t>(i) < pimpl->spectra.size())
            out.push_back(pimpl->spectra[i].precursor_mz);
        return out;
      }
      std::vector<float> Reader::get_spectra_precursor_window_mz(std::vector<int> indices) { return std::vector<float>(indices.empty() ? pimpl->spectra.size() : indices.size(), 0.0f); }
      std::vector<float> Reader::get_spectra_precursor_window_mzlow(std::vector<int> indices) { return std::vector<float>(indices.empty() ? pimpl->spectra.size() : indices.size(), 0.0f); }
      std::vector<float> Reader::get_spectra_precursor_window_mzhigh(std::vector<int> indices) { return std::vector<float>(indices.empty() ? pimpl->spectra.size() : indices.size(), 0.0f); }
      std::vector<float> Reader::get_spectra_collision_energy(std::vector<int> indices)
      {
        if (indices.empty())
        {
          indices.resize(pimpl->spectra.size());
          std::iota(indices.begin(), indices.end(), 0);
        }
        std::vector<float> out;
        for (int i : indices)
          if (i >= 0 && static_cast<size_t>(i) < pimpl->spectra.size())
            out.push_back(pimpl->spectra[i].activation_ce);
        return out;
      }

      MS_SPECTRA_HEADERS Reader::get_spectra_headers(std::vector<int> indices, bool derive_missing_stats)
      {
        if (indices.empty())
        {
          indices.resize(pimpl->spectra.size());
          std::iota(indices.begin(), indices.end(), 0);
        }
        MS_SPECTRA_HEADERS h;
        h.resize_all(static_cast<int>(indices.size()));
        int j = 0;
        for (int i : indices)
        {
          if (i < 0 || static_cast<size_t>(i) >= pimpl->spectra.size())
            continue;
          const auto &s = pimpl->spectra[i];
          h.index[j] = s.index;
          h.scan[j] = s.scan;
          h.array_length[j] = s.array_length;
          h.level[j] = s.level;
          h.mode[j] = s.mode;
          h.polarity[j] = s.polarity;
          h.lowmz[j] = s.lowmz;
          h.highmz[j] = s.highmz;
          h.bpmz[j] = s.bpmz;
          h.bpint[j] = s.bpint;
          h.tic[j] = s.tic;
          h.configuration[j] = s.configuration;
          h.rt[j] = s.rt;
          h.mobility[j] = s.mobility;
          h.window_mz[j] = s.window_mz;
          h.window_mzlow[j] = s.window_mzlow;
          h.window_mzhigh[j] = s.window_mzhigh;
          h.precursor_mz[j] = s.precursor_mz;
          h.precursor_intensity[j] = s.precursor_intensity;
          h.precursor_charge[j] = s.precursor_charge;
          h.activation_ce[j] = s.activation_ce;
          ++j;
        }
        return h;
      }

      MS_CHROMATOGRAMS_HEADERS Reader::get_chromatograms_headers(std::vector<int>) { return {}; }

      std::vector<std::vector<std::vector<float>>> Reader::get_spectra(std::vector<int> indices)
      {
        if (indices.empty())
        {
          indices.resize(pimpl->spectra.size());
          std::iota(indices.begin(), indices.end(), 0);
        }
        std::vector<std::vector<std::vector<float>>> out;
        out.reserve(indices.size());
        for (int i : indices)
          if (i >= 0 && static_cast<size_t>(i) < pimpl->spectra.size())
          {
            ensure_spectrum_binary_loaded(*pimpl, static_cast<std::size_t>(i));
            out.push_back(pimpl->spectra[i].binary_data);
          }
        return out;
      }

      std::vector<std::vector<std::vector<float>>> Reader::get_chromatograms(std::vector<int>) { return {}; }
      std::vector<std::vector<std::string>> Reader::get_software() { return {}; }
      std::vector<std::vector<std::string>> Reader::get_hardware() { return {}; }
      MS_SPECTRUM Reader::get_spectrum(const int &idx)
      {
        if (idx < 0 || static_cast<size_t>(idx) >= pimpl->spectra.size())
        {
          return MS_SPECTRUM{};
        }
        ensure_spectrum_binary_loaded(*pimpl, static_cast<std::size_t>(idx));
        return pimpl->spectra[idx];
      }

    } // namespace mzxml

    namespace mzml
    {

      struct ParsedArray
      {
        std::string name;
        std::vector<float> values;
      };

      constexpr std::string_view accession_ms_level = "MS:1000511";
      constexpr std::string_view accession_positive_scan = "MS:1000130";
      constexpr std::string_view accession_negative_scan = "MS:1000129";
      constexpr std::string_view accession_lowest_observed_mz = "MS:1000528";
      constexpr std::string_view accession_highest_observed_mz = "MS:1000527";
      constexpr std::string_view accession_base_peak_mz = "MS:1000504";
      constexpr std::string_view accession_base_peak_intensity = "MS:1000505";
      constexpr std::string_view accession_total_ion_current = "MS:1000285";
      constexpr std::string_view accession_scan_start_time = "MS:1000016";
      constexpr std::string_view accession_selected_ion_mz = "MS:1000744";
      constexpr std::string_view accession_peak_intensity = "MS:1000042";
      constexpr std::string_view accession_charge_state = "MS:1000041";
      constexpr std::string_view accession_collision_energy = "MS:1000045";
      constexpr std::string_view accession_isolation_window_target_mz = "MS:1000827";
      constexpr std::string_view accession_ion_mobility_drift_time = "MS:1002476";
      constexpr std::string_view accession_inverse_reduced_ion_mobility = "MS:1002815";
      constexpr std::string_view accession_zlib_compression = "MS:1000574";
      constexpr std::string_view accession_64_bit_float = "MS:1000523";
      constexpr std::string_view accession_mz_array = "MS:1000514";
      constexpr std::string_view accession_intensity_array = "MS:1000515";
      constexpr std::string_view accession_time_array = "MS:1000595";

      constexpr std::string_view unit_second = "UO:0000010";
      constexpr std::string_view unit_minute = "UO:0000031";
      constexpr std::string_view unit_millisecond = "UO:0000028";

      inline bool accession_equals(const pugi::xml_node &cv, std::string_view accession)
      {
        return std::string_view(cv.attribute("accession").as_string()) == accession;
      }

      inline bool name_contains(const pugi::xml_node &cv, std::string_view needle)
      {
        return std::string_view(cv.attribute("name").as_string()).find(needle) != std::string_view::npos;
      }

      inline bool unit_equals(const pugi::xml_node &cv, std::string_view unit_accession)
      {
        return std::string_view(cv.attribute("unitAccession").as_string()) == unit_accession;
      }

      pugi::xml_node mzml_root_node(const pugi::xml_document &doc)
      {
        auto root = doc.document_element();
        if (!root)
        {
          return {};
        }
        const std::string_view root_name = root.name();
        if (root_name == "mzML")
        {
          return root;
        }
        if (root_name == "indexedmzML")
        {
          return root.child("mzML");
        }
        return root.child("mzML");
      }

      float parse_scan_time(const pugi::xml_node &scan_node)
      {
        for (auto cv : scan_node.children("cvParam"))
        {
          const std::string_view accession = cv.attribute("accession").as_string();
          const bool is_scan_time = !accession.empty()
            ? accession == accession_scan_start_time
            : name_contains(cv, "scan start time");
          if (is_scan_time)
          {
            const float value = static_cast<float>(cv.attribute("value").as_double());
            if (unit_equals(cv, unit_minute) || name_contains(cv, "minute"))
            {
              return value * 60.0f;
            }
            if (unit_equals(cv, unit_millisecond) || name_contains(cv, "millisecond"))
            {
              return value / 1000.0f;
            }
            return value;
          }
        }
        return 0.0f;
      }

      float parse_scan_mobility(const pugi::xml_node &scan_node)
      {
        for (auto cv : scan_node.children("cvParam"))
        {
          const std::string_view accession = cv.attribute("accession").as_string();
          const bool is_mobility = !accession.empty()
            ? (accession == accession_ion_mobility_drift_time ||
                accession == accession_inverse_reduced_ion_mobility)
            : (name_contains(cv, "ion mobility drift time") ||
                name_contains(cv, "inverse reduced ion mobility"));
          if (is_mobility)
          {
            const float value = static_cast<float>(cv.attribute("value").as_double());
            if (unit_equals(cv, unit_second) || name_contains(cv, "second"))
            {
              return value * 1000.0f;
            }
            if (unit_equals(cv, unit_minute) || name_contains(cv, "minute"))
            {
              return value * 60000.0f;
            }
            return value;
          }
        }
        return 0.0f;
      }

      std::vector<float> decode_binary(const pugi::xml_node &array_node)
      {
        std::string encoded = array_node.child_value("binary");
        if (encoded.empty())
          return {};

        bool compressed = false;
        bool precision64 = false;
        for (auto cv : array_node.children("cvParam"))
        {
          const std::string_view accession = cv.attribute("accession").as_string();
          if ((!accession.empty() && accession == accession_zlib_compression) ||
              (accession.empty() && name_contains(cv, "zlib compression")))
            compressed = true;
          if ((!accession.empty() && accession == accession_64_bit_float) ||
              (accession.empty() && name_contains(cv, "64-bit float")))
            precision64 = true;
        }

        std::string decoded = utils::decode_base64(encoded);
        if (compressed)
          decoded = utils::decompress_zlib(decoded);
        if (decoded.empty())
          return {};
        return utils::decode_little_endian_to_float(decoded, precision64 ? 8 : 4);
      }

      ParsedArray parse_array(const pugi::xml_node &array_node)
      {
        ParsedArray out;
        for (auto cv : array_node.children("cvParam"))
        {
          const std::string_view accession = cv.attribute("accession").as_string();
          if ((!accession.empty() && accession == accession_mz_array) ||
              (accession.empty() && name_contains(cv, "m/z array")))
          {
            out.name = "m/z array";
            break;
          }
          if ((!accession.empty() && accession == accession_intensity_array) ||
              (accession.empty() && name_contains(cv, "intensity array")))
          {
            out.name = "intensity array";
            break;
          }
          if ((!accession.empty() && accession == accession_time_array) ||
              (accession.empty() && name_contains(cv, "time array")))
          {
            out.name = "time array";
            break;
          }
        }
        out.values = decode_binary(array_node);
        return out;
      }

      void populate_spectrum_binary_data(const pugi::xml_node &spectrum_node, MS_SPECTRUM &s)
      {
        auto bdal = spectrum_node.child("binaryDataArrayList");
        if (!bdal)
        {
          s.binary_names.clear();
          s.binary_data.clear();
          s.binary_arrays_count = 0;
          return;
        }

        std::vector<float> mz;
        std::vector<float> intensity;
        for (auto bda : bdal.children("binaryDataArray"))
        {
          ParsedArray arr = parse_array(bda);
          if (arr.name.find("m/z array") != std::string::npos)
            mz = std::move(arr.values);
          else if (arr.name.find("intensity array") != std::string::npos)
            intensity = std::move(arr.values);
        }

        s.binary_names = {"mz", "intensity"};
        s.binary_data = {std::move(mz), std::move(intensity)};
        s.binary_arrays_count = static_cast<int>(s.binary_data.size());

        if (!s.binary_data.empty() && !s.binary_data[0].empty())
        {
          if (s.lowmz == 0.0f)
          {
            s.lowmz = *std::min_element(s.binary_data[0].begin(), s.binary_data[0].end());
          }
          if (s.highmz == 0.0f)
          {
            s.highmz = *std::max_element(s.binary_data[0].begin(), s.binary_data[0].end());
          }
        }
        if (s.tic == 0.0f && s.binary_data.size() > 1)
        {
          for (float intensity_value : s.binary_data[1])
          {
            s.tic += intensity_value;
            if (intensity_value > s.bpint)
            {
              s.bpint = intensity_value;
            }
          }
        }
        if (s.bpmz == 0.0f && s.bpint > 0.0f && s.binary_data.size() > 1)
        {
          for (size_t i = 0; i < s.binary_data[1].size() && i < s.binary_data[0].size(); ++i)
          {
            if (s.binary_data[1][i] == s.bpint)
            {
              s.bpmz = s.binary_data[0][i];
              break;
            }
          }
        }
      }

      MS_SPECTRUM make_spectrum(const pugi::xml_node &spectrum_node, bool decode_binary_arrays)
      {
        MS_SPECTRUM s{};
        s.index = spectrum_node.attribute("index").as_int();
        s.scan = s.index;
        s.array_length = spectrum_node.attribute("defaultArrayLength").as_int();

        int ms_level = 1;
        int polarity = 0;
        float rt = 0.0f;
        float prec_mz = 0.0f;
        float prec_int = 0.0f;
        int prec_charge = 0;
        float ce = 0.0f;

        for (auto cv : spectrum_node.children("cvParam"))
        {
          const std::string_view accession = cv.attribute("accession").as_string();
          if (!accession.empty())
          {
            if (accession == accession_ms_level)
              ms_level = cv.attribute("value").as_int(1);
            else if (accession == accession_positive_scan)
              polarity = 1;
            else if (accession == accession_negative_scan)
              polarity = -1;
            else if (accession == accession_lowest_observed_mz)
              s.lowmz = cv.attribute("value").as_float(0.0f);
            else if (accession == accession_highest_observed_mz)
              s.highmz = cv.attribute("value").as_float(0.0f);
            else if (accession == accession_base_peak_mz)
              s.bpmz = cv.attribute("value").as_float(0.0f);
            else if (accession == accession_base_peak_intensity)
              s.bpint = cv.attribute("value").as_float(0.0f);
            else if (accession == accession_total_ion_current)
              s.tic = cv.attribute("value").as_float(0.0f);
          }
          else
          {
            if (name_contains(cv, "ms level"))
              ms_level = cv.attribute("value").as_int(1);
            else if (name_contains(cv, "positive scan"))
              polarity = 1;
            else if (name_contains(cv, "negative scan"))
              polarity = -1;
            else if (name_contains(cv, "lowest observed m/z"))
              s.lowmz = cv.attribute("value").as_float(0.0f);
            else if (name_contains(cv, "highest observed m/z"))
              s.highmz = cv.attribute("value").as_float(0.0f);
            else if (name_contains(cv, "base peak m/z"))
              s.bpmz = cv.attribute("value").as_float(0.0f);
            else if (name_contains(cv, "base peak intensity"))
              s.bpint = cv.attribute("value").as_float(0.0f);
            else if (name_contains(cv, "total ion current"))
              s.tic = cv.attribute("value").as_float(0.0f);
          }
        }
        s.level = ms_level;
        s.polarity = polarity;

        auto scan_list = spectrum_node.child("scanList");
        if (scan_list)
        {
          auto scan = scan_list.child("scan");
          if (scan)
          {
            rt = parse_scan_time(scan);
            s.mobility = parse_scan_mobility(scan);
          }
        }
        s.rt = rt;

        auto prec_list = spectrum_node.child("precursorList");
        if (prec_list)
        {
          auto precursor = prec_list.child("precursor");
          if (precursor)
          {
            for (auto cv : precursor.children("cvParam"))
            {
              const std::string_view accession = cv.attribute("accession").as_string();
              if ((!accession.empty() && accession == accession_collision_energy) ||
                  (accession.empty() &&
                    (name_contains(cv, "collision energy") || name_contains(cv, "activation energy"))))
                ce = cv.attribute("value").as_float(0.0f);
            }
            auto selected = precursor.child("selectedIonList").child("selectedIon");
            if (selected)
            {
              for (auto cv : selected.children("cvParam"))
              {
                const std::string_view accession = cv.attribute("accession").as_string();
                if (!accession.empty())
                {
                  if (accession == accession_selected_ion_mz)
                    prec_mz = cv.attribute("value").as_float(0.0f);
                  else if (accession == accession_peak_intensity)
                    prec_int = cv.attribute("value").as_float(0.0f);
                  else if (accession == accession_charge_state)
                    prec_charge = cv.attribute("value").as_int(0);
                }
                else
                {
                  if (name_contains(cv, "selected ion m/z"))
                    prec_mz = cv.attribute("value").as_float(0.0f);
                  else if (name_contains(cv, "peak intensity"))
                    prec_int = cv.attribute("value").as_float(0.0f);
                  else if (name_contains(cv, "charge state"))
                    prec_charge = cv.attribute("value").as_int(0);
                }
              }
            }
          }
        }
        s.precursor_mz = prec_mz;
        s.precursor_intensity = prec_int;
        s.precursor_charge = prec_charge;
        s.activation_ce = ce;

        if (decode_binary_arrays)
        {
          populate_spectrum_binary_data(spectrum_node, s);
        }
        return s;
      }

      MS_CHROMATOGRAMS_HEADERS make_chrom_headers(const std::vector<MS_SPECTRUM> &specs, const std::vector<pugi::xml_node> &chrom_nodes)
      {
        MS_CHROMATOGRAMS_HEADERS out;
        out.resize_all(static_cast<int>(chrom_nodes.size()));
        for (size_t i = 0; i < chrom_nodes.size(); ++i)
        {
          const auto &ch = chrom_nodes[i];
          out.index[i] = ch.attribute("index").as_int(static_cast<int>(i));
          out.id[i] = ch.attribute("id").as_string();
          out.array_length[i] = ch.attribute("defaultArrayLength").as_int();
          out.polarity[i] = 0;
          out.precursor_mz[i] = 0.0f;
          out.activation_ce[i] = 0.0f;
          out.product_mz[i] = 0.0f;
          for (auto cv : ch.children("cvParam"))
          {
            const std::string_view accession = cv.attribute("accession").as_string();
            if ((!accession.empty() && accession == accession_positive_scan) ||
                (accession.empty() && name_contains(cv, "positive scan")))
              out.polarity[i] = 1;
            if ((!accession.empty() && accession == accession_negative_scan) ||
                (accession.empty() && name_contains(cv, "negative scan")))
              out.polarity[i] = -1;
          }
          auto prec = ch.child("precursor");
          if (prec)
          {
            auto sel = prec.child("isolationWindow");
            if (sel)
            {
              for (auto cv : sel.children("cvParam"))
              {
                const std::string_view accession = cv.attribute("accession").as_string();
                if ((!accession.empty() && accession == accession_isolation_window_target_mz) ||
                    (accession.empty() && name_contains(cv, "isolation window target m/z")))
                  out.precursor_mz[i] = cv.attribute("value").as_float(0.0f);
              }
            }
            for (auto cv : prec.children("cvParam"))
            {
              const std::string_view accession = cv.attribute("accession").as_string();
              if ((!accession.empty() && accession == accession_collision_energy) ||
                  (accession.empty() &&
                    (name_contains(cv, "collision energy") || name_contains(cv, "activation energy"))))
                out.activation_ce[i] = cv.attribute("value").as_float(0.0f);
            }
          }
          auto bdal = ch.child("binaryDataArrayList");
          if (bdal)
          {
            for (auto bda : bdal.children("binaryDataArray"))
            {
              ParsedArray arr = parse_array(bda);
              if (arr.name.find("time array") != std::string::npos)
              {
                // no-op for headers
              }
            }
          }
        }
        return out;
      }

      struct Impl
      {
        pugi::xml_document doc;
        std::string file_path;
        std::string file_name;
        std::vector<MS_SPECTRUM> spectra;
        std::vector<pugi::xml_node> spectrum_nodes;
        std::vector<pugi::xml_node> chrom_nodes;
        std::vector<bool> spectrum_binary_loaded;
        std::vector<bool> spectrum_stats_resolved;
        bool loaded = false;
      };

      bool spectrum_needs_derived_metrics(const MS_SPECTRUM &s)
      {
        return s.lowmz == 0.0f || s.highmz == 0.0f || s.tic == 0.0f;
      }

      void ensure_spectrum_stats(Impl &impl, std::size_t index)
      {
        if (index >= impl.spectra.size() || impl.spectrum_stats_resolved[index])
        {
          return;
        }

        if (spectrum_needs_derived_metrics(impl.spectra[index]) && index < impl.spectrum_nodes.size())
        {
          populate_spectrum_binary_data(impl.spectrum_nodes[index], impl.spectra[index]);
          impl.spectrum_binary_loaded[index] = true;
        }

        impl.spectrum_stats_resolved[index] = true;
      }

      void ensure_spectrum_binary_loaded(Impl &impl, std::size_t index)
      {
        if (index >= impl.spectra.size())
        {
          return;
        }

        if (!impl.spectrum_binary_loaded[index] && index < impl.spectrum_nodes.size())
        {
          populate_spectrum_binary_data(impl.spectrum_nodes[index], impl.spectra[index]);
          impl.spectrum_binary_loaded[index] = true;
        }

        impl.spectrum_stats_resolved[index] = true;
      }

      Reader::Reader(const std::string &file) : MS_READER(file), pimpl(std::make_unique<Impl>())
      {
        pimpl->file_path = file;
        pimpl->file_name = std::filesystem::path(file).filename().string();
        pugi::xml_parse_result result = pimpl->doc.load_file(file.c_str());
        if (!result)
          throw std::runtime_error(std::string("Failed to parse mzML file: ") + result.description());
        auto mzml_root = mzml_root_node(pimpl->doc);
        auto run = mzml_root.child("run");
        auto spectrum_list = run.child("spectrumList");
        auto chromatogram_list = run.child("chromatogramList");

        const auto spectra_count = static_cast<std::size_t>(spectrum_list.attribute("count").as_ullong());
        if (spectra_count > 0)
        {
          pimpl->spectra.reserve(spectra_count);
          pimpl->spectrum_nodes.reserve(spectra_count);
          pimpl->spectrum_binary_loaded.reserve(spectra_count);
          pimpl->spectrum_stats_resolved.reserve(spectra_count);
        }

        for (auto node = spectrum_list.child("spectrum"); node; node = node.next_sibling("spectrum"))
        {
          pimpl->spectrum_nodes.push_back(node);
          pimpl->spectra.push_back(make_spectrum(node, false));
          pimpl->spectrum_binary_loaded.push_back(false);
          pimpl->spectrum_stats_resolved.push_back(false);
        }

        const auto chromatogram_count = static_cast<std::size_t>(chromatogram_list.attribute("count").as_ullong());
        if (chromatogram_count > 0)
        {
          pimpl->chrom_nodes.reserve(chromatogram_count);
        }
        for (auto node = chromatogram_list.child("chromatogram"); node; node = node.next_sibling("chromatogram"))
        {
          pimpl->chrom_nodes.push_back(node);
        }
        pimpl->loaded = true;
      }

      Reader::~Reader() = default;
      std::string Reader::get_format() { return "mzML"; }
      std::string Reader::get_type() { return "MS"; }
      int Reader::get_number_spectra() { return static_cast<int>(pimpl->spectra.size()); }
      int Reader::get_number_chromatograms() { return static_cast<int>(pimpl->chrom_nodes.size()); }
      std::vector<std::vector<std::vector<float>>> Reader::get_spectra(std::vector<int> indices)
      {
        std::vector<int> idx = indices;
        if (idx.empty())
        {
          idx.resize(pimpl->spectra.size());
          std::iota(idx.begin(), idx.end(), 0);
        }
        std::vector<std::vector<std::vector<float>>> out;
        out.reserve(idx.size());
        for (int i : idx)
        {
          if (i < 0 || static_cast<size_t>(i) >= pimpl->spectra.size())
            continue;
          ensure_spectrum_binary_loaded(*pimpl, static_cast<std::size_t>(i));
          out.push_back(pimpl->spectra[i].binary_data);
        }
        return out;
      }
      std::vector<std::vector<std::vector<float>>> Reader::get_chromatograms(std::vector<int> indices)
      {
        std::vector<int> idx = indices;
        if (idx.empty())
        {
          idx.resize(pimpl->chrom_nodes.size());
          std::iota(idx.begin(), idx.end(), 0);
        }
        std::vector<std::vector<std::vector<float>>> out;
        out.reserve(idx.size());
        for (int i : idx)
        {
          if (i < 0 || static_cast<size_t>(i) >= pimpl->chrom_nodes.size())
            continue;
          auto node = pimpl->chrom_nodes[i];
          std::vector<float> rt;
          std::vector<float> inten;
          auto bdal = node.child("binaryDataArrayList");
          if (bdal)
          {
            for (auto bda : bdal.children("binaryDataArray"))
            {
              ParsedArray arr = parse_array(bda);
              if (arr.name.find("time array") != std::string::npos)
                rt = std::move(arr.values);
              else if (arr.name.find("intensity array") != std::string::npos)
                inten = std::move(arr.values);
            }
          }
          out.push_back({std::move(rt), std::move(inten)});
        }
        return out;
      }
      int Reader::get_number_spectra_binary_arrays() { return static_cast<int>(pimpl->spectra.size() * 2); }
      std::string Reader::get_time_stamp() { return {}; }
      std::vector<int> Reader::get_polarity()
      {
        std::vector<int> out;
        for (const auto &s : pimpl->spectra)
          out.push_back(s.polarity);
        return out;
      }
      std::vector<int> Reader::get_mode() { return std::vector<int>(pimpl->spectra.size(), 0); }
      std::vector<int> Reader::get_level()
      {
        std::vector<int> out;
        for (const auto &s : pimpl->spectra)
          out.push_back(s.level);
        return out;
      }
      std::vector<int> Reader::get_configuration() { return std::vector<int>(pimpl->spectra.size(), 0); }
      float Reader::get_min_mz()
      {
        float out = std::numeric_limits<float>::max();
        for (const auto &s : pimpl->spectra)
        {
          if (s.lowmz > 0.0f && s.lowmz < out)
            out = s.lowmz;
        }
        return out == std::numeric_limits<float>::max() ? 0.0f : out;
      }
      float Reader::get_max_mz()
      {
        float out = 0.0f;
        for (const auto &s : pimpl->spectra)
        {
          if (s.highmz > out)
            out = s.highmz;
        }
        return out;
      }
      float Reader::get_start_rt()
      {
        float out = std::numeric_limits<float>::max();
        for (const auto &s : pimpl->spectra)
        {
          if (s.rt > 0.0f && s.rt < out)
            out = s.rt;
        }
        return out == std::numeric_limits<float>::max() ? 0.0f : out;
      }
      float Reader::get_end_rt()
      {
        float out = 0.0f;
        for (const auto &s : pimpl->spectra)
        {
          if (s.rt > out)
            out = s.rt;
        }
        return out;
      }
      bool Reader::has_ion_mobility()
      {
        return std::any_of(pimpl->spectra.begin(), pimpl->spectra.end(), [](const auto &s)
                           { return s.mobility > 0.0f; });
      }
      MS_SUMMARY Reader::get_summary()
      {
        MS_SUMMARY s{};
        s.file_name = pimpl->file_name;
        s.file_path = pimpl->file_path;
        s.file_dir = std::filesystem::path(pimpl->file_path).parent_path().string();
        s.file_extension = std::filesystem::path(pimpl->file_path).extension().string();
        s.number_spectra = static_cast<int>(pimpl->spectra.size());
        s.number_chromatograms = static_cast<int>(pimpl->chrom_nodes.size());
        s.number_spectra_binary_arrays = get_number_spectra_binary_arrays();
        s.format = "mzML";
        s.type = "MS";
        s.min_mz = get_min_mz();
        s.max_mz = get_max_mz();
        s.start_rt = get_start_rt();
        s.end_rt = get_end_rt();
        s.has_ion_mobility = has_ion_mobility();
        return s;
      }

      std::vector<int> Reader::get_spectra_index(std::vector<int> indices)
      {
        if (indices.empty())
        {
          indices.resize(pimpl->spectra.size());
          std::iota(indices.begin(), indices.end(), 0);
        }
        std::vector<int> out;
        for (int i : indices)
          if (i >= 0 && static_cast<size_t>(i) < pimpl->spectra.size())
            out.push_back(pimpl->spectra[i].index);
        return out;
      }
      std::vector<int> Reader::get_spectra_scan_number(std::vector<int> indices) { return get_spectra_index(std::move(indices)); }
      std::vector<int> Reader::get_spectra_array_length(std::vector<int> indices)
      {
        if (indices.empty())
        {
          indices.resize(pimpl->spectra.size());
          std::iota(indices.begin(), indices.end(), 0);
        }
        std::vector<int> out;
        for (int i : indices)
          if (i >= 0 && static_cast<size_t>(i) < pimpl->spectra.size())
            out.push_back(pimpl->spectra[i].array_length);
        return out;
      }
      std::vector<int> Reader::get_spectra_level(std::vector<int> indices)
      {
        if (indices.empty())
        {
          indices.resize(pimpl->spectra.size());
          std::iota(indices.begin(), indices.end(), 0);
        }
        std::vector<int> out;
        for (int i : indices)
          if (i >= 0 && static_cast<size_t>(i) < pimpl->spectra.size())
            out.push_back(pimpl->spectra[i].level);
        return out;
      }
      std::vector<int> Reader::get_spectra_configuration(std::vector<int> indices) { return std::vector<int>(indices.empty() ? pimpl->spectra.size() : indices.size(), 0); }
      std::vector<int> Reader::get_spectra_mode(std::vector<int> indices) { return std::vector<int>(indices.empty() ? pimpl->spectra.size() : indices.size(), 0); }
      std::vector<int> Reader::get_spectra_polarity(std::vector<int> indices)
      {
        if (indices.empty())
        {
          indices.resize(pimpl->spectra.size());
          std::iota(indices.begin(), indices.end(), 0);
        }
        std::vector<int> out;
        for (int i : indices)
          if (i >= 0 && static_cast<size_t>(i) < pimpl->spectra.size())
            out.push_back(pimpl->spectra[i].polarity);
        return out;
      }
      std::vector<float> Reader::get_spectra_lowmz(std::vector<int> indices) { return std::vector<float>(indices.empty() ? pimpl->spectra.size() : indices.size(), 0.0f); }
      std::vector<float> Reader::get_spectra_highmz(std::vector<int> indices) { return std::vector<float>(indices.empty() ? pimpl->spectra.size() : indices.size(), 0.0f); }
      std::vector<float> Reader::get_spectra_bpmz(std::vector<int> indices) { return std::vector<float>(indices.empty() ? pimpl->spectra.size() : indices.size(), 0.0f); }
      std::vector<float> Reader::get_spectra_bpint(std::vector<int> indices) { return std::vector<float>(indices.empty() ? pimpl->spectra.size() : indices.size(), 0.0f); }
      std::vector<float> Reader::get_spectra_tic(std::vector<int> indices) { return std::vector<float>(indices.empty() ? pimpl->spectra.size() : indices.size(), 0.0f); }
      std::vector<float> Reader::get_spectra_rt(std::vector<int> indices)
      {
        if (indices.empty())
        {
          indices.resize(pimpl->spectra.size());
          std::iota(indices.begin(), indices.end(), 0);
        }
        std::vector<float> out;
        for (int i : indices)
          if (i >= 0 && static_cast<size_t>(i) < pimpl->spectra.size())
            out.push_back(pimpl->spectra[i].rt);
        return out;
      }
      std::vector<float> Reader::get_spectra_mobility(std::vector<int> indices)
      {
        if (indices.empty())
        {
          indices.resize(pimpl->spectra.size());
          std::iota(indices.begin(), indices.end(), 0);
        }
        std::vector<float> out;
        for (int i : indices)
          if (i >= 0 && static_cast<size_t>(i) < pimpl->spectra.size())
            out.push_back(pimpl->spectra[i].mobility);
        return out;
      }
      std::vector<int> Reader::get_spectra_precursor_scan(std::vector<int> indices) { return std::vector<int>(indices.empty() ? pimpl->spectra.size() : indices.size(), 0); }
      std::vector<float> Reader::get_spectra_precursor_mz(std::vector<int> indices)
      {
        if (indices.empty())
        {
          indices.resize(pimpl->spectra.size());
          std::iota(indices.begin(), indices.end(), 0);
        }
        std::vector<float> out;
        for (int i : indices)
          if (i >= 0 && static_cast<size_t>(i) < pimpl->spectra.size())
            out.push_back(pimpl->spectra[i].precursor_mz);
        return out;
      }
      std::vector<float> Reader::get_spectra_precursor_window_mz(std::vector<int> indices) { return std::vector<float>(indices.empty() ? pimpl->spectra.size() : indices.size(), 0.0f); }
      std::vector<float> Reader::get_spectra_precursor_window_mzlow(std::vector<int> indices) { return std::vector<float>(indices.empty() ? pimpl->spectra.size() : indices.size(), 0.0f); }
      std::vector<float> Reader::get_spectra_precursor_window_mzhigh(std::vector<int> indices) { return std::vector<float>(indices.empty() ? pimpl->spectra.size() : indices.size(), 0.0f); }
      std::vector<float> Reader::get_spectra_collision_energy(std::vector<int> indices)
      {
        if (indices.empty())
        {
          indices.resize(pimpl->spectra.size());
          std::iota(indices.begin(), indices.end(), 0);
        }
        std::vector<float> out;
        for (int i : indices)
          if (i >= 0 && static_cast<size_t>(i) < pimpl->spectra.size())
            out.push_back(pimpl->spectra[i].activation_ce);
        return out;
      }

      MS_SPECTRA_HEADERS Reader::get_spectra_headers(std::vector<int> indices, bool derive_missing_stats)
      {
        (void)derive_missing_stats;
        if (indices.empty())
        {
          indices.resize(pimpl->spectra.size());
          std::iota(indices.begin(), indices.end(), 0);
        }
        MS_SPECTRA_HEADERS h;
        h.resize_all(static_cast<int>(indices.size()));
        int j = 0;
        for (int i : indices)
        {
          if (i < 0 || static_cast<size_t>(i) >= pimpl->spectra.size())
            continue;
          if (derive_missing_stats)
          {
            ensure_spectrum_stats(*pimpl, static_cast<std::size_t>(i));
          }
          const auto &s = pimpl->spectra[i];
          h.index[j] = s.index;
          h.scan[j] = s.scan;
          h.array_length[j] = s.array_length;
          h.level[j] = s.level;
          h.mode[j] = s.mode;
          h.polarity[j] = s.polarity;
          h.lowmz[j] = s.lowmz;
          h.highmz[j] = s.highmz;
          h.bpmz[j] = s.bpmz;
          h.bpint[j] = s.bpint;
          h.tic[j] = s.tic;
          h.configuration[j] = s.configuration;
          h.rt[j] = s.rt;
          h.mobility[j] = s.mobility;
          h.window_mz[j] = s.window_mz;
          h.window_mzlow[j] = s.window_mzlow;
          h.window_mzhigh[j] = s.window_mzhigh;
          h.precursor_mz[j] = s.precursor_mz;
          h.precursor_intensity[j] = s.precursor_intensity;
          h.precursor_charge[j] = s.precursor_charge;
          h.activation_ce[j] = s.activation_ce;
          ++j;
        }
        return h;
      }

      MS_CHROMATOGRAMS_HEADERS Reader::get_chromatograms_headers(std::vector<int> indices)
      {
        if (indices.empty())
        {
          indices.resize(pimpl->chrom_nodes.size());
          std::iota(indices.begin(), indices.end(), 0);
        }
        MS_CHROMATOGRAMS_HEADERS h;
        h.resize_all(static_cast<int>(indices.size()));
        int j = 0;
        for (int i : indices)
        {
          if (i < 0 || static_cast<size_t>(i) >= pimpl->chrom_nodes.size())
            continue;
          const auto &ch = pimpl->chrom_nodes[i];
          h.index[j] = ch.attribute("index").as_int();
          h.id[j] = ch.attribute("id").as_string();
          h.array_length[j] = ch.attribute("defaultArrayLength").as_int();
          h.polarity[j] = 0;
          h.precursor_mz[j] = 0.0f;
          h.activation_ce[j] = 0.0f;
          h.product_mz[j] = 0.0f;
          h.signal_type[j] = "MS";
          h.chromatogram_type[j] = h.id[j].find("TIC") != std::string::npos ? "TIC" : "MS Chromatogram";
          h.detector[j] = "MS";
          h.channel[j] = h.id[j];
          h.units[j] = "counts";
          ++j;
        }
        return h;
      }

      std::vector<std::vector<std::string>> Reader::get_software() { return {}; }
      std::vector<std::vector<std::string>> Reader::get_hardware() { return {}; }
      MS_SPECTRUM Reader::get_spectrum(const int &idx)
      {
        if (idx < 0 || static_cast<size_t>(idx) >= pimpl->spectra.size())
        {
          return MS_SPECTRUM{};
        }
        ensure_spectrum_binary_loaded(*pimpl, static_cast<std::size_t>(idx));
        return pimpl->spectra[idx];
      }

    } // namespace mzml

    namespace shimadzu_txt
    {
      struct Impl
      {
        std::string file_path;
        std::vector<text_chromatogram::Block> blocks;
      };

      void parse_lc_name(text_chromatogram::Block &block)
      {
        const std::size_t dash = block.id.find('-');
        if (dash != std::string::npos)
        {
          block.detector = text_chromatogram::trim(block.id.substr(0, dash));
          block.channel = text_chromatogram::trim(block.id.substr(dash + 1));
        }
        else
        {
          block.detector = block.id;
          block.channel = block.id;
        }
      }

      void finalize_lc_block(text_chromatogram::Block &block)
      {
        if (std::isnan(block.start_time) && !block.time.empty())
        {
          block.start_time = block.time.front();
        }
        if (std::isnan(block.end_time) && !block.time.empty())
        {
          block.end_time = block.time.back();
        }
        if (std::isnan(block.interval_ms) && block.time.size() > 1)
        {
          block.interval_ms = (block.time[1] - block.time[0]) * 60000.0f;
        }
        parse_lc_name(block);
        const std::string lower_id = text_chromatogram::lowercase(block.id);
        if (!std::isnan(block.wavelength_nm) || lower_id.find("detector") != std::string::npos)
        {
          block.signal_type = "UV";
          block.chromatogram_type = "UV Trace";
        }
        else
        {
          block.signal_type = "Analog";
          block.chromatogram_type = "Analog Trace";
        }
      }

      void finalize_lc_status_block(text_chromatogram::Block &block)
      {
        if (std::isnan(block.start_time) && !block.time.empty())
        {
          block.start_time = block.time.front();
        }
        if (std::isnan(block.end_time) && !block.time.empty())
        {
          block.end_time = block.time.back();
        }
        if (std::isnan(block.interval_ms) && block.time.size() > 1)
        {
          block.interval_ms = (block.time[1] - block.time[0]) * 60000.0f;
        }
        block.signal_type = "LC Status";
        block.chromatogram_type = "Status Trace";
        block.detector = "LC Status";
        block.channel = block.id;
      }

      void parse_metadata(text_chromatogram::Block &block, const std::string &line)
      {
        const auto parts = text_chromatogram::split_tab(line);
        if (parts.size() < 2)
        {
          return;
        }
        const std::string key = text_chromatogram::lowercase(parts[0]);
        if (key == "interval(msec)")
        {
          block.interval_ms = text_chromatogram::parse_float_or_nan(parts[1]);
        }
        else if (key == "start time(min)")
        {
          block.start_time = text_chromatogram::parse_float_or_nan(parts[1]);
        }
        else if (key == "end time(min)")
        {
          block.end_time = text_chromatogram::parse_float_or_nan(parts[1]);
        }
        else if (key == "intensity units")
        {
          block.units = parts[1];
        }
        else if (key == "intensity multiplier")
        {
          float multiplier = 1.0f;
          if (text_chromatogram::parse_float(parts[1], multiplier))
          {
            block.intensity_multiplier = multiplier;
          }
        }
        else if (key == "wavelength(nm)")
        {
          block.wavelength_nm = text_chromatogram::parse_float_or_nan(parts[1]);
        }
      }

      std::vector<text_chromatogram::Block> parse_file(const std::string &file_path)
      {
        std::ifstream input(file_path);
        if (!input)
        {
          throw std::runtime_error("Failed to open Shimadzu TXT file: " + file_path);
        }
        std::vector<std::string> lines;
        std::string line;
        while (std::getline(input, line))
        {
          lines.push_back(line);
        }

        std::vector<text_chromatogram::Block> blocks;
        for (std::size_t i = 0; i < lines.size(); ++i)
        {
          const std::string current = text_chromatogram::trim(lines[i]);
          const bool is_lc = current.rfind("[LC Chromatogram(", 0) == 0;
          const bool is_lc_status = current.rfind("[LC Status Trace(", 0) == 0;
          const bool is_ms = current == "[MS Chromatogram]";
          if (!is_lc && !is_lc_status && !is_ms)
          {
            continue;
          }

          text_chromatogram::Block block;
          block.index = static_cast<int>(blocks.size());
          if (is_lc || is_lc_status)
          {
            const std::size_t begin = current.find('(');
            const std::size_t end = current.rfind(')');
            block.id = begin != std::string::npos && end != std::string::npos && end > begin ? current.substr(begin + 1, end - begin - 1) : current;
          }
          else
          {
            block.signal_type = "MS";
            block.detector = "MS";
            block.units = "counts";
          }

          bool in_data = false;
          for (++i; i < lines.size(); ++i)
          {
            const std::string row = text_chromatogram::trim(lines[i]);
            if (row.empty())
            {
              continue;
            }
            if (text_chromatogram::starts_section(row))
            {
              --i;
              break;
            }
            const std::string lower = text_chromatogram::lowercase(row);
            if (!in_data && lower.rfind("r.time", 0) == 0)
            {
              in_data = true;
              continue;
            }
            if (!in_data)
            {
              if (is_ms)
              {
                const auto parts = text_chromatogram::split_tab(row);
                if (parts.size() >= 2 && text_chromatogram::lowercase(parts[0]) == "m/z")
                {
                  block.id = parts[1];
                  block.channel = block.id;
                  block.polarity = text_chromatogram::parse_polarity(block.id);
                  block.chromatogram_type = text_chromatogram::classify_ms_trace(block.id);
                  text_chromatogram::parse_transition(block.id, block.precursor_mz, block.product_mz);
                }
              }
              parse_metadata(block, row);
              continue;
            }

            const auto values = text_chromatogram::split_numeric_line(row);
            if (values.size() < 2)
            {
              continue;
            }
            float rt = 0.0f;
            float intensity = 0.0f;
            if (text_chromatogram::parse_float(values[0], rt) && text_chromatogram::parse_float(values[1], intensity))
            {
              block.time.push_back(rt);
              block.intensity.push_back((is_lc || is_lc_status) ? intensity * block.intensity_multiplier : intensity);
            }
          }

          if (is_lc)
          {
            finalize_lc_block(block);
          }
          else if (is_lc_status)
          {
            finalize_lc_status_block(block);
          }
          else
          {
            if (block.id.empty())
            {
              block.id = "MS Chromatogram";
              block.channel = block.id;
              block.chromatogram_type = "MS Chromatogram";
            }
            if (std::isnan(block.start_time) && !block.time.empty())
            {
              block.start_time = block.time.front();
            }
            if (std::isnan(block.end_time) && !block.time.empty())
            {
              block.end_time = block.time.back();
            }
          }
          if (!block.time.empty() && !block.intensity.empty())
          {
            blocks.push_back(std::move(block));
          }
        }
        return blocks;
      }

      Reader::Reader(const std::string &file) : MS_READER(file), pimpl(std::make_unique<Impl>())
      {
        pimpl->file_path = file;
        pimpl->blocks = parse_file(file);
      }
      Reader::~Reader() = default;
      int Reader::get_number_spectra() { return 0; }
      int Reader::get_number_chromatograms() { return static_cast<int>(pimpl->blocks.size()); }
      int Reader::get_number_spectra_binary_arrays() { return 0; }
      std::string Reader::get_format() { return "ShimadzuTXT"; }
      std::string Reader::get_type() { return "chromatogram"; }
      std::string Reader::get_time_stamp() { return {}; }
      std::vector<int> Reader::get_polarity() { return {}; }
      std::vector<int> Reader::get_mode() { return {}; }
      std::vector<int> Reader::get_level() { return {}; }
      std::vector<int> Reader::get_configuration() { return {}; }
      float Reader::get_min_mz() { return 0.0f; }
      float Reader::get_max_mz() { return 0.0f; }
      float Reader::get_start_rt() { return text_chromatogram::min_time(pimpl->blocks); }
      float Reader::get_end_rt() { return text_chromatogram::max_time(pimpl->blocks); }
      bool Reader::has_ion_mobility() { return false; }
      MS_SUMMARY Reader::get_summary() { return text_chromatogram::make_summary(pimpl->file_path, "ShimadzuTXT", pimpl->blocks); }
      std::vector<int> Reader::get_spectra_index(std::vector<int> indices) { return text_chromatogram::empty_int(indices); }
      std::vector<int> Reader::get_spectra_scan_number(std::vector<int> indices) { return text_chromatogram::empty_int(indices); }
      std::vector<int> Reader::get_spectra_array_length(std::vector<int> indices) { return text_chromatogram::empty_int(indices); }
      std::vector<int> Reader::get_spectra_level(std::vector<int> indices) { return text_chromatogram::empty_int(indices); }
      std::vector<int> Reader::get_spectra_configuration(std::vector<int> indices) { return text_chromatogram::empty_int(indices); }
      std::vector<int> Reader::get_spectra_mode(std::vector<int> indices) { return text_chromatogram::empty_int(indices); }
      std::vector<int> Reader::get_spectra_polarity(std::vector<int> indices) { return text_chromatogram::empty_int(indices); }
      std::vector<float> Reader::get_spectra_lowmz(std::vector<int> indices) { return text_chromatogram::empty_float(indices); }
      std::vector<float> Reader::get_spectra_highmz(std::vector<int> indices) { return text_chromatogram::empty_float(indices); }
      std::vector<float> Reader::get_spectra_bpmz(std::vector<int> indices) { return text_chromatogram::empty_float(indices); }
      std::vector<float> Reader::get_spectra_bpint(std::vector<int> indices) { return text_chromatogram::empty_float(indices); }
      std::vector<float> Reader::get_spectra_tic(std::vector<int> indices) { return text_chromatogram::empty_float(indices); }
      std::vector<float> Reader::get_spectra_rt(std::vector<int> indices) { return text_chromatogram::empty_float(indices); }
      std::vector<float> Reader::get_spectra_mobility(std::vector<int> indices) { return text_chromatogram::empty_float(indices); }
      std::vector<int> Reader::get_spectra_precursor_scan(std::vector<int> indices) { return text_chromatogram::empty_int(indices); }
      std::vector<float> Reader::get_spectra_precursor_mz(std::vector<int> indices) { return text_chromatogram::empty_float(indices); }
      std::vector<float> Reader::get_spectra_precursor_window_mz(std::vector<int> indices) { return text_chromatogram::empty_float(indices); }
      std::vector<float> Reader::get_spectra_precursor_window_mzlow(std::vector<int> indices) { return text_chromatogram::empty_float(indices); }
      std::vector<float> Reader::get_spectra_precursor_window_mzhigh(std::vector<int> indices) { return text_chromatogram::empty_float(indices); }
      std::vector<float> Reader::get_spectra_collision_energy(std::vector<int> indices) { return text_chromatogram::empty_float(indices); }
      MS_SPECTRA_HEADERS Reader::get_spectra_headers(std::vector<int>, bool) { return {}; }
      MS_CHROMATOGRAMS_HEADERS Reader::get_chromatograms_headers(std::vector<int> indices) { return text_chromatogram::make_headers(pimpl->blocks, std::move(indices)); }
      std::vector<std::vector<std::vector<float>>> Reader::get_spectra(std::vector<int>) { return {}; }
      std::vector<std::vector<std::vector<float>>> Reader::get_chromatograms(std::vector<int> indices) { return text_chromatogram::make_arrays(pimpl->blocks, std::move(indices)); }
      std::vector<std::vector<std::string>> Reader::get_software() { return {}; }
      std::vector<std::vector<std::string>> Reader::get_hardware() { return {}; }
      MS_SPECTRUM Reader::get_spectrum(const int &) { return {}; }

    } // namespace shimadzu_txt

    namespace asc
    {
      struct Impl
      {
        std::string file_path;
        std::vector<text_chromatogram::Block> blocks;
      };

      std::vector<text_chromatogram::Block> parse_file(const std::string &file_path)
      {
        std::ifstream input(file_path);
        if (!input)
        {
          throw std::runtime_error("Failed to open ASC chromatogram file: " + file_path);
        }
        text_chromatogram::Block block;
        block.index = 0;
        block.id = std::filesystem::path(file_path).stem().string();
        block.signal_type = "Unknown";
        block.chromatogram_type = "Chromatogram";
        block.intensity_multiplier = 1.0f;
        std::string line;
        while (std::getline(input, line))
        {
          const std::string row = text_chromatogram::trim(line);
          if (row.empty() || row.front() == '#' || row.front() == '[')
          {
            continue;
          }
          if (!(std::isdigit(static_cast<unsigned char>(row.front())) || row.front() == '-' || row.front() == '+' || row.front() == '.'))
          {
            continue;
          }
          const auto values = text_chromatogram::split_numeric_line(row);
          if (values.size() < 2)
          {
            continue;
          }
          float rt = 0.0f;
          float intensity = 0.0f;
          if (text_chromatogram::parse_float(values[0], rt) && text_chromatogram::parse_float(values[1], intensity))
          {
            block.time.push_back(rt);
            block.intensity.push_back(intensity);
          }
        }
        if (!block.time.empty())
        {
          block.start_time = block.time.front();
          block.end_time = block.time.back();
          if (block.time.size() > 1)
          {
            block.interval_ms = (block.time[1] - block.time[0]) * 60000.0f;
          }
          return {std::move(block)};
        }
        return {};
      }

      Reader::Reader(const std::string &file) : MS_READER(file), pimpl(std::make_unique<Impl>())
      {
        pimpl->file_path = file;
        pimpl->blocks = parse_file(file);
      }
      Reader::~Reader() = default;
      int Reader::get_number_spectra() { return 0; }
      int Reader::get_number_chromatograms() { return static_cast<int>(pimpl->blocks.size()); }
      int Reader::get_number_spectra_binary_arrays() { return 0; }
      std::string Reader::get_format() { return "ASC"; }
      std::string Reader::get_type() { return "chromatogram"; }
      std::string Reader::get_time_stamp() { return {}; }
      std::vector<int> Reader::get_polarity() { return {}; }
      std::vector<int> Reader::get_mode() { return {}; }
      std::vector<int> Reader::get_level() { return {}; }
      std::vector<int> Reader::get_configuration() { return {}; }
      float Reader::get_min_mz() { return 0.0f; }
      float Reader::get_max_mz() { return 0.0f; }
      float Reader::get_start_rt() { return text_chromatogram::min_time(pimpl->blocks); }
      float Reader::get_end_rt() { return text_chromatogram::max_time(pimpl->blocks); }
      bool Reader::has_ion_mobility() { return false; }
      MS_SUMMARY Reader::get_summary() { return text_chromatogram::make_summary(pimpl->file_path, "ASC", pimpl->blocks); }
      std::vector<int> Reader::get_spectra_index(std::vector<int> indices) { return text_chromatogram::empty_int(indices); }
      std::vector<int> Reader::get_spectra_scan_number(std::vector<int> indices) { return text_chromatogram::empty_int(indices); }
      std::vector<int> Reader::get_spectra_array_length(std::vector<int> indices) { return text_chromatogram::empty_int(indices); }
      std::vector<int> Reader::get_spectra_level(std::vector<int> indices) { return text_chromatogram::empty_int(indices); }
      std::vector<int> Reader::get_spectra_configuration(std::vector<int> indices) { return text_chromatogram::empty_int(indices); }
      std::vector<int> Reader::get_spectra_mode(std::vector<int> indices) { return text_chromatogram::empty_int(indices); }
      std::vector<int> Reader::get_spectra_polarity(std::vector<int> indices) { return text_chromatogram::empty_int(indices); }
      std::vector<float> Reader::get_spectra_lowmz(std::vector<int> indices) { return text_chromatogram::empty_float(indices); }
      std::vector<float> Reader::get_spectra_highmz(std::vector<int> indices) { return text_chromatogram::empty_float(indices); }
      std::vector<float> Reader::get_spectra_bpmz(std::vector<int> indices) { return text_chromatogram::empty_float(indices); }
      std::vector<float> Reader::get_spectra_bpint(std::vector<int> indices) { return text_chromatogram::empty_float(indices); }
      std::vector<float> Reader::get_spectra_tic(std::vector<int> indices) { return text_chromatogram::empty_float(indices); }
      std::vector<float> Reader::get_spectra_rt(std::vector<int> indices) { return text_chromatogram::empty_float(indices); }
      std::vector<float> Reader::get_spectra_mobility(std::vector<int> indices) { return text_chromatogram::empty_float(indices); }
      std::vector<int> Reader::get_spectra_precursor_scan(std::vector<int> indices) { return text_chromatogram::empty_int(indices); }
      std::vector<float> Reader::get_spectra_precursor_mz(std::vector<int> indices) { return text_chromatogram::empty_float(indices); }
      std::vector<float> Reader::get_spectra_precursor_window_mz(std::vector<int> indices) { return text_chromatogram::empty_float(indices); }
      std::vector<float> Reader::get_spectra_precursor_window_mzlow(std::vector<int> indices) { return text_chromatogram::empty_float(indices); }
      std::vector<float> Reader::get_spectra_precursor_window_mzhigh(std::vector<int> indices) { return text_chromatogram::empty_float(indices); }
      std::vector<float> Reader::get_spectra_collision_energy(std::vector<int> indices) { return text_chromatogram::empty_float(indices); }
      MS_SPECTRA_HEADERS Reader::get_spectra_headers(std::vector<int>, bool) { return {}; }
      MS_CHROMATOGRAMS_HEADERS Reader::get_chromatograms_headers(std::vector<int> indices) { return text_chromatogram::make_headers(pimpl->blocks, std::move(indices)); }
      std::vector<std::vector<std::vector<float>>> Reader::get_spectra(std::vector<int>) { return {}; }
      std::vector<std::vector<std::vector<float>>> Reader::get_chromatograms(std::vector<int> indices) { return text_chromatogram::make_arrays(pimpl->blocks, std::move(indices)); }
      std::vector<std::vector<std::string>> Reader::get_software() { return {}; }
      std::vector<std::vector<std::string>> Reader::get_hardware() { return {}; }
      MS_SPECTRUM Reader::get_spectrum(const int &) { return {}; }

    } // namespace asc

    namespace shimadzu_lcd
    {
      Reader::Reader(const std::string &file) : MS_READER(file)
      {
        throw std::runtime_error("Shimadzu LCD detected, but native LCD chromatogram decoding is not implemented yet. Export to TXT or ASC for now.");
      }
    } // namespace shimadzu_lcd

    std::string detect_format(const std::string &file_path)
    {
      std::string lower = file_path;
      std::transform(lower.begin(), lower.end(), lower.begin(), [](unsigned char c)
                     { return static_cast<char>(std::tolower(c)); });

      if (lower.size() >= 5 && lower.substr(lower.size() - 5) == ".mzml")
        return "mzML";
      if (lower.size() >= 6 && lower.substr(lower.size() - 6) == ".mzxml")
        return "mzXML";

      if (lower.size() >= 4 && lower.substr(lower.size() - 4) == ".lcd")
      {
        std::ifstream file(file_path, std::ios::binary);
        unsigned char signature[8] = {0};
        file.read(reinterpret_cast<char *>(signature), 8);
        const unsigned char ole_signature[8] = {0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1};
        if (file.gcount() == 8 && std::equal(std::begin(signature), std::end(signature), std::begin(ole_signature)))
        {
          return "ShimadzuLCD";
        }
      }

      if (lower.size() >= 4 && lower.substr(lower.size() - 4) == ".txt")
      {
        std::ifstream file(file_path);
        std::string contents;
        contents.assign(std::istreambuf_iterator<char>(file), std::istreambuf_iterator<char>());
        if (contents.find("[LC Chromatogram(") != std::string::npos ||
            contents.find("[LC Status Trace(") != std::string::npos ||
            contents.find("[MS Chromatogram]") != std::string::npos)
        {
          return "ShimadzuTXT";
        }
      }

      if (lower.size() >= 4 && lower.substr(lower.size() - 4) == ".asc")
      {
        return "ASC";
      }

      std::ifstream file(file_path);
      std::string line;
      for (int i = 0; i < 10 && std::getline(file, line); ++i)
      {
        if (line.find("mzML") != std::string::npos)
          return "mzML";
        if (line.find("mzXML") != std::string::npos)
          return "mzXML";
      }

      return "unknown";
    }

    std::unique_ptr<MS_READER> create_reader(const std::string &file_path)
    {
      const std::string format = detect_format(file_path);
      if (format == "mzML")
        return std::make_unique<mzml::Reader>(file_path);
      if (format == "mzXML")
        return std::make_unique<mzxml::Reader>(file_path);
      if (format == "ShimadzuTXT")
        return std::make_unique<shimadzu_txt::Reader>(file_path);
      if (format == "ASC")
        return std::make_unique<asc::Reader>(file_path);
      if (format == "ShimadzuLCD")
        throw std::runtime_error("Shimadzu LCD detected, but native LCD chromatogram decoding is not implemented yet. Export to TXT or ASC for now.");
      throw std::runtime_error("Unsupported file format: " + format);
    }

    MS_FILE::MS_FILE(const std::string &file)
    {
      file_path = file;
      file_dir = std::filesystem::path(file).parent_path().string();
      file_name = std::filesystem::path(file).stem().string();
      file_extension = std::filesystem::path(file).extension().string();
      if (!file_extension.empty() && file_extension.front() == '.')
        file_extension.erase(file_extension.begin());
      format = detect_format(file);
      format_case = 0;
      if (format == "mzXML")
        format_case = 1;
      else if (format == "ShimadzuTXT")
        format_case = 2;
      else if (format == "ASC")
        format_case = 3;
      else if (format == "ShimadzuLCD")
        format_case = 4;
      ms = create_reader(file);
    }

    mass_spec::spectra::MS_TARGETS_SPECTRA MS_FILE::get_spectra_targets(const mass_spec::spectra::MS_TARGETS &targets, const MS_SPECTRA_HEADERS &hd, const float &minIntLv1, const float &minIntLv2)
    {
      mass_spec::spectra::MS_TARGETS_SPECTRA out;
      const std::vector<int> all_indices = [](size_t n)
      {
        std::vector<int> idx(n);
        std::iota(idx.begin(), idx.end(), 0);
        return idx;
      }(hd.size());

      auto raw = ms->get_spectra(all_indices);
      for (size_t t = 0; t < targets.id.size(); ++t)
      {
        const bool precursor = t < targets.precursor.size() ? targets.precursor[t] : false;
        const int level = t < targets.level.size() ? targets.level[t] : 0;
        const int polarity = t < targets.polarity.size() ? targets.polarity[t] : 0;
        const float mzmin = t < targets.mzmin.size() ? targets.mzmin[t] : 0.0f;
        const float mzmax = t < targets.mzmax.size() ? targets.mzmax[t] : 0.0f;
        const float rtmin = t < targets.rtmin.size() ? targets.rtmin[t] : 0.0f;
        const float rtmax = t < targets.rtmax.size() ? targets.rtmax[t] : 0.0f;
        const float mzcenter = t < targets.mz.size() ? targets.mz[t] : 0.0f;
        const float mmin = mzmin == 0.0f && mzmax == 0.0f ? mzcenter - 0.01f : mzmin;
        const float mmax = mzmin == 0.0f && mzmax == 0.0f ? mzcenter + 0.01f : mzmax;

        for (size_t i = 0; i < hd.rt.size(); ++i)
        {
          if (i >= hd.level.size() || i >= hd.polarity.size())
            continue;
          if (level != 0 && hd.level[i] != level)
            continue;
          // Select all matching scans and concatenate peak lists.
          if (i >= hd.level.size() || i >= hd.polarity.size())
            continue;
          if (level != 0 && hd.level[i] != level)
            continue;
          if (polarity != 0 && hd.polarity[i] != polarity)
            continue;
          if (rtmin != 0.0f && hd.rt[i] < rtmin)
            continue;
          if (rtmax != 0.0f && hd.rt[i] > rtmax)
            continue;
          if (precursor && (i < hd.precursor_mz.size()))
          {
            const float pmz = hd.precursor_mz[i];
            if (mmin != 0.0f || mmax != 0.0f)
            {
              if (pmz < mmin || pmz > mmax)
                continue;
            }
          }
          if (i >= raw.size())
            continue;
          const auto &scan = raw[i];
          if (scan.size() < 2)
            continue;
          const float scan_rt = i < hd.rt.size() ? hd.rt[i] : (t < targets.rt.size() ? targets.rt[t] : 0.0f);
          const float scan_pre_mz = (precursor && i < hd.precursor_mz.size()) ? hd.precursor_mz[i] : mzcenter;
          const float scan_mobility = i < hd.mobility.size() ? hd.mobility[i] : (t < targets.mobility.size() ? targets.mobility[t] : 0.0f);
          for (size_t k = 0; k < scan[0].size(); ++k)
          {
            const float mzv = scan[0][k];
            const float inv = scan[1][k];
            if (level == 1 && inv < minIntLv1)
              continue;
            if (level >= 2 && inv < minIntLv2)
              continue;
            if (!precursor && (mzv < mmin || mzv > mmax))
              continue;
            out.id.push_back(targets.id[t]);
            out.polarity.push_back(polarity);
            out.level.push_back(level);
            out.pre_mz.push_back(scan_pre_mz);
            out.pre_mzlow.push_back(mmin);
            out.pre_mzhigh.push_back(mmax);
            out.pre_ce.push_back(i < hd.activation_ce.size() ? hd.activation_ce[i] : 0.0f);
            out.rt.push_back(scan_rt);
            out.mobility.push_back(scan_mobility);
            out.mz.push_back(mzv);
            out.intensity.push_back(inv);
          }
        }
      }
      return out;
    }

  } // namespace reader

} // namespace mass_spec
