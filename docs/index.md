# streamfind

<p align="center">
  <img src="assets/streamfind.png" width="70%" />
</p>

streamfind is a DuckDB-backed workflow framework for analytical data
processing. The repository hosts a shared **semantic catalogue**, two
independent backend implementations (**C++** and **Rust**), and the language
and integration bindings built on top of them.

The central contract is the semantic catalogue: a backend-neutral declaration
of domains, operations, workflow methods, parameters, results, errors, and
interface mappings. Each backend implements that contract independently and
shares behaviour through conformance fixtures, never by wrapping the other
backend.

## Components

| Component | What it is | Status |
| --- | --- | --- |
| [Semantic catalogue](components/semantic.md) | Backend-neutral contract (Turtle + generated projection) | Foundation |
| [C++ core](components/core-cpp.md) | Independent C++20 backend with DuckDB persistence and MCP server | Foundation |
| [Rust backend](components/rust.md) | Independent Rust backend with CLI and MCP server | Foundation |
| [R package](components/bindings-r.md) | Formal StreamFind R package, BMFTR-funded project | Preserved and functional |
| [Python binding](components/bindings-python.md) | Public Python package | Future |
| [Cogniflow integration](components/cf-streamfind.md) | Cogniflow step package | Deferred |

## Where to start

- **Use the R package** for non-target screening workflows and the Shiny app →
  [R package](components/bindings-r.md).
- **Run the MCP servers** to operate projects from an MCP client →
  [C++ MCP](quickstart/cpp-mcp.md) / [Rust MCP](quickstart/rust-mcp.md).
- **Understand the design** behind the independent backends →
  [Architecture](architecture.md).
- **Develop against the contract** →
  [Semantic catalogue](components/semantic.md) and [Testing](testing.md).

## Principles

- The semantic catalogue is the authoritative source of public metadata; no
  backend keeps a duplicate method catalogue.
- C++ and Rust are independent implementations of the same contract. Rust
  never links to, wraps, or calls the C++ backend.
- The generic core and generic MCP code stay domain-neutral. Adding a method
  means a semantic declaration plus a registry registration per backend, with
  no MCP dispatch edits.
