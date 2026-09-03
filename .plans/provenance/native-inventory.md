# Native Inventory Baseline

Status: Phase 0 inventory

This inventory covers active project-owned native code and the binding/build
entry points. Vendored third-party source trees and generated object files are
listed as dependencies, not repeated file by file.

## Active Native Source Map

The active project-owned native implementation is mapped below, excluding
vendored third-party trees and generated objects. The file lists are the source
of truth for the extraction boundary; generated `.o`, `.dll`, and equivalent
build outputs are not migration units.

### Project and storage

| Path | Role | Initial target |
| --- | --- | --- |
| `bindings/r/src/core/project/project.cpp` | DuckDB connection guards, schema creation/validation, project metadata, workflow JSON, cache, audit, copy, table listing | `core/src/project/project.cpp` |
| `bindings/r/src/core/project/project.h` | Project API, database helpers, row/table wrappers, project error type | Public/private split under `core/include/streamfind/` and `core/src/project/` |

### MassSpec

| Path | Role | Initial target |
| --- | --- | --- |
| `bindings/r/src/core/mass_spec/mass_spec.cpp` | Analysis metadata, spectra/chromatogram header persistence, MassSpec project operations | `core/src/mass_spec/mass_spec.cpp` |
| `bindings/r/src/core/mass_spec/mass_spec.h` | MassSpec data structures and project operations | `core/include/streamfind/mass_spec/` plus private implementation headers |
| `bindings/r/src/core/mass_spec/reader.cpp` | Reader dispatch, mzML/mzXML/TXT/ASC/LCD parsing, binary arrays, OLE streams | `core/src/mass_spec/reader.cpp` |
| `bindings/r/src/core/mass_spec/reader.h` | `MS_READER`, `MS_FILE`, summaries, spectrum/chromatogram structures, decoding API | Public reader contracts plus private format headers |
| `bindings/r/src/core/mass_spec/processing.cpp` | Chromatogram table creation, persistence, query, filtering and processing | `core/src/mass_spec/processing.cpp` |
| `bindings/r/src/core/mass_spec/processing.h` | Chromatogram processing structures and functions | Public/private MassSpec boundary |

### NTA

| Path | Role | Initial target |
| --- | --- | --- |
| `bindings/r/src/core/nta/nta.cpp` | NTA tables, feature data access, orchestration and persistence | `core/src/nta/nta.cpp` |
| `bindings/r/src/core/nta/nta.h` | NTA data structures and orchestration declarations | `core/include/streamfind/nta/` plus private headers |
| `src/core/nta/nta_alignment.cpp` / `.h` | Feature alignment and grouping support | `core/src/nta/` |
| `src/core/nta/nta_annotation.cpp` / `.h` | Component/isotope annotation | `core/src/nta/` |
| `src/core/nta/nta_assign_transformation_products.cpp` / `.h` | Transformation-product assignment | `core/src/nta/` |
| `src/core/nta/nta_blank_subtraction.cpp` / `.h` | Blank subtraction | `core/src/nta/` |
| `src/core/nta/nta_componentization.cpp` / `.h` | Component creation | `core/src/nta/` |
| `src/core/nta/nta_correction_algorithms.cpp` / `.h` | Matrix-suppression correction | `core/src/nta/` |
| `src/core/nta/nta_deconvolution.cpp` / `.h` | Deconvolution support | `core/src/nta/` |
| `src/core/nta/nta_filters.cpp` / `.h` | Feature, suspect, and standard filtering | `core/src/nta/` |
| `src/core/nta/nta_gap_filling.cpp` / `.h` | Feature gap filling | `core/src/nta/` |
| `src/core/nta/nta_metfrag_runner.cpp` / `.h` | MetFrag external-tool integration | Core external-tool adapter, not a binding implementation |
| `src/core/nta/nta_suspect_screening.cpp` / `.h` | Suspect and internal-standard screening | `core/src/nta/` |

### Native utilities and adapters

| Path | Role | Initial target |
| --- | --- | --- |
| `bindings/r/src/core/asm/file.cpp` / `.h` | ASM file representation | `core/src/data/asm/` |
| `bindings/r/src/core/asm/reader.cpp` / `.h` | ASM reader | `core/src/data/asm/` |
| `bindings/r/src/core/asm/writer.cpp` / `.h` | ASM writer | `core/src/data/asm/` |
| `bindings/r/src/core/json/json.cpp` / `.h` | JSON/native conversion helpers | `core/src/data/` and private headers |
| `bindings/r/src/core/external/simdutf_wrapper.cpp` | UTF-8 acceleration wrapper | `core/src/external/` |
| `bindings/r/src/core/external/openbabel_adapter.cpp` / `.h` | OpenBabel-facing chemistry operations | `core/src/chemistry/` |

## Rcpp Entry Points

There are 86 `Rcpp::export` attributes across the active sources. The
generated `src/RcppExports.cpp` and `R/RcppExports.R` are generated files and
must not be manually edited.

| File | Classification | Future handling |
| --- | --- | --- |
| `bindings/r/src/rcpp_project_export.cpp` | Project lifecycle, metadata, workflow, cache, audit, table access, MassSpec access, and conversion | Move domain operations to core; retain thin R conversion/lifecycle wrappers |
| `bindings/r/src/rcpp_project_nta_export.cpp` | NTA feature operations, processing, screening, and result conversion | Move orchestration/algorithms to core; retain R data conversion |
| `bindings/r/src/rcpp_utils.cpp` | Base64/binary helpers, reader utilities, OpenBabel-facing helpers, external-tool support | Classify each function during extraction; domain utilities belong in core |
| `bindings/r/src/rcpp_tests.cpp` | Native test/debug exports callable from R | Replace with native tests where possible; preserve only compatibility diagnostics needed by R |
| `bindings/r/src/RcppExports.cpp` | Generated `.Call` registration and wrappers | Regenerate from attributes after any binding changes |

The key Phase 0 conclusion is that the current Rcpp layer is not thin. It
contains SQL operations, project initialization and validation, reader access,
workflow handling, NTA orchestration, and result shaping. This is an extraction
map, not a reason to change the current R package before relocation.

## R Method Inventory

The current `Method` object is an R metadata contract with required preceding
methods, owning class, occurrence limits, developer/reference metadata, and
parameter defaults. It is defined in `R/class_Method.R` and specialized
constructors are in the following files.

### MassSpec chromatograms

- `Method_MassSpecChromatograms_LoadChromatograms`
- `Method_MassSpecChromatograms_FilterChromatogramsRetentionTime`

Source: `R/class_MethodsMassSpecChromatograms.R`.

### NTA

- `FindFeatures`
- `LoadFeaturesMS1`
- `LoadFeaturesMS2`
- `CreateComponents`
- `AnnotateComponents`
- `GroupFeatures`
- `FillFeatures`
- `BlankSubtraction`
- `CorrectMatrixSuppression`
- `FilterFeatures`
- `SuspectScreening`
- `FindInternalStandards`
- `FilterSuspects`
- `FilterInternalStandards`
- `FilterFeaturesMS2`
- `MetFragScreening`
- `AssignTransformationProducts`

Source: `R/class_MethodsNonTargetAnalysis.R`.

These names are the initial behavior catalogue. Canonical operation IRIs,
typed ports, versioning, and native validation are later migration work.

## Reader Inventory

The dispatch list is declared in `src/core/mass_spec/reader.h` and currently
contains:

| Format | Representative fixture |
| --- | --- |
| mzML | `E:/example_files/raw_vendor_files/shimadzu/karl.mzML` |
| mzXML | No committed representative fixture identified in the initial scan |
| Shimadzu TXT | `E:/example_files/raw_vendor_files/shimadzu/karl.txt`, `E:/example_files/raw_vendor_files/shimadzu/adc.txt` |
| ASC | No committed representative fixture identified in the initial scan |
| Shimadzu LCD | `E:/example_files/raw_vendor_files/shimadzu/karl.lcd`, `E:/example_files/raw_vendor_files/shimadzu/adc.lcd` |

Reader support also includes base64, little/big-endian numeric decoding, zlib
compression, SIMD UTF-8 handling, and OLE compound-file stream access.

## DuckDB Schema Ownership

| Table | Definition path | Owner |
| --- | --- | --- |
| `PROJECT` | `src/core/project/project.cpp` | Generic project |
| `CACHE` | `src/core/project/project.cpp` | Generic project |
| `AUDIT_TRAIL` | `src/core/project/project.cpp` | Generic project |
| `MS_ANALYSES` | `src/core/mass_spec/mass_spec.cpp` | MassSpec |
| `MS_SPECTRA_HEADERS` | `src/core/mass_spec/mass_spec.cpp` | MassSpec |
| `MS_CHROMATOGRAMS_HEADERS` | `src/core/mass_spec/mass_spec.cpp` | MassSpec |
| `MS_CHROMATOGRAMS` | `src/core/mass_spec/processing.cpp` | Chromatograms |
| `NTA_FEATURES` | `src/core/nta/nta.cpp` | NTA |
| `NTA_INTERNAL_STANDARDS` | `src/core/nta/nta.cpp` | NTA |
| `NTA_SUSPECTS` | `src/core/nta/nta.cpp` | NTA |
| `NTA_TRANSFORMATION_PRODUCTS` | `src/core/nta/nta.cpp` | NTA |

Current schema behavior is `CREATE TABLE IF NOT EXISTS`, plus targeted repair of
the `PROJECT.domain` column. SQL remains embedded in the owning native domain
files and is the behavior to preserve during extraction.

## External Dependencies

### Native

- DuckDB, headers and platform libraries under `bindings/r/src/core/external/duckdb`
- OpenBabel 3.2.0 and InChI under `bindings/r/src/core/external/openbabel`
- zlib under `bindings/r/src/core/external/zlib/zlib-develop`
- pugixml under `bindings/r/src/core/external/pugixml-1.14`
- simdutf under `bindings/r/src/core/external/simdutf`
- nlohmann/json under `bindings/r/src/core/external/nlohmann`
- JSON Schema Validator under `bindings/r/src/core/external/json-schema-validator`
- Optional OpenMP

### Binding and application

- R >= 4.3, Rcpp, R6, DBI, duckdb, data.table, checkmate, jsonlite, and the
  remaining packages declared in `DESCRIPTION`
- CMake >= 3.20 and a C++17-compatible compiler
- Python, `cf-package-contracts`, and Cogniflow step tooling for the current
  `cf_streamfind_steps` target
- Shiny, golem, plotly, DT, Quarto/R Markdown, and related packages for the
  current application and reports

## Current Build Inputs

| Build input | Behavior |
| --- | --- |
| `bindings/r/src/Makevars` | Linux/macOS R package compilation, OpenBabel static archives, zlib, DuckDB static library |
| `bindings/r/src/Makevars.win` | Windows R package compilation, OpenBabel and DuckDB DLL handling |
| Root `CMakeLists.txt` | Cogniflow extension target, vendored dependencies, generated signature header, runtime/resource installation |
| `bindings/r/src/core/cmake/ExternalDependencies.cmake` | Platform tag and imported DuckDB target configuration |
| `pyproject.toml` | Current Python/Cogniflow packaging metadata |

The R package build remains controlled by its package-local `Makevars` files.
The relocated Cogniflow CMake project resolves shared native sources from
`bindings/r/src/core` and writes integration artifacts under
`integrations/cf-streamfind`. Its dependencies are intentionally unresolved in
Phase 1.

## Baseline Fixtures and Checks

Use the following external Shimadzu fixtures where available:

- `E:/example_files/raw_vendor_files/shimadzu/karl.mzML`
- `E:/example_files/raw_vendor_files/shimadzu/karl.txt`
- `E:/example_files/raw_vendor_files/shimadzu/adc.txt`
- `E:/example_files/raw_vendor_files/shimadzu/karl.lcd`
- `E:/example_files/raw_vendor_files/shimadzu/adc.lcd`
- NTA CSV templates under `bindings/r/dev/dev_duckdb/`

The complete root `dev/` tree, including legacy code storage, is treated as
R-package development material and moves with the package. In particular,
`dev/legacy_code_refactoring_to_project_classes_2/` is retained under
`bindings/r/dev/` until a later explicit decision changes its ownership.

Record stable summaries rather than full binary output:

- project table names and columns;
- analysis count and metadata;
- reader format, scan/chromatogram counts, and retention-time range;
- chromatogram row counts and selected values;
- NTA feature/result counts;
- workflow JSON and cache/audit row summaries.

Minimum checks are project create/open/validate/close, schema initialization,
analysis import, reader dispatch, workflow serialization, one chromatogram
operation, and one NTA checkpoint. These checks establish the behavior to
compare after the Phase 1 move; they do not require creating a second Rcpp
inventory document.
