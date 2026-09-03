use serde_json::json;
use std::fs;
use streamfind_rust_core::{Project, ProjectOptions};
use streamfind_rust_mass_spec::{
    processing_methods_chromatograms::{
        filter_chromatograms_retention_time, load_chromatograms,
        FilterChromatogramsRetentionTimeRequest, LoadChromatogramsRequest,
    },
    reader::Reader,
};

fn fixture() -> std::path::PathBuf {
    streamfind_rust_test_support::shimadzu_data_dir()
        .expect("Shimadzu fixtures unavailable; set STREAMFIND_SHIMADZU_DATA_ROOT")
        .join("karl.mzML")
}

fn project(name: &str) -> Project {
    let database =
        streamfind_rust_test_support::tmp_projects_dir().join(format!("streamfind-{name}.duckdb"));
    let _ = fs::remove_file(&database);
    Project::create(ProjectOptions {
        database_path: database,
        project_id: name.into(),
        domain: "mass_spec".into(),
        create_if_missing: false,
        read_only: false,
    })
    .unwrap()
}

fn analysed_project(name: &str, replicate: &str) -> Project {
    let project = project(name);
    project
        .execute_sql(
            "CREATE TABLE MASS_SPEC_ANALYSES (project_id VARCHAR, analysis VARCHAR, file_path VARCHAR, analysis_index INTEGER DEFAULT 0, replicate VARCHAR)",
        )
        .unwrap();
    project
        .execute_sql(&format!(
            "INSERT INTO MASS_SPEC_ANALYSES (project_id, analysis, file_path, replicate) VALUES ('{name}', 'karl', '{}', '{replicate}')",
            fixture().to_string_lossy().replace('\'', "''")
        ))
        .unwrap();
    project
}

/// The R interface's chromatogram result scheme (13 keys).
const R_SCHEME_KEYS: [&str; 13] = [
    "project_id",
    "analysis",
    "replicate",
    "index",
    "chromatogram_id",
    "polarity",
    "precursor_mz",
    "activation_ce",
    "product_mz",
    "rt",
    "raw_intensity",
    "baseline",
    "intensity",
];

#[test]
fn loads_karl_mzml_chromatograms() {
    let reader = Reader::open(fixture()).unwrap();
    assert_eq!(reader.summary().number_chromatograms, 40);
    assert_eq!(reader.chromatograms()[0].id, "TIC1");
    assert_eq!(reader.chromatograms()[0].time.len(), 695);
    assert_eq!(
        reader.chromatograms()[0].time.len(),
        reader.chromatograms()[0].intensity.len()
    );
}

#[test]
fn loads_and_filters_chromatograms_by_retention_time() {
    let mut project = analysed_project("mass-spec-chromatogram-processing", "");
    load_chromatograms(
        &mut project,
        &LoadChromatogramsRequest {
            analyses: vec!["karl".into()],
            chromatogram_id_regex: vec!["^TIC1$".into()],
            ignore_case: true,
            invert: false,
        },
    )
    .unwrap();
    let before = project
        .query_json("SELECT COUNT(*) AS count FROM MASS_SPEC_CHROMATOGRAMS")
        .unwrap();
    assert_eq!(before[0]["count"], json!(695));
    // Reader-derived columns are persisted on the point rows (not blanked).
    let persisted = project
        .query_json(
            "SELECT MIN(index) AS min_index, MAX(index) AS max_index, COUNT(polarity) AS polarity_count FROM MASS_SPEC_CHROMATOGRAMS",
        )
        .unwrap();
    assert_eq!(persisted[0]["min_index"], json!(0));
    assert_eq!(persisted[0]["max_index"], json!(0));
    assert_eq!(persisted[0]["polarity_count"], json!(695));
    let source_reader = Reader::open(fixture()).unwrap();
    let start = source_reader.chromatograms()[0].time[0] as f64;
    let end = source_reader.chromatograms()[0].time[2] as f64;
    filter_chromatograms_retention_time(
        &mut project,
        &FilterChromatogramsRetentionTimeRequest {
            analyses: vec!["karl".into()],
            rtmin: start,
            rtmax: end,
        },
    )
    .unwrap();
    let after = project
        .query_json(
            "SELECT MIN(rt) AS min_rt, MAX(rt) AS max_rt, COUNT(*) AS count, MIN(index) AS min_index, MAX(index) AS max_index, COUNT(polarity) AS polarity_count FROM MASS_SPEC_CHROMATOGRAMS",
        )
        .unwrap();
    assert!(after[0]["min_rt"].as_f64().unwrap() >= start);
    assert!(after[0]["max_rt"].as_f64().unwrap() <= end);
    assert!(after[0]["count"].as_i64().unwrap() > 0);
    let count = after[0]["count"].as_i64().unwrap();
    assert_eq!(after[0]["min_index"], json!(0));
    assert_eq!(after[0]["max_index"], json!(0));
    assert_eq!(after[0]["polarity_count"], json!(count));
}

#[test]
fn reads_raw_chromatograms_from_file() {
    let mut project = analysed_project("mass-spec-raw-chromatograms", "r1");
    let mut operations = streamfind_rust_core::OperationRegistry::default();
    streamfind_rust_mass_spec::register_operations(&mut operations).unwrap();
    let rows = project
        .run_operation(
            "mass_spec.get_raw_chromatograms",
            &json!({"analysis_names": ["karl"], "indices": [0]}),
            &operations,
        )
        .unwrap();
    assert_eq!(rows["row_count"], 695);
    let columns = rows["columns"].as_object().unwrap();
    for key in R_SCHEME_KEYS {
        assert!(columns.contains_key(key), "missing raw column {key}");
    }
    assert_eq!(columns["chromatogram_id"][0], "TIC1");
    assert_eq!(columns["index"][0], json!(0));
    assert_eq!(columns["replicate"][0], json!("r1"));
    assert_eq!(columns["baseline"][0], json!(0.0));
    assert_eq!(columns["raw_intensity"][0], columns["intensity"][0]);
    assert!(columns["polarity"][0].is_number());
}

#[test]
fn gets_persisted_chromatograms_with_r_scheme() {
    let mut project = analysed_project("mass-spec-persisted-chromatograms", "r1");
    load_chromatograms(
        &mut project,
        &LoadChromatogramsRequest {
            analyses: vec!["karl".into()],
            chromatogram_id_regex: vec!["^TIC1$".into()],
            ignore_case: true,
            invert: false,
        },
    )
    .unwrap();
    let mut operations = streamfind_rust_core::OperationRegistry::default();
    streamfind_rust_mass_spec::register_operations(&mut operations).unwrap();
    let rows = project
        .run_operation(
            "mass_spec.get_chromatograms",
            &json!({"analysis_names": ["karl"]}),
            &operations,
        )
        .unwrap();
    assert_eq!(rows["row_count"], 695);
    let columns = rows["columns"].as_object().unwrap();
    for key in R_SCHEME_KEYS {
        assert!(columns.contains_key(key), "missing persisted column {key}");
    }
    assert_eq!(columns["chromatogram_id"][0], "TIC1");
    assert_eq!(columns["index"][0], json!(0));
    assert_eq!(columns["replicate"][0], json!("r1"));
    assert_eq!(columns["analysis"][0], json!("karl"));
    assert!(columns["polarity"][0].is_number());
    assert!(columns["rt"][0].is_number());
    assert!(columns["intensity"][0].is_number());
    assert_eq!(columns["baseline"][0], json!(0.0));
}

#[test]
fn replicas_stay_out_of_the_chromatograms_table() {
    let mut project = analysed_project("mass-spec-no-replicate-column", "r1");
    load_chromatograms(
        &mut project,
        &LoadChromatogramsRequest {
            analyses: vec!["karl".into()],
            chromatogram_id_regex: vec!["^TIC1$".into()],
            ignore_case: true,
            invert: false,
        },
    )
    .unwrap();
    let columns = project
        .query_json(
            "SELECT column_name FROM information_schema.columns WHERE table_name = 'MASS_SPEC_CHROMATOGRAMS' ORDER BY column_name",
        )
        .unwrap();
    let names = columns
        .as_array()
        .unwrap()
        .iter()
        .filter_map(|row| row["column_name"].as_str())
        .collect::<Vec<_>>();
    assert!(
        !names.contains(&"replicate"),
        "replicate must not be a MASS_SPEC_CHROMATOGRAMS column: {names:?}"
    );
    for expected in [
        "index",
        "polarity",
        "precursor_mz",
        "activation_ce",
        "product_mz",
    ] {
        assert!(
            names.contains(&expected),
            "missing column {expected}: {names:?}"
        );
    }
}
