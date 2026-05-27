
<!-- README.md is generated from README.Rmd. Please edit that file -->

<!-- badges: start -->

[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

<img src="man/figures/readme_logos.png" alt="Logo" width="100%" style="display: block; margin: auto;" />

StreamFind is a DuckDB-backed workflow framework for analytical data
processing in R. The current package architecture is built around
persistent `Project` child classes that hold data, workflow metadata,
cached results, and audit state in one place.

The main project classes are:

- `ProjectMassSpec`: shared mass-spectrometry project interface
- `ProjectMassSpecSpectra`: spectra-focused raw MS access
- `ProjectMassSpecChromatograms`: chromatogram-focused raw MS access
- `ProjectNonTargetAnalysis`: non-target analysis workflows and results

Workflows are assembled from ordered `Method` objects, stored on the
project, and executed reproducibly. This gives one framework for
interactive exploration, scripted processing, and Shiny-based inspection
of the same project state.

## Installation

StreamFind requires R and a working C++17 toolchain. On Windows this
generally means installing
[RTools](https://cran.r-project.org/bin/windows/Rtools/). Some optional
methods depend on external software such as Java, MetFrag, Python-based
tooling, or chemistry packages listed in `Suggests`.

Install the package from GitHub:

``` r
options(timeout = 600)
if (!requireNamespace("remotes", quietly = TRUE)) {
  install.packages("remotes")
}
remotes::install_github("odea-project/StreamFind")
```

Supplementary example data and assets are available in the companion
package
[StreamFindData](https://github.com/odea-project/StreamFindData):

``` r
if (!requireNamespace("remotes", quietly = TRUE)) {
  install.packages("remotes")
}
remotes::install_github("odea-project/StreamFindData")
```

## Framework overview

The typical workflow is:

1.  Open or create a project child class.
2.  Import domain data into that project.
3.  Define a `Workflow` from `Method` objects.
4.  Attach the workflow with `set_workflow()`.
5.  Run it with `run_workflow()` or stepwise with `run_method()`.
6.  Inspect results through the project API or `run_app()`.

Example for non-target analysis:

``` r
library(StreamFind)

nta <- open_ProjectNonTargetAnalysis(
  db = "streamfind.duckdb",
  project_id = "nta_demo"
)

workflow <- Workflow(list(
  Method_NonTargetAnalysis_FindFeatures(),
  Method_NonTargetAnalysis_LoadFeaturesMS1(),
  Method_NonTargetAnalysis_LoadFeaturesMS2(),
  Method_NonTargetAnalysis_GroupFeatures(),
  Method_NonTargetAnalysis_FillFeatures(),
  Method_NonTargetAnalysis_FilterFeatures()
))

set_workflow(nta, workflow)
run_workflow(nta)

features <- get_features(nta)
plot_features_count(nta)
```

## Non-target analysis

`ProjectNonTargetAnalysis` is the most feature-rich project class
currently exposed in StreamFind. It supports native workflow methods
for:

- feature finding
- MS1 and MS2 trace loading
- component creation and annotation
- feature grouping and gap filling
- blank subtraction
- matrix-suppression correction
- feature filtering
- suspect screening
- internal-standard matching
- MetFrag screening
- transformation-product assignment

The project object also exposes structured getters and plots for
features, spectra, suspects, internal standards, matrix suppression,
fold change, and transformation products.

## Shiny application

The same project objects can be inspected in the integrated application:

``` r
nta$run_app()
```

This is useful when you want to browse analyses, results, and workflow
state without leaving the package data model.

## External dependencies

Some workflows depend on third-party tools that are not bundled with
StreamFind. For example:

- MetFrag screening requires a MetFrag CL installation and Java
- some chemistry features depend on `rcdk` and `rJava`
- optional reporting uses Quarto

Method-level documentation describes these requirements where relevant.

## Documentation

Reference documentation and articles are published at:

- <https://odea-project.github.io/StreamFind/>
- <https://odea-project.github.io/StreamFind/reference/index.html>

## Project background

StreamFind is developed within the project “Flexible data analysis and
workflow designer to identify chemicals in the water cycle” with
contributions centred at IUTA and partner organisations. The package is
under active development and the project-class framework is the primary
interface going forward.
