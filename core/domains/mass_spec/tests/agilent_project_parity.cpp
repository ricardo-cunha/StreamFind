#include "streamfind/mass_spec/mass_spec.hpp"
#include "streamfind/project.hpp"
#include "../../../tests/tmp_projects.hpp"

#include <filesystem>
#include <iostream>
#include <string>

#ifndef STREAMFIND_AGILENT_MASS_HUNTER_PROJECT_FIXTURE
#error STREAMFIND_AGILENT_MASS_HUNTER_PROJECT_FIXTURE is required
#endif
#ifndef STREAMFIND_AGILENT_CHEMSTATION_PROJECT_FIXTURE
#error STREAMFIND_AGILENT_CHEMSTATION_PROJECT_FIXTURE is required
#endif

int main()
{
  try
  {
    const auto database = streamfind::test::tmp_projects_dir() / "streamfind-agilent-project-parity.duckdb";
    std::error_code error;
    std::filesystem::remove(database, error);
    auto project = streamfind::Project::create({database, "agilent-project-parity", std::nullopt, false, false, "mass_spec"});
    streamfind::mass_spec::Project domain(project);
    const auto add = domain.add_analyses({{"analyses", streamfind::Json::array({{{"path", STREAMFIND_AGILENT_MASS_HUNTER_PROJECT_FIXTURE}, {"replicate_name", "masshunter"}}, {{"path", STREAMFIND_AGILENT_CHEMSTATION_PROJECT_FIXTURE}, {"replicate_name", "chemstation"}}})}});
    if (add.size() != 2)
      return 1;
    const char *spectrum_columns[] = {"analysis", "index", "scan", "array_length", "level", "mode", "polarity", "configuration", "lowmz", "highmz", "bpmz", "bpint", "tic", "rt", "mobility", "window_mz", "window_mzlow", "window_mzhigh", "precursor_mz", "precursor_intensity", "precursor_charge", "activation_ce"};
    const char *chromatogram_columns[] = {"analysis", "index", "chromatogram_id", "array_length", "polarity", "precursor_mz", "activation_ce", "product_mz", "signal_type", "chromatogram_type", "detector", "channel", "units", "wavelength_nm", "interval_ms", "start_time", "end_time", "intensity_multiplier"};
    const auto headers = domain.get_spectra_headers();
    const auto chromatogram_headers = domain.get_chromatograms_headers();
    if (headers.empty() || chromatogram_headers.empty())
      return 2;
    for (const auto &row : headers)
      for (const auto *column : spectrum_columns)
        if (!row.contains(column) || row.at(column).is_null()) return 3;
    for (const auto &row : chromatogram_headers)
      for (const auto *column : chromatogram_columns)
        if (!row.contains(column) || row.at(column).is_null()) return 4;
    const auto parameters = streamfind::Json{{"targets", streamfind::Json::array({{{"id", "first"}, {"polarity", streamfind::Json::array({0})}, {"levels", streamfind::Json::array({1})}, {"mz_min", 100.0}, {"mz_max", 5000.0}, {"rt_min", 0.0}, {"rt_max", 10000.0}}})}};
    const auto raw = domain.get_raw_spectra(parameters);
    const auto eic = domain.get_raw_spectra_eic(parameters);
    auto ms1_parameters = parameters; ms1_parameters["mz_clust"] = 0.003; ms1_parameters["presence"] = 0.0;
    const auto ms1 = domain.get_raw_spectra_ms1(ms1_parameters);
    auto ms2_parameters = ms1_parameters; ms2_parameters["isolation_window"] = 1.3;
    const auto ms2 = domain.get_raw_spectra_ms2(ms2_parameters);
    const char *raw_columns[] = {"analysis", "replicate", "target_id", "id", "polarity", "level", "pre_mz", "pre_mzlow", "pre_mzhigh", "pre_ce", "rt", "mobility", "mz", "intensity"};
    for (const auto *rows : {&raw, &eic, &ms1, &ms2})
      for (const auto &row : *rows)
        for (const auto *column : raw_columns)
          if (!row.contains(column) || row.at(column).is_null()) return 5;
    std::filesystem::remove(database, error);
    return 0;
  }
  catch (const std::exception &exception)
  {
    std::cerr << exception.what() << '\n';
    return 6;
  }
}
