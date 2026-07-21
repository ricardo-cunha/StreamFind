# Streamfind Rust Backend

The Rust workspace contains the independent Rust implementation of the
Streamfind project backend.

## Crates

- `streamfind-rust-core`: DuckDB-backed Project, workflow, parameter, cache,
  and audit APIs.
- `streamfind-rust-cli`: Minimal `create` and `describe` command-line client.
- `streamfind-rust-external`: Resolves required external tools from `PATH`.

## Build And Test

```powershell
cargo fmt --all -- --check
cargo test --workspace
cargo doc --workspace --no-deps --open
```

## CLI

From the repository root:

```powershell
cargo run --manifest-path rust/Cargo.toml -p streamfind-rust-cli -- create `
  --database-path "$HOME\.streamfind\projects\demo.duckdb" `
  --project-id demo

cargo run --manifest-path rust/Cargo.toml -p streamfind-rust-cli -- describe `
  --database-path "$HOME\.streamfind\projects\demo.duckdb" `
  --project-id demo
```

## External Tools

External tools are prerequisites and are not downloaded or installed by the
Rust backend. OpenBabel must be installed so that `obabel` is available on the
process `PATH`.

The resolver reports an actionable error when a required executable is absent.
