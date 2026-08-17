#include <filesystem>
#include <iostream>
#include <exception>
#include <fstream>
#include <set>
#include <sstream>

#include "streamfind/mass_spec/register.hpp"
#include "streamfind/project.hpp"
#include "streamfind/raman/register.hpp"
#include "streamfind/sensors/register.hpp"

int run_domain_smoke() {
    const auto fail = [](const char *check) {
        std::cerr << "domain smoke failed: " << check << "\n";
        return 1;
    };
    streamfind::MethodRegistry registry;
    streamfind::OperationRegistry operations;
    streamfind::mass_spec::register_operations(operations);
    streamfind::mass_spec::register_methods(registry);
    streamfind::raman::register_methods(registry);
    streamfind::sensors::register_methods(registry);
    if (operations.list("mass_spec").size() != 19) return fail("mass_spec registration");
    if (operations.find("mass_spec.get_spectra_headers")->definition().parameters.definitions.size() != 3) return fail("spectra headers parameters");
    if (operations.find("mass_spec.get_chromatograms_headers")->definition().parameters.definitions.size() != 3) return fail("chromatogram headers parameters");
    if (operations.find("mass_spec.get_spectra_tic")->definition().parameters.definitions.size() != 6) return fail("spectra TIC parameters");
    if (operations.find("mass_spec.get_chromatograms")->definition().parameters.definitions.size() != 4) return fail("chromatogram parameters");
    if (operations.find("mass_spec.get_raw_chromatograms")->definition().parameters.definitions.size() != 4) return fail("raw chromatogram parameters");
    if (operations.find("mass_spec.get_raw_spectra")->definition().parameters.definitions.size() != 9) return fail("raw spectra parameters");
    if (operations.find("mass_spec.get_raw_spectra_ms1")->definition().parameters.definitions.size() != 12) return fail("MS1 parameters");
    if (operations.find("mass_spec.get_raw_spectra_ms2")->definition().parameters.definitions.size() != 13) return fail("MS2 parameters");
    if (registry.list("raman").size() != 2) return fail("raman registration");
    if (!operations.find("mass_spec.add_analyses")) return fail("mass_spec.add_analyses registration");
    if (!registry.find("mass_spec.load_chromatograms")) return fail("mass_spec.load_chromatograms registration");
    if (!registry.find("mass_spec.filter_chromatograms_retention_time")) return fail("mass_spec.filter_chromatograms_retention_time registration");
    if (!registry.find("raman.remove_analyses")) return fail("raman.remove_analyses registration");
    if (!registry.list("sensors").empty()) return fail("sensors registration");

    const auto data = std::filesystem::path(STREAMFIND_MASS_SPEC_DATA_ROOT);
    const auto wastewater = data / "wastewater";
    const auto r001 = wastewater / "01_tof_ww_is_pos_blank-r001.mzML";
    const auto r002 = wastewater / "01_tof_ww_is_pos_blank-r002.mzML";
    const auto r003 = wastewater / "01_tof_ww_is_pos_blank-r003.mzML";
    const auto database = std::filesystem::temp_directory_path() / "streamfind-mass-spec-domain-smoke.duckdb";
    std::error_code error;
    std::filesystem::remove(database, error);
    auto project = streamfind::Project::create({database, "mass-spec-smoke", std::nullopt, false, false, "mass_spec"});

    const streamfind::Json analyses = streamfind::Json::array({
        streamfind::Json{{"path", r001.string()}},
        streamfind::Json{{"path", r002.string()}},
        streamfind::Json{{"path", r003.string()}}
    });
    const auto added = project.run_operation("mass_spec.add_analyses", {{"analyses", analyses}}, operations);
    if (added.at("row_count") != 3 || added.at("columns").at("analysis").size() != 3) {
        std::cerr << "add_analyses returned " << added.dump() << "\n";
        return 1;
    }
    const auto initial_info = project.run_operation("mass_spec.get_analyses_info", {}, operations);
    if (initial_info.at("row_count") != 3) {
        std::cerr << "initial get_analyses_info returned " << initial_info.dump() << "\n";
        return 1;
    }
    project.run_operation("mass_spec.set_replicate_names", {{"replicate_names", streamfind::Json::array({"r1", "r2", "r3"})}}, operations);

    streamfind::Json targets = streamfind::Json::array();
    std::ifstream standards(wastewater / "internal_standards.csv");
    std::string line;
    std::getline(standards, line);
    while (std::getline(standards, line)) {
        std::stringstream fields(line);
        std::string name, formula, mass, rt;
        std::getline(fields, name, ',');
        std::getline(fields, formula, ',');
        std::getline(fields, mass, ',');
        std::getline(fields, rt, ',');
        if (!mass.empty() && !rt.empty()) targets.push_back({{"id", name}, {"analyses", streamfind::Json::array({r001.stem().string()})}, {"mass", std::stod(mass)}, {"rt", std::stod(rt)}, {"polarity", 1}});
    }
    const auto eic = project.run_operation("mass_spec.get_raw_spectra_eic", {{"targets", targets}, {"rt_tolerance", 60.0}}, operations);
    if (eic.empty()) {
        std::cerr << "multi-target EIC returned no rows\n";
        return 1;
    }
    std::set<std::string> target_ids;
    for (const auto &value : eic.at("columns").at("target_id")) target_ids.insert(value.get<std::string>());
    if (target_ids.size() <= 1) {
        std::cerr << "multi-target EIC returned only one target\n";
        return 1;
    }
    if (target_ids.size() != 8 || eic.at("columns").at("target_id").front() != "Carbamazepine-D10" ||
        eic.at("columns").at("id").front() != "01_tof_ww_is_pos_blank-r001:1006" ||
        eic.at("columns").at("replicate").front() != "r1" ||
        eic.at("columns").at("mz").front() != 247.16661071777344) {
        std::cerr << "multi-target EIC output does not match Rust contract\n";
        return 1;
    }
    const auto ms1 = project.run_operation("mass_spec.get_raw_spectra_ms1", {{"targets", targets}, {"ppm", 20.0}, {"rt_tolerance", 60.0}, {"mz_clust", 0.003}, {"presence", 0.8}, {"min_intensity_ms1", 1000.0}}, operations);
    if (ms1.empty()) return fail("MS1 aggregation");
    for (const auto &value : ms1.at("columns").at("level")) if (value != 1) return fail("MS1 aggregation filter");
    for (const auto &value : ms1.at("columns").at("intensity")) if (value < 1000.0) return fail("MS1 aggregation filter");
    const auto ms2 = project.run_operation("mass_spec.get_raw_spectra_ms2", {{"targets", targets}, {"ppm", 20.0}, {"rt_tolerance", 60.0}, {"isolation_window", 1.3}, {"mz_clust", 0.005}, {"presence", 0.0}}, operations);
    if (ms2.empty()) return fail("MS2 aggregation");
    for (const auto &value : ms2.at("columns").at("level")) if (value != 2) return fail("MS2 aggregation filter");
    streamfind::Json preview = streamfind::Json::array();
    for (std::size_t i = 0; i < eic.at("row_count") && i < 5; ++i) preview.push_back(i);
    std::cout << "multi-target EIC target count: " << target_ids.size() << "\nfirst rows:\n" << preview.dump(2) << "\n";

    project.run_operation("mass_spec.remove_analyses", {{"analysis_names", streamfind::Json::array({r003.stem().string()})}}, operations);
    const auto remaining_info = project.run_operation("mass_spec.get_analyses_info", {}, operations);
    if (remaining_info.at("row_count") != 2) {
        std::cerr << "remaining get_analyses_info returned " << remaining_info.dump() << "\n";
        return 1;
    }

    const auto karl = data / "shimadzu" / "karl.mzML";
    project.run_operation("mass_spec.add_analyses", { {"analyses", streamfind::Json::array({streamfind::Json{{"path", karl.string()}}})} }, operations);
    const auto raw_chromatograms = project.run_operation("mass_spec.get_raw_chromatograms", {{"analysis_names", streamfind::Json::array({"karl"})}, {"indices", streamfind::Json::array({0})}}, operations);
    if (raw_chromatograms.at("row_count") != 695) return fail("raw chromatograms");
    project.run_method("mass_spec.load_chromatograms", { {"analysis_names", streamfind::Json::array({"karl"})}, {"chromatogram_id_regex", streamfind::Json::array({"^TIC1$"})}, {"ignore_case", true}, {"invert", false} }, registry);
    const auto chromatograms = project.run_operation("mass_spec.get_chromatograms", { {"analysis_names", streamfind::Json::array({"karl"})} }, operations);
    if (chromatograms.at("row_count") != 695) return fail("chromatogram loading");
    const auto rt_min = chromatograms.at("columns").at("rt").at(0).get<double>();
    const auto rt_max = chromatograms.at("columns").at("rt").at(2).get<double>();
    project.run_method("mass_spec.filter_chromatograms_retention_time", { {"analysis_names", streamfind::Json::array({"karl"})}, {"rt_min", rt_min}, {"rt_max", rt_max} }, registry);
    const auto filtered = project.run_operation("mass_spec.get_chromatograms", { {"analysis_names", streamfind::Json::array({"karl"})} }, operations);
    if (filtered.at("row_count") == 0 || filtered.at("columns").at("rt").back().get<double>() > rt_max) return fail("chromatogram retention filtering");
    std::filesystem::remove(database, error);
    return 0;
}

int main() {
    try {
        return run_domain_smoke();
    } catch (const std::exception &exception) {
        std::cerr << "domain smoke exception: " << exception.what() << "\n";
        return 1;
    } catch (...) {
        std::cerr << "domain smoke exception: unknown\n";
        return 1;
    }
}
