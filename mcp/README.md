# Streamfind MCP

The repository provides two independent MCP stdio adapters:

- C++: `streamfind_mcp.exe`, built with the native core.
- Rust: `streamfind-rust-mcp`, built from `rust/crates/mcp`.

Both implement the initial line-delimited JSON-RPC MCP surface:

- `initialize`
- `tools/list`
- `tools/call`

Both adapters expose the same project tool catalogue:

```text
project_create
project_describe
project_validate
project_get_domain
project_get_metadata / project_set_metadata
project_get_workflow / project_set_workflow
project_validate_workflow / project_run_workflow
project_get_cache / project_get_cache_size / project_delete_cache
project_get_audit_trail
get_available_methods / project_run_method
project_copy / project_close
```

Call `project_connect` once per stdio session with `database_path` and
`project_id`. After that, `tools/list` adds only methods registered for the
connected project's immutable domain, and calls to those method names run
against the connected project.

`project_run_method` appends the method to the persisted workflow before
execution. Workflow validation enforces method domain, required predecessor
methods, parameter validation, and occurrence limits.

MCP is an adapter layer. It delegates to the C++ JSON API or Rust typed API and
does not access DuckDB directly. The Rust `egui` frontend does not need MCP;
it uses the Rust API directly.
