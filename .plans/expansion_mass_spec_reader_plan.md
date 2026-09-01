# Native Mass-Spectrometry Reader Expansion — Final Status Plan

> **Status:** implementation substantially complete for the currently validated fixture families; broader format coverage, exact calibration, corpus validation, and release hardening remain open.
>
> **Scope:** native C++ and Rust readers with one shared public contract for Agilent, SCIEX, Bruker, Shimadzu, mzML, and mzXML.

## Goal

Provide native, lazy, cross-language mass-spectrometry readers that expose identical public behavior in C++ and Rust for logical-analysis selection, spectrum/chromatogram metadata, decoded arrays, raw flattened rows, persistence, and MCP operations.

Production readers must parse native files directly. Vendor DLLs, Clearcore, ProteoWizard, `msconvert`, and paired mzML files are development-only diagnostic or differential oracles and must never be runtime dependencies or fallbacks.

## Canonical architecture and contract

### Analysis model

Every source is represented through the normalized concepts:

```text
analysis_index          zero-based public logical-analysis index
source_analysis_number vendor/container analysis number when applicable
name                    deterministic logical-analysis name
analysis_count          number of logical analyses in the physical source
```

Project persistence and reopening use:

```text
file_path + analysis_index
```

Single-analysis formats expose index `0` and count `1`. Container formats expose one row per logical analysis and reject duplicate logical names.

### Spectrum access

The direct reader boundary is:

```text
C++:  MASS_SPEC_FILE::get_spectrum(index)
Rust: Reader::spectrum_data(index)
```

Headers remain lightweight. Payload arrays are decoded on demand. Native profile, line, sparse, and token representations are preserved; no implicit centroiding is used.

### Public raw-spectrum selection

`mass_spec.get_raw_spectra` is a flattened, table-like peak operation. There is no separate public spectrum-object operation.

Selection precedence is:

```text
analysis_names → indices → targets
```

Behavior:

1. `analysis_names` limits logical analyses before decoding.
2. A non-empty `indices` list selects only those zero-based spectra.
3. In index mode, targets do not further filter the selected spectra; all selected peaks are returned with `target_id = spectrum:<index>`.
4. If `indices` is omitted or empty, the existing targets framework is used.
5. Public retention times are seconds.
6. Out-of-range indices fail explicitly.

C++ and Rust indexed raw-spectrum requests were compared across Agilent MassHunter, SCIEX TOF, Bruker TSF/BAF, Shimadzu LCD, and mzML paths. Flattened rows and complete selected arrays matched for the validated fixtures.

## Completed implementation

### Shared C++/Rust reader and persistence layer

Completed:

- normalized analysis catalog and selected-analysis state;
- deterministic logical names;
- public analysis-index bounds checks;
- project insertion and reopening through `file_path + analysis_index`;
- shared spectrum-header and chromatogram-header schemas;
- lazy direct spectrum access for native readers;
- flattened raw-spectrum public output;
- semantic catalogue declaration for `analysis_names`, `indices`, `levels`, and targets;
- generated semantic projection synchronization.

### Agilent MassHunter

Implemented and validated for the supplied MassHunter acquisition:

- native `.d` detection;
- `AcqData` metadata parsing;
- `MSScan.bin` metadata and scan records;
- native LZF profile decoding from `MSProfile.bin`;
- native profile m/z reconstruction;
- polarity from `AcqMethod.xml`/`ionPolarity`;
- MS level, TIC, BPC, RT, precursor m/z, precursor intensity, and collision energy;
- lazy C++ and Rust spectrum decoding;
- C++/Rust header and selected-array parity;
- indexed public raw-spectrum selection.

Validated representative MS2 result:

```text
scan                 188171
level                2
polarity             1
array length         165344
retention time       188.16299438476562 s
precursor m/z        237.05221557617188
precursor intensity  528.0
collision energy     10.0
```

The Rust path uses cached native metadata for headers and does not decode profile arrays merely to derive header fields.

### Agilent ChemStation

Implemented/validated in the current development slice:

- legacy `MSD1.MS`/`DATA.MS` detection;
- legacy big-endian header and word-based directory offsets;
- retention-time index records;
- packed abundance decoding;
- public C++ spectrum exposure;
- conditional development smoke coverage for the supplied 2DLC `MSD1.MS` fixture;
- ChemStation `.ch` version 130 chromatograms;
- ChemStation `.UV` version 131 chromatograms;
- Rust/C++ public chromatogram parity for the validated slice.

The validated 2DLC slice contains 672 spectra with 20 points in the first spectrum. This does not constitute complete ChemStation/2DLC support.

### SCIEX WIFF / WIFF.SCAN

Implemented and validated:

- OLE compound-file detection and stream access;
- `.wiff.scan` companion discovery;
- sample-block discovery;
- native `Idx` parsing;
- source analysis names;
- logical-analysis selection;
- PAC compact MRM decoding;
- selected multi-experiment compact MRM decoding;
- sparse tagged Nitrosamine decoding for the validated grammar;
- native MRM chromatogram headers and arrays for validated families;
- native TOF public spectrum dispatch;
- sparse/raw token preservation without centroiding;
- native TOF precursor m/z and precursor intensity extraction;
- source-index-preserving scan reporting;
- C++/Rust parity for validated spectra and chromatograms;
- bounded indexed payload reads in both C++ and Rust.

Validated TOF fixture:

```text
public spectra       8964
MS1 rows             3653
MS2 rows             5311
selected MS2 index   20
scan                 261
array length         190
retention time       124.18999481201172 s
precursor m/z        430.3861999511719
precursor intensity  404.0
collision energy     0.0  (metadata absent)
```

The TOF warm indexed-read benchmark improved from hundreds of milliseconds to approximately `0 ms` after both implementations stopped rereading the complete `.wiff.scan` file for each spectrum.

### Bruker TSF

Implemented and validated:

- `.d` family detection;
- `analysis.tsf` and `analysis.tsf_bin` access;
- native SQLite metadata;
- type-3 Zstandard payload decoding;
- frame metadata;
- MS/MS parent metadata;
- lazy indexed spectra;
- precursor m/z, isolation window, charge, and collision energy propagation;
- native calibration provenance fields;
- C++/Rust public spectrum and selected-array parity.

Validated MS2 example:

```text
index                97
scan                 98
level                2
polarity             1
array length         1521
retention time       49.431331634521484 s
precursor m/z        922.0137939453125
precursor charge     1
collision energy     75.32083129882812
```

The current m/z calibration is an explicitly documented approximation with approximately `1.8736 ppm` maximum observed oracle difference in the validated frame sample. It must not be described as exact proprietary calibration.

### Bruker BAF

Implemented and validated:

- BAF family detection;
- native `analysis.sqlite` metadata access;
- `Spectra` and `AcquisitionKeys` metadata;
- native `ProfileIntensityId` handling;
- `0xBFA01001` DataVectorBlock validation;
- `0xEE77` decoder header validation;
- profile count and decoder-table checks;
- MSB-first bit reading;
- signed-delta reconstruction;
- zero-run expansion;
- both observed signed-delta encodings;
- lazy bounded profile-block reads;
- bulk point-count lookup using one `analysis.baf` file open during metadata construction;
- C++/Rust public spectrum and complete-array parity.

Validated representative profile:

```text
points             513287
nonzero bins       3499
maximum intensity  2140
```

The bulk point-count and bounded-block changes reduced Rust BAF cold indexed access from approximately `93132 ms` to approximately `54 ms`, matching the C++ baseline of approximately `55 ms`. Warm access is approximately `2–3 ms` in both implementations.

### Shimadzu LCD

Implemented and validated in both C++ and Rust:

- `adc.lcd` and `karl.lcd` detection;
- native TLM parsing;
- TIC/BPC chromatograms;
- MRM transitions;
- precursor/product m/z;
- polarity and collision energy;
- RT arrays and headers in seconds;
- C++/Rust header parity;
- point-for-point C++/Rust chromatogram-array parity.

Validated fixtures:

```text
adc.lcd   8 chromatograms, 21008 total points
karl.lcd  90 chromatograms, 45862 total points, 40 MRM traces
```

### mzML and mzXML

Existing native XML support is implemented for:

- mzML spectrum and chromatogram metadata;
- base64 binary arrays;
- 32-bit and 64-bit values;
- zlib-compressed arrays;
- RT unit conversion to seconds;
- precursor metadata;
- mzML/mzXML public schema parity;
- mzXML peak arrays and summary behavior.

Rust mzML now stores spectrum byte ranges and decodes only the requested `<spectrum>` slice through `spectrum_data(index)`, matching the lazy C++ design. The mzML/mzXML project parity test and reader tests pass.

## Performance work completed

### Native bounded reads

Completed for Rust BAF and both SCIEX TOF implementations:

- no full `analysis.baf` read for point-count lookup per spectrum;
- no full BAF profile-file read for selected profile decoding;
- no full `.wiff.scan` read for every selected TOF spectrum;
- selected payloads are bounded by native offsets and neighboring records.

### Measured direct-reader benchmark

The benchmark used one representative indexed spectrum per format and measured cold open plus decode and warm decode. Timings should be interpreted within each format because decoded point counts differ.

Representative point counts:

```text
Agilent MassHunter  165344
SCIEX TOF              190
Bruker TSF            1521
Bruker BAF          513287
mzML                     6
```

The benchmark reports whole milliseconds for presentation. Raw logs remain under `tmp/logs/` and are development-only.

## Remaining implementation work

The following items are still open and must not be represented as complete format support.

### Agilent

- validate all supplied MassHunter acquisitions through both public readers;
- support additional MassHunter instrument families and acquisition layouts;
- classify and decode all observed `SpectrumFormatID` variants, including centroid/MSPeak formats, or reject them explicitly;
- recover and validate `MSMassCal.bin`, `DefaultMassCal.xml`, `CalibrationID`, and `MassCalOffset` semantics;
- determine scan/segment-specific m/z calibration behavior;
- complete `MSD2.MS` and 2D correlation support;
- broaden ChemStation 1D/2D acquisition coverage;
- add confirmed DAD/UV/pump/TCC/auxiliary trace families;
- complete IMS frame metadata linkage and validated CCS/mobility calibration for the ion-mobility corpus;
- add MassHunter and ChemStation holdout fixtures.

### SCIEX

- generalize MRM transition/event assignment without marker-frequency heuristics;
- complete Mix1 tagged-cycle reconciliation;
- resolve Nitrosamine outer-fragment and sparse-tail behavior;
- parse all per-period/per-experiment `MassRangeEx` lists with boundaries;
- decode pump and auxiliary chromatogram families;
- improve unsupported-grammar diagnostics with file/sample/experiment/transition context;
- validate TOF calibration and calibrated m/z arrays across additional variants;
- validate more WIFF container layouts and malformed/truncated inputs;
- complete multi-file and multiple-logical-analysis persistence differential tests.

### Bruker TSF

- replace the validated approximate m/z calibration with vendor-exact calibration where recoverable;
- validate calibration across additional acquisition software and calibration rows;
- broaden PASEF/mobility dimension preservation and diagnostics;
- test malformed/truncated Zstandard blocks and unsupported frame variants;
- validate all persisted TSF public paths and error parity.

### Bruker BAF

- generalize object lookup through `.baf_idx`, `.baf_xtr`, and metadata rather than relying on representative object-offset assumptions;
- classify/decode additional profile, line, APCI, and later-block variants;
- decode native profile m/z arrays and exact calibration from `Transformators.Blob`, `FrameMzCalibration`, and digitizer constants;
- expose native line arrays and profile m/z arrays through both public APIs;
- validate the six known BAF acquisitions across MS1/MS2 and differing profile counts;
- add malformed-header, truncated-payload, impossible-count, overflow, and unsupported-variant tests;
- validate BAF chromatogram support separately;
- complete BAF project persistence and multi-file reopening tests.

### Shimadzu

- broaden corpus validation beyond `adc.lcd` and `karl.lcd`;
- add malformed LCD/TLM diagnostics;
- identify and implement additional native LCD stream families;
- validate persisted Shimadzu analysis reads.

### mzML/mzXML

- benchmark larger mzML files with multiple large spectra;
- validate indexed slice boundaries for namespaces, self-closing forms, multiline binary text, and unusual XML formatting;
- add malformed XML/base64/zlib/array-length tests;
- consider file-backed or memory-mapped indexed access for very large mzML files rather than retaining the complete source bytes in memory;
- validate broader mzXML variants and RT/unit edge cases.

### Cross-language and public API

- permanent indexed-selection regression coverage now exists in `rust/crates/mass-spec/tests/project_indexed_persistence.rs` and `core/domains/mass_spec/tests/project_indexed_persistence.cpp`, covering analysis filtering, one/multiple indices, target precedence, empty/omitted indices, level filtering, out-of-range indices, and persistence/reopen;
- add explicit instrumentation or counters proving unrequested payloads are not decoded;
- permanent C++/Rust MCP differential coverage now exists in `tests/mass_spec_mcp_differential.py`; it compares tool names/input schemas and complete operation responses for portable multi-file mzML, plus opt-in Agilent, SCIEX TOF, Bruker TSF/BAF, and Shimadzu fixtures via `STREAMFIND_MCP_VENDOR_FIXTURES`; current validation passed portable mzML, SCIEX TOF, and Shimadzu LCD; unavailable external fixtures are skipped explicitly;
- validate all public aggregate operations (`get_raw_spectra_eic`, MS1, MS2, chromatograms) after indexed changes;
- verify project persistence after reopen for every supported family;
- keep semantic catalogue, generated projection, C++, Rust, and MCP schemas synchronized.

## Validation currently completed

The following checks passed during the current implementation:

```text
Rust reader suite
Rust Bruker BAF test
Rust SCIEX reader tests
Rust mzML/mzXML project parity test
C++ Release MCP build
Rust Release build/check
C++/Rust selected spectrum array comparisons
C++/Rust indexed flattened-row comparisons
C++/Rust Shimadzu chromatogram comparisons
semantic RDF/TriG/SHACL validation
generate_projection.py --check
rustfmt --check
git diff --check
```

R package validation remains environment-blocked because Rtools is unavailable:

```text
Error: Could not find tools necessary to compile a package
```

External vendor fixtures are conditional development inputs and are not release tests.

## Release and integration gates

Before declaring the expansion complete:

1. Reconcile all current worktree changes against the integration branch.
2. Run complete C++ and Rust public reader/MCP suites.
3. Run portable tests without external vendor fixtures.
4. Run opt-in external corpus and oracle differential tests.
5. Validate malformed/truncated/unsupported inputs for every native family.
6. Validate exact or documented-tolerance C++/Rust metadata and array parity.
7. Validate all logical-analysis persistence and reopen paths.
8. Resolve or explicitly document calibration approximations.
9. Run semantic validation and projection checks after catalogue changes.
10. Run `scripts\clean-build-temp.cmd` before commit, preserving only approved development logs/scripts as appropriate.
11. Review the final diff and create a commit only with explicit user approval.

## Non-negotiable constraints

- no runtime vendor DLL, Clearcore, ProteoWizard, or mzML fallback;
- no compatibility shim, duplicate source tree, legacy execution path, or filename-specific parser branch;
- no silent centroiding or representation substitution;
- no speculative calibration equation presented as exact;
- no secrets, credentials, API keys, passwords, tokens, or connection strings in source, plan, logs, or summaries;
- external fixtures, generated reports, build trees, and benchmark artifacts remain under `tmp/` and are not committed.
