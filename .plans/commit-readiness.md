# NTA migration — commit readiness

Branch: `dev_refactoring`

This is the current-state + commit checklist for the NTA migration work that has
landed on the branch. It is intended to be read (and committed) alongside the
code so the next session or reviewer knows exactly what is done, what is staged
material, and what to hold back.

## What this branch now contains (done + verified)

### 1. NTA processing suite — complete in the C++ core
The standalone C++ backend (`core/`) registers the full NTA method set, each
wired generically through the semantic catalogue (no per-method MCP code):

- Detection / loading: `find_features`, `load_features_ms1`, `load_features_ms2`
- Processing: `create_components`, `group_features`, `fill_features`,
  `subtract_blank`, `filter_features` (full R surface), `filter_features_ms2`
- Annotation: `annotate_components`, `suspect_screening`,
  `find_internal_standards`, `filter_suspects`, `filter_internal_standards`
- Correction: `correct_matrix_suppression`
- Persisted-table query: `get_features` (pre-existing), plus the new
  `MASS_SPEC_NTA_SUSPECTS` / `MASS_SPEC_NTA_INTERNAL_STANDARDS` tables

Parameters and default values reproduce the R package
(`bindings/r/R/class_MethodsNonTargetAnalysis.R`). Verified: full wastewater
conformance passes; the fast (basic_tof) tests pass; no regressions.

### 1b. Analysis-container harmonization (multi-analysis files)
- `add_analyses` enumerates container catalogs (Sciex WIFF) into one row per
  logical analysis: `analysis_index` / `source_analysis_number` / `analysis_count`
  are stored on `MASS_SPEC_ANALYSES`.
- All operations and NTA methods select the logical analysis internally by
  matching the unique analysis name and resolving the index from the DB row;
  `analysis_index` is never a user-facing argument. Analyses are addressed by
  their unique names everywhere.
- C++ and Rust both carry per-analysis indices through the NTA context and call
  `select_analysis(index)` at every reader open (find_features,
  load_analysis_features, load_features_ms1/2, load_chromatograms, raw ops).
- Fixed a latent bug: `Project::query_json` stringifies columns, so
  `analysis_index` (and other int columns) are parsed via string-tolerant
  helpers (`detail::integer_column` / `as_i64`) instead of `row.value(int)`.

### 1c. Chromatogram R-scheme harmonization
- `MASS_SPEC_CHROMATOGRAMS` now carries the reader-derived per-point columns
  `index`, `polarity`, `precursor_mz`, `activation_ce`, `product_mz` plus
  `rt`, `raw_intensity`, `baseline`, `intensity` (replicate is NOT a table
  column; it is joined from `MASS_SPEC_ANALYSES` into results).
- Both `get_chromatograms` and `get_raw_chromatograms` return the R-interface
  scheme, exactly: `project_id, analysis, replicate, index, chromatogram_id,
  polarity, precursor_mz, activation_ce, product_mz, rt, raw_intensity,
  baseline, intensity`.
- `load_chromatograms` persists via the batched DuckDB Appender
  (`Project::append_rows`) — no per-row INSERT slowdown.
- Semantic definitions are neutral element descriptions (no development-decisions
  baked into vocabulary text).

### 2. Columnar NTA data model
`MASS_SPEC_NTA_FEATURES` is structure-of-arrays in-memory, matching the persisted
DuckDB table and the columnar semantic results. Existing methods were migrated
onto it (behaviour preserved).

### 3. Batched DuckDB Appender persistence (performance fix)
`Project::append_rows` (duckdb_appender) mirrors `bindings/r/src/core/nta/nta.cpp`.
All full-table NTA rewrites use it. Measured: wastewater run cut from ~3 h to
under a minute; quantized CI variant ~53 s.

### 4. Reader layer + OpenBabel
- R-compatible reader aliases + helpers in `reader.hpp`.
- OpenBabel C-API + `sf::obabel` adapter ported into core; robust
  (`openbabel_available()` returns false instead of crashing when the DLL is absent).

### 5. Style compliance
No anonymous namespaces anywhere in project C++ (converted to named
`streamfind::*_detail` / file-local `static`), per AGENTS.md.

### 6. Tests
- `load_features_test.cpp` (basic_tof, Metoprolol-D7)
- `nta_processing_test.cpp` (full pipeline on basic_tof)
- `nta_wastewater_conformance.cpp` — full 18-file suite (default) +
  `--quantized` 3-file CI variant (fast)
- Rust: `processing_nta_ms.rs` + the earlier mass-spec tests

## Semantic layer
Declared + validated + projected (59+ entries) in `semantic/`, with regenerated
embedded metadata for both MCP implementations. Run
`.venv/Scripts/python.exe semantic/validate_semantic.py` and
`semantic/generate_projection.py` after any ontology edit.

## What is staged / modified (commit this)

All modified + added files under `.plans/`, `semantic/`, `core/` (incl. the new
`nta_*` sources, `external/` openbabel adapter, and the test files), and the Rust
mass-spec changes already present on the branch.

Subagent work-briefs that are now complete were moved to `.plans/completed/`
(`nta_wiring_brief`, `nta_fidelity_brief`, `nta_batch_persistence_brief`,
`analysis_index_harmonization_brief`, `chromatogram_r_scheme_brief`). The living
documents stay in `.plans/` root: `streamfind_migration_plan.md`,
`commit-readiness.md`, `sciex_reader_plan.md`.

## What to LEAVE OUT of the commit

- **`rust/.cargo/config.toml`** — machine-local Cargo config pointing at a temp
  linker path (`C:/Users/<user>/AppData/Local/Temp/lldw/lld-link.exe`). Do NOT
  commit; it is loader-specific. If a committed config is needed, add a
  reproducible one under `rust/` and add `rust/.cargo/` to `.gitignore`.
- **`core/build/`, `rust/target/`** — generated build output (already ignored).
- **`.worktrees/`** — local git worktree metadata (untracked).

## Remaining work (not yet on this commit)

1. **Rust parity for the NTA processing/annotation/matrix methods** — Rust still
   has only `find_features`/`get_features`/`load_features_ms1/2` + chromatogram
   methods. Port the rest to converge on the same semantic contracts.
2. **NTA queries** (`get_suspects`, `get_internal_standards`, ...) as
   `sf:Operation`s alongside the persisted tables.
3. **MetFrag + transformation-product assignment** — needs a design decision
   (MetFrag shells out to an external Java tool).
4. **MCP progress/cancellation boundary** before exposing long-running NTA
   Methods through MCP.
5. **CI adoption** — wire the quantized conformance + fast tests into CI; decide
   whether the full 18-file wastewater run is a nightly optional gate.

## Suggested commit message
`feat(nta): complete C++ NTA processing suite with R-faithful semantics and batched persistence`
