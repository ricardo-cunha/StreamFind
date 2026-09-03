use serde_json::json;
use std::fs;
use std::sync::{
    atomic::{AtomicUsize, Ordering},
    Arc,
};
use std::time::{SystemTime, UNIX_EPOCH};
use streamfind_rust_core::{
    api, Method, MethodRegistry, ParameterSchema, ParameterType, Project, ProjectOptions, Table,
    TableColumn, TypeDescriptor, Workflow, WorkflowStep,
};

fn temporary_database() -> std::path::PathBuf {
    let stamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    streamfind_rust_test_support::tmp_projects_dir().join(format!("streamfind-rust-{stamp}.duckdb"))
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
        serde_json::from_str::<serde_json::Value>(
            api::get_metadata(&json!({
                "database_path": path.to_string_lossy(),
                "project_id": "rust-test"
            }))
            .unwrap()["columns"]["metadata"][0]
                .as_str()
                .unwrap(),
        )
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

#[test]
fn workflow_cache_restores_written_tables() {
    let path = temporary_database();
    let mut project = Project::create(ProjectOptions {
        database_path: path.clone(),
        project_id: "cache-test".into(),
        domain: "test".into(),
        create_if_missing: false,
        read_only: false,
    })
    .unwrap();
    let runs = Arc::new(AtomicUsize::new(0));
    let runs_for_method = Arc::clone(&runs);
    let mut method = Method::new(
        "test.write_table",
        "test.write_table",
        "Write a test table",
        "test",
        ParameterSchema::default(),
        Box::new(move |project, _| {
            runs_for_method.fetch_add(1, Ordering::SeqCst);
            project.execute_sql(
                "CREATE TABLE IF NOT EXISTS TEST_OUTPUT (project_id VARCHAR, value VARCHAR)",
            )?;
            project.execute_sql("DELETE FROM TEST_OUTPUT WHERE project_id = 'cache-test'")?;
            project.execute_sql("INSERT INTO TEST_OUTPUT VALUES ('cache-test', 'materialized')")?;
            Ok(json!({"status": "finished"}))
        }),
    );
    method.cacheable = true;
    method.writes = vec!["TEST_OUTPUT".into()];
    let mut registry = MethodRegistry::default();
    registry.register(method).unwrap();
    project
        .set_workflow(
            Workflow {
                domain: "test".into(),
                steps: vec![WorkflowStep {
                    method: "test.write_table".into(),
                    parameters: json!({}),
                    metadata: None,
                }],
                ..Workflow::default()
            },
            &registry,
        )
        .unwrap();
    let workflow = project.get_workflow().unwrap();
    project
        .run_workflow(&workflow, &registry, None, None)
        .unwrap();
    project
        .execute_sql("DELETE FROM TEST_OUTPUT WHERE project_id = 'cache-test'")
        .unwrap();
    let workflow = project.get_workflow().unwrap();
    project
        .run_workflow(&workflow, &registry, None, None)
        .unwrap();
    assert_eq!(runs.load(Ordering::SeqCst), 1);
    assert_eq!(
        project
            .query_json("SELECT value FROM TEST_OUTPUT WHERE project_id = 'cache-test'")
            .unwrap(),
        json!([{"value": "materialized"}])
    );
    assert_eq!(
        project.get_workflow_execution().unwrap()[0]["status"],
        "succeeded"
    );
    let execution_table = api::get_workflow_execution(&json!({
        "database_path": path.to_string_lossy(),
        "project_id": "cache-test"
    }))
    .unwrap();
    assert_eq!(execution_table["row_count"], 1);
    assert!(execution_table["columns"]["step_index"].is_array());
    fs::remove_file(path).unwrap();
}
