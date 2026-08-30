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

fn assert_columns(result: &Value, names: &[&str]) {
    let columns = result["columns"].as_object().expect("columnar result");
    for name in names {
        let values = columns
            .get(*name)
            .unwrap_or_else(|| panic!("missing column {name}"));
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
fn bruker_project_outputs_match_main_reader_contract() {
    let tsf = std::env::var("STREAMFIND_BRUKER_TSF_FIXTURE").unwrap_or_else(|_| "E:/example_files/ms_merck/Beispieldaten Routine/ACC1_28127_1_blank_P1-A-1_1_2022_13602.d".into());
    let baf = std::env::var("STREAMFIND_BRUKER_BAF_FIXTURE").unwrap_or_else(|_| {
        "E:/example_files/ms_merck/Beispieldaten Routine/ACC1_24890_1_P1-B-8_1_2022_7707.d".into()
    });
    let sources = [("tsf", PathBuf::from(tsf)), ("baf", PathBuf::from(baf))];
    let database =
        streamfind_rust_test_support::tmp_projects_dir().join("bruker-project-parity.duckdb");
    let _ = fs::remove_file(&database);
    let mut project = Project::create(ProjectOptions {
        database_path: database.clone(),
        project_id: "bruker-project-parity".into(),
        domain: "mass_spec".into(),
        create_if_missing: false,
        read_only: false,
    })
    .unwrap();
    let mut operations = OperationRegistry::default();
    streamfind_rust_mass_spec::register_operations(&mut operations).unwrap();
    let additions = sources
        .iter()
        .map(|(name, path)| json!({"path": path.to_string_lossy(), "replicate_name": name}))
        .collect::<Vec<_>>();
    assert_eq!(
        project
            .run_operation(
                "mass_spec.add_analyses",
                &json!({"analyses": additions}),
                &operations
            )
            .unwrap()["row_count"],
        json!(2)
    );
    assert_columns(
        &project
            .run_operation("mass_spec.get_spectra_headers", &json!({}), &operations)
            .unwrap(),
        &HEADER_COLUMNS,
    );
    for (_, path) in sources {
        let reader = Reader::open(&path).unwrap();
        let first = reader.spectrum_data(0).unwrap();
        if reader.format() == streamfind_rust_mass_spec::reader::Format::BrukerTsf {
            let name = path.file_stem().unwrap().to_string_lossy().to_string();
            let target = json!({"id": "first", "analyses": [name], "levels": [first.level], "polarity": [first.polarity], "mz_min": first.mz[0] - 0.001, "mz_max": first.mz[0] + 0.001, "rt_min": first.retention_time - 0.001, "rt_max": first.retention_time + 0.001});
            for operation in [
                "mass_spec.get_raw_spectra",
                "mass_spec.get_raw_spectra_eic",
                "mass_spec.get_raw_spectra_ms1",
                "mass_spec.get_raw_spectra_ms2",
            ] {
                let mut parameters =
                    json!({"targets": [target], "ppm": 20.0, "rt_tolerance": 60.0});
                if operation.ends_with("_ms1") || operation.ends_with("_ms2") {
                    parameters["mz_clust"] = json!(0.003);
                    parameters["presence"] = json!(0.0);
                }
                if operation.ends_with("_ms2") {
                    parameters["isolation_window"] = json!(1.3);
                }
                assert_columns(
                    &project
                        .run_operation(operation, &parameters, &operations)
                        .unwrap(),
                    &RAW_COLUMNS,
                );
            }
        }
    }
    drop(project);
    let _ = fs::remove_file(database);
}
