# Chromatogram R-scheme harmonization brief (C++ / Rust)

Repo root: C:/Users/cunha/Documents/GitHub/streamfind (branch dev_refactoring). Windows; bash terminal; native tools need C:/ paths. Read AGENTS.md (no anonymous namespaces in C++; Rust tests in the owning crate's tests/ dir). C++20.

## Goal
Make the mass-spec chromatogram data returned by BOTH `mass_spec.get_chromatograms` (persisted) and `mass_spec.get_raw_chromatograms` (from source files) match the R interface's exported chromatogram scheme, and make the persisted `MASS_SPEC_CHROMATOGRAMS` table carry the reader-derived per-point columns.

## The R scheme (authoritative)
From `bindings/r/src/rcpp_project_export.cpp` (the chromatogram-data DataFrame export), a chromatogram point row has these fields:

```
analysis, replicate, index, chromatogram_id, polarity, pre_mz, pre_ce, pro_mz, rt, intensity
```

- `analysis` = analysis name; `replicate` = replicate label (may be NA/empty); `index` = zero-based chromatogram index within the analysis; `chromatogram_id` = id string; `polarity` = int; `pre_mz` = precursor m/z, `pre_ce` = precursor collision energy, `pro_mz` = product m/z (from header row: precursor_mz, activation_ce, product_mz); `rt` = retention time point; `intensity` = intensity point.

## Semantic contract (already updated & regenerated — 61 entries)
- `MASS_SPEC_CHROMATOGRAMS` table columns (NOTE: replicate is NOT a table column — it stays owned by MASS_SPEC_ANALYSES and is joined at result time):
  `project_id, analysis, index, chromatogram_id, polarity, pre_mz, pre_ce, pro_mz, rt, raw_intensity, baseline, intensity, created_at`
  (index/polarity/pre_mz/pre_ce/pro_mz are the new reader-derived columns; raw_intensity + baseline are processing extras kept from before.)
- `chromatogramsResult` properties (the result/JSON surface for BOTH get_chromatograms and get_raw_chromatograms), which DOES include replicate:
  `project_id, analysis, replicate, index, chromatogram_id, polarity, pre_mz, pre_ce, pro_mz, rt, raw_intensity, baseline, intensity`
  Column names are exactly: `project_id`, `analysis`, `replicate`, `index`, `chromatogram_id`, `polarity`, `pre_mz`, `pre_ce`, `pro_mz`, `rt`, `raw_intensity`, `baseline`, `intensity`.
- Read `semantic/generated/catalogue.json` entries for `mass_spec.get_chromatograms` and `mass_spec.get_raw_chromatograms` (and `mass_spec.load_chromatograms`) to confirm the exact projected result/parameter names after regeneration.

## Required changes

### C++ (core/domains/mass_spec/): 
1. `src/processing_methods_chromatograms.cpp`:
   - `ensure_table()`: extend the `MASS_SPEC_CHROMATOGRAMS` CREATE TABLE with `index INTEGER NOT NULL`, `polarity INTEGER`, `pre_mz DOUBLE`, `pre_ce DOUBLE`, `pro_mz DOUBLE` (nullable metadata; `index` NOT NULL default 0). Also `ALTER TABLE ... ADD COLUMN IF NOT EXISTS` for each new column so existing databases migrate. Do NOT add a `replicate` column.
   - `load_chromatograms()`: when inserting a point, also store the reader header's `index`, `polarity`, `precursor_mz` (-> `pre_mz`), `activation_ce` (-> `pre_ce`), `product_mz` (-> `pro_mz`) for that chromatogram. The reader headers are already read (`file.get_chromatograms_headers()`); keep the per-point loop and add the columns to the INSERT + values.
2. `src/mass_spec.cpp`:
   - `Project::get_chromatograms(...)`: change the SELECT to include the new columns (index, polarity, pre_mz, pre_ce, pro_mz) AND JOIN `MASS_SPEC_ANALYSES` on project_id+analysis to bring in `replicate`. Return rows keyed exactly as the result contract: `project_id, analysis, replicate, index, chromatogram_id, polarity, pre_mz, pre_ce, pro_mz, rt, raw_intensity, baseline, intensity` (replicate may be null/empty; keep numeric conversions of rt/raw_intensity/baseline/intensity to numbers — the existing code already re-parses those from query_json strings; do the same for the new numeric columns).
   - `Project::get_raw_chromatograms(...)`: for each analysis row, SELECT also `replicate` from MASS_SPEC_ANALYSES and, per chromatogram point, output the full R scheme: `project_id, analysis, replicate, index, chromatogram_id, polarity, pre_mz, pre_ce, pro_mz, rt, intensity` (raw_intensity = intensity, baseline = 0.0) — mirroring the R exporter exactly. `index`/`polarity`/`pre_mz`/`pre_ce`/`pro_mz` come from `file.get_chromatograms_headers()`; the count/min semantics stay as-is.
   - Make sure the operations' result passes through `detail::columnar(...)` consistently (the register.cpp wrapper already columnarises table results using the semantic result schema — verify the projection names match what you emit).

### Rust (rust/crates/mass-spec/src/):
1. `processing_methods_chromatograms.rs`:
   - `CHROMATOGRAMS_SCHEMA` (or local ensure): add `index INTEGER NOT NULL DEFAULT 0`, `polarity INTEGER`, `pre_mz DOUBLE`, `pre_ce DOUBLE`, `pro_mz DOUBLE` + ALTER-ADD for existing DBs. No replicate column.
   - `load_chromatograms` / filter insert: persist the new columns from the reader's chromatogram (Chromatogram struct in reader.rs has id, polarity, precursor_mz?, activation_ce?, product_mz?, time, intensity — CHECK the actual struct fields; map to pre_mz/pre_ce/pro_mz; index = the chromatogram's index in the file).
2. `lib.rs`:
   - `get_chromatograms`-ish operation (~line 690 area): extend SELECT with the new columns + JOIN MASS_SPEC_ANALYSES for `replicate`; emit the full R-scheme JSON keys.
   - `get_raw_chromatograms` operation: emit the R scheme with `replicate` from MASS_SPEC_ANALYSES and per-point `index`, `polarity`, `pre_mz`, `pre_ce`, `pro_mz` from the reader chromatogram headers.

## Constraints
- `replicate` appears ONLY in results (joined), NEVER as a MASS_SPEC_CHROMATOGRAMS column.
- Keep single-analysis behaviour identical; only the schema/result shape widens.
- Do NOT touch reader.cpp / reader_sciex.cpp / reader.rs / reader_sciex.rs internals beyond reading existing fields.
- Do not break `filter_chromatograms_retention_time` or tests; update test fixtures that hand-roll MASS_SPEC_CHROMATOGRAMS if the added NOT NULL column requires it (prefer column-list INSERTs to stay strict-compatible).

## Build & verify
- C++: vcvarsall x64 + Ninja (tests: -DSTREAMFIND_BUILD_TESTS=ON -B build/cmake/default -S core). Run streamfind_mass_spec_load_features_tests and streamfind_mass_spec_nta_processing_tests (fast) — must pass.
- Rust: cargo test -p streamfind-rust-mass-spec (tests under rust/crates/mass-spec/tests/) — must pass.
- Report real output + the exact JSON keys emitted by get_chromatograms and get_raw_chromatograms for one analysis (paste a sample row) as evidence the R scheme is matched.

## Report
List files changed; paste the schema DDL and the sample result row for both operations; confirm replicate is only joined-in, not stored; paste build/test pass/fail.