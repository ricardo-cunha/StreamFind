# Current Architecture Baseline

Status: Phase 1 relocation baseline

This document records the current repository boundaries after the Phase 1
filesystem relocation. The R implementation remains intact and is now rooted
at `bindings/r`; that directory is the R package root for all package commands.

## Repository Shape

The current repository is one R package with native C++ sources and a Python
Cogniflow extension build embedded in the root CMake project.

| Area | Current location | Current responsibility | Phase 1 destination |
| --- | --- | --- | --- |
| R package | `bindings/r/DESCRIPTION`, `bindings/r/NAMESPACE`, `bindings/r/R/`, `bindings/r/src/`, `bindings/r/inst/`, `bindings/r/tests/`, `bindings/r/man/`, `bindings/r/man-roxygen/`, `bindings/r/vignettes/`, `bindings/r/data/` or `data-raw/` when present | Public R API, R6/S3 models, Shiny app, Rcpp boundary, native build inputs | `bindings/r/` |
| R package metadata and documentation | `bindings/r/.Rbuildignore`, `bindings/r/_pkgdown.yml`, `bindings/r/pkgdown/`, package README/assets, generated or authored package documentation | R package build exclusion rules, pkgdown site, reference/documentation inputs | `bindings/r/` |
| R package development, Docker, and legacy assets | Entire `bindings/r/dev/` tree, `bindings/r/Dockerfile`, `bindings/r/DOCKER_OVERVIEW.md`, `bindings/r/.dockerignore`, including experiments and legacy code storage | Package development, Docker image, demonstrations, reports, local build support, and retained historical implementation context | `bindings/r/` |
| Native domain code | `bindings/r/src/core/` | Project persistence, readers, MassSpec, NTA, algorithms, native utilities | `core/src/` and `core/include/` |
| Rcpp exports | `bindings/r/src/rcpp_*.cpp`, `bindings/r/src/RcppExports.cpp` | R conversion plus project, storage, reader, and processing orchestration | Thin R binding under `bindings/r/src/` plus core services |
| Cogniflow package | `integrations/cf-streamfind/src/cf_streamfind/` | Cogniflow step contract, native extension, OpenBabel resources, runtime packaging | `integrations/cf-streamfind/` |
| Native build | root `CMakeLists.txt`, `bindings/r/src/Makevars*`, integration CMake | C++17 compilation, DuckDB/OpenBabel/zlib linking, Cogniflow extension output | Root CMake delegating to `core/`, `python/`, and integration targets |
| Database | DuckDB file supplied to project classes | Project, MassSpec, chromatogram, and NTA persistence | Owned by `streamfind-core` |
| User interface | `inst/app/`, `R/app_*.R` | Shiny project, import, exploration, workflow, result, and report screens | React/FastAPI later; preserve during migration |
| Repository-wide infrastructure | Root `README.md`, `LICENSE.md`, contributor guidance, root CMake, CMake presets, CI, shared `docs/`, root `.gitignore`, and cross-language scripts | Repository documentation, shared builds, automation, and migration support | Repository root |
| R-package-local infrastructure | `bindings/r/.gitignore`, `bindings/r/Dockerfile`, `bindings/r/DOCKER_OVERVIEW.md`, `bindings/r/.dockerignore` | R package-specific ignore rules and Docker image build | `bindings/r/` |

The Phase 1 skeleton contains `core/`, `python/`, `server/`, `frontend/`,
`bindings/r/`, and `integrations/`. The files `*.o`,
`bindings/r/src/streamfind.dll`, and other compiled outputs are build artifacts
and are not architectural source units.

## Runtime Flow

```text
R functions and R6/S3 classes
    -> RcppExports.R / RcppExports.cpp
    -> rcpp_project_export.cpp, rcpp_project_nta_export.cpp, rcpp_utils.cpp
    -> bindings/r/src/core native code
    -> DuckDB, readers, algorithms, and external libraries
```

The Cogniflow path is currently separate in packaging but reuses much of the
same native source tree:

```text
integrations/cf-streamfind/src/cf_streamfind
    -> root CMake target cf_streamfind_steps
    -> bindings/r/src/core native sources
    -> DuckDB, OpenBabel, zlib, and other vendored libraries
```

The root CMake project currently exposes the optional
`STREAMFIND_BUILD_CF_STREAMFIND` integration target. The integration target is
`cf_streamfind_steps`; it is not a standalone `streamfind-core` library. CMake
requires `cf-package-contracts` when that option is enabled and configures
DuckDB from `bindings/r/src/core/external/duckdb`.

## Native Ownership Baseline

| Current subsystem | Current owner | Initial target owner | Notes |
| --- | --- | --- | --- |
| Project identity, lifecycle, metadata, cache, audit | `bindings/r/src/core/project/project.cpp` | Core project/storage | Contains DuckDB SQL and current schema upgrade behavior |
| MassSpec project and analysis persistence | `bindings/r/src/core/mass_spec/mass_spec.cpp` | Core MassSpec capability | Creates analysis and header tables |
| File reader dispatch and binary decoding | `bindings/r/src/core/mass_spec/reader.cpp` | Core MassSpec reader services | Supports mzML, mzXML, Shimadzu TXT, ASC, and Shimadzu LCD |
| Chromatogram persistence and processing | `bindings/r/src/core/mass_spec/processing.cpp` | Core chromatogram capability | Creates and queries `MS_CHROMATOGRAMS` |
| NTA persistence and orchestration | `bindings/r/src/core/nta/nta.cpp` | Core NTA capability | Creates NTA tables and coordinates data operations |
| NTA algorithms | `bindings/r/src/core/nta/nta_*.cpp` | Core NTA methods | Keep algorithm logic native; expose through future methods |
| ASM format support | `bindings/r/src/core/asm/` | Core data/format services | Native reader/writer utility with no independent public binding yet |
| JSON support | `bindings/r/src/core/json/` | Core data utilities | Used by native project and binding boundaries |
| OpenBabel adapter | `bindings/r/src/core/external/openbabel_adapter.*` | Core chemistry service | Uses vendored OpenBabel/InChI |
| R conversion and lifecycle | `bindings/r/src/rcpp_*.cpp` | `bindings/r` | Must remain functional during core extraction |
| Shiny UI and reports | `bindings/r/R/app_*.R`, `bindings/r/inst/app/` | R compatibility/application layer | Not core ownership; direct SQL calls need later replacement |
| Cogniflow contract and packaging | `integrations/cf-streamfind/src/cf_streamfind/` | `integrations/cf-streamfind` | Expected to remain non-buildable until dependencies and implementation are refactored |

## R Package Preservation

The root package currently includes package metadata, R sources, Rcpp sources,
native C++ sources, vendored/native build inputs, tests, documentation,
documentation-generation inputs, vignettes, installed assets, and Shiny
resources. The complete package boundary includes:

- `DESCRIPTION`, `NAMESPACE`, `.Rbuildignore`, `MANIFEST.in`, and package
  licence/README metadata;
- `R/`, `src/`, `inst/`, `tests/`, `man/`, `man-roxygen/`, `vignettes/`, and
  any `data/` or `data-raw/` directories;
- `_pkgdown.yml`, `pkgdown/`, and any generated pkgdown output intentionally
  retained in version control;
- the complete root `dev/` tree, including development scripts, Quarto,
  R Markdown, Docker, report assets, experiments, and legacy code storage;
- package build files including `bindings/r/src/Makevars` and
  `bindings/r/src/Makevars.win`.

The package boundary has now moved to `bindings/r` without deleting or
refactoring implementation. Root README, contributor guidance, shared CI,
root CMake, shared Docker/orchestration files, and cross-language
documentation remain at the repository root unless the relocation manifest
proves that a particular file is package-owned.

For the initial relocation, `dev/` is package-owned in its entirety. It moves
to `bindings/r/dev/`, including `dev/legacy_code_refactoring_to_project_classes_2/`.
Later cleanup or promotion of a cross-language utility requires an explicit
ownership decision rather than leaving a second development tree at the root.

The following public R concepts are part of the compatibility baseline:

- R6 classes: `Project`, `ProjectMassSpec`, `ProjectMassSpecSpectra`,
  `ProjectMassSpecChromatograms`, `ProjectNonTargetAnalysis`, and `Workflow`.
- S3 metadata object: `Method`.
- Rcpp-generated API in `R/RcppExports.R` and `src/RcppExports.cpp`.
- Shiny application entry point: `inst/app/app.R` and `R/run_app.R`.
- Reports and development workflows under `vignettes/`, `dev/`, and
  `dev/dev_duckdb/`.

The package's native pointer lifecycle and R exception conversion must continue
to work from `bindings/r` before any domain logic is moved into the standalone
core.

## Database Baseline

The active schema contains these 11 tables:

| Table | Current owner | Definition location |
| --- | --- | --- |
| `PROJECT` | Generic project | `src/core/project/project.cpp` |
| `CACHE` | Generic project | `src/core/project/project.cpp` |
| `AUDIT_TRAIL` | Generic project | `src/core/project/project.cpp` |
| `MS_ANALYSES` | MassSpec | `src/core/mass_spec/mass_spec.cpp` |
| `MS_SPECTRA_HEADERS` | MassSpec | `src/core/mass_spec/mass_spec.cpp` |
| `MS_CHROMATOGRAMS_HEADERS` | MassSpec | `src/core/mass_spec/mass_spec.cpp` |
| `MS_CHROMATOGRAMS` | Chromatograms | `src/core/mass_spec/processing.cpp` |
| `NTA_FEATURES` | NTA | `src/core/nta/nta.cpp` |
| `NTA_INTERNAL_STANDARDS` | NTA | `src/core/nta/nta.cpp` |
| `NTA_SUSPECTS` | NTA | `src/core/nta/nta.cpp` |
| `NTA_TRANSFORMATION_PRODUCTS` | NTA | `src/core/nta/nta.cpp` |

Schema creation uses `CREATE TABLE IF NOT EXISTS`. Existing project handling
also applies a targeted `ALTER TABLE PROJECT ADD COLUMN domain` when required.
There is no formal schema migration table or independent migration framework.
This behavior is preserved as the baseline; it is not redesigned in Phase 0.

Legacy SQL references also exist in development and Shiny code, including
`Analyses`, `Peaks`, and `NTS_*` naming. These are recorded as migration debt
and must not be confused with the active schema above.

## Readers and Processing

The native reader dispatch advertises five formats:

- mzML
- mzXML
- Shimadzu TXT
- ASC
- Shimadzu LCD

The current public processing method inventory contains two MassSpec
chromatogram methods and 17 NTA methods. Their names and owning R files are
recorded in `native-inventory.md`.

## Shiny Workflows

The current application modules are:

1. Workflow assembly and execution: `R/app_mod_Workflow.R`
2. MassSpec analysis import: `R/app_mod_Analyses_MassSpec.R`
3. MassSpec exploration: `R/app_mod_Explorer_MassSpec.R`
4. Chromatogram results: `R/app_mod_Results_ProjectMassSpecChromatograms.R`
5. NTA results: `R/app_mod_Results_ProjectNonTargetAnalysis.R`
6. Report generation: `R/app_mod_Report.R`

These remain operational during migration. The Shiny modules are interface
owners, not owners of the domain schema or future core processing behavior.

## Baseline Commands

The commands to record and rerun before Phase 1 are:

```text
R CMD check .
R CMD build .
devtools::test()
Rscript -e "testthat::test_local()"
cmake -S . -B build
cmake --build build
```

The exact command availability depends on the local R, compiler, CMake,
DuckDB, OpenBabel, and Cogniflow installations. Phase 0 does not change the
build; it records the working baseline and failures.

## Phase 0 Ownership Decision

The minimum sufficient Phase 0 result is this architecture map plus
`native-inventory.md`. The complete R layer does not require a separate
`rcpp-logic-inventory.md` because it is preserved as an atomic package move.
Rcpp/native domain classification is included in the native inventory only to
identify the future extraction seams.
