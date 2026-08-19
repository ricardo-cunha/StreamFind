# Rust backend

`rust/` is an independent Rust implementation of the generic streamfind
project backend. It uses the same DuckDB project schema and JSON contract as
`streamfind-core`, but never links to or wraps the C++ implementation.

!!! note "Maturity"
    The Rust backend is an active developer-preview foundation. It is intended
    to remain interoperable with C++ through the semantic catalogue and shared
    fixtures, but it is not yet a release-stable replacement for the R package.

## Crates

- `streamfind-rust-core` — project, workflow, typed parameters, methods,
  cache, audit, and execution APIs.
- `streamfind-rust-cli` — minimal project `create` and `describe` CLI.
- `streamfind-rust-external` — resolves user-installed tools from `PATH`.
- `streamfind-rust-mcp` — line-delimited JSON-RPC MCP stdio adapter.
- `streamfind-rust-mass-spec`, `streamfind-rust-raman`,
  `streamfind-rust-sensors` — domain crates that register their capabilities.

## Build and test

From `rust/`:

```powershell
cargo fmt --all -- --check
cargo test --workspace
cargo doc --workspace --no-deps --open
```

## Project API

```rust
let project = Project::create(ProjectOptions {
    database_path: "project.duckdb".into(),
    project_id: "demo".into(),
    domain: "mass_spec".into(),
    create_if_missing: false,
    read_only: false,
})?;
```

Canonical methods follow the same `get_*` / `set_*` / `run_*` / `delete_*`
prefixes as C++. `Project` owns its DuckDB connection; `close(self)` consumes
the handle. Domains are assigned at creation and are immutable afterward.

## CLI

From the repository root:

```powershell
cargo run --manifest-path rust/Cargo.toml -p streamfind-rust-cli -- create `
  --database-path "$HOME\.streamfind\projects\demo.duckdb" `
  --project-id demo `
  --domain mass_spec

cargo run --manifest-path rust/Cargo.toml -p streamfind-rust-cli -- describe `
  --database-path "$HOME\.streamfind\projects\demo.duckdb" `
  --project-id demo
```

## Interoperability

The Rust and C++ implementations share the `PROJECT`, `CACHE`, and
`AUDIT_TRAIL` tables and the workflow/metadata/cache/audit JSON. Shared
fixtures and conformance tests live under `tests/data/` and
`rust/crates/core/tests/`.

See `rust/README.md` for the full contracts.

The [development status](../status.md) describes which capabilities have
crossed the migration boundary and which remain in the preserved R package.
