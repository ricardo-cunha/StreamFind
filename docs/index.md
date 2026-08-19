# streamfind

<p align="center">
  <img src="assets/streamfind.png" width="70%" />
</p>

streamfind is a DuckDB-backed workflow framework for analytical data
processing. The repository hosts a shared **semantic catalogue**, two
independent backend implementations (**C++** and **Rust**), and the language
and integration bindings built on top of them.

!!! warning "Current development stage"
    streamfind is in an active architecture migration. The R package is the
    preserved functional user path, while the C++ and Rust backends and MCP
    servers are active developer-preview foundations. The public Python package
    and the complete non-target-analysis migration are not available yet.

See the [development status](status.md) for the current capabilities,
limitations, and recommended path for each type of user.

The central contract is the semantic catalogue: a backend-neutral declaration
of domains, operations, workflow methods, parameters, results, errors, and
interface mappings. Each backend implements that contract independently and
shares behaviour through conformance fixtures, never by wrapping the other
backend.

## Components

| Component | What it is | Status |
| --- | --- | --- |
| [Semantic catalogue](components/semantic.md) | Backend-neutral contract (Turtle + generated projection) | Foundation |
| [C++ core](components/core-cpp.md) | Independent C++20 backend with DuckDB persistence and MCP server | Active foundation |
| [Rust backend](components/rust.md) | Independent Rust backend with CLI and MCP server | Active foundation |
| [R package](components/bindings-r.md) | Formal StreamFind R package, BMFTR-funded project | Preserved and functional |
| [Python binding](components/bindings-python.md) | Public Python package | Future |
| [Cogniflow integration](components/cf-streamfind.md) | Cogniflow step package | Deferred |

## Where to start

- **Understand what is supported today** → [Development status](status.md).
- **Use the R package** for non-target screening workflows and the Shiny app →
  [R package](components/bindings-r.md).
- **Run the MCP servers** to operate projects from an MCP client →
  [C++ MCP](quickstart/cpp-mcp.md) / [Rust MCP](quickstart/rust-mcp.md).
- **Understand the design** behind the independent backends →
  [Architecture](architecture.md).
- **Develop against the contract** →
  [Semantic catalogue](components/semantic.md) and [Testing](testing.md).

## Capability boundaries

The current refactoring deliberately separates maturity levels:

| Capability | Current stage |
| --- | --- |
| R package and Shiny application | Preserved and functional |
| Semantic catalogue and generated projection | Active foundation |
| C++ and Rust project backends | Active developer-preview foundations |
| Generic MCP servers | Working foundation with registered capabilities |
| Public Python package and frontend | Not available yet |
| Cogniflow integration on the new backend path | Deferred |

## Principles

- The semantic catalogue is the authoritative source of public metadata; no
  backend keeps a duplicate method catalogue.
- C++ and Rust are independent implementations of the same contract. Rust
  never links to, wraps, or calls the C++ backend.
- The generic core and generic MCP code stay domain-neutral. Adding a method
  means a semantic declaration plus a registry registration per backend, with
  no MCP dispatch edits.
