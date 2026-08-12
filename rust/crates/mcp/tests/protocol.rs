use serde_json::json;
use streamfind_rust_core::MethodRegistry;

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
        19
    );
    let tools = streamfind_rust_mcp::handle(&json!({"id": 2, "method": "tools/list"}), &registry);
    let metadata = tools["result"]["tools"]
        .as_array()
        .unwrap()
        .iter()
        .find(|tool| tool["name"] == "project_set_metadata")
        .unwrap();
    assert!(metadata["inputSchema"]["required"]
        .as_array()
        .unwrap()
        .iter()
        .any(|value| value == "metadata"));
}
