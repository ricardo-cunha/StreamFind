#include <filesystem>
#include <iostream>
#include <exception>
#include <fstream>
#include <set>
#include <sstream>
#include <map>

#include "streamfind/catalogue.hpp"
#include "streamfind/mass_spec/register.hpp"
#include "streamfind/project.hpp"
#include "streamfind/raman/register.hpp"
#include "streamfind/sensors/register.hpp"
#include "../tmp_projects.hpp"

#ifndef STREAMFIND_CATALOGUE_PATH
#error STREAMFIND_CATALOGUE_PATH is required
#endif

/// Map of operation id -> parameter name list, derived from the committed
/// semantic catalogue. Tests compare the registered operations against it, so
/// counts adapt automatically when the catalogue changes.
std::map<std::string, std::set<std::string>> catalogue_parameters(const streamfind::Json &entries) {
    std::map<std::string, std::set<std::string>> parameters;
    for (const auto &entry : entries) {
        std::string id = entry.value("canonical_id", "");
        std::set<std::string> names;
        for (const auto &parameter : entry.value("parameters", streamfind::Json::array())) {
            names.insert(parameter.value("name", ""));
        }
        parameters.emplace(std::move(id), std::move(names));
    }
    return parameters;
}

int run_domain_smoke() {
    const auto fail = [](const char *check) {
        std::cerr << "domain smoke failed: " << check << "\n";
        return 1;
    };
    // Expectations are derived from the committed semantic catalogue (the same
    // contract the registries are generated from), so counts adapt
    // automatically when operations/methods are added or removed.
    const auto entries = streamfind::catalogue::load(STREAMFIND_CATALOGUE_PATH);
    if (!entries) return fail("catalogue load");
    const auto catalogue = catalogue_parameters(*entries);
    const auto expected_operations = static_cast<int>(std::count_if(
        entries->begin(), entries->end(), [](const auto &entry) {
            return entry.value("kind", "") == "operation" && entry.value("domain", "") == "mass_spec";
        }));
    const auto expected_raman_methods = static_cast<int>(std::count_if(
        entries->begin(), entries->end(), [](const auto &entry) {
            return entry.value("kind", "") == "method" && entry.value("domain", "") == "raman";
        }));
    const auto expected_sensors_methods = static_cast<int>(std::count_if(
        entries->begin(), entries->end(), [](const auto &entry) {
            return entry.value("kind", "") == "method" && entry.value("domain", "") == "sensors";
        }));

    streamfind::MethodRegistry registry;
    streamfind::OperationRegistry operations;
    streamfind::mass_spec::register_operations(operations);
    streamfind::mass_spec::register_methods(registry);
    streamfind::raman::register_methods(registry);
    streamfind::sensors::register_methods(registry);
    if (operations.list("mass_spec").size() != static_cast<std::size_t>(expected_operations)) return fail("mass_spec registration");
    // Parameter shapes: every registered operation's parameter names must match
    // the catalogue contract (adapted per-operation, not hardcoded counts).
    for (const auto &definition : operations.list("mass_spec")) {
            const auto &id = definition.id;
            const auto expect = catalogue.find(id);
            if (expect == catalogue.end()) return fail("catalogue entry missing for registered operation");
            std::set<std::string> actual;
            for (const auto &parameter : definition.parameters.definitions) actual.insert(parameter.name);
            if (actual != expect->second) return fail(("parameter mismatch: " + id).c_str());
        }
    if (registry.list("raman").size() != static_cast<std::size_t>(expected_raman_methods)) return fail("raman registration");
    if (registry.list("sensors").size() != static_cast<std::size_t>(expected_sensors_methods)) return fail("sensors registration");
    if (!operations.find("mass_spec.add_analyses")) return fail("mass_spec.add_analyses registration");
    if (!registry.find("mass_spec.load_chromatograms")) return fail("mass_spec.load_chromatograms registration");
    if (!registry.find("mass_spec.filter_chromatograms_retention_time")) return fail("mass_spec.filter_chromatograms_retention_time registration");
    if (!registry.find("mass_spec.find_features")) return fail("mass_spec.find_features registration");
    const auto *find_features = registry.find("mass_spec.find_features");
    if (!find_features->definition().cacheable || !find_features->definition().single_occurrence || !find_features->definition().required_methods.empty()) return fail("find_features lifecycle metadata");
    if (!registry.find("raman.remove_analyses")) return fail("raman.remove_analyses registration");

    const auto data = std::filesystem::path(STREAMFIND_MASS_SPEC_DATA_ROOT);
    const auto wastewater = data / "wastewater";
    const auto r001 = wastewater / "01_tof_ww_is_pos_blank-r001.mzML";
    const auto r002 = wastewater / "01_tof_ww_is_pos_blank-r002.mzML";
    const auto r003 = wastewater / "01_tof_ww_is_pos_blank-r003.mzML";
    const auto database = streamfind::test::tmp_projects_dir() / "streamfind-mass-spec-domain-smoke.duckdb";
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
    const streamfind::Json nta_parameters = { {"analysis_names", streamfind::Json::array({r001.stem().string(), r002.stem().string(), r003.stem().string()})}, {"rt_windows_min", streamfind::Json::array({streamfind::Json(800.0)})}, {"rt_windows_max", streamfind::Json::array({streamfind::Json(1000.0)})}, {"ppm_threshold", 12.0}, {"noise_threshold", 500.0}, {"min_snr", 15.0}, {"min_traces", 5}, {"baseline_window", 30.0}, {"max_feature_width", 60.0}, {"base_quantile", 0.1} };
    streamfind::Workflow nta_workflow; nta_workflow.domain = "mass_spec"; nta_workflow.steps.push_back({"mass_spec.find_features", streamfind::ParameterValues::from_json(nta_parameters)}); project.set_workflow(std::move(nta_workflow), registry);
    project.run_method("mass_spec.find_features", nta_parameters, registry);
    if (project.query_json("SELECT COUNT(*) AS count FROM MASS_SPEC_NTA_FEATURES").at(0).at("count") == 0) return fail("feature detection");
    const auto metoprolol = project.query_json("SELECT COUNT(*) AS count FROM MASS_SPEC_NTA_FEATURES WHERE ABS(mass - 274.227) < 0.01 AND ABS(rt - 915.0) < 5.0");
    if (metoprolol.at(0).at("count").get<std::string>() != "3") return fail("Metoprolol-D7 feature detection");
    const auto features = project.run_operation("mass_spec.get_features", {
        {"analysis_names", streamfind::Json::array({r001.stem().string(), r002.stem().string(), r003.stem().string()})},
        {"targets", streamfind::Json::array({{{"id", "Metoprolol-D7"}, {"mass", 274.227}, {"rt", 915.0}, {"polarity", 1}}})},
        {"ppm", 20.0}, {"rt_tolerance", 5.0}}, operations);
    if (features.at("row_count") != 3 || !features.at("columns").contains("feature") || !features.at("columns").contains("component_bridge_flag")) return fail("NTA feature table result");
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

    const auto shimadzu = std::filesystem::path(STREAMFIND_SHIMADZU_DATA_ROOT);
    const auto karl = shimadzu / "karl.mzML";
    if (shimadzu.empty() || !std::filesystem::exists(karl)) {
        std::cerr << "Shimadzu external fixtures unavailable; skipping Shimadzu domain checks\n";
        std::filesystem::remove(database, error);
        return 0;
    }
    project.run_operation("mass_spec.add_analyses", { {"analyses", streamfind::Json::array({streamfind::Json{{"path", karl.string()}}})} }, operations);
    const auto raw_chromatograms = project.run_operation("mass_spec.get_raw_chromatograms", {{"analysis_names", streamfind::Json::array({"karl"})}, {"indices", streamfind::Json::array({0})}}, operations);
    if (raw_chromatograms.at("row_count") != 695) return fail("raw chromatograms");
    const auto load_parameters = streamfind::Json{{"analysis_names", streamfind::Json::array({"karl"})}, {"chromatogram_id_regex", streamfind::Json::array({"^TIC1$"})}, {"ignore_case", true}, {"invert", false}}; streamfind::Workflow load_workflow; load_workflow.domain = "mass_spec"; load_workflow.steps.push_back({"mass_spec.load_chromatograms", streamfind::ParameterValues::from_json(load_parameters)}); project.set_workflow(std::move(load_workflow), registry); project.run_method("mass_spec.load_chromatograms", load_parameters, registry);
    const auto chromatograms = project.run_operation("mass_spec.get_chromatograms", { {"analysis_names", streamfind::Json::array({"karl"})} }, operations);
    if (chromatograms.at("row_count") != 695) return fail("chromatogram loading");
    const auto rt_min = chromatograms.at("columns").at("rt").at(0).get<double>();
    const auto rt_max = chromatograms.at("columns").at("rt").at(2).get<double>();
    const auto filter_parameters = streamfind::Json{{"analysis_names", streamfind::Json::array({"karl"})}, {"rt_min", rt_min}, {"rt_max", rt_max}}; streamfind::Workflow filter_workflow; filter_workflow.domain = "mass_spec"; filter_workflow.steps.push_back({"mass_spec.filter_chromatograms_retention_time", streamfind::ParameterValues::from_json(filter_parameters)}); project.set_workflow(std::move(filter_workflow), registry); project.run_method("mass_spec.filter_chromatograms_retention_time", filter_parameters, registry);
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
