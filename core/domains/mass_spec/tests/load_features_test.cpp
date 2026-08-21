#include <filesystem>
#include <iostream>
#include <exception>

#include "streamfind/mass_spec/register.hpp"
#include "streamfind/project.hpp"

#ifndef STREAMFIND_BASIC_TOF_DATA_ROOT
#error STREAMFIND_BASIC_TOF_DATA_ROOT is required
#endif

int run_load_features_test() {
    const auto fail = [](const char *check) {
        std::cerr << "load_features test failed: " << check << "\n";
        return 1;
    };
    streamfind::MethodRegistry registry;
    streamfind::mass_spec::register_methods(registry);

    // Registration sanity: both new methods must be wired to an executor.
    if (!registry.find("mass_spec.load_features_ms1")) return fail("mass_spec.load_features_ms1 registration");
    if (!registry.find("mass_spec.load_features_ms2")) return fail("mass_spec.load_features_ms2 registration");

    const auto tof = std::filesystem::path(STREAMFIND_BASIC_TOF_DATA_ROOT);
    const auto r001 = tof / "00_tof_s_is_pos_cent-r001.mzML";
    const auto r002 = tof / "00_tof_s_is_pos_cent-r002.mzML";
    const auto r003 = tof / "00_tof_s_is_pos_cent-r003.mzML";
    const streamfind::Json analysis_names = streamfind::Json::array({
        r001.stem().string(), r002.stem().string(), r003.stem().string()
    });

    const auto database = std::filesystem::current_path() / "streamfind-load-features-test.duckdb";
    std::error_code error;
    std::filesystem::remove(database, error);
    auto project = streamfind::Project::create({database, "load-features-test", std::nullopt, false, false, "mass_spec"});

    const streamfind::Json analyses = streamfind::Json::array({
        streamfind::Json{{"path", r001.string()}},
        streamfind::Json{{"path", r002.string()}},
        streamfind::Json{{"path", r003.string()}}
    });
    streamfind::OperationRegistry operations;
    streamfind::mass_spec::register_operations(operations);
    const auto add_result = project.run_operation("mass_spec.add_analyses", {{"analyses", analyses}}, operations);
    if (add_result.at("row_count") != 3) return fail("add_analyses");

    // Detect features around Metoprolol-D7 (m/z ~268.19, rt ~911 s in this fixture).
    const streamfind::Json nta_parameters = {
        {"analysis_names", analysis_names},
        {"rt_windows_min", streamfind::Json::array({streamfind::Json(900.0)})},
        {"rt_windows_max", streamfind::Json::array({streamfind::Json(925.0)})},
        {"ppm_threshold", 12.0}, {"noise_threshold", 500.0}, {"min_snr", 15.0},
        {"min_traces", 5}, {"baseline_window", 30.0}, {"max_feature_width", 60.0}, {"base_quantile", 0.1}
    };
    streamfind::Workflow nta_workflow; nta_workflow.domain = "mass_spec";
    nta_workflow.steps.push_back({"mass_spec.find_features", streamfind::ParameterValues::from_json(nta_parameters)});
    project.set_workflow(std::move(nta_workflow), registry);
    project.run_method("mass_spec.find_features", nta_parameters, registry);

    const auto metoprolol = project.query_json(
        "SELECT COUNT(*) AS count FROM MASS_SPEC_NTA_FEATURES WHERE ABS(mz - 268.19) < 0.01");
    if (metoprolol.at(0).at("count").get<std::string>() == "0") {
        const auto all = project.query_json("SELECT COUNT(*) AS count FROM MASS_SPEC_NTA_FEATURES");
        std::cerr << "no feature near m/z 268.19 (total features: " << all.at(0).at("count").dump() << ")\n";
        return fail("Metoprolol-D7 feature detection");
    }

    // MS1 loading
    const streamfind::Json ms1_params = {
        {"analysis_names", analysis_names}, {"filtered", false},
        {"rt_window", streamfind::Json::array({streamfind::Json(0.0), streamfind::Json(0.0)})},
        {"mz_window", streamfind::Json::array({streamfind::Json(0.0), streamfind::Json(0.0)})},
        {"min_traces_intensity", 0.0}, {"mz_clust", 0.003}, {"presence", 0.8}
    };
    streamfind::Workflow ms1_workflow; ms1_workflow.domain = "mass_spec";
    ms1_workflow.steps.push_back({"mass_spec.load_features_ms1", streamfind::ParameterValues::from_json(ms1_params)});
    project.set_workflow(std::move(ms1_workflow), registry);
    project.run_method("mass_spec.load_features_ms1", ms1_params, registry);
    const auto ms1 = project.query_json(
        "SELECT COUNT(*) AS count FROM MASS_SPEC_NTA_FEATURES WHERE ABS(mz - 268.19) < 0.01 "
        "AND ms1_size > 0 AND ms1_mz != '' AND ms1_intensity != ''");
    if (ms1.at(0).at("count").get<std::string>() == "0") return fail("MS1 spectrum population");

    // MS2 loading
    const streamfind::Json ms2_params = {
        {"analysis_names", analysis_names}, {"filtered", false},
        {"min_traces_intensity", 0.0}, {"isolation_window", 1.3},
        {"mz_clust", 0.003}, {"presence", 0.8}
    };
    streamfind::Workflow ms2_workflow; ms2_workflow.domain = "mass_spec";
    ms2_workflow.steps.push_back({"mass_spec.load_features_ms2", streamfind::ParameterValues::from_json(ms2_params)});
    project.set_workflow(std::move(ms2_workflow), registry);
    project.run_method("mass_spec.load_features_ms2", ms2_params, registry);
    const auto ms2 = project.query_json(
        "SELECT COUNT(*) AS count FROM MASS_SPEC_NTA_FEATURES WHERE ABS(mz - 268.19) < 0.01 "
        "AND ms2_size > 0 AND ms2_mz != '' AND ms2_intensity != ''");
    if (ms2.at(0).at("count").get<std::string>() == "0") return fail("MS2 spectrum population");

    const auto summary = project.query_json(
        "SELECT analysis, feature, mz, rt, ms1_size, ms2_size FROM MASS_SPEC_NTA_FEATURES WHERE ABS(mz - 268.19) < 0.01 ORDER BY analysis");
    std::cout << "Metoprolol-D7 features (m/z ~268.19):\n" << summary.dump(2) << "\n";

    std::filesystem::remove(database, error);
    return 0;
}

int main() {
    try {
        return run_load_features_test();
    } catch (const std::exception &exception) {
        std::cerr << "load_features test exception: " << exception.what() << "\n";
        return 1;
    } catch (...) {
        std::cerr << "load_features test exception: unknown\n";
        return 1;
    }
}
