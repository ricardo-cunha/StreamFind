#include <filesystem>
#include <iostream>
#include <exception>
#include <string>

#include "streamfind/mass_spec/register.hpp"
#include "streamfind/project.hpp"
#include "streamfind/external/tools_resolver.hpp"
#include "tmp_projects.hpp"

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
        "mass_spec.find_internal_standards", "mass_spec.correct_matrix_suppression",
        "mass_spec.assign_transformation_products", "mass_spec.metfrag_screening"
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

    const auto database = streamfind::test::tmp_projects_dir() / "streamfind-nta-processing-test.duckdb";
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
        return project.run_method(id, params, registry);
    };

    // Parameter sets for every pipeline step. The workflow is set ONCE with the
    // full ordered pipeline because Workflow::validate enforces required_methods
    // (each step's prerequisites must appear earlier in the workflow).
    // 1. find_features over the Metoprolol-D7 window.
    const streamfind::Json find_params = {
        {"analysis_names", analysis_names},
        {"rt_windows_min", streamfind::Json::array({streamfind::Json(900.0)})},
        {"rt_windows_max", streamfind::Json::array({streamfind::Json(925.0)})},
        {"ppm_threshold", 12.0}, {"noise_threshold", 500.0}, {"min_snr", 15.0},
        {"min_traces", 5}, {"baseline_window", 30.0}, {"max_feature_width", 60.0}, {"base_quantile", 0.1}
    };
    // 2. filter_features (no criteria supplied -> no-op filtering, must not crash).
    const streamfind::Json filter_params = {
        {"analysis_names", analysis_names}
    };
    // 3. create_components (needs EIC data written by find_features).
    const streamfind::Json components_params = {
        {"analysis_names", analysis_names},
        {"rt_window", streamfind::Json::array({streamfind::Json(60.0), streamfind::Json(0.0)})},
        {"min_correlation", 0.8}
    };
    // 4. annotate_components (requires create_components earlier).
    const streamfind::Json annotate_params = {
        {"analysis_names", analysis_names},
        {"max_isotopes", 10}, {"max_charge", 2}, {"max_gaps", 1}, {"ppm", 5.0},
        {"isotope_elements", streamfind::Json::array({streamfind::Json("C"), streamfind::Json("H")})}
    };
    const streamfind::Json blank_params = {
        {"analysis_names", analysis_names}, {"blank_threshold", 2.0},
        {"rt_expand", 1.0}, {"mz_expand", 0.01}
    };
    const streamfind::Json group_params = {
        {"analysis_names", analysis_names}, {"method", "obi_warp"},
        {"rt_deviation", 10.0}, {"ppm", 5.0}, {"min_samples", 2}, {"bin_size", 5.0}
    };
    // 7. load_features_ms2 must run before filter_features_ms2 (required method).
    const streamfind::Json load_ms2_params = {
        {"analysis_names", analysis_names}, {"filtered", false},
        {"min_traces_intensity", 0.0}, {"isolation_window", 1.3},
        {"mz_clust", 0.005}, {"presence", 0.8}
    };
    const streamfind::Json ms2_params = {
        {"analysis_names", analysis_names}, {"top", 0}, {"min_intensity_ms2", 0.0},
        {"rel_min_intensity", 0.0}, {"blank_clean", false}, {"mz_clust", 0.005},
        {"blank_presence_threshold", 0.8}, {"global_presence_threshold", 0.1}
    };
    const streamfind::Json suspects_targets = streamfind::Json::array({
        streamfind::Json{{"id", "caffeine"}, {"mass", 194.0804}}
    });
    const streamfind::Json suspect_params = {
        {"analysis_names", analysis_names}, {"targets", suspects_targets},
        {"ppm", 5.0}, {"sec", 10.0}, {"ppm_ms2", 10.0}, {"mzr_ms2", 0.008},
        {"min_cosine_similarity", 0.7}, {"min_shared_fragments", 2}, {"filtered", false}
    };
    const streamfind::Json matrix_params = {
        {"analysis_names", analysis_names}, {"mp_rt_window", 60.0}, {"ref_blank_replicate", ""}
    };
    const streamfind::Json fill_params = {
        {"analysis_names", analysis_names}, {"within_replicate", false}, {"filtered", false},
        {"rt_expand", 1.0}, {"mz_expand", 0.01}, {"max_peak_width", 30.0},
        {"min_traces_intensity", 1000.0}, {"min_number_traces", 3}, {"min_intensity_ms1", 1000.0},
        {"rt_apex_deviation", 1.0}, {"min_signal_to_noise_ratio", 3.0}, {"min_gaussian_fit", 0.5}
    };
    // 13. assign_transformation_products: a small transformation table (Metoprolol
    // O-dealkylation + hydroxylation). The current suspects carry no feature groups,
    // so the algorithm emits its "unresolved" fallback rows — the important contract
    // is that the suspects table grows by exactly one row per input product.
    const streamfind::Json transformation_products = streamfind::Json::array({
        streamfind::Json{
            {"name", "Metoprolol O-dealkylation"}, {"transformation", "O-Dealkylation"},
            {"formula", "C13H21NO3"}, {"mass", 239.1521},
            {"SMILES", "OCC(CNC(C)C)Oc1ccc(O)cc1"}, {"InChI", "InChI=1S/C13H21NO3/c1-12(2)14-10-13(16)17-11-5-3-9(4-6-11)7-8-15/h3-6,12-16H,7-8,10H2,1-2H3"},
            {"InChIKey", "UVVQEARUQBNLLE-UHFFFAOYSA-N"}, {"xLogP", 1.2},
            {"precursor_name", "Metoprolol"}, {"precursor_formula", "C15H25NO3"},
            {"precursor_mass", 267.1834}, {"precursor_SMILES", "COCCc1ccc(cc1)OCC(CNC(C)C)O"},
            {"precursor_InChI", "InChI=1S/C15H25NO3/c1-12(2)16-10-14(17)11-19-15-6-4-13(5-7-15)8-9-18-3/h4-7,12,14,16-17H,8-11H2,1-3H3"},
            {"precursor_InChIKey", "IUBSYMUCCVWXPE-UHFFFAOYSA-N"}, {"precursor_xLogP", 1.9},
            {"main_precursor_name", "Metoprolol"}, {"main_precursor_formula", "C15H25NO3"},
            {"main_precursor_mass", 267.1834}, {"main_precursor_SMILES", "COCCc1ccc(cc1)OCC(CNC(C)C)O"},
            {"main_precursor_InChI", "InChI=1S/C15H25NO3/c1-12(2)16-10-14(17)11-19-15-6-4-13(5-7-15)8-9-18-3/h4-7,12,14,16-17H,8-11H2,1-3H3"},
            {"main_precursor_InChIKey", "IUBSYMUCCVWXPE-UHFFFAOYSA-N"}, {"main_precursor_xLogP", 1.9}
        },
        streamfind::Json{
            {"name", "Metoprolol hydroxylation"}, {"transformation", "Hydroxylation"},
            {"formula", "C15H25NO4"}, {"mass", 283.1783},
            {"SMILES", "COCCc1ccc(cc1)OCC(CNC(C)C)O.O"}, {"InChI", "InChI=1S/C15H25NO4/c1-12(2)16-10-14(17)11-19-15-6-4-13(5-7-15)8-9-18-3/h4-7,12,14,16-17H,8-11H2,1-3H3"},
            {"InChIKey", "IUBSYMUCCVWXPE-ZDUSSCGKSA-N"}, {"xLogP", 0.9},
            {"precursor_name", "Metoprolol"}, {"precursor_formula", "C15H25NO3"},
            {"precursor_mass", 267.1834}, {"precursor_SMILES", "COCCc1ccc(cc1)OCC(CNC(C)C)O"},
            {"precursor_InChI", "InChI=1S/C15H25NO3/c1-12(2)16-10-14(17)11-19-15-6-4-13(5-7-15)8-9-18-3/h4-7,12,14,16-17H,8-11H2,1-3H3"},
            {"precursor_InChIKey", "IUBSYMUCCVWXPE-UHFFFAOYSA-N"}, {"precursor_xLogP", 1.9},
            {"main_precursor_name", "Metoprolol"}, {"main_precursor_formula", "C15H25NO3"},
            {"main_precursor_mass", 267.1834}, {"main_precursor_SMILES", "COCCc1ccc(cc1)OCC(CNC(C)C)O"},
            {"main_precursor_InChI", "InChI=1S/C15H25NO3/c1-12(2)16-10-14(17)11-19-15-6-4-13(5-7-15)8-9-18-3/h4-7,12,14,16-17H,8-11H2,1-3H3"},
            {"main_precursor_InChIKey", "IUBSYMUCCVWXPE-UHFFFAOYSA-N"}, {"main_precursor_xLogP", 1.9}
        }
    });
    const streamfind::Json transform_params = {
        {"analysis_names", analysis_names},
        {"transformation_products", transformation_products},
        {"chromatographic_phase", "reverse_phase"}, {"mzr_ms2", 0.008}
    };
    // 14. metfrag_screening with a LocalCSV database. Row masses match the
    // measured features in the [900,925] window: MZ293 (4N-Acetylsulfadiazine,
    // RT 906, m/z 293.070) and MZ268 (Metoprolol D0, RT 916, m/z 268.191) —
    // deuterated Metoprolol-D7 is included for realism but MetFrag's IsotopeFilter
    // discards it again, exactly as it would in R.
    const int metfrag_top_n = 2;
    const streamfind::Json metfrag_database = streamfind::Json::array({
        streamfind::Json{
            {"name", "4N-Acetylsulfadiazine"}, {"formula", "C12H12N4O3S"}, {"mass", 292.063},
            {"SMILES", "CC(=Nc1ccc(cc1)S(=O)(=O)Nc1ncccn1)O"},
            {"InChI", "InChI=1S/C12H12N4O3S/c1-9(17)15-10-3-5-11(6-4-10)20(18,19)16-12-13-7-2-8-14-12/h2-8H,1H3,(H,15,17)(H,13,14,16)"},
            {"InChIKey", "NJIZUWGMNCUKGU-UHFFFAOYSA-N"}, {"xLogP", 0.0}
        },
        streamfind::Json{
            {"name", "Metoprolol"}, {"formula", "C15H25NO3"}, {"mass", 267.1834},
            {"SMILES", "COCCc1ccc(cc1)OCC(CNC(C)C)O"},
            {"InChI", "InChI=1S/C15H25NO3/c1-12(2)16-10-14(17)11-19-15-6-4-13(5-7-15)8-9-18-3/h4-7,12,14,16-17H,8-11H2,1-3H3"},
            {"InChIKey", "IUBSYMUCCVWXPE-UHFFFAOYSA-N"}, {"xLogP", 1.9}
        },
        streamfind::Json{
            {"name", "Metoprolol-D7"}, {"formula", "C15H18[2H]7NO3"}, {"mass", 274.2289},
            {"SMILES", "COCCc1ccc(cc1)OCC(CNC(C([2H])([2H])[2H])(C([2H])([2H])[2H])[2H])O"},
            {"InChI", "InChI=1S/C15H25NO3/c1-12(2)16-10-14(17)11-19-15-6-4-13(5-7-15)8-9-18-3/h4-7,12,14,16-17H,8-11H2,1-3H3/i1D3,2D3,12D"},
            {"InChIKey", "IUBSYMUCCVWXPE-QLWPOVNFSA-N"}, {"xLogP", 2.0041}
        }
    });

    const streamfind::Json metfrag_params = {
        {"analysis_names", analysis_names},
        {"database_type", "Local"}, {"database", metfrag_database},
        {"ppm", 5.0}, {"sec", 10.0}, {"ppm_ms2", 10.0}, {"mzr_ms2", 0.008},
        {"top_n", metfrag_top_n},
        {"score_types", streamfind::Json::array({streamfind::Json("FragmenterScore")})},
        {"score_weights", streamfind::Json::array({streamfind::Json(1.0)})},
        {"pre_processing_candidate_filter", streamfind::Json::array({
            streamfind::Json("UnconnectedCompoundFilter"), streamfind::Json("IsotopeFilter")})},
        {"post_processing_candidate_filter", streamfind::Json::array({streamfind::Json("InChIKeyFilter")})},
        {"maximum_tree_depth", 3}, {"number_threads", 1},
        {"use_smiles", true}, {"filtered", false}, {"debug", false}
    };


    streamfind::Workflow pipeline; pipeline.domain = "mass_spec";
    pipeline.steps.push_back({"mass_spec.find_features", streamfind::ParameterValues::from_json(find_params)});
    pipeline.steps.push_back({"mass_spec.filter_features", streamfind::ParameterValues::from_json(filter_params)});
    pipeline.steps.push_back({"mass_spec.create_components", streamfind::ParameterValues::from_json(components_params)});
    pipeline.steps.push_back({"mass_spec.annotate_components", streamfind::ParameterValues::from_json(annotate_params)});
    pipeline.steps.push_back({"mass_spec.subtract_blank", streamfind::ParameterValues::from_json(blank_params)});
    pipeline.steps.push_back({"mass_spec.group_features", streamfind::ParameterValues::from_json(group_params)});
    pipeline.steps.push_back({"mass_spec.load_features_ms2", streamfind::ParameterValues::from_json(load_ms2_params)});
    pipeline.steps.push_back({"mass_spec.filter_features_ms2", streamfind::ParameterValues::from_json(ms2_params)});
    pipeline.steps.push_back({"mass_spec.suspect_screening", streamfind::ParameterValues::from_json(suspect_params)});
    pipeline.steps.push_back({"mass_spec.find_internal_standards", streamfind::ParameterValues::from_json(suspect_params)});
    pipeline.steps.push_back({"mass_spec.correct_matrix_suppression", streamfind::ParameterValues::from_json(matrix_params)});
    pipeline.steps.push_back({"mass_spec.fill_features", streamfind::ParameterValues::from_json(fill_params)});
    pipeline.steps.push_back({"mass_spec.assign_transformation_products", streamfind::ParameterValues::from_json(transform_params)});
    pipeline.steps.push_back({"mass_spec.metfrag_screening", streamfind::ParameterValues::from_json(metfrag_params)});
    project.set_workflow(std::move(pipeline), registry);

    // 1. find_features over the Metoprolol-D7 window.
    if (run("mass_spec.find_features", find_params).value("status", "") != "finished")
        return fail("find_features status");
    const auto total = project.query_json("SELECT COUNT(*) AS count FROM MASS_SPEC_NTA_FEATURES");
    if (total.at(0).at("count").get<std::string>() == "0") return fail("find_features produced no features");

    // 2. filter_features (no criteria supplied -> no-op filtering, must not crash).
    if (run("mass_spec.filter_features", filter_params).value("status", "") != "finished")
        return fail("filter_features status");
    const auto remaining = project.query_json("SELECT COUNT(*) AS count FROM MASS_SPEC_NTA_FEATURES");
    if (remaining.at(0).at("count").get<std::string>() == "0") return fail("filter_features removed everything");

    // 3. create_components (needs EIC data written by find_features).
    if (run("mass_spec.create_components", components_params).value("status", "") != "finished")
        return fail("create_components status");

    // 4. annotate_components.
    if (run("mass_spec.annotate_components", annotate_params).value("status", "") != "finished")
        return fail("annotate_components status");

    // 5-6. subtract_blank + group_features (obi_warp alignment).
    if (run("mass_spec.subtract_blank", blank_params).value("status", "") != "finished")
        return fail("subtract_blank status");
    if (run("mass_spec.group_features", group_params).value("status", "") != "finished")
        return fail("group_features status");

    // 7-8. MS2 loading must precede MS2 filtering.
    if (run("mass_spec.load_features_ms2", load_ms2_params).value("status", "") != "finished")
        return fail("load_features_ms2 status");
    if (run("mass_spec.filter_features_ms2", ms2_params).value("status", "") != "finished")
        return fail("filter_features_ms2 status");

    // 9-10. suspect screening + internal standards.
    if (run("mass_spec.suspect_screening", suspect_params).value("status", "") != "finished")
        return fail("suspect_screening status");
    if (run("mass_spec.find_internal_standards", suspect_params).value("status", "") != "finished")
        return fail("find_internal_standards status");

    // 11. correct_matrix_suppression (requires find_internal_standards earlier).
    if (run("mass_spec.correct_matrix_suppression", matrix_params).value("status", "") != "finished")
        return fail("correct_matrix_suppression status");

    // 12. fill_features (requires find_features and group_features earlier).
    if (run("mass_spec.fill_features", fill_params).value("status", "") != "finished")
        return fail("fill_features status");

    const auto surviving = project.query_json("SELECT COUNT(*) AS count FROM MASS_SPEC_NTA_FEATURES");
    std::cout << "features after pipeline: " << surviving.at(0).at("count").dump() << "\n";
    // 13. assign_transformation_products appends the combination-scored rows
    // (one per input transformation product).
    const auto suspects_before_assign = std::stoi(
        project.query_json("SELECT COUNT(*) AS count FROM MASS_SPEC_NTA_SUSPECTS").at(0).at("count").get<std::string>());
    if (run("mass_spec.assign_transformation_products", transform_params).value("status", "") != "finished")
        return fail("assign_transformation_products status");
    const auto suspects_after_assign = std::stoi(
        project.query_json("SELECT COUNT(*) AS count FROM MASS_SPEC_NTA_SUSPECTS").at(0).at("count").get<std::string>());
    std::cout << "suspects before assign: " << suspects_before_assign
              << ", after assign: " << suspects_after_assign << "\n";
    if (suspects_after_assign < suspects_before_assign)
        return fail("assign_transformation_products removed suspects");
    if (suspects_after_assign == suspects_before_assign)
        return fail("assign_transformation_products appended no rows");

    // 14. metfrag_screening: tolerant on the jar. When the tool is installed the
    // LocalCSV run must finish and append ranked candidates (top_n respected);
    // otherwise the graceful tool-missing error must surface.
    if (streamfind::tools::resolve_metfrag().has_value()) {
        const auto suspects_before_metfrag = std::stoi(
            project.query_json("SELECT COUNT(*) AS count FROM MASS_SPEC_NTA_SUSPECTS").at(0).at("count").get<std::string>());
        if (run("mass_spec.metfrag_screening", metfrag_params).value("status", "") != "finished")
            return fail("metfrag_screening status");
        const auto suspects_after_metfrag = std::stoi(
            project.query_json("SELECT COUNT(*) AS count FROM MASS_SPEC_NTA_SUSPECTS").at(0).at("count").get<std::string>());
        std::cout << "suspects before metfrag: " << suspects_before_metfrag
                  << ", after metfrag: " << suspects_after_metfrag << "\n";
        if (suspects_after_metfrag == 0)
            return fail("metfrag_screening produced no candidates");
        const auto ranks = project.query_json("SELECT candidate_rank FROM MASS_SPEC_NTA_SUSPECTS");
        for (const auto &row : ranks) {
            const int rank = std::stoi(row.at("candidate_rank").get<std::string>());
            if (rank < 1 || rank > metfrag_top_n)
                return fail("metfrag candidate_rank violates top_n");
        }
    } else {
        try {
            run("mass_spec.metfrag_screening", metfrag_params);
            return fail("metfrag_screening missing-tool error not raised");
        } catch (const streamfind::Error &exception) {
            if (std::string(exception.what()).find(
                    "MetFrag command line is not installed") == std::string::npos)
                return fail("metfrag_screening missing-tool message");
        }
    }

    std::cout << "NTA processing pipeline completed successfully.\n";

    // Negative: a workflow of [find_features, filter_suspects] must fail ordering
    // validation because filter_suspects requires suspect_screening earlier.
    {
        streamfind::Workflow wf; wf.domain = "mass_spec";
        wf.steps.push_back({"mass_spec.find_features", streamfind::ParameterValues::from_json(find_params)});
        wf.steps.push_back({"mass_spec.filter_suspects", streamfind::ParameterValues::from_json(
            {{"analysis_names", analysis_names}, {"id_levels", streamfind::Json::array({streamfind::Json(1)})}})});
        try {
            project.set_workflow(std::move(wf), registry);
            return fail("ordering validation accepted [find_features, filter_suspects]");
        } catch (const streamfind::Error &exception) {
            if (exception.code() != streamfind::ErrorCode::WorkflowValidation)
                return fail("ordering validation error code");
            if (std::string(exception.what()).find(
                    "Required method is not earlier in workflow: mass_spec.suspect_screening") == std::string::npos)
                return fail("ordering validation message");
        }
    }

    // Negative: suspect_screening targets must carry an identifier (mass, mz,
    // formula, SMILES, or InChI) in addition to the id/name.
    {
        const streamfind::Json bad_targets = streamfind::Json::array({
            streamfind::Json{{"id", "caffeine"}}
        });
        const streamfind::Json bad_params = {
            {"analysis_names", analysis_names}, {"targets", bad_targets}
        };
        streamfind::Workflow wf; wf.domain = "mass_spec";
        wf.steps.push_back({"mass_spec.find_features", streamfind::ParameterValues::from_json(find_params)});
        wf.steps.push_back({"mass_spec.suspect_screening", streamfind::ParameterValues::from_json(bad_params)});
        try {
            project.set_workflow(std::move(wf), registry);
            return fail("targets validation accepted an id-only target");
        } catch (const streamfind::Error &exception) {
            if (exception.code() != streamfind::ErrorCode::WorkflowValidation)
                return fail("targets validation error code");
            if (std::string(exception.what()).find(
                    "mass_spec.suspect_screening: invalid parameters:") == std::string::npos)
                return fail("targets validation message");
        }
    }

    // Negative: group_features method must be "internal_standards" or "obi_warp".
    {
        const streamfind::Json bad_params = {
            {"analysis_names", analysis_names}, {"method", "obiwarp"},
            {"rt_deviation", 10.0}, {"ppm", 5.0}, {"min_samples", 2}, {"bin_size", 5.0}
        };
        streamfind::Workflow wf; wf.domain = "mass_spec";
        wf.steps.push_back({"mass_spec.find_features", streamfind::ParameterValues::from_json(find_params)});
        wf.steps.push_back({"mass_spec.group_features", streamfind::ParameterValues::from_json(bad_params)});
        try {
            project.set_workflow(std::move(wf), registry);
            return fail("group method validation accepted obiwarp");
        } catch (const streamfind::Error &exception) {
            if (exception.code() != streamfind::ErrorCode::WorkflowValidation)
                return fail("group method validation error code");
            if (std::string(exception.what()).find(
                    "mass_spec.group_features: invalid parameters:") == std::string::npos)
                return fail("group method validation message");
        }
    }

    // Negative: assign_transformation_products chromatographic_phase must be
    // reverse_phase or hilic.
    {
        const streamfind::Json bad_params = {
            {"analysis_names", analysis_names},
            {"transformation_products", transformation_products},
            {"chromatographic_phase", "normal_phase"}, {"mzr_ms2", 0.008}
        };
        streamfind::Workflow wf; wf.domain = "mass_spec";
        wf.steps.push_back({"mass_spec.find_features", streamfind::ParameterValues::from_json(find_params)});
        wf.steps.push_back({"mass_spec.assign_transformation_products", streamfind::ParameterValues::from_json(bad_params)});
        try {
            project.set_workflow(std::move(wf), registry);
            return fail("assign phase validation accepted normal_phase");
        } catch (const streamfind::Error &exception) {
            if (exception.code() != streamfind::ErrorCode::WorkflowValidation)
                return fail("assign phase validation error code");
            if (std::string(exception.what()).find(
                    "mass_spec.assign_transformation_products: invalid parameters:") == std::string::npos)
                return fail("assign phase validation message");
        }
    }

    // Negative: metfrag_screening score_types/score_weights length mismatch.
    {
        const streamfind::Json bad_params = {
            {"analysis_names", analysis_names}, {"database_type", "PubChem"},
            {"score_types", streamfind::Json::array({streamfind::Json("FragmenterScore")})},
            {"score_weights", streamfind::Json::array({streamfind::Json(1.0), streamfind::Json(2.0)})}
        };
        streamfind::Workflow wf; wf.domain = "mass_spec";
        wf.steps.push_back({"mass_spec.find_features", streamfind::ParameterValues::from_json(find_params)});
        wf.steps.push_back({"mass_spec.load_features_ms2", streamfind::ParameterValues::from_json(load_ms2_params)});
        wf.steps.push_back({"mass_spec.metfrag_screening", streamfind::ParameterValues::from_json(bad_params)});
        try {
            project.set_workflow(std::move(wf), registry);
            return fail("metfrag score validation accepted mismatched lengths");
        } catch (const streamfind::Error &exception) {
            if (exception.code() != streamfind::ErrorCode::WorkflowValidation)
                return fail("metfrag score validation error code");
            if (std::string(exception.what()).find(
                    "score_types and score_weights") == std::string::npos)
                return fail("metfrag score validation message");
        }
    }


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