#pragma once

#include <string>
#include <vector>

namespace mass_spec
{
  namespace api { class PROJECT_MASS_SPEC_CHROMATOGRAMS; }

  namespace processing
  {

    struct LOAD_CHROMATOGRAMS_REQUEST
    {
      std::vector<std::string> analyses;
      std::vector<std::string> chromatogram_id_regex;
      bool ignore_case = true;
      bool invert = false;
    };

    struct FILTER_CHROMATOGRAMS_RT_REQUEST
    {
      std::vector<std::string> analyses;
      double rtmin = 0.0;
      double rtmax = 0.0;
    };

    struct MS_CHROMATOGRAM_ROW
    {
      std::string project_id;
      std::string analysis;
      std::string chromatogram_id;
      double rt = 0.0;
      double raw_intensity = 0.0;
      double baseline = 0.0;
      double intensity = 0.0;
    };

    bool load_chromatograms(
        api::PROJECT_MASS_SPEC_CHROMATOGRAMS &project,
        const LOAD_CHROMATOGRAMS_REQUEST &request);

    bool filter_chromatograms_retention_time(
        api::PROJECT_MASS_SPEC_CHROMATOGRAMS &project,
        const FILTER_CHROMATOGRAMS_RT_REQUEST &request);

    std::vector<MS_CHROMATOGRAM_ROW> get_chromatograms(
        api::PROJECT_MASS_SPEC_CHROMATOGRAMS &project,
        const std::vector<std::string> &analyses);

  } // namespace processing
} // namespace mass_spec
