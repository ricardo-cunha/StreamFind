**Phase 1 Report**
Scope implemented
- Froze the core architecture decisions in code-facing metadata rather than leaving them only in the JSON plan.
- Introduced `owner_class` as first-class `ProcessingStep` metadata to support the planned shift from engine-based dispatch to project-class-based dispatch.
- Added owner-aware processing discovery helpers for later workflow/app migration.

Files changed
- `R/class_ProcessingStep.R`
- `R/utils_general.R`
- `R/class_Workflow.R`

Schema/API changes
- `ProcessingStep()` now accepts `owner_class`.
- `ProcessingStep()` now infers `owner_class` when it is omitted.
- Current default inference rules:
  - steps touching `NonTargetAnalysis` classes -> `ProjectNonTargetAnalysis`
  - other `MassSpec`-class steps -> `ProjectMassSpec`
- Added `.infer_processing_owner_class()`.
- Added `.get_available_processing_methods_for_owner()`.
- `.list_processing_steps_metadata()` now exposes `owner_class`.
- `info.Workflow()` now includes `owner_class`.

Verification performed
- Confirmed the current app/workflow path is still engine-based and that this phase does not yet switch runtime dispatch.
- Limited implementation to metadata and discovery helpers to avoid crossing into later phases prematurely.
- `devtools::load_all('.')` completed successfully after the phase-1 changes.
- `roxygen2::roxygenise()` regenerated updated documentation successfully.

Rcpp exports regenerated
- No
- Reason: this phase only changed R-side workflow/processing metadata and documentation.

devtools::load_all status
- Passed
- Command used: `Rscript -e "devtools::load_all('.')"`

Documentation updated
- Added roxygen documentation for `owner_class` in `ProcessingStep`.
- Added workflow roxygen details describing the phase-1 architecture-freeze role of `owner_class`.
- Regenerated documentation files:
  - `man/ProcessingStep.Rd`
  - `man/Workflow.Rd`

Known gaps
- `Engine$run()` still dispatches by `type`, not `owner_class`.
- `app_mod_Workflow` still discovers methods by engine type.
- Existing `MassSpecMethod_*` constructors still declare legacy `input_class`/`output_class` values, though `owner_class` now provides a bridge toward the target project hierarchy.
- `ProjectNonTargetAnalysis` class and C++ facade did not exist in phase 1 and were deferred to the later dedicated phase.
- The eventual migration target is for methods now living on `R/class_MassSpecResults_NonTargetAnalysis.R` to move onto `ProjectNonTargetAnalysis`, mirroring how Mass Spec-facing behavior is being centralized on `ProjectMassSpec`.
- The legacy removal sequence is expected to end with removing `R/class_MassSpecResults_NonTargetAnalysis.R`, `R/class_MassSpecResults_Chromatograms.R`, `R/class_MassSpecResults_Spectra.R`, `R/class_MassSpecEngine.R`, and finally `R/class_MassSpecAnalyses.R` once their behavior is absorbed by project child classes.
- Beyond the Mass Spec result wrappers, standalone DB wrapper classes such as `R/class_Results.R`, `R/class_AuditTrail.R`, `R/class_Cache.R`, and `R/class_Analyses.R` are also expected to become legacy as equivalent behavior moves under `Project` and its child classes.
- Generic value/container classes such as `Metadata`, `Workflow`, and `ProcessingStep` are still part of the target architecture and are not part of the removal list.
- The refactor plan now records explicit legacy-to-target ownership mappings so later phases can migrate behavior into `Project`, `ProjectMassSpec`, or `ProjectNonTargetAnalysis` without leaving ownership ambiguous.

Next recommended steps
1. Run `devtools::load_all()` and fix any issues from the new `owner_class` metadata additions.
2. Add the `ProjectNonTargetAnalysis` R/C++ skeleton.
3. Start migrating processing-step constructors to explicitly declare `owner_class` instead of relying on inference only.
4. When NTS migration begins, move public/query/result methods from `R/class_MassSpecResults_NonTargetAnalysis.R` onto `ProjectNonTargetAnalysis` rather than creating another parallel result-wrapper layer.
5. Inventory standalone DB wrappers such as `Results`, `AuditTrail`, `Cache`, and `Analyses` so their responsibilities can be reassigned to `Project` or project child classes before legacy removal.
