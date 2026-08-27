# Rust test tmp-centralization brief

Repo root: C:/Users/cunha/Documents/GitHub/streamfind (branch dev_refactoring). Windows, bash terminal, native tools need C:/ paths. Read AGENTS.md — specifically the "Repository Scratch, Build, and Log Locations (tmp/)" section: test-created DuckDB projects MUST live under `<repo-root>/tmp/projects/`, never `std::env::temp_dir()` / system temp.

## Already done (do NOT touch)
- New crate `rust/crates/test-support` (package `streamfind-rust-test-support`, lib `streamfind_rust_test_support`) with:
  `pub fn tmp_projects_dir() -> PathBuf` — returns `<repo-root>/tmp/projects` (creates dirs).
- Workspace `rust/Cargo.toml` members include `crates/test-support`.
- `streamfind-rust-test-support` added as `[dev-dependencies]` to: `rust/crates/core/Cargo.toml`, `rust/crates/mcp/Cargo.toml`, `rust/crates/mass-spec/Cargo.toml`, `rust/crates/external/Cargo.toml`.
- C++ side already done (mass-spec tests use a `tmp_projects.hpp` helper).

## Your job
Replace every `std::env::temp_dir()` call in the TEST files below with `streamfind_rust_test_support::tmp_projects_dir()`, and add the use-import. Runtime (`src/`) usages in `nta_metfrag.rs` / `nta_suspect_screening.rs` are OUT OF SCOPE — leave them.

Files (13):
- rust/crates/core/tests/conformance.rs
- rust/crates/core/tests/project.rs
- rust/crates/mcp/tests/protocol.rs
- rust/crates/external/tests/tools_resolution.rs
- rust/crates/mass-spec/tests/nta_conformance.rs
- rust/crates/mass-spec/tests/nta_last_two.rs
- rust/crates/mass-spec/tests/nta_query_ops.rs
- rust/crates/mass-spec/tests/processing_chromatograms.rs
- rust/crates/mass-spec/tests/processing_nta.rs
- rust/crates/mass-spec/tests/processing_nta_ms.rs
- rust/crates/mass-spec/tests/project.rs
- rust/crates/mass-spec/tests/reader.rs
- rust/crates/mass-spec/tests/smiles_targets.rs

Patterns to handle:
1. `std::env::temp_dir().join(format!("streamfind-{name}.duckdb"))` → `streamfind_rust_test_support::tmp_projects_dir().join(format!("streamfind-{name}.duckdb"))` (and any other `.join(...)` forms).
2. Add `use streamfind_rust_test_support::tmp_projects_dir;` (or fully-qualify; match the file's existing style).
3. If a test deletes the DB after the run, it still removes from the new path — keep that behaviour. Also `fs::remove_file` calls referencing the old temp path must be updated to the new path (same variable, so usually automatic).

Build + verify:
- `cd rust && cargo test -p streamfind-rust-mass-spec -p streamfind-rust-core -p streamfind-rust-mcp -p streamfind-rust-external` (target dir is configured to `<repo>/tmp/build/rust-target` via rust/.cargo/config.toml — no action needed).
- ALL tests must pass with `0 failures`. Report the real tail of each failing/succeeding suite run.
- Confirm with a grep that no `temp_dir()` remains in `rust/crates/*/tests/` (run the grep yourself and paste the result). Runtime src/ usages stay.

## Constraints
- No inline `#[cfg(test)]`; only integration tests dirs.
- Do not modify src/ runtime code.
- Do not change test semantics — only the directory the DB/fixture files land in.