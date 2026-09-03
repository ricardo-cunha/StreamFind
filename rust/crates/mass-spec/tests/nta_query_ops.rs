//! Integration tests for the NTA table query Operations
//! `mass_spec.get_suspects`, `mass_spec.get_internal_standards` and
//! `mass_spec.get_transformation_products` (mirroring
//! `mass_spec.get_features`), plus the `assign_transformation_products`
//! persistence of real transformation-product rows to the NEW
//! `MASS_SPEC_NTA_TRANSFORMATION_PRODUCTS` table.
//! Runs on the basic_tof centroid fixture (metoprolol [M+H]+ = 268.19 at
//! rt ~915; Metoprolol-D7 internal standard at rt 915).

use serde_json::{json, Value};
use std::{fs, path::Path};
use streamfind_rust_core::{
    MethodRegistry, OperationRegistry, Project, ProjectOptions, Workflow, WorkflowStep,
};

fn basic_tof_root() -> std::path::PathBuf {
    streamfind_rust_test_support::example_data_dir()
        .expect("streamfind.data unavailable; set STREAMFIND_EXAMPLE_DATA_ROOT")
        .join("mass_spec/basic_tof")
}

fn setup_project(database: &Path, analysis: &str, fixture: &Path) -> Project {
    let _ = fs::remove_file(database);
    let project = Project::create(ProjectOptions {
        database_path: database.to_path_buf(),
        project_id: "rust-nta-query-ops".into(),
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
            "INSERT INTO MASS_SPEC_ANALYSES (project_id, analysis, analysis_index, file_path) VALUES ('rust-nta-query-ops', '{}', 0, '{}')",
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

// Metoprolol row from streamfind.data/mass_spec/basic_tof/suspects.csv.
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
    atp_parameters_with_products(analysis, true)
}

fn atp_parameters_with_products(analysis: &str, with_products: bool) -> Value {
    let base_rows = [
        json!({
            "name": "Metoprolol O-demethylation",
            "transformation": "Demethylation",
            "mass": 253.1678,
            "SMILES": "OC(CNC(C)C)COc1ccc(O)cc1"
        }),
        json!({
            "name": "Metoprolol hydroxylation",
            "transformation": "Hydroxylation",
            "mass": 283.1783,
            "SMILES": "COCCc1ccc(O)cc1OCC(CNC(C)C)O"
        }),
        json!({
            "name": "Metoprolol O-dealkylation",
            "transformation": "O-Dealkylation",
            "mass": 207.1485,
            "SMILES": "OC(CNC(C)C)COc1ccc(O)cc1"
        }),
    ];
    let products: Vec<Value> = if with_products {
        base_rows
            .iter()
            .map(|row| {
                let mut row = row.clone();
                for (key, value) in metoprolol_precursor_fields().as_object().unwrap() {
                    row[key] = value.clone();
                }
                row
            })
            .collect()
    } else {
        Vec::new()
    };
    json!({
        "analysis_names": [analysis],
        "transformation_products": products,
        "chromatographic_phase": "reverse_phase",
        "mzr_ms2": 0.008
    })
}

fn run_operations_assert(project: &mut Project, operations: &OperationRegistry) {
    // Default targets (absent) return the ENTIRE suspects table.
    let all = project
        .run_operation("mass_spec.get_suspects", &json!({}), operations)
        .unwrap();
    assert!(
        all["row_count"].as_i64().unwrap_or(-1) >= 0,
        "get_suspects failed: {all}"
    );
    assert_eq!(all["row_count"].as_i64().unwrap(), suspect_count(project));
    // Emitted keys match the suspectsResult catalogue schema.
    let columns = all["columns"].as_object().unwrap();
    for key in [
        "project_id",
        "analysis",
        "feature",
        "feature_group",
        "candidate_rank",
        "name",
        "polarity",
        "db_mass",
        "exp_mass",
        "db_rt",
        "exp_rt",
        "SMILES",
        "InChI",
        "InChIKey",
        "xLogP",
        "created_at",
    ] {
        assert!(
            columns.contains_key(key),
            "get_suspects missing column key {key}"
        );
    }
}

#[test]
fn get_suspects_and_transformation_products_query_persisted_rows() {
    let database = streamfind_rust_test_support::tmp_projects_dir()
        .join("streamfind-rust-nta-query-ops.duckdb");
    let fixture = basic_tof_root().join("00_tof_s_is_pos_cent-r002.mzML");
    let mut project = setup_project(&database, "r002", &fixture);
    let mut methods = MethodRegistry::default();
    streamfind_rust_mass_spec::register_methods(&mut methods).unwrap();
    let mut operations = OperationRegistry::default();
    streamfind_rust_mass_spec::register_operations(&mut operations).unwrap();

    set_pipeline(
        &mut project,
        &methods,
        vec![
            ("mass_spec.find_features", find_parameters("r002")),
            ("mass_spec.suspect_screening", screening_parameters("r002")),
            (
                "mass_spec.assign_transformation_products",
                atp_parameters("r002"),
            ),
        ],
    );

    for (method, params) in [
        ("mass_spec.find_features", find_parameters("r002")),
        ("mass_spec.suspect_screening", screening_parameters("r002")),
    ] {
        let result = project.run_method(method, &params, &methods).unwrap();
        assert_eq!(result["status"], "finished", "{method} failed: {result}");
    }
    let suspects_after_screening = suspect_count(&project);

    let result = project
        .run_method(
            "mass_spec.assign_transformation_products",
            &atp_parameters("r002"),
            &methods,
        )
        .unwrap();
    assert_eq!(result["status"], "finished", "assign failed: {result}");
    let suspects_after_assign = suspect_count(&project);
    assert_eq!(
        suspects_after_assign,
        suspects_after_screening + 3,
        "assign_transformation_products must append 3 rows"
    );

    // --- mass_spec.get_suspects ---
    run_operations_assert(&mut project, &operations);
    let by_analysis = project
        .run_operation(
            "mass_spec.get_suspects",
            &json!({ "analysis_names": ["r002"] }),
            &operations,
        )
        .unwrap();
    assert_eq!(
        by_analysis["row_count"].as_i64().unwrap(),
        suspects_after_assign,
        "analysis_names filter must be inclusive"
    );
    let none = project
        .run_operation(
            "mass_spec.get_suspects",
            &json!({ "analysis_names": ["missing"] }),
            &operations,
        )
        .unwrap();
    assert_eq!(none["row_count"].as_i64().unwrap(), 0);
    // TP-assigned suspect rows are appended with polarity 0
    // (transformation_product_to_suspect); screening rows carry the feature
    // polarity (1 for the positive-mode fixture), so polarity 0 selects
    // exactly the 3 assignment rows.
    let polarity_zero = project
        .run_operation(
            "mass_spec.get_suspects",
            &json!({ "targets": [{ "polarity": 0 }] }),
            &operations,
        )
        .unwrap();
    assert_eq!(
        polarity_zero["row_count"].as_i64().unwrap(),
        3,
        "polarity 0 must select only the TP-assigned suspect rows: {polarity_zero}"
    );
    // Mass window (±ppm) against db_mass/exp_mass picks the screening row.
    let by_mass = project
        .run_operation(
            "mass_spec.get_suspects",
            &json!({ "targets": [{ "mass": 267.1834, "ppm": 20.0 }] }),
            &operations,
        )
        .unwrap();
    assert!(
        by_mass["row_count"].as_i64().unwrap() >= 1,
        "mass target must match the Metoprolol suspect row: {by_mass}"
    );

    // --- mass_spec.get_transformation_products ---
    // Reads ONLY the new TP table: one row per assigned transformation product.
    let tp_rows = project
        .query_json("SELECT * FROM MASS_SPEC_NTA_TRANSFORMATION_PRODUCTS ORDER BY name")
        .unwrap();
    let tp_rows = tp_rows.as_array().unwrap();
    assert_eq!(tp_rows.len(), 3, "expected 3 persisted TP rows");
    let tp_all = project
        .run_operation(
            "mass_spec.get_transformation_products",
            &json!({}),
            &operations,
        )
        .unwrap();
    assert_eq!(tp_all["row_count"].as_i64().unwrap(), 3);
    let tp_columns = tp_all["columns"].as_object().unwrap();
    for key in [
        "project_id",
        "analysis",
        "feature_group",
        "precursor_feature_group",
        "main_precursor_feature_group",
        "assignment_rank",
        "name",
        "formula",
        "mass",
        "SMILES",
        "InChI",
        "InChIKey",
        "xLogP",
        "transformation",
        "precursor_name",
        "precursor_formula",
        "precursor_mass",
        "precursor_SMILES",
        "precursor_InChI",
        "precursor_InChIKey",
        "precursor_xLogP",
        "main_precursor_name",
        "main_precursor_formula",
        "main_precursor_mass",
        "main_precursor_SMILES",
        "main_precursor_InChI",
        "main_precursor_InChIKey",
        "main_precursor_xLogP",
        "cosine_similarity",
        "main_precursor_cosine_similarity",
        "rt_plausibility",
        "main_precursor_rt_plausibility",
        "assignment_score",
        "network_level",
        "assignment_status",
        "created_at",
    ] {
        assert!(
            tp_columns.contains_key(key),
            "get_transformation_products missing key {key}"
        );
    }
    // The transformation-products result schema has no polarity/rt columns:
    // the op must read the NEW table, not the suspects `_transform_` rows.
    assert!(!tp_columns.contains_key("polarity"));
    assert!(!tp_columns.contains_key("rt"));
    // Per-row data round-trips: analysis + feature_group + name + scores.
    let tp_row = &tp_rows[0];
    let name = tp_row["name"].as_str().unwrap();
    let mass = tp_row["mass"].as_f64().unwrap();
    let named = project
        .run_operation(
            "mass_spec.get_transformation_products",
            &json!({ "targets": [{ "mass": mass, "ppm": 5.0 }] }),
            &operations,
        )
        .unwrap();
    assert_eq!(
        named["row_count"].as_i64().unwrap(),
        1,
        "mass window must isolate one TP row"
    );
    assert_eq!(named["columns"]["name"].as_array().unwrap()[0], name);
    // RT targets are dropped for the TP table (no rt column): the target is
    // inert and the whole table is returned, matching the get_features rule
    // that targets without matchers do not restrict.
    let rt_ignored = project
        .run_operation(
            "mass_spec.get_transformation_products",
            &json!({ "targets": [{ "rt": 915.0 }] }),
            &operations,
        )
        .unwrap();
    assert_eq!(rt_ignored["row_count"].as_i64().unwrap(), 3);
    // The catalogue declares no `polarity` parameter for the TP op (the
    // table has no polarity column), so the parameter contract rejects it.
    let polarity_rejected = project.run_operation(
        "mass_spec.get_transformation_products",
        &json!({ "polarity": 1 }),
        &operations,
    );
    assert!(
        polarity_rejected.is_err(),
        "polarity must be rejected for get_transformation_products"
    );

    let _ = fs::remove_file(database);
}

#[test]
fn get_internal_standards_query_after_is_pipeline() {
    let database = streamfind_rust_test_support::tmp_projects_dir()
        .join("streamfind-rust-nta-query-ops-is.duckdb");
    let fixture = basic_tof_root().join("00_tof_s_is_pos_cent-r002.mzML");
    let mut project = setup_project(&database, "r002", &fixture);
    let mut methods = MethodRegistry::default();
    streamfind_rust_mass_spec::register_methods(&mut methods).unwrap();
    let mut operations = OperationRegistry::default();
    streamfind_rust_mass_spec::register_operations(&mut operations).unwrap();

    // Metoprolol-D7 internal standard (streamfind.data/mass_spec/basic_tof/internal_standards.csv).
    let is_targets = json!([{
        "id": "Metoprolol-D7",
        "name": "Metoprolol-D7",
        "formula": "C15H18[2H]7NO3",
        "mass": 274.227,
        "rt": 915.0,
        "SMILES": "COCCc1ccc(cc1)OCC(CNC(C([2H])([2H])[2H])(C([2H])([2H])[2H])[2H])O",
        "InChI": "InChI=1S/C15H25NO3/c1-12(2)16-10-14(17)11-19-15-6-4-13(5-7-15)8-9-18-3/h4-7,12,14,16-17H,8-11H2,1-3H3/i1D3,2D3,12D",
        "InChIKey": "IUBSYMUCCVWXPE-QLWPOVNFSA-N",
        "xLogP": 2.0041
    }]);
    let is_find_parameters = json!({
        "analysis_names": ["r002"],
        "rt_windows_min": [850.0],
        "rt_windows_max": [1100.0],
        "ppm_threshold": 10.0,
        "noise_threshold": 250.0,
        "min_snr": 3.0,
        "min_traces": 3,
        "baseline_window": 200.0,
        "max_feature_width": 100.0,
        "base_quantile": 0.99
    });
    let is_screening_parameters = json!({
        "analysis_names": ["r002"],
        "targets": is_targets,
        "ppm": 10.0,
        "sec": 15.0,
        "ppm_ms2": 10.0,
        "mzr_ms2": 0.008,
        "min_cosine_similarity": 0.7,
        "min_shared_fragments": 3,
        "filtered": true
    });

    set_pipeline(
        &mut project,
        &methods,
        vec![
            ("mass_spec.find_features", is_find_parameters.clone()),
            (
                "mass_spec.create_components",
                json!({ "analysis_names": ["r002"], "rt_window": [-2.5, 2.5], "min_correlation": 0.85 }),
            ),
            (
                "mass_spec.annotate_components",
                json!({
                    "analysis_names": ["r002"],
                    "max_isotopes": 8, "max_charge": 1, "max_gaps": 1, "ppm": 10.0,
                    "isotope_elements": ["C:1-80", "N:0-10", "O:0-20", "S:0-4", "Cl:0-6", "Br:0-4"]
                }),
            ),
            (
                "mass_spec.load_features_ms2",
                json!({
                    "analysis_names": ["r002"], "filtered": false,
                    "min_traces_intensity": 10.0, "isolation_window": 1.3, "mz_clust": 0.008, "presence": 0.5
                }),
            ),
            (
                "mass_spec.find_internal_standards",
                is_screening_parameters.clone(),
            ),
        ],
    );

    for (method, params) in [
        ("mass_spec.find_features", is_find_parameters.clone()),
        (
            "mass_spec.create_components",
            json!({ "analysis_names": ["r002"], "rt_window": [-2.5, 2.5], "min_correlation": 0.85 }),
        ),
        (
            "mass_spec.annotate_components",
            json!({
                "analysis_names": ["r002"],
                "max_isotopes": 8, "max_charge": 1, "max_gaps": 1, "ppm": 10.0,
                "isotope_elements": ["C:1-80", "N:0-10", "O:0-20", "S:0-4", "Cl:0-6", "Br:0-4"]
            }),
        ),
        (
            "mass_spec.load_features_ms2",
            json!({
                "analysis_names": ["r002"], "filtered": false,
                "min_traces_intensity": 10.0, "isolation_window": 1.3, "mz_clust": 0.008, "presence": 0.5
            }),
        ),
        (
            "mass_spec.find_internal_standards",
            is_screening_parameters.clone(),
        ),
    ] {
        let result = project.run_method(method, &params, &methods).unwrap();
        assert_eq!(result["status"], "finished", "{method} failed: {result}");
    }

    let is_rows = project
        .query_json("SELECT COUNT(*) AS count FROM MASS_SPEC_NTA_INTERNAL_STANDARDS")
        .unwrap();
    let is_found = is_rows[0]["count"].as_i64().unwrap_or(0);
    eprintln!("internal standards found: {is_found}");

    let result = project
        .run_operation("mass_spec.get_internal_standards", &json!({}), &operations)
        .unwrap();
    // The op reads the persisted IS table faithfully: row count must match the
    // table exactly, whatever the screening found.
    assert_eq!(result["row_count"].as_i64().unwrap(), is_found);
    let columns = result["columns"].as_object().unwrap();
    for key in [
        "project_id",
        "analysis",
        "feature",
        "feature_group",
        "feature_component",
        "adduct",
        "candidate_rank",
        "name",
        "polarity",
        "db_mass",
        "exp_mass",
        "db_rt",
        "exp_rt",
        "SMILES",
        "InChI",
        "InChIKey",
        "xLogP",
        "created_at",
    ] {
        assert!(
            columns.contains_key(key),
            "get_internal_standards missing key {key}"
        );
    }
    if is_found > 0 {
        // A named analysis filter keeps the rows; mass window matches.
        let by_analysis = project
            .run_operation(
                "mass_spec.get_internal_standards",
                &json!({ "analysis_names": ["r002"] }),
                &operations,
            )
            .unwrap();
        assert_eq!(by_analysis["row_count"].as_i64().unwrap(), is_found);
        let by_mass = project
            .run_operation(
                "mass_spec.get_internal_standards",
                &json!({ "targets": [{ "mass": 274.227, "ppm": 20.0 }] }),
                &operations,
            )
            .unwrap();
        assert!(
            by_mass["row_count"].as_i64().unwrap() >= 1,
            "IS mass target must match: {by_mass}"
        );
    }

    let _ = fs::remove_file(database);
}

#[test]
fn transformation_products_table_creatable_and_queryable_when_empty() {
    let database = streamfind_rust_test_support::tmp_projects_dir()
        .join("streamfind-rust-nta-query-ops-empty.duckdb");
    let fixture = basic_tof_root().join("00_tof_s_is_pos_cent-r002.mzML");
    let mut project = setup_project(&database, "r002", &fixture);
    let mut methods = MethodRegistry::default();
    streamfind_rust_mass_spec::register_methods(&mut methods).unwrap();
    let mut operations = OperationRegistry::default();
    streamfind_rust_mass_spec::register_operations(&mut operations).unwrap();

    set_pipeline(
        &mut project,
        &methods,
        vec![
            ("mass_spec.find_features", find_parameters("r002")),
            ("mass_spec.suspect_screening", screening_parameters("r002")),
            (
                "mass_spec.assign_transformation_products",
                atp_parameters_with_products("r002", false),
            ),
        ],
    );
    for (method, params) in [
        ("mass_spec.find_features", find_parameters("r002")),
        ("mass_spec.suspect_screening", screening_parameters("r002")),
        (
            "mass_spec.assign_transformation_products",
            atp_parameters_with_products("r002", false),
        ),
    ] {
        let result = project.run_method(method, &params, &methods).unwrap();
        assert_eq!(result["status"], "finished", "{method} failed: {result}");
    }

    // The TP table is created by the assignment persist step and is queryable
    // even when no transformation products were supplied (empty result).
    let result = project
        .run_operation(
            "mass_spec.get_transformation_products",
            &json!({}),
            &operations,
        )
        .unwrap();
    assert_eq!(result["row_count"].as_i64().unwrap(), 0);
    assert!(result["columns"]["name"].is_array());

    let _ = fs::remove_file(database);
}
