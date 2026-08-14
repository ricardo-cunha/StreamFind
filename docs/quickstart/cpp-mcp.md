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

## 2. Run a session

The server reads one JSON-RPC request per line on stdin and writes one
response per line on stdout. A minimal session:

```powershell
@(
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}',
  '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"create","arguments":{"database_path":"demo.duckdb","project_id":"demo","domain":"mass_spec"}}}',
  '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"connect","arguments":{"database_path":"demo.duckdb","project_id":"demo"}}}',
  '{"jsonrpc":"2.0","id":4,"method":"tools/list","params":{}}',
  '{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"mass_spec.get_analyses_info","arguments":{}}}',
  '{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"close","arguments":{"database_path":"demo.duckdb","project_id":"demo"}}}'
) | & .\build\cmake\default\core\Debug\streamfind_mcp.exe
```

Session flow:

| Step | Method | Purpose |
| --- | --- | --- |
| 1 | `initialize` | MCP handshake |
| 2 | `tools/call` `create` | Create a `mass_spec` project |
| 3 | `tools/call` `connect` | Select the project; returns its domain |
| 4 | `tools/list` | Lists generic tools plus the connected domain's capabilities |
| 5 | `tools/call` `<domain tool>` | Invoke a domain operation |
| 6 | `tools/call` `close` | Close the project handle |

## 3. Use from an MCP client

Configure your MCP client (Claude Desktop, VS Code, Cursor, etc.) to launch
the server over stdio with the command from step 1. After the client connects,
the generic operations and the connected domain's tools become available.

## Notes

- The domain methods/operations advertised after `connect` are the
  intersection of the semantic catalogue and the registered executables.
- Create the project before `connect`; `connect` only opens an existing
  project.
