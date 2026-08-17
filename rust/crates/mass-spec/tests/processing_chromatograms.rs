use serde_json::json;
use std::{fs, path::Path};
use streamfind_rust_core::{Project, ProjectOptions};
use streamfind_rust_mass_spec::{
    processing_chromatograms::{
        filter_chromatograms_retention_time, get_raw_chromatograms, load_chromatograms,
        FilterChromatogramsRetentionTimeRequest, LoadChromatogramsRequest,
    },
    reader::Reader,
};

fn fixture() -> std::path::PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("../../..")
        .join("tests/data/mass_spec/shimadzu/karl.mzML")
}

fn project(name: &str) -> Project {
    let database = std::env::temp_dir().join(format!("streamfind-{name}.duckdb"));
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
    let mut project = project("mass-spec-chromatogram-processing");
    let source_reader = Reader::open(fixture()).unwrap();
    let start = source_reader.chromatograms()[0].time[0] as f64;
    let end = source_reader.chromatograms()[0].time[2] as f64;
    project
        .execute_sql(&format!(
            "CREATE TABLE MASS_SPEC_ANALYSES (project_id VARCHAR, analysis VARCHAR, file_path VARCHAR)"
        ))
        .unwrap();
    project
        .execute_sql(&format!(
            "INSERT INTO MASS_SPEC_ANALYSES VALUES ('mass-spec-chromatogram-processing', 'karl', '{}')",
            fixture().to_string_lossy().replace('\'', "''")
        ))
        .unwrap();
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
            "SELECT MIN(rt) AS min_rt, MAX(rt) AS max_rt, COUNT(*) AS count FROM MASS_SPEC_CHROMATOGRAMS",
        )
        .unwrap();
    assert!(after[0]["min_rt"].as_f64().unwrap() >= start);
    assert!(after[0]["max_rt"].as_f64().unwrap() <= end);
    assert!(after[0]["count"].as_i64().unwrap() > 0);
}

#[test]
fn reads_raw_chromatograms_from_file() {
    let mut project = project("mass-spec-raw-chromatograms");
    project
        .execute_sql("CREATE TABLE MASS_SPEC_ANALYSES (project_id VARCHAR, analysis VARCHAR, file_path VARCHAR)")
        .unwrap();
    project
        .execute_sql(&format!(
            "INSERT INTO MASS_SPEC_ANALYSES VALUES ('mass-spec-raw-chromatograms', 'karl', '{}')",
            fixture().to_string_lossy().replace('\'', "''")
        ))
        .unwrap();
    let rows = get_raw_chromatograms(
        &mut project,
        &json!({"analysis_names": ["karl"], "indices": [0]}),
    )
    .unwrap();
    assert_eq!(rows.as_array().unwrap().len(), 695);
    assert_eq!(rows[0]["chromatogram_id"], "TIC1");
}
