# NTA wiring brief — wire 10 processing methods in core/ (C++)

Repo root: C:/Users/cunha/Documents/GitHub/streamfind (branch dev_refactoring). Windows, bash terminal; native tools use forward-slash paths. Read AGENTS.md first (no anonymous namespaces; use named `streamfind::detail` or file-local `static`; do not touch core/vendor/). C++20.

## Goal
The standalone C++ backend `core/` now has a COLUMNAR NTA data model and 8 algorithm files already compiling+linking into `streamfind_mass_spec`. Wire the 10 new NTA workflow Methods as executors + register them. Do NOT touch semantic/, Rust, or the reader. Build + run the existing library + tests.

## Key reference files (already working / read first)
- `core/domains/mass_spec/src/processing_methods_nta.cpp` — has `find_features`, `load_features_ms1`, `load_features_ms2` wired. Reuse its `detail::` helpers: `sql()`, `row_sql(project_id, NTA_FEATURE_ROW)` (builds full 70-col VALUES list), `load_analysis_features(project, parameters)` (builds a `nta::PROJECT_NON_TARGET_ANALYSIS` from persisted MASS_SPEC_NTA_FEATURES + MASS_SPEC_ANALYSES), `merge_nta_feature_spectra`, `encode_float_array`.
- `core/domains/mass_spec/include/streamfind/mass_spec/processing_methods_nta.hpp` — declare the 10 new executor signatures here (like the existing `Json find_features(project, parameters)`).
- `core/domains/mass_spec/src/register.cpp` `register_methods()` — add `else if` branches for the 10 new IDs mapping to the new executors (loop is already generic over the catalogue).
- `core/domains/mass_spec/include/streamfind/mass_spec/nta.hpp` — the columnar model: `nta::api::NTA_FEATURES` (columns + `size()`/`get_feature(i)`/`set_feature(i,row)`/`append_feature(row)`), `nta::api::NTA_SUSPECTS`/`NTA_SUSPECT_ROW`, `nta::api::NTA_INTERNAL_STANDARDS`/`NTA_INTERNAL_STANDARD_ROW`, and `nta::PROJECT_NON_TARGET_ANALYSIS` (alias for `nta::api::PROJECT_NON_TARGET_ANALYSIS`) with `analysis_names()`, `file_paths()`, `spectra_headers_at(i)`, `feature_buffers()` (vector<NTA_FEATURES>&), `blank_names()`, `replicate_names()`, `suspect_buffers()`, `internal_standard_buffers()`.
- Algorithm `*_impl` functions (already compiling) live in `nta_annotation.hpp/.cpp`, `nta_componentization`, `nta_blank_subtraction`, `nta_filters`, `nta_gap_filling`, `nta_alignment`, `nta_suspect_screening`, `nta_correction_algorithms` — namespaces `nta::{annotation, componentization, blank_subtraction, gap_filling, alignment, filter_features, filter_suspects, filter_internal_standards, filter_features_ms2, suspect_screening, correction_algorithms}`. Read each `.hpp` for the exact `*_impl` signature and parameter meaning BEFORE writing its executor.

## The 10 methods, their canonical IDs, wire params (snake_case, from semantic/generated/catalogue.json), and the `*_impl` to call
1. `mass_spec.subtract_blank` — params: analysis_names, blank_threshold, rt_expand, mz_expand, min_traces_intensity → `nta::blank_subtraction::subtract_blank_impl(nta_data, blankThreshold, rtExpand, mzExpand, minTracesIntensity)`.
2. `mass_spec.filter_features` — params: analysis_names, min_snr, noise_threshold, blank_names, max_feature_width, ppm, rt_min, rt_max, mz_min, mz_max → `nta::filter_features::filter_features_impl(nta_data, ...)`. Read its full 30-arg signature in nta_filters.hpp; map the 10 exposed params to it and pass sensible defaults for the rest (keep operation intact).
3. `mass_spec.filter_features_ms2` — params: analysis_names, top, min_intensity_ms2, rel_min_intensity, blank_clean, mz_clust, blank_presence_threshold, global_presence_threshold → `nta::filter_features_ms2::filter_features_ms2_impl(nta_data, top, minIntensity, relMinIntensity, blankClean, mzClust, blankPresenceThreshold, globalPresenceThreshold)`.
4. `mass_spec.group_features` — params: analysis_names, method, rt_deviation, ppm, min_samples, bin_size → `nta::alignment::group_features_impl(nta_data, method, rt_deviation, ppm_threshold, min_samples, bin_size)`.
5. `mass_spec.fill_features` — params: analysis_names, within_replicate, filtered, rt_expand, mz_expand, max_peak_width, min_traces_intensity, min_number_traces, min_intensity_ms1, rt_apex_deviation, min_signal_to_noise_ratio, min_gaussian_fit → `nta::gap_filling::fill_features_impl(nta_data, withinReplicate, filtered, rtExpand, mzExpand, maxPeakWidth, minTracesIntensity, minNumberTraces, minIntensity, rtApexDeviation, minSNR, minGaussianFit)`.
6. `mass_spec.create_components` — params: analysis_names, rt_window, min_correlation → `nta::componentization::create_components_impl(nta_data, rtWindow, minCorrelation)`.
7. `mass_spec.annotate_components` — params: analysis_names, max_isotopes, max_charge, max_gaps, ppm, isotope_elements → `nta::annotation::annotate_components_impl(nta_data, maxIsotopes, maxCharge, maxGaps, ppm, isotopeElements)`.
8. `mass_spec.suspect_screening` — params: analysis_names, targets (array of suspect objects with name/mass/rt/formula/SMILES/InChI/fragments...), ppm, sec, ppm_ms2, mzr_ms2, min_cosine_similarity, min_shared_fragments, filtered → map targets into `std::vector<nta::suspect_screening::SuspectQuery>` (struct is in nta_suspect_screening.hpp) then `suspect_screening_impl(nta_data, analyses, suspects, ppm, sec, ppmMS2, mzrMS2, minCosineSimilarity, minSharedFragments, filtered)`.
9. `mass_spec.find_internal_standards` — same targets mapping as #8 → `find_internal_standards_impl(...)` (same params).
10. `mass_spec.correct_matrix_suppression` — params: analysis_names, mp_rt_window, ref_blank_replicate → `nta::correction_algorithms::correct_matrix_suppression_impl(nta_data, mpRtWindow, refBlankReplicate)`.

## Executor contract (mirror `find_features` style)
For every executor:
- `Json executor_name(streamfind::Project &project, const Json &parameters)`.
- Read each snake_case parameter with `.value(name, default)` and validate ranges (throw `streamfind::Error(ErrorCode::InvalidArgument, msg)` on bad input, like find_features does).
- Build the analysis context: reuse/extend `detail::load_analysis_features` so it loads ALL persisted feature columns into each columnar `NTA_FEATURES` buffer (not just the subset currently loaded by load_features_ms1/2 — the processing algorithms read annotation/component/eic/ms1/ms2/filler columns, and the write-back must preserve untouched columns). Also populate `blank_names`/`replicate_names` from MASS_SPEC_ANALYSES (SELECT analysis, blank, replicate ...) onto the object (call the setters/members the class exposes — inspect nta.hpp; if the class lacks setters for blank/replicate, the buffers populated them at construction = blank/replicate per analysis; provide what the `_impl` needs).
  - NOTE: `MASS_SPEC_ANALYSES` has `blank` and `replicate` columns. If `blank_names()`/`replicate_names()` return empty because `load_analysis_features` doesn't read them, EXTEND `load_analysis_features` to also SELECT `blank, replicate` and populate them so the algorithms behave like R. Keep it working for the existing 3 methods too.
- Call the `*_impl`.
- Write back the full persisted feature state: since these algorithms mutate many columns and gap-filling ADDS rows, do a per-analysis DELETE + full INSERT of every current row via `detail::row_sql(project_id, buffer.get_feature(fi))` (like find_features' INSERT loop). For suspect/internal-standard methods, also persist the `suspect_buffers()`/`internal_standard_buffers()` into their own tables ONLY if such tables exist in this branch (check; if not, persist to MASS_SPEC_NTA_FEATURES annotation columns as the algorithm does — inspect the _impl to see where it writes). Keep results consistent with what the algorithm computes.
- Return `Json{{"status","finished"},{"info","..."}}`.

## Registration
In `register.cpp` `register_methods()`, add `else if` branches:
`else if (id == "mass_spec.subtract_blank") executor = processing_methods::subtract_blank;` ... for all 10. Declare all 10 in the .hpp.

## Build + verify (MUST actually compile/link and run tests)
Configure/build the core library + tests via the batch approach on Windows:
vcvarsall x64 then `cmake -G Ninja -DSTREAMFIND_BUILD_TESTS=ON -B build/cmake/default -S .` and `cmake --build build/cmake/default -j 8 --target streamfind_mass_spec` then build+run existing tests. Read core/README/CMakePresets.json. Iterate to zero errors. Then add at least a minimal smoke test under `core/domains/mass_spec/tests/` that runs find_features then a couple of the new methods (e.g. filter_features, create_components, annotate_components) on the basic_tof fixture (tests/data/mass_spec/basic_tof/00_tof_s_is_pos_cent-r001.mzML r002 r003) and asserts non-crash + expected status, mirroring existing `load_features_test.cpp` harness. Build the test target and run it. Report real output.

## Constraints
- Keep algorithm operations intact — only wire them.
- Do not modify vendor/, Rust, semantic/, reader.hpp, nta_deconvolution.cpp.
- No anonymous namespaces in new project code.
- C++20.
