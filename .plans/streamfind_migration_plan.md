# StreamFind Living Implementation Roadmap

**Branch:** \`dev_refactoring\`  
**Purpose:** keep the refactor plan aligned with the implementation that exists today. This is a roadmap for unfinished work, not a record of superseded greenfield tasks.

## Status legend

| Status | Meaning |
| --- | --- |
| **Complete** | Present in the branch and covered by its component tests or build workflow. |
| **Partial** | Implemented foundation that still needs contract, interface, or release hardening. |
| **Next** | The shortest unblocked implementation work. |
| **Future** | Deliberately sequenced after the current foundation. |

## Architecture: contracts first, independent backends

The centre of the architecture is the **StreamFind contract**, not either backend. It defines the interoperable project model: DuckDB tables, JSON request/result envelopes, workflow and method shapes, cache and audit representations, error codes, cancellation, progress, and conformance fixtures.

\`\`\`text
                         StreamFind contracts
       DuckDB schema • JSON API • workflow • cache • audit • errors
                cancellation • progress • conformance fixtures
                                     │
                    ┌────────────────┴────────────────┐
                    │                                 │
                    ▼                                 ▼
          streamfind-core (C++)              StreamFind Rust
          independent C++ backend            independent Rust backend
                    │                                 │
       ┌────────────┼────────────┐        ┌───────────┼─────────────┐
       │            │            │        │           │             │
    Python         CLI       C++ MCP      CLI         MCP        external
  distribution                                      server/apps
       │
       ├── FastAPI module
       └── React/TypeScript build integration
\`\`\`

The C++ and Rust backends must implement the same contracts where a capability is shared, but **Rust must never link to, wrap, or call the C++ backend**. Differences are exposed by conformance tests and resolved in the contract or implementation; they are not hidden behind an adapter.

The C++ ecosystem is the only native backend for the consolidated Python distribution. Python, FastAPI, the React frontend, the R binding, and Cogniflow do not select or abstract over a Rust backend unless a separate architecture decision explicitly introduces that capability.

### C++ ecosystem

\`\`\`text
React + TypeScript source
          │ build
          ▼
python/frontend/ built assets ──► streamfind.server (FastAPI)
                                      │ service layer
                                      ▼
                            streamfind.core public Python API
                                      │ private pybind11 boundary
                                      ▼
                              streamfind._core / C++ core
                                      │
                       DuckDB • readers • methods • results
\`\`\`

### Rust ecosystem

\`\`\`text
streamfind-rust-core ──► streamfind-rust-cli
          │
          ├──────────────► streamfind-rust-mcp
          ├──────────────► streamfind-rust-external
          └──────────────► future streamfind-rust-server / apps crates

Each crate uses Rust-owned APIs and dependencies. None depends on
streamfind-core (C++).
\`\`\`

## Current implementation status

| Area | Status | Evidence in this branch | Roadmap implication |
| --- | --- | --- | --- |
| C++ backend | **Complete foundation** | Standalone C++20 \`core/\` with CMake, public \`Project\` and JSON APIs, DuckDB persistence, workflow, cache, audit, cancellation, progress, MCP support, install rules, and native tests. | Extend by coherent capability slices; do not recreate the generic project kernel. |
| Rust backend | **Complete foundation** | \`rust/\` is a Cargo workspace with \`core\`, \`cli\`, \`external\`, and \`mcp\` crates. Its README states that it is independent from C++. | Preserve independent implementation and modular-crate boundaries. |
| Shared generic contract | **Partial** | C++ and Rust share \`PROJECT\`, \`CACHE\`, and \`AUDIT_TRAIL\` persistence; JSON, workflow, cache, audit, error, cancellation, and progress conventions; and the \`project_conformance.json\` fixture exercised by C++ and Rust tests. | Promote these shared assets into an explicitly versioned, backend-neutral contract surface and broaden conformance coverage. |
| C++/Rust MCP | **Partial** | C++ exposes MCP source and the Rust workspace has an MCP crate. | Align tool catalogues, argument schemas, result envelopes, errors, progress, and protocol fixtures. |
| R binding | **Complete relocation / Partial migration** | The complete R package, native sources, tests, vignettes, and package assets are under \`bindings/r/\`. | Keep it working there; move only proven domain logic to C++ and leave R-specific conversion and ergonomics in the binding. |
| Cogniflow integration | **Complete relocation / Partial integration** | \`integrations/cf-streamfind/\` exists as the integration boundary. | Make it consume only the installed public Python API once that API exists; it must not own native logic or access private bindings. |
| Python distribution | **Next** | \`python/\` is currently a reserved placeholder. | Build one distributable C++-backed Python package, including CLI, FastAPI, and frontend integration. |
| Standalone \`server/\` and \`frontend/\` roots | **Legacy placeholders** | Each currently contains only a README. | Absorb their responsibilities into \`python/\`; remove the placeholder roots in the same relocation change. |
| Domain capabilities | **Future** | The generic backend layer is present; a completed end-to-end MassSpec or NTA replacement slice is not yet established here. | Migrate and test one domain slice at a time against shared contracts and retained R baselines. |

## Target repository shape

This is the intended shape after the next consolidation. Paths marked \`[next]\` do not yet exist; it is not a claim that they are implemented.

\`\`\`text
streamfind/
├── contracts/                         # [next] backend-neutral versioned contracts
│   ├── schema/
│   ├── json/
│   ├── fixtures/
│   └── conformance/
│
├── core/                              # independent C++ backend
│   ├── include/streamfind/
│   ├── src/
│   ├── external/
│   ├── tests/
│   └── tools/                         # C++ MCP executable
│
├── python/                            # one C++-backed Python distribution [next]
│   ├── pyproject.toml
│   ├── CMakeLists.txt
│   ├── cpp/                           # pybind11 implementation
│   ├── frontend/                      # React + TypeScript source
│   ├── src/streamfind/
│   │   ├── _core/                     # private compiled extension
│   │   ├── core/                      # public high-level Python API
│   │   ├── cli/
│   │   ├── server/                    # FastAPI application and service layer
│   │   └── frontend/                  # built, packaged web assets
│   └── tests/
│
├── rust/                              # independent Rust workspace
│   ├── Cargo.toml
│   ├── crates/
│   │   ├── core/
│   │   ├── cli/
│   │   ├── mcp/
│   │   ├── external/
│   │   ├── server/                    # [future]
│   │   └── apps/                      # [future]
│   └── tests/
│
├── bindings/
│   └── r/                             # retained R package
│
├── integrations/
│   └── cf-streamfind/                 # Cogniflow integration
│
├── docs/
├── dev/
└── .plans/
\`\`\`

The top-level \`server/\` and \`frontend/\` placeholders are intentionally absent from the target tree. Their source moves to \`python/frontend/\`, their runtime code to \`python/src/streamfind/server/\`, and built frontend assets to \`python/src/streamfind/frontend/\`.

## Ownership and non-negotiable boundaries

### StreamFind contracts

- Own backend-neutral persisted and wire-compatible behaviour, not a backend implementation.
- Version schema and JSON changes with fixtures and compatibility tests.
- Describe common method identifiers, parameters, workflow/result envelopes, audit/cache representations, error codes, cancellation, progress, and MCP tool contracts where applicable.
- Do not import C++, Rust, Python, R, HTTP, UI, or Cogniflow types.
- Until the planned \`contracts/\` move is made, the existing shared fixture remains the operative source of truth; moving it must preserve both C++ and Rust test coverage.

### \`core/\` — C++

- Own C++ project lifecycle, DuckDB, native readers/algorithms, workflow execution, results, and C++ JSON/MCP entry points.
- Build without R, Python, pybind11, FastAPI, Node.js, or React.
- Provide the native API consumed by the Python private extension; it does not embed Python, FastAPI, React, Cogniflow, or R conversion code.

### \`rust/\` — Rust

- Own the independent Rust project, persistence, workflow, algorithms, Rust CLI, MCP, external-tool integration, and future Rust server/apps.
- Use Rust-owned APIs and dependencies. Rust may use appropriately isolated native libraries where needed, but it must not depend on \`streamfind-core\` or C++ project APIs.
- Implement shared capabilities independently and prove compatibility with conformance tests.

### \`python/\` — consolidated C++ distribution

- Own the package build, private \`_core\` pybind11 extension, public Python API, CLI, FastAPI service layer, React/TypeScript source, and packaged frontend assets.
- Public Python code, CLI commands, FastAPI routes, and integrations use \`streamfind.core\`, never \`_core\` directly.
- FastAPI routes call a Python service layer. Long workflows run outside request handlers and report structured job/progress state.
- The frontend calls the FastAPI/OpenAPI contract only; it never opens DuckDB or calls native bindings.

### \`bindings/r\` and \`integrations/\`

- \`bindings/r\` remains an installable R package. Preserve it while feature parity is migrated; only language conversion, ergonomics, and R-specific reporting belong there.
- \`integrations/cf-streamfind\` translates Cogniflow contracts to the public Python API. It must not compile C++, include C++ headers, link native runtimes, access DuckDB, or import \`_core\`.

## Roadmap

### 1. Stabilise and publish the shared contracts — **Next**

1. Create a backend-neutral contract home and move/copy the current shared fixture, JSON definitions, and schema documentation without changing their meaning.
2. Define an explicit contract version and compatibility policy for DuckDB schema, JSON operations, workflow, cache, audit, errors, cancellation, and progress.
3. Run the same fixture set from \`core/tests/\` and \`rust/crates/core/tests/\`; add cross-open tests in both directions for C++-created and Rust-created projects.
4. Add shared MCP protocol/tool-catalogue fixtures. C++ and Rust MCP adapters must return equivalent validated envelopes for the common tool set.

**Exit condition:** a contract change cannot merge unless both independent backends pass the relevant conformance suite or an intentional version transition is documented.

### 2. Build the consolidated Python distribution — **Next**

1. Establish \`python/pyproject.toml\`, \`python/CMakeLists.txt\`, and \`python/cpp/\` using scikit-build-core and pybind11.
2. Keep \`streamfind._core\` private and minimal: bind stable, coarse-grained C++ services and release the GIL for long native operations.
3. Implement \`streamfind.core\` as the typed, Pythonic public API with exception mapping, resource lifecycle, and progress adapters.
4. Add \`streamfind.cli\` for generic project create, describe, validate, workflow, cache, audit, and execution operations.
5. Add \`streamfind.server\` with Pydantic schemas, a service layer, health/project/workflow/job/result endpoints, and job/progress handling.
6. Move the React/TypeScript source into \`python/frontend/\`; package its build output in \`streamfind/frontend/\`.
7. Remove the top-level \`server/\` and \`frontend/\` placeholders only after their contents have been relocated.

**Exit condition:** an installed wheel can create and inspect a generic C++-backed project through the public Python API, CLI, and FastAPI, with no public consumer importing \`_core\` or opening DuckDB directly.

### 3. Keep R and Cogniflow aligned with the public C++ path — **Next**

1. Record the supported R workflows and retain regression fixtures before changing Rcpp-backed behaviour.
2. Replace duplicated generic/domain logic in R only after the equivalent C++ capability and tests exist; preserve R conversions and user ergonomics.
3. Update Cogniflow to use the installed public \`streamfind\` package and its operation catalogue when the Python baseline is available.
4. Add integration tests that prove R and Cogniflow do not access private bindings, native build steps, or DuckDB directly.

**Exit condition:** each migrated capability has one C++ implementation for the C++ ecosystem, and the R/Cogniflow layers are adapters over its public interfaces.

### 4. Deliver domain capabilities in paired, independent slices — **Future**

Start with one vertical MassSpec slice:

\`\`\`text
C++: create project → import representative input → persist → run one method → result
Rust: independently implement the same slice → run the same contract fixtures
C++ interfaces: Python API/CLI → FastAPI → React; R compatibility where supported
\`\`\`

For every shared domain capability:

1. define or update the contract and representative fixtures;
2. implement and test C++ behaviour;
3. independently implement and test Rust behaviour;
4. compare persisted data, workflow/audit/cache records, results, errors, and progress semantics;
5. expose the C++ slice through Python, CLI, server, frontend, R, and Cogniflow only where required.

Migrate NTA only after the first MassSpec slice is stable. Continue NTA in workflow dependency order: data/feature loading, processing, filtering, components, annotation, and external-tool adapters. Add Rust domain crates when a capability is large enough to justify one; do not put a parallel C++ wrapper behind a Rust crate.

### 5. Distribute and harden — **Future**

- C++: install/export packages, runtime dependencies, static/shared CI, and clean-system tests.
- Python: cross-platform wheel builds, native-runtime repair/audit, CLI/API/frontend package tests, and source-build documentation.
- Rust: workspace CI, crate versioning, external-tool diagnostics, independent MCP testing, and future server/apps release boundaries.
- R: package checks and binary packaging from \`bindings/r\`.
- Shared: schema upgrade, concurrent-writer/failure, performance, and version-compatibility test matrices.

## Definition of done for a shared capability

A capability is complete only when:

- its contract and version are documented;
- C++ and Rust implementations are independently tested against the relevant conformance fixtures;
- neither implementation calls or wraps the other;
- the C++ ecosystem exposes it through the public Python API when user-facing;
- CLI, FastAPI, React, R, and Cogniflow support is added only where required and never bypasses the public boundary;
- persistence compatibility, structured errors, cancellation, progress, and representative results are tested;
- packaging and documentation are updated.

## Deliberately removed from this roadmap

The previous plan's completed relocation/bootstrap work, standalone top-level server/frontend target, C++-as-the-only-authoritative-backend model, and initial-agent task list are obsolete. They are not retained as pending tasks. Historical detail belongs in commits and \`.plans/completed/\`, not in the active implementation roadmap.
