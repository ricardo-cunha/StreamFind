# Mass-Spectrometry Reader Interface Expansion Plan

> **Scope:** Expand the native C++ and Rust mass-spectrometry reader interfaces across container and vendor formats while preserving one shared public contract.

**Goal:** Provide native, testable readers for container-based vendor data, including logical-analysis selection, metadata, spectra/chromatograms, calibration provenance, public dispatch, and persisted project reads without runtime vendor DLLs or mzML fallbacks.

**Architecture:** A physical vendor source may contain one or more logical analyses. The shared interface exposes a normalized zero-based `analysis_index`, the vendor `source_analysis_number`, a deterministic analysis name, and `analysis_count`. Native C++ and Rust readers parse the vendor files directly; matched mzML, Clearcore, ProteoWizard, and other installed tools are development-only differential oracles.

**Non-negotiable constraints:**

- Production readers must not load Bruker/SCIEX/vendor DLLs, Clearcore, ProteoWizard, `msconvert`, or other conversion runtimes.
- Production readers must not use matching mzML files as fallback input.
- Do not add filename-specific branches, sample-specific offsets, compatibility shims, duplicate source trees, or legacy execution paths.
- Preserve native profile/line arrays; do not centroid unless a separate explicitly requested processing operation does so.
- Unknown binary grammars and unproven calibration models must fail explicitly with diagnostic context.
- Real vendor files outside the repository are development fixtures only. Tests that require them support reverse engineering and local validation; they are not part of the distributable/release test suite and must remain conditionally configured or opt-in.
- Rust tests belong under `rust/crates/mass-spec/tests/`.
- Before committing on the integration branch, run `scripts\clean-build-temp.cmd` and move completed briefs from `.plans/` to `.plans/completed/` as required by repository workflow.

---

## Work already completed: shared reader/container interface

### Normalized analysis model

The shared C++ and Rust layers now contain the normalized container concepts:

```text
analysis_index          zero-based logical analysis index
source_analysis_number vendor/container analysis number
name                    deterministic logical-analysis name
analysis_count          number of analyses in the physical source
```

Single-analysis formats expose one catalog entry at index `0` with count `1`. Container formats expose one entry per logical analysis. Logical names use the physical file stem plus the source analysis name where available.

Relevant files:

```text
core/domains/mass_spec/include/streamfind/mass_spec/reader.hpp
core/domains/mass_spec/src/reader.cpp
core/domains/mass_spec/src/mass_spec.cpp
rust/crates/mass-spec/src/reader.rs
rust/crates/mass-spec/src/lib.rs
rust/crates/mass-spec/tests/reader.rs
```

### Selection and persistence boundary

`MASS_SPEC_FILE` and Rust `Reader` expose analysis catalogs, selected-analysis state, and range validation. Project ingestion/read paths have been extended to persist and reopen logical analyses using:

```text
file_path + analysis_index
```

SCIEX WIFF ingestion expands a physical container into logical-analysis rows and rejects duplicate logical names. This work must be reconciled with any newer main-branch edits before integration; do not blindly overwrite `reader.cpp`, `reader.hpp`, `mass_spec.cpp`, or related CMake files.

### Existing public contract

Vendor adapters must implement the existing interfaces rather than introducing vendor-only getters:

```text
MASS_SPEC_READER
MASS_SPEC_FILE
get_spectra_headers()
get_spectra()
get_spectrum()
get_chromatograms_headers()
get_chromatograms()
```

Rust must mirror the same behavior through `Reader`, `spectra()`, `spectrum()`, `chromatograms()`, and project operations.

---

## SCIEX WIFF / WIFF.SCAN

### Completed work

Native C++ and Rust SCIEX code exists in:

```text
core/domains/mass_spec/include/streamfind/mass_spec/reader_sciex.hpp
core/domains/mass_spec/src/reader_sciex.cpp
rust/crates/mass-spec/src/reader_sciex.rs
```

Validated/prototyped capabilities include:

- OLE/compound-file detection and stream access.
- `.wiff.scan` companion discovery.
- Sample-block discovery using observed `0x11111111` records.
- Source analysis-name extraction from `SampleDABE/DATA`.
- Native `Idx` parsing with sample-local offsets and sample-block bases.
- Method transition metadata: precursor m/z, product m/z, collision energy, and scheduled windows.
- PAC compact two-float MRM decoding.
- `201209_MM_2` multi-experiment compact decoding: 800 records × 10 channels followed by 900 records × 4 channels in the validated fixture.
- Nitrosamine sparse tagged decoding using concatenated indexed fragments, `-33.01` markers, and `-N.01` skips.
- C++/Rust public chromatogram adapters for currently validated MRM families.
- TIC/BPC derivation from decoded active transition values where validated.
- Native TOF public spectrum dispatch for the tested `220104_1_1.wiff` fixture, preserving sparse/raw token points without centroiding.
- C++ and Rust analysis catalog/selection and persisted-analysis integration.

Validated observations:

```text
201023_Pac.wiff:
    one experiment
    two transitions
    1091 points
    compact two-float records

201209_MM_2.wiff:
    experiment 0: 800 records × 10 channels
    experiment 1: 900 records × 4 channels
    combined output: 1700 points

220511_Nitrosamine...wiff:
    35 SRM transitions in the validated oracle
    sparse tagged payload

220104_1_1.wiff:
    47,491 Idx records
    8,964 native/public spectra in the tested fixture
```

The MRM timing finding that must remain documented is:

```text
Idx record + 0x08 = little-endian f64 elapsed time in milliseconds
retention_time_minutes = value / 60000.0
```

The `f32` at `+0x0c` is the upper half of that double and must not be interpreted as RT.

### SCIEX open questions / remaining work

1. Generalize transition/event assignment across all supported MRM families without relying on marker frequency heuristics.
2. Finish Mix1 tagged-cycle reconciliation and do not enable it through heuristic mapping until its assignment is fully generalized.
3. Resolve the final outer-fragment/tail behavior in the Nitrosamine sparse grammar.
4. Parse all per-period/per-experiment `MassRangeEx` lists and preserve experiment boundaries.
5. Decode pump chromatograms as a separate signal family.
6. Resolve unsupported-grammar diagnostics with file/sample/experiment/transition-count context.
7. Finish native TOF calibration, precursor metadata, and calibrated m/z arrays for variants beyond the tested fixture.
8. Complete multi-file C++/Rust public differential tests and persisted reads for multiple logical analyses sharing one physical WIFF path.
9. Reconcile all current worktree changes against the main branch before committing.

Primary development fixtures:

```text
E:\example_files\raw_vendor_files\sciex\201023_Pac.wiff
E:\example_files\raw_vendor_files\sciex\201209_MM_2.wiff
E:\example_files\raw_vendor_files\sciex\220511_Nitrosamine_M220426_M220503_Vierlinden.wiff
E:\example_files\raw_vendor_files\sciex\250414_Mix1.wiff
E:\example_files\raw_vendor_files\sciex\tof\220104_1_1.wiff
```

Use paired mzML and Clearcore/ProteoWizard output only as external validation oracles. Never embed these paths or dependencies in production code.

---

## Bruker TSF

### Completed work

Native TSF parsing is implemented in:

```text
core/domains/mass_spec/include/streamfind/mass_spec/reader_bruker.hpp
core/domains/mass_spec/src/reader_bruker.cpp
rust/crates/mass-spec/src/reader_bruker.rs
```

The implementation includes:

- Bruker `.d` family detection.
- `analysis.tsf`, `analysis.tsf_bin`, and native SQLite metadata access.
- Type-3 Zstandard payload decoding using vendored Zstandard `v1.5.7` in C++ and the Rust `zstd` crate.
- Decompressed layout validation:
  ```text
  NumPeaks × float64 TOF/index
  NumPeaks × float32 intensity
  NumPeaks × float32 auxiliary line-width
  ```
- Frame metadata, MS/MS parent information, and lazy spectrum access.
- Native calibration provenance fields.
- The selected validated open-source linear-in-√m/z approximation:
  ```text
  if AcquisitionSoftware == "Bruker otofControl":
      mz_min -= 5
      mz_max += 5

  mz(tof) = (sqrt(mz_min) +
             (sqrt(mz_max) - sqrt(mz_min)) * tof / tof_max)^2
  ```
- C++ and Rust public TSF dispatch and tests.

Observed validation included frames `1, 2, 3, 98, 100, 4451`, with a maximum observed oracle difference of approximately `1.8736 ppm`.

### TSF open questions / remaining work

1. Keep the approximation explicitly documented as an approximation; do not claim exact proprietary polynomial reproduction.
2. Validate calibration and public metadata across more TSF acquisition families, especially differing acquisition software and calibration rows.
3. Validate persisted TSF reads and all public array surfaces after project ingestion.
4. Confirm behavior for malformed/truncated Zstandard blocks and unsupported frame variants.
5. Ensure C++/Rust error text and bounds behavior remain aligned.

Representative fixture:

```text
E:\example_files\ms_merck\Beispieldaten Routine\ACC1_28127_1_blank_P1-A-1_1_2022_13602.d
```

---

## Bruker BAF

### Completed work

Native BAF work uses:

```text
core/domains/mass_spec/include/streamfind/mass_spec/reader_bruker.hpp
core/domains/mass_spec/src/reader_bruker.cpp
rust/crates/mass-spec/src/reader_bruker.rs
core/domains/mass_spec/tests/reader_bruker_baf_smoke.cpp
rust/crates/mass-spec/tests/reader_bruker_baf.rs
```

Native files inspected:

```text
analysis.baf
analysis.baf_idx
analysis.baf_xtr
analysis.sqlite
calibration.sqlite
chromatography-data.sqlite
```

The C++ metadata/container adapter reads:

```sql
Spectra(
  Id, Rt, AcquisitionKey, Parent,
  MzAcqRangeLower, MzAcqRangeUpper,
  SumIntensity, MaxIntensity, TransformatorId,
  ProfileMzId, ProfileIntensityId,
  LineIndexId, LineMzId, LineIntensityId,
  LineIndexWidthId, LinePeakAreaId, LineSnrId
)

AcquisitionKeys(
  Id, Polarity, ScanMode, AcquisitionMode, MsLevel
)
```

The native profile decoder supports the validated `0xBFA01001` `DataVectorBlock` variant:

```text
ProfileIntensityId = (type byte << 56) | 56-bit object id
object id lower bits map to the native BAF block locator in validated files
block + 0x2c: little-endian 0xEE77 decoder magic
block + 0x30: little-endian profile count
block + 0x34: big-endian serialized table length
26-byte decoder table
MSB-first 32-bit bit reader with big-endian refills
signed delta reconstruction
zero-run expansion
```

The C++ public BAF path now reaches:

```text
MASS_SPEC_FILE
    → detect_format()
    → BrukerBAF
    → create_baf_reader()
    → read_baf_spectra_metadata()
    → read_baf_profile_spectrum()
    → get_spectra_headers()
    → get_spectrum()
```

The Rust low-level profile decoder has matching bit ordering, table checks, delta/run logic, and bounds checks. Rust BAF profile integration tests pass for the representative profile.

Validated representative profile:

```text
count          = 513287
nonzero bins   = 3499
maximum        = 2140
bin 33         = 16
bins 166–168   = 42,60,40
bins 432–434   = 30,48,38
```

The controlled mutation fixture changes bins `432–434` from `30,48,38` to `46,64,54`, proving the native decoder responds to payload mutation before public conversion.

### BAF open questions / remaining work

1. Generalize object lookup through `.baf_idx`/`.baf_xtr` and metadata. Do not rely on the representative sample's `analysis.baf + 0x18475` offset or assume every lower object ID is directly a file offset.
2. Support and classify additional block variants. The APCI acquisition and some later spectrum-98 blocks share the outer header but use a different payload mode; they must be rejected with diagnostics until independently decoded.
3. Complete native profile m/z decoding. The current public adapter uses the acquisition-range linear grid only as a provisional projection and must not present it as vendor-exact calibration.
4. Decode `Transformators.Blob`, `FrameMzCalibration`, `DigitizerConstants`, and any related mappings. The observed BAF calibration database includes:
   ```text
   DigitizerTimebase = 0.2
   DigitizerDelay = 25159.0
   FrameMzCalibration.ModelType = 1
   C0 = 333.6898490671741
   C1 = 154134.80342273906
   dC1 = 0.00045574173403438374
   dC2 = 0.0
   C2 = -0.005438303535971796
   ```
   A simple linear √m/z fit showed approximately `3.69 ppm` maximum error on one oracle comparison, so it must not be shipped as the native equation.
5. Expose native line arrays and profile m/z arrays through both public C++ and Rust `get_spectrum`/`spectrum` surfaces.
6. Add Rust `BrukerBAF` public metadata/container adapter matching C++ rather than only the low-level profile function.
7. Add multi-file public differential tests across the six known BAF acquisitions, including MS1/MS2 and differing profile counts.
8. Validate project persistence and reopening through `file_path + analysis_index` for BAF.
9. Add explicit unsupported-variant tests, malformed-header tests, truncated-payload tests, impossible-count tests, and run-overflow tests.

Representative BAF acquisitions:

```text
E:\example_files\ms_merck\Beispieldaten Routine\ACC1_24890_1_P1-B-8_1_2022_7707.d
E:\example_files\ms_merck\Beispieldaten Routine\ACC1_25237_2_APCI_50-2500.d
E:\example_files\ms_merck\Beispieldaten Routine\ACC1_25777_1_blank_P1-A-1_1_2022_9271.d
E:\example_files\ms_merck\Beispieldaten Routine\ACC1_25777_1_P1-A-7_1_2022_9272.d
E:\example_files\ms_merck\Beispieldaten Routine\ACC1_26393_1_blank_P1-A-1_1_2022_10559.d
E:\example_files\ms_merck\Beispieldaten Routine\ACC1_26393_1_P1-A-5_1_2022_10560.d
```

### BAF oracle boundary

During reverse engineering, the following were used only as development tools:

```text
C:\Program Files\ProteoWizard\ProteoWizard 3.0.22340.6fe44c6\baf2sql_c.dll
WinDbg/CDB traces
matching mzML files
```

Important recovered native stages:

```text
baf2sql_c + 0xc31460  decoder-state initialization
baf2sql_c + 0xc31640  dense 32-bit source-vector population
baf2sql_c + 0xc03500  32-bit MSB-first bit reader
baf2sql_c + 0xbd03c1  final public double write
```

The vendor runtime proved that the public array is copied from a dense `count × 4-byte` vector into a `count × 8-byte` double array. These observations are evidence for the clean-room implementation only; no vendor runtime is part of the production reader.

---

## Cross-format work to perform

### Public C++ completion

- Finish BAF calibrated m/z and native line/profile array exposure.
- Complete `MASS_SPEC_READER` metadata semantics: polarity, MS level, parent/precursor fields, TIC/BPC, ranges, and array lengths.
- Ensure `.d` detection distinguishes TSF and BAF cleanly and rejects incomplete directories with useful diagnostics.
- Add public C++ tests for all supported BAF/TSF families and unsupported variants.

### Rust parity

- Add the Rust BAF metadata/container model and public dispatch to match C++.
- Mirror C++ array IDs, metadata fields, calibration provenance, errors, and unsupported-variant behavior.
- Keep Rust profile/line decoding tests in `rust/crates/mass-spec/tests/`.
- Run:
  ```text
  env -u TMP -u tmp -u TEMP -u temp cargo test -p streamfind-rust-mass-spec
  ```
  from `rust/` on Windows environments with duplicate-case temporary variables.

### Differential validation

For each supported vendor family, compare native output against a development oracle for:

```text
analysis count and logical names
spectrum/chromatogram counts
scan/frame IDs
RT and parent relationships
MS level/polarity/mode
array lengths
native intensities
m/z values and calibration error
TIC/BPC
public C++ vs Rust parity
```

Use holdout fixtures. Exact equality is required for integer profile intensities and decoded line intensities where the format guarantees it; document floating-point tolerances for RT and m/z.

### Persistence validation

Verify every project-level path uses the persisted logical locator:

```text
file_path + analysis_index
```

Test:

- one single-analysis TSF source;
- one single-analysis BAF source;
- one multi-analysis SCIEX WIFF source;
- two selected analyses sharing one physical file;
- duplicate logical-analysis rejection;
- persisted raw and processed reads returning the selected analysis rather than the first analysis.

### Semantic and quality validation

If ontology/catalogue declarations change, run:

```text
.venv\Scripts\python.exe semantic\validate_semantic.py
.venv\Scripts\python.exe semantic\generate_projection.py --check
```

Always run:

```text
git diff --check
```

For C++ native changes, build through the configured Visual Studio CMake build with duplicate `TMP/tmp` and `TEMP/temp` variables removed. For R package changes, run `devtools::load_all()` from `bindings/r`; the R package remains a preserved boundary during this reader expansion.

---

## Relevant temporary diagnostic artifacts

These files are now under the repository-managed scratch locations:

```text
tmp/scripts/decode-baf-profile-prototype.py
tmp/scripts/validate-baf-profile-blocks.py
tmp/scripts/validate-baf-profile-oracle.py
tmp/scripts/bruker-baf-calfit.py
tmp/scripts/bruker-baf-trace-target.py
tmp/scripts/signal-baf-event.py
tmp/scripts/baf-source-write.cmd
tmp/scripts/baf-source-vector.cmd
tmp/scripts/baf-decoder-entry.cmd
tmp/scripts/bruker-baf-idx-parse.py
tmp/scripts/bruker-baf-pointer-probe.py
tmp/scripts/bruker-baf-object-records.py
tmp/logs/bruker-baf-map.json
```

The repository `AGENTS.md` rule is authoritative: future development scripts belong in `tmp/scripts/`, transient reports/logs belong in `tmp/logs/`, and temporary fixtures/projects belong in `tmp/projects/`. These locations are gitignored and are not production dependencies.

Use these only as investigation aids. They may contain fixture-specific assumptions and must not be copied into production dependencies. Stale/invalid trace runs that reported `count=0`, `before_read 0`, heap corruption, or stale ASLR addresses were explicitly discarded and are not evidence.

No secrets, credentials, API keys, passwords, or connection strings belong in this plan.

---

## Final completion criteria

The expansion is complete only when:

- C++ and Rust public readers open every claimed supported vendor family.
- Container analyses can be selected and persisted/reopened deterministically.
- BAF m/z calibration is decoded and validated, or unsupported calibration is reported explicitly.
- C++ and Rust outputs agree on metadata and arrays within documented tolerances.
- Multi-file holdout differential tests pass.
- Persisted project reads select the correct logical analysis.
- No production path loads vendor DLLs or reads mzML as fallback.
- Unsupported binary variants fail clearly instead of returning plausible but incorrect data.

---

## Agilent MassHunter `.d`

### Completed work and corpus

The native Agilent reader work is represented by:

```text
core/domains/mass_spec/include/streamfind/mass_spec/reader_agilent.hpp
core/domains/mass_spec/src/reader_agilent.cpp
rust/crates/mass-spec/src/reader_agilent.rs
core/domains/mass_spec/tests/reader_agilent_smoke.cpp
rust/crates/mass-spec/tests/reader_agilent.rs
rust/crates/mass-spec/tests/reader_agilent_public.rs
```

The initial corpus is:

```text
E:\example_files\raw_vendor_files\agilent_mass_hunter\020_Aceton_Uracil_Mix1_01-r001.d
E:\example_files\raw_vendor_files\agilent_mass_hunter\021_Aceton_Uracil_Mix1_1-r001.d
E:\example_files\raw_vendor_files\agilent_mass_hunter\022_Aceton_Uracil_Mix1_10-r001.d
```

Each acquisition has a matching mzML oracle under:

```text
E:\example_files\raw_vendor_files\agilent_mass_hunter\as_mzML\
```

The `.d/AcqData` boundary contains:

```text
Contents.xml
AcqMethod.xml
MSTS.xml
MSActualDefs.xml
MSScan.xsd
MSScan.bin
MSProfile.bin
MSMassCal.bin
MSPeriodicActuals.bin
DefaultMassCal.xml
Devices.xml
DeviceConfigInfo.xml
sample_info.xml
DAD1.*
QuatPump1.*
TCC1.*
HiP-ALS1.*
```

`MSScan.xsd` documents fields including `ScanID`, `ScanMethodID`, `TimeSegmentID`, `ScanTime`, `MSLevel`, `ScanType`, `TIC`, `BasePeakMZ`, `BasePeakValue`, `IonMode`, `IonPolarity`, `Fragmentor`, `CollisionEnergy`, `MzOfInterest`, `ChargeState`, `MassCalOffset`, `ActualsOffset`, `NumOfActualsPerScan`, and spectrum offset/byte-count/point-count records.

The initial implementation established:

- `MSScan.bin` as a 228-byte preamble followed by 220-byte scan records for the supplied Q-TOF corpus.
- `SpectrumFormatID=1` profile linkage.
- `MSProfile.bin` profile blocks decoded with raw standard LZF.
- Decompressed profile payloads as native `uint32` intensity counts.
- m/z reconstruction from `MinX`, `MaxX`, and `PointCount`.
- End-to-end validation of the first 7,870-scan fixture: intensity sums and maxima agree with native scan TIC/base-peak fields.
- Structural `.d` detection and lazy C++ public spectrum decoding.
- Rust metadata through `spectra()` and on-demand arrays through `spectrum_data(index)` to avoid eager multi-gigabyte allocation.

### Agilent open questions / remaining work

1. Validate all three supplied acquisitions through both public readers against their mzML oracles.
2. Confirm `MSScan.bin` layouts and optional fields across additional MassHunter instrument families.
3. Decode all observed `SpectrumFormatID` variants, including centroid/MSPeak formats, or reject them explicitly.
4. Recover `MSMassCal.bin`, `DefaultMassCal.xml`, `CalibrationID`, and `MassCalOffset` semantics; do not infer calibration from one fixture.
5. Determine whether profile m/z values are already calibrated or require a segment/scan-specific transform.
6. Decode DAD, pump, TCC, and autosampler traces only as separate confirmed chromatogram families.
7. Enrich XML/method metadata while keeping `MSActualDefs.xml` as the authority for `MSPeriodicActuals.bin` field interpretation.
8. Decide whether the Rust API should gain a general lazy-spectrum abstraction rather than the current Agilent-specific `spectrum_data` accessor.
9. Add holdouts beyond the three Q-TOF files: another instrument family, MS1-only, DDA/MS2, and DAD-only data if available.

Agilent analysis semantics currently appear to be one logical analysis per `.d` directory:

```text
analysis_index = 0
analysis_count = 1
source_analysis_number = absent/null
```

Do not treat time segments as separate analyses without evidence. Do not infer analyses from the `.d` suffix because Bruker also uses `.d`.

Validated ChemStation chromatogram support now covers `.ch` version 130 (big-endian delta segments with 32-bit escape values) and `.UV` version 131 (little-endian per-time wavelength segments with delta or label-70 float64 bodies). The public C++ and Rust readers expose one chromatogram per `.ch` file or UV wavelength, including detector/channel/units/wavelength/interval/start/end metadata. Tests pass for a 33,601-point `DAD1A.ch`, a 12,003-time-point/106-wavelength `DAD1.UV`, and a DAD-only `.D` directory containing four `.ch` plus 106 `.UV` chromatograms. Unsupported versions remain explicit errors.

### Current expanded Agilent corpus

Inventory under `tmp/scripts/inventory-agilent-variants.py` found 263 `.D` directories: 254 legacy ChemStation directories and 9 MassHunter directories. ChemStation is a separate legacy family: representative `MSD1.MS` files have `MSD Spectral File` at offset 5, big-endian word-based directory offsets, and packed abundance records; 2DLC runs add `MSD2.MS` and distinct 1D/2D pump, MCT, and DAD streams. The native C++ `MSD1.MS` slice is implemented and its conditional 2DLC smoke test passes with 672 spectra and 20 points in the first spectrum. `MSD2.MS`, 2D correlation, DAD/UV/pump traces, and broader ChemStation variants remain open work.

MassHunter wide-range files such as `BVCZ_Intra-Day_1.d` add `MSPeak.bin` alongside `MSProfile.bin`, `MSScan.bin`, `MSMassCal.bin`, and `MSPeriodicActuals.bin`. The smallest ion-mobility target is `E:/example_files/raw_vendor_files/agilent_mass_hunter/ion_mobility/calibrant.d`, which adds `IMSFrame.bin`, `IMSFrame.xsd`, `IMSFrameMeth.xml`, `DefaultImsCal.xml`, and `OverrideImsCal.xml`. Its `IMSFrame.xsd` defines drift-bin, frame TIC/base-abundance, isolation, IMS pressure/temperature/field/trap-time, mass-calibration offset, and transient-count fields; the fixture has 103 scans from approximately 0.0514 to 1.9981 minutes. `OverrideImsCal.xml` provides nitrogen single-field CCS calibration values `TFix=0.05180056157601598` and `Beta=0.12420626303137353`. First implement IMS frame metadata and linkage to `MSScan.bin`; validate CCS/mobility calibration separately against `calibrant.mzML`.

Supporting inventory and binary reports are kept in `tmp/logs/` and the inspection scripts in `tmp/scripts/`; all are development-only and must remain outside release inputs.


### Current expansion findings

The initial inventory script found 263 `.D` directories:

```text
254 legacy ChemStation directories
9 MassHunter directories
```

The legacy ChemStation family is not compatible with the current MassHunter `AcqData` parser. A representative `MSD1.MS` begins with:

```text
offset 5: "MSD Spectral File"
embedded method text, for example "MSD1, Initial Ions=..."
```

ChemStation 2DLC runs add distinct data streams such as `MSD2.MS` and method-described 1D/2D pump, MCT, and DAD components. Their `.MS`, `.ch`, `.UV`, `.REG`, and method files require a separate reader family.

MassHunter wide-range files include `MSPeak.bin` alongside the existing `MSProfile.bin`, `MSScan.bin`, `MSMassCal.bin`, and `MSPeriodicActuals.bin`. They need broader spectrum-format and calibration dispatch rather than a filename-specific branch.

The smallest MassHunter ion-mobility fixture is:

```text
E:/example_files/raw_vendor_files/agilent_mass_hunter/ion_mobility/calibrant.d
```

It adds:

```text
IMSFrame.bin
IMSFrame.xsd
IMSFrameMeth.xml
DefaultImsCal.xml
OverrideImsCal.xml
```

`IMSFrame.xsd` defines frame metadata fields including `FrameId`, `FrameMethodId`, `TimeSegmentId`, `ActualsOffset`, `CycleNumber`, `FirstNonzeroDriftBin`, `FrameBaseAbund`, `FrameBaseDriftBin`, `FrameBaseMsBin`, `FrameScanTime`, `FrameTic`, `ImsField`, `ImsPressure`, `ImsTemperature`, `ImsTrapTime`, isolation m/z fields, `MassCalOffset`, and `NumTransients`. The fixture has a 103-scan segment from approximately `0.0514` to `1.9981` minutes.

`IMSFrameMeth.xml` reports `FrameSpecFmtId=1`, `FrameType=1`, `NumTransients=19`, drift-bin limits, `MaxMsBin=239360`, `MinMsBin=59552`, `ImsField=18.560290983623`, nitrogen drift gas, `ImsTrapTime=20000 ms`, and `TfsStorageMode=1`. `OverrideImsCal.xml` contains a single-field CCS calibration with nitrogen mass `28.006148`, `TFix=0.05180056157601598`, and `Beta=0.12420626303137353`.

The ion-mobility implementation parses IMS frame metadata, the expanded 296-byte-header/106-byte-record `MSScan.bin` layout, and native RLE `MSProfile.bin` blocks. It exposes native mobility through the existing `mobility` field as `DriftBin * FrameDtPeriod`; it does not add a CCS field or perform CCS conversion. `OverrideImsCal.xml` remains reserved for a later validated processing-stage CCS conversion, and mobility must not be inferred from CCS calibration parameters.

The initial native ChemStation C++ slice is now implemented for `MSD1.MS`/`DATA.MS`. It reads the legacy big-endian header, word-based directory offsets, retention-time index records, and packed abundance values, and exposes the decoded spectra through `MASS_SPEC_FILE` as `AgilentChemStationD`. The conditional development smoke test passes for the supplied 2DLC `MSD1.MS` fixture with 672 spectra and 20 points in the first spectrum. This does not yet claim support for `MSD2.MS`, 2D-specific correlation, DAD/UV/pump traces, or all ChemStation acquisition variants.

### Expanded fixture inventory

A repository-local inventory under `tmp/scripts/inventory-agilent-variants.py` found 263 Agilent `.D` directories across the supplied roots:

```text
E:/example_files/raw_vendor_files/agilent_chemstation
E:/example_files/raw_vendor_files/agilent_mass_hunter
```

The inventory includes 254 legacy ChemStation directories and 9 MassHunter directories, including:

```text
E:/example_files/raw_vendor_files/agilent_chemstation/2DLC/
E:/example_files/raw_vendor_files/agilent_mass_hunter/BVCZ_Intra-Day_1.d
E:/example_files/raw_vendor_files/agilent_mass_hunter/ion_mobility/calibrant.d
E:/example_files/raw_vendor_files/agilent_mass_hunter/ion_mobility/mix1.d
```

ChemStation is structurally distinct from MassHunter. Representative ChemStation files include:

```text
MSD1.MS
MSD2.MS                 optional second-dimension detector
DAD1A.ch / DAD1B.ch / DAD1C.ch / DAD1D.ch
DAD1.UV
MSACQINF.REG
MSDIAG.REG
MSPARMS.txt
acq.txt
SAMPLE.XML
acq.macaml / da.macaml
```

The 2DLC method text explicitly identifies separate `1D Pump`, `2D Pump`, `1D MCT`, `2D MCT`, `1D DAD`, and `2D DAD` components. It is not safe to treat 2DLC as ordinary 1D ChemStation data.

Observed legacy `MSD1.MS` evidence:

```text
header signature: offset 5 = "MSD Spectral File"
embedded acquisition/method text, including "MSD1, Initial Ions=..."
legacy flat binary layout; no AcqData/MSScan.bin or MSProfile.bin
```

Representative MassHunter extensions:

```text
BVCZ_Intra-Day_1.d:
    MSProfile.bin
    MSPeak.bin
    MSScan.bin
    MSMassCal.bin
    MSPeriodicActuals.bin
    Results/Qual and Results/BioConfirm data

ion_mobility/calibrant.d:
    IMSFrame.bin
    IMSFrame.xsd
    IMSFrameMeth.xml
    DefaultImsCal.xml
    OverrideImsCal.xml
    MSProfile.bin
    MSPeak.bin
    MSScan.bin
```

The smallest ion-mobility target is:

```text
E:/example_files/raw_vendor_files/agilent_mass_hunter/ion_mobility/calibrant.d
```

Its first implementation slice should decode `IMSFrame.xsd`/`IMSFrame.bin` metadata and relate IMS frame records to `MSScan.bin` spectra before attempting CCS or mobility calibration. `OverrideImsCal.xml` and `DefaultImsCal.xml` are calibration inputs, not optional decorative files.

Inventory and binary-inspection outputs are kept under:

```text
tmp/logs/agilent-variants-inventory.json
tmp/logs/agilent-variant-headers.json
tmp/logs/chemstation-ms-inspection.txt
tmp/logs/chemstation-records.txt
tmp/scripts/inventory-agilent-variants.py
tmp/scripts/inspect-agilent-variant-headers.py
tmp/scripts/inspect-chemstation-ms.py
tmp/scripts/inspect-chemstation-records.py
```

These are development-only artifacts. Do not place the external vendor files, generated reports, or system-temp copies into the repository's tracked source tree.

### Current expansion findings

The initial inventory script found 263 `.D` directories:

```text
254 legacy ChemStation directories
9 MassHunter directories
```

The legacy ChemStation family is not compatible with the current MassHunter `AcqData` parser. A representative `MSD1.MS` begins with:

```text
offset 5: "MSD Spectral File"
embedded method text, for example "MSD1, Initial Ions=..."
```

ChemStation 2DLC runs add distinct data streams such as `MSD2.MS` and method-described 1D/2D pump, MCT, and DAD components. Their `.MS`, `.ch`, `.UV`, `.REG`, and method files require a separate reader family.

MassHunter wide-range files include `MSPeak.bin` alongside the existing `MSProfile.bin`, `MSScan.bin`, `MSMassCal.bin`, and `MSPeriodicActuals.bin`. They need broader spectrum-format and calibration dispatch rather than a filename-specific branch.

The smallest MassHunter ion-mobility fixture is:

```text
E:/example_files/raw_vendor_files/agilent_mass_hunter/ion_mobility/calibrant.d
```

It adds:

```text
IMSFrame.bin
IMSFrame.xsd
IMSFrameMeth.xml
DefaultImsCal.xml
OverrideImsCal.xml
```

`IMSFrame.xsd` defines frame metadata fields including `FrameId`, `FrameMethodId`, `TimeSegmentId`, `ActualsOffset`, `CycleNumber`, `FirstNonzeroDriftBin`, `FrameBaseAbund`, `FrameBaseDriftBin`, `FrameBaseMsBin`, `FrameScanTime`, `FrameTic`, `ImsField`, `ImsPressure`, `ImsTemperature`, `ImsTrapTime`, isolation m/z fields, `MassCalOffset`, and `NumTransients`. The fixture has a 103-scan segment from approximately `0.0514` to `1.9981` minutes.

`IMSFrameMeth.xml` reports `FrameSpecFmtId=1`, `FrameType=1`, `NumTransients=19`, drift-bin limits, `MaxMsBin=239360`, `MinMsBin=59552`, `ImsField=18.560290983623`, nitrogen drift gas, `ImsTrapTime=20000 ms`, and `TfsStorageMode=1`. `OverrideImsCal.xml` contains a single-field CCS calibration with nitrogen mass `28.006148`, `TFix=0.05180056157601598`, and `Beta=0.12420626303137353`.

The ion-mobility implementation parses IMS frame metadata, the expanded 296-byte-header/106-byte-record `MSScan.bin` layout, and native RLE `MSProfile.bin` blocks. It exposes native mobility through the existing `mobility` field as `DriftBin * FrameDtPeriod`; it does not add a CCS field or perform CCS conversion. `OverrideImsCal.xml` remains reserved for a later validated processing-stage CCS conversion, and mobility must not be inferred from CCS calibration parameters.

### Current expansion findings

---

## Additional Bruker evidence retained from the original plan

BAF native `analysis.sqlite` also exposes these tables and metadata sources:

```text
Properties
Steps
ReferenceTransformators
PerSpectrumVariables
PerSegAcqKeyVariables
PerSegmentVariables
SupportedVariables
Info
```

`Info` contains schema/compressor/size metadata such as:

```text
SchemaVersion
Compressor
BAFSize
IDXSize
XTRSize
```

The representative BAF fixture has:

```text
native Spectra rows = 2956
matching mzML spectra = 2956
first spectrum:
    Id = 1
    Rt = 0.53
    AcquisitionKey = 1
    SumIntensity = 61030
    MaxIntensity = 2140
```

The first observed MS2 spectrum is spectrum `98`, whose parent is `97`. Relevant per-spectrum variables include:

```text
Collision_Energy_Act
MSMS_PreCursorChargeState
MSMS_IsolationMass_Act
Quadrupole_IsolationResolution_Act
```

BAF chromatogram support is a separate future track. `chromatography-data.sqlite` exposes:

```text
Globals
SpectrumSources
TraceSources
Spectra
TraceChunks
TreatmentEvents
```

Only confirmed BPC/TIC/DAD/UV traces should be mapped into the shared chromatogram contract; auxiliary chromatograms must not block MS spectrum support.

TSF validation evidence retained from the original investigation:

```text
native Frames rows = 4451
matching mzML spectra = 4451
native MS2 FrameMsMsInfo rows = 2556
matching mzML MS1 rows = 1895
matching mzML MS2 rows = 2556
```

Representative TSF metadata:

```text
Frame 98 → Parent 97
TriggerMass = 922.013796...
IsolationWidth = 7.688055...
PrecursorCharge = 1
CollisionEnergy = 75.320827...
```

Both Bruker families use family-specific payload locators:

```text
BAF: profile/line IDs plus BAF/IDX/XTR locators
TSF: frame ID, scan index, TimsId, and TSF binary offsets
```

Do not flatten TSF mobility/PASEF dimensions silently. Preserve them or report explicit unsupported behavior.

---

## Windows binary and DLL inspection assets

The development environment has the Windows 10 SDK/Debugging Tools installed under:

```text
C:\Program Files (x86)\Windows Kits\10\
```

These tools are useful for inspecting installed Clearcore/SCIEX assemblies and native binaries during reverse engineering, crash diagnosis, and oracle comparison. They are **development-only assets** and must never become production reader dependencies.

### x64 debugger and dump tools

Verified available under:

```text
C:\Program Files (x86)\Windows Kits\10\Debuggers\x64\
```

Relevant tools:

```text
cdb.exe       command-line user-mode debugger; preferred for repeatable traces
windbg.exe    interactive WinDbg debugger
ntsd.exe      command-line debugger variant
tlist.exe      process/module listing
list.exe      debugger list utility
dbh.exe       symbol and image inspection utility
dumpchk.exe   basic crash-dump validation/inspection
dumpexam.exe  dump examination utility
symchk.exe    symbol-server/symbol availability checks
symstore.exe  local symbol-store management
pdbcopy.exe   PDB processing/copying
srcsrv\       source-server utilities including pdbstr.exe and srctool.exe
gflags.exe    loader/heap/debugging flag configuration
umdh.exe      user-mode heap-diff investigation
logger.exe    user-mode logging support
logviewer.exe log inspection
```

The names above are the relevant tools; preserve the actual installed path and architecture when invoking them. Use x86 tools from the corresponding `Debuggers\x86` directory when the target process is 32-bit.

### x64 SDK binary/metadata inspection tools

Verified available under:

```text
C:\Program Files (x86)\Windows Kits\10\bin\10.0.28000.0\x64\
```

Relevant tools include:

```text
inspect.exe              Windows binary/metadata inspection utility
oleview.exe              COM/type-library inspection utility
signtool.exe             signature inspection/verification
filetypeverifier.exe     file-type/package validation
filtdump.exe             filter/metadata dump utility
wstracedump.exe          Windows trace dump utility
wsutil.exe               Windows trace support utility
```

For ordinary PE export/import/dependency inspection, use the installed Visual Studio `dumpbin.exe` when available, or another explicitly identified PE inspection tool. Record the exact tool path and version in a diagnostic report.

### Recommended Clearcore/SCIEX inspection workflow

Use these assets in an isolated, external diagnostic workflow:

```text
installed Clearcore/SCIEX DLL or managed assembly
    → cdb.exe / WinDbg
    → module/symbol/export inspection
    → controlled breakpoint or memory/register trace
    → stable JSON/CSV/hex diagnostic report
    → clean-room native C++/Rust implementation
```

Recommended steps:

1. Identify target architecture: x86 versus x64.
2. Record the exact DLL/assembly path and file version/hash outside production source.
3. Inspect PE headers, imports, exports, sections, and dependencies before loading.
4. Prefer documented exports or a separate diagnostic host; do not inject vendor runtime code into StreamFind production paths.
5. Use CDB command files for repeatable breakpoints, register/memory captures, and controlled termination.
6. Account for ASLR on every run; derive module-relative addresses from the current loaded module base rather than reusing stale absolute addresses.
7. Capture only evidence needed to establish file structures, metadata semantics, calibration, and decoder behavior.
8. Validate inferred rules against multiple fixtures and a holdout before writing production code.
9. Preserve raw traces and scripts under a temporary/external location; summarize only stable findings in this plan or test documentation.
10. Terminate debugger/oracle processes cleanly after each investigation and discard runs with zero counts, invalid handles, heap corruption, stale addresses, or other harness failures.

### Clearcore boundary

Clearcore/SCIEX assemblies, Bruker DLLs, ProteoWizard DLLs, and Windows debugging tools may be used to inspect binaries or produce development oracle data. They must not be:

- linked into StreamFind C++ or Rust production targets;
- loaded by public reader operations;
- copied into `core/vendor/`;
- used to convert vendor files to mzML at runtime;
- used to hide unsupported native grammars behind a fallback path.

A valid production result is always:

```text
public operation
    → native StreamFind C++/Rust parser
    → supported result or explicit diagnostic error
```

not:

```text
public operation
    → Clearcore/vendor DLL/msconvert
    → implicit conversion or oracle read
    → silently returned data
```
