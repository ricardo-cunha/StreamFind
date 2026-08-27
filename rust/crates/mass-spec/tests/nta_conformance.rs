//! Rust NTA conformance pipeline (mirrors
//! `core/domains/mass_spec/tests/nta_wastewater_conformance.cpp` --quantized):
//! find_features -> create_components -> annotate_components ->
//! load_features_ms2 -> find_internal_standards -> filter_internal_standards ->
//! group_features -> subtract_blank -> filter_features -> filter_suspects.
//! Runs the 3-file positive-mode wastewater subset with a narrow RT window so
//! the whole pipeline finishes in minutes.

use serde_json::{json, Value};
use std::{fs, path::Path};
use streamfind_rust_core::{MethodRegistry, Project, ProjectOptions, Workflow, WorkflowStep};

fn wastewater_root() -> std::path::PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("../../..").join("tests/data/mass_spec/wastewater")
}

/// Minimal RFC-4180-ish CSV parse: rows including the header row as element 0.
fn parse_csv(path: &Path) -> Vec<Vec<String>> {
    let text = fs::read_to_string(path).unwrap_or_default();
    let mut rows = Vec::new();
    for line in text.lines() {
        if line.trim().is_empty() {
            continue;
        }
        let mut fields = Vec::new();
        let mut cur = String::new();
        let mut in_quotes = false;
        let chars: Vec<char> = line.chars().collect();
        let mut i = 0;
        while i < chars.len() {
            let c = chars[i];
            if in_quotes {
                if c == '"' && i + 1 < chars.len() && chars[i + 1] == '"' {
                    cur.push('"');
                    i += 1;
                } else if c == '"' {
                    in_quotes = false;
                } else {
                    cur.push(c);
                }
            } else if c == '"' {
                in_quotes = true;
            } else if c == ',' {
                fields.push(std::mem::take(&mut cur));
            } else {
                cur.push(c);
            }
            i += 1;
        }
        fields.push(cur);
        rows.push(fields);
    }
    rows
}

/// Build a JSON targets array from a suspect/IS CSV (name, mass, rt, SMILES,
/// InChI, InChIKey, xLogP, ms2_positive).
fn targets_from_csv(path: &Path) -> Value {
    let rows = parse_csv(path);
    if rows.is_empty() {
        return json!([]);
    }
    let header = &rows[0];
    let col = |name: &str| header.iter().position(|h| h == name);
    let mut out = Vec::new();
    for row in rows.iter().skip(1) {
        let field = |idx: Option<usize>| -> String {
            idx.and_then(|i| row.get(i)).cloned().unwrap_or_default()
        };
        let name = field(col("name"));
        if name.is_empty() {
            continue;
        }
        let mut t = serde_json::Map::new();
        t.insert("id".into(), json!(name));
        for key in ["mass", "rt"] {
            let v = field(col(key));
            if !v.is_empty() {
                if let Ok(num) = v.parse::<f64>() {
                    t.insert(key.into(), json!(num));
                }
            }
        }
        for key in ["formula", "SMILES", "InChI", "InChIKey"] {
            let v = field(col(key));
            if !v.is_empty() {
                t.insert(key.into(), json!(v));
            }
        }
        let xlogp = field(col("xLogP"));
        if !xlogp.is_empty() {
            if let Ok(num) = xlogp.parse::<f64>() {
                t.insert("xLogP".into(), json!(num));
            }
        }
        let mut ms2 = field(col("ms2_positive"));
        if ms2.is_empty() {
            ms2 = field(col("ms2_negative"));
        }
        if !ms2.is_empty() {
            let mut mz = Vec::new();
            let mut intensity = Vec::new();
            for token in ms2.split(';') {
                let parts: Vec<&str> = token.split_whitespace().collect();
                if parts.len() >= 2 {
                    if let (Ok(m), Ok(i)) = (parts[0].parse::<f64>(), parts[1].parse::<f64>()) {
                        mz.push(json!(m));
                        intensity.push(json!(i));
                    }
                }
            }
            t.insert("fragments_mz_pos".into(), json!(mz));
            t.insert("fragments_intensity_pos".into(), json!(intensity));
        }
        out.push(json!(t));
    }
    Value::Array(out)
}

fn setup_project(database: &Path) -> Project {
    let _ = fs::remove_file(database);
    let project = Project::create(ProjectOptions {
        database_path: database.to_path_buf(),
        project_id: "rust-nta-ww".into(),
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
}

/// Run a single workflow method with the pipeline installed by `set_pipeline`.
fn run_method(project: &mut Project, methods: &MethodRegistry, method: &str, parameters: Value) {
    let result = project.run_method(method, &parameters, methods).unwrap();
    assert_eq!(
        result.get("status").and_then(Value::as_str),
        Some("finished"),
        "{method} failed: {result}"
    );
}

/// Install the full ordered pipeline once; `required_methods` ordering is then
/// validated against the complete workflow and `run_method` executes one step per call.
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

#[test]
fn nta_quantized_wastewater_pipeline() {
    let ww = wastewater_root();
    let files = [
        "01_tof_ww_is_pos_blank-r001.mzML",
        "02_tof_ww_is_pos_influent-r001.mzML",
        "03_tof_ww_is_pos_o3sw_effluent-r001.mzML",
    ];
    let database = streamfind_rust_test_support::tmp_projects_dir().join("streamfind-rust-nta-ww.duckdb");
    let mut project = setup_project(&database);
    let mut methods = MethodRegistry::default();
    streamfind_rust_mass_spec::register_methods(&mut methods).unwrap();

    for (fi, file) in files.iter().enumerate() {
        let path = ww.join(file);
        assert!(path.exists(), "missing fixture {path:?}");
        project
            .execute_sql(&format!(
                "INSERT INTO MASS_SPEC_ANALYSES (project_id, analysis, analysis_index, replicate, blank, file_path) VALUES ('rust-nta-ww', '{}', 0, '{}', '{}', '{}')",
                path.file_stem().unwrap().to_string_lossy(),
                match fi { 0 => "pos_blank", 1 => "pos_influent", _ => "pos_o3sw_effluent" },
                if fi == 0 { "pos_blank" } else { "pos_blank" },
                path.to_string_lossy().replace('\'', "''")
            ))
            .unwrap();
    }
    let analysis_names: Vec<Value> = files
        .iter()
        .map(|f| json!(Path::new(f).file_stem().unwrap().to_string_lossy().to_string()))
        .collect();

    let is_csv = ww.join("internal_standards.csv");
    let is_targets = targets_from_csv(&is_csv);
    assert!(!is_targets.as_array().unwrap().is_empty(), "no IS targets parsed");
    eprintln!("internal standard targets parsed: {}", is_targets.as_array().unwrap().len());
    let suspects_csv = ww.join("suspects.csv");
    let suspect_targets = targets_from_csv(&suspects_csv);
    assert!(!suspect_targets.as_array().unwrap().is_empty(), "no suspect targets parsed");
    eprintln!("suspect targets parsed: {}", suspect_targets.as_array().unwrap().len());

    // One full ordered pipeline: required_methods ordering is validated once at
    // set_workflow time, then every step runs via run_method in the same revision.
    set_pipeline(
        &mut project,
        &methods,
        vec![
            ("mass_spec.find_features", json!({
                "analysis_names": analysis_names,
                "rt_windows_min": [850.0],
                "rt_windows_max": [1100.0],
                "ppm_threshold": 10.0, "noise_threshold": 250.0, "min_snr": 3.0,
                "min_traces": 3, "baseline_window": 200.0, "max_feature_width": 100.0, "base_quantile": 0.99
            })),
            ("mass_spec.create_components", json!({
                "analysis_names": analysis_names,
                "rt_window": [-2.5, 2.5],
                "min_correlation": 0.85
            })),
            ("mass_spec.annotate_components", json!({
                "analysis_names": analysis_names,
                "max_isotopes": 8, "max_charge": 1, "max_gaps": 1, "ppm": 10.0,
                "isotope_elements": ["C:1-80", "N:0-10", "O:0-20", "S:0-4", "Cl:0-6", "Br:0-4"]
            })),
            ("mass_spec.load_features_ms2", json!({
                "analysis_names": analysis_names, "filtered": false,
                "min_traces_intensity": 10.0, "isolation_window": 1.3, "mz_clust": 0.008, "presence": 0.5
            })),
            ("mass_spec.find_internal_standards", json!({
                "analysis_names": analysis_names, "targets": is_targets,
                "ppm": 10.0, "sec": 15.0, "ppm_ms2": 10.0, "mzr_ms2": 0.008,
                "min_cosine_similarity": 0.7, "min_shared_fragments": 3, "filtered": true
            })),
            ("mass_spec.filter_internal_standards", json!({ "analysis_names": analysis_names, "id_levels": [1, 2, 3] })),
            ("mass_spec.group_features", json!({
                "analysis_names": analysis_names, "method": "internal_standards",
                "rt_deviation": 5.0, "ppm": 10.0, "min_samples": 1, "bin_size": 5.0
            })),
            ("mass_spec.subtract_blank", json!({
                "analysis_names": analysis_names, "blank_threshold": 5.0, "rt_expand": 10.0, "mz_expand": 0.005
            })),
            ("mass_spec.filter_features", json!({
                "analysis_names": analysis_names,
                "min_intensity": 10000.0,
                "remove_isotopes": true, "remove_adducts": true, "remove_losses": true
            })),
            ("mass_spec.suspect_screening", json!({
                "analysis_names": analysis_names, "targets": suspect_targets,
                "ppm": 10.0, "sec": 15.0, "ppm_ms2": 10.0, "mzr_ms2": 0.008,
                "min_cosine_similarity": 0.7, "min_shared_fragments": 3, "filtered": true
            })),
            ("mass_spec.filter_suspects", json!({ "analysis_names": analysis_names, "id_levels": [1, 2] })),
        ],
    );

    run_method(
        &mut project,
        &methods,
        "mass_spec.find_features",
        json!({
            "analysis_names": analysis_names,
            "rt_windows_min": [850.0],
            "rt_windows_max": [1100.0],
            "ppm_threshold": 10.0, "noise_threshold": 250.0, "min_snr": 3.0,
            "min_traces": 3, "baseline_window": 200.0, "max_feature_width": 100.0, "base_quantile": 0.99
        }),
    );
    let feats = project
        .query_json("SELECT COUNT(*) AS count FROM MASS_SPEC_NTA_FEATURES")
        .unwrap();
    let feat_count = feats[0]["count"].as_i64().unwrap_or(0);
    assert!(feat_count > 0, "find_features produced no features");
    eprintln!("features detected: {feat_count}");

    run_method(
        &mut project,
        &methods,
        "mass_spec.create_components",
        json!({
            "analysis_names": analysis_names,
            "rt_window": [-2.5, 2.5],
            "min_correlation": 0.85
        }),
    );
    run_method(
        &mut project,
        &methods,
        "mass_spec.annotate_components",
        json!({
            "analysis_names": analysis_names,
            "max_isotopes": 8, "max_charge": 1, "max_gaps": 1, "ppm": 10.0,
            "isotope_elements": ["C:1-80", "N:0-10", "O:0-20", "S:0-4", "Cl:0-6", "Br:0-4"]
        }),
    );
    run_method(
        &mut project,
        &methods,
        "mass_spec.load_features_ms2",
        json!({
            "analysis_names": analysis_names, "filtered": false,
            "min_traces_intensity": 10.0, "isolation_window": 1.3, "mz_clust": 0.008, "presence": 0.5
        }),
    );

    let is_csv = ww.join("internal_standards.csv");
    let is_targets = targets_from_csv(&is_csv);
    assert!(!is_targets.as_array().unwrap().is_empty(), "no IS targets parsed");
    eprintln!("internal standard targets parsed: {}", is_targets.as_array().unwrap().len());
    run_method(
        &mut project,
        &methods,
        "mass_spec.find_internal_standards",
        json!({
            "analysis_names": analysis_names, "targets": is_targets,
            "ppm": 10.0, "sec": 15.0, "ppm_ms2": 10.0, "mzr_ms2": 0.008,
            "min_cosine_similarity": 0.7, "min_shared_fragments": 3, "filtered": true
        }),
    );
    let is_rows = project
        .query_json("SELECT COUNT(*) AS count FROM MASS_SPEC_NTA_INTERNAL_STANDARDS")
        .unwrap();
    let is_found = is_rows[0]["count"].as_i64().unwrap_or(0);
    eprintln!("internal standards found: {is_found}");

    run_method(
        &mut project,
        &methods,
        "mass_spec.filter_internal_standards",
        json!({ "analysis_names": analysis_names, "id_levels": [1, 2, 3] }),
    );
    let is_after = project
        .query_json("SELECT COUNT(*) AS count FROM MASS_SPEC_NTA_INTERNAL_STANDARDS")
        .unwrap();
    eprintln!("internal standards after filter: {}", is_after[0]["count"]);

    run_method(
        &mut project,
        &methods,
        "mass_spec.group_features",
        json!({
            "analysis_names": analysis_names, "method": "internal_standards",
            "rt_deviation": 5.0, "ppm": 10.0, "min_samples": 1, "bin_size": 5.0
        }),
    );
    let groups = project
        .query_json(
            "SELECT COUNT(DISTINCT feature_group) AS count FROM MASS_SPEC_NTA_FEATURES WHERE feature_group != ''",
        )
        .unwrap();
    eprintln!("feature groups: {}", groups[0]["count"]);

    run_method(
        &mut project,
        &methods,
        "mass_spec.subtract_blank",
        json!({
            "analysis_names": analysis_names, "blank_threshold": 5.0, "rt_expand": 10.0, "mz_expand": 0.005
        }),
    );
    run_method(
        &mut project,
        &methods,
        "mass_spec.filter_features",
        json!({
            "analysis_names": analysis_names,
            "min_intensity": 10000.0,
            "remove_isotopes": true, "remove_adducts": true, "remove_losses": true
        }),
    );
    let suspects_csv = ww.join("suspects.csv");
    let suspect_targets = targets_from_csv(&suspects_csv);
    assert!(!suspect_targets.as_array().unwrap().is_empty(), "no suspect targets parsed");
    eprintln!("suspect targets parsed: {}", suspect_targets.as_array().unwrap().len());
    run_method(
        &mut project,
        &methods,
        "mass_spec.suspect_screening",
        json!({
            "analysis_names": analysis_names, "targets": suspect_targets,
            "ppm": 10.0, "sec": 15.0, "ppm_ms2": 10.0, "mzr_ms2": 0.008,
            "min_cosine_similarity": 0.7, "min_shared_fragments": 3, "filtered": true
        }),
    );
    run_method(
        &mut project,
        &methods,
        "mass_spec.filter_suspects",
        json!({ "analysis_names": analysis_names, "id_levels": [1, 2] }),
    );

    let _ = fs::remove_file(database);
        eprintln!("NTA wastewater QUANTIZED conformance pipeline completed successfully.");
}