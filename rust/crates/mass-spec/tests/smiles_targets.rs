//! Chemical targets for raw-data operations: a target defined by SMILES/InChI
//! only must yield an EIC — the exact mass is derived with Open Babel and
//! converted to an m/z window with the polarity-aware adduct.
use serde_json::{json, Value};
use std::{fs, path::Path};
use streamfind_rust_core::{OperationRegistry, Project, ProjectOptions};

fn fixtures() -> [std::path::PathBuf; 2] {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("../../..");
    [
        root.join("tests/data/mass_spec/basic_tof/00_tof_s_is_pos_cent-r002.mzML"),
        root.join("tests/data/mass_spec/basic_tof/00_tof_s_is_pos_cent-r003.mzML"),
    ]
}

fn setup(tag: &str) -> (Project, OperationRegistry) {
    let database = std::env::temp_dir().join(format!("streamfind-rust-smiles-{tag}.duckdb"));
    let _ = fs::remove_file(&database);
    let mut project = Project::create(ProjectOptions {
        database_path: database.clone(),
        project_id: "rust-smiles".into(),
        domain: "mass_spec".into(),
        create_if_missing: false,
        read_only: false,
    })
    .unwrap();
    project
        .execute_sql(
            "CREATE TABLE MASS_SPEC_ANALYSES (project_id VARCHAR, analysis VARCHAR, file_path VARCHAR, analysis_index INTEGER DEFAULT 0)",
        )
        .unwrap();
    for (analysis, fixture) in ["r002", "r003"].into_iter().zip(fixtures()) {
        project
            .execute_sql(&format!(
                "INSERT INTO MASS_SPEC_ANALYSES (project_id, analysis, file_path) VALUES ('rust-smiles', '{}', '{}')",
                analysis,
                fixture.to_string_lossy().replace('\'', "''")
            ))
            .unwrap();
    }
    let mut operations = OperationRegistry::default();
    streamfind_rust_mass_spec::register_operations(&mut operations).unwrap();
    (project, operations)
}

const METOPROLOL_SMILES: &str = "COCCc1ccc(cc1)OCC(CNC(C)C)O";
// Metoprolol neutral mass 267.1834; [M+H]+ = 268.1907 (the fixture's known peak).
const METOPROLOL_MH: f64 = 268.19;

fn mean_mz(rows: &Value) -> f64 {
    // Operation results are columnar: {"row_count": N, "columns": {"mz": [...]}}.
    let mzs: Vec<f64> = rows
        .get("columns")
        .and_then(|columns| columns.get("mz"))
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
        .filter_map(Value::as_f64)
        .collect();
    assert!(!mzs.is_empty(), "no m/z rows returned");
    mzs.iter().sum::<f64>() / mzs.len() as f64
}

#[test]
fn smiles_target_yields_raw_spectra_eic() {
    let (mut project, operations) = setup("eic");
    // Control: numeric m/z target must yield rows (validates harness + fixture).
    let control = project
        .run_operation(
            "mass_spec.get_raw_spectra_eic",
            &json!({
                "analysis_names": ["r002"],
                "targets": [{"id": "control", "mz": 268.19}],
                "ppm": 20.0
            }),
            &operations,
        )
        .unwrap();
    eprintln!("CONTROL rows: {}", control.as_array().map(|v| v.len()).unwrap_or(0));
    let all = project
        .run_operation(
            "mass_spec.get_raw_spectra",
            &json!({"analysis_names": ["r002"], "levels": [1]}),
            &operations,
        )
        .unwrap();
    eprintln!("ALL-rows: {}", all.as_array().map(|v| v.len()).unwrap_or(0));
    let result = project
        .run_operation(
            "mass_spec.get_raw_spectra_eic",
            &json!({
                "analysis_names": ["r002"],
                "targets": [{"id": "metoprolol", "SMILES": METOPROLOL_SMILES}],
                "ppm": 20.0
            }),
            &operations,
        )
        .unwrap();
    let mean = mean_mz(&result);
    eprintln!("SMILES EIC mean m/z: {mean:.4}");
    assert!(
        (mean - METOPROLOL_MH).abs() < 0.01,
        "EIC m/z mean {mean} not near metoprolol [M+H]+ (268.19)"
    );
}

#[test]
fn smiles_target_yields_raw_spectra_ms1() {
    let (mut project, operations) = setup("ms1");
    let result = project
        .run_operation(
            "mass_spec.get_raw_spectra_ms1",
            &json!({
                "analysis_names": ["r002", "r003"],
                "targets": [{"id": "metoprolol", "SMILES": METOPROLOL_SMILES}],
                "ppm": 20.0
            }),
            &operations,
        )
        .unwrap();
    let mean = mean_mz(&result);
    eprintln!("SMILES MS1 mean m/z: {mean:.4}");
    assert!(
        (mean - METOPROLOL_MH).abs() < 0.01,
        "MS1 m/z mean {mean} not near metoprolol [M+H]+ (268.19)"
    );
}