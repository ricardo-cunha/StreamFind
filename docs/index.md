# streamfind

<p align="center">
  <img src="assets/streamfind.png" width="70%" />
</p>

streamfind is a DuckDB-backed workflow framework for analytical data
processing. The repository contains a shared **semantic catalogue**, independent
**C++ and Rust backends**, native mass-spectrometry readers, MCP servers, the
preserved R package, and related integration boundaries.

!!! note "Current release status"
    Version **0.1.0** development releases are available for the Windows x64
    C++ core and Rust backend. They are suitable for testing and integration,
    but do not yet promise stable cross-version APIs or ABIs.

The central contract is the **semantic catalogue**: a backend-neutral
declaration of domains, operations, workflow methods, parameters, results,
errors, and agent-facing interface guidance. C++ and Rust implement that
contract independently and share behavior through schemas and conformance
fixtures, not through a shared runtime.

## Components

| Component | What it provides | Current status |
| --- | --- | --- |
| [Semantic catalogue](components/semantic.md) | Turtle/SKOS/SHACL source plus generated JSON and DuckDB projections | Authoritative contract |
| [C++ core](components/core-cpp.md) | Native C++20 project backend, mass-spec domain, CLI/API support, and MCP server | Windows x64 development release |
| [Rust backend](components/rust.md) | Independent Rust project backend, native readers, CLI, and MCP server | Windows x64 development release |
| [R package](components/bindings-r.md) | Existing R workflows and Shiny application | Preserved and functional |
| [Python binding](components/bindings-python.md) | Public Python package boundary | Not released |
| [Cogniflow integration](components/cf-streamfind.md) | Separate Cogniflow adapter boundary | Not part of the current native release path |

## Where to start

- **Download the native packages** → [Releases](releases.md).
- **Use C++ through MCP** → [C++ MCP quickstart](quickstart/cpp-mcp.md).
- **Use Rust through MCP** → [Rust MCP quickstart](quickstart/rust-mcp.md).
- **Understand current capabilities and limitations** → [Development status](status.md).
- **Understand the catalogue, registries, and MCP composition** → [Architecture](architecture.md).
- **Develop or validate the backends** → [Testing](testing.md).
- **Use the existing R workflow path** → [R package](components/bindings-r.md).

## Current MCP contract

Both native MCP servers communicate over line-delimited JSON-RPC on standard
input/output and use the generated semantic catalogue for tool names,
descriptions, parameter schemas, annotations, and interface metadata.

- `initialize` returns agent-facing instructions for project creation,
  inspection, stateless domain operations, and workflow execution.
- `tools/list` advertises callable **Operations**, including domain operations,
  before a project is connected.
- Direct domain Operations are stateless and require `database_path` and
  `project_id` on every call.
- Workflow **Methods** are not MCP tools. Discover them with
  `get_available_methods` and execute them through a connected project session.
- `connect` is required for workflow Methods; `close` ends that session.

The [MCP quickstarts](quickstart/cpp-mcp.md) show the complete
`create → inspect → operate` and `connect → discover methods → run workflow`
paths.

## Capability boundaries

| Capability | Current status |
| --- | --- |
| Native C++ and Rust project backends | Available as development releases |
| Native mass-spectrometry readers and project operations | Available in the current backend implementations; vendor-fixture coverage varies |
| Generic C++ and Rust MCP servers | Working catalogue-driven interfaces |
| Semantic catalogue and generated projection | Authoritative and shared by both backends |
| Existing R package and Shiny application | Preserved and functional, separate from the native release packages |
| Public Python package and frontend | Not released |
| Cogniflow integration on the native public-Python path | Not part of the current supported path |

The native releases are intended for backend and MCP integration testing. The
R package remains the existing user-facing path for workflows that have not yet
been validated as part of the native release contract.
