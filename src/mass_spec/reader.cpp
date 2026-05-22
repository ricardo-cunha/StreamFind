#define PUGIXML_HEADER_ONLY
#include "../external/pugixml-1.14/src/pugixml.hpp"

#include "reader.h"
#include <simdutf.h>

#include <algorithm>
#include <cctype>
#include <fstream>
#include <limits>
#include <filesystem>
#include <cstring>
#include <stdexcept>
#include <array>
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

      MS_SPECTRA_HEADERS Reader::get_spectra_headers(std::vector<int> indices)
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

      bool cv_has_name(const pugi::xml_node &node, const char *needle)
      {
        for (auto cv : node.children("cvParam"))
        {
          const std::string name = cv.attribute("name").as_string();
          const std::string accession = cv.attribute("accession").as_string();
          if (name.find(needle) != std::string::npos || accession.find(needle) != std::string::npos)
            return true;
        }
        return false;
      }

      std::string cv_first_name(const pugi::xml_node &node, const char *needle)
      {
        for (auto cv : node.children("cvParam"))
        {
          const std::string name = cv.attribute("name").as_string();
          const std::string accession = cv.attribute("accession").as_string();
          if (name.find(needle) != std::string::npos || accession.find(needle) != std::string::npos)
            return name;
        }
        return {};
      }

      float parse_scan_time(const pugi::xml_node &scan_node)
      {
        for (auto cv : scan_node.children("cvParam"))
        {
          const std::string name = cv.attribute("name").as_string();
          if (name.find("scan start time") != std::string::npos)
          {
            const std::string unit = cv.attribute("unitName").as_string();
            const float value = static_cast<float>(cv.attribute("value").as_double());
            if (unit.find("minute") != std::string::npos)
            {
              return value * 60.0f;
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
          const std::string name = cv.attribute("name").as_string();
          if (name.find("zlib compression") != std::string::npos)
            compressed = true;
          if (name.find("64-bit float") != std::string::npos)
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
          const std::string name = cv.attribute("name").as_string();
          if (name.find("m/z array") != std::string::npos || name.find("intensity array") != std::string::npos || name.find("time array") != std::string::npos)
          {
            out.name = name;
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
          const std::string name = cv.attribute("name").as_string();
          if (name == "ms level")
            ms_level = cv.attribute("value").as_int(1);
          else if (name.find("positive scan") != std::string::npos)
            polarity = 1;
          else if (name.find("negative scan") != std::string::npos)
            polarity = -1;
          else if (name.find("lowest observed m/z") != std::string::npos)
            s.lowmz = cv.attribute("value").as_float(0.0f);
          else if (name.find("highest observed m/z") != std::string::npos)
            s.highmz = cv.attribute("value").as_float(0.0f);
          else if (name.find("base peak m/z") != std::string::npos)
            s.bpmz = cv.attribute("value").as_float(0.0f);
          else if (name.find("base peak intensity") != std::string::npos)
            s.bpint = cv.attribute("value").as_float(0.0f);
          else if (name.find("total ion current") != std::string::npos)
            s.tic = cv.attribute("value").as_float(0.0f);
        }
        s.level = ms_level;
        s.polarity = polarity;

        auto scan_list = spectrum_node.child("scanList");
        if (scan_list)
        {
          auto scan = scan_list.child("scan");
          if (scan)
            rt = parse_scan_time(scan);
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
              const std::string name = cv.attribute("name").as_string();
              if (name.find("activation energy") != std::string::npos)
                ce = cv.attribute("value").as_float(0.0f);
            }
            auto selected = precursor.child("selectedIonList").child("selectedIon");
            if (selected)
            {
              for (auto cv : selected.children("cvParam"))
              {
                const std::string name = cv.attribute("name").as_string();
                if (name.find("selected ion m/z") != std::string::npos)
                  prec_mz = cv.attribute("value").as_float(0.0f);
                else if (name.find("peak intensity") != std::string::npos)
                  prec_int = cv.attribute("value").as_float(0.0f);
                else if (name.find("charge state") != std::string::npos)
                  prec_charge = cv.attribute("value").as_int(0);
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
            const std::string name = cv.attribute("name").as_string();
            if (name.find("positive scan") != std::string::npos)
              out.polarity[i] = 1;
            if (name.find("negative scan") != std::string::npos)
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
                const std::string name = cv.attribute("name").as_string();
                if (name.find("isolation window target m/z") != std::string::npos)
                  out.precursor_mz[i] = cv.attribute("value").as_float(0.0f);
              }
            }
            for (auto cv : prec.children("cvParam"))
            {
              const std::string name = cv.attribute("name").as_string();
              if (name.find("collision energy") != std::string::npos)
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
        return s.lowmz == 0.0f || s.highmz == 0.0f || s.tic == 0.0f || s.bpmz == 0.0f;
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
        auto root = pimpl->doc.document_element();
        for (auto node : root.select_nodes("//spectrumList/spectrum"))
        {
          pimpl->spectrum_nodes.push_back(node.node());
          pimpl->spectra.push_back(make_spectrum(node.node(), false));
          pimpl->spectrum_binary_loaded.push_back(false);
          pimpl->spectrum_stats_resolved.push_back(false);
        }
        for (auto node : root.select_nodes("//chromatogramList/chromatogram"))
          pimpl->chrom_nodes.push_back(node.node());
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
      bool Reader::has_ion_mobility() { return false; }
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

      MS_SPECTRA_HEADERS Reader::get_spectra_headers(std::vector<int> indices)
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
          ensure_spectrum_stats(*pimpl, static_cast<std::size_t>(i));
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

    std::string detect_format(const std::string &file_path)
    {
      std::string lower = file_path;
      std::transform(lower.begin(), lower.end(), lower.begin(), [](unsigned char c)
                     { return static_cast<char>(std::tolower(c)); });

      if (lower.find(".mzml") != std::string::npos)
        return "mzML";
      if (lower.find(".mzxml") != std::string::npos)
        return "mzXML";

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
            out.pre_ce.push_back(0.0f);
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
