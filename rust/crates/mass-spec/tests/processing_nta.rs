use serde_json::json;
use std::fs;
use streamfind_rust_core::{
    ErrorCode, MethodRegistry, OperationRegistry, Project, ProjectOptions, Workflow, WorkflowStep,
};

fn fixtures() -> [std::path::PathBuf; 3] {
    let root = streamfind_rust_test_support::example_data_dir()
        .expect("streamfind.data unavailable; set STREAMFIND_EXAMPLE_DATA_ROOT");
    [
        root.join("mass_spec/wastewater/01_tof_ww_is_pos_blank-r001.mzML"),
        root.join("mass_spec/wastewater/01_tof_ww_is_pos_blank-r002.mzML"),
        root.join("mass_spec/wastewater/01_tof_ww_is_pos_blank-r003.mzML"),
    ]
}

#[test]
fn finds_wastewater_features() {
    let database = streamfind_rust_test_support::tmp_projects_dir()
        .join("streamfind-rust-nta-wastewater.duckdb");
    let _ = fs::remove_file(&database);
    let mut project = Project::create(ProjectOptions {
        database_path: database,
        project_id: "rust-nta".into(),
        domain: "mass_spec".into(),
        create_if_missing: false,
        read_only: false,
    })
    .unwrap();
    project
        .execute_sql("CREATE TABLE MASS_SPEC_ANALYSES (project_id VARCHAR, analysis VARCHAR, file_path VARCHAR, analysis_index INTEGER DEFAULT 0)")
        .unwrap();
    for (analysis, fixture) in ["r001", "r002", "r003"].into_iter().zip(fixtures()) {
        project
            .execute_sql(&format!(
                "INSERT INTO MASS_SPEC_ANALYSES (project_id, analysis, file_path) VALUES ('rust-nta', '{}', '{}')",
                analysis,
                fixture.to_string_lossy().replace('\'', "''")
            ))
            .unwrap();
    }
    let mut methods = MethodRegistry::default();
    streamfind_rust_mass_spec::register_methods(&mut methods).unwrap();
    let find_features = methods.get("mass_spec.find_features").unwrap();
    assert!(find_features.cacheable);
    assert!(find_features.required_methods.is_empty());
    assert!(find_features.single_occurrence);
    project.set_workflow(Workflow { name: String::new(), version: 1, domain: "mass_spec".into(), steps: vec![WorkflowStep { method: "mass_spec.find_features".into(), parameters: json!({
        "analysis_names": ["r001", "r002", "r003"], "rt_windows_min": [800.0], "rt_windows_max": [1000.0], "ppm_threshold": 12.0, "noise_threshold": 500.0, "min_snr": 15.0, "min_traces": 5, "baseline_window": 30.0, "max_feature_width": 60.0, "base_quantile": 0.1
    }), metadata: None }] }, &methods).unwrap();
    project
        .run_method(
            "mass_spec.find_features",
            &json!({
                "analysis_names": ["r001", "r002", "r003"],
                "rt_windows_min": [800.0],
                                "rt_windows_max": [1000.0],
                "ppm_threshold": 12.0,
                "noise_threshold": 500.0,
                "min_snr": 15.0,
                "min_traces": 5,
                "baseline_window": 30.0,
                "max_feature_width": 60.0,
                "base_quantile": 0.1
            }),
            &methods,
        )
        .unwrap();
    let counts = project
        .query_json("SELECT analysis, COUNT(*) AS count FROM MASS_SPEC_NTA_FEATURES GROUP BY analysis ORDER BY analysis")
        .unwrap();
    println!("Rust wastewater feature counts: {counts}");
    let counts = counts.as_array().unwrap();
    assert_eq!(counts.len(), 3);
    assert_eq!(counts.len(), 3);
    assert_eq!(counts[0]["analysis"], "r001");
    assert_eq!(counts[0]["count"], 30);
    assert_eq!(counts[1]["analysis"], "r002");
    assert_eq!(counts[1]["count"], 33);
    assert_eq!(counts[2]["analysis"], "r003");
    assert_eq!(counts[2]["count"], 32);
    assert_eq!(
        project
            .query_json("SELECT COUNT(*) AS count FROM MASS_SPEC_NTA_FEATURES")
            .unwrap()[0]["count"],
        95
    );
    assert_eq!(
        project
            .query_json("SELECT COUNT(*) AS count FROM MASS_SPEC_NTA_FEATURES WHERE ABS(mass - 274.227) < 0.01 AND ABS(rt - 915.0) < 5.0")
            .unwrap()[0]["count"],
        3
    );
    let mut operations = OperationRegistry::default();
    streamfind_rust_mass_spec::register_operations(&mut operations).unwrap();
    let features = project
        .run_operation(
            "mass_spec.get_features",
            &json!({
                "analysis_names": ["r001", "r002", "r003"],
                "targets": [{"id": "Metoprolol-D7", "mass": 274.227, "rt": 915.0, "polarity": 1}],
                "ppm": 20.0,
                "rt_tolerance": 5.0
            }),
            &operations,
        )
        .unwrap();
    assert_eq!(features["row_count"], 3);
    assert!(features["columns"].get("feature").is_some());
    assert!(features["columns"].get("component_bridge_flag").is_some());
}

#[test]
fn rejects_invalid_nta_parameters() {
    let database = streamfind_rust_test_support::tmp_projects_dir()
        .join("streamfind-rust-nta-validator.duckdb");
    let _ = fs::remove_file(&database);
    let mut project = Project::create(ProjectOptions {
        database_path: database,
        project_id: "rust-nta-validator".into(),
        domain: "mass_spec".into(),
        create_if_missing: false,
        read_only: false,
    })
    .unwrap();
    project
        .execute_sql("CREATE TABLE MASS_SPEC_ANALYSES (project_id VARCHAR, analysis VARCHAR, file_path VARCHAR, analysis_index INTEGER DEFAULT 0)")
        .unwrap();
    let mut methods = MethodRegistry::default();
    streamfind_rust_mass_spec::register_methods(&mut methods).unwrap();
    let analysis_names: Vec<serde_json::Value> = fixtures()
        .iter()
        .map(|fixture| json!(fixture.file_stem().unwrap().to_string_lossy().to_string()))
        .collect();
    let find_features_parameters = json!({
        "analysis_names": analysis_names.clone(),
        "rt_windows_min": [800.0], "rt_windows_max": [1000.0],
        "ppm_threshold": 12.0, "noise_threshold": 500.0, "min_snr": 15.0,
        "min_traces": 5, "baseline_window": 30.0, "max_feature_width": 60.0, "base_quantile": 0.1
    });

    // 1. filter_suspects without an earlier suspect_screening step fails ordering.
    let error = project
        .set_workflow(
            Workflow {
                name: String::new(),
                version: 1,
                domain: "mass_spec".into(),
                steps: vec![
                    WorkflowStep {
                        method: "mass_spec.find_features".into(),
                        parameters: find_features_parameters.clone(),
                        metadata: None,
                    },
                    WorkflowStep {
                        method: "mass_spec.filter_suspects".into(),
                        parameters: json!({ "analysis_names": analysis_names.clone(), "id_levels": [1, 2] }),
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
            .contains("required method is not earlier in workflow: mass_spec.suspect_screening"),
        "unexpected workflow error: {error}"
    );

    // 2. suspect_screening targets without mass/mz/formula/SMILES/InChI fail.
    let error = project
        .set_workflow(
            Workflow {
                name: String::new(),
                version: 1,
                domain: "mass_spec".into(),
                steps: vec![
                    WorkflowStep {
                        method: "mass_spec.find_features".into(),
                        parameters: find_features_parameters.clone(),
                        metadata: None,
                    },
                    WorkflowStep {
                        method: "mass_spec.suspect_screening".into(),
                        parameters: json!({ "analysis_names": analysis_names.clone(), "targets": [{"id": "caffeine"}] }),
                        metadata: None,
                    },
                ],
            },
            &methods,
        )
        .unwrap_err();
    assert_eq!(error.code, ErrorCode::WorkflowValidation);
    assert!(
        error.message.contains(
            "mass_spec.suspect_screening: invalid parameters: targets[0] must provide at least one"
        ),
        "unexpected error: {error}"
    );

    // 3. group_features with an unknown alignment method fails.
    let error = project
        .set_workflow(
            Workflow {
                name: String::new(),
                version: 1,
                domain: "mass_spec".into(),
                steps: vec![
                    WorkflowStep {
                        method: "mass_spec.find_features".into(),
                        parameters: find_features_parameters.clone(),
                        metadata: None,
                    },
                    WorkflowStep {
                        method: "mass_spec.group_features".into(),
                        parameters: json!({
                            "analysis_names": analysis_names.clone(),
                            "method": "obiwarp",
                            "rt_deviation": 5.0, "ppm": 10.0, "min_samples": 1, "bin_size": 5.0
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
            .contains("mass_spec.group_features: invalid parameters: method must be"),
        "unexpected error: {error}"
    );
}
