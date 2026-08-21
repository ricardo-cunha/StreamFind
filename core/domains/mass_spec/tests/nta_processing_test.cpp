#include <filesystem>
#include <iostream>
#include <exception>

#include "streamfind/mass_spec/register.hpp"
#include "streamfind/project.hpp"

#ifndef STREAMFIND_BASIC_TOF_DATA_ROOT
#error STREAMFIND_BASIC_TOF_DATA_ROOT is required
#endif

int run_nta_processing_test() {
    const auto fail = [](const char *check) {
        std::cerr << "nta_processing test failed: " << check << "\n";
        return 1;
    };
    streamfind::MethodRegistry registry;
    streamfind::mass_spec::register_methods(registry);

    // Registration sanity: every new NTA processing method must be wired to an executor.
    const char *wired[] = {
        "mass_spec.subtract_blank", "mass_spec.filter_features",
        "mass_spec.filter_features_ms2", "mass_spec.group_features",
        "mass_spec.fill_features", "mass_spec.create_components",
        "mass_spec.annotate_components", "mass_spec.suspect_screening",
        "mass_spec.find_internal_standards", "mass_spec.correct_matrix_suppression"
    };
    for (const char *id : wired)
        if (!registry.find(id)) return fail(id);

    const auto tof = std::filesystem::path(STREAMFIND_BASIC_TOF_DATA_ROOT);
    const auto r001 = tof / "00_tof_s_is_pos_cent-r001.mzML";
    const auto r002 = tof / "00_tof_s_is_pos_cent-r002.mzML";
    const auto r003 = tof / "00_tof_s_is_pos_cent-r003.mzML";
    const streamfind::Json analysis_names = streamfind::Json::array({
        r001.stem().string(), r002.stem().string(), r003.stem().string()
    });

    const auto database = std::filesystem::current_path() / "streamfind-nta-processing-test.duckdb";
    std::error_code error;
    std::filesystem::remove(database, error);
    auto project = streamfind::Project::create({database, "nta-processing-test", std::nullopt, false, false, "mass_spec"});

    const streamfind::Json analyses = streamfind::Json::array({
        streamfind::Json{{"path", r001.string()}},
        streamfind::Json{{"path", r002.string()}},
        streamfind::Json{{"path", r003.string()}}
    });
    streamfind::OperationRegistry operations;
    streamfind::mass_spec::register_operations(operations);
    const auto add_result = project.run_operation("mass_spec.add_analyses", {{"analyses", analyses}}, operations);
    if (add_result.at("row_count") != 3) return fail("add_analyses");

    auto run = [&](const std::string &id, const streamfind::Json &params) -> streamfind::Json {
        streamfind::Workflow wf; wf.domain = "mass_spec";
        wf.steps.push_back({id, streamfind::ParameterValues::from_json(params)});
        project.set_workflow(std::move(wf), registry);
        return project.run_method(id, params, registry);
    };

    // 1. find_features over the Metoprolol-D7 window.
    const streamfind::Json find_params = {
        {"analysis_names", analysis_names},
        {"rt_windows_min", streamfind::Json::array({streamfind::Json(900.0)})},
        {"rt_windows_max", streamfind::Json::array({streamfind::Json(925.0)})},
        {"ppm_threshold", 12.0}, {"noise_threshold", 500.0}, {"min_snr", 15.0},
        {"min_traces", 5}, {"baseline_window", 30.0}, {"max_feature_width", 60.0}, {"base_quantile", 0.1}
    };
    if (run("mass_spec.find_features", find_params).value("status", "") != "finished")
        return fail("find_features status");
    const auto total = project.query_json("SELECT COUNT(*) AS count FROM MASS_SPEC_NTA_FEATURES");
    if (total.at(0).at("count").get<std::string>() == "0") return fail("find_features produced no features");

    // 2. filter_features (no criteria supplied -> no-op filtering, must not crash).
    const streamfind::Json filter_params = {
        {"analysis_names", analysis_names}
    };
    if (run("mass_spec.filter_features", filter_params).value("status", "") != "finished")
        return fail("filter_features status");
    const auto remaining = project.query_json("SELECT COUNT(*) AS count FROM MASS_SPEC_NTA_FEATURES");
    if (remaining.at(0).at("count").get<std::string>() == "0") return fail("filter_features removed everything");

    // 3. create_components (needs EIC data written by find_features).
    const streamfind::Json components_params = {
        {"analysis_names", analysis_names},
        {"rt_window", streamfind::Json::array({streamfind::Json(60.0)})}, {"min_correlation", 0.8}
    };
    if (run("mass_spec.create_components", components_params).value("status", "") != "finished")
        return fail("create_components status");

    // 4. annotate_components.
    const streamfind::Json annotate_params = {
        {"analysis_names", analysis_names},
        {"max_isotopes", 10}, {"max_charge", 2}, {"max_gaps", 1}, {"ppm", 5.0},
        {"isotope_elements", streamfind::Json::array({streamfind::Json("C"), streamfind::Json("H")})}
    };
    if (run("mass_spec.annotate_components", annotate_params).value("status", "") != "finished")
        return fail("annotate_components status");

    // 5. The remaining wiring is exercised so every wired executor actually runs.
    const streamfind::Json blank_params = {
        {"analysis_names", analysis_names}, {"blank_threshold", 2.0},
        {"rt_expand", 1.0}, {"mz_expand", 0.01}
    };
    if (run("mass_spec.subtract_blank", blank_params).value("status", "") != "finished")
        return fail("subtract_blank status");

    const streamfind::Json group_params = {
        {"analysis_names", analysis_names}, {"method", "obiwarp"},
        {"rt_deviation", 10.0}, {"ppm", 5.0}, {"min_samples", 2}, {"bin_size", 5.0}
    };
    if (run("mass_spec.group_features", group_params).value("status", "") != "finished")
        return fail("group_features status");

    const streamfind::Json ms2_params = {
        {"analysis_names", analysis_names}, {"top", 0}, {"min_intensity_ms2", 0.0},
        {"rel_min_intensity", 0.0}, {"blank_clean", false}, {"mz_clust", 0.005},
        {"blank_presence_threshold", 0.8}, {"global_presence_threshold", 0.1}
    };
    if (run("mass_spec.filter_features_ms2", ms2_params).value("status", "") != "finished")
        return fail("filter_features_ms2 status");

    const streamfind::Json suspects_targets = streamfind::Json::array({
        streamfind::Json{{"id", "caffeine"}, {"mass", 194.0804}}
    });
    const streamfind::Json suspect_params = {
        {"analysis_names", analysis_names}, {"targets", suspects_targets},
        {"ppm", 5.0}, {"sec", 10.0}, {"ppm_ms2", 10.0}, {"mzr_ms2", 0.008},
        {"min_cosine_similarity", 0.7}, {"min_shared_fragments", 2}, {"filtered", false}
    };
    if (run("mass_spec.suspect_screening", suspect_params).value("status", "") != "finished")
        return fail("suspect_screening status");

    if (run("mass_spec.find_internal_standards", suspect_params).value("status", "") != "finished")
        return fail("find_internal_standards status");

    const streamfind::Json matrix_params = {
        {"analysis_names", analysis_names}, {"mp_rt_window", 60.0}, {"ref_blank_replicate", ""}
    };
    if (run("mass_spec.correct_matrix_suppression", matrix_params).value("status", "") != "finished")
        return fail("correct_matrix_suppression status");

    const streamfind::Json fill_params = {
        {"analysis_names", analysis_names}, {"within_replicate", false}, {"filtered", false},
        {"rt_expand", 1.0}, {"mz_expand", 0.01}, {"max_peak_width", 30.0},
        {"min_traces_intensity", 1000.0}, {"min_number_traces", 3}, {"min_intensity_ms1", 1000.0},
        {"rt_apex_deviation", 1.0}, {"min_signal_to_noise_ratio", 3.0}, {"min_gaussian_fit", 0.5}
    };
    if (run("mass_spec.fill_features", fill_params).value("status", "") != "finished")
        return fail("fill_features status");

    const auto surviving = project.query_json("SELECT COUNT(*) AS count FROM MASS_SPEC_NTA_FEATURES");
    std::cout << "features after pipeline: " << surviving.at(0).at("count").dump() << "\n";
    std::cout << "NTA processing pipeline completed successfully.\n";

    std::filesystem::remove(database, error);
    return 0;
}

int main() {
    try {
        return run_nta_processing_test();
    } catch (const std::exception &exception) {
        std::cerr << "nta_processing test exception: " << exception.what() << "\n";
        return 1;
    } catch (...) {
        std::cerr << "nta_processing test exception: unknown\n";
        return 1;
    }
}
