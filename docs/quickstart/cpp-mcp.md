# Quickstart: C++ MCP server

The C++ MCP server (`streamfind_mcp`) is a line-delimited JSON-RPC stdio
server that exposes the generic project operations plus the domain
capabilities registered by the composition root in
`core/tools/streamfind-mcp.cpp`.

## 1. Build

```powershell
cmake --preset default
cmake --build --preset default --config Debug
```

The server binary is built at:

```text
build/cmake/default/core/Debug/streamfind_mcp.exe
```

## 2. Run a stateless Operation

The server reads one JSON-RPC request per line on stdin and writes one
response per line on stdout. This example invokes a direct domain Operation:

```powershell
@(
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}',
  '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"create","arguments":{"database_path":"demo.duckdb","project_id":"demo","domain":"mass_spec"}}}',
  '{"jsonrpc":"2.0","id":3,"method":"tools/list","params":{}}',
  '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"mass_spec.get_analyses_info","arguments":{"database_path":"demo.duckdb","project_id":"demo"}}}'
) | & .\build\cmake\default\core\Debug\streamfind_mcp.exe
```

Session flow for this example:

| Step | Method | Purpose |
| --- | --- | --- |
| 1 | `initialize` | MCP handshake |
| 2 | `tools/call` `create` | Create a `mass_spec` project |
| 3 | `tools/list` | List generic tools |
| 4 | `tools/call` `<domain Operation>` | Invoke a stateless domain operation with `database_path` and `project_id` |

Direct domain **Operations** are stateless. The server opens the selected
project for the request and closes it before returning, so `connect` and
`close` are not needed for this path.

For workflow **Methods**, use a connected session instead:

1. Call `connect` with `database_path` and `project_id`.
2. Call `tools/list` to advertise the connected domain's registered
   Operations (Methods are never tools).
3. Call `get_available_methods` to discover the domain's Methods, then build a
   workflow with `set_workflow` / `add_method` and execute it with
   `run_workflow` (or `run_method` for a single method).
4. Call `close` when the session is finished.

## 3. Use from an MCP client

Configure your MCP client (Claude Desktop, VS Code, Cursor, etc.) to launch
the server over stdio with the command from step 1. Generic Operations can be
called with their explicit project arguments. Connect a session when using
workflow Methods.

## Runtime requirement: catalogue.duckdb

An installation is complete only when `catalogue.duckdb` — the semantic
catalogue knowledge base generated from the Turtle ontology — is present
alongside the runtime. The server refuses to start with a clear error when it
cannot locate it. Search chain:

1. `STREAMFIND_CATALOGUE` environment variable (explicit override)
2. `catalogue.duckdb` next to the executable
3. `<install-prefix>/share/streamfind/catalogue.duckdb`

In a build tree the file is copied next to the server automatically
(`semantic/generated/catalogue.duckdb` → the binary directory).

## Notes

- Domain Operations require `database_path` and `project_id` in every request.
- The domain Methods advertised after `connect` are the intersection of the
  semantic catalogue and the registered executables.
- Create the project before using it; `connect` only opens an existing project.
