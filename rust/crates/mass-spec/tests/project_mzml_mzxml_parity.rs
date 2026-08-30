#![cfg(feature = "reader-interface-tests")]

use serde_json::{json, Value};
use std::{fs, path::PathBuf};
use streamfind_rust_core::{OperationRegistry, Project, ProjectOptions};
use streamfind_rust_mass_spec::reader::Reader;

const HEADER_COLUMNS: [&str; 22] = [
    "analysis",
    "index",
    "scan",
    "array_length",
    "level",
    "mode",
    "polarity",
    "configuration",
    "lowmz",
    "highmz",
    "bpmz",
    "bpint",
    "tic",
    "rt",
    "mobility",
    "window_mz",
    "window_mzlow",
    "window_mzhigh",
    "precursor_mz",
    "precursor_intensity",
    "precursor_charge",
    "activation_ce",
];
const RAW_COLUMNS: [&str; 14] = [
    "analysis",
    "replicate",
    "target_id",
    "id",
    "polarity",
    "level",
    "pre_mz",
    "pre_mzlow",
    "pre_mzhigh",
    "pre_ce",
    "rt",
    "mobility",
    "mz",
    "intensity",
];

fn fixture_paths() -> [(String, PathBuf); 2] {
    let root = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../..");
    [
        (
            "mzml".into(),
            root.join("tests/data/mass_spec/shimadzu/karl.mzML"),
        ),
        (
            "mzxml".into(),
            root.join("tests/data/mass_spec/basic_tof/00_tof_s_is_pos_mzxml_cent-r001.mzXML"),
        ),
    ]
}

fn assert_columns(result: &Value, names: &[&str]) {
    let columns = result["columns"]
        .as_object()
        .expect("columnar operation result");
    for name in names {
        let values = columns
            .get(*name)
            .unwrap_or_else(|| panic!("missing column {name}"));
        assert!(values.as_array().is_some(), "column {name} is not an array");
        assert!(
            values
                .as_array()
                .unwrap()
                .iter()
                .all(|value| !value.is_null()),
            "column {name} contains NULL"
        );
    }
}

#[test]
fn mzml_and_mzxml_project_outputs_have_the_same_non_null_schema() {
    let database =
        streamfind_rust_test_support::tmp_projects_dir().join("mass-spec-mzml-mzxml-parity.duckdb");
    let _ = fs::remove_file(&database);
    let mut project = Project::create(ProjectOptions {
        database_path: database.clone(),
        project_id: "mzml-mzxml-parity".into(),
        domain: "mass_spec".into(),
        create_if_missing: false,
        read_only: false,
    })
    .unwrap();
    let mut operations = OperationRegistry::default();
    streamfind_rust_mass_spec::register_operations(&mut operations).unwrap();
    let mut analyses = Vec::new();
    for (name, path) in fixture_paths() {
        let reader = Reader::open(&path).unwrap();
        let first = reader.spectrum_data(0).unwrap();
        analyses.push((name, path, first));
    }
    let add = project.run_operation("mass_spec.add_analyses", &json!({"analyses": analyses.iter().map(|(name, path, _)| json!({"path": path.to_string_lossy(), "replicate_name": name})).collect::<Vec<_>>() }), &operations).unwrap();
    assert_eq!(add["row_count"], json!(2));
    let headers = project
        .run_operation("mass_spec.get_spectra_headers", &json!({}), &operations)
        .unwrap();
    assert_columns(&headers, &HEADER_COLUMNS);
    for (name, _, first) in analyses {
        let target = json!({"id": "first", "analyses": [name], "levels": [first.level], "polarity": [0], "mz_min": first.mz[0] - 0.001, "mz_max": first.mz[0] + 0.001, "rt_min": first.retention_time - 0.001, "rt_max": first.retention_time + 0.001});
        for operation in [
            "mass_spec.get_raw_spectra",
            "mass_spec.get_raw_spectra_eic",
            "mass_spec.get_raw_spectra_ms1",
            "mass_spec.get_raw_spectra_ms2",
        ] {
            let mut parameters = json!({"targets": [target], "ppm": 20.0, "rt_tolerance": 60.0});
            if operation.ends_with("_ms1") {
                parameters["mz_clust"] = json!(0.003);
                parameters["presence"] = json!(0.0);
            } else if operation.ends_with("_ms2") {
                parameters["mz_clust"] = json!(0.003);
                parameters["presence"] = json!(0.0);
                parameters["isolation_window"] = json!(1.3);
            }
            let result = project
                .run_operation(operation, &parameters, &operations)
                .unwrap();
            assert_columns(&result, &RAW_COLUMNS);
        }
    }
    drop(project);
    let _ = fs::remove_file(database);
}
