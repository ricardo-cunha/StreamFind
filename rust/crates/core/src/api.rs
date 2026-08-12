//! JSON-friendly command facade for the Rust Project backend.

use crate::{Error, ErrorCode, Json, Project, ProjectOptions, Result};
use std::path::PathBuf;

fn options(request: &Json, read_only: bool) -> Result<ProjectOptions> {
    Ok(ProjectOptions {
        database_path: PathBuf::from(
            request
                .get("database_path")
                .and_then(Json::as_str)
                .ok_or_else(|| Error::new(ErrorCode::InvalidArgument, "missing database_path"))?,
        ),
        project_id: request
            .get("project_id")
            .and_then(Json::as_str)
            .ok_or_else(|| Error::new(ErrorCode::InvalidArgument, "missing project_id"))?
            .into(),
        domain: request
            .get("domain")
            .and_then(Json::as_str)
            .unwrap_or_default()
            .into(),
        create_if_missing: false,
        read_only,
    })
}

pub fn describe(request: &Json) -> Result<Json> {
    let project = Project::open(options(request, true)?)?;
    Ok(json!({
        "id": project.info().id,
        "domain": project.info().domain,
        "metadata": project.info().metadata,
        "schema_version": project.info().schema_version,
        "framework_version": project.info().framework_version,
        "created_at": project.info().created_at
    }))
}

pub fn create(request: &Json) -> Result<Json> {
    let mut project = Project::create(options(request, false)?)?;
    if let Some(metadata) = request.get("metadata") {
        project.set_metadata(metadata.clone())?;
    }
    Ok(
        json!({"id": project.info().id, "domain": project.info().domain, "metadata": project.info().metadata}),
    )
}

pub fn get_metadata(request: &Json) -> Result<Json> {
    Ok(Project::open(options(request, true)?)?.get_metadata())
}

pub fn validate(request: &Json) -> Result<Json> {
    Project::open(options(request, true)?)?.validate()?;
    Ok(json!({"valid": true}))
}

pub fn get_domain(request: &Json) -> Result<Json> {
    Ok(json!(Project::open(options(request, true)?)?.get_domain()))
}

pub fn get_workflow(request: &Json) -> Result<Json> {
    Ok(Project::open(options(request, true)?)?
        .get_workflow()?
        .to_json())
}

pub fn validate_workflow(request: &Json, registry: &crate::MethodRegistry) -> Result<Json> {
    let workflow = crate::Workflow::from_json(
        request
            .get("workflow")
            .ok_or_else(|| Error::new(ErrorCode::InvalidArgument, "missing workflow"))?,
    )?;
    workflow.validate(registry)?;
    Ok(json!({"valid": true, "workflow": workflow.to_json()}))
}

pub fn set_workflow(request: &Json, registry: &crate::MethodRegistry) -> Result<Json> {
    let workflow = crate::Workflow::from_json(
        request
            .get("workflow")
            .ok_or_else(|| Error::new(ErrorCode::InvalidArgument, "missing workflow"))?,
    )?;
    let mut project = Project::open(options(request, false)?)?;
    project.set_workflow(workflow, registry)?;
    Ok(project.get_workflow()?.to_json())
}

pub fn run_workflow(request: &Json, registry: &crate::MethodRegistry) -> Result<Json> {
    let workflow = match request.get("workflow") {
        Some(value) => crate::Workflow::from_json(value)?,
        None => Project::open(options(request, true)?)?.get_workflow()?,
    };
    let mut project = Project::open(options(request, false)?)?;
    Ok(project
        .run_workflow(&workflow, registry, None, None)?
        .to_json())
}

pub fn get_available_methods(request: &Json, registry: &crate::MethodRegistry) -> Result<Json> {
    let domain = request
        .get("domain")
        .and_then(Json::as_str)
        .ok_or_else(|| Error::new(ErrorCode::InvalidArgument, "missing domain"))?;
    Ok(json!(registry.list(domain)))
}

pub fn run_method(request: &Json, registry: &crate::MethodRegistry) -> Result<Json> {
    let method = request
        .get("method")
        .and_then(Json::as_str)
        .ok_or_else(|| Error::new(ErrorCode::InvalidArgument, "missing method"))?;
    let mut project = Project::open(options(request, false)?)?;
    let parameters = request
        .get("parameters")
        .cloned()
        .unwrap_or_else(|| json!({}));
    project.run_method(method, &parameters, registry)
}

pub fn copy(request: &Json) -> Result<Json> {
    let source = Project::open(options(request, true)?)?;
    let destination_path = request
        .get("destination_database_path")
        .and_then(Json::as_str)
        .ok_or_else(|| {
            Error::new(
                ErrorCode::InvalidArgument,
                "missing destination_database_path",
            )
        })?;
    let destination_id = request
        .get("destination_project_id")
        .and_then(Json::as_str)
        .ok_or_else(|| Error::new(ErrorCode::InvalidArgument, "missing destination_project_id"))?;
    let destination = source.copy(ProjectOptions {
        database_path: PathBuf::from(destination_path),
        project_id: destination_id.into(),
        domain: String::new(),
        create_if_missing: false,
        read_only: false,
    })?;
    let destination_path = destination
        .get_database_path()
        .to_string_lossy()
        .into_owned();
    let destination_id = destination.get_project_id().to_owned();
    drop(destination);
    describe(&json!({
        "database_path": destination_path,
        "project_id": destination_id
    }))
}

pub fn get_cache_size(request: &Json) -> Result<Json> {
    Ok(json!(
        Project::open(options(request, true)?)?.get_cache_size()?
    ))
}

pub fn close(request: &Json) -> Result<Json> {
    Project::open(options(request, true)?)?.close();
    Ok(json!({"closed": true}))
}

pub fn set_metadata(request: &Json) -> Result<Json> {
    let metadata = request
        .get("metadata")
        .cloned()
        .ok_or_else(|| Error::new(ErrorCode::InvalidArgument, "missing metadata"))?;
    let mut project = Project::open(options(request, false)?)?;
    project.set_metadata(metadata)?;
    Ok(project.get_metadata())
}

pub fn get_cache(request: &Json) -> Result<Json> {
    Ok(json!(Project::open(options(request, true)?)?.get_cache()?))
}

pub fn delete_cache(request: &Json) -> Result<Json> {
    let mut project = Project::open(options(request, false)?)?;
    project.delete_cache()?;
    Ok(json!({"deleted": true}))
}

pub fn get_audit_trail(request: &Json) -> Result<Json> {
    Ok(json!(
        Project::open(options(request, true)?)?.get_audit_trail()?
    ))
}

use serde_json::json;
