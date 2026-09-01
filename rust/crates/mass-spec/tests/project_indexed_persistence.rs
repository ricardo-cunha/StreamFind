#![cfg(feature = "reader-interface-tests")]

use serde_json::{json, Value};
use std::{
    fs,
    path::{Path, PathBuf},
};
use streamfind_rust_core::{OperationRegistry, Project, ProjectOptions};

fn root() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../..")
}

fn create_project(name: &str) -> (Project, PathBuf, OperationRegistry) {
    let database = streamfind_rust_test_support::tmp_projects_dir().join(format!("{name}.duckdb"));
    let _ = fs::remove_file(&database);
    let project = Project::create(ProjectOptions {
        database_path: database.clone(),
        project_id: name.into(),
        domain: "mass_spec".into(),
        create_if_missing: false,
        read_only: false,
    })
    .unwrap();
    let mut operations = OperationRegistry::default();
    streamfind_rust_mass_spec::register_operations(&mut operations).unwrap();
    (project, database, operations)
}

fn add_sources(project: &mut Project, operations: &OperationRegistry, paths: &[&Path]) {
    let analyses = paths
        .iter()
        .map(|path| json!({"path": path}))
        .collect::<Vec<_>>();
    let result = project
        .run_operation(
            "mass_spec.add_analyses",
            &json!({"analyses": analyses}),
            operations,
        )
        .unwrap();
    assert_eq!(result["row_count"], paths.len());
}

fn columns(result: &Value, name: &str) -> Vec<Value> {
    result["columns"][name].as_array().unwrap().clone()
}

#[test]
fn persists_multiple_files_and_reopens_indexed_analysis_selection() {
    let files = [
        root().join("tests/data/mass_spec/wastewater/01_tof_ww_is_pos_blank-r001.mzML"),
        root().join("tests/data/mass_spec/wastewater/01_tof_ww_is_pos_blank-r002.mzML"),
        root().join("tests/data/mass_spec/wastewater/01_tof_ww_is_pos_blank-r003.mzML"),
    ];
    let (mut project, database, operations) = create_project("mass-spec-multi-file-indexed");
    add_sources(
        &mut project,
        &operations,
        files
            .iter()
            .map(PathBuf::as_path)
            .collect::<Vec<_>>()
            .as_slice(),
    );
    let names = project
        .run_operation("mass_spec.get_analysis_names", &json!({}), &operations)
        .unwrap();
    assert_eq!(names.as_array().unwrap().len(), 3);

    let all = project
        .run_operation("mass_spec.get_spectra_headers", &json!({}), &operations)
        .unwrap();
    assert!(all["row_count"].as_u64().unwrap() > 0);
    let selected_name = names.as_array().unwrap()[1].as_str().unwrap();
    let indexed = project
        .run_operation(
            "mass_spec.get_raw_spectra",
            &json!({
                "analysis_names": [selected_name],
                "indices": [0],
                "targets": [{"mz_min": 99999.0, "mz_max": 100000.0, "rt_min": 0.0, "rt_max": 1.0}]
            }),
            &operations,
        )
        .unwrap();
    assert!(indexed["row_count"].as_u64().unwrap() > 0);
    assert!(columns(&indexed, "analysis")
        .iter()
        .all(|value| value == selected_name));
    assert!(columns(&indexed, "target_id")
        .iter()
        .all(|value| value == "spectrum:0"));
    let multiple = project
        .run_operation(
            "mass_spec.get_raw_spectra",
            &json!({"analysis_names": [selected_name], "indices": [0, 1], "levels": [1]}),
            &operations,
        )
        .unwrap();
    assert!(multiple["row_count"].as_u64().unwrap() >= indexed["row_count"].as_u64().unwrap());
    assert!(columns(&multiple, "target_id")
        .iter()
        .all(|value| value == "spectrum:0" || value == "spectrum:1"));
    assert!(project
        .run_operation(
            "mass_spec.get_raw_spectra",
            &json!({"analysis_names": [selected_name], "indices": [999999]}),
            &operations,
        )
        .is_err());

    let selected_path = &files[1];
    let selected_reader = streamfind_rust_mass_spec::reader::Reader::open(selected_path).unwrap();
    let selected_spectrum = selected_reader.spectrum_data(0).unwrap();
    let mz = selected_spectrum.mz[0];
    let rt = selected_spectrum.retention_time;
    let target = json!({"id": "first", "mz_min": mz - 0.001, "mz_max": mz + 0.001, "rt_min": rt - 0.001, "rt_max": rt + 0.001, "polarity": [0], "levels": [selected_spectrum.level]});
    let fallback = project
        .run_operation(
            "mass_spec.get_raw_spectra",
            &json!({"analysis_names": [selected_name], "indices": [], "targets": [target]}),
            &operations,
        )
        .unwrap();
    assert!(fallback["row_count"].as_u64().unwrap() > 0);
    assert!(columns(&fallback, "target_id")
        .iter()
        .all(|value| value == "first"));
    let omitted = project
        .run_operation(
            "mass_spec.get_raw_spectra",
            &json!({"analysis_names": [selected_name], "targets": [target]}),
            &operations,
        )
        .unwrap();
    assert_eq!(omitted, fallback);

    drop(project);
    let mut reopened = Project::open(ProjectOptions {
        database_path: database.clone(),
        project_id: "mass-spec-multi-file-indexed".into(),
        domain: "mass_spec".into(),
        create_if_missing: false,
        read_only: false,
    })
    .unwrap();
    let reopened_names = reopened
        .run_operation("mass_spec.get_analysis_names", &json!({}), &operations)
        .unwrap();
    assert_eq!(reopened_names, names);
    let reopened_indexed = reopened
        .run_operation(
            "mass_spec.get_raw_spectra",
            &json!({"analysis_names": [selected_name], "indices": [0]}),
            &operations,
        )
        .unwrap();
    assert_eq!(reopened_indexed["row_count"], indexed["row_count"]);
    assert!(columns(&reopened_indexed, "analysis")
        .iter()
        .all(|value| value == selected_name));
    drop(reopened);
    fs::remove_file(database).unwrap();
}

#[test]
fn persists_and_reopens_opt_in_multi_analysis_wiff() {
    let Ok(path) = std::env::var("STREAMFIND_SCIEX_MULTI_WIFF_FIXTURE") else {
        return;
    };
    let fixture = PathBuf::from(path);
    if !fixture.exists() {
        return;
    }
    let (mut project, database, operations) = create_project("mass-spec-sciex-multi-analysis");
    add_sources(&mut project, &operations, &[fixture.as_path()]);
    let names = project
        .run_operation("mass_spec.get_analysis_names", &json!({}), &operations)
        .unwrap();
    assert!(names.as_array().unwrap().len() > 1);
    for name in names
        .as_array()
        .unwrap()
        .iter()
        .map(|value| value.as_str().unwrap())
    {
        let headers = project
            .run_operation(
                "mass_spec.get_spectra_headers",
                &json!({"analysis_names": [name]}),
                &operations,
            )
            .unwrap();
        assert!(
            headers["row_count"].as_u64().unwrap() > 0,
            "analysis {name} has no headers"
        );
    }
    drop(project);
    let mut reopened = Project::open(ProjectOptions {
        database_path: database.clone(),
        project_id: "mass-spec-sciex-multi-analysis".into(),
        domain: "mass_spec".into(),
        create_if_missing: false,
        read_only: false,
    })
    .unwrap();
    assert_eq!(
        reopened
            .run_operation("mass_spec.get_analysis_names", &json!({}), &operations)
            .unwrap(),
        names
    );
    drop(reopened);
    fs::remove_file(database).unwrap();
}
