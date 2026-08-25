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
    assert_eq!(added["columns"]["analysis"][0], "adc");
    let info = project
        .run_operation("mass_spec.get_analyses_info", &json!({}), &operations)
        .unwrap();
    assert_eq!(info["columns"]["format"][0], "ShimadzuLCD");
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
    // 20 pre-existing operations + the three NTA table query operations
    // (get_suspects, get_internal_standards, get_transformation_products).
    assert_eq!(operations.list("mass_spec").len(), 23);
    let parameter_count = |id: &str| {
        operations
            .list("mass_spec")
            .into_iter()
            .find(|operation| operation["id"] == id)
            .unwrap()["parameters"]
            .as_array()
            .unwrap()
            .len()
    };
    assert_eq!(parameter_count("mass_spec.get_spectra_headers"), 3);
    assert_eq!(parameter_count("mass_spec.get_chromatograms_headers"), 3);
    assert_eq!(parameter_count("mass_spec.get_spectra_tic"), 6);
    assert_eq!(parameter_count("mass_spec.get_chromatograms"), 4);
    assert_eq!(parameter_count("mass_spec.get_raw_chromatograms"), 4);
    assert_eq!(parameter_count("mass_spec.get_raw_spectra"), 9);
    assert_eq!(parameter_count("mass_spec.get_raw_spectra_eic"), 8);
    assert_eq!(parameter_count("mass_spec.get_raw_spectra_ms1"), 11);
    assert_eq!(parameter_count("mass_spec.get_raw_spectra_ms2"), 12);
    assert!(operations
        .list("mass_spec")
        .iter()
        .any(|operation| operation["id"] == "mass_spec.add_analyses"));

    let data = std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("../../..")
        .join("tests/data/mass_spec/wastewater");
    let paths = [
        data.join("01_tof_ww_is_pos_blank-r001.mzML"),
        data.join("01_tof_ww_is_pos_blank-r002.mzML"),
        data.join("01_tof_ww_is_pos_blank-r003.mzML"),
    ];
    let analyses = json!({
        "analyses": paths.iter().map(|path| json!({"path": path})).collect::<Vec<_>>()
    });
    let added = project
        .run_operation("mass_spec.add_analyses", &analyses, &operations)
        .unwrap();
    assert_eq!(added["row_count"], 3);
    assert_eq!(
        project
            .run_operation("mass_spec.get_analyses_info", &json!({}), &operations)
            .unwrap()["row_count"],
        3
    );
    assert_eq!(
        project
            .run_operation("mass_spec.get_analysis_names", &json!({}), &operations)
            .unwrap()
            .as_array()
            .unwrap()
            .len(),
        3
    );
    project
        .run_operation(
            "mass_spec.set_replicate_names",
            &json!({"replicate_names": ["r1", "r2", "r3"]}),
            &operations,
        )
        .unwrap();
    project
        .run_operation(
            "mass_spec.set_blank_names",
            &json!({"blank_names": ["b1", "b2", "b3"]}),
            &operations,
        )
        .unwrap();
    project
        .run_operation(
            "mass_spec.set_concentrations",
            &json!({"concentrations": [1.0, 2.0, 3.0]}),
            &operations,
        )
        .unwrap();
    assert_eq!(
        project
            .run_operation("mass_spec.get_concentrations", &json!({}), &operations)
            .unwrap()
            .as_array()
            .unwrap()
            .len(),
        3
    );
    assert!(
        project
            .run_operation("mass_spec.get_spectra_headers", &json!({}), &operations)
            .unwrap()["row_count"]
            .as_u64()
            .unwrap()
            > 0
    );
    assert!(
        project
            .run_operation(
                "mass_spec.get_spectra_tic",
                &json!({"levels": [1]}),
                &operations
            )
            .unwrap()["row_count"]
            .as_u64()
            .unwrap()
            > 0
    );
    assert!(
        project
            .run_operation(
                "mass_spec.get_raw_spectra",
                &json!({"targets": [{"mz_min": 100.0, "mz_max": 200.0, "polarity": 0}]}),
                &operations
            )
            .unwrap()["row_count"]
            .as_u64()
            .unwrap()
            > 0
    );
    let targets =
        include_str!("../../../../tests/data/mass_spec/wastewater/internal_standards.csv")
            .lines()
            .skip(1)
            .filter_map(|line| {
                let fields = line.splitn(5, ',').collect::<Vec<_>>();
                let mass = fields.get(2)?.parse::<f64>().ok()?;
                let rt = fields.get(3)?.parse::<f64>().ok()?;
                Some(json!({"id": fields[0], "analyses": ["01_tof_ww_is_pos_blank-r001"], "mass": mass, "rt": rt, "polarity": 1}))
            })
            .collect::<Vec<_>>();
    let eic = project
        .run_operation(
            "mass_spec.get_raw_spectra_eic",
            &json!({"targets": targets.clone(), "ppm": 20.0, "rt_tolerance": 60.0}),
            &operations,
        )
        .unwrap();
    assert!(eic["row_count"].as_u64().unwrap() > 0);
    let target_ids = eic["columns"]["target_id"]
        .as_array()
        .unwrap()
        .iter()
        .filter_map(serde_json::Value::as_str)
        .collect::<std::collections::BTreeSet<_>>();
    assert!(target_ids.len() > 1);
    assert_eq!(target_ids.len(), 8);
    assert_eq!(eic["columns"]["target_id"][0], "Carbamazepine-D10");
    assert_eq!(eic["columns"]["id"][0], "01_tof_ww_is_pos_blank-r001:1006");
    assert_eq!(eic["columns"]["replicate"][0], "r1");
    assert_eq!(eic["columns"]["mz"][0], json!(247.16661071777344));
    let ms1 = project
        .run_operation(
            "mass_spec.get_raw_spectra_ms1",
            &json!({"targets": targets.clone(), "ppm": 20.0, "rt_tolerance": 60.0, "mz_clust": 0.003, "presence": 0.8, "min_intensity_ms1": 1000.0}),
            &operations,
        )
        .unwrap();
    assert!(ms1["row_count"].as_u64().unwrap() > 0);
    assert!(ms1["columns"]["level"]
        .as_array()
        .unwrap()
        .iter()
        .all(|value| value == 1));
    assert!(ms1["columns"]["intensity"]
        .as_array()
        .unwrap()
        .iter()
        .all(|value| value.as_f64().unwrap() >= 1000.0));
    let ms2 = project
        .run_operation(
            "mass_spec.get_raw_spectra_ms2",
            &json!({"targets": targets, "ppm": 20.0, "rt_tolerance": 60.0, "isolation_window": 1.3, "mz_clust": 0.005, "presence": 0.0}),
            &operations,
        )
        .unwrap();
    assert!(ms2["row_count"].as_u64().unwrap() > 0);
    assert!(ms2["columns"]["level"]
        .as_array()
        .unwrap()
        .iter()
        .all(|value| value == 2));
    let preview = eic["columns"]["target_id"]
        .as_array()
        .unwrap()
        .iter()
        .take(5)
        .cloned()
        .collect::<Vec<_>>();
    println!(
        "multi-target EIC target IDs: {:?}\nfirst rows:\n{}",
        target_ids,
        serde_json::to_string_pretty(&preview).unwrap()
    );

    project
        .run_operation(
            "mass_spec.remove_analyses",
            &json!({"analysis_names": ["01_tof_ww_is_pos_blank-r003"]}),
            &operations,
        )
        .unwrap();
    assert_eq!(
        project
            .run_operation("mass_spec.get_analyses_info", &json!({}), &operations)
            .unwrap()["row_count"],
        2
    );
    drop(project);
    fs::remove_file(database).unwrap();
}
