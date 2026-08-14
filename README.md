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

## Repository layout

| Path | Component | Status |
| --- | --- | --- |
| `semantic/` | Backend-neutral semantic catalogue and generated projection | Foundation |
| `core/` | Independent C++20 backend (`streamfind-core`) | Foundation |
| `rust/` | Independent Rust backend (`streamfind-rust-*` crates) | Foundation |
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
reproducibly. A Docker image bundles the package with code-server, SSH, and
external tools.

### Installation

streamfind requires R and a working C++17 toolchain (on Windows, [RTools](https://cran.r-project.org/bin/windows/Rtools/)).

``` r
options(timeout = 600)
if (!requireNamespace("remotes", quietly = TRUE)) {
  install.packages("remotes")
}
remotes::install_github("odea-project/streamfind")
```

### Development

Run package commands from `bindings/r`:

```text
R CMD check bindings/r
R CMD build bindings/r
```

The repository root is not the package root. See `bindings/r/README.md` for
the framework overview, Shiny application, and Docker usage.

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

## Contributing

The living implementation roadmap lives in `.plans/streamfind_migration_plan.md`.
Key rules: add methods through a semantic declaration plus a registry
registration per backend; never wrap one backend with the other; keep the
generic core and generic MCP code domain-neutral.
