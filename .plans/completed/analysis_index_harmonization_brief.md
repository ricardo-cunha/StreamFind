# NTA / container-file analysis-index harmonization brief

Repo root: C:/Users/cunha/Documents/GitHub/streamfind (branch dev_refactoring). Windows; bash terminal; native tools need C:/ paths. Read AGENTS.md first (no anonymous namespaces in C++, Rust tests under the owning crate's tests/ dir, no inline #[cfg(test)]). C++20 for core.

## Background
The repo now supports **container files** (Sciex WIFF) that expose multiple logical analyses. The persisted `MASS_SPEC_ANALYSES` table carries per-row `analysis_index` (zero-based logical index within the physical file), `source_analysis_number` (vendor number), and `analysis_count`. The reader APIs (`MASS_SPEC_FILE::select_analysis(int)` in C++, `Reader::select_analysis(usize)` in Rust) switch the reader to a specific logical analysis; WIFF swaps the underlying reader/chromatograms to that analysis.

`add_analyses` already populates all rows correctly (one row per logical analysis; analysis name = file stem + "::" + logical name for WIFF). The query operations (get_spectra_headers, get_chromatograms_headers, get_spectra_tic, raw spectra ops) already call `select_analysis(row.analysis_index)`.

**The bug:** several NTA processing methods and load_chromatograms do NOT select the analysis — they open the reader and read whatever the default (analysis 0) gives. For a container file, every row except index 0 silently reads the wrong logical analysis. They also SELECT only `analysis, file_path` (missing `analysis_index`).

## Required changes (do ALL of them; keep behaviour identical for single-analysis files)
For each reader-open call site below:
1. Change the SQL to include `analysis_index` (from MASS_SPEC_ANALYSES) alongside `analysis, file_path` (and any existing columns).
2. Immediately after constructing the reader for a specific row, call `select_analysis(row.analysis_index)` (0 for single-analysis files is fine — select_analysis(0) is a no-op that keeps default).
3. For helper functions that return (analysis, path) pairs, extend them to also carry the index (e.g. tuple of 3) and thread it to the reader call.

### C++ (core/domains/mass_spec/):
- `src/processing_methods_chromatograms.cpp`:
  - `detail::analyses(...)` (returns vector<pair<analysis,path>>) — SELECT `analysis, file_path, analysis_index`, return a triple (analysis, path, index).
  - `load_chromatograms(...)` — after `MASS_SPEC_FILE file(path)` call `file.select_analysis(index)`.
- `src/processing_methods_nta.cpp`:
  - `detail::load_analysis_features(...)` — SELECT `analysis, file_path, analysis_index, blank, replicate`; after `MASS_SPEC_FILE file(...)` call `file.select_analysis(row.value("analysis_index", 0))`.
  - `find_features(...)` — SELECT `analysis, file_path, analysis_index`; `file.select_analysis(row.value("analysis_index", 0))`.
  - `load_features_ms1(...)` / `load_features_ms2(...)` — they open `data.file_paths()[i]`; the PROJECT_NON_TARGET_ANALYSIS already carries per-analysis state — add an `analysis_index` vector to that class (or reuse the index from load_analysis_features by storing per-buffer indices) and call `file.select_analysis(index)` at both open sites (lines ~591 and ~655).
  - NOTE: `nta::PROJECT_NON_TARGET_ANALYSIS` (include/streamfind/mass_spec/nta.hpp) is the in-memory NTA context; add an `std::vector<int> analysis_indices` member + setter, populate it in `load_analysis_features`, and use it in load_features_ms1/2. keep it optional/default 0.
- `src/nta_deconvolution.cpp` `find_features_impl(...)` opens `MASS_SPEC_FILE ana(file_paths[a])` at ~line 2042: it reads spectra & headers inside; the PROJECT_NON_TARGET_ANALYSIS should expose the per-analysis index too — reuse the analysis_indices member and call `ana.select_analysis(indices[a])` there. (Look at how spectra_headers_at/analysis_names are exposed and mirror an `analysis_index_at(size_t)` accessor.)

### Rust (rust/crates/mass-spec/src/):
- `lib.rs`: the operation around line 690 that opens `reader::Reader::open(row["file_path"])` (get_chromatograms / chromatogram-headers style op) — SELECT `analysis, file_path, analysis_index`, then `reader.select_analysis(row["analysis_index"]...)`.
- `processing_methods_chromatograms.rs`: `analyses(...)` helper (returns Vec<(String,String)>) — SELECT + carry `analysis_index` (Vec<(String,String,i64)>), and `load_chromatograms`/the ms2-consuming op (line ~76) call `file.select_analysis(index)`.
- `processing_methods_nta.rs`:
  - `find_features` (line ~779) — SELECT `analysis, file_path, analysis_index` from MASS_SPEC_ANALYSES (or from the feature-loading query used there), then `file.select_analysis(...)`.
  - `load_features_ms1` (line ~1019) and `load_features_ms2` (line ~1164) — they open `Reader::open(&file)` per analysis from MASS_SPEC_ANALYSES; ensure the query selects `analysis_index` and call `reader.select_analysis(...)`.

## Not required
- Do NOT touch reader.cpp/reader_sciex.cpp/reader_sciex.rs internals (select_analysis already works).
- Do NOT touch semantic/, add_analyses, or the already-correct query operations.
- Do NOT change SQL table schema.

## Build & verify
- C++: configure/build via vcvarsall x64 + Ninja (see core/README; tests on: -DSTREAMFIND_BUILD_TESTS=ON -B build/cmake/default -S core). Targets: streamfind_mass_spec_nta_processing_tests, streamfind_mass_spec_load_features_tests, streamfind_mass_spec_nta_wastewater_conformance (--quantized run also OK but slow; run the two fast ones at minimum). All must pass.
- Rust: cargo build/test -p streamfind-rust-mass-spec (tests under rust/crates/mass-spec/tests/). Must pass with no new warnings that are errors.
- Report real build/test output.

## Report
List each changed file + what changed; confirm every SELECT now includes analysis_index and every reader open now selects; paste build + test pass/fail for your backend.