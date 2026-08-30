use serde_json::{json, Value};
use std::{fs, path::PathBuf};
use streamfind_rust_core::{OperationRegistry, Project, ProjectOptions};
use streamfind_rust_mass_spec::reader::Reader;

const SPECTRA_COLUMNS: [&str; 22] = [
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
const CHROM_COLUMNS: [&str; 18] = [
    "analysis",
    "index",
    "chromatogram_id",
    "array_length",
    "polarity",
    "precursor_mz",
    "activation_ce",
    "product_mz",
    "signal_type",
    "chromatogram_type",
    "detector",
    "channel",
    "units",
    "wavelength_nm",
    "interval_ms",
    "start_time",
    "end_time",
    "intensity_multiplier",
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
fn agilent_project_outputs_are_complete_and_non_null() {
    let mass_hunter = std::env::var("STREAMFIND_AGILENT_MASS_HUNTER_FIXTURE");
    let chemstation = std::env::var("STREAMFIND_AGILENT_CHEMSTATION_FIXTURE");
    if mass_hunter.is_err() || chemstation.is_err() {
        return;
    }
    let sources = [
        ("masshunter", PathBuf::from(mass_hunter.unwrap())),
        ("chemstation", PathBuf::from(chemstation.unwrap())),
    ];
    let database =
        streamfind_rust_test_support::tmp_projects_dir().join("agilent-project-parity.duckdb");
    let _ = fs::remove_file(&database);
    let mut project = Project::create(ProjectOptions {
        database_path: database.clone(),
        project_id: "agilent-project-parity".into(),
        domain: "mass_spec".into(),
        create_if_missing: false,
        read_only: false,
    })
    .unwrap();
    let mut operations = OperationRegistry::default();
    streamfind_rust_mass_spec::register_operations(&mut operations).unwrap();
    let mut additions = Vec::new();
    for (name, path) in &sources {
        let reader = Reader::open(path).unwrap();
        assert!(!reader.spectra().is_empty());
        additions.push(json!({"path": path.to_string_lossy(), "replicate_name": name}));
    }
    let added = project
        .run_operation(
            "mass_spec.add_analyses",
            &json!({"analyses": additions}),
            &operations,
        )
        .unwrap();
    assert_eq!(added["row_count"], json!(2));
    assert_columns(
        &project
            .run_operation("mass_spec.get_spectra_headers", &json!({}), &operations)
            .unwrap(),
        &SPECTRA_COLUMNS,
    );
    assert_columns(
        &project
            .run_operation(
                "mass_spec.get_chromatograms_headers",
                &json!({}),
                &operations,
            )
            .unwrap(),
        &CHROM_COLUMNS,
    );
    for (name, path) in sources {
        let reader = Reader::open(&path).unwrap();
        let first = reader.spectrum_data(0).unwrap();
        let target = json!({"id": "first", "analyses": [path.file_stem().unwrap().to_string_lossy()], "levels": [first.level], "polarity": [0], "mz_min": first.mz[0] - 0.001, "mz_max": first.mz[0] + 0.001, "rt_min": first.retention_time - 0.001, "rt_max": first.retention_time + 0.001});
        for operation in [
            "mass_spec.get_raw_spectra",
            "mass_spec.get_raw_spectra_eic",
            "mass_spec.get_raw_spectra_ms1",
            "mass_spec.get_raw_spectra_ms2",
        ] {
            let mut parameters = json!({"targets": [target], "ppm": 20.0, "rt_tolerance": 60.0});
            if operation.ends_with("_ms1") || operation.ends_with("_ms2") {
                parameters["mz_clust"] = json!(0.003);
                parameters["presence"] = json!(0.0);
            }
            if operation.ends_with("_ms2") {
                parameters["isolation_window"] = json!(1.3);
            }
            let result = project
                .run_operation(operation, &parameters, &operations)
                .unwrap();
            assert_columns(&result, &RAW_COLUMNS);
        }
        assert!(!name.is_empty());
    }
    drop(project);
    let _ = fs::remove_file(database);
}
