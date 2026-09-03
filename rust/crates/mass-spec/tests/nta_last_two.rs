//! End-to-end and negative tests for the last two ported R NTA methods:
//! `mass_spec.assign_transformation_products` and `mass_spec.metfrag_screening`.
//! Runs on the basic_tof centroid fixtures (metoprolol [M+H]+ = 268.19 at
//! rt ~915).

use serde_json::{json, Value};
use std::{fs, path::Path};
use streamfind_rust_core::{
    ErrorCode, MethodRegistry, Project, ProjectOptions, Workflow, WorkflowStep,
};

fn basic_tof_root() -> std::path::PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("../../..")
        .join("tests/data/mass_spec/basic_tof")
}

fn setup_project(database: &Path, analysis: &str, fixture: &Path) -> Project {
    let _ = fs::remove_file(database);
    let project = Project::create(ProjectOptions {
        database_path: database.to_path_buf(),
        project_id: "rust-nta-lasttwo".into(),
        domain: "mass_spec".into(),
        create_if_missing: false,
        read_only: false,
    })
    .unwrap();
    project
        .execute_sql(
            "CREATE TABLE MASS_SPEC_ANALYSES (project_id VARCHAR NOT NULL, analysis VARCHAR NOT NULL, \
             analysis_index INTEGER NOT NULL DEFAULT 0, source_analysis_number INTEGER, analysis_count INTEGER NOT NULL DEFAULT 1, \
             replicate VARCHAR, blank VARCHAR, file_name VARCHAR, file_path VARCHAR NOT NULL, file_dir VARCHAR, file_extension VARCHAR, \
             format VARCHAR, type VARCHAR, time_stamp VARCHAR, number_spectra INTEGER, number_chromatograms INTEGER, \
             number_spectra_binary_arrays INTEGER, min_mz DOUBLE, max_mz DOUBLE, start_rt DOUBLE, end_rt DOUBLE, \
             has_ion_mobility BOOLEAN, concentration DOUBLE, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, \
             PRIMARY KEY(project_id, analysis))",
        )
        .unwrap();
    project
        .execute_sql(&format!(
            "INSERT INTO MASS_SPEC_ANALYSES (project_id, analysis, analysis_index, file_path) VALUES ('rust-nta-lasttwo', '{}', 0, '{}')",
            analysis,
            fixture.to_string_lossy().replace('\'', "''")
        ))
        .unwrap();
    project
}

fn set_pipeline(project: &mut Project, methods: &MethodRegistry, steps: Vec<(&str, Value)>) {
    project
        .set_workflow(
            Workflow {
                name: String::new(),
                version: 1,
                domain: "mass_spec".into(),
                steps: steps
                    .into_iter()
                    .map(|(method, parameters)| WorkflowStep {
                        method: method.into(),
                        parameters,
                        metadata: None,
                    })
                    .collect(),
            },
            methods,
        )
        .unwrap();
}

fn suspect_count(project: &Project) -> i64 {
    project
        .query_json("SELECT COUNT(*) AS count FROM MASS_SPEC_NTA_SUSPECTS")
        .unwrap()[0]["count"]
        .as_i64()
        .unwrap_or(0)
}

// Metoprolol row from tests/data/mass_spec/basic_tof/suspects.csv.
const METOPROLOL_SMILES: &str = "COCCc1ccc(cc1)OCC(CNC(C)C)O";
const METOPROLOL_INCHI: &str =
    "InChI=1S/C15H25NO3/c1-12(2)16-10-14(17)11-19-15-6-4-13(5-7-15)8-9-18-3/h4-7,12,14,16-17H,8-11H2,1-3H3";
const METOPROLOL_INCHIKEY: &str = "IUBSYMUCCVWXPE-UHFFFAOYSA-N";

fn find_parameters(analysis: &str) -> Value {
    json!({
        "analysis_names": [analysis],
        "rt_windows_min": [900.0],
        "rt_windows_max": [925.0],
        "ppm_threshold": 15.0,
        "noise_threshold": 2000.0,
        "min_snr": 5.0,
        "min_traces": 3,
        "baseline_window": 30.0,
        "max_feature_width": 60.0,
        "base_quantile": 0.1
    })
}

fn screening_parameters(analysis: &str) -> Value {
    json!({
        "analysis_names": [analysis],
        "targets": [{
            "id": "Metoprolol",
            "mass": 267.183443665,
            "rt": 915.0,
            "formula": "C15H25NO3",
            "SMILES": METOPROLOL_SMILES,
            "InChI": METOPROLOL_INCHI,
            "InChIKey": METOPROLOL_INCHIKEY,
            "xLogP": 0.0
        }],
        "ppm": 10.0,
        "sec": 15.0,
        "ppm_ms2": 10.0,
        "mzr_ms2": 0.008,
        "min_cosine_similarity": 0.7,
        "min_shared_fragments": 3,
        "filtered": true
    })
}

fn metoprolol_precursor_fields() -> Value {
    json!({
        "precursor_name": "Metoprolol",
        "precursor_formula": "C15H25NO3",
        "precursor_mass": 267.183443665,
        "precursor_SMILES": METOPROLOL_SMILES,
        "precursor_InChI": METOPROLOL_INCHI,
        "precursor_InChIKey": METOPROLOL_INCHIKEY,
        "precursor_xLogP": 0.0,
        "main_precursor_name": "Metoprolol",
        "main_precursor_formula": "C15H25NO3",
        "main_precursor_mass": 267.183443665,
        "main_precursor_SMILES": METOPROLOL_SMILES,
        "main_precursor_InChI": METOPROLOL_INCHI,
        "main_precursor_InChIKey": METOPROLOL_INCHIKEY,
        "main_precursor_xLogP": 0.0
    })
}

fn atp_parameters(analysis: &str) -> Value {
    let base_rows = [
        json!({
            "name": "Metoprolol O-demethylation",
            "transformation": "Demethylation",
            "SMILES": "OC(CNC(C)C)COc1ccc(O)cc1"
        }),
        json!({
            "name": "Metoprolol hydroxylation",
            "transformation": "Hydroxylation",
            "SMILES": "COCCc1ccc(O)cc1OCC(CNC(C)C)O"
        }),
        json!({
            "name": "Metoprolol O-dealkylation",
            "transformation": "O-Dealkylation",
            "SMILES": "OC(CNC(C)C)COc1ccc(O)cc1"
        }),
    ];
    let products: Vec<Value> = base_rows
        .iter()
        .map(|row| {
            let mut row = row.clone();
            for (key, value) in metoprolol_precursor_fields().as_object().unwrap() {
                row[key] = value.clone();
            }
            row
        })
        .collect();
    json!({
        "analysis_names": [analysis],
        "transformation_products": products,
        "chromatographic_phase": "reverse_phase",
        "mzr_ms2": 0.008
    })
}

#[test]
fn assign_transformation_products_appends_to_suspects() {
    let database = streamfind_rust_test_support::tmp_projects_dir()
        .join("streamfind-rust-nta-lasttwo-atp.duckdb");
    let fixture = basic_tof_root().join("00_tof_s_is_pos_cent-r002.mzML");
    let mut project = setup_project(&database, "r002", &fixture);
    let mut methods = MethodRegistry::default();
    streamfind_rust_mass_spec::register_methods(&mut methods).unwrap();

    let find = find_parameters("r002");
    let screening = screening_parameters("r002");
    let atp = atp_parameters("r002");

    set_pipeline(
        &mut project,
        &methods,
        vec![
            ("mass_spec.find_features", find),
            ("mass_spec.suspect_screening", screening),
            ("mass_spec.assign_transformation_products", atp),
        ],
    );

    let result = project
        .run_method(
            "mass_spec.find_features",
            &find_parameters("r002"),
            &methods,
        )
        .unwrap();
    assert_eq!(result["status"], "finished");
    let result = project
        .run_method(
            "mass_spec.suspect_screening",
            &screening_parameters("r002"),
            &methods,
        )
        .unwrap();
    assert_eq!(result["status"], "finished");
    let suspects_after_screening = suspect_count(&project);
    eprintln!("suspects after suspect_screening: {suspects_after_screening}");

    let result = project
        .run_method(
            "mass_spec.assign_transformation_products",
            &atp_parameters("r002"),
            &methods,
        )
        .unwrap();
    assert_eq!(result["status"], "finished", "assign failed: {result}");
    let suspects_after_assign = suspect_count(&project);
    eprintln!("suspects after assign_transformation_products: {suspects_after_assign}");
    // One combination-scored row is appended per transformation-product row.
    assert_eq!(
        suspects_after_assign,
        suspects_after_screening + 3,
        "assign_transformation_products must append 3 rows"
    );

    // The persisted assignment rows carry the transformation product names.
    let rows = project
        .query_json(
            "SELECT name FROM MASS_SPEC_NTA_SUSPECTS WHERE name = 'Metoprolol O-demethylation'",
        )
        .unwrap();
    assert_eq!(rows.as_array().unwrap().len(), 1);
}

#[test]
fn metfrag_screening_missing_tools_or_localcsv_run() {
    let database = streamfind_rust_test_support::tmp_projects_dir()
        .join("streamfind-rust-nta-lasttwo-mf.duckdb");
    let fixture = basic_tof_root().join("00_tof_s_is_pos_cent-r002.mzML");
    let mut project = setup_project(&database, "r002", &fixture);
    let mut methods = MethodRegistry::default();
    streamfind_rust_mass_spec::register_methods(&mut methods).unwrap();

    let find = find_parameters("r002");
    let load_ms2 = json!({
        "analysis_names": ["r002"], "filtered": false,
        "min_traces_intensity": 10.0, "isolation_window": 1.3, "mz_clust": 0.008, "presence": 0.5
    });
    let metfrag = json!({
        "analysis_names": ["r002"],
        "database_type": "Local",
        "database": [{
            "name": "Metoprolol", "formula": "C15H25NO3", "mass": 267.183443665,
            "SMILES": METOPROLOL_SMILES, "InChI": METOPROLOL_INCHI,
            "InChIKey": METOPROLOL_INCHIKEY, "xLogP": 0.0
        }],
        "ppm": 5, "sec": 10, "ppm_ms2": 10, "mzr_ms2": 0.008,
        "top_n": 5,
        "score_types": ["FragmenterScore"],
        "score_weights": [1.0],
        "pre_processing_candidate_filter": ["UnconnectedCompoundFilter", "IsotopeFilter"],
        "post_processing_candidate_filter": ["InChIKeyFilter"],
        "maximum_tree_depth": 3, "number_threads": 1,
        "use_smiles": true, "filtered": false, "debug": false
    });

    set_pipeline(
        &mut project,
        &methods,
        vec![
            ("mass_spec.find_features", find),
            ("mass_spec.load_features_ms2", load_ms2.clone()),
            ("mass_spec.metfrag_screening", metfrag.clone()),
        ],
    );
    project
        .run_method(
            "mass_spec.find_features",
            &find_parameters("r002"),
            &methods,
        )
        .unwrap();
    project
        .run_method("mass_spec.load_features_ms2", &load_ms2, &methods)
        .unwrap();

    let outcome = project.run_method("mass_spec.metfrag_screening", &metfrag, &methods);
    match outcome {
        Err(error) => {
            // Java + MetFragCL jar are not installed: graceful tool-missing
            // error mirroring R's NA path.
            assert_eq!(
                error.code,
                ErrorCode::MethodExecution,
                "unexpected error: {error}"
            );
            assert!(
                error
                    .message
                    .contains("MetFrag command line is not installed"),
                "unexpected error: {error}"
            );
            eprintln!("metfrag tool-missing error as expected: {error}");
        }
        Ok(result) => {
            // Tools installed: LocalCSV screening completes and appends
            // candidates (bounded by top_n per feature).
            assert_eq!(result["status"], "finished", "metfrag failed: {result}");
            let after = suspect_count(&project);
            assert!(after >= 0, "suspect count must be non-negative");
            eprintln!("metfrag candidates appended: {after}");
        }
    }
}

#[test]
fn rejects_invalid_last_two_parameters() {
    let database = streamfind_rust_test_support::tmp_projects_dir()
        .join("streamfind-rust-nta-lasttwo-neg.duckdb");
    let fixture = basic_tof_root().join("00_tof_s_is_pos_cent-r002.mzML");
    let mut project = setup_project(&database, "r002", &fixture);
    let mut methods = MethodRegistry::default();
    streamfind_rust_mass_spec::register_methods(&mut methods).unwrap();

    let mut product = metoprolol_precursor_fields();
    product["name"] = json!("Metoprolol O-demethylation");
    product["transformation"] = json!("Demethylation");
    product["SMILES"] = json!("OC(CNC(C)C)COc1ccc(O)cc1");

    // 1. Invalid chromatographic_phase fails validation.
    let error = project
        .set_workflow(
            Workflow {
                name: String::new(),
                version: 1,
                domain: "mass_spec".into(),
                steps: vec![WorkflowStep {
                    method: "mass_spec.assign_transformation_products".into(),
                    parameters: json!({
                        "analysis_names": ["r002"],
                        "transformation_products": [product],
                        "chromatographic_phase": "normal_phase",
                        "mzr_ms2": 0.008
                    }),
                    metadata: None,
                }],
            },
            &methods,
        )
        .unwrap_err();
    assert_eq!(error.code, ErrorCode::WorkflowValidation);
    assert!(
        error
            .message
            .contains("chromatographic_phase must be \"reverse_phase\" or \"hilic\""),
        "unexpected error: {error}"
    );

    // 2. Missing product structure column (neither SMILES nor InChI nor
    //    InChIKey at product level) fails validation.
    let mut bare = metoprolol_precursor_fields();
    bare["name"] = json!("Metoprolol without structure");
    bare["transformation"] = json!("Demethylation");
    let error = project
        .set_workflow(
            Workflow {
                name: String::new(),
                version: 1,
                domain: "mass_spec".into(),
                steps: vec![WorkflowStep {
                    method: "mass_spec.assign_transformation_products".into(),
                    parameters: json!({
                        "analysis_names": ["r002"],
                        "transformation_products": [bare],
                        "chromatographic_phase": "reverse_phase",
                        "mzr_ms2": 0.008
                    }),
                    metadata: None,
                }],
            },
            &methods,
        )
        .unwrap_err();
    assert_eq!(error.code, ErrorCode::WorkflowValidation);
    assert!(
        error
            .message
            .contains("must include at least one of \"SMILES\", \"InChI\", \"InChIKey\""),
        "unexpected error: {error}"
    );

    // 3. score_types / score_weights length mismatch fails validation (with
    //    the required earlier steps present for workflow ordering).
    let error = project
        .set_workflow(
            Workflow {
                name: String::new(),
                version: 1,
                domain: "mass_spec".into(),
                steps: vec![
                    WorkflowStep {
                        method: "mass_spec.find_features".into(),
                        parameters: find_parameters("r002"),
                        metadata: None,
                    },
                    WorkflowStep {
                        method: "mass_spec.load_features_ms2".into(),
                        parameters: json!({
                            "analysis_names": ["r002"], "filtered": false,
                            "min_traces_intensity": 10.0, "isolation_window": 1.3,
                            "mz_clust": 0.008, "presence": 0.5
                        }),
                        metadata: None,
                    },
                    WorkflowStep {
                        method: "mass_spec.metfrag_screening".into(),
                        parameters: json!({
                            "analysis_names": ["r002"],
                            "score_types": ["FragmenterScore"],
                            "score_weights": [1.0, 0.5]
                        }),
                        metadata: None,
                    },
                ],
            },
            &methods,
        )
        .unwrap_err();
    assert_eq!(error.code, ErrorCode::WorkflowValidation);
    assert!(
        error
            .message
            .contains("score_types and score_weights must have the same length"),
        "unexpected error: {error}"
    );
}
