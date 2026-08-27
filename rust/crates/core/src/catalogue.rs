//! Read-only access to the semantic catalogue knowledge base
//! (`semantic/generated/catalogue.duckdb`).
//!
//! The catalogue is the runtime replacement for the former embedded
//! `generated_metadata.rs` literals. Every method/operation document is one
//! row of `catalogue_entries`; this module opens the database read-only and
//! serves the MCP tool list and the registration views.
//!
//! Search chain:
//! 1. `STREAMFIND_CATALOGUE` environment variable (explicit override)
//! 2. `catalogue.duckdb` next to the executable
//! 3. the repository source-tree layout (`semantic/generated`) — dev/test
//!    fallback anchored at the core crate manifest dir

use duckdb::{AccessMode, Config, Connection};
use serde_json::{json, Value};
use std::path::PathBuf;
use std::sync::OnceLock;

const CATALOGUE_SQL: &str = "SELECT canonical_id, kind, domain, label, definition, executable, \
     exposed, mcp_name, CAST(input_schema AS VARCHAR), CAST(parameters AS VARCHAR), \
     CAST(result_schema AS VARCHAR), CAST(reads_tables AS VARCHAR), CAST(writes_tables AS VARCHAR), \
     cacheable, single_occurrence, mutates_project, CAST(required_methods AS VARCHAR) \
     FROM catalogue_entries ORDER BY canonical_id";

fn env_path() -> Option<PathBuf> {
    std::env::var_os("STREAMFIND_CATALOGUE").map(PathBuf::from)
}

fn binary_relative() -> Option<PathBuf> {
    let candidate = std::env::current_exe().ok()?.parent()?.join("catalogue.duckdb");
    candidate.exists().then_some(candidate)
}

fn repo_layout() -> Option<PathBuf> {
    let candidate = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("../../../semantic/generated/catalogue.duckdb");
    candidate.exists().then_some(candidate)
}

/// Resolve `catalogue.duckdb` via the runtime search chain.
pub fn find_path() -> Option<PathBuf> {
    env_path()
        .or_else(binary_relative)
        .or_else(repo_layout)
}

fn parse_json(raw: Option<String>, id: &str) -> Result<Value, String> {
    match raw {
        None => Ok(Value::Null),
        Some(text) => serde_json::from_str(&text)
            .map_err(|error| format!("catalogue: invalid JSON for {id}: {error}")),
    }
}

fn load_entries() -> Result<Vec<Value>, String> {
    let path = find_path().ok_or_else(|| {
        "catalogue.duckdb not found; searched STREAMFIND_CATALOGUE, the executable directory, \
         and the repository semantic/generated layout. Ensure the runtime knowledge base is \
         installed alongside the binaries."
            .to_string()
    })?;
    let config = Config::default()
        .access_mode(AccessMode::ReadOnly)
        .map_err(|error| format!("catalogue: config failed: {error}"))?;
    let connection = Connection::open_with_flags(&path, config)
        .map_err(|error| format!("catalogue: failed to open {}: {error}", path.display()))?;
    let mut statement = connection
        .prepare(CATALOGUE_SQL)
        .map_err(|error| format!("catalogue: prepare failed: {error}"))?;
    let mut rows = statement
        .query([])
        .map_err(|error| format!("catalogue: query failed: {error}"))?;
    let mut entries = Vec::new();
    while let Some(row) = rows
        .next()
        .map_err(|error| format!("catalogue: row read failed: {error}"))?
    {
        let canonical_id: String = row
            .get(0)
            .map_err(|error| format!("catalogue: canonical_id read failed: {error}"))?;
        let kind: String = row
            .get(1)
            .map_err(|error| format!("catalogue: kind read failed: {error}"))?;
        let entry = json!({
            "kind": kind,
            "canonical_id": canonical_id,
            "domain": row.get::<_, String>(2).map_err(|e| e.to_string())?,
            "label": row.get::<_, String>(3).map_err(|e| e.to_string())?,
            "definition": row.get::<_, String>(4).map_err(|e| e.to_string())?,
            "executable": row.get::<_, bool>(5).map_err(|e| e.to_string())?,
            "exposed": row.get::<_, bool>(6).map_err(|e| e.to_string())?,
            "parameters": parse_json(row.get::<_, Option<String>>(9).map_err(|e| e.to_string())?, &canonical_id)?,
            "result": json!({"schema": parse_json(row.get::<_, Option<String>>(10).map_err(|e| e.to_string())?, &canonical_id)?}),
            "effects": json!({
                "mutates_project": row.get::<_, bool>(15).map_err(|e| e.to_string())?,
                "reads": parse_json(row.get::<_, Option<String>>(11).map_err(|e| e.to_string())?, &canonical_id)?,
                "writes": parse_json(row.get::<_, Option<String>>(12).map_err(|e| e.to_string())?, &canonical_id)?,
            }),
        });
        let entry = if kind == "operation" {
            let name: Option<String> = row
                .get(7)
                .map_err(|error| format!("catalogue: mcp_name read failed: {error}"))?;
            let input_schema = parse_json(
                row.get::<_, Option<String>>(8)
                    .map_err(|error| format!("catalogue: input_schema read failed: {error}"))?,
                &canonical_id,
            )?;
            let mut entry = entry;
            entry["mcp"] = json!({"name": name.unwrap_or_else(|| canonical_id.clone()), "input_schema": input_schema});
            entry
        } else {
            let mut entry = entry;
            entry["cacheable"] = json!(row.get::<_, bool>(13).map_err(|e| e.to_string())?);
            entry["single_occurrence"] = json!(row.get::<_, bool>(14).map_err(|e| e.to_string())?);
            entry["required_methods"] = parse_json(
                row.get::<_, Option<String>>(16).map_err(|e| e.to_string())?,
                &canonical_id,
            )?;
            entry
        };
        entries.push(entry);
    }
    Ok(entries)
}

struct Catalogue {
    entries: Vec<Value>,
    error: Option<String>,
}

fn catalogue() -> &'static Catalogue {
    static CATALOGUE: OnceLock<Catalogue> = OnceLock::new();
    CATALOGUE.get_or_init(|| match load_entries() {
        Ok(entries) => Catalogue {
            entries,
            error: None,
        },
        Err(error) => Catalogue {
            entries: Vec::new(),
            error: Some(error),
        },
    })
}

/// All catalogue entry documents (same shape as catalogue.json `entries`).
/// Empty when the catalogue cannot be located or read.
pub fn entries() -> &'static [Value] {
    &catalogue().entries
}

/// MCP tool definitions: exposed streamfind operations shaped
/// {name, description, inputSchema, outputSchema, effects} — the same shape
/// the generated `TOOLS` literal provided. Empty on a catalogue miss.
pub fn tools_json() -> Value {
    let tools = entries()
        .iter()
        .filter(|entry| {
            entry["kind"] == "operation"
                && entry["domain"] == "streamfind"
                && entry["exposed"].as_bool() == Some(true)
        })
        .map(|entry| {
            json!({
                "name": entry["mcp"]["name"],
                "description": entry["label"],
                "inputSchema": entry["mcp"]["input_schema"],
                "outputSchema": entry["result"]["schema"],
                "effects": entry["effects"],
            })
        })
        .collect::<Vec<_>>();
    Value::Array(tools)
}

/// Method contract documents (kind='method'), for available-methods queries.
pub fn methods_json() -> Value {
    let methods = entries()
        .iter()
        .filter(|entry| entry["kind"] == "method")
        .cloned()
        .collect::<Vec<_>>();
    Value::Array(methods)
}

/// Reason the catalogue could not be loaded, if it failed.
pub fn load_error() -> Option<&'static str> {
    catalogue().error.as_deref()
}