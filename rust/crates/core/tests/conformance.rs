use serde_json::Value;
use std::fs;
use std::path::PathBuf;
use streamfind_rust_core::{Project, ProjectOptions};

fn fixture() -> Value {
    serde_json::from_str(include_str!(
        "../../../../tests/data/project/project_conformance.json"
    ))
    .unwrap()
}

fn database(name: &str) -> PathBuf {
    let path = std::env::temp_dir().join(name);
    let _ = fs::remove_file(&path);
    path
}

fn options(path: PathBuf, fixture: &Value, read_only: bool) -> ProjectOptions {
    ProjectOptions {
        database_path: path,
        project_id: fixture["project_id"].as_str().unwrap().into(),
        domain: fixture["domain"].as_str().unwrap().into(),
        create_if_missing: false,
        read_only,
    }
}

#[test]
fn shared_fixture_round_trips_project_contract() {
    let fixture = fixture();
    let path = database("streamfind-rust-conformance.duckdb");
    let mut project = Project::create(options(path.clone(), &fixture, false)).unwrap();
    project.set_metadata(fixture["metadata"].clone()).unwrap();
    project
        .set_workflow(
            streamfind_rust_core::Workflow::from_json(&fixture["workflow"]).unwrap(),
            &streamfind_rust_core::MethodRegistry::default(),
        )
        .unwrap();
    project
        .set_cache(
            fixture["cache"]["name"].as_str().unwrap(),
            fixture["cache"]["description"].as_str().unwrap(),
            fixture["cache"]["hash"].as_str().unwrap(),
            &fixture["cache"]["value"],
        )
        .unwrap();
    assert_eq!(project.get_project_id(), fixture["project_id"]);
    assert_eq!(project.get_domain(), fixture["domain"]);
    assert_eq!(project.get_metadata(), fixture["metadata"]);
    assert_eq!(
        project.get_workflow().unwrap().to_json(),
        fixture["workflow"]
    );
    assert_eq!(project.get_cache_size().unwrap(), 1);
    project.validate().unwrap();
    drop(project);

    let reopened = Project::open(options(path.clone(), &fixture, true)).unwrap();
    assert_eq!(
        reopened.get_cache().unwrap()[0].hash,
        fixture["cache"]["hash"]
    );
    reopened.validate().unwrap();
    drop(reopened);
    fs::remove_file(path).unwrap();
}

#[test]
fn rust_schema_matches_shared_duckdb_contract() {
    let fixture = fixture();
    let path = database("streamfind-rust-schema-conformance.duckdb");
    let extension_directory = path
        .parent()
        .unwrap()
        .join(".streamfind-duckdb-extensions")
        .join(path.file_name().unwrap());
    fs::create_dir_all(&extension_directory).unwrap();
    let config = duckdb::Config::default()
        .with(
            "extension_directory",
            extension_directory.to_string_lossy().as_ref(),
        )
        .unwrap();
    let connection = duckdb::Connection::open_with_flags(&path, config).unwrap();
    connection
        .execute_batch("CREATE TABLE PROJECT (project_id VARCHAR PRIMARY KEY, domain VARCHAR, metadata JSON, workflow JSON, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, schema_version INTEGER NOT NULL DEFAULT 1, framework_version VARCHAR NOT NULL DEFAULT '0.1.0'); CREATE TABLE CACHE (project_id VARCHAR, name VARCHAR, description VARCHAR, hash VARCHAR, data BLOB, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY(project_id, hash)); CREATE TABLE AUDIT_TRAIL (project_id VARCHAR, operation_type VARCHAR, object_type VARCHAR, operation_details JSON, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);")
        .unwrap();
    connection
        .execute(
            "INSERT INTO PROJECT (project_id, domain, metadata, workflow) VALUES (?1, ?2, ?3, ?4)",
            duckdb::params![
                fixture["project_id"].as_str().unwrap(),
                fixture["domain"].as_str().unwrap(),
                fixture["metadata"].to_string(),
                fixture["workflow"].to_string()
            ],
        )
        .unwrap();
    drop(connection);
    let project = Project::open(options(path.clone(), &fixture, true)).unwrap();
    assert_eq!(project.get_metadata(), fixture["metadata"]);
    assert_eq!(
        project.get_workflow().unwrap().to_json(),
        fixture["workflow"]
    );
    drop(project);
    fs::remove_file(path).unwrap();
}
