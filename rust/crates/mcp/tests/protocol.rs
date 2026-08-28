use serde_json::json;
use streamfind_rust_core::{MethodRegistry, OperationRegistry};

fn catalogue_fixture() -> serde_json::Value {
    serde_json::from_str(include_str!(
        "../../../../tests/fixtures/mcp/generic_mcp_catalogue.json"
    ))
    .unwrap()
}

#[test]
fn supports_initialize_and_tool_listing() {
    let registry = MethodRegistry::default();
    assert_eq!(
        streamfind_rust_mcp::handle(&json!({"id": 1, "method": "initialize"}), &registry)["result"]
            ["serverInfo"]["name"],
        "streamfind-rust"
    );
    assert_eq!(
        streamfind_rust_mcp::handle(&json!({"id": 2, "method": "tools/list"}), &registry)["result"]
            ["tools"]
            .as_array()
            .unwrap()
            .len(),
        26
    );
    let tools = streamfind_rust_mcp::handle(&json!({"id": 2, "method": "tools/list"}), &registry);
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
    assert_eq!(tools["result"]["tools"].as_array().unwrap().len(), 26);
}

#[test]
fn advertised_tools_match_shared_fixture() {
    let registry = MethodRegistry::default();
    let actual = streamfind_rust_mcp::handle(&json!({"id": 1, "method": "tools/list"}), &registry);
    let actual = actual["result"]["tools"].as_array().unwrap();
    for expected in catalogue_fixture()["generic_tools"].as_array().unwrap() {
        let tool = actual
            .iter()
            .find(|tool| tool["name"] == expected["name"])
            .unwrap();
        for required in expected["required"].as_array().unwrap() {
            assert!(tool["inputSchema"]["required"]
                .as_array()
                .unwrap()
                .contains(required));
        }
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
    let tools = session.handle(&json!({"id": 3, "method": "tools/list"}))["result"]["tools"]
        .as_array()
        .unwrap()
        .clone();
    assert_eq!(tools.len(), 49);
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
    assert_eq!(
        session.handle(&json!({"id": 5, "method": "tools/list"}))["result"]["tools"]
            .as_array()
            .unwrap()
            .len(),
        49
    );
    let _ = std::fs::remove_file(path);
}
