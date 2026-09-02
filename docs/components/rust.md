# Rust backend

`rust/` is an independent Rust implementation of the streamfind project
backend. It uses the same DuckDB project schema and JSON contract as
`streamfind-core`, but never links to or wraps the C++ implementation.

!!! note "Release status"
    The current Windows x64 package is version **0.1.0**. It is a self-contained
    development release for integration and testing, not a compatibility-stable
    Rust API promise.

Download it from [Releases](../releases.md).

## Crates

- `streamfind-rust-core` — project, workflow, typed parameters, methods, cache,
  audit, and execution APIs;
- `streamfind-rust-cli` — project `create` and `describe` CLI;
- `streamfind-rust-external` — resolves explicitly user-installed tools from
  `PATH`;
- `streamfind-rust-mcp` — line-delimited JSON-RPC MCP stdio adapter;
- `streamfind-rust-mass-spec`, `streamfind-rust-raman`, and
  `streamfind-rust-sensors` — domain crates that register capabilities.

## Build and test from source

From `rust/`:

```powershell
cargo build --workspace
cargo test --workspace
```

The repository helpers place Cargo output under `tmp/build/rust-target`:

```powershell
scripts\build-rust.ps1
scripts\test-rust.cmd
```

The default workspace test suite excludes direct reader-interface and
vendor-parity tests. Run those explicitly when the corresponding fixtures are
available:

```powershell
scripts\test-rust.cmd `
  -Package streamfind-rust-mass-spec `
  -IncludeReaderInterface
```

Equivalent Cargo command:

```powershell
cargo test -p streamfind-rust-mass-spec --features reader-interface-tests
```

## Release package layout

After extracting `streamfind-rust-0.1.0-Windows-x86_64.zip`:

```text
streamfind-rust-0.1.0-Windows-x86_64/
├── bin/
│   ├── streamfind-rust-cli.exe
│   └── streamfind-rust-mcp.exe
└── share/streamfind/
    ├── catalogue.duckdb
    └── catalogue.json
```

The catalogue files are required runtime data for the MCP server.

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

## MCP and interoperability

The [Rust MCP quickstart](../quickstart/rust-mcp.md) documents the stdio server.
Its MCP contract is equivalent to the C++ server: `tools/list` exposes
catalogue-backed Operations immediately; `get_available_methods` returns
workflow Methods and their complete schemas; `connect` is required before
running workflow Methods.

The Rust and C++ implementations share the `PROJECT`, `CACHE`, and
`AUDIT_TRAIL` tables, workflow/metadata/cache/audit JSON, and semantic catalogue,
while remaining independent runtimes.

External tools are explicit prerequisites. The backend does not download or
install them automatically.
