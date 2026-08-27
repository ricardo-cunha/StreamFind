# NTA table query Operations brief (C++ / Rust)

Repo root: C:/Users/cunha/Documents/GitHub/streamfind (branch dev_refactoring). Windows; bash terminal; native tools need C:/ paths. Read AGENTS.md (no anonymous namespaces in C++; Rust tests under the owning crate's tests/ dir). C++20.

## Goal
Add three NTA table query `sf:Operation`s to YOUR backend, reusing the existing `mass_spec.get_features` query pattern as much as possible:
- `mass_spec.get_suspects` — read persisted `MASS_SPEC_NTA_SUSPECTS`
- `mass_spec.get_internal_standards` — read persisted `MASS_SPEC_NTA_INTERNAL_STANDARDS`
- `mass_spec.get_transformation_products` — read persisted `MASS_SPEC_NTA_TRANSFORMATION_PRODUCTS` (NEW table; `assign_transformation_products` must now persist real TP rows here)

User-visible semantics (identical for all three, matching get_features): same parameters (`analysis_names`, `targets`, `polarity` [suspects/IS only], `ppm`, `rt_tolerance`); default targets `[{}]` (or absent) returns the ENTIRE table for the project; targets filter by analysis, polarity, mass/mz window (±ppm), rt window (±rt_tolerance), and SMILES/InChI exact-mass (via the backend's Open Babel normalize helper). SQL `WHERE project_id = X` plus filters, `ORDER BY analysis`.

## Semantic contract (ALREADY DONE + regenerated — do NOT edit semantic/)
The catalogue now declares the three operations (66 entries) with:
- ops: `mass_spec.get_suspects` / `get_internal_standards` / `get_transformation_products`; params `database_path, project_id, analysis_names, targets, polarity (suspects+IS only), ppm, rt_tolerance`; defaults `{"analysis_names":[],"ppm":20.0,"rt_tolerance":60.0}`; results `suspectsResult` / `internalStandardsResult` / `transformationProductsResult`.
- results reference the suspects (`suspects*`), internal-standard (`is*`), and transformation-product (`tp*`) columns.
- NEW table `MASS_SPEC_NTA_TRANSFORMATION_PRODUCTS` (column names exactly as in the `tp*` columns: analysis, feature_group, precursor_feature_group, main_precursor_feature_group, assignment_rank, name, formula, mass, SMILES, InChI, InChIKey, xLogP, transformation, precursor_name, precursor_formula, precursor_mass, precursor_SMILES, precursor_InChI, precursor_InChIKey, precursor_xLogP, main_precursor_name, main_precursor_formula, main_precursor_mass, main_precursor_SMILES, main_precursor_InChI, main_precursor_InChIKey, main_precursor_xLogP, cosine_similarity, main_precursor_cosine_similarity, rt_plausibility, main_precursor_rt_plausibility, assignment_score, network_level, assignment_status) + project_id, created_at.
- `mass_spec.assign_transformation_products` `sf:writes` now lists `suspectsTable, transformationProductsTable`.

Read `semantic/generated/catalogue.json` entries for the three ops to confirm exact result-schema property names and match them EXACTLY as emitted keys.

## Cross-backend re-use notes
- Model the executors directly on YOUR backend's existing `get_features` implementation (C++: `core/domains/mass_spec/src/mass_spec.cpp` `Project::get_features`; Rust: `rust/crates/mass-spec/src/lib.rs` `get_features_impl`). Generalize the table name + column names; the filter-building logic (analyses IN, polarity IN, mass/mz BETWEEN ±ppm, rt BETWEEN ±rt_tolerance, SMILES/InChI → normalized exact mass) is identical, just pointed at the target table's columns (`db_mass`/`exp_mass`, `db_rt`/`exp_rt` for suspects/IS/tp: use `mass` and `rt` if present; check the actual table columns).
- Suspects/IS tables already exist (persisted by `persist_suspects` / `persist_internal_standards`).

## Required changes

### C++ (core/domains/mass_spec/):
1. `src/mass_spec.cpp` — add `Project::get_suspects`, `Project::get_internal_standards`, `Project::get_transformation_products` (declare in `include/streamfind/mass_spec/mass_spec.hpp`): mirror `get_features` with the target table (`MASS_SPEC_NTA_SUSPECTS` / `MASS_SPEC_NTA_INTERNAL_STANDARDS` / `MASS_SPEC_NTA_TRANSFORMATION_PRODUCTS`). For SMILES/InChI exact-mass reuse `sf::obabel::normalize_structure` (already used by get_features). Polarity param only for suspects + IS (those tables have polarity column); transformation-products table has NO polarity column → drop the polarity matcher for that op.
2. `src/processing_methods_nta.cpp` — `assign_transformation_products`: after computing `products` (the `nta::api::NTA_TRANSFORMATION_PRODUCTS`), persist them to `MASS_SPEC_NTA_TRANSFORMATION_PRODUCTS` via the Appender (`append_rows`) following the `persist_suspects` pattern: CREATE TABLE IF NOT EXISTS (columns exactly as listed above, project_id + analysis + feature_group + ... + created_at; PRIMARY KEY(project_id, analysis, feature_group, name)), DELETE for the project, batch-insert rows via a new `tp_cells(...)`/`tp_columns()` helper (mirror `suspect_cells`/`suspects_columns`). Keep the existing suspects-table append behaviour (TP assignments still appended to suspects). Map from `NTA_TRANSFORMATION_PRODUCT_ROW` fields (see include/streamfind/mass_spec/nta.hpp ~line 828): analysis = the buffer/analysis resolved in `append_transformation_products_to_suspects` (use the same `analysis_of_group`/fallback logic; simplest: reuse the resolved analysis per row, or refactor that helper to ALSO emit the TP rows with their analysis).
3. `src/register.cpp` — register the three operations (they are Operations, not Methods): follow the existing operation registration pattern (analyses_info / get_features style; table_result with the semantic result name). Verify with `semantic/validate_semantic.py` (it checks C++ registration) — it must pass.

### Rust (rust/crates/mass-spec/src/):
1. `lib.rs` — add `get_suspects_impl`, `get_internal_standards_impl`, `get_transformation_products_impl` mirroring `get_features_impl` (line ~795) with the target table + columns; SMILES/InChI via `crate::nta_suspect_screening::normalize_structure` (as get_features does); polarity only for suspects/IS. Register the three operations in the dispatch (`"mass_spec.get_suspects" => ...`, etc.) following the get_features registration pattern; they are Operations.
2. `processing_methods_nta.rs` — `assign_transformation_products`: persist the TP rows (the `out` vec of TP rows) to `MASS_SPEC_NTA_TRANSFORMATION_PRODUCTS` via the crate's batched insert (mirror `persist_suspects` in that file; CREATE/ALTER + DELETE + batch INSERT with tp columns). The TP row struct (see `nta_transformation_products.rs` `transformation_product_to_suspect` + the row type) must supply the fields; resolve `analysis` per row from the same group→buffer logic used for the suspects append.
3. Keep `cargo test -p streamfind-rust-mass-spec` green; add/adjust integration tests to exercise the three get_* ops (e.g. after running a pipeline that populates suspects/IS, assert non-empty result; TP table at least creatable/queryable, empty-or-populated).

## Build & verify
- C++: vcvarsall x64 + Ninja, tests ON, `-B build/cmake/default -S core`; run `streamfind_mass_spec_load_features_tests` + `streamfind_mass_spec_nta_processing_tests` (fast) — must pass; also run `semantic/validate_semantic.py` and confirm it no longer reports missing C++ IDs (it checks registration).
- Rust: `cargo test -p streamfind-rust-mass-spec`.
- Report real build/test output; paste one sample row (or the column list) per new op as evidence the emitted keys match the catalogue result schema.

## Constraints
- Do NOT edit `semantic/` (already done; projection regenerated at 66 entries).
- Result keys must match the catalogue result-schema property names EXACTLY (read catalogue.json).
- `get_transformation_products` reads ONLY the new TP table (not the suspects `_transform_` rows).
- Keep existing behaviour intact; no anonymous namespaces in C++; no inline `#[cfg(test)]` in Rust.
- Replicate the `query_json` stringification tolerance for numeric columns exactly as get_features does (C++ `detail::integer_column`-style where needed; Rust `as_f64`/`as_i64`-style).

## Report
Files changed; where each op is registered; the TP table DDL + how assign_transformation_products persists; sample result column keys; build/test output; validator result.