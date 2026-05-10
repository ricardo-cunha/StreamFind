**Phase 4 Report**
Scope implemented
- Corrected the phase 4 architecture so NTS shared-table access is owned by `src/nts/project_non_target_analysis.h/.cpp`, not by R-side DuckDB helpers.
- Expanded the project-owned shared NTS schemas in C++ to cover the legacy NTA table families:
  - `NTS_FEATURES`
  - `NTS_INTERNAL_STANDARDS`
  - `NTS_SUSPECTS`
  - `NTS_TRANSFORMATION_PRODUCTS`
- Kept the `ProjectNonTargetAnalysis` facade get-only for table access; writes are expected to come from NTS processing methods rather than `set_*` project APIs.
- Migrated the first legacy feature-table methods from `R/class_MassSpecResults_NonTargetAnalysis.R` onto `R/class_ProjectNonTargetAnalysis.R` on top of that native boundary.
- Added project-owned processing methods on `PROJECT_NON_TARGET_ANALYSIS` and `ProjectNonTargetAnalysis` for feature finding, suspect screening, and internal-standard persistence.
- Exposed the remaining low-level `src/nts` processing surface through `PROJECT_NON_TARGET_ANALYSIS`, with project-owned methods that update shared NTS tables instead of returning result-object-local persistence outputs.

Files changed
- `R/class_ProjectNonTargetAnalysis.R`
- `src/nts/project_non_target_analysis.h`
- `src/nts/project_non_target_analysis.cpp`
- `src/rcpp_nts_export.cpp`
- `src/RcppExports.cpp`
- `R/RcppExports.R`
- `NAMESPACE`
- `man/ProjectNonTargetAnalysis.Rd`
- `man/ProjectNonTargetAnalysisS3.Rd`
- `.ai_plan/phase_4_nts_storage_and_processing_migration_report.md`

Schema/API changes
- `nts::PROJECT_NON_TARGET_ANALYSIS` now owns creation and validation of the shared project NTS tables in C++:
  - `NTS_FEATURES`
  - `NTS_INTERNAL_STANDARDS`
  - `NTS_SUSPECTS`
  - `NTS_TRANSFORMATION_PRODUCTS`
- `nts::PROJECT_NON_TARGET_ANALYSIS` now exposes project-owned feature-table read accessors through `src/nts/project_non_target_analysis.h`:
  - `get_features(...)`
  - `get_features_count(...)`
- `nts::PROJECT_NON_TARGET_ANALYSIS` now exposes project-owned processing entrypoints through `src/nts/project_non_target_analysis.h`:
  - `find_features(...)`
  - `load_features_ms1(...)`
  - `load_features_ms2(...)`
  - `create_components(...)`
  - `annotate_components(...)`
  - `group_features(...)`
  - `fill_features(...)`
  - `blank_subtraction(...)`
  - `filter_features(...)`
  - `suspect_screening(...)`
  - `find_internal_standards(...)`
  - `filter_suspects(...)`
  - `filter_internal_standards(...)`
  - `filter_features_ms2(...)`
  - `metfrag_screening(...)`
  - `assign_transformation_products(...)`
- Added project NTS Rcpp exports for the read facade:
  - `rcpp_project_non_target_analysis_get_features(...)`
  - `rcpp_project_non_target_analysis_get_features_count(...)`
  - `rcpp_project_non_target_analysis_get_suspects(...)`
  - `rcpp_project_non_target_analysis_get_internal_standards(...)`
  - `rcpp_project_non_target_analysis_get_transformation_products(...)`
- Added project NTS Rcpp exports for project-owned processing:
  - `rcpp_project_non_target_analysis_find_features(...)`
  - `rcpp_project_non_target_analysis_load_features_ms1(...)`
  - `rcpp_project_non_target_analysis_load_features_ms2(...)`
  - `rcpp_project_non_target_analysis_create_components(...)`
  - `rcpp_project_non_target_analysis_annotate_components(...)`
  - `rcpp_project_non_target_analysis_group_features(...)`
  - `rcpp_project_non_target_analysis_fill_features(...)`
  - `rcpp_project_non_target_analysis_blank_subtraction(...)`
  - `rcpp_project_non_target_analysis_filter_features(...)`
  - `rcpp_project_non_target_analysis_suspect_screening(...)`
  - `rcpp_project_non_target_analysis_find_internal_standards(...)`
  - `rcpp_project_non_target_analysis_filter_suspects(...)`
  - `rcpp_project_non_target_analysis_filter_internal_standards(...)`
  - `rcpp_project_non_target_analysis_filter_features_ms2(...)`
  - `rcpp_project_non_target_analysis_metfrag_screening(...)`
  - `rcpp_project_non_target_analysis_assign_transformation_products(...)`
- `ProjectNonTargetAnalysis` now routes feature-table reads through the native NTS facade instead of `DBI`/`duckdb` calls from R.
- Removed the accidental project write API:
  - `set_features(value)`
- Simplified the NTS processing-step registry so each `ProcessingStep` now uses the owning `ProjectNonTargetAnalysis` method name directly as `method`, for example `find_features` and `group_features`, instead of carrying a separate dispatch field.
- Updated `.project_non_target_analysis_processing_methods()` so the registry keys also match the owning project method names directly.
- Updated workflow execution to dispatch via `step$method` on the active project object instead of a separate `project_method` field.
- Added migrated project-owned methods on `ProjectNonTargetAnalysis`:
  - `find_features(...)`
  - `load_features_ms1(...)`
  - `load_features_ms2(...)`
  - `create_components(...)`
  - `annotate_components(...)`
  - `group_features(...)`
  - `fill_features(...)`
  - `blank_subtraction(...)`
  - `filter_features(...)`
  - `suspect_screening(...)`
  - `find_internal_standards(...)`
  - `filter_suspects(...)`
  - `filter_internal_standards(...)`
  - `filter_features_ms2(...)`
  - `metfrag_screening(...)`
  - `assign_transformation_products(...)`
  - `get_features(analyses = NULL, filtered = FALSE)`
  - `get_features_profile(...)`
  - `get_features_count(analyses = NULL, filtered = FALSE)`
  - `get_suspects(...)`
  - `get_internal_standards(...)`
  - `get_transformation_products(...)`
  - `get_fold_change(...)`
  - `info()`
  - `plot_features_count(...)`
  - `plot_features_profile(...)`
  - `plot_features(...)`
  - `map_features(...)`
  - `plot_features_ms1(...)`
  - `plot_features_ms2(...)`
  - `plot_suspects_ms2(...)`
  - `plot_fold_change(...)`
  - `plot_transformation_products(...)`
- Added S3 wrappers for the migrated project-owned methods:
  - `info.ProjectNonTargetAnalysis`
  - `get_features.ProjectNonTargetAnalysis`
  - `get_features_profile.ProjectNonTargetAnalysis`
  - `get_features_count.ProjectNonTargetAnalysis`
  - `get_suspects.ProjectNonTargetAnalysis`
  - `get_internal_standards.ProjectNonTargetAnalysis`
  - `get_transformation_products.ProjectNonTargetAnalysis`
  - `get_fold_change.ProjectNonTargetAnalysis`
  - `plot_features_count.ProjectNonTargetAnalysis`
  - `plot_features_profile.ProjectNonTargetAnalysis`
  - `plot_features.ProjectNonTargetAnalysis`
  - `map_features.ProjectNonTargetAnalysis`
  - `plot_features_ms1.ProjectNonTargetAnalysis`
  - `plot_features_ms2.ProjectNonTargetAnalysis`
  - `plot_suspects_ms2.ProjectNonTargetAnalysis`
  - `plot_fold_change.ProjectNonTargetAnalysis`
  - `plot_transformation_products.ProjectNonTargetAnalysis`

- `get_suspects(...)` and `get_internal_standards(...)` now push selector and target matching into native project code, including:
  - `features`
  - `groups`
  - target-table inputs built from `mass` / `mz` / `rt` / `mobility`
  - `ppm`
  - `sec`
  - `millisec`
- `get_features(...)` on `ProjectNonTargetAnalysis` now restores the broader legacy selector surface in R on top of native feature rows, including:
  - `features`
  - `groups`
  - `components`
  - `mass`
  - `mz`
  - `rt`
  - `mobility`
  - `ppm`
  - `sec`
  - `millisec`
  - `filtered`

Verification performed
- Regenerated exports with `Rscript -e "Rcpp::compileAttributes()"`.
- Regenerated documentation/NAMESPACE with `Rscript -e "roxygen2::roxygenise()"`.
- Ran `Rscript -e "devtools::load_all('.')"` successfully after the NTS facade changes.
- Re-ran the same sequential validation after adding the project-owned `find_features(...)`, `suspect_screening(...)`, and `find_internal_standards(...)` methods.
- Re-ran the same sequential validation after exposing the remaining project-owned NTS processing methods and table-updating persistence paths.
- Re-ran the same sequential validation after migrating the shared-table query surface for suspects, internal standards, and transformation products.
- Re-ran the same sequential validation after migrating fold-change helpers and the remaining large R-only plotting methods onto `ProjectNonTargetAnalysis`.
- Fixed the final migration cleanup issues found by roxygen:
  - missing `plot_transformation_products.ProjectNonTargetAnalysis` S3 wrapper
  - missing `showText` parameter documentation on migrated `plot_features_ms1(...)`, `plot_features_ms2(...)`, and `plot_suspects_ms2(...)`
- Removed the shadowed duplicate legacy `get_internal_standards.MassSpecResults_NonTargetAnalysis` definition so the file now contains only the later, fuller implementation.
- Re-ran sequential validation after the legacy duplicate cleanup:
  - `Rscript -e "roxygen2::roxygenise()"`
  - `Rscript -e "devtools::load_all('.')"`
- Re-ran `Rscript -e "devtools::load_all('.')"` after simplifying `ProcessingStep` dispatch metadata and renaming the NTS registry keys to project method names.

Rcpp exports regenerated
- `src/RcppExports.cpp`
- `R/RcppExports.R`

devtools::load_all status
- Passed
- Safe validation sequence used:
  - `Rscript -e "Rcpp::compileAttributes()"`
  - `Rscript -e "roxygen2::roxygenise()"`
  - `Rscript -e "devtools::load_all('.')"`

Documentation updated
- Expanded roxygen for `ProjectNonTargetAnalysis` to include the migrated feature accessors and S3 wrappers.
- Updated the generated Rd topics for `ProjectNonTargetAnalysis` and `ProjectNonTargetAnalysisS3`.
- Kept NTS project ownership documented in `src/nts/project_non_target_analysis.h`.

Known gaps
- Project-owned writes now exist for `NTS_FEATURES`, `NTS_SUSPECTS`, `NTS_INTERNAL_STANDARDS`, and `NTS_TRANSFORMATION_PRODUCTS`.
- The base shared-table reads for suspects, internal standards, and transformation products are now migrated to `PROJECT_NON_TARGET_ANALYSIS`, but higher-level plotting/shaping helpers still remain intentionally R-side.
- `R/class_MassSpecResults_NonTargetAnalysis.R` remains active and cannot be removed yet because it is still a public legacy class and downstream callers may still depend on its file-backed API.
- Additional method removal from `R/class_MassSpecResults_NonTargetAnalysis.R` is intentionally deferred until downstream callers are migrated; beyond the duplicate cleanup, removing those methods now would be a breaking change.
- `ProcessingStep` still retains optional `algorithm` and legacy-style `constructor_name` metadata for compatibility/UI naming, even though workflow dispatch now uses only `method`.

Next recommended steps
1. Inventory what still remains active in `R/class_MassSpecResults_NonTargetAnalysis.R` after the project-layer migration and remove any now-stale duplicated methods.
2. Decide whether the restored legacy selector compatibility in `ProjectNonTargetAnalysis$get_features(...)` should stay R-side or be moved deeper into native project queries.
3. Decide whether internal-standard finding should remain suspect-screening-backed orchestration or gain its own lower-level `src/nts` entrypoint.
4. Extend the same method-name-only registry/dispatch convention to any future spectra/chromatogram processing registries so all project classes share one workflow contract.
5. Update downstream callers/app code to use `ProjectNonTargetAnalysis` instead of the legacy result wrapper where possible.
6. Once legacy callers are updated, remove `R/class_MassSpecResults_NonTargetAnalysis.R` and associated stale compatibility code.
