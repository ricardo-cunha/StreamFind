# C++ API

The C++ backend provides a native project API and a C++ MCP server. The current
Windows x64 and Linux x86_64 packages are listed on [Releases](../releases.md).

!!! note "Compatibility"
    The native C++ package is a versioned preview release. It is suitable
    for applications and integration testing, but does not yet promise a stable
    cross-version ABI.

## Package contents

The C++ package includes:

- `streamfind_mcp` / `streamfind_mcp.exe`;
- the C++ libraries and public headers;
- DuckDB and other native runtime dependencies;
- `share/streamfind/catalogue.duckdb`.

The catalogue is required by the MCP server and must remain with the package.

## Project API

`streamfind::Project` owns one DuckDB-backed project selected by
`ProjectOptions`:

```cpp
streamfind::ProjectOptions options{
    "project.duckdb", "demo", std::nullopt, false, false, "mass_spec"
};
auto project = streamfind::Project::create(options);
```

Common project operations include:

```text
create, describe, validate
get_metadata, set_metadata
get_domain
get_workflow, set_workflow, validate_workflow, run_workflow
get_methods, run_method
get_cache, get_cache_size, delete_cache
get_audit_trail
copy, close
```

Domains are assigned when a project is created and are immutable afterward.

## MCP

The [C++ MCP quickstart](../quickstart/cpp-mcp.md) documents the stdio server
and the stateless Operation/workflow Method distinction.

The C++ and Rust MCP servers use the same semantic operation names and input
schemas. They remain separate native implementations.
