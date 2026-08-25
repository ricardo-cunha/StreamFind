# NTA three-way alignment audit — bindings/r vs core C++ vs Rust

Worktree `rust_nta_extension`. Goal: verify that core C++ and Rust reproduce the
`bindings/r` NTA workflow results, and list every place where outputs are not
aligned. Method: (1) mechanical diffs R↔core with name-swap masking,
(2) constants/logic audit core↔Rust, (3) same quantized wastewater pipeline run
on both backends for empirical counts.

## Hop 1 — R ↔ core C++: ALIGNED (byte-equivalent algorithms)

- Unified diff of `bindings/r/src/core/nta/nta_{alignment,annotation,blank_subtraction,
  componentization,correction_algorithms,filters,gap_filling,suspect_screening,
  deconvolution}.cpp` vs `core/domains/mass_spec/src/nta_*.cpp`, after masking the
  mechanical renames (`MS_FILE`→`MASS_SPEC_FILE`, `MS_TARGETS_SPECTRA`→
  `MASS_SPEC_TARGETS_SPECTRA`, include paths, `.h`→`.hpp`):
  **26 residual changed lines out of ~8 800** — all plumbing (named namespaces per
  AGENTS.md, one include path, one added `ana.select_analysis(analysis_index_at(a))`
  in core deconvolution for multi-analysis files; R is single-analysis only).
- Reader layer: `reader.cpp` differs only by additive SCIEX/WIFF support in core;
  `get_spectra_targets`, spectra-header derivation (TIC), and mzML parsing are the
  same code. So for mzML fixtures R and core consume identical data.
- Wrapper defaults (R6 `class_MethodsNonTargetAnalysis.R`) were previously aligned
  to the executors (fidelity brief); spot-checked again (FillFeatures
  rtExpand=10/mzExpand=0.01/maxPeakWidth=30/minTracesIntensity=1000/
  minNumberTraces=5L matches core and Rust executors).

## Hop 2 — core ↔ Rust: ALIGNED everywhere except Rust find_features

### Verified aligned (constants + semantics)
- Extracted every distinctive numeric literal from the 8 core algorithm files:
  **0 literals missing** in the Rust counterparts. All binary string literals
  (filter reasons, FC/FG names, adducts, isotope entries) present.
- Spot semantic checks (Rust vs core): blank-subtraction max/avg over blanks;
  EIC extraction (identical windows, intensity floor, placeholder noise);
  `filter_features` apply-loop skips already-filtered features and appends reasons
  with a single space (`filter = "a b"`) — matches R/core; NaN=disabled mapping;
  minRelPresenceReplicate `replicate|feature_group` keys; correction TIC profile
  (level 1 only, finite rt/tic, mp=-1.0 fallbacks, `tichri = ((blank/sample)-1)*(-1)`
  and the mp regression); annotation isotope table values; alignment FG naming;
  `merge_nta_feature_spectra` for load_features_ms1/2.

### NOT aligned — Rust `find_features` (processing_methods_nta.rs) vs core
#### nta_deconvolution.cpp
The overall pipeline is the same (per-scan denoise via bin-quantile noise levels →
m/z clustering → zero-crossing peak candidates → valley validation → boundaries →
merge → metrics), and the noise/cluster/validation formulas match (verified:
VectorStats/AdaptiveNoiseParams/bin-assignment/multipliers = Rust noise_levels;
`count > minTraces && snr > minSNR`; candidate + validation rules). Confirmed
value-level divergences:

1. **Peak-boundary max half-width**: Rust `boundaries(..., max_width.min(30.) / 2.)`
   vs core/R `maxWidth / 2.0f`. With max_feature_width=100 this is **15 vs 50**,
   so Rust clips every peak window at ±15 s (RT gap / span checks) and core at
   ±50 s. Changes which peaks survive and every width/rtmin/rtmax, and therefore
   downstream gaussian fits and filters. (The `.min(30.)` is a stale remnant of an
   older executor default.)
2. **Post-merge boundary re-shrink**: after merging overlapping peaks core
   re-walks the merged boundaries and re-truncates to `intensity <= baseline` or
   `<= 1% of apex` (nta_deconvolution.cpp lines 1351-1374); Rust only takes
   min/max of the two boundary sets — merged peaks in Rust keep wider boundaries.
3. **Pre-fit outlier interpolation**: core marks consecutive non-rising (left of
   apex) / non-falling (right of apex) smoothed points and interpolates them
   before `fit_gaussian` (lines 1545-1660); Rust fits the gaussian on the raw
   smoothed profile. Different gaussian_A/mu/sigma/r2 → different
   `r2 > -1` acceptance and different gaussian columns downstream.
4. Minor: baseline window uses the median RT cycle time in core/R vs the first
   RT gap in Rust (equal on regular scan grids, differs when scans are missing);
   cluster cv denominator uses `mean != 0` in core vs `mean.max(1e-8)` in Rust
   (only differs for near-zero means).

**Not a divergence (checked twice):** the merge apex-distance rule —
Rust `apex_distance < (w_i + w_j) * 0.15` equals core `apex_distance < avg_width * 0.3`
(0.15 × sum ≡ 0.30 × mean); valley threshold 0.70 × lower apex identical.

## Empirical (quantized wastewater pipeline, identical parameters in both)

| Step | core C++ | Rust |
| --- | --- | --- |
| features detected | **1693** | **1372** (~ −19%) |
| IS targets parsed | 18 | 18 |
| internal standards found | 14 | **12** |
| internal standards after filter | 12 | **11** |
| feature groups | 1172 | **1023** |
| pipeline status | finished | finished |

Every later step in both stacks reached `status:"finished"`; the count gaps
(features, then IS hits, then groups) all originate inside find_features,
consistent with findings 1-3 (Rust's ±15 s windows and missing
interpolation/re-shrink reject/reshape peaks).

## Recommended fix (Rust only, find_features)

1. `boundaries()`: use `max_width / 2.` (drop `.min(30.)`).
2. Port the core post-merge boundary re-shrink loop (baseline / 1%-apex).
3. Port the core pre-fit outlier interpolation.
4. Baseline window: median RT difference instead of first gap; (optional) cv
   denominator `mean != 0`.
Then re-run the quantized conformance on both stacks and expect feature counts to
converge; add a count-equality assertion (tolerance) to the Rust conformance test.

## RESOLVED (same session)

All four items implemented in `rust/crates/mass-spec/src/processing_methods_nta.rs`
(`find_features`/`make_feature`/`detect`), plus the row-construction alignment
(m/z = mean over FWHM region via `calculate_fwhm_combined`; rt/intensity/feature
name from the allowed-window max position; metrics on the same sources as core).
Quantized wastewater: features 1710 vs C++ 1693; overlap at 10 ppm/5 s rose from
75.1%→91.2% (matched 1030→1544), at 100 ppm 98.3% cpp-covered; matched-pair
|dmz| median 0.001 ppm, |drt| 0.000 s, area ratio 1.000. All 19 Rust tests
green (conformance re-run included). Residual: on the basic_tof strict-params
fixture ([900,925] Metoprolol window) Rust and C++ produce **identical feature
lists** (6 features, same m/z/RT/intensity/SN/width/r2 and names); the only
remaining divergence is ~29 C++-only / ~46 Rust-only borderline peaks in the
wastewater quantized run at 100 ppm.