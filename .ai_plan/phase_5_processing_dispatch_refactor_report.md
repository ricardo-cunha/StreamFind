**Phase 5 Report**
Scope implemented
- Simplified workflow processing metadata so `ProcessingStep$method` is now the single canonical runtime dispatch key.
- Removed the redundant `project_method` field from active `ProcessingStep` metadata and from workflow dispatch.
- Updated the active NTS processing registry to use owning `ProjectNonTargetAnalysis` method names directly for:
  - registry keys
  - `ProcessingStep$method`
  - dependency declarations in `required`
- Kept `algorithm` and `constructor_name` only as optional compatibility/display metadata rather than runtime dispatch inputs.

Files changed
- `R/class_ProcessingStep.R`
- `R/utils_general.R`
- `R/class_Project.R`
- `R/class_Workflow.R`
- `R/class_ProjectClasses.R`
- `R/app_mod_Workflow.R`
- `R/class_ProjectNonTargetAnalysis.R`
- `.ai_plan/phase_5_processing_dispatch_refactor_report.md`

Schema/API changes
- `ProcessingStep$method` now matches the owning project child method name and is the authoritative workflow dispatch field.
- `Project$run_processing_step()` now dispatches via `self[[step$method]]`.
- `.project_non_target_analysis_processing_methods()` now uses direct project method names for all active entries, including:
  - `find_features`
  - `load_features_ms1`
  - `load_features_ms2`
  - `create_components`
  - `annotate_components`
  - `group_features`
  - `fill_features`
  - `blank_subtraction`
  - `filter_features`
  - `filter_features_ms2`
  - `suspect_screening`
  - `metfrag_screening`
  - `find_internal_standards`
  - `filter_suspects`
  - `filter_internal_standards`
  - `assign_transformation_products`
- `ProjectClasses()$processing_methods` now reflects the same direct method-name surface.
- Workflow list entry names no longer depend on `algorithm` for identity.

Verification performed
- Ran `Rscript -e "devtools::load_all('.')"` after simplifying `ProcessingStep` dispatch metadata.
- Re-ran `Rscript -e "devtools::load_all('.')"` after renaming the NTS registry keys to direct project method names.

Rcpp exports regenerated
- No

devtools::load_all status
- Passed

Documentation updated
- Updated the `ProcessingStep` roxygen contract to describe `method` as the owning project child method name.
- Updated the phase reports to reflect the simplified workflow/registry contract.

Known gaps
- Only `ProjectNonTargetAnalysis` currently exposes a populated processing registry; `ProjectMassSpecSpectra` and `ProjectMassSpecChromatograms` still return empty registries.
- `algorithm` and `constructor_name` remain in `ProcessingStep` for compatibility/UI purposes and may be removable later if no active path depends on them.
- The workflow UI still presents compatibility-oriented metadata and may benefit from a smaller project-first presentation pass later.

Next recommended steps
1. Implement spectra and chromatogram processing registries using the same method-name-only convention.
2. Audit workflow serialization and UI code to confirm no remaining path depends on compatibility-only `algorithm` naming.
3. Continue migrating remaining legacy callers away from result-wrapper and engine-era processing paths.
4. Remove compatibility metadata from `ProcessingStep` only after confirming no active workflow/app path still uses it.
