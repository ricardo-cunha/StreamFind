# Development status

streamfind is in an active backend and interface transition. The current native
C++ and Rust implementations are usable development releases, while the
existing R package remains a separate preserved workflow path.

## What is available today

| Path | Maturity | Best use today |
| --- | --- | --- |
| **C++ backend** | Version 0.1.0 development release | Native project persistence, mass-spec operations, workflow execution, and MCP integration |
| **Rust backend** | Version 0.1.0 development release | Independent backend development, native readers, CLI, interoperability testing, and MCP integration |
| **MCP servers** | Working catalogue-driven interface | AI-agent and client integration through the C++ or Rust stdio server |
| **Semantic catalogue** | Authoritative shared contract | Discovering operations, methods, parameters, schemas, and interface guidance |
| **R package** | Preserved and functional | Existing R workflows, non-target screening, and the Shiny application |
| **Python package** | Not released | No public installation path |
| **Cogniflow integration** | Not part of the current native path | Do not use it as the native C++/Rust release interface |

Download the current native packages from [Releases](releases.md). For an
existing R workflow, use the [R package](components/bindings-r.md). For new
backend or agent integration, use the [C++](components/core-cpp.md) or
[Rust](components/rust.md) documentation.

## Implemented native foundation

The current branch provides:

- a Turtle/SKOS/SHACL semantic catalogue and deterministic JSON/DuckDB
  projection;
- 70 catalogue entries, including 49 callable Operations and 21 workflow
  Methods;
- independent C++ and Rust project backends using the shared DuckDB schema and
  JSON contracts;
- project lifecycle, metadata, workflow, cache, audit, validation, and
  cancellation/progress foundations;
- catalogue-driven C++ and Rust MCP servers with complete input schemas,
  nested target schemas, annotations, and agent-facing initialization guidance;
- 23 mass-spectrometry Operations and 19 mass-spectrometry workflow Methods;
- native mzML and vendor-container reader implementations, with reader parity
  and vendor-fixture validation kept separate from the default distribution
  test suite;
- mass-spectrometry analysis management, metadata/query operations, raw and
  persisted spectra/chromatogram access, and migrated feature-processing
  methods.

## Current limitations

The native packages are development releases, not compatibility-stable SDKs.
In particular:

- no stable cross-version C++ ABI or Rust API guarantee is provided yet;
- vendor-reader validation depends on local fixtures for some formats and is
  not evidence that every vendor format is available on every installation;
- optional tools such as Java and MetFrag are explicit user-installed
  components and are not downloaded automatically;
- the public Python package, service layer, and frontend are not released;
- the Cogniflow adapter is not part of the current native release path;
- the R package and native C++/Rust packages are separate interfaces and should
  not be treated as interchangeable installation formats.

## MCP interface status

Both native servers expose the same catalogue-backed interface:

1. call `initialize`;
2. call `tools/list` to discover callable Operations;
3. call `create` and then `describe` for a new project;
4. call stateless domain Operations with explicit `database_path` and
   `project_id`;
5. call `connect` before workflow Methods;
6. call `get_available_methods` to discover Method schemas;
7. build and validate a workflow, then call `run_workflow` or `run_method`;
8. call `close` when the connected session ends.

Operations are always discoverable through `tools/list`. Methods are returned
by `get_available_methods`, not advertised as MCP tools. The semantic catalogue
is the source of the descriptions and JSON schemas used by both servers.

## Test boundaries

The default distribution-facing tests intentionally exclude direct
reader-interface and vendor-parity tests because they require local proprietary
fixtures or have substantially different runtimes. Those tests remain
available explicitly for reader development.

```powershell
# Default C++ tests: excludes the reader-interface label
scripts\test-core.cmd

# Include reader-interface tests explicitly
scripts\test-core.cmd -IncludeReaderInterface

# Default Rust workspace tests: excludes feature-gated reader tests
scripts\test-rust.cmd

# Include Rust reader and vendor-parity tests explicitly
scripts\test-rust.cmd -Package streamfind-rust-mass-spec -IncludeReaderInterface
```

## Development commands

Validate the semantic contract and generated projection:

```powershell
& .\.venv\Scripts\python.exe semantic\validate_semantic.py
& .\.venv\Scripts\python.exe semantic\generate_projection.py --check
```

Build and test the C++ backend:

```powershell
scripts\build-core.cmd
scripts\test-core.cmd
```

Build and test the Rust workspace:

```powershell
scripts\build-rust.ps1
scripts\test-rust.cmd
```

Build both Windows release packages:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\release.ps1 -Version 0.1.0
```

The [living roadmap](https://github.com/odea-project/StreamFind/blob/master/.plans/streamfind_migration_plan.md)
tracks work beyond the current release. Status labels describe the current
implementation state, not a promise of API stability.
