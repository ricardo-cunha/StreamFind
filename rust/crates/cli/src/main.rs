//! Minimal command-line interface for the Rust project backend.
//!
//! Supported commands are `create` and `describe`. Both require
//! `--database-path` and `--project-id`.

use std::env;
use std::path::PathBuf;
use streamfind_rust_core::{Project, ProjectOptions, Result};

fn option(args: &[String], name: &str) -> Result<String> {
    args.windows(2)
        .find(|pair| pair[0] == name)
        .map(|pair| pair[1].clone())
        .ok_or_else(|| streamfind_rust_core::Error {
            code: streamfind_rust_core::ErrorCode::InvalidArgument,
            message: format!("missing {name}"),
        })
}

fn main() {
    if let Err(error) = run() {
        eprintln!("{error}");
        std::process::exit(1);
    }
}

fn run() -> Result<()> {
    let args: Vec<String> = env::args().collect();
    let command = args.get(1).map(String::as_str).unwrap_or("describe");
    let options = ProjectOptions {
        database_path: PathBuf::from(option(&args, "--database-path")?),
        project_id: option(&args, "--project-id")?,
        domain: args
            .windows(2)
            .find(|pair| pair[0] == "--domain")
            .map(|pair| pair[1].clone())
            .unwrap_or_default(),
        create_if_missing: false,
        read_only: command == "describe",
    };
    let project = if command == "create" {
        Project::create(options)?
    } else {
        Project::open(options)?
    };
    println!(
        "{}",
        serde_json::json!({"id": project.info().id, "domain": project.info().domain, "metadata": project.info().metadata})
    );
    Ok(())
}
