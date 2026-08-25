#include <filesystem>
#include <fstream>
#include <iostream>
#include <exception>
#include <sstream>
#include <string>
#include <vector>

#include "streamfind/mass_spec/register.hpp"
#include "streamfind/project.hpp"

#ifndef STREAMFIND_WASTEWATER_DATA_ROOT
#error STREAMFIND_WASTEWATER_DATA_ROOT is required
#endif

namespace {

// Minimal RFC-4180-ish CSV parser (handles double-quoted fields). The returned
// rows include the header row as element 0.
std::vector<std::vector<std::string>> parse_csv(const std::string &path) {
    std::ifstream in(path);
    std::vector<std::vector<std::string>> rows;
    std::string line;
    if (!in) return rows;
    while (std::getline(in, line)) {
        if (line.empty()) continue;
        std::vector<std::string> fields;
        std::string cur;
        bool in_quotes = false;
        for (size_t i = 0; i < line.size(); ++i) {
            const char c = line[i];
            if (in_quotes) {
                if (c == '"' && i + 1 < line.size() && line[i + 1] == '"') { cur += '"'; ++i; }
                else if (c == '"') in_quotes = false;
                else cur += c;
            } else {
                if (c == '"') in_quotes = true;
                else if (c == ',') { fields.push_back(cur); cur.clear(); }
                else cur += c;
            }
        }
        fields.push_back(cur);
        rows.push_back(std::move(fields));
    }
    return rows;
}

int col_index(const std::vector<std::string> &header, const std::string &name) {
    for (size_t i = 0; i < header.size(); ++i) if (header[i] == name) return static_cast<int>(i);
    return -1;
}

// Parse an "mz int; mz int; ..." fragment string into parallel m/z and intensity vectors.
void parse_fragments(const std::string &text, streamfind::Json &mz, streamfind::Json &intensity) {
    std::istringstream ss(text);
    std::string token;
    while (std::getline(ss, token, ';')) {
        std::istringstream ts(token);
        double m, i;
        if (ts >> m >> i) {
            mz.push_back(streamfind::Json(m));
            intensity.push_back(streamfind::Json(i));
        }
    }
}

// Build a JSON targets array from a suspect/IS CSV (name, mass, rt, SMILES, InChI,
// InChIKey, xLogP, ms2_positive).
streamfind::Json targets_from_csv(const std::string &path) {
    const auto rows = parse_csv(path);
    if (rows.empty()) return streamfind::Json::array();
    const auto header = rows[0];
    const int ci_name = col_index(header, "name");
    const int ci_mass = col_index(header, "mass");
    const int ci_rt = col_index(header, "rt");
    const int ci_formula = col_index(header, "formula");
    const int ci_smiles = col_index(header, "SMILES");
    const int ci_inchi = col_index(header, "InChI");
    const int ci_key = col_index(header, "InChIKey");
    const int ci_xlogp = col_index(header, "xLogP");
    const int ci_ms2p = col_index(header, "ms2_positive");
    const int ci_ms2n = col_index(header, "ms2_negative");
    streamfind::Json out = streamfind::Json::array();
    for (size_t r = 1; r < rows.size(); ++r) {
        const auto &f = rows[r];
        auto field = [&](int idx) -> std::string {
            return (idx >= 0 && static_cast<size_t>(idx) < f.size()) ? f[static_cast<size_t>(idx)] : std::string();
        };
        auto has = [&](int idx) { return idx >= 0 && static_cast<size_t>(idx) < f.size() && !field(idx).empty(); };
        if (ci_name < 0 || !has(ci_name)) continue;
        streamfind::Json t = streamfind::Json{{"id", field(ci_name)}};
        if (has(ci_mass)) t["mass"] = std::stod(field(ci_mass));
        if (has(ci_rt)) t["rt"] = std::stod(field(ci_rt));
        if (has(ci_formula)) t["formula"] = field(ci_formula);
        if (has(ci_smiles)) t["SMILES"] = field(ci_smiles);
        if (has(ci_inchi)) t["InChI"] = field(ci_inchi);
        if (has(ci_key)) t["InChIKey"] = field(ci_key);
        if (has(ci_xlogp)) t["xLogP"] = std::stod(field(ci_xlogp));
        // Use positive MS2 fragments when present, else negative.
        const std::string ms2 = has(ci_ms2p) ? field(ci_ms2p) : (has(ci_ms2n) ? field(ci_ms2n) : std::string());
        if (!ms2.empty()) {
            streamfind::Json mz = streamfind::Json::array();
            streamfind::Json intensity = streamfind::Json::array();
            parse_fragments(ms2, mz, intensity);
            t["fragments_mz_pos"] = mz;
            t["fragments_intensity_pos"] = intensity;
        }
        out.push_back(std::move(t));
    }
    return out;
}

} // namespace

int run_nta_wastewater_conformance(bool quantized) {
    const auto fail = [](const char *check) {
        std::cerr << "wastewater conformance test failed: " << check << "\n";
        return 1;
    };
    streamfind::MethodRegistry registry;
    streamfind::mass_spec::register_methods(registry);

    const char *wired[] = {
        "mass_spec.filter_internal_standards", "mass_spec.filter_suspects"
    };
    for (const char *id : wired)
        if (!registry.find(id)) return fail(id);

    const auto ww = std::filesystem::path(STREAMFIND_WASTEWATER_DATA_ROOT);

    // Full mode: the complete 18-file wastewater set (3 replicates x 6 groups).
    // Quantized mode: a small positive-mode subset (blank + influent + effluent,
    // 2 replicates each) plus a narrow RT window, so the same pipeline runs in a
    // few seconds-minutes instead of ~3 hours. This is the CI regression target.
    const char *files[] = {
        "01_tof_ww_is_neg_blank-r001.mzML", "01_tof_ww_is_neg_blank-r002.mzML", "01_tof_ww_is_neg_blank-r003.mzML",
        "01_tof_ww_is_pos_blank-r001.mzML", "01_tof_ww_is_pos_blank-r002.mzML", "01_tof_ww_is_pos_blank-r003.mzML",
        "02_tof_ww_is_neg_influent-r001.mzML", "02_tof_ww_is_neg_influent-r002.mzML", "02_tof_ww_is_neg_influent-r003.mzML",
        "02_tof_ww_is_pos_influent-r001.mzML", "02_tof_ww_is_pos_influent-r002.mzML", "02_tof_ww_is_pos_influent-r003.mzML",
        "03_tof_ww_is_neg_o3sw_effluent-r001.mzML", "03_tof_ww_is_neg_o3sw_effluent-r002.mzML", "03_tof_ww_is_neg_o3sw_effluent-r003.mzML",
        "03_tof_ww_is_pos_o3sw_effluent-r001.mzML", "03_tof_ww_is_pos_o3sw_effluent-r002.mzML", "03_tof_ww_is_pos_o3sw_effluent-r003.mzML"
    };
    // Quantized: [pos_blank r001, pos_influent r001, pos_o3sw_effluent r001] -> 3 files.
    // One blank plus two sample conditions still exercises blank subtraction,
    // grouping (minSamples=1) and the full pipeline on real data, but cuts the
    // per-file spectrum reading/denoising cost enough to finish in minutes.
    const int quantized_idx[] = {3, 9, 15};
    const int N = quantized ? 3 : 18;

    streamfind::Json analysis_names = streamfind::Json::array();
    streamfind::Json analyses = streamfind::Json::array();
    for (int i = 0; i < N; ++i) {
        // In quantized mode the analysis order is blank(2), influent(2), effluent(2) positive.
        const int fi = quantized ? quantized_idx[i] : i;
        const auto p = ww / files[fi];
        analysis_names.push_back(streamfind::Json(std::filesystem::path(p).stem().string()));
        analyses.push_back(streamfind::Json{{"path", p.string()}});
    }

    const auto database = std::filesystem::current_path() /
        (quantized ? "streamfind-nta-wastewater-quantized.duckdb" : "streamfind-nta-wastewater-conformance.duckdb");
    std::error_code error;
    std::filesystem::remove(database, error);
    auto project = streamfind::Project::create({database, "ww-conformance", std::nullopt, false, false, "mass_spec"});

    streamfind::OperationRegistry operations;
    streamfind::mass_spec::register_operations(operations);
    const auto add_result = project.run_operation("mass_spec.add_analyses", {{"analyses", analyses}}, operations);
    if (add_result.at("row_count") != N) return fail("add_analyses");

    auto run = [&](const std::string &id, const streamfind::Json &params) -> streamfind::Json {
        return project.run_method(id, params, registry);
    };
    auto finished = [](const streamfind::Json &r) { return r.value("status", "") == "finished"; };

    // Step 2: replicate + blank names. Full mode: 6 groups x 3 reps (lexical order).
    // Quantized mode: 3 positive groups x 2 reps: pos_blank, pos_influent, pos_o3sw_effluent.
    streamfind::Json replicate_names = streamfind::Json::array();
    streamfind::Json blank_names = streamfind::Json::array();
    if (!quantized) {
        const char *replicas6[] = {"neg_blank","pos_blank","neg_influent","pos_influent","neg_o3sw_effluent","pos_o3sw_effluent"};
        const char *blanks6[] = {"neg_blank","pos_blank","neg_blank","pos_blank","neg_blank","pos_blank"};
        for (int g = 0; g < 6; ++g) for (int k = 0; k < 3; ++k) {
            replicate_names.push_back(streamfind::Json(replicas6[g]));
            blank_names.push_back(streamfind::Json(blanks6[g]));
        }
    } else {
        // 3 files: pos_blank r001, pos_influent r001, pos_o3sw_effluent r001.
        replicate_names = streamfind::Json::array({streamfind::Json("pos_blank"), streamfind::Json("pos_influent"), streamfind::Json("pos_o3sw_effluent")});
        blank_names = streamfind::Json::array({streamfind::Json("pos_blank"), streamfind::Json("pos_blank"), streamfind::Json("pos_blank")});
    }
    project.run_operation("mass_spec.set_replicate_names", {{"replicate_names", replicate_names}}, operations);
    project.run_operation("mass_spec.set_blank_names", {{"blank_names", blank_names}}, operations);

    // Step 3: find_features. Full mode uses empty rtWindows = full range; the
    // quantized mode uses a narrow window (IS/suspect-rich region) for speed.
    const streamfind::Json find_params = quantized
        ? streamfind::Json{
            {"analysis_names", analysis_names},
            {"rt_windows_min", streamfind::Json::array({streamfind::Json(850.0)})},
            {"rt_windows_max", streamfind::Json::array({streamfind::Json(1100.0)})},
            {"ppm_threshold", 10.0}, {"noise_threshold", 250.0}, {"min_snr", 3.0},
            {"min_traces", 3}, {"baseline_window", 200.0}, {"max_feature_width", 100.0}, {"base_quantile", 0.99}}
        : streamfind::Json{
            {"analysis_names", analysis_names},
            {"rt_windows_min", streamfind::Json::array()}, {"rt_windows_max", streamfind::Json::array()},
            {"ppm_threshold", 10.0}, {"noise_threshold", 250.0}, {"min_snr", 3.0},
            {"min_traces", 3}, {"baseline_window", 200.0}, {"max_feature_width", 100.0}, {"base_quantile", 0.99}};

    // Parameter sets for the remaining pipeline steps.
    const streamfind::Json create_params = {
        {"analysis_names", analysis_names},
        {"rt_window", streamfind::Json::array({streamfind::Json(-2.5), streamfind::Json(2.5)})},
        {"min_correlation", 0.85}};
    const streamfind::Json annotate_params = {
        {"analysis_names", analysis_names},
        {"max_isotopes", 8}, {"max_charge", 1}, {"max_gaps", 1}, {"ppm", 10.0},
        {"isotope_elements", streamfind::Json::array({streamfind::Json("C:1-80"), streamfind::Json("N:0-10"),
            streamfind::Json("O:0-20"), streamfind::Json("S:0-4"), streamfind::Json("Cl:0-6"), streamfind::Json("Br:0-4")})}};
    const streamfind::Json load_ms2_params = {
        {"analysis_names", analysis_names}, {"filtered", false},
        {"min_traces_intensity", 10.0}, {"isolation_window", 1.3}, {"mz_clust", 0.008}, {"presence", 0.5}};
    const auto is_csv = (ww / "internal_standards.csv").string();
    const streamfind::Json is_targets = targets_from_csv(is_csv);
    const streamfind::Json is_params = {
        {"analysis_names", analysis_names}, {"targets", is_targets},
        {"ppm", 10.0}, {"sec", 15.0}, {"ppm_ms2", 10.0}, {"mzr_ms2", 0.008},
        {"min_cosine_similarity", 0.7}, {"min_shared_fragments", 3}, {"filtered", true}};
    const streamfind::Json filter_is_params = {
        {"analysis_names", analysis_names},
        {"id_levels", streamfind::Json::array({streamfind::Json(1), streamfind::Json(2), streamfind::Json(3)})}};
    const streamfind::Json group_params = {
        {"analysis_names", analysis_names}, {"method", "internal_standards"},
        {"rt_deviation", 5.0}, {"ppm", 10.0}, {"min_samples", 1}, {"bin_size", 5.0}};
    const streamfind::Json subtract_params = {
        {"analysis_names", analysis_names}, {"blank_threshold", 5.0}, {"rt_expand", 10.0}, {"mz_expand", 0.005}};
    const streamfind::Json filter_params = {
        {"analysis_names", analysis_names},
        {"min_intensity", 10000.0},
        {"remove_isotopes", true}, {"remove_adducts", true}, {"remove_losses", true}};
    // Step 10: suspect_screening before filter_suspects (filter_suspects requires it
    // earlier in the workflow), using the suspects.csv targets and the same
    // parameters as the find_internal_standards step.
    const auto suspects_csv = (ww / "suspects.csv").string();
    const streamfind::Json suspect_targets = targets_from_csv(suspects_csv);
    std::cout << "suspect targets parsed: " << suspect_targets.size() << "\n";
    const streamfind::Json suspect_params = {
        {"analysis_names", analysis_names}, {"targets", suspect_targets},
        {"ppm", 10.0}, {"sec", 15.0}, {"ppm_ms2", 10.0}, {"mzr_ms2", 0.008},
        {"min_cosine_similarity", 0.7}, {"min_shared_fragments", 3}, {"filtered", true}};
    const streamfind::Json filter_suspects_params = {
        {"analysis_names", analysis_names}, {"id_levels", streamfind::Json::array({streamfind::Json(1), streamfind::Json(2)})}};

    // The workflow is set ONCE with the full ordered pipeline: Workflow::validate
    // enforces required_methods, so every step's prerequisites must appear earlier.
    streamfind::Workflow pipeline; pipeline.domain = "mass_spec";
    pipeline.steps.push_back({"mass_spec.find_features", streamfind::ParameterValues::from_json(find_params)});
    pipeline.steps.push_back({"mass_spec.create_components", streamfind::ParameterValues::from_json(create_params)});
    pipeline.steps.push_back({"mass_spec.annotate_components", streamfind::ParameterValues::from_json(annotate_params)});
    pipeline.steps.push_back({"mass_spec.load_features_ms2", streamfind::ParameterValues::from_json(load_ms2_params)});
    pipeline.steps.push_back({"mass_spec.find_internal_standards", streamfind::ParameterValues::from_json(is_params)});
    pipeline.steps.push_back({"mass_spec.filter_internal_standards", streamfind::ParameterValues::from_json(filter_is_params)});
    pipeline.steps.push_back({"mass_spec.group_features", streamfind::ParameterValues::from_json(group_params)});
    pipeline.steps.push_back({"mass_spec.subtract_blank", streamfind::ParameterValues::from_json(subtract_params)});
    pipeline.steps.push_back({"mass_spec.filter_features", streamfind::ParameterValues::from_json(filter_params)});
    pipeline.steps.push_back({"mass_spec.suspect_screening", streamfind::ParameterValues::from_json(suspect_params)});
    pipeline.steps.push_back({"mass_spec.filter_suspects", streamfind::ParameterValues::from_json(filter_suspects_params)});
    project.set_workflow(std::move(pipeline), registry);

    // Step 3: find_features.
    if (!finished(run("mass_spec.find_features", find_params))) return fail("find_features status");
    const auto feats = project.query_json("SELECT COUNT(*) AS count FROM MASS_SPEC_NTA_FEATURES");
    const long feat_count = std::stol(feats.at(0).at("count").get<std::string>());
    if (feat_count == 0) return fail("find_features produced no features");
    std::cout << "features detected: " << feat_count << "\n";

    // Step 4: create_components.
    if (!finished(run("mass_spec.create_components", create_params))) return fail("create_components status");

    // Step 5: annotate_components.
    if (!finished(run("mass_spec.annotate_components", annotate_params))) return fail("annotate_components status");

    // Step 6: load_features_ms2.
    if (!finished(run("mass_spec.load_features_ms2", load_ms2_params))) return fail("load_features_ms2 status");

    // Step 7: find_internal_standards from internal_standards.csv.
    std::cout << "internal standard targets parsed: " << is_targets.size() << "\n";
    if (!finished(run("mass_spec.find_internal_standards", is_params))) return fail("find_internal_standards status");
    const auto is_rows = project.query_json("SELECT COUNT(*) AS count FROM MASS_SPEC_NTA_INTERNAL_STANDARDS");
    const long is_found = std::stol(is_rows.at(0).at("count").get<std::string>());
    std::cout << "internal standards found: " << is_found << "\n";

    // Step 8: filter_internal_standards (idLevels 1,2,3).
    if (!finished(run("mass_spec.filter_internal_standards", filter_is_params))) return fail("filter_internal_standards status");
    const auto is_after = project.query_json("SELECT COUNT(*) AS count FROM MASS_SPEC_NTA_INTERNAL_STANDARDS");
    std::cout << "internal standards after filter: " << is_after.at(0).at("count").dump() << "\n";

    // Step 9: group_features (internal_standards alignment).
    if (!finished(run("mass_spec.group_features", group_params))) return fail("group_features status");
    const auto groups = project.query_json("SELECT COUNT(DISTINCT feature_group) AS count FROM MASS_SPEC_NTA_FEATURES WHERE feature_group != ''");
    std::cout << "feature groups: " << groups.at(0).at("count").dump() << "\n";

    // Step 10: blank_subtraction + filter_features to prove the new params run.
    if (!finished(run("mass_spec.subtract_blank", subtract_params))) return fail("subtract_blank status");
    if (!finished(run("mass_spec.filter_features", filter_params))) return fail("filter_features status");

    // Step 11: suspect_screening (suspects.csv) then filter_suspects on its results.
    if (!finished(run("mass_spec.suspect_screening", suspect_params))) return fail("suspect_screening status");
    if (!finished(run("mass_spec.filter_suspects", filter_suspects_params))) return fail("filter_suspects status");

    std::cout << (quantized ? "NTA wastewater QUANTIZED conformance pipeline completed successfully.\n"
                            : "NTA wastewater conformance pipeline completed successfully.\n");
    std::filesystem::remove(database, error);
    return 0;
}

int main(int argc, char **argv) {
    // Optional '--quantized' flag: runs the small positive-mode subset + narrow RT
    // window for fast CI regression. Default (no arg) runs the full 18-file suite.
    const bool quantized = argc > 1 && std::string(argv[1]) == "--quantized";
    try {
        return run_nta_wastewater_conformance(quantized);
    } catch (const std::exception &exception) {
        std::cerr << "wastewater conformance exception: " << exception.what() << "\n";
        return 1;
    } catch (...) {
        std::cerr << "wastewater conformance exception: unknown\n";
        return 1;
    }
}
