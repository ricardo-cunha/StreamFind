use streamfind_external::Error;

#[test]
fn missing_tool_error_requires_path_installation() {
    let error = Error::ToolNotOnPath { command: "obabel" };
    assert!(error.to_string().contains("obabel"));
    assert!(error.to_string().contains("PATH"));
}
