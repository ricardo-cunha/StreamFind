# Development status

streamfind is in an **active architecture migration**. The repository is
building the long-term semantic, C++, and Rust foundations while preserving
the existing R package. It is not yet a single, stable release across all
languages.

## What users can use today

| Path | Maturity | Best use today |
| --- | --- | --- |
| **R package** | Preserved and functional | Production-oriented R workflows, non-target screening, and the Shiny application |
| **C++ backend** | Developer preview / active foundation | Native development, project persistence, workflow execution, and MCP integration |
| **Rust backend** | Developer preview / active foundation | Independent backend development, interoperability testing, CLI, and MCP integration |
| **MCP servers** | Working foundation | Experimenting with generic project tools and the currently registered domain capabilities |
| **Python package** | Not available yet | No public installation path yet; the package boundary is reserved |
| **Cogniflow integration** | Deferred | Not part of the current supported path |

For an existing analytical workflow, use the [R package](components/bindings-r.md).
For backend or MCP development, use the [C++](components/core-cpp.md) or
[Rust](components/rust.md) documentation and the matching quickstart.

## Implemented foundation

The active refactoring branch currently provides:

- a Turtle/SKOS/SHACL semantic catalogue with a deterministic generated
  projection;
- independent C++ and Rust project backends using the shared DuckDB schema and
  JSON contracts;
- project lifecycle, metadata, workflow, cache, audit, validation, and
  cancellation/progress foundations;
- generic, registry-driven C++ and Rust MCP servers;
- MassSpec analysis management, metadata/query operations, raw and persisted
  spectra/chromatogram access, and the first migrated feature-processing
  methods;
- initial Raman registration boundaries and shared conformance fixtures.

The [architecture](architecture.md) page explains how semantic declarations,
backend registries, and MCP tool exposure fit together.

## Current limitations

The following are intentionally unfinished or not yet supported as part of the
new public backend path:

- the complete non-target-analysis processing graph, including feature loading,
  grouping, filling, filtering, annotation, suspect screening, and
  transformation-product assignment;
- a public Python distribution, service layer, or frontend;
- a release and compatibility guarantee for the new C++/Rust APIs;
- a production-ready Cogniflow integration on top of the new public Python
  boundary;
- automatic installation or discovery of all external analytical tools.

The R package remains the functional reference for capabilities that have not
yet crossed the migration boundary. New work should be implemented directly in
`semantic/`, `core/`, and `rust/`; the R implementation should not be wrapped as
a compatibility layer for the new backends.

## How the migration progresses

A capability is considered migrated when it has all of the following:

1. a semantic declaration with parameters, results, errors, and mutation/cache
   contracts;
2. backend-neutral fixtures where appropriate;
3. an independent C++ implementation and registry entry;
4. an independent Rust implementation and registry entry; and
5. conformance and component tests.

The [living roadmap](https://github.com/odea-project/StreamFind/blob/master/.plans/streamfind_migration_plan.md)
tracks the detailed inventory and ordering. Status labels on this site describe
the current development stage, not a promise of API stability.

## Development commands

Validate the semantic contract and generated projection:

```powershell
& .\.venv\Scripts\python.exe semantic\validate_semantic.py
& .\.venv\Scripts\python.exe semantic\generate_projection.py --check
```

Build and test the C++ backend:

```powershell
# Run these commands from core/
cmake --preset default
cmake --build --preset default --config Debug
ctest --test-dir build/cmake/default -C Debug --output-on-failure
```

Test the Rust workspace:

```powershell
cargo fmt --manifest-path rust/Cargo.toml --all -- --check
cargo test --manifest-path rust/Cargo.toml --workspace
```
