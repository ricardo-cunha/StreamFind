#include "streamfind/mass_spec/reader_bruker.hpp"
#include "streamfind/mass_spec/reader.hpp"
#include <algorithm>
#include <cmath>
#include <iostream>

int main()
{
  try
  {
    const std::string path = "E:/example_files/ms_merck/Beispieldaten Routine/ACC1_24890_1_P1-B-8_1_2022_7707.d";
    if (mass_spec::reader::bruker::detect_family(path) != mass_spec::reader::bruker::Family::Baf)
      return 1;
    const auto ms1 = mass_spec::reader::bruker::read_baf_line_spectrum(path, 0x160000000001b1a4ull);
    if (ms1.coordinate.size() != 1410 || ms1.intensity.size() != 1410 || ms1.width.size() != 1410 ||
        std::fabs(ms1.coordinate.front() - 33.0) > 1e-12 || ms1.intensity.front() != 16.0 ||
        *std::max_element(ms1.intensity.begin(), ms1.intensity.end()) != 2140.0)
      return 2;
    const auto ms2 = mass_spec::reader::bruker::read_baf_line_spectrum(path, 0x1600000002270badull);
    if (ms2.coordinate.size() != 2114 || ms2.intensity.size() != 2114 || ms2.width.size() != 2114 ||
        std::fabs(ms2.coordinate.front() - 15.846153846153847) > 1e-12 || ms2.intensity.front() != 56.0 ||
        *std::max_element(ms2.intensity.begin(), ms2.intensity.end()) != 101370.0)
      return 3;
    const auto profile = mass_spec::reader::bruker::read_baf_profile_spectrum(path, 0x4200000000018475ull);
    if (profile.intensity.size() != 513287 ||
        profile.intensity[33] != 16 || profile.intensity[166] != 42 ||
        profile.intensity[167] != 60 || profile.intensity[168] != 40 ||
        profile.intensity[432] != 30 || profile.intensity[433] != 48 ||
        profile.intensity[434] != 38 ||
        std::count_if(profile.intensity.begin(), profile.intensity.end(), [](const auto value) { return value != 0; }) != 3499 ||
        *std::max_element(profile.intensity.begin(), profile.intensity.end()) != 2140)
      return 5;
    mass_spec::reader::MASS_SPEC_FILE public_file(path);
    if (public_file.get_format() != "BrukerBAF" || public_file.get_number_spectra() <= 0)
      return 6;
    const auto headers = public_file.get_spectra_headers({0});
    if (headers.size() != 1 || headers.scan[0] != 1 || headers.array_length[0] != 513287 || headers.level[0] != 0 ||
        headers.tic[0] <= 0.0f || headers.bpint[0] <= 0.0f)
      return 7;
    const auto public_spectrum = public_file.get_spectrum(0);
    if (public_spectrum.binary_arrays_count != 2 || public_spectrum.binary_data.size() != 2 ||
        public_spectrum.binary_data[0].size() != 513287 || public_spectrum.binary_data[1][33] != 16.0f)
      return 8;
    return 0;
  }
  catch (const std::exception &error)
  {
    std::cerr << error.what() << '\n';
    return 4;
  }
}
