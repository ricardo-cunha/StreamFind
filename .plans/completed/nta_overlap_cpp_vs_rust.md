# Feature overlap: core C++ vs Rust (quantized wastewater)

DBs: `%TEMP%\streamfind-nta-wastewater-quantized.duckdb` (cpp, 1693) vs
`%TEMP%\streamfind-rust-nta-ww.duckdb` (rust, 1710 after the find_features
alignment fix; 1372 before). Greedy 1:1 matching per (analysis, polarity),
windows (ppm on m/z, 5 s on RT).

## Overlap by tolerance — BEFORE the fix (rust 1372)

| window | matched | cpp-only | rust-only | rust covered |
| --- | --- | --- | --- | --- |
| 10 ppm / 5 s | 1030 | 663 | 342 | 75.1% |
| 25 ppm / 5 s | 1216 | 477 | 156 | 88.6% |
| 100 ppm / 5 s | 1350 | 343 | 22 | 98.4% |

## Overlap by tolerance — AFTER the fix (rust 1710)

| window | matched | cpp-only | rust-only | rust covered | cpp covered |
| --- | --- | --- | --- | --- | --- |
| 10 ppm / 5 s | 1544 | 149 | 166 | 90.3% | 91.2% |
| 25 ppm / 5 s | 1583 | 110 | 127 | 92.6% | 93.5% |
| 100 ppm / 5 s | 1664 | 29 | 46 | 97.3% | 98.3% |

Jaccard 83.1% @10 ppm → 95.7% @100 ppm (was 50.6% / 78.7%).

## Matched-pair agreement (after fix)

|dmz| ppm median **0.001**, p90 0.002, max 5.78 (window-10 run) — effectively
bit-identical centroids (was median 1.9). |drt| median **0.000 s** (max 0.000).
Intensity ratio median 1.000; **area ratio median 1.000** (was 0.90).

## Residual backend-unique (100 ppm): 29 cpp-only / 46 rust-only

Hard-edge detection differences (peak merge/validation decisions on borderline
clusters), both ~50/50 filtered afterwards. Peak detection counts now nearly
equal: cpp 1693 vs rust 1710.

## basic_tof strict-parameter fixture (Metoprolol window [900,925],
minSNR 15, minTraces 5, ppm 12, noise 500, maxWidth 60, baseQuantile 0.1)

Rust and C++ now produce **identical feature lists** (6 features: r002×3 +
r003×3; r001 adds none, C++ fills it later): same m/z to 4 decimals
(293.0713 / 268.1923 / 269.1953 / 293.0713 / 315.0529≈315.0530 / 275.2362),
same RT, intensity, S/N, width, gaussian_r2, and identical feature names
(CL74_PK7_MZ293_RT906_POS …). Confirmed by dumping both sides from DuckDB.

## What changed (Rust find_features only)

1. Peak boundary half-width: `max_width/2` (was `min(max_width,30)/2`).
2. Post-merge boundary re-shrink to baseline / 1% of apex (ported).
3. Pre-fit outlier interpolation + fit on corrected profile + corrected apex
   initialisation (ported).
4. Row construction aligned: m/z = mean over FWHM region (`calculate_fwhm_combined`),
   rt/intensity/name from the allowed-window max position, metrics on the same
   sources as core; baseline window uses median RT cycle time; cv denominator
   `mean != 0`.