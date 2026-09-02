# C++ core

`core/` is the standalone C++20 backend (`streamfind-core`) for project
persistence, native domain operations, and generic workflow execution. It does
not depend on R, Python, FastAPI, or React. Domain libraries depend on the
generic core; the generic core never depends on domains.

!!! note "Release status"
    The current Windows x64 package is version **0.1.0**. It is a self-contained
    development release for integration and testing, not a compatibility-stable
    C++ SDK or ABI promise.

Download it from [Releases](../releases.md).

## Build and test from source

From `core/`:

```powershell
cmake --preset default
cmake --build --preset default --config Debug
ctest --test-dir ../tmp/build/core-default -C Debug --output-on-failure
```

The repository helper is the preferred path because it uses the configured
Windows toolchain and the repository-local temporary build directory:

```powershell
scripts\build-core.cmd
scripts\test-core.cmd
```

The default test helper excludes tests labelled `reader-interface`. To include
them explicitly:

```powershell
scripts\test-core.cmd -IncludeReaderInterface
```

## Release package layout

After extracting `streamfind-core-cpp-0.1.0-Windows-x86_64.zip`:

```text
streamfind-core-cpp-0.1.0-Windows-x86_64/
├── bin/
│   └── streamfind_mcp.exe
├── include/
├── lib/
└── share/streamfind/
    └── catalogue.duckdb
```

The catalogue is required by the MCP server. Do not distribute or move the MCP
executable without its package data and native runtime dependencies.

## Project API

`streamfind::Project` owns one DuckDB-backed project selected by
`ProjectOptions`:

```cpp
streamfind::ProjectOptions options{
    "project.duckdb", "demo", std::nullopt, false, false, "mass_spec"
};
auto project = streamfind::Project::create(options);
```

Canonical methods use these prefixes:

- `get_*` — read project state, metadata, workflow, cache, audit, identity, or
  database path;
- `set_*` — mutate metadata, workflow, or cache entries;
- `run_*` — execute one method or the persisted workflow;
- `delete_*` — remove project-owned cache data.

`Project` is move-only and owns its native DuckDB state. `close()` marks the
handle closed; later operations fail. Domains are assigned at creation and
cannot be changed afterward.

## MCP and JSON interfaces

The [C++ MCP quickstart](../quickstart/cpp-mcp.md) documents the stdio server.
The server exposes catalogue-backed Operations immediately through `tools/list`.
Workflow Methods are discovered by `get_available_methods` after `connect` and
are not MCP tools.

`streamfind::api::run()` exposes the same generic project operations through the
C++ JSON API. Direct domain Operations remain stateless and require
`database_path` and `project_id` in every request.

The C++ and Rust backends use the same semantic catalogue, DuckDB schema, and
JSON contracts, but remain independent implementations.
