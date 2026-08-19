# streamfind

<p align="center">
  <img src="bindings/r/inst/app/www/streamfind.png" width="70%" />
</p>

streamfind is a DuckDB-backed workflow framework for analytical data
processing. The repository hosts a shared semantic catalogue, two independent
backend implementations (C++ and Rust), the preserved R package, and the
language and integration bindings built on top of them.

The central contract is the **semantic catalogue**: a backend-neutral
declaration of domains, operations, workflow methods, parameters, results,
errors, and interface mappings. Each backend implements that contract
independently and shares behaviour through conformance fixtures, never by
wrapping the other backend.

> **Development stage:** streamfind is in an active architecture migration.
> The R package is the preserved functional user path. The C++ and Rust
> backends and MCP servers are active developer-preview foundations; the public
> Python package and complete non-target-analysis migration are not available
> yet. See the [development status](https://streamfind.odea-project.org/status/)
> page for the current capabilities and limitations.

## Repository layout

| Path | Component | Status |
| --- | --- | --- |
| `semantic/` | Backend-neutral semantic catalogue and generated projection | Foundation |
| `core/` | Independent C++20 backend (`streamfind-core`) | Active foundation |
| `rust/` | Independent Rust backend (`streamfind-rust-*` crates) | Active foundation |
| `bindings/r/` | R package | Preserved and functional |
| `bindings/python/` | Public Python binding | Future |
| `integrations/cf-streamfind/` | Cogniflow integration | Deferred |
| `tests/` | Shared domain data and conformance fixtures | Active |

## semantic/

The backend-neutral contract for shared operations, methods, domains,
parameters, results, errors, fixtures, and interface mappings. The ontology is
authored as Turtle under `semantic/ontology/`, validated with SHACL, and
compiled into one generated projection at `semantic/generated/catalogue.json`
that the native backends embed.

### Development

Uses the repository-local `.venv` with `rdflib` and `pyshacl`:

```powershell
& .\semantic\validate.ps1
& .\.venv\Scripts\python.exe .\semantic\generate_projection.py
```

Regenerate the projection after changing `semantic/ontology/`. Built libraries
do not read `semantic/` at runtime.

## core/

Standalone C++20 backend for project persistence and generic workflow
execution. It owns one DuckDB-backed `streamfind::Project` per project
selection and exposes `get_*`/`set_*`/`run_*`/`delete_*` project methods plus a
JSON `streamfind::api::run()` facade. The core does not depend on R, Python,
FastAPI, or React. Domain libraries depend on the generic core; the generic
core never depends on domains.

### Build and test

From `core/`:

```powershell
cmake --preset default
cmake --build --preset default --config Debug
ctest --test-dir build/cmake/default -C Debug --output-on-failure
```

See `core/README.md` for the full project and JSON API contracts.

## rust/

Independent Rust implementation of the same project backend, sharing the
DuckDB schema and JSON contract with `streamfind-core` but never linking to or
wrapping C++. The workspace is composed of small crates: `streamfind-rust-core`
(project/workflow/execution APIs), `streamfind-rust-cli`, `streamfind-rust-external`
(tool resolution from `PATH`), and `streamfind-rust-mcp` (stdio MCP adapter).

### Build and test

From `rust/`:

```powershell
cargo fmt --all -- --check
cargo test --workspace
cargo doc --workspace --no-deps --open
```

See `rust/README.md` for the project API, CLI usage, and interoperability
fixtures.

## bindings/r

The formal StreamFind R package, developed under the [streamFind
project](https://www.bildung-forschung.digital/digitalezukunft/de/bildung/digital-_und_datenkompetenzen/datenkompetenzen_wissenschaftlichen_nachwuchs/Projekte/stream_find.html)
funded by the BMFTR. The project develops an open, flexible, and extensible
software solution for non-target screening with mass spectrometry in water
analysis; its data processing is implemented as an independent R package,
keeping the package root at `bindings/r`.

The package is built on a DuckDB-backed workflow framework of persistent
`Project` child classes (`ProjectMassSpec`, `ProjectNonTargetAnalysis`, and
related classes) that hold data, workflow metadata, cached results, and audit
state. Workflows are assembled from ordered `Method` objects and executed
reproducibly. The R package is currently the most complete user-facing
workflow path in the repository.

### Installation

streamfind requires R and a working C++17 toolchain (on Windows, [RTools](https://cran.r-project.org/bin/windows/Rtools/)).

``` r
options(timeout = 600)
if (!requireNamespace("remotes", quietly = TRUE)) {
  install.packages("remotes")
}
remotes::install_github("odea-project/streamfind", subdir = "bindings/r")
```

### Development

Run package commands from `bindings/r`:

```text
cd bindings/r
devtools::load_all()
R CMD check .
R CMD build .
```

The repository root is not the package root. For a local installation from the
repository root, use `remotes::install_local("bindings/r")`.

### Methods and documentation

Workflow steps are exported `Method_*` constructors. Their parameters,
prerequisites, return objects, and examples are documented with roxygen2 in
`bindings/r/R/` and generated into the package help topics:

```r
library(streamfind)

grep("^Method_", getNamespaceExports("streamfind"), value = TRUE)
?Method_NonTargetAnalysis_FindFeatures
?Method_MassSpecChromatograms_LoadChromatograms
```

Regenerate the documentation from `bindings/r/` with:

```powershell
Rscript -e "devtools::document(); devtools::load_all()"
```

### Shiny application

The R package includes a Shiny application for browsing projects, analyses,
workflows, chromatograms, spectra, and non-target-analysis results:

```r
library(streamfind)

nta <- open_ProjectNonTargetAnalysis(
  db = "streamfind.duckdb",
  project_id = "nta_demo"
)
nta$run_app()
```

### Docker image

A pre-built image is available at
[ricardocunha23/streamfind on Docker Hub](https://hub.docker.com/r/ricardocunha23/streamfind):

```bash
docker pull ricardocunha23/streamfind:latest
docker run -d --name streamfind \
  -v "$PWD/data:/host/data:rw" \
  -p 3838:3838 -p 8080:8080 -p 2222:22 \
  -e SSH_PASSWORD=change-me \
  -e CS_PASSWORD=change-me \
  ricardocunha23/streamfind:latest
```

The container provides the Shiny application at <http://localhost:3838>,
code-server at <http://localhost:8080>, and SSH on port `2222`. Change the
example passwords before exposing the container beyond the local machine.

See [`bindings/r/README.md`](bindings/r/README.md) for mounts, external tools,
and additional container configuration.

## bindings/python

Reserved for the future public Python package. It will be built on the C++
backend with pybind11 (private `streamfind._core`), a typed public `streamfind.core`
API, a CLI, and a FastAPI service layer. Development starts only after the
semantic/registry/MCP contracts are stable.

## integrations/cf-streamfind

Reserved Cogniflow integration boundary. It is intentionally not expected to
build during the current phase: the Cogniflow dependencies are not available
and its native implementation will be refactored in this location. Work is
deferred until the public C++/Python path is complete.

## tests/

Shared backend-neutral fixtures used by the C++ and Rust implementations for
conformance: analytical sample data under `tests/data/` (mass spectrometry,
Raman, sensors) and semantic/MCP JSON fixtures under `tests/fixtures/`.

## MCP lifecycle

Direct domain **Operations** are stateless: pass `database_path` and
`project_id` with each request, and the server opens and closes the project
within that request. They do not require `connect` or `close`.

Workflow **Methods** are session-bound: call `connect` first, use `tools/list`
to discover the connected domain's Methods, invoke the Methods, and call
`close` when the session ends. See the [C++ MCP quickstart](https://streamfind.odea-project.org/quickstart/cpp-mcp/)
or [Rust MCP quickstart](https://streamfind.odea-project.org/quickstart/rust-mcp/).

## Documentation

The full documentation site is available at
<https://streamfind.odea-project.org/>.

## Contributing

The living implementation roadmap lives in `.plans/streamfind_migration_plan.md`.
Key rules: add methods through a semantic declaration plus a registry
registration per backend; never wrap one backend with the other; keep the
generic core and generic MCP code domain-neutral.
