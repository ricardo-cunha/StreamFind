# App Refactor Plan: Dynamic Project Framework + Themed UI

## Summary
Refactor the Shiny app so project discovery, project opening, workflow/cache/metadata/audit handling, and top-level navigation are driven by the new `Project` child framework. Keep `projects_overview()` as the registry for discoverable/openable project classes, and use class-based UI/server dispatch for project-specific analyses, explorer, and results modules. In this pass, move Settings from a modal into a dedicated tab and implement theme/style controls only.

Create the written implementation artifact in `.ai_plan` as a single app-refactor plan document, based on this spec.

## Key Changes
### 1. Dynamic project lifecycle
- Keep `projects_overview()` as the canonical registry for available project classes.
- Extend each registry entry so the app can render:
  - user-facing label and description
  - supported file formats
  - `open_<ProjectClass>()` function
  - module ownership hints for analyses, explorer, and results
- Add a lightweight project resolver for existing DuckDB files:
  - inspect the DB and `PROJECT` content
  - if exactly one valid `project_id` exists, auto-select it
  - if multiple valid `project_id`s exist, show a selector after file pick
  - resolve the `domain` from the stored project and map it back to exactly one `project_class` from `projects_overview()`
  - if no match or multiple matches exist, show a blocking validation error
- Split “Create Project” from “Open Project” in the Project tab:
  - Create: choose one current project type from `projects_overview()`, then create/open through its registered `open_<ProjectClass>()`
  - Open: choose a DuckDB file first, infer the project class dynamically, then render the correct project child object without requiring the user to pre-pick the type

### 2. Module architecture by project class
- Standardize three app extension points:
  - analyses module
  - explorer module
  - results module
- Use class-based dispatch for those extension points, with `ProjectMassSpec` as the reusable base for mass-spec-family projects.
- Implement/refactor dispatch so:
  - `ProjectMassSpecSpectra`, `ProjectMassSpecChromatograms`, and `ProjectNonTargetAnalysis` reuse `ProjectMassSpec` analyses behavior unless they need overrides
  - explorer for the full mass-spec family uses the shared raw spectra/chromatogram explorer behavior already tied to `ProjectMassSpec`
  - future non-mass-spec projects such as `ProjectRaman` can register their own analyses/explorer/results modules without changing the app shell
- Keep workflow, metadata, cache, and audit-trail modules owned by base `Project` behavior and reused unchanged across project classes except for UI cleanup
- Replace hard-coded results routing with class-based results dispatch
- Rename result modules to the project-class naming scheme:
  - `R/app_mod_MassSpecResults_Chromatograms.R` -> `R/app_mod_Results_ProjectMassSpecChromatograms.R`
  - `R/app_mod_MassSpecResults_NonTargetAnalysis.R` -> `R/app_mod_Results_ProjectNonTargetAnalysis.R`
- Update exported/internal module symbols to match the new naming convention and remove old call sites

### 3. App shell and settings flow
- Keep the top-level tab shell, but add a dedicated `Settings` tab instead of opening settings in a modal
- Make the main app state explicit:
  - active project object
  - active project class
  - resolved project registry entry
  - workflow
  - results descriptors
- Project tab becomes the entry/control surface for:
  - create/open flow
  - project summary
  - shared metadata editor
- Results tab sub-navigation must be generated from the active project class’ results module availability
- Remove the current hard-coded assumption that only `ProjectNonTargetAnalysis` has results

### 4. CSS, theme, and layout system
- Rework the UI styling toward the referenced frontend style system:
  - CSS custom properties for palette, surfaces, text, borders, radius, shadows, and spacing
  - global theme attributes on the root app container
  - reusable style presets rather than per-module inline styling
- Introduce a small StreamFind design token layer:
  - `--sf-space: 5px`
  - `--sf-radius-*`
  - `--sf-surface-*`
  - `--sf-border`
  - `--sf-shadow-*`
  - `--sf-text-*`
  - `--sf-accent`
- Use padding only as the primary layout spacing primitive for app components; do not rely on ad hoc margins for module/page layout
- Create reusable global CSS classes for:
  - page shell
  - panel/card
  - toolbar/action row
  - table container
  - plot container
  - split panes
  - empty-state blocks
  - info banners
- Move inline style-heavy layout out of R UI code where practical and replace it with shared classes
- Settings tab in this pass controls theme only:
  - light/dark mode
  - style preset selection
- Persist the selected theme in app session state; do not add broader app-config editing in this refactor

## Public Interfaces / Structural Changes
- `projects_overview()` becomes the app registry contract and must expose enough metadata for create/open and module dispatch
- Add a project-class resolution helper for existing DBs, used by the app server before calling `open_<ProjectClass>()`
- Standardize module dispatch naming around project classes:
  - analyses: `.mod_Analyses_UI.<Class>` / `.mod_Analyses_Server.<Class>`
  - explorer: `.mod_Explorer_UI.<Class>` / `.mod_Explorer_Server.<Class>`
  - results: `.mod_Results_UI.<Class>` / `.mod_Results_Server.<Class>`
- Shared workflow UI stays on `.mod_Workflow_UI.Project` / `.mod_Workflow_Server.Project`, but its styling and method-detail rendering should be cleaned up to match current `Method` objects

## Test Plan
- Project registry smoke test:
  - `projects_overview()` returns all current classes and enough metadata to build create/open UI
- Open existing DB flow:
  - valid DB with one project opens directly into the correct child class
  - valid DB with multiple project IDs prompts for selection
  - invalid DB or unmapped domain shows a clear error
- Create project flow:
  - all three current project classes can be created/opened from the app
- Dynamic module routing:
  - `ProjectMassSpecSpectra` uses shared mass-spec analyses/explorer behavior
  - `ProjectMassSpecChromatograms` loads its dedicated results module
  - `ProjectNonTargetAnalysis` loads its dedicated results module
- Shared framework behavior:
  - metadata, workflow, cache, and audit-trail tabs work for all current project classes
- Theme/settings behavior:
  - Settings tab changes mode/style without breaking layout
  - reusable panel/table/plot classes render consistently with 5 px padding
- Regression/manual checks:
  - top navigation still switches correctly
  - dynamic results subnav updates when the active project class changes
  - `devtools::document()` and app launch still succeed after renames

## Assumptions
- Use a hybrid extension model:
  - `projects_overview()` handles discovery/opening metadata
  - class-based dispatch handles project-specific app modules
- Settings scope for this refactor is theme-only
- `ProjectMassSpec` remains the shared base for analyses/explorer behavior across the current mass-spec family
- Existing DB project-class detection should be based on stored project `domain`, not file naming or user guesswork
- The implementation should add a single `.ai_plan` document describing the concrete execution steps for this refactor
