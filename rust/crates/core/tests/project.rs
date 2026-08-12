use serde_json::json;
use std::fs;
use std::time::{SystemTime, UNIX_EPOCH};
use streamfind_rust_core::{
    api, ParameterType, Project, ProjectOptions, Table, TableColumn, TypeDescriptor,
};

fn temporary_database() -> std::path::PathBuf {
    let stamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    std::env::temp_dir().join(format!("streamfind-rust-{stamp}.duckdb"))
}

#[test]
fn project_round_trips_metadata_and_schema() {
    let path = temporary_database();
    let options = ProjectOptions {
        database_path: path.clone(),
        project_id: "rust-test".into(),
        domain: "mass_spec".into(),
        create_if_missing: false,
        read_only: false,
    };
    let mut project = Project::create(options.clone()).unwrap();
    project.set_metadata(json!({"owner": "rust-test"})).unwrap();
    assert_eq!(project.get_metadata()["owner"], "rust-test");
    project
        .set_cache("test", "test cache", "hash", &json!({"value": 42}))
        .unwrap();
    assert_eq!(project.get_cache().unwrap().len(), 1);
    assert!(!project.get_audit_trail().unwrap().is_empty());
    project.delete_cache().unwrap();
    assert!(project.get_cache().unwrap().is_empty());
    let copy_path = temporary_database();
    let copied = project
        .copy(ProjectOptions {
            database_path: copy_path.clone(),
            project_id: "rust-copy".into(),
            domain: String::new(),
            create_if_missing: false,
            read_only: false,
        })
        .unwrap();
    assert_eq!(copied.get_project_id(), "rust-copy");
    assert_eq!(copied.get_metadata()["owner"], "rust-test");
    copied.close();
    fs::remove_file(copy_path).unwrap();
    drop(project);

    let reopened = Project::open(ProjectOptions {
        read_only: true,
        ..options
    })
    .unwrap();
    assert_eq!(reopened.info().id, "rust-test");
    assert_eq!(reopened.info().domain, "mass_spec");
    assert_eq!(reopened.info().metadata["owner"], "rust-test");
    drop(reopened);
    assert_eq!(
        api::get_metadata(&json!({
            "database_path": path.to_string_lossy(),
            "project_id": "rust-test"
        }))
        .unwrap()["owner"],
        "rust-test"
    );
    assert!(api::validate(&json!({
        "database_path": path.to_string_lossy(),
        "project_id": "rust-test"
    }))
    .unwrap()["valid"]
        .as_bool()
        .unwrap());
    assert_eq!(
        api::get_cache_size(&json!({
            "database_path": path.to_string_lossy(),
            "project_id": "rust-test"
        }))
        .unwrap(),
        0
    );
    fs::remove_file(path).unwrap();
}

#[test]
fn table_rejects_unequal_columns() {
    let table = Table {
        columns: vec![
            TableColumn {
                name: "a".into(),
                kind: ParameterType::String,
                values: vec![json!("x")],
            },
            TableColumn {
                name: "b".into(),
                kind: ParameterType::Real,
                values: vec![json!(1.0), json!(2.0)],
            },
        ],
    };
    assert!(table.validate(None).is_err());
}

#[test]
fn array_type_round_trips() {
    let descriptor = TypeDescriptor::array(TypeDescriptor::scalar(ParameterType::Real));
    assert_eq!(
        TypeDescriptor::from_json(&descriptor.to_json())
            .unwrap()
            .to_json(),
        descriptor.to_json()
    );
}
