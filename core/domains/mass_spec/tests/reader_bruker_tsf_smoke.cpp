#include "streamfind/mass_spec/reader_bruker.hpp"
#include <algorithm>
#include <cmath>
#include <iostream>

int main()
{
  try
  {
    const std::string path = "E:/example_files/ms_merck/Beispieldaten Routine/ACC1_28127_1_blank_P1-A-1_1_2022_13602.d";
    if (mass_spec::reader::bruker::detect_family(path) != mass_spec::reader::bruker::Family::Tsf)
      return 1;
    const auto frames = mass_spec::reader::bruker::read_tsf_frames(path);
    if (frames.size() != 4451 || frames[0].id != 1 || frames[0].polarity != "+" ||
        std::fabs(frames[0].retention_time - 0.5966953) > 1e-7 ||
        frames[0].num_peaks != 1561 || frames[0].summed_intensities != 47320.0)
      return 2;
    const auto msms = mass_spec::reader::bruker::read_tsf_msms_info(path);
    if (msms.size() != 2556 || msms[0].frame != 98 || msms[0].parent != 97 ||
        std::fabs(msms[0].trigger_mass - 922.0137960978609) > 1e-9 ||
        msms[0].precursor_charge != 1)
      return 3;
    const auto calibration = mass_spec::reader::bruker::read_tsf_calibration(path, frames.front());
    if (calibration.id != 1 || calibration.model_type != 1 || calibration.tof_max != 513299 ||
        calibration.mz_min != 100.0 || calibration.mz_max != 2500.0 || calibration.c1 <= 154000.0)
      return 4;
    const auto mz = mass_spec::reader::bruker::tsf_tof_to_mz(calibration, {0.0, 344.7142857142857, 513299.0});
    if (std::fabs(mz[0] - 95.0) > 1e-9 || std::fabs(mz[1] - 95.52835104408595) > 1e-9 ||
        std::fabs(mz[2] - 2505.0) > 1e-9)
      return 5;
    const auto line = mass_spec::reader::bruker::read_tsf_line_spectrum(path, frames.front());
    if (line.tof.size() != 1561 || line.intensity.size() != 1561 ||
        std::fabs(line.tof.front() - 344.7142857142857) > 1e-12 ||
        line.intensity.front() != 50.0 ||
        *std::max_element(line.intensity.begin(), line.intensity.end()) != 908.0)
      return 6;
    mass_spec::reader::MASS_SPEC_FILE public_file(path);
    if (public_file.get_format() != "BrukerTSF" || public_file.get_number_spectra() != 4451)
      return 7;
    const auto public_spectrum = public_file.get_spectrum(0);
    if (public_spectrum.binary_arrays_count != 2 || public_spectrum.binary_data.size() != 2 ||
        public_spectrum.binary_data[0].size() != 1561 || public_spectrum.binary_data[1].size() != 1561 ||
        std::fabs(public_spectrum.binary_data[0][0] - 95.528351f) > 1e-4f ||
        public_spectrum.binary_data[1][0] != 50.0f)
      return 8;
    return 0;
  }
  catch (const std::exception &error)
  {
    std::cerr << error.what() << '\n';
    return 4;
  }
}
