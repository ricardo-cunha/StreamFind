**Phase 2 Report**
Scope implemented
- Refactored the Mass Spec architecture toward the new shared-base plus domain-specific project-class model.
- Kept `ProjectMassSpec` as the shared/internal Mass Spec R/C++ base for import, analyses metadata, and shared raw/header access.
- Added native-backed public Mass Spec child classes:
  - `ProjectMassSpecSpectra`
  - `ProjectMassSpecChromatograms`
- Added dedicated native C++ Mass Spec facade types:
  - `mass_spec::PROJECT_MASS_SPEC_SPECTRA`
  - `mass_spec::PROJECT_MASS_SPEC_CHROMATOGRAMS`
- Moved domain ownership out of the shared `PROJECT_MASS_SPEC` base so concrete project child classes can own domain-specific project rows.
- Updated NTS domain initialization to use the new `mass_spec_nts` domain code.
- Updated project-domain validation so the root project layer accepts the new domain-specific project codes:
  - `mass_spec_spectra`
  - `mass_spec_chromatograms`
  - `mass_spec_nts`
- Kept active DB interaction and authoritative state management in C++ while leaving downstream plotting/data-shaping helpers in R.

Files changed
- `src/project/project.cpp`
- `src/mass_spec/project_mass_spec.cpp`
- `src/mass_spec/project_mass_spec_spectra.h`
- `src/mass_spec/project_mass_spec_spectra.cpp`
- `src/mass_spec/project_mass_spec_chromatograms.h`
- `src/mass_spec/project_mass_spec_chromatograms.cpp`
- `src/rcpp_mass_spec_export.cpp`
- `src/nts/project_non_target_analysis.cpp`
- `R/class_ProjectMassSpec.R`
- `R/class_ProjectMassSpecSpectra.R`
- `R/class_ProjectMassSpecChromatograms.R`
- `R/class_ProjectNonTargetAnalysis.R`
- `R/class_ProcessingStep.R`
- `R/class_Workflow.R`
- `R/app_mod_Workflow.R`
- `R/utils_general.R`
- `DESCRIPTION`
- `src/RcppExports.cpp`
- `R/RcppExports.R`
- `NAMESPACE`
- `man/ProcessingStep.Rd`
- `man/Workflow.Rd`
- `man/ProjectMassSpec.Rd`
- `man/ProjectMassSpecSpectra.Rd`
- `man/ProjectMassSpecChromatograms.Rd`
- `man/ProjectNonTargetAnalysis.Rd`
- `.ai_plan/phase_2_mass_spec_storage_unification_report.md`

Schema/API changes
- The root native project layer now accepts domain-specific project codes in addition to the older generic domains.
- `mass_spec::PROJECT_MASS_SPEC` no longer force-sets a broad `MS` domain on construction.
- `mass_spec::PROJECT_MASS_SPEC_SPECTRA` now sets the project row domain to `mass_spec_spectra`.
- `mass_spec::PROJECT_MASS_SPEC_CHROMATOGRAMS` now sets the project row domain to `mass_spec_chromatograms`.
- `nts::PROJECT_NON_TARGET_ANALYSIS` now sets the project row domain to `mass_spec_nts`.
- Added new Mass Spec Rcpp constructors:
  - `rcpp_project_mass_spec_spectra_new(SEXP project_xptr)`
  - `rcpp_project_mass_spec_chromatograms_new(SEXP project_xptr)`
- Added new spectra-native Rcpp accessors:
  - `rcpp_project_mass_spec_spectra_get_spectra_tic(...)`
  - `rcpp_project_mass_spec_spectra_get_raw_spectra(...)`
- Added new chromatogram-native Rcpp accessor:
  - `rcpp_project_mass_spec_chromatograms_extract(...)`
- Added new R6 wrappers:
  - `ProjectMassSpecSpectra`
  - `ProjectMassSpecChromatograms`
- Restored lightweight package-owned `ProcessingStep` and `Workflow` compatibility objects so the active package once again provides the metadata shape used by the workflow editor.
- Moved chromatogram-facing public R6/S3 methods off `ProjectMassSpec` and onto `ProjectMassSpecChromatograms`:
  - `get_chromatograms_headers(...)`
  - `get_chromatograms(...)`
  - `plot_chromatograms(...)`
- `ProjectNonTargetAnalysis` continues to inherit from the shared `ProjectMassSpec` base so NTS remains attached to the generic/shared Mass Spec layer rather than a spectra-specific public child class.
- Updated processing owner inference in `R/utils_general.R` so chromatogram/spectra-oriented classes resolve to:
  - `ProjectMassSpecChromatograms`
  - `ProjectMassSpecSpectra`
- Added `available_processing_methods()` to the project hierarchy as the new project-owned registry entry point.
- Implemented a populated NTS registry on `ProjectNonTargetAnalysis` that returns ProcessingStep-compatible metadata objects enriched with:
  - legacy ProcessingStep fields (`type`, `method`, `required`, `algorithm`, `owner_class`, `input_class`, `output_class`, `number_permitted`, `version`, `software`, `developer`, `contact`, `link`, `doi`, `parameters`)
  - dispatch/identity metadata (`constructor_name`)
  - documentation metadata (`title`, `description`, `details`, `parameter_docs`)
- Updated the workflow UI to consume project-owned processing metadata directly instead of relying on missing legacy constructor functions for active package paths.
- Audited `R/utils_general.R` against active-package callers and removed legacy-only helpers that were no longer referenced outside `dev/` reference code.
- Confirmed `ProjectMassSpecSpectra` and `ProjectMassSpecChromatograms` should currently keep empty `available_processing_methods()` registries because they expose extraction/plotting APIs but do not yet own project-processing workflow steps.
- Added `Project$run_processing_step()` and `Project$run_workflow()` so stored workflow steps dispatch through each step's `method` on the active project object.
- Updated the workflow module to use project-native `workflow` storage only and to invoke `run_workflow()` on the active project object.
- Added `Project$report_quarto()` and `Project$run_app()` so app/report entry points now live on the shared internal project runtime rather than the legacy engine class.
- Refactored the main Shiny app bootstrap to open only public project classes:
  - `ProjectMassSpecSpectra`
  - `ProjectMassSpecChromatograms`
  - `ProjectNonTargetAnalysis`
- Updated app modules and S3 bindings so the analyses, explorer, workflow, report, and NTA results tabs can bind directly to project-class objects.
- Replaced the old `DataTypeObjects()` engine/data-type registry with a public `ProjectClasses()` registry that describes the supported project child classes, their domains, file formats, user-facing labels/descriptions, and available processing-method metadata.
- Removed `DataTypeObjects()` from the active package surface so `ProjectClasses()` is now the single overview registry for public project types.
- Refactored `ProjectNonTargetAnalysis` processing methods so execution-oriented methods now return `TRUE/FALSE` instead of returning result rows directly.
- Updated the NTA R/C++ bridge so persisted outputs are read back through getters such as:
  - `get_features()`
  - `get_features_count()`
  - `get_suspects()`
  - `get_internal_standards()`
  - `get_transformation_products()`
- Added cache-aware NTA execution keyed by both effective method parameters and relevant upstream persisted Mass Spec/NTA state.
- Implemented cache-hit restoration of persisted DuckDB tables so cached NTA steps restore stored table state instead of only skipping recomputation.
- Moved reusable generic cache payload/hash/JSON store-restore helpers out of `src/nts/project_non_target_analysis.cpp` into the shared project cache layer:
  - `src/project/cache.h`
  - `src/project/cache.cpp`
- Kept only NTA-specific persisted-table snapshot logic in `src/nts/project_non_target_analysis.cpp`.

Verification performed
- `Rscript -e "devtools::load_all('.')"`
- Re-ran `Rscript -e "devtools::load_all('.')"` after the `R/utils_general.R` dead-helper cleanup and confirmed the package still loads cleanly.
- Re-ran `Rscript -e "devtools::load_all('.')"` after adding project-native workflow dispatch and confirmed the package still loads cleanly.
- Re-ran `Rscript -e "devtools::load_all('.')"` after switching the app bootstrap to project classes and confirmed the package still loads cleanly.
- Re-ran `Rscript -e "devtools::load_all('.')"` after the NTA `TRUE/FALSE` return change and shared cache-helper migration and confirmed the package loads cleanly.
- Confirmed that concurrent regeneration/compile runs can interfere with incremental Windows builds; compile verification should be run via `devtools::load_all('.')` only.

Rcpp exports regenerated
- Yes.

devtools::load_all status
- Passed after the NTA cache refactor and export regeneration. Final compile verification was run with `devtools::load_all('.')` only.

Documentation updated
- Updated `ProjectMassSpec` roxygen description to reflect its new role as the shared/internal Mass Spec base.
- Added roxygen documentation for:
  - `ProcessingStep`
  - `Workflow`
  - `ProjectMassSpecSpectra`
  - `ProjectMassSpecChromatograms`
- Regenerated `NAMESPACE` and Rd files.

Known gaps
- `ProjectMassSpec` still carries shared spectra-facing helpers and shared metadata/base access; only the chromatogram-facing public surface has been trimmed so far.
- `Project` and `ProjectMassSpec` remain internal runtime/base classes; the app startup now exposes only the public project wrappers, but these internal classes are still exported in package metadata and should be hidden from end users in a later cleanup step.
- The new child classes currently wrap dedicated native constructors, but shared raw spectra access remains intentionally on `ProjectMassSpec`; processed-table ownership for `MS_SPECTRA*` and `MS_CHROMATOGRAMS*` is not yet implemented.
- `available_processing_methods()` is currently populated only for `ProjectNonTargetAnalysis`; `ProjectMassSpecSpectra` and `ProjectMassSpecChromatograms` intentionally still return empty registries because they do not yet own project-processing workflow steps.
- The app shell is now project-first, but some non-NTA result views and cache-management UI still reflect the older engine/results architecture and need follow-up cleanup or replacement.
- `NAMESPACE` still contains many stale exports/S3 registrations from absent legacy R sources; this did not block `load_all()`, but it remains cleanup work for later phases.
- Export/doc regeneration is still required when native/Rcpp interfaces change, but compile validation should continue to use `devtools::load_all('.')` as the only compile path.

Next recommended steps
- Implement spectra-specific and chromatogram-specific processed-table schema owners in C++.
- Move/implement spectra-specific processed-table methods on `ProjectMassSpecSpectra` while keeping shared raw spectra access on `ProjectMassSpec` for reuse by both `ProjectMassSpecSpectra` and `ProjectNonTargetAnalysis`.
- Populate `available_processing_methods()` on `ProjectMassSpecSpectra` and `ProjectMassSpecChromatograms` using the same harmonized ProcessingStep-compatible metadata shape now used for NTS.
- Hide internal `Project` / `ProjectMassSpec` classes from the user-facing package/app surface and continue trimming engine-era UI labels, stale exports, and non-project result modules.
