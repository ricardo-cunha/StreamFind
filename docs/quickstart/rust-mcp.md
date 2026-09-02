# Quickstart: Rust MCP server

The Rust MCP server (`streamfind-rust-mcp`) is a line-delimited JSON-RPC stdio
server with the same catalogue-backed interface as the C++ server.

## 1. Obtain or build the server

### Use the Windows release

Download and extract the [Rust release](../releases.md):

```text
streamfind-rust-0.1.0-Windows-x86_64/bin/streamfind-rust-mcp.exe
streamfind-rust-0.1.0-Windows-x86_64/share/streamfind/catalogue.duckdb
```

### Build from source

From `rust/`:

```powershell
cargo build --release -p streamfind-rust-mcp
```

Or from the repository root:

```powershell
scripts\build-rust.ps1 -Release
```

## 2. Run stateless Operations

```powershell
@(
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}',
  '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}',
  '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"create","arguments":{"database_path":"demo.duckdb","project_id":"demo","domain":"mass_spec"}}}',
  '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"mass_spec.get_analyses_info","arguments":{"database_path":"demo.duckdb","project_id":"demo"}}}'
) | & .\rust\target\release\streamfind-rust-mcp.exe
```

The normal project entry path is:

1. call `initialize` and read its agent-facing instructions;
2. call `tools/list` to discover callable Operations;
3. call `create` for a new project;
4. inspect it with `describe`, `get_domain`, or `get_metadata`;
5. call domain Operations with explicit `database_path` and `project_id`.

Direct domain Operations are stateless. The server opens and closes the
selected project for that request, so `connect` and `close` are not needed.

## 3. Run workflow Methods

Workflow Methods are not MCP tools. For a workflow:

1. call `connect` with `database_path` and `project_id` for an existing project;
2. call `get_available_methods` to discover Methods and their complete schemas;
3. use `add_method` or `set_workflow` to construct the ordered workflow;
4. call `validate_workflow`, then `run_workflow` or `run_method`;
5. call `close` when finished.

`tools/list` already exposes the callable Operations before `connect`; it is not
the Method-discovery endpoint.

## 4. Configure an MCP client

Configure an MCP client to launch the extracted release executable over stdio:

```text
<extract-dir>\streamfind-rust-0.1.0-Windows-x86_64\bin\streamfind-rust-mcp.exe
```

Keep `share/streamfind/catalogue.duckdb` and `catalogue.json` with the package.
The catalogue search order is:

1. `STREAMFIND_CATALOGUE`, when explicitly set;
2. `catalogue.duckdb` next to the executable;
3. the repository source-tree catalogue for development/test runs.

## Also on this backend

Create and inspect projects without MCP with
[`streamfind-rust-cli`](../components/rust.md#cli). Optional external tools are
resolved from the process `PATH`; the backend does not download or install them.
