use serde_json::json;
use std::fs;
use streamfind_rust_core::{OperationRegistry, Project, ProjectOptions};

#[test]
fn mass_spec_operations_persist_lcd_summary_and_ontology_tables() {
    let database = std::env::temp_dir().join("streamfind-rust-mass-spec-project.duckdb");
    let _ = fs::remove_file(&database);
    let mut project = Project::create(ProjectOptions {
        database_path: database.clone(),
        project_id: "mass-spec-test".into(),
        domain: "mass_spec".into(),
        create_if_missing: false,
        read_only: false,
    })
    .unwrap();
    let mut operations = OperationRegistry::default();
    streamfind_rust_mass_spec::register_operations(&mut operations).unwrap();
    let source = std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("../../..")
        .join("tests/data/mass_spec/shimadzu/adc.lcd");

    let added = project
        .run_operation(
            "mass_spec.add_analyses",
            &json!({"analyses": [{"path": source.to_string_lossy(), "replicate_name": "r1"}]}),
            &operations,
        )
        .unwrap();
    assert_eq!(added[0]["analysis"], "adc");
    let info = project
        .run_operation("mass_spec.get_analyses_info", &json!({}), &operations)
        .unwrap();
    assert_eq!(info[0]["format"], "ShimadzuLCD");
    assert!(project
        .list_tables()
        .unwrap()
        .iter()
        .any(|name| name == "MASS_SPEC_ANALYSES"));
    assert!(project
        .list_tables()
        .unwrap()
        .iter()
        .any(|name| name == "MASS_SPEC_SPECTRA_HEADERS"));
    assert!(project
        .list_tables()
        .unwrap()
        .iter()
        .any(|name| name == "MASS_SPEC_CHROMATOGRAMS_HEADERS"));
    drop(project);
    fs::remove_file(database).unwrap();
}

#[test]
fn domain_smoke_matches_cpp_mass_spec_operations() {
    let database = std::env::temp_dir().join("streamfind-rust-mass-spec-domain-smoke.duckdb");
    let _ = fs::remove_file(&database);
    let mut project = Project::create(ProjectOptions {
        database_path: database.clone(),
        project_id: "mass-spec-smoke".into(),
        domain: "mass_spec".into(),
        create_if_missing: false,
        read_only: false,
    })
    .unwrap();
    let mut operations = OperationRegistry::default();
    streamfind_rust_mass_spec::register_operations(&mut operations).unwrap();
    assert_eq!(operations.list("mass_spec").len(), 3);
    assert!(operations
        .list("mass_spec")
        .iter()
        .any(|operation| operation["id"] == "mass_spec.add_analyses"));

    let data = std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("../../..")
        .join("tests/data/mass_spec/wastewater");
    let paths = [
        data.join("03_tof_ww_is_pos_o3sw_effluent-r001.mzML"),
        data.join("03_tof_ww_is_pos_o3sw_effluent-r002.mzML"),
        data.join("03_tof_ww_is_pos_o3sw_effluent-r003.mzML"),
    ];
    let analyses = json!({
        "analyses": paths.iter().map(|path| json!({"path": path})).collect::<Vec<_>>()
    });
    let added = project
        .run_operation("mass_spec.add_analyses", &analyses, &operations)
        .unwrap();
    assert_eq!(added.as_array().unwrap().len(), 3);
    assert_eq!(
        project
            .run_operation("mass_spec.get_analyses_info", &json!({}), &operations)
            .unwrap()
            .as_array()
            .unwrap()
            .len(),
        3
    );

    project
        .run_operation(
            "mass_spec.remove_analyses",
            &json!({"analysis_names": ["03_tof_ww_is_pos_o3sw_effluent-r003"]}),
            &operations,
        )
        .unwrap();
    assert_eq!(
        project
            .run_operation("mass_spec.get_analyses_info", &json!({}), &operations)
            .unwrap()
            .as_array()
            .unwrap()
            .len(),
        2
    );
    drop(project);
    fs::remove_file(database).unwrap();
}
