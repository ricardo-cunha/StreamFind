# Quickstart: Rust MCP server

The Rust MCP server (`streamfind-rust-mcp`) is a line-delimited JSON-RPC stdio
server with the same generic algorithm as the C++ server. Its composition root
is `rust/crates/mcp/src/main.rs`.

## 1. Build

From the repository root:

```powershell
cargo build --manifest-path rust/Cargo.toml -p streamfind-rust-mcp
```

The server binary is built at:

```text
rust/target/debug/streamfind-rust-mcp.exe
```

## 2. Run a stateless Operation

```powershell
@(
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}',
  '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"create","arguments":{"database_path":"demo.duckdb","project_id":"demo","domain":"mass_spec"}}}',
  '{"jsonrpc":"2.0","id":3,"method":"tools/list","params":{}}',
  '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"mass_spec.get_analyses_info","arguments":{"database_path":"demo.duckdb","project_id":"demo"}}}'
) | & .\rust\target\debug\streamfind-rust-mcp.exe
```

This example invokes a stateless domain **Operation**. The server opens and
closes the project for that request, so `connect` and `close` are not needed.

For workflow **Methods**, use a connected session: call `connect`, call
`tools/list` to obtain the connected domain's Operations (Methods are never
tools), call `get_available_methods` to discover the domain's Methods, then
`set_workflow` / `run_workflow` (or `run_method` for a single method), and
call `close` when finished. The session flow is otherwise identical to the
[C++ server](cpp-mcp.md).

## 3. Use from an MCP client

Configure your MCP client to launch the server over stdio with the command
from step 1. Generic Operations require `database_path` and `project_id` in
each request; workflow Methods use the connected project session.

## Runtime requirement: catalogue.duckdb

An installation is complete only when `catalogue.duckdb` — the semantic
catalogue knowledge base generated from the Turtle ontology — is present
alongside the runtime. The server refuses to start with a clear error when it
cannot locate it. Search chain:

1. `STREAMFIND_CATALOGUE` environment variable (explicit override)
2. `catalogue.duckdb` next to the executable
3. the repository source-tree layout (`semantic/generated`), for dev/test runs

## Also on this backend

- Create and inspect projects without MCP via the
  [`streamfind-rust-cli`](../components/rust.md#cli).
- Tool resolution (e.g. `obabel`) is handled by `streamfind-rust-external`;
  the backend does not download or install external tools.
