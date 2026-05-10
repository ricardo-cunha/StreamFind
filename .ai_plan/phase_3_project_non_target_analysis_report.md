**Phase 3 Report**
Scope implemented
- Added the minimal `ProjectNonTargetAnalysis` scaffold in R, C++, and Rcpp.
- Anchored NTS ownership to the shared project DB without attempting the full NTS processing migration yet.
- Established the first NTS-owned table in the shared DB to make schema ownership concrete.

Files changed
- `src/nts/project_non_target_analysis.h`
- `src/nts/project_non_target_analysis.cpp`
- `src/rcpp_nts_export.cpp`
- `R/class_ProjectNonTargetAnalysis.R`
- `DESCRIPTION`
- `R/RcppExports.R`
- `src/RcppExports.cpp`
- `NAMESPACE`
- `man/ProjectNonTargetAnalysis.Rd`

Schema/API changes
- Added new C++ facade:
  - `nts::PROJECT_NON_TARGET_ANALYSIS`
- Added minimal shared-DB NTS schema ownership:
  - `NTS_FEATURES`
- Added new Rcpp constructor export:
  - `rcpp_project_non_target_analysis_new(SEXP project_xptr)`
- Added new R6 class:
  - `ProjectNonTargetAnalysis`
- `ProjectNonTargetAnalysis` inherits `ProjectMassSpec` and owns a native `.nts_ptr` handle.

Verification performed
- Regenerated Rcpp exports with `Rcpp::compileAttributes()`.
- Regenerated roxygen/NAMESPACE with `roxygen2::roxygenise()`.
- Ran `devtools::load_all('.')` successfully after the new facade/class/export were added.
- Confirmed the new wrapper is present in `R/RcppExports.R`.

Rcpp exports regenerated
- Yes
- New export added:
  - `rcpp_project_non_target_analysis_new`

devtools::load_all status
- Passed
- Command used: `Rscript -e "devtools::load_all('.')"`

Documentation updated
- Added roxygen for `ProjectNonTargetAnalysis`.
- Added C++ header documentation for `nts::PROJECT_NON_TARGET_ANALYSIS`.
- Regenerated package docs and namespace.

Known gaps
- `ProjectNonTargetAnalysis` currently provides lifecycle/schema scaffolding only.
- No NTS query/write methods are exposed yet beyond constructor/schema initialization.
- Existing NTS processing still runs through legacy result-object and workflow paths, especially `R/class_MassSpecResults_NonTargetAnalysis.R`.
- No app integration exists yet for the new project child class.
- `NTS_FEATURES` is intentionally minimal and will need to expand during phase 4.
- The intended migration direction is to move methods from `R/class_MassSpecResults_NonTargetAnalysis.R` onto `ProjectNonTargetAnalysis` in the same way Mass Spec-facing methods were centralized on `ProjectMassSpec`.
- The broader legacy retirement target remains to remove `R/class_MassSpecResults_NonTargetAnalysis.R`, `R/class_MassSpecResults_Chromatograms.R`, `R/class_MassSpecResults_Spectra.R`, `R/class_MassSpecEngine.R`, and finally `R/class_MassSpecAnalyses.R` after migration is complete.
- The broader project-framework migration also leaves standalone DB wrapper classes such as `R/class_Results.R`, `R/class_AuditTrail.R`, `R/class_Cache.R`, and `R/class_Analyses.R` as future legacy targets once their active behavior is available through `Project`, `ProjectMassSpec`, or `ProjectNonTargetAnalysis`.
- The master refactor plan now includes an explicit legacy-to-target mapping table, and `MassSpecResults_NonTargetAnalysis -> ProjectNonTargetAnalysis` is the primary phase 4 migration path.

Next recommended steps
1. Start phase 4 by moving one concrete NTS persistence path into `ProjectNonTargetAnalysis`.
2. Move the first public/query/result methods from `R/class_MassSpecResults_NonTargetAnalysis.R` onto `ProjectNonTargetAnalysis` and use that class as the replacement surface.
3. Add explicit `owner_class = "ProjectNonTargetAnalysis"` to NTS `ProcessingStep` constructors instead of relying only on inference.
4. Add the first R-facing query method on `ProjectNonTargetAnalysis` once the NTS table shape is expanded.
5. Start identifying which `Results`, `AuditTrail`, `Cache`, and `Analyses` behaviors should live on `Project` versus which should live on `ProjectMassSpec` or `ProjectNonTargetAnalysis` before those standalone wrappers are retired.
