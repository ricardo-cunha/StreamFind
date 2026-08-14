# streamfind Living Implementation Roadmap

**Branch:** `dev_refactoring`  
**Purpose:** keep the refactor plan aligned with the implementation that exists today. This is a roadmap for unfinished work, not a record of superseded greenfield tasks.

## Status legend

| Status | Meaning |
| --- | --- |
| **Complete** | Present in the branch and covered by its component tests or build workflow. |
| **Partial** | Implemented foundation that still needs semantic, interface, or release hardening. |
| **Next** | The shortest unblocked implementation work. |
| **Future** | Deliberately sequenced after the current foundation. |

## Architecture: semantic catalogue, independent backends, generic interfaces

The centre of the architecture is the **streamfind semantic catalogue**, not either backend and not MCP. The catalogue documents the externally visible concepts and capabilities that define streamfind interoperability.

The semantic catalogue uses:

- **Turtle (`.ttl`)** as the primary authoring format;
- **SKOS** for concepts, labels, definitions, and broader/narrower relationships;
- a small **streamfind vocabulary** for domains, public operations, workflow methods, parameters, results, errors, fixture references, and interface mappings;
- **SHACL** only for completeness and consistency checks;
- backend-neutral fixtures under `tests/data/` and `tests/fixtures/` for C++/Rust conformance;
- one generated **semantic projection** for consumers that do not need to parse RDF directly.

The ontology is declarative. It contains no executable analytical logic.

### Semantic source structure

The authoritative semantic source is split into readable Turtle files under
`semantic/ontology/`:

```text
semantic/ontology/
├── vocabulary.ttl                 # streamfind vocabulary
├── shapes.ttl                     # SHACL completeness constraints
├── core/
│   ├── scheme.ttl
│   ├── parameters.ttl
│   ├── operations.ttl
│   ├── results.ttl
│   ├── errors.ttl
│   └── tables.ttl
└── domains/
    ├── mass_spec/
    │   ├── domain.ttl
    │   ├── operations.ttl
    │   ├── results.ttl
    │   └── tables.ttl
    ├── raman/raman.ttl
    └── sensors/sensors.ttl
```

All `.ttl` files are parsed recursively as Turtle. `semantic/generated/catalogue.json`
is generated from these files and is not hand-authored. `a` is retained as the
Turtle shorthand for `rdf:type`, and prefixed names are preferred over expanded
IRIs.

```text
                     semantic/ontology/**/*.ttl
       concepts • domains • operations • methods • parameters
          results • errors • documentation • fixtures • mappings
                           │
                    validate with SHACL
                           │
                           ▼
            generated semantic projection
        deterministic, backend-neutral catalogue
                           │
              ┌────────────┴────────────┐
              │                         │
              ▼                         ▼
     streamfind-core C++          streamfind Rust
     independent backend          independent backend
               │                         │
        MethodRegistry              MethodRegistry
        OperationRegistry            OperationRegistry
              │                         │
              └────────────┬────────────┘
                           ▼
                  generic MCP adapters
               catalogue + registry join
```

Rust must never link to, wrap, or call the C++ backend. Shared behaviour is established by semantic declarations and conformance fixtures, not by a shared native implementation.

The C++ ecosystem remains the native backend for the consolidated Python distribution.

## Core design principle for expansion

Adding a new method must not require editing MCP-specific dispatch tables, descriptions, argument schemas, or documentation in multiple places.

A domain method has exactly two authored parts per backend ecosystem:

1. **semantic declaration** — what the method is;
2. **backend executor registration** — how that backend executes it.

Everything else is derived generically.

```text
New method
   │
   ├── semantic/ontology/domains/<domain>/*.ttl
   │     ID, label, definition, parameters, results, errors, MCP exposure
   │
   ├── C++ implementation + registry.register(method_id, executor)
   │
   └── Rust implementation + registry.register(method_id, executor)

No method-specific MCP code.
No duplicate descriptions.
No duplicate parameter catalogue.
No per-method switch statement in MCP.
```

The same rule applies to generic `sf:Operation` capabilities where practical.

## Canonical semantic model

The ontology distinguishes generic project operations from workflow/domain methods.

```text
    sf:Operation
    generic public streamfind capability
    examples:
      create
      connect
      validate
      get_metadata
      set_metadata
      get_workflow
      set_workflow
      get_cache
      get_audit_trail
      run_method
      close

sf:Method
    workflow-executable capability owned by one domain
    examples:
      mass_spec.process_features
      mass_spec.annotate_compounds
      raman.preprocess_spectra
      sensors.detect_events

sf:Operation
    direct project/domain capability, not a workflow step
    examples:
      mass_spec.add_analyses
      mass_spec.remove_analyses
      mass_spec.get_analyses_info
      mass_spec.plot_chromatogram

Methods and operations have separate registries and execution paths. `Method`
instances are the only units allowed in `WorkflowStep` and `run_method`.
`Operation` instances are called directly through `run_operation`, are exposed
as MCP tools, and never modify the workflow. Data access, import/export, and
plotting capabilities therefore cannot accidentally become processing steps.
```

Every public capability has one canonical semantic identifier. Transports and language interfaces map to it; they do not create another domain contract.

```text
                         sf:GetWorkflow
                              │
          ┌───────────────────┼──────────────────────┐
          │                   │                      │
          ▼                   ▼                      ▼
 C++ Project API          Rust Project API     Python/CLI/FastAPI/MCP
```

For MCP, the semantic catalogue is the authoritative source for tool-facing labels, descriptions, parameter metadata, result semantics, shared errors, and examples. MCP code owns protocol handling, session state, registry lookup, execution, cancellation/progress, and backend-specific diagnostics only.

## Current implementation status

| Area | Status | Evidence in this branch | Roadmap implication |
| --- | --- | --- | --- |
| C++ backend | **Complete foundation** | Standalone C++20 `core/` with CMake, Project/JSON APIs, DuckDB persistence, workflow, cache, audit, cancellation, progress, MCP support, install rules, and tests. | Extend through domain modules; do not recreate the generic project kernel. |
| Rust backend | **Complete foundation** | `rust/` Cargo workspace with `core`, `cli`, `external`, and `mcp` crates; independent from C++. | Preserve independent implementation and modular crates. |
| Semantic catalogue | **Partial / baseline complete** | `semantic/` contains vocabulary/catalogue, SKOS metadata, SHACL, results/errors, and validation; shared semantic and MCP fixtures live under `tests/fixtures/`. | Simplify its consumption through one normalized semantic projection and extend it incrementally. |
| C++/Rust MCP | **Partial** | Both stdio servers support initialization, tools listing/calling, connection lifecycle, generic operations, domain filtering, registered domain methods, and generated semantic metadata. MCP tests now call `mass_spec.get_analyses_info` through both adapters and verify a JSON result. | Remove method-specific MCP maintenance by making MCP entirely registry/catalogue driven. |
| Domain composition | **Partial** | Registry hooks and connected-project domain filtering exist. | Formalize one minimal DomainModule/registration contract and prove it with real domain modules only as capabilities are migrated. |
| R binding | **Complete relocation / deferred alignment** | Complete R package is under `bindings/r/`. | Keep functional as-is until new backends/domain paths are mature. |
| Cogniflow integration | **Complete relocation / deferred alignment** | Integration boundary exists under `integrations/cf-streamfind/`. | Align only after the public Python path is stable. |
| Python distribution | **Future** | `bindings/python/` remains reserved. | Build after semantic/registry/MCP contracts are stable. |
| Domain capabilities | **Partial** | MassSpec has a tested C++ direct-operation slice (`add_analyses`, `remove_analyses`, `get_analyses_info`). Rust registers the same operations and exposes `get_analyses_info` through MCP, but its executor still returns an empty placeholder result pending real persistence. Raman and sensors remain composition scaffolding. | Complete one real cross-backend domain slice at a time. |

### MCP result-info verification

`mass_spec.get_analyses_info` is available through the connected-project MCP
session in both backends. The C++ MCP smoke test registers the MassSpec
operations, calls the operation through `tools/call`, and passes with an empty
JSON array for a new project. The Rust MCP protocol test performs the same
connected-session call and checks the JSON result. Both MCP test suites pass.

## Target repository shape

```text
streamfind/
├── semantic/
│   ├── ontology/
│   │   ├── vocabulary.ttl               # small sf vocabulary
│   │   ├── shapes.ttl                   # SHACL validation
│   │   ├── core/                         # generic operations, results, tables
│   │   └── domains/                      # one folder per domain
│   │       ├── mass_spec/
│   │       ├── raman/
│   │       └── sensors/
│   ├── generated/
│   │   └── catalogue.json               # generated; never hand edited
│   └── README.md
│
├── core/
│   ├── CMakeLists.txt                    # standalone C++ project
│   ├── CMakePresets.json
│   ├── build/                            # ignored generated output
│   ├── include/streamfind/
│   ├── src/
│   ├── cmake/
│   ├── domains/
│   │   ├── mass_spec/
│   │   ├── raman/
│   │   └── sensors/
│   ├── vendor/
│   ├── tests/
│   └── tools/streamfind-mcp.cpp          # generic C++ MCP executable

├── tests/
│   ├── data/
│   │   ├── mass_spec/
│   │   ├── raman/
│   │   └── project/
│   └── fixtures/
│       ├── semantic/
│       └── mcp/
│
├── bindings/
│   ├── python/
│   │   └── README.md                    # reserved future C++-backed Python binding
│   └── r/                                # existing R package
│       ├── DESCRIPTION
│       ├── R/
│       ├── src/
│       └── tests/
│
├── rust/
│   ├── Cargo.toml
│   ├── crates/
│   │   ├── core/                           # implementation + tests/
│   │   ├── cli/
│   │   ├── mcp/                         # generic Rust MCP adapter
│   │   ├── external/
│   │   ├── mass-spec/
│   │   ├── raman/
│   │   ├── sensors/
│   │   ├── server/                      # future
│   │   └── apps/                        # future
│
├── integrations/
│   └── cf-streamfind/                    # independent integration build
├── docs/
└── .plans/
```

`semantic/generated/catalogue.json` is a build/test artefact derived from the Turtle catalogue. It is not another source of truth. If committed for packaging convenience, CI must prove that regeneration produces no diff.

## Ownership and non-negotiable boundaries

### `semantic/` — authoritative public metadata

- Own canonical IDs, domains, labels, definitions, parameters, results, shared errors, fixture references, and interface mappings.
- Use one qualified ID for every domain method: `<domain>.<method>`.
- Keep generic operations and domain methods semantically distinct.
- Use SKOS parent concepts only for documentation/grouping; never infer implementation inheritance from SKOS hierarchy.
- Keep analytical data outside RDF; shared test data lives under `tests/data/` and semantic/MCP JSON fixtures under `tests/fixtures/`.
- Keep semantic declarations declarative and backend-neutral.
- New public methods are incomplete without semantic declaration and validation.

### Semantic projection — one generator, many consumers

To avoid maintaining separate C++ and Rust semantic generators, use one small repository tool to compile the Turtle catalogue into a normalized projection such as `semantic/generated/catalogue.json`.

The projection contains only data needed by native/interface consumers, for example:

```json
{
  "domains": {
    "mass_spec": {
      "operations": {
        "mass_spec.add_analyses": {
          "label": "Add analyses",
          "description": "...",
          "parameters": [],
          "result": "...",
          "errors": [],
          "mcp": {"enabled": true, "name": "add_analyses"}
        }
      }
    }
  }
}
```

Rules:

- Turtle remains authoritative.
- The projection is deterministic and generated in one place.
- C++ and Rust must not implement separate RDF interpretation logic.
- Both MCP servers consume/embed the same projection shape.
- Generation happens at development/build/package time, not on every MCP request.
- CI validates Turtle + SHACL, regenerates the projection, and detects stale generated output.

### Minimal MethodRegistry and OperationRegistry contracts

Both registries are execution registries, not metadata catalogues. `MethodRegistry`
contains workflow-processing Methods; `OperationRegistry` contains direct project
and domain Operations such as import, query, plotting, and export.

Each registry entry should contain only what is required for execution and backend diagnostics:

```text
canonical method ID
executor/callable
optional backend capability flags needed for execution
```

Do not duplicate in the registry:

```text
label
human description
parameter descriptions
MCP input schema
result documentation
shared error documentation
```

Those come from the semantic projection.

The registry must support only a small stable API, conceptually:

```text
register(method_id, executor)
has(method_id)
list_ids(domain)
invoke(method_id, context, parameters)
```

Avoid domain-specific registry subclasses and avoid adding new registry APIs for individual domains.

### Domain module contract

A domain is a separately owned implementation module, not a special case in the generic core or MCP server.

Each C++ domain library exposes one stable registration entry point, conceptually:

```cpp
void register_methods(streamfind::MethodRegistry& registry);
void register_operations(streamfind::OperationRegistry& registry);
```

Each Rust domain crate exposes the equivalent:

```rust
pub fn register_methods(registry: &mut MethodRegistry) -> Result<()>;
pub fn register_operations(registry: &mut OperationRegistry) -> Result<()>;
```

A domain module:

- implements its readers, persistence extensions, Methods, Operations, and results;
- registers executors by canonical qualified ID in the matching registry;
- does not provide MCP descriptions or schemas;
- does not alter the generic Project API;
- does not depend on other domains unless an explicit cross-domain architecture is approved;
- is independently testable.

### Application composition

Domain discovery at runtime is **not required** for the initial architecture. Avoid a plugin ABI/dynamic-library loader until there is a concrete distribution need for third-party domain plugins.

For now, applications explicitly compose the domains they ship:

```text
C++ MCP executable
  register mass_spec Operations
  register raman
  register sensors

Rust MCP executable
  register mass-spec Operations
  register raman crate
  register sensors crate
```

This is deliberately one small composition point per application, not one MCP edit per method.

Adding the tenth MassSpec method therefore does not change the MCP executable. Adding a completely new domain requires only adding the domain module to the application composition once.

### Generic MCP adapter

Both MCP implementations follow the same generic algorithm:

```text
initialize
   │
   ▼
load/embed semantic projection
   │
   ▼
compose MethodRegistry + OperationRegistry
   │
   ▼
connect(project)
   │
   ├── read immutable project domain
   │
   ▼
tools/list
   │
   ├── generic operations
   ├── direct domain Operations for the connected domain
   └── intersection of:
         semantic Methods/Operations for connected domain
         AND
         registered executable IDs in the matching registry
   │
   ▼
tools/call
   │
   ├── resolve advertised MCP name -> canonical Method or Operation ID from projection
   ├── validate parameters using projected contract
   └── matching registry invokes the canonical ID
```

The **intersection rule** is important: a semantic declaration alone must not advertise an unavailable executable, and a registered executor without a semantic declaration must fail validation/build tests rather than become an undocumented tool.

The MCP servers must not contain per-domain or per-method `if`, `switch`, or match branches for normal method discovery/dispatch.

### Domain and method identity rules

- Generic operations retain canonical generic IDs.
- Domain methods always use `<domain>.<method>` internally and in workflows.
- The connected project has one immutable domain.
- MCP may expose a shorter local tool name after connection if unambiguous, but resolution must immediately map back to the canonical qualified ID.
- A domain method from another domain must never be callable in the current session.
- Same local names across domains are allowed because canonical IDs are qualified.
- Cross-domain SKOS parents are documentation concepts only.
- Do not create placeholder analytical methods merely to populate a domain. Add methods when their public contract is actually agreed.
- Do not advertise unsupported placeholder methods in normal MCP catalogues. If a capability is intentionally declared before implementation, mark it explicitly as non-executable in semantics and exclude it from the registry/catalogue intersection.

### C++ backend

- Keep `streamfind_core` domain-neutral.
- Domain libraries depend on the generic core; the generic core never depends on domains.
- C++ MCP consumes the semantic projection generically and dispatches through the matching `MethodRegistry` or `OperationRegistry`.
- No hand-written MCP description/schema duplicates are allowed for semantic capabilities.

### Rust backend

- Keep `streamfind-rust-core` domain-neutral.
- Domain crates depend on Rust core; Rust core never depends on domain crates.
- Rust MCP consumes the same semantic projection shape and dispatches through its `MethodRegistry` or `OperationRegistry`.
- Rust remains independent from C++.

### Python distribution

- Own pybind11, public Python API, CLI, FastAPI service layer, React source, and packaged frontend assets.
- Public Python code uses the high-level `streamfind.core` API, not `_core` directly.
- Python/CLI/FastAPI mappings reuse semantic labels/descriptions and canonical IDs where useful.
- The frontend communicates only with FastAPI/OpenAPI.

### Public capability rule

Any externally visible Project operation, Method, CLI command, MCP tool, endpoint, or integration capability must map to a canonical semantic declaration.

For a domain Method or Operation, the minimal change set is:

```text
required once:
  semantic declaration
  fixture(s)

required per implementing backend:
  executor implementation
  one registry registration
  backend tests

not required:
  MCP description edits
  MCP schema edits
  MCP dispatch branches
  duplicated method metadata
```

## Roadmap

### 1. Finish the semantic projection and generic MCP contract — **Complete**

The generic semantic/MCP baseline already exists. The remaining work should simplify consumption rather than add another abstraction layer.

1. Consolidate semantic extraction into **one** deterministic generator that produces `semantic/generated/catalogue.json` (or an equivalently simple backend-neutral projection).
2. Remove the need for separate hand-authored/generated semantic metadata models in C++ and Rust; both backends consume/embed the same projection format.
3. Ensure the projection includes only public metadata needed by consumers: domain, canonical ID, label/definition, parameters, result/errors, executable/exposure flags, MCP mapping, and fixture references where useful.
4. Keep generic operations and domain methods in the same projection format but as distinct semantic types.
5. Add CI checks:
   - RDF/Turtle parsing;
   - SHACL validation;
   - duplicate canonical IDs;
   - invalid/unqualified domain method IDs;
   - stale generated projection;
   - fixture references exist;
   - MCP names are unique within a connected domain.
6. Keep MCP lifecycle conformance covering initialize, connect, pre/post-connect tools, calls, errors, close, cancellation, and progress.

**Exit condition:** one semantic source and one generated projection drive both MCP catalogues; neither backend maintains a duplicate public metadata catalogue. Complete in this branch; Phase 1.5 is the next implementation phase.

### 1.5. Stabilise domain composition and registry-driven MCP — **Active**

This phase proves that domains can expand without expanding MCP maintenance. The
composition skeleton is present for `mass_spec`, `raman`, and `sensors` in both
backends. MassSpec direct Operations are registered in both backends; the C++
add/remove/info path is tested, while Rust persistence remains pending.

#### A. Stabilise the registry

1. Keep `MethodRegistry` and `OperationRegistry` separate: Methods are workflow units; Operations are direct Project/MCP calls.
2. Keep each registry to the minimal execution API: register, list IDs by domain, lookup/invoke, duplicate rejection.
3. Add tests proving:
   - duplicate IDs fail;
   - malformed/unqualified domain IDs fail;
   - listing by domain is exact;
   - invocation is by canonical qualified ID.

#### B. Stabilise domain modules

1. Create a domain library/crate only when that domain has an agreed capability to implement. Do not create empty or fake method catalogues merely to prove extensibility.
2. Each domain has matching `register_methods` and/or `register_operations` entry points for the capabilities it owns.
3. The application composition root registers each shipped domain exactly once.
4. Adding methods inside an already composed domain must require no changes to MCP/application composition.
5. Add one small real or test-only registry fixture per starting domain to prove filtering if the analytical migration is not ready yet; do not expose fake production tools.

#### C. Make MCP completely generic for domain Methods and Operations

1. At `tools/list`, take the connected project domain and compute:

   ```text
    semantic Methods and Operations for domain
             ∩
   registered executable IDs
   ```

2. Build MCP tool metadata entirely from the semantic projection.
3. Resolve calls generically from MCP mapping to a canonical ID and invoke the matching registry.
4. Remove or forbid per-domain/per-method MCP dispatch branches for normal domain methods.
5. Add conformance tests for both a workflow Method and a direct Operation, proving each appears and executes **without editing MCP source**.
6. Run the same test pattern in C++ and Rust.

#### D. New-domain maintenance test

Add a repository-level test/example documenting the exact steps for a future domain, for example `imaging`:

```text
1. semantic/ontology/domains/imaging/*.ttl
2. core/domains/imaging/ OR rust/crates/imaging/
3. implement executors
4. register methods inside the domain module
5. add the domain module once to the application composition
6. add fixtures/tests
```

No MCP tool definition or dispatch file may need editing.

**Exit condition:** adding a method to an existing domain requires semantic declaration + executor registration only; adding a new domain requires one semantic domain file, one backend domain module, and one composition entry per shipping application. Both MCP servers discover/document/dispatch its methods generically.

### 2. Build the consolidated Python distribution — **Future / after Section 1.5**

1. Establish `bindings/python/pyproject.toml`, `bindings/python/CMakeLists.txt`, and `bindings/python/cpp/` using scikit-build-core and pybind11.
2. Keep `streamfind._core` private and minimal.
3. Implement `streamfind.core` as the typed public Python API.
4. Add `streamfind.cli` for generic project and workflow operations.
5. Add `streamfind.server` with Pydantic schemas, service layer, project/workflow/job/result endpoints, and progress handling.
6. Keep React/TypeScript source in `bindings/python/frontend/` and package build output with the Python distribution.
7. Remove legacy top-level `server/` and `frontend/` placeholders after relocation.
8. Reuse semantic metadata for developer-facing method/API documentation where practical; do not introduce a second method catalogue in Python.

**Exit condition:** an installed wheel can operate a generic C++-backed project through Python API, CLI, and FastAPI without consumers accessing `_core` or DuckDB directly.

### 3. Deliver real domain capabilities in independent vertical slices — **Future**

Start with one MassSpec capability that provides real value end to end.

```text
semantic declaration + fixture
          │
     ┌────┴────┐
     ▼         ▼
   C++       Rust
 executor   executor
     │         │
 registry    registry
     └────┬────┘
          ▼
 generic MCP exposure
```

For each shared domain capability:

1. define/update the semantic Method or Operation, parameters, result/error semantics, exposure flags, and fixture;
2. implement C++ behaviour and register it in `MethodRegistry` or `OperationRegistry`;
3. independently implement Rust behaviour and register it in the matching registry;
4. run the same conformance fixtures;
5. compare persistence, workflow, audit/cache, results, errors, cancellation, and progress where applicable;
6. expose the C++ capability through Python/FastAPI/frontend where required;
7. do **not** edit MCP-specific method code unless the MCP protocol adapter itself changes.

Migrate NTA only after a stable MassSpec vertical slice. Continue in workflow dependency order.

**Exit condition:** real domain methods can be added repeatedly without growing generic MCP code or duplicating semantic metadata.

### 4. Distribution, CI, and documentation hardening — **Future**

- C++: install/export packages, runtime dependencies, static/shared CI, clean-system tests.
- Python: cross-platform wheels, native-runtime repair/audit, package/frontend tests.
- Rust: workspace CI, crate versioning, external-tool diagnostics, server/apps release boundaries.
- Semantic: catalogue versioning, SHACL, fixture integrity, projection regeneration, documentation generation.
- MCP: common lifecycle/domain conformance and proof that tool catalogues remain semantic/registry driven.
- Documentation: generate or semi-generate method/domain/MCP references from the semantic catalogue rather than maintaining parallel hand-written inventories.

### 5. Align R and Cogniflow with the completed public C++ path — **Future, final phase**

1. Preserve R regression fixtures before changing Rcpp-backed behaviour.
2. Replace duplicated R generic/domain logic only after equivalent C++ capabilities exist.
3. Map R public operations/methods to canonical semantic identifiers.
4. Update Cogniflow to consume the installed public `streamfind` Python package and canonical semantic catalogue.
5. Ensure R and Cogniflow do not access private bindings or DuckDB directly.
6. Remove obsolete transition code only after regression/conformance coverage passes.

## Definition of done for a domain capability

A domain Method or Operation is complete only when:

- one canonical qualified semantic ID exists;
- its semantic type is explicit: `sf:Method` for workflow processing or `sf:Operation` for direct Project/MCP access;
- label, definition, domain, parameters, results, shared errors, and exposure mappings are documented in Turtle;
- SHACL/semantic validation passes;
- representative fixture coverage exists;
- each implementing backend provides an independently tested executor in the matching registry under the same canonical ID;
- registry and semantic projection agree that the capability exists;
- C++/Rust shared behaviour is tested where harmonisation is required;
- Methods participate in workflow validation/execution; Operations use `run_operation`, never become workflow steps, and are exposed generically through MCP;
- MCP exposure, documentation, parameter validation, and dispatch occur generically without capability-specific MCP code;
- user-facing Python/API/UI mappings are added where required;
- packaging and documentation are updated.

## Maintenance acceptance criteria

The architecture should be considered successful only if these remain true as streamfind grows:

- **Add method to existing domain:** no generic core or MCP source changes.
- **Add domain:** one domain semantic file + one domain implementation module + one application composition entry per backend/application that ships it.
- **Change documentation:** edit semantic catalogue once; C++/Rust MCP documentation follows after regeneration.
- **Change parameter contract:** edit semantic declaration and backend executor validation/tests; no duplicate MCP schema edits.
- **Add backend:** consume the same semantic projection and implement the same minimal registry contract.
- **No ontology runtime requirement:** deployed native backends may embed/package the generated projection rather than run an RDF stack.
- **No hidden drift:** CI rejects registered methods without semantics and semantic executable methods without a matching registered implementation in tested distributions.

## Deliberately avoided

The roadmap intentionally avoids:

- runtime RDF parsing in every backend;
- separate C++ and Rust ontology models/generators;
- method-specific MCP switch statements;
- duplicated descriptions and parameter schemas;
- generic-core dependencies on domain modules;
- dynamic shared-library/plugin ABI complexity before there is a real third-party plugin requirement;
- placeholder production methods used only to demonstrate extensibility;
- a second metadata registry competing with `semantic/`.

Historical bootstrap and superseded architecture detail belongs in commits and `.plans/completed/`, not in this active roadmap.
