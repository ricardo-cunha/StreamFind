# R package

`bindings/r` is the formal StreamFind R package, developed under the
[streamFind project](https://www.bildung-forschung.digital/digitalezukunft/de/bildung/digital-_und_datenkompetenzen/datenkompetenzen_wissenschaftlichen_nachwuchs/Projekte/stream_find.html)
funded by the BMFTR. The project develops an open, flexible, and extensible
software solution for non-target screening with mass spectrometry in water
analysis; its data processing is implemented as an independent R package, with
the package root at `bindings/r`.

!!! success "Current user path"
    This is the preserved and functional user-facing path today. The new C++
    and Rust backends are being developed alongside it; they do not yet replace
    the complete R non-target-analysis workflow.

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
remotes::install_github("odea-project/streamfind", subdir = "bindings/r")
```

The `subdir` argument is required because the repository root is not the R
package root. The GitHub installation can be run from any working directory;
only local package development commands need to run from `bindings/r`.

Supplementary example data and assets are available in the companion package
`streamfind.data`:

``` r
remotes::install_github("odea-project/streamfind.data")
```

## Development

Run package commands from `bindings/r` — the repository root is not the
package root:

```text
cd bindings/r
devtools::load_all()
R CMD check .
R CMD build .
```

From the repository root, a local installation can also be performed with:

``` r
remotes::install_local("bindings/r")
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

## Methods and method documentation

Workflow steps are created with exported `Method_*` constructor functions.
Each constructor is documented beside its implementation with
[roxygen2](https://roxygen2.r-lib.org/) comments. The comments describe the
method purpose, parameters, return object, prerequisites, and exported R help
topic. The generated reference files under `bindings/r/man/` are build
outputs; edit the roxygen comments in `bindings/r/R/` instead of editing `.Rd`
files directly.

### Discover available methods

After loading the package, list the exported method constructors:

``` r
library(streamfind)

method_constructors <- getNamespaceExports("streamfind")
grep("^Method_", method_constructors, value = TRUE)
```

You can also search the generated package index:

``` r
help(package = "streamfind")
```

Read the documentation for a specific method with `?` or `help()`:

``` r
?Method_NonTargetAnalysis_FindFeatures
?Method_NonTargetAnalysis_LoadFeaturesMS1
?Method_MassSpecChromatograms_LoadChromatograms
```

### Create and inspect methods

Constructors validate their parameters and return `Method` objects. Methods
can then be placed in an ordered `Workflow`:

``` r
find_features <- Method_NonTargetAnalysis_FindFeatures(
  rtWindows = data.frame(rtmin = 0, rtmax = 600),
  ppmThreshold = 15,
  noiseThreshold = 250,
  minSNR = 3,
  minTraces = 3L
)

load_ms1 <- Method_NonTargetAnalysis_LoadFeaturesMS1(
  filtered = FALSE,
  rtWindow = c(-2, 2),
  mzWindow = c(-1, 6)
)

workflow <- Workflow(list(find_features, load_ms1))
workflow
get_methods(workflow)
```

The workflow checks method prerequisites and order. For example,
`LoadFeaturesMS1` requires `FindFeatures` to appear earlier in the workflow.
Attach and execute the workflow on a compatible `ProjectNonTargetAnalysis`:

``` r
nta <- open_ProjectNonTargetAnalysis(
  db = "streamfind.duckdb",
  project_id = "nta_demo"
)

set_workflow(nta, workflow)
run_workflow(nta)
```

For chromatogram workflows, the corresponding constructors are
`Method_MassSpecChromatograms_LoadChromatograms()` and
`Method_MassSpecChromatograms_FilterChromatogramsRetentionTime(rtmin, rtmax)`.
The latter declares `LoadChromatograms` as a prerequisite, so it must follow
the loading method in the workflow.

### Update method documentation

From the package root, edit or add roxygen comments in the relevant file under
`bindings/r/R/`, then regenerate the package documentation:

``` powershell
cd bindings/r
devtools::document()
devtools::load_all()
```

Do not manually edit generated files under `bindings/r/man/` or the generated
Rcpp export files.

## Shiny application

The StreamFind Shiny application provides an interactive interface for
browsing projects, analyses, workflows, chromatograms, spectra, and
non-target-analysis results. It uses the same project objects and workflow
state as the R API.

Run it from R with an opened project:

``` r
library(streamfind)

nta <- open_ProjectNonTargetAnalysis(
  db = "streamfind.duckdb",
  project_id = "nta_demo"
)

nta$run_app()
```

When running locally, the application opens in a browser. The application is
also started automatically by the Docker image described below.

## Docker image

A pre-built Docker image for the StreamFind R package is available on Docker
Hub:

[ricardocunha23/streamfind on Docker Hub](https://hub.docker.com/r/ricardocunha23/streamfind)

Pull the image with:

```bash
docker pull ricardocunha23/streamfind:latest
```

Run the container with the Shiny application, code-server, and SSH exposed:

```bash
docker run -d --name streamfind \
  -v "$PWD/data:/host/data:rw" \
  -p 3838:3838 \
  -p 8080:8080 \
  -p 2222:22 \
  -e SSH_PASSWORD=change-me \
  -e CS_PASSWORD=change-me \
  ricardocunha23/streamfind:latest
```

Then open:

- Shiny application: <http://localhost:3838>
- Browser-based code-server: <http://localhost:8080>
- SSH: `ssh -p 2222 streamfind@localhost`

The container includes the R package, its native dependencies, code-server,
SSH, Java, MetFrag, and bundled analytical libraries. Mount project and data
folders under `/host/<name>` so they are available to the application and
code-server. See [`bindings/r/README.md`](https://github.com/odea-project/StreamFind/blob/master/bindings/r/README.md)
for additional mounts, network-drive guidance, and environment variables.

Change the example passwords before exposing the container beyond your local
machine. The image defaults are intended for development only.
