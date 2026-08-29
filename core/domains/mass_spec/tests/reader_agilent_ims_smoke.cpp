#include "streamfind/mass_spec/reader_agilent.hpp"

#include <cmath>
#include <cstdlib>
#include <iostream>

int main()
{
  try
  {
    const char *fixture = std::getenv("STREAMFIND_AGILENT_IMS_FIXTURE");
    if (fixture == nullptr || *fixture == '\0')
      return 11;
    if (!mass_spec::reader::agilent::is_agilent_ion_mobility_directory(fixture))
      return 1;
    const auto frames = mass_spec::reader::agilent::read_ims_frame_records(fixture);
    if (frames.size() != 103 || frames.front().frame_id != 1 || frames.back().frame_id != 103)
      return 2;
    const auto &first = frames.front();

    if (first.frame_method_id != 1 || first.time_segment_id != 1 || first.first_nonzero_drift_bin != 1 ||
        first.frame_base_abundance != 55227.0 || first.frame_base_drift_bin != 152 ||
        first.frame_base_ms_bin != 145591 || std::fabs(first.frame_scan_time_minutes - 0.05143333333333333) > 1e-12 ||
        first.frame_tic != 15541141.0 || std::fabs(first.ims_pressure - 3.94) > 1e-6 ||
        std::fabs(first.ims_temperature - 26.0) > 1e-12 || std::fabs(first.ims_trap_time - 20000.0) > 1e-9 ||
        first.last_nonzero_drift_bin != 366 || first.num_transients != 19)
      return 3;
    if (std::fabs(frames.back().frame_scan_time_minutes - 1.99808333333333) > 1e-12)
      return 4;
    return 0;
  }
  catch (const std::exception &error)
  {
    std::cerr << error.what() << '\n';
    return 10;
  }
}
