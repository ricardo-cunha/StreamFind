# Quickstart: C++ MCP server

The C++ MCP server (`streamfind_mcp`) is a line-delimited JSON-RPC stdio
server. It exposes catalogue-backed project and domain **Operations** from the
native C++ backend.

## 1. Obtain or build the server

### Use the Windows release

Download and extract the [C++ release](../releases.md):

```text
streamfind-core-cpp-0.1.0-Windows-x86_64/bin/streamfind_mcp.exe
streamfind-core-cpp-0.1.0-Windows-x86_64/share/streamfind/catalogue.duckdb
```

### Build from source

From `core/`:

```powershell
cmake --preset default
cmake --build --preset default --config Debug
```

The repository helper builds the same target under `tmp/build/core-default`:

```powershell
scripts\build-core.cmd
```

## 2. Run stateless Operations

The server reads one JSON-RPC request per line on stdin and writes one response
per line on stdout. This example uses the source build path; replace it with the
release path when using the archive:

```powershell
@(
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}',
  '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}',
  '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"create","arguments":{"database_path":"demo.duckdb","project_id":"demo","domain":"mass_spec"}}}',
  '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"mass_spec.get_analyses_info","arguments":{"database_path":"demo.duckdb","project_id":"demo"}}}'
) | & .\tmp\build\core-default\streamfind_mcp.exe
```

The normal project entry path is:

1. `initialize` — perform the MCP handshake and read the returned instructions;
2. `tools/list` — discover callable Operations;
3. `create` — create the project;
4. `describe`, `get_domain`, or `get_metadata` — inspect it;
5. call domain Operations such as `mass_spec.add_analyses` or
   `mass_spec.get_analyses_info` with explicit `database_path` and `project_id`.

Direct domain Operations are stateless. The server opens and closes the
selected project for each request, so `connect` and `close` are not needed for
this path.

## 3. Run workflow Methods

Workflow Methods are not MCP tools. Use this session flow instead:

1. call `connect` with `database_path` and `project_id` for an existing project;
2. call `get_available_methods` to discover the domain's Methods, parameters,
   required values, and complete `inputSchema` definitions;
3. construct a workflow using `add_method` or `set_workflow`;
4. call `validate_workflow`, then `run_workflow` or `run_method`;
5. call `close` when the connected session is finished.

Do not expect Methods to appear in `tools/list`; use
`get_available_methods` for Method discovery.

## 4. Configure an MCP client

Configure Claude Desktop, VS Code, Cursor, or another MCP client to launch the
server executable over stdio. For the extracted release, use:

```text
<extract-dir>\streamfind-core-cpp-0.1.0-Windows-x86_64\bin\streamfind_mcp.exe
```

Keep the package's `share/streamfind/catalogue.duckdb` available. The server's
catalogue search order is:

1. `STREAMFIND_CATALOGUE`, when explicitly set;
2. `catalogue.duckdb` next to the executable;
3. the installed `share/streamfind/catalogue.duckdb` location.

## Notes

- Operations require `database_path` and `project_id` on every applicable call.
- `connect` opens an existing project for workflow Methods; it does not create a
  project.
- The C++ and Rust servers expose the same semantic operation names and input
  schemas, but are separate native implementations.
- Optional scientific tools are not installed automatically.
