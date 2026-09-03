#include "streamfind/mass_spec/mass_spec.hpp"
#include "streamfind/project.hpp"
#include "../../../tests/tmp_projects.hpp"

#include <filesystem>
#include <iostream>
#include <string>
#include <vector>

int main()
{
  try
  {
    const auto root = std::filesystem::path(STREAMFIND_TEST_DATA_ROOT) / "mass_spec/wastewater";
    const std::vector<std::filesystem::path> files = {
        root / "01_tof_ww_is_pos_blank-r001.mzML",
        root / "01_tof_ww_is_pos_blank-r002.mzML",
        root / "01_tof_ww_is_pos_blank-r003.mzML"};
    const auto database = streamfind::test::tmp_projects_dir() / "streamfind-indexed-persistence.duckdb";
    std::error_code error;
    std::filesystem::remove(database, error);
    auto project = streamfind::Project::create({database, "indexed-persistence", std::nullopt, false, false, "mass_spec"});
    streamfind::mass_spec::Project domain(project);
    streamfind::Json analyses = streamfind::Json::array();
    for (const auto &file : files)
      analyses.push_back({{"path", file.string()}});
    if (domain.add_analyses({{"analyses", analyses}}).size() != files.size())
      return 1;
    const auto names = domain.get_analysis_names();
    if (names.size() != files.size())
      return 2;
    const auto selected = names.at(1).get<std::string>();
    const auto indexed = domain.get_raw_spectra({
        {"analysis_names", streamfind::Json::array({selected})},
        {"indices", streamfind::Json::array({0})},
        {"targets", streamfind::Json::array({{{"mz_min", 99999.0}, {"mz_max", 100000.0}}})}});
    if (indexed.empty())
      return 3;
    for (const auto &row : indexed)
    {
      if (row.at("analysis") != selected || row.at("target_id") != "spectrum:0")
        return 4;
    }
    const auto multiple = domain.get_raw_spectra({
        {"analysis_names", streamfind::Json::array({selected})},
        {"indices", streamfind::Json::array({0, 1})},
        {"levels", streamfind::Json::array({1})}});
    if (multiple.size() < indexed.size())
      return 10;
    for (const auto &row : multiple)
      if (row.at("target_id") != "spectrum:0" && row.at("target_id") != "spectrum:1")
        return 11;
    bool rejected = false;
    try
    {
      domain.get_raw_spectra({{"analysis_names", streamfind::Json::array({selected})}, {"indices", streamfind::Json::array({999999})}});
    }
    catch (const std::exception &)
    {
      rejected = true;
    }
    if (!rejected)
      return 12;
    const auto first_mz = indexed.front().at("mz").get<double>();
    const auto first_rt = indexed.front().at("rt").get<double>();
    const auto first_level = indexed.front().at("level").get<int>();
    const auto fallback = domain.get_raw_spectra({
        {"analysis_names", streamfind::Json::array({selected})},
        {"indices", streamfind::Json::array()},
        {"targets", streamfind::Json::array({{{"id", "first"}, {"mz_min", first_mz - 0.001}, {"mz_max", first_mz + 0.001}, {"rt_min", first_rt - 0.001}, {"rt_max", first_rt + 0.001}, {"polarity", streamfind::Json::array({0})}, {"levels", streamfind::Json::array({first_level})}}})}});
    if (fallback.empty())
      return 5;
    for (const auto &row : fallback)
      if (row.at("analysis") != selected || row.at("target_id") != "first")
        return 6;
    const auto omitted = domain.get_raw_spectra({
        {"analysis_names", streamfind::Json::array({selected})},
        {"targets", streamfind::Json::array({{{"id", "first"}, {"mz_min", first_mz - 0.001}, {"mz_max", first_mz + 0.001}, {"rt_min", first_rt - 0.001}, {"rt_max", first_rt + 0.001}, {"polarity", streamfind::Json::array({0})}, {"levels", streamfind::Json::array({first_level})}}})}});
    if (omitted.size() != fallback.size())
      return 13;
    project = streamfind::Project::open({database, "indexed-persistence", std::nullopt, false, false, "mass_spec"});
    streamfind::mass_spec::Project reopened(project);
    if (reopened.get_analysis_names() != names)
      return 7;
    const auto reopened_indexed = reopened.get_raw_spectra({
        {"analysis_names", streamfind::Json::array({selected})},
        {"indices", streamfind::Json::array({0})}});
    if (reopened_indexed.size() != indexed.size())
      return 8;
    std::filesystem::remove(database, error);
    return 0;
  }
  catch (const std::exception &exception)
  {
    std::cerr << exception.what() << '\n';
    return 9;
  }
}
