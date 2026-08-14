# R package

`bindings/r` is the formal StreamFind R package, developed under the
[streamFind project](https://www.bildung-forschung.digital/digitalezukunft/de/bildung/digital-_und_datenkompetenzen/datenkompetenzen_wissenschaftlichen_nachwuchs/Projekte/stream_find.html)
funded by the BMFTR. The project develops an open, flexible, and extensible
software solution for non-target screening with mass spectrometry in water
analysis; its data processing is implemented as an independent R package, with
the package root at `bindings/r`.

The package is a DuckDB-backed workflow framework of persistent `Project`
child classes — `ProjectMassSpec`, `ProjectNonTargetAnalysis`, and related
classes — that hold data, workflow metadata, cached results, and audit state.
Workflows are assembled from ordered `Method` objects and executed
reproducibly.

## Installation

streamfind requires R and a working C++17 toolchain. On Windows this
generally means installing [RTools](https://cran.r-project.org/bin/windows/Rtools/).

``` r
options(timeout = 600)
if (!requireNamespace("remotes", quietly = TRUE)) {
  install.packages("remotes")
}
remotes::install_github("odea-project/streamfind")
```

Supplementary example data and assets are available in the companion package
`streamfind.data`:

``` r
remotes::install_github("odea-project/streamfind.data")
```

## Development

Run package commands from `bindings/r` — the repository root is not the
package root:

```text
R CMD check bindings/r
R CMD build bindings/r
```

## Example workflow

``` r
library(streamfind)

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

## Shiny application and Docker

The same project objects can be inspected in the integrated application:

``` r
nta$run_app()
```

A Docker image bundles streamfind, its R dependencies, code-server, SSH, and
external tools (Java, MetFrag). See `bindings/r/README.md` for build, run, and
mount instructions.
