# SCIEX WIFF Reader Implementation Plan

> **Scope:** Native SCIEX WIFF/WIFF.SCAN reading in C++ and Rust, with multi-analysis project integration.

**Goal:** Read SCIEX container files natively, expose one logical analysis per contained acquisition, populate the existing mass-spectrometry reader structures, and persist each logical analysis in `MASS_SPEC_ANALYSES` without requiring Clearcore, ProteoWizard, or mzML at runtime.

**Agreed native support scope:** prioritize the validated PAC compact-MRM family, the `201209_MM_2` multi-experiment compact-MRM family, Nitrosamine sparse-tagged MRM, and the supplied TOF spectrum family. Mix1 remains deferred because its transition assignment is unresolved. Native production code must remain independent of Clearcore, ProteoWizard, msconvert, and mzML.

**Architecture:** A physical WIFF file is treated as a container of logical analyses. Each analysis has a normalized zero-based `analysis_index`, a vendor `source_analysis_number`, a source analysis name, and an `analysis_count`. Existing single-analysis formats expose one logical analysis at index `0`. The C++ and Rust readers will use the same decoded data model and the existing spectrum/chromatogram-facing interfaces.

**Primary fixtures:**

```text
E:\example_files\raw_vendor_files\sciex\250414_Mix1.wiff
E:\example_files\raw_vendor_files\sciex\250414_Mix1.wiff.scan

E:\example_files\raw_vendor_files\sciex\220511_Nitrosamine_M220426_M220503_Vierlinden.wiff
E:\example_files\raw_vendor_files\sciex\220511_Nitrosamine_M220426_M220503_Vierlinden.wiff.scan
```

**Additional validation fixtures used by the worktree:**

```text
E:\example_files\raw_vendor_files\sciex\201023_Pac.wiff
E:\example_files\raw_vendor_files\sciex\201023_Pac.wiff.scan

E:\example_files\raw_vendor_files\sciex\201209_MM_2.wiff
E:\example_files\raw_vendor_files\sciex\201209_MM_2.wiff.scan

E:\example_files\raw_vendor_files\sciex\tof\220104_1_1.wiff
E:\example_files\raw_vendor_files\sciex\tof\220104_1_1.wiff.scan

E:\example_files\raw_vendor_files\sciex\as_mzML\
E:\example_files\raw_vendor_files\sciex\as_mzMl_direct_no_peck_picking\
```

These paths are local development-fixture paths only. They must not be embedded in production source, installed into the package, or required by default builds.

**CMake fixture variables used for local C++ validation:**

```text
STREAMFIND_SCIEX_WIFF_FIXTURE
    → Mix1 or another single-fixture SCIEX smoke test

STREAMFIND_SCIEX_MULTI_WIFF_FIXTURE
    → E:\example_files\raw_vendor_files\sciex\201209_MM_2.wiff

STREAMFIND_SCIEX_NITRO_WIFF_FIXTURE
    → E:\example_files\raw_vendor_files\sciex\220511_Nitrosamine_M220426_M220503_Vierlinden.wiff
```

Example local configuration commands, run from the repository root with the C++ source directory as the CMake source:

```text
cmake -S core -B build-sciex-multi-vs \
  -DSTREAMFIND_SCIEX_MULTI_WIFF_FIXTURE=E:/example_files/raw_vendor_files/sciex/201209_MM_2.wiff

cmake -S core -B build-sciex-nitro-vs \
  -DSTREAMFIND_SCIEX_NITRO_WIFF_FIXTURE=E:/example_files/raw_vendor_files/sciex/220511_Nitrosamine_M220426_M220503_Vierlinden.wiff
```

The test targets are conditionally created only when the selected fixture variable is nonempty and the path exists:

```text
streamfind_mass_spec_sciex_reader_tests
streamfind_mass_spec_sciex_multi_reader_tests
streamfind_mass_spec_sciex_nitro_reader_tests
```

**Validation oracles:**

```text
sciex\as_mzML\
sciex\as_mzMl_direct_no_peck_picking\
```

The second dataset has 67 analyses, 35 SRM chromatograms plus one pump chromatogram, and matching peak-picked/non-peak-picked mzML files. The first dataset has 37 analyses, 59 SRM chromatograms plus TIC, BPC, and pump traces.

**Development reference for SCIEX TOF parsing:**

```text
https://github.com/Sigilweaver/OpenSXRaw/tree/main
```

OpenSXRaw is a development-time format reference and differential-validation aid for WIFF/TOF structures. It is not a StreamFind runtime dependency and must not be copied into `core/vendor/` without an explicit decision.

---

## Current implementation checkpoint

- [x] WIFF compound-file detection in C++.
- [x] `.wiff.scan` companion discovery.
- [x] Sample-block discovery using `0x11111111` markers.
- [x] Variable sample counts observed: 37 and 67.
- [x] Analysis schema fields added: `analysis_index`, `source_analysis_number`, `analysis_count`.
- [x] Duplicate logical-analysis rejection added to C++ and Rust `add_analyses` paths.
- [x] Task 1 complete: normalized analysis catalog exposed by C++ and Rust readers; single-analysis formats return index `0`, count `1`.
- [x] Task 2 complete: selected-analysis state, index-0 selection, and out-of-range validation added to C++ and Rust readers.
- [x] Task 3 complete: C++ and Rust extract WIFF source analysis names from `SampleDABE/DATA` and dispatch WIFF files to a multi-analysis catalog.
- [x] Task 4 partial: variable transition metadata, collision energy, and per-analysis timing implemented in C++ and Rust.
- [x] Task 5 partial: lossless `-59.01` event records and intensity groups implemented in C++ and Rust for the Mix1 scan grammar.
- [x] Native indexed scan foundation: `SampleN/Idx` record parsing and byte-token payload decoding added to C++ and Rust, based on OpenSXRaw's clean-room format work.
- [x] Phase 1 complete: indexed records and token decoding compile and pass real-fixture tests.
- [ ] Phase 2 active: selected-analysis adapter and SRM chromatogram emission.
- [x] Phase 2a partial: MRM `Idx` records are now read as indexed float fragments without discarding small sizes; Mix1 yields 3421 fragments.
- [x] Phase 2a diagnostic: `Idx` offsets are sample-local; adding the SampleN `.wiff.scan` block base resolves the apparent coverage mismatch. Sample4 base `334680` plus indexed fragments reconstructs the MRM payload and 3425 `-59.01` markers; the two remaining markers are outer-boundary artifacts.
- [x] Phase 2a complete: no additional Sample4 stream or interleaved hidden payload is required for the indexed MRM data.
- [ ] Phase 2b active: aggregate indexed MRM float fragments into transition/TIC/BPC series.
- [ ] Phase 2b: map raw MRM payloads to method transitions and emit time/intensity series.
- [ ] Phase 2c: expose C++ and Rust chromatograms through existing reader interfaces.
- [ ] Phase 2d: validate TIC/BPC and all transition series against Clearcore/mzML development oracles.
- [x] Phase 2b partial: indexed MRM fragments now aggregate into retention-time-bearing event records in C++ and Rust.
- [ ] Phase 2b remaining: assign event intensity groups to the 59/35 transition order and derive TIC/BPC.
- [x] Clearcore timing investigation: `MSExperiment.GetRTFromExperimentScanIndex(i)` and `GetRTFromExperimentCycle(i)` both expose the exact MRM scan-index relation; scan index `0..3420` maps to Clearcore RT `0.7005..7.7000` minutes for Mix1 sample 4.
- [x] Cross-sample timing check: all 37 Mix1 samples show the same MRM `Idx` timing basis (`~7.1413..9.7624`) while Clearcore reports `~0.7005..7.7002`; Sample4 is not corrupt and the discrepancy is systematic.
- [x] Additional MRM timing check: `201209_MM_2.wiff` has 74 samples, 10 MRM transitions, 1700 `Idx` records, and 1700-point mzML chromatograms, while Clearcore reports 800 experiment scans for its first sample; MRM indexed records and Clearcore scan counts are not universally one-to-one.
- [x] Multi-experiment MRM finding: `201209_MM_2-0.1.mzML` contains two valid MRM experiments in one analysis: 10 transitions from `0.0..1.99975` minutes and 4 transitions from `2.0023..3.8013` minutes. The post-2-minute TIC/BPC segment is associated with the second MRM experiment, not an irrelevant artifact.
- [x] Clearcore experiment-count reconciliation: `201209_MM_2` sample 1 reports experiment 0 = 800 scans/10 transitions and experiment 1 = 900 scans/4 transitions; `800 + 900 = 1700` indexed/mzML chromatogram points.
- [x] Controlled PAC fixture inventory: `201023_Pac.wiff` contains a one-experiment, two-transition MRM method (`Pac 569`, `Pac 286`) with 1091-point mzML chromatograms, but its indexed payload has no `-59.01` markers and uses a separate compact float-record encoding.
- [x] PAC compact-record rule: each sample has a 24-byte block header followed by 1091 two-float indexed records; after skipping the first three header records, field 0 is `Pac 569` intensity and field 1 is `Pac 286` intensity, matching Clearcore SRM traces exactly by record order.
- [x] PAC decoder added to C++ and Rust as `read_compact_mrm_pairs(...)`.
- [x] Native PAC time fallback: when PAC has no transition RT window, prepend the three header-aligned zero points and construct a regular 110 ms/cycle grid from the native 50 ms dwell and two-transition method.
- [ ] Native PAC time fallback validation: compare the approximate grid against vendor/ Clearcore timing and expose its approximation status in reader metadata.
- [x] Scheduling interpretation confirmed from MultiQuant and `sMRMPro_adw_Times`: the displayed transition RT is the scheduled expected RT, calculated as `(start_time + end_time) / 2`; e.g. Mix1 `1H-Benzotriazol_1` → `2.04 min` and `Amisulprid_1` → `2.23 min`.
- [ ] Phase 2b refinement: use each transition's scheduled start/end window as chromatogram metadata and reconstruct its point time axis over that window; do not use the MRM `Idx` clock field as the transition chromatogram RT axis.
- [x] Common MRM series model added in C++ and Rust with per-transition time arrays and intensity arrays.
- [x] PAC compact pair builder added; it validates two channels and constructs per-transition scheduled-window time arrays.
- [x] PAC/201209 series wired into the public `MASS_SPEC_READER`/Rust `Reader` chromatogram collections.
- [x] PAC public wiring: Rust `Reader::chromatograms()` and the C++ `Sciex` factory adapter now expose TIC, BPC, and the two PAC SRM chromatograms with precursor/product metadata.
- [x] 201209 public wiring: expose both experiment-specific compact MRM series through the C++ and Rust public readers using payload-width and method-period dispatch; no fixture filename checks are used in production.
- [x] C++ public-reader validation: dedicated real-fixture smoke test confirms 16 chromatograms, 1700-point combined TIC/BPC, and 800/900-point experiment transition arrays for the multi-experiment compact MRM fixture.
- [x] Nitrosamine grammar classification: unscheduled/full-run acquisition is supported as a sparse tagged grammar; variable-width payload assignment is decoded via fragment concatenation and `-33.01` records.
- [x] Nitrosamine sample-block boundary variant: timing streams with no two-header-pair prefix are now accepted; selected C++ analyses recreate the SCIEX reader for their source sample.
- [x] Nitrosamine sparse `-33.01` decoder validated against 33 mzML SRM traces and connected to the C++ public reader; final-record outer-boundary tail remains documented.
- [ ] Phase 2b refinement: parse all per-period/per-experiment `MassRangeEx` transition lists and preserve experiment boundaries when assigning indexed MRM groups.
- [ ] Native timing investigation: determine the MRM-specific nonlinear scan-index-to-RT source; OpenSXRaw's direct `Idx`-RT rule is valid for its tested spectrum corpus but cannot yet be applied to this MRM variant.
- [x] Scope decision: prioritize PAC compact MRM, `201209_MM_2` multi-experiment MRM, and TOF native support; defer Mix1 and unresolved Nitrosamine grammars with explicit unsupported diagnostics.
- [ ] Unsupported-grammar diagnostics: identify payload family and report file/sample/experiment/transition-count context without silently falling back to mzML or Clearcore.
- [ ] Phase 3 active track: native TOF WIFF spectrum reader.
- [x] Phase 3 fixture inventory: `220104_1_1.wiff` has one sample, 47,491 Idx records, 8,964 mzML spectra, and 2 mzML chromatograms.
- [ ] Phase 3a: parse TOF `Idx` records including zero-size continuation/placeholder records and map non-empty records to spectrum boundaries.
- [ ] Phase 3b: decode TOF byte-token spectra using sample-local block offsets and instrument calibration streams.
- [ ] Phase 3c: parse TOF experiment/method metadata, MS level, polarity, precursor information, and calibrated m/z arrays.
- [ ] Phase 3d: expose TOF spectra through the existing C++ and Rust reader interfaces and validate against `220104_1_1-vorl1.mzML`.
- [ ] Task 4 remaining: selected-analysis reader adapter and correct handling of MRM `Idx` records whose small sizes do not represent standalone spectrum blocks.
- [ ] Task 5 remaining: map decoded indexed payloads to the requested SRM chromatogram series and validate physical m/z calibration.
- [ ] C++ `SciexReader : MASS_SPEC_READER` implementation.
- [ ] Rust `reader_sciex.rs` implementation.
- [ ] Complete event-group-to-transition assignment.
- [ ] TIC/BPC derivation from decoded SRM traces.
- [ ] Pump chromatogram decoding.
- [ ] WIFF source analysis-name extraction.
- [ ] Multi-analysis expansion in `add_analyses`.
- [ ] Persisted reads selecting `file_path + analysis_index`.

---

## Phase 1: Reader contracts and analysis catalog

### Task 1: Define the normalized analysis catalog

**Files:**
- Modify: `core/domains/mass_spec/include/streamfind/mass_spec/reader.hpp`
- Modify: `rust/crates/mass-spec/src/reader.rs`
- Test: `core/domains/mass_spec/tests/reader_sciex_smoke.cpp`
- Test: `rust/crates/mass-spec/tests/reader.rs`

Add equivalent models:

```text
analysis_index: zero-based logical analysis index
source_analysis_number: vendor/container number
source_analysis_name: vendor analysis name
analysis_count: number of analyses in the physical source
```

Single-analysis formats must return exactly one catalog entry with index `0` and count `1`.

**Verification:** Existing mzML, mzXML, LCD, and ASC tests continue to open with one catalog entry.

### Task 2: Add selected-analysis state

**Files:**
- Modify: `core/domains/mass_spec/include/streamfind/mass_spec/reader.hpp`
- Modify: `core/domains/mass_spec/src/reader.cpp`
- Modify: `rust/crates/mass-spec/src/reader.rs`
- Test: reader integration tests

Add a selection boundary without changing existing chromatogram/spectrum method signatures:

```cpp
file.select_analysis(index);
file.get_chromatograms_headers();
file.get_chromatograms();
```

Reject out-of-range indexes with a clear `InvalidArgument`/reader error.

**Verification:** Selecting index `0` on single-analysis formats succeeds; selecting any other index fails.

### Task 3: Extract WIFF source analysis names

**Files:**
- Modify: `core/domains/mass_spec/src/reader_sciex.cpp`
- Modify: `core/domains/mass_spec/include/streamfind/mass_spec/reader_sciex.hpp`
- Create/modify: `rust/crates/mass-spec/src/reader_sciex.rs`
- Test: real WIFF catalog tests

Inspect WIFF sample metadata and expose source names. Do not derive source names from chromatogram IDs when a WIFF metadata name is available. Use a deterministic fallback only when the source name is genuinely absent:

```text
sample_<source_analysis_number>
```

**Verification:** Catalog count and source numbers match 37 and 67 sample containers; names are stable across repeated reads.

---

## Phase 2: Native event and schedule decoding

### Task 4: Generalize transition metadata parsing

**Files:**
- `core/domains/mass_spec/src/reader_sciex.cpp`
- `core/domains/mass_spec/include/streamfind/mass_spec/reader_sciex.hpp`
- `rust/crates/mass-spec/src/reader_sciex.rs`

Parse variable transition counts. Do not hardcode 59. Extract:

```text
transition index
name
precursor m/z
product m/z
collision energy
start time
end time
```

Read per-analysis timing from:

```text
SampleSubtree/SampleN/SampleDAM/sMRMPro_adw1/sMRMPro_adw_Times
```

**Verification:**

- Mix1: 59 SRM transitions.
- Nitrosamine: 35 SRM transitions.
- Timing windows match the mzML chromatogram time ranges within tolerance.

### Task 5: Implement lossless event parsing in both languages

**Files:**
- `core/domains/mass_spec/src/reader_sciex.cpp`
- `core/domains/mass_spec/include/streamfind/mass_spec/reader_sciex.hpp`
- `rust/crates/mass-spec/src/reader_sciex.rs`
- Tests in both reader test suites.

Parse each `-59.01` event into:

```text
ordinal
field groups
field code
positive values
terminators
```

Preserve unknown fields rather than dropping them. The parser must support variable-length records and `-58.01` sparse sections.

**Verification:** Event counts and known event shapes match both WIFF fixtures.

### Task 6: Map payload series to chromatograms using method order and timing metadata

**Files:**
- Sciex C++ and Rust reader modules.
- Decoder tests.

Do not reconstruct the complete active-transition schedule or auxiliary acquisition state. The requested output only requires independent chromatogram series. Use the method records to associate each payload series with its transition metadata and use `sMRMPro_adw_Times` (or the equivalent variant-specific timing stream) to build its time axis.

For each emitted chromatogram, recover only:

```text
chromatogram id/name
precursor m/z
product m/z
time array
intensity array
```

Ignore auxiliary fields that cannot be mapped to an output chromatogram. Use transition order, series lengths, and timing records to validate assignment; do not use mzML at runtime.

**Verification:** Known event groups map to the expected transition pairs, and each output series matches the corresponding mzML time/intensity arrays within tolerance.

### Task 7: Classify auxiliary fields structurally

**Files:**
- Sciex decoder modules.
- Decoder tests.

Do not use arbitrary intensity thresholds. Classify a group as chromatographic only when its field context and group length fit active scheduled transitions. Preserve unsupported auxiliary records for diagnostics.

Test patterns including:

```text
-48.01, [3981243]
-22.01, [68, 1155]
-14.01, [3245, 113]
```

**Verification:** Auxiliary values never appear in emitted SRM intensity arrays.

### Task 8: Reconstruct transition time axes

**Files:**
- Sciex C++ and Rust decoder modules.

For each transition, collect values and emit a time axis using the per-analysis method timing pair and the recovered point count. Account for sparse scheduled acquisitions and zero-valued points.

**Verification:** Compare all transition time arrays against corresponding mzML arrays for samples from both WIFF files. Use a documented absolute tolerance for floating-point time values.

---

## Phase 3: C++ reader implementation

### Task 9: Implement `SciexReader : MASS_SPEC_READER`

**Files:**
- Create/modify: `core/domains/mass_spec/include/streamfind/mass_spec/reader_sciex.hpp`
- Create/modify: `core/domains/mass_spec/src/reader_sciex.cpp`
- Modify: `core/domains/mass_spec/src/reader.cpp`
- Modify: `core/domains/mass_spec/CMakeLists.txt`

Implement the complete existing reader contract. The selected analysis must determine the decoded sample block.

Required output:

```text
59 SRM + TIC + BPC + pump for Mix1
35 SRM + pump for Nitrosamine
```

Populate `MASS_SPEC_CHROMATOGRAMS_HEADERS` and chromatogram arrays. Return zero spectra for these MRM fixtures unless a full-scan experiment is detected.

Connect:

```cpp
create_reader(path)
```

to the Sciex backend.

**Verification:** `MASS_SPEC_FILE` opens both WIFF files, selects each analysis, and returns expected chromatogram counts.

### Task 10: Derive TIC and BPC

**Files:** C++ Sciex reader implementation and tests.

Derive:

```text
TIC = sum of active SRM transition intensities
BPC = maximum active SRM transition intensity
```

Do not depend on the raw `-38.01` subset as a complete TIC/BPC source.

**Verification:** Compare TIC/BPC arrays against mzML for multiple analyses from both containers.

### Task 11: Decode pump chromatograms

**Files:** C++ Sciex reader implementation and tests.

Identify the pump/LC trace event family and emit the final chromatogram with correct channel, units, time, and intensity arrays.

**Verification:** Chromatogram count and pump trace metadata match mzML.

---

## Phase 4: Rust reader implementation

### Task 12: Add `reader_sciex.rs`

**Files:**
- Create: `rust/crates/mass-spec/src/reader_sciex.rs`
- Modify: `rust/crates/mass-spec/src/reader.rs`
- Modify: `rust/crates/mass-spec/src/lib.rs`
- Test: `rust/crates/mass-spec/tests/reader.rs`

Mirror the C++ data model and decoder behavior without using Clearcore, ProteoWizard, or runtime mzML conversion.

Add WIFF detection and reader dispatch. Avoid changing existing reader behavior for current formats.

**Verification:** Rust WIFF open/catalog/selection tests pass for both raw containers.

### Task 13: Match C++ and Rust decoder behavior

**Files:** C++/Rust Sciex modules and integration tests.

Use shared fixture assertions for:

```text
analysis count
source analysis number
transition count
chromatogram count
transition metadata
array lengths
retention-time arrays
TIC/BPC arrays
pump trace
```

**Verification:** C++ and Rust outputs agree within documented numeric tolerances.

---

## Phase 5: Project integration

### Task 14: Expand `add_analyses` for containers

**Files:**
- `core/domains/mass_spec/src/mass_spec.cpp`
- `rust/crates/mass-spec/src/lib.rs`
- Project tests in C++ and Rust.

For a single-analysis path, insert one row:

```text
analysis_index = 0
analysis_count = 1
source_analysis_number = NULL
```

For a WIFF path without an explicit selector, insert one row per catalog entry:

```text
<file_stem>::<source_analysis_name>
```

Support an optional `analysis_index` selector for importing only one contained analysis.

Return one result entry per logical analysis.

**Verification:** Importing one WIFF creates 37 or 67 rows; importing an mzML creates one row.

### Task 15: Enforce project-level analysis uniqueness

**Files:** C++/Rust project layers and tests.

Reject duplicate logical analysis names within:

- an existing project;
- one request;
- one container.

Do not use `INSERT OR REPLACE` for new logical analyses.

**Verification:** Duplicate import fails without modifying the existing row.

### Task 16: Update all persisted read paths

**Files:**
- `core/domains/mass_spec/src/mass_spec.cpp`
- `rust/crates/mass-spec/src/lib.rs`
- Related feature/processing paths.

Every read must use:

```text
file_path + analysis_index
```

This includes:

- spectra headers;
- chromatogram headers;
- raw spectra;
- raw chromatograms;
- feature detection;
- target extraction;
- NTA/processing helpers.

**Verification:** Selecting two analyses from the same WIFF returns different chromatogram data and timestamps.

### Task 17: Update semantic metadata and generated projection

**Files:**
- `semantic/ontology/domains/mass_spec/columns.ttl`
- `semantic/ontology/domains/mass_spec/tables.ttl`
- Generated projection if required.

Document the three analysis-container columns and the normalized zero-based index semantics.

**Verification:**

```powershell
.venv\Scripts\python.exe semantic\validate_semantic.py
.venv\Scripts\python.exe semantic\generate_projection.py --check
```

---

## Phase 6: Final validation

### Task 18: C++ real-fixture integration tests

Validate:

```text
Mix1 sample indexes 0, 9, 28
Nitrosamine sample indexes 0, 1, and a late analysis
```

Check chromatogram arrays against the paired mzML files.

### Task 19: Rust real-fixture integration tests

Repeat the C++ assertions in:

```text
rust/crates/mass-spec/tests/reader.rs
```

Run:

```powershell
cargo test -p streamfind-rust-mass-spec
```

### Task 20: Project-level container tests

Test:

- importing one mzML;
- importing one WIFF with automatic expansion;
- importing one WIFF with an explicit analysis index;
- selecting two analyses sharing one physical path;
- duplicate logical-analysis rejection;
- persisted chromatogram reads selecting the correct analysis.

### Task 21: Final quality gates

Run:

```powershell
git diff --check
cargo test -p streamfind-rust-mass-spec
.venv\Scripts\python.exe semantic\validate_semantic.py
.venv\Scripts\python.exe semantic\generate_projection.py --check
```

Build the C++ targets through the Visual Studio developer environment with duplicate MSYS `TMP/tmp` variables removed.

Completion requires the real WIFF tests to pass through the public C++ and Rust reader interfaces, not only through low-level decoder helpers.

---

## Current implementation handoff

This section records the state for the next agent. The immediate priority is the base reader and project analysis-container framework; deeper SCIEX MRM and TOF refinement is intentionally deferred unless required to keep the base interfaces building and tested.

### Base C++ reader and project integration

Implemented in:

```text
core/domains/mass_spec/include/streamfind/mass_spec/reader.hpp
core/domains/mass_spec/src/reader.cpp
core/domains/mass_spec/src/mass_spec.cpp
```

Current behavior:

- `MASS_SPEC_ANALYSIS` carries `analysis_index`, `source_analysis_number`, `name`, and `analysis_count`.
- `MASS_SPEC_FILE` exposes `get_analysis_catalog()`, `select_analysis(index)`, and `selected_analysis_index()`.
- Single-analysis formats normalize to index `0`, count `1`.
- SCIEX WIFF catalogs are expanded from `.wiff.scan` sample blocks.
- SCIEX project analysis names use `<file_stem>::<source_analysis_name>`.
- C++ project ingestion accepts `.wiff`, expands one physical WIFF into one persisted row per logical analysis, and persists the normalized analysis fields.
- Project-level spectra/chromatogram header and raw-read paths select the persisted `analysis_index` before reading the file.
- The SCIEX factory accepts an explicit source-analysis number when reopening a selected logical analysis.

Important integration caveat: the current main-branch code may have changed `reader.cpp`, `reader.hpp`, `mass_spec.cpp`, and the project CMake files. Reconcile those files against the main branch before committing; do not blindly overwrite newer main-branch work.

### Base Rust reader and project integration

Implemented in:

```text
rust/crates/mass-spec/src/reader.rs
rust/crates/mass-spec/src/lib.rs
rust/crates/mass-spec/tests/reader.rs
```

Current behavior:

- Rust `Analysis` mirrors the C++ normalized analysis model.
- `Reader::analysis_catalog()`, `select_analysis(index)`, and `selected_analysis_index()` are public.
- Selecting a SCIEX analysis reloads its chromatograms from the same physical path and the selected source analysis number.
- Rust `add_analyses()` expands a SCIEX catalog and persists one row per logical analysis with `analysis_index`, `source_analysis_number`, and `analysis_count`.
- Project-level Rust reader operations select the persisted analysis index before returning spectra or raw chromatograms.
- Rust `Chromatogram` retains `id`, `precursor_mz`, `product_mz`, `activation_ce`, `start_time`, and `end_time` so the output matches `MASS_SPEC_CHROMATOGRAMS_HEADERS` and the R/DuckDB contract.

Rust tests belong only under:

```text
rust/crates/mass-spec/tests/
```

Do not move SCIEX tests into implementation modules.

### SCIEX implementation currently present

New native SCIEX files:

```text
core/domains/mass_spec/include/streamfind/mass_spec/reader_sciex.hpp
core/domains/mass_spec/src/reader_sciex.cpp
rust/crates/mass-spec/src/reader_sciex.rs
```

The implementation currently contains:

- OLE/compound-file stream access;
- `.wiff.scan` companion discovery;
- sample-block discovery using `0x11111111` headers;
- WIFF source-name extraction from `SampleDABE/DATA`;
- `Idx` record parsing with sample-local offsets and sample-block base offsets;
- method transition parsing, precursor/product m/z, collision energy, and timing-stream layout handling;
- normalized selected-analysis reopening;
- PAC compact two-float MRM decoding;
- `201209_MM_2` variable experiment-width compact decoding (`10` channels followed by `4` channels in the validated fixture);
- Nitrosamine sparse tagged decoding using concatenated indexed fragments, `-33.01` record markers, and `-N.01` zero-channel skips;
- TIC/BPC derivation and chromatogram header metadata;
- C++ and Rust public chromatogram adapters for the currently validated MRM families.

Do not add filename checks or fixture-specific branches to production readers. Fixtures and expected counts belong in tests only.

### Validated evidence and current limitations

PAC:

```text
3 header-aligned records + 1088 compact two-float records = 1091 points
field 0 and field 1 match the two Clearcore SRM traces
```

`MassRangeExEx` does not provide the PAC chromatogram time vector. The current native fallback uses an explicitly approximate regular grid derived from the native method fill/dwell metadata. Do not present this grid as vendor-exact timing.

`201209_MM_2`:

```text
experiment 0: 800 records × 10 channels
experiment 1: 900 records × 4 channels
```

The combined TIC/BPC output has 1700 points, while each transition chromatogram retains its experiment-specific point count.

Nitrosamine:

```text
sample-dependent sparse tagged payload
one -33.01 marker per indexed point
fragment concatenation is required before record splitting
```

The selected sample-9 differential comparison has 33 SRM traces and 3366 points. The sparse decoder matches the mzML intensity values for all complete records; the final outer-fragment boundary has five unresolved trailing values. The file's timing stream also has a different layout: `16 + transition_count * 8` bytes rather than the Mix1 two-header-pair layout.

Mix1 remains deferred. Its `-59.01` event grammar and transition assignment are not sufficiently generalized for production output. Do not re-enable it through heuristic mapping.

### Clearcore, msconvert, and vendor DLL guidance

Installed Clearcore/SCIEX DLLs and an installed ProteoWizard `msconvert` are acceptable only as development-time diagnostic or differential-validation tools:

```text
native reader implementation
    ↔ Clearcore API result
    ↔ msconvert/mzML result
```

Permitted uses include:

- obtaining per-scan/per-cycle retention times;
- exporting transition chromatograms and metadata for comparison;
- checking TIC/BPC derivation;
- determining whether a WIFF payload family has one or more experiments;
- investigating calibration and TOF spectrum boundaries.

They must not be:

- linked into the production C++ or Rust reader;
- invoked at runtime as a fallback;
- vendored or copied into the repository;
- used to silently convert WIFF to mzML during public operations.

If a diagnostic oracle is used, record the exact input fixture, API/command, output path, and comparison result in the plan or a test-only helper. Keep diagnostic scripts outside production source trees.

### Alternative installed-DLL API scenario: diagnostic host only

There is a useful alternative development architecture in which the installed Clearcore/SCIEX assemblies are treated as the primary **diagnostic API** for reverse engineering, while the StreamFind native reader remains the production implementation.

```text
diagnostic host process
    → load installed Clearcore/SCIEX assemblies
    → open WIFF/WIFF.SCAN through the vendor API
    → enumerate samples, periods, experiments, transitions, scans, RTs
    → export a stable neutral trace/metadata report

native StreamFind reader
    → parse the same WIFF/WIFF.SCAN independently
    → compare its result with the diagnostic report
```

The diagnostic host may use the vendor API as the main API for understanding a SCIEX file. It can be a small C# program, a separate native executable, or another process that emits CSV/JSON/NPZ fixtures. It should not be loaded into the StreamFind production process.

The most valuable diagnostic export should include stable, explicit records such as:

```text
physical_file
source_analysis_number
analysis_index
period
experiment
scan_index
cycle_index
retention_time_minutes
chromatogram_id
transition_index
precursor_mz
product_mz
collision_energy
intensity
```

For each diagnostic run, record:

```text
exact input WIFF path
Clearcore/SCIEX assembly names and versions
host architecture (x86/x64)
API calls used
output file path
output schema/version
native-vs-oracle comparison result
```

This approach is appropriate for:

- discovering the true scan-index/cycle-to-RT mapping;
- distinguishing periods and experiments inside one logical analysis;
- identifying whether a field is a transition intensity, auxiliary value, or boundary marker;
- checking vendor handling of unusual sample-block variants;
- generating regression fixtures for native C++ and Rust tests.

It is not a production Clearcore backend. The native reader must still own the final WIFF/WIFF.SCAN decoding path and must emit an explicit unsupported diagnostic when a grammar has not been implemented.

### Installed msconvert/ProteoWizard DLL scenario

An installed ProteoWizard/msconvert directory may contain format readers, vendor bridges, managed/native interop libraries, calibration helpers, and shared dependencies for formats such as:

```text
mz5
vendor .d directories
other vendor RAW/container formats
```

Those libraries can be useful in a separate conversion/diagnostic process:

```text
installed msconvert process or wrapper
    → open one vendor file
    → export mzML/mz5 or a focused trace report
    → compare against native StreamFind output
```

This can be much faster than reverse engineering every format from scratch during development, especially when the goal is to obtain:

- spectrum/chromatogram counts;
- scan and retention-time arrays;
- transition metadata;
- calibrated m/z values;
- TIC/BPC and vendor auxiliary traces;
- a known-good result for differential tests.

The installed msconvert directory must not be treated as a stable SDK merely because DLLs are present. Before using a library directly, verify:

1. the supported public API and its license;
2. x86/x64 and runtime-library compatibility;
3. whether the DLL is a public redistributable component or an internal implementation detail;
4. required native/managed dependencies and search-path behavior;
5. version-specific behavior and output reproducibility;
6. whether the input format requires vendor software or a licensed vendor bridge.

Prefer invoking the installed `msconvert` executable or a documented public wrapper over loading internal DLLs directly. Direct DLL loading is more fragile because of undocumented symbols, global initialization, dependency resolution, COM/runtime requirements, and version-coupled ABIs.

For development, the recommended abstraction is a process-level oracle adapter:

```text
OracleRunner
    input path
    requested output kind
    tool/version identity
    deterministic output path
    structured result + stderr/stdout log
```

Examples of permitted use:

```text
native mz5 reader
    ↔ msconvert-generated mzML/mz5 arrays

native vendor-D reader
    ↔ msconvert/vendor-bridge spectra and chromatograms

native SCIEX reader
    ↔ Clearcore/SCIEX API traces
    ↔ msconvert-generated mzML traces
```

The oracle output should be checked into neither production source nor generated runtime data. Store only small, reviewable diagnostic reports or test fixtures where repository policy permits. Large converted files should remain in external fixture storage.

### Why this remains separate from production

Using installed vendor/ProteoWizard components as the primary API for production would introduce:

- deployment requirements outside the StreamFind package;
- licensing and redistribution uncertainty;
- architecture and native-runtime coupling;
- non-deterministic version-dependent behavior;
- inability to support Linux/macOS or clean environments consistently;
- hidden conversion/fallback paths that can silently produce incorrect data;
- difficulty reproducing failures when a user's installed DLL set differs.

Therefore the project may use these components to accelerate format discovery and validation, but public StreamFind operations must follow:

```text
public operation
    → native C++/Rust reader
    → explicit supported/unsupported result
```

and never:

```text
public operation
    → Clearcore/msconvert DLL
    → implicit conversion
    → silently returned data
```

### OpenSXRaw TOF development reference

Use this repository as a clean-room development reference for SCIEX TOF/WIFF structures:

```text
https://github.com/Sigilweaver/OpenSXRaw/tree/main
```

Relevant clues include sample-local `Idx` handling, byte-token spectrum payloads, and retention-time/calibration concepts. Verify every inferred rule against StreamFind fixtures; do not assume OpenSXRaw's direct `Idx` retention-time interpretation applies to every MRM family.

### Next handoff priorities

1. Reconcile `reader.hpp`, `reader.cpp`, `mass_spec.cpp`, Rust `reader.rs`, and Rust `lib.rs` with the modified main branch.
2. Add focused project-level tests proving WIFF expansion, duplicate-name rejection, persisted `file_path + analysis_index` reopening, and raw chromatogram selection.
3. Keep the current native SCIEX decoders compiling while the base interface is reconciled.
4. Defer Mix1 refinement and native TOF decoding until the base reader/container merge is stable.


## Risks and decisions

- WIFF analysis names may be stored in a vendor-specific metadata structure; fallback names must be deterministic and tested.
- Field codes are not globally stable transition IDs; assignment must use schedule context.
- TIC/BPC should be derived from decoded SRM data for these MRM files.
- The pump trace is a separate signal family and must not be mistaken for an SRM transition.
- Peak picking is not part of the native parser contract; the supplied 67 paired conversions have identical chromatogram arrays with and without peak picking.
- The parser must reject unsupported acquisition layouts clearly rather than emit guessed chromatograms.
- The existing reader interfaces should remain compatible for single-analysis formats while gaining a separate catalog/selection boundary for containers.
