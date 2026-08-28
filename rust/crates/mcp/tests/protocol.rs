use serde_json::json;
use streamfind_rust_core::{MethodRegistry, OperationRegistry};
use streamfind_rust_test_support::{advertised_core_tools, catalogue_entries};

/// Tool names `tools/list` must advertise: derived from the committed semantic
/// catalogue (the same file the MCP servers serve from), so these tests adapt
/// automatically when operations are added or removed.
fn advertised_tool_names() -> Vec<String> {
    advertised_core_tools()
        .into_iter()
        .map(|entry| entry["mcp"]["name"].as_str().unwrap().to_owned())
        .collect()
}

/// The full tool set after connecting to a mass_spec project: core tools +
/// the registered mass_spec operations (per the session contract, methods are
/// never tools). Domain operations are advertised domain-prefixed
/// (`mass_spec.<name>`), so the derivation mirrors the MCP naming.
fn advertised_tool_names_with_mass_spec() -> Vec<String> {
    let mut names = advertised_tool_names();
    for entry in catalogue_entries() {
        if entry["kind"] == "operation"
            && entry["domain"] == "mass_spec"
            && entry["exposed"] == true
        {
            names.push(format!(
                "mass_spec.{}",
                entry["mcp"]["name"].as_str().unwrap()
            ));
        }
    }
    names
}

/// Assert a `tools/list` payload advertises exactly the expected tool names.
fn assert_advertises(tools: &serde_json::Value, expected: &[String]) {
    let actual_names: Vec<String> = tools
        .as_array()
        .unwrap()
        .iter()
        .map(|tool| tool["name"].as_str().unwrap().to_owned())
        .collect();
    let mut expected = expected.to_vec();
    expected.sort();
    let mut actual = actual_names.clone();
    actual.sort();
    assert_eq!(
        actual, expected,
        "advertised tools differ from the catalogue"
    );
    assert_eq!(
        actual_names.len(),
        expected.len(),
        "duplicate or missing tool names"
    );
    assert!(tools
        .as_array()
        .unwrap()
        .iter()
        .all(|tool| tool["inputSchema"]["type"] == "object"));
}

#[test]
fn supports_initialize_and_tool_listing() {
    let registry = MethodRegistry::default();
    assert_eq!(
        streamfind_rust_mcp::handle(&json!({"id": 1, "method": "initialize"}), &registry)["result"]
            ["serverInfo"]["name"],
        "streamfind-rust"
    );
    let tools = streamfind_rust_mcp::handle(&json!({"id": 2, "method": "tools/list"}), &registry);
    assert_advertises(&tools["result"]["tools"], &advertised_tool_names());
    let metadata = tools["result"]["tools"]
        .as_array()
        .unwrap()
        .iter()
        .find(|tool| tool["name"] == "set_metadata")
        .unwrap();
    assert!(metadata["inputSchema"]["required"]
        .as_array()
        .unwrap()
        .iter()
        .any(|value| value == "metadata"));
}

#[test]
fn session_hides_domain_methods_until_connected() {
    let registry = MethodRegistry::default();
    let operations = OperationRegistry::default();
    let mut session = streamfind_rust_mcp::Session::new(&registry, &operations);
    let tools = session.handle(&json!({"id": 1, "method": "tools/list"}));
    // Before connecting, only the core streamfind tools are advertised — no
    // mass_spec domain operations or methods.
    assert_advertises(&tools["result"]["tools"], &advertised_tool_names());
    assert!(tools["result"]["tools"]
        .as_array()
        .unwrap()
        .iter()
        .all(|tool| !tool["name"].as_str().unwrap().starts_with("mass_spec.")));
}

#[test]
fn advertised_tools_carry_catalogue_required_parameters() {
    let registry = MethodRegistry::default();
    let actual = streamfind_rust_mcp::handle(&json!({"id": 1, "method": "tools/list"}), &registry);
    let actual = actual["result"]["tools"].as_array().unwrap();
    // Every advertised core tool must expose the required parameters the
    // catalogue declares for it (derived, so this tracks catalogue changes).
    for entry in advertised_core_tools() {
        let tool = actual
            .iter()
            .find(|tool| tool["name"] == entry["mcp"]["name"])
            .unwrap();
        let expected_required: std::collections::BTreeSet<String> = entry["parameters"]
            .as_array()
            .unwrap()
            .iter()
            .filter(|parameter| parameter["required"] == true)
            .map(|parameter| parameter["name"].as_str().unwrap().to_owned())
            .collect();
        let actual_required: std::collections::BTreeSet<String> = tool["inputSchema"]["required"]
            .as_array()
            .unwrap()
            .iter()
            .map(|value| value.as_str().unwrap().to_owned())
            .collect();
        assert_eq!(
            actual_required, expected_required,
            "required parameters differ from the catalogue for {}",
            entry["mcp"]["name"]
        );
    }
}

#[test]
fn session_lifecycle_rebinds_catalogue() {
    let registry = MethodRegistry::default();
    let mut operations = OperationRegistry::default();
    streamfind_rust_mass_spec::register_operations(&mut operations).unwrap();
    let mut session = streamfind_rust_mcp::Session::new(&registry, &operations);
    let path = streamfind_rust_test_support::tmp_projects_dir()
        .join("streamfind-rust-mcp-lifecycle.duckdb");
    let _ = std::fs::remove_file(&path);
    let call = |session: &mut streamfind_rust_mcp::Session<'_>, id, name, arguments| {
        session.handle(&json!({"id": id, "method": "tools/call", "params": {"name": name, "arguments": arguments}}))
    };
    assert!(
        call(
            &mut session,
            1,
            "create",
            json!({"database_path": path, "project_id": "mcp", "domain": "mass_spec"})
        )["result"]["isError"]
            != true
    );
    // The session only advertises domain operations after connecting to a
    // project of that domain.
    assert!(
        call(
            &mut session,
            2,
            "connect",
            json!({"database_path": path, "project_id": "mcp"})
        )["result"]["isError"]
            != true
    );
    // After connecting to a mass_spec project, the advertised set grows with
    // the mass_spec operations (derived from the catalogue), and methods stay
    // out of tools/list.
    let tools = session.handle(&json!({"id": 3, "method": "tools/list"}))["result"]["tools"]
        .as_array()
        .unwrap()
        .clone();
    assert_advertises(&json!(tools), &advertised_tool_names_with_mass_spec());
    let eic = tools
        .iter()
        .find(|tool| tool["name"] == "mass_spec.get_raw_spectra_eic")
        .unwrap();
    assert_eq!(eic["inputSchema"]["properties"]["targets"]["type"], "array");
    assert_eq!(
        eic["inputSchema"]["properties"]["targets"]["items"]["type"],
        "object"
    );
    assert_eq!(
        eic["inputSchema"]["properties"]["rt_tolerance"]["type"],
        "number"
    );
    assert_eq!(
        eic["inputSchema"]["properties"]["targets"]["examples"][0][0]["id"],
        "caffeine"
    );
    let info = call(
        &mut session,
        4,
        "mass_spec.get_analyses_info",
        json!({"database_path": path, "project_id": "mcp"}),
    );
    assert_ne!(info["result"]["isError"], true, "{info}");
    assert_eq!(
        serde_json::from_str::<serde_json::Value>(
            info["result"]["content"][0]["text"].as_str().unwrap()
        )
        .unwrap(),
        json!({
            "row_count": 0,
            "columns": {
                "analysis": [],
                "replicate": [],
                "blank": [],
                "file_path": [],
                "format": [],
                "number_spectra": [],
                "number_chromatograms": []
            }
        })
    );
    assert!(
        call(
            &mut session,
            5,
            "close",
            json!({"database_path": path, "project_id": "mcp"})
        )["result"]["isError"]
            != true
    );
    // After close, the advertised set reverts to the core tools only.
    let closed =
        session.handle(&json!({"id": 5, "method": "tools/list"}))["result"]["tools"].clone();
    assert_advertises(&closed, &advertised_tool_names());
    let _ = std::fs::remove_file(path);
}
