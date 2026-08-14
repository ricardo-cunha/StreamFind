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

## 2. Run a session

```powershell
@(
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}',
  '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"create","arguments":{"database_path":"demo.duckdb","project_id":"demo","domain":"mass_spec"}}}',
  '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"connect","arguments":{"database_path":"demo.duckdb","project_id":"demo"}}}',
  '{"jsonrpc":"2.0","id":4,"method":"tools/list","params":{}}',
  '{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"mass_spec.get_analyses_info","arguments":{}}}',
  '{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"close","arguments":{"database_path":"demo.duckdb","project_id":"demo"}}}'
) | & .\rust\target\debug\streamfind-rust-mcp.exe
```

The session flow is identical to the [C++ server](cpp-mcp.md): `initialize`,
`create`, `connect`, `tools/list`, `tools/call` on a domain tool, then
`close`.

## 3. Use from an MCP client

Configure your MCP client to launch the server over stdio with the command
from step 1.

## Also on this backend

- Create and inspect projects without MCP via the
  [`streamfind-rust-cli`](../components/rust.md#cli).
- Tool resolution (e.g. `obabel`) is handled by `streamfind-rust-external`;
  the backend does not download or install external tools.
