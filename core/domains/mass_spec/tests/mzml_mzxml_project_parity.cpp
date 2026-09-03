#include "streamfind/mass_spec/mass_spec.hpp"
#include "streamfind/project.hpp"
#include "../../../tests/tmp_projects.hpp"

#include <filesystem>
#include <iostream>
#include <string>

#ifndef STREAMFIND_MZML_PARITY_FIXTURE
#error STREAMFIND_MZML_PARITY_FIXTURE is required
#endif
#ifndef STREAMFIND_MZXML_PARITY_FIXTURE
#error STREAMFIND_MZXML_PARITY_FIXTURE is required
#endif

int main()
{
  try
  {
    const auto database = streamfind::test::tmp_projects_dir() / "streamfind-mzml-mzxml-project-parity.duckdb";
    std::error_code error;
    std::filesystem::remove(database, error);
    auto project = streamfind::Project::create({database, "mzml-mzxml-project-parity", std::nullopt, false, false, "mass_spec"});
    streamfind::mass_spec::Project domain(project);
    const auto add = domain.add_analyses({{"analyses", streamfind::Json::array({{{"path", STREAMFIND_MZML_PARITY_FIXTURE}}, {{"path", STREAMFIND_MZXML_PARITY_FIXTURE}}})}});
    if (add.size() != 2)
      return 1;
    const char *headers[] = {"analysis", "index", "scan", "array_length", "level", "mode", "polarity", "configuration", "lowmz", "highmz", "bpmz", "bpint", "tic", "rt", "mobility", "window_mz", "window_mzlow", "window_mzhigh", "precursor_mz", "precursor_intensity", "precursor_charge", "activation_ce"};
    const auto header_rows = domain.get_spectra_headers();
    if (header_rows.empty())
      return 2;
    for (const auto &row : header_rows)
      for (const auto *name : headers)
        if (!row.contains(name) || row.at(name).is_null())
          return 3;
    const auto parameters = streamfind::Json{{"targets", streamfind::Json::array({{{"id", "all"}, {"polarity", streamfind::Json::array({0})}, {"levels", streamfind::Json::array({1})}, {"mz_min", 100.0}, {"mz_max", 200.0}, {"rt_min", 0.0}, {"rt_max", 10000.0}}})}};
    const char *operations[] = {"get_raw_spectra", "get_raw_spectra_eic", "get_raw_spectra_ms1", "get_raw_spectra_ms2"};
    const char *raw[] = {"analysis", "target_id", "id", "polarity", "level", "pre_mz", "pre_mzlow", "pre_mzhigh", "pre_ce", "rt", "mobility", "mz", "intensity"};
    for (const auto *operation : operations)
    {
      auto result = operation == std::string("get_raw_spectra") ? domain.get_raw_spectra(parameters) : operation == std::string("get_raw_spectra_eic") ? domain.get_raw_spectra_eic(parameters) : operation == std::string("get_raw_spectra_ms1") ? domain.get_raw_spectra_ms1(parameters) : domain.get_raw_spectra_ms2(parameters);
      for (const auto &row : result)
        for (const auto *name : raw)
          if (!row.contains(name) || row.at(name).is_null())
            return 4;
    }
    std::filesystem::remove(database, error);
    return 0;
  }
  catch (const std::exception &exception)
  {
    std::cerr << exception.what() << '\n';
    return 5;
  }
}
