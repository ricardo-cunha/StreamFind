use serde_json::{json, Value};
use std::{fs, path::Path};
use streamfind_rust_core::{
    MethodRegistry, Project, ProjectOptions, Workflow, WorkflowStep,
};

fn fixtures() -> [std::path::PathBuf; 3] {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("../../..");
    [
        root.join("tests/data/mass_spec/basic_tof/00_tof_s_is_pos_cent-r001.mzML"),
        root.join("tests/data/mass_spec/basic_tof/00_tof_s_is_pos_cent-r002.mzML"),
        root.join("tests/data/mass_spec/basic_tof/00_tof_s_is_pos_cent-r003.mzML"),
    ]
}

fn setup_project(database: &str) -> Project {
    let _ = fs::remove_file(database);
    let project = Project::create(ProjectOptions {
        database_path: database.into(),
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
    project
}

/// Run a single workflow method with explicit parameters (mirrors the existing
/// wastewater test harness: the workflow declares the method as a pending step).
fn run_method(project: &mut Project, methods: &MethodRegistry, method: &str, parameters: Value) {
    project
        .set_workflow(
            Workflow {
                name: String::new(),
                version: 1,
                domain: "mass_spec".into(),
                steps: vec![WorkflowStep {
                    method: method.into(),
                    parameters: parameters.clone(),
                    metadata: None,
                }],
            },
            methods,
        )
        .unwrap();
    project.run_method(method, &parameters, methods).unwrap();
}

#[test]
fn loads_ms1_and_ms2_spectra_for_basic_tof_features() {
    let database = std::env::temp_dir().join("streamfind-rust-nta-basic.duckdb");
    let mut project = setup_project(database.to_str().unwrap());
    let mut methods = MethodRegistry::default();
    streamfind_rust_mass_spec::register_methods(&mut methods).unwrap();

    // Persist features first.
    run_method(
        &mut project,
        &methods,
        "mass_spec.find_features",
        json!({
            "analysis_names": ["r001", "r002", "r003"],
            "rt_windows_min": [800.0],
            "rt_windows_max": [1000.0],
            "ppm_threshold": 15.0,
            "noise_threshold": 2000.0,
            "min_snr": 5.0,
            "min_traces": 3,
            "baseline_window": 30.0,
            "max_feature_width": 60.0,
            "base_quantile": 0.1
        }),
    );
    let counts = project
        .query_json("SELECT analysis, COUNT(*) AS count FROM MASS_SPEC_NTA_FEATURES GROUP BY analysis ORDER BY analysis")
        .unwrap();
    println!("FEATURE COUNTS: {counts}");

    // Load MS1 then MS2 spectra into the matching columns.
    run_method(
        &mut project,
        &methods,
        "mass_spec.load_features_ms1",
        json!({
            "analysis_names": ["r001", "r002", "r003"],
            "filtered": false,
            "rt_window": [-2.0, 2.0],
            "mz_window": [-0.5, 0.5],
            "min_traces_intensity": 250.0,
            "mz_clust": 0.005,
            "presence": 0.5
        }),
    );
    run_method(
        &mut project,
        &methods,
        "mass_spec.load_features_ms2",
        json!({
            "analysis_names": ["r001", "r002", "r003"],
            "filtered": false,
            "min_traces_intensity": 10.0,
            "isolation_window": 1.3,
            "mz_clust": 0.005,
            "presence": 0.5
        }),
    );

    // Inspect the persisted columns.
    let ms1 = project
        .query_json("SELECT analysis, feature, rt, mz, ms1_size FROM MASS_SPEC_NTA_FEATURES WHERE ms1_size > 0 ORDER BY analysis, feature")
        .unwrap();
    let ms2 = project
        .query_json("SELECT analysis, feature, rt, mz, ms2_size FROM MASS_SPEC_NTA_FEATURES WHERE ms2_size > 0 ORDER BY analysis, feature")
        .unwrap();
    println!("MS1 POPULATED: {ms1}");
    println!("MS2 POPULATED: {ms2}");

    // Both methods must populate at least some rows.
    assert!(ms1.as_array().map(|a| !a.is_empty()).unwrap_or(false), "no MS1 rows populated");
    assert!(ms2.as_array().map(|a| !a.is_empty()).unwrap_or(false), "no MS2 rows populated");

    // The Metoprolol-D7 feature (~m/z 268.19, positive) must carry both an MS1
    // and an MS2 joined spectrum in every replicate where it was detected.
    let target = project
        .query_json("SELECT analysis, feature, rt, mz, ms1_size, ms1_mz, ms1_intensity, ms2_size, ms2_mz, ms2_intensity FROM MASS_SPEC_NTA_FEATURES WHERE ABS(mz - 268.19) < 0.05 AND polarity = 1 ORDER BY analysis")
        .unwrap();
    println!("TARGET 268.19: {target}");
    let rows = target.as_array().expect("query returned an array");
    assert!(!rows.is_empty(), "no feature found near m/z 268.19");
    for row in rows {
        let ms1_size = row["ms1_size"].as_i64().unwrap_or(0);
        let ms1_mz = row["ms1_mz"].as_str().unwrap_or("");
        let ms1_int = row["ms1_intensity"].as_str().unwrap_or("");
        assert!(ms1_size > 0, "feature {} ms1_size not populated", row["feature"]);
        assert!(!ms1_mz.is_empty(), "feature {} ms1_mz empty", row["feature"]);
        assert!(!ms1_int.is_empty(), "feature {} ms1_intensity empty", row["feature"]);
        let ms2_size = row["ms2_size"].as_i64().unwrap_or(0);
        let ms2_mz = row["ms2_mz"].as_str().unwrap_or("");
        let ms2_int = row["ms2_intensity"].as_str().unwrap_or("");
        assert!(ms2_size > 0, "feature {} ms2_size not populated", row["feature"]);
        assert!(!ms2_mz.is_empty(), "feature {} ms2_mz empty", row["feature"]);
        assert!(!ms2_int.is_empty(), "feature {} ms2_intensity empty", row["feature"]);
    }
}
