use serde_json::json;
use std::{fs, path::Path};
use streamfind_rust_core::{Project, ProjectOptions};
use streamfind_rust_mass_spec::{
    processing_methods_chromatograms::{load_chromatograms, LoadChromatogramsRequest},
    reader::Reader,
};

#[test]
fn persists_masshunter_dad_traces_through_public_reader() {
    let Ok(path) = std::env::var("STREAMFIND_AGILENT_WIDE_FIXTURE") else {
        return;
    };
    let path = Path::new(&path);
    let reader = Reader::open(path).expect("MassHunter reader");
    assert_eq!(reader.chromatograms().len(), 16);

    let name = "mass-spec-agilent-dad-persistence";
    let database = streamfind_rust_test_support::tmp_projects_dir().join(format!("{name}.duckdb"));
    let _ = fs::remove_file(&database);
    let mut project = Project::create(ProjectOptions {
        database_path: database,
        project_id: name.into(),
        domain: "mass_spec".into(),
        create_if_missing: false,
        read_only: false,
    })
    .unwrap();
    project
        .execute_sql("CREATE TABLE MASS_SPEC_ANALYSES (project_id VARCHAR, analysis VARCHAR, file_path VARCHAR, analysis_index INTEGER DEFAULT 0, replicate VARCHAR)")
        .unwrap();
    project
        .execute_sql(&format!(
            "INSERT INTO MASS_SPEC_ANALYSES (project_id, analysis, file_path, analysis_index, replicate) VALUES ({}, 'bvc', {}, 0, 'r1')",
            format!("'{}'", name),
            format!("'{}'", path.to_string_lossy().replace('\'', "''"))
        ))
        .unwrap();
    load_chromatograms(
        &mut project,
        &LoadChromatogramsRequest {
            analyses: vec!["bvc".into()],
            chromatogram_id_regex: vec!["^DAD1A$".into()],
            ignore_case: false,
            invert: false,
        },
    )
    .unwrap();
    let rows = project
        .query_json("SELECT COUNT(*) AS count FROM MASS_SPEC_CHROMATOGRAMS WHERE analysis = 'bvc' AND chromatogram_id = 'DAD1A'")
        .unwrap();
    assert_eq!(rows[0]["count"], json!(1501));
}
