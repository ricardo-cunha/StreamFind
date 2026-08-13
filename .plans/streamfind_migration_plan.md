# StreamFind Living Implementation Roadmap

**Branch:** `dev_refactoring`  
**Purpose:** keep the refactor plan aligned with the implementation that exists today. This is a roadmap for unfinished work, not a record of superseded greenfield tasks.

## Status legend

| Status | Meaning |
| --- | --- |
| **Complete** | Present in the branch and covered by its component tests or build workflow. |
| **Partial** | Implemented foundation that still needs semantic, interface, or release hardening. |
| **Next** | The shortest unblocked implementation work. |
| **Future** | Deliberately sequenced after the current foundation. |

## Architecture: semantic contract first, independent backends

The centre of the architecture is the **StreamFind semantic contract catalogue**, not either backend. The catalogue is a backend-neutral ontology that documents the concepts and externally visible capabilities that define StreamFind interoperability.

The semantic catalogue is stored primarily as TriG and uses:

- **SKOS** for concepts, labels, definitions, broader/narrower relationships, and documentation;
- a small **StreamFind vocabulary** for operational relationships such as domains, public operations, workflow methods, parameters, result/error semantics, fixtures, and interface mappings;
- **SHACL** only where useful to validate that required semantic declarations are complete and consistent;
- backend-neutral **fixtures** referenced by the ontology and consumed by C++ and Rust conformance tests.

The ontology describes what a StreamFind capability means. It does not contain executable business logic and must not become a third backend or framework.

```text
                    StreamFind semantic catalogue
              SKOS concepts • sf:Operation • sf:Method
       domains • parameters • results • errors • fixtures • mappings
                             TriG + SHACL
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
```

The C++ and Rust backends must implement the same semantic contract where a capability is shared, but **Rust must never link to, wrap, or call the C++ backend**. Differences are exposed by conformance tests and resolved either in the semantic contract or in the implementation; they are not hidden behind an adapter.

The C++ ecosystem is the only native backend for the consolidated Python distribution. Python, FastAPI, the React frontend, the R binding, and Cogniflow do not select or abstract over a Rust backend unless a separate architecture decision explicitly introduces that capability.

### Canonical semantic model

The ontology distinguishes generic backend operations from workflow/domain methods.

```text
sf:Operation
    generic public StreamFind capability
    examples:
      create
      validate
      get_metadata
      set_metadata
      get_workflow
      set_workflow
      get_cache
      get_audit_trail
      run_method

sf:Method
    workflow-executable capability available under a domain
    examples:
      mass_spec.load_chromatograms
      mass_spec.filter_retention_time
```

A public capability has one canonical semantic identifier. Language bindings and transports map to that identifier instead of defining their own domain contract.

```text
                         sf:GetWorkflow
                              │
          ┌───────────────────┼────────────────────┐
          │                   │                    │
          ▼                   ▼                    ▼
 C++ Project::get_workflow  Rust API       Python/FastAPI/MCP mapping
```

FastAPI routes, CLI commands, MCP tools, React actions, R wrappers, and Cogniflow operations are therefore **interface mappings to canonical StreamFind operations or methods**, not independent domain definitions.

For MCP specifically, the semantic catalogue is also the canonical source for shared tool documentation. Tool labels, descriptions, parameter metadata, result semantics, and shared error descriptions are authored once in `semantic/` and projected into or validated against both the C++ and Rust MCP tool catalogues. Backend MCP code owns dispatch and execution only; it must not maintain a second hand-written documentation catalogue for the same capability.

### C++ ecosystem

```text
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
```

### Rust ecosystem

```text
streamfind-rust-core ──► streamfind-rust-cli
          │
          ├──────────────► streamfind-rust-mcp
          ├──────────────► streamfind-rust-external
          └──────────────► future streamfind-rust-server / apps crates

Each crate uses Rust-owned APIs and dependencies. None depends on
streamfind-core (C++).
```

## Current implementation status

| Area | Status | Evidence in this branch | Roadmap implication |
| --- | --- | --- | --- |
| C++ backend | **Complete foundation** | Standalone C++20 `core/` with CMake, public `Project` and JSON APIs, DuckDB persistence, workflow, cache, audit, cancellation, progress, MCP support, install rules, and native tests. | Extend by coherent capability slices; do not recreate the generic project kernel. |
| Rust backend | **Complete foundation** | `rust/` is a Cargo workspace with `core`, `cli`, `external`, and `mcp` crates. Its README states that it is independent from C++. | Preserve independent implementation and modular-crate boundaries. |
| Shared semantic contract | **Partial** | C++ and Rust already share `PROJECT`, `CACHE`, and `AUDIT_TRAIL` persistence; JSON/workflow/cache/audit/error/cancellation/progress conventions; and the `project_conformance.json` fixture exercised by both backends. | Promote the shared public model into a backend-neutral semantic catalogue and make it the documented source for verification, validation, usage, and conformance. |
| C++/Rust MCP | **Partial** | Both stdio servers implement `initialize`, `tools/list`, `tools/call`, `project_connect`, generic project tools, and per-session domain filtering. `project_connect` binds the immutable project domain; `project_close` clears the binding; registered domain methods are advertised and dispatched against the connected project. Rust MCP protocol tests cover the session foundation; C++ currently has build coverage but needs matching focused MCP tests. | Replace the duplicated hand-written catalogues with one semantic source or generated/validated metadata; add cross-backend catalogue and lifecycle conformance tests; handle remaining MCP protocol details consistently. |
| R binding | **Complete relocation / Deferred alignment** | The complete R package, native sources, tests, vignettes, and package assets are under `bindings/r/`. | Keep it functional as-is. Do not refactor, redirect, or add transition helpers until the C++/Python and Rust domain implementations are complete. |
| Cogniflow integration | **Complete relocation / Deferred alignment** | `integrations/cf-streamfind/` exists as the integration boundary. | Keep it at its present boundary until final alignment, after the C++/Python and Rust domain implementations are complete. |
| Python distribution | **Future** | `python/` is currently a reserved placeholder. | Start only after the semantic catalogue and shared MCP contract are established; build one distributable C++-backed Python package, including CLI, FastAPI, and frontend integration. |
| Standalone `server/` and `frontend/` roots | **Legacy placeholders** | Each currently contains only a README. | Absorb their responsibilities into `python/`; remove the placeholder roots in the same relocation change. |
| Domain capabilities | **Future** | The generic backend layer and registry hooks are present; no completed end-to-end MassSpec or NTA replacement slice is established here. | Add each externally visible capability to the semantic catalogue first, then register and implement it independently in the relevant C++ and Rust domain crates/modules. |

## Target repository shape

This is the intended shape after the next consolidation. Paths marked `[next]` do not yet exist; it is not a claim that they are implemented.

```text
streamfind/
├── semantic/                          # [next] backend-neutral semantic contract catalogue
│   ├── streamfind.trig                # concepts, operations, methods, domains, parameters
│   ├── vocabulary.ttl                 # small StreamFind vocabulary
│   ├── shapes.trig                    # SHACL completeness/consistency rules
│   ├── fixtures/
│   │   ├── project/
│   │   ├── workflow/
│   │   ├── mass_spec/
│   │   └── ...
│   └── README.md
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
│   └── r/                             # retained and unchanged during active development
│
├── integrations/
│   └── cf-streamfind/                 # Cogniflow integration
│
├── docs/
├── dev/
└── .plans/
```

The top-level `server/` and `frontend/` placeholders are intentionally absent from the target tree. Their source moves to `python/frontend/`, their runtime code to `python/src/streamfind/server/`, and built frontend assets to `python/src/streamfind/frontend/`.

## Ownership and non-negotiable boundaries

### `semantic/` — StreamFind semantic contract catalogue

- Own the backend-neutral definitions of externally visible StreamFind concepts and capabilities.
- Use SKOS for concepts, labels, definitions, and conceptual relationships.
- Use a small StreamFind vocabulary for operational relationships such as `sf:Operation`, `sf:Method`, `sf:Domain`, `sf:Parameter`, `sf:Fixture`, `sf:appliesTo`, `sf:availableInDomain`, `sf:hasParameter`, `sf:returns`, `sf:errorCode`, `sf:operationId`, and fixture/interface mappings where required.
- Use TriG as the primary authoring format. Named graphs may separate concepts, generic operations, domain methods, fixtures, and mappings when this improves clarity.
- Use SHACL only to validate semantic completeness and consistency, for example requiring each public `sf:Operation` or `sf:Method` to have a canonical identifier, label, definition, applicable domain/target, parameters where relevant, and result/error semantics.
- Document every externally visible Project function, generic operation, domain Method, parameter, result/error contract, and shared transport mapping needed for verification or usage.
- Own the shared MCP-facing documentation metadata for canonical capabilities: tool labels/descriptions, parameter documentation, result semantics, shared error descriptions, and stable MCP mappings where applicable. MCP backends may add implementation-specific runtime details only when those details are not part of the shared public contract.
- Require new public capabilities to reference a canonical ontology declaration before they are considered complete.
- Keep small fixtures directly in or alongside the semantic catalogue when practical. Reference larger analytical fixtures by repository path rather than embedding large datasets in RDF.
- Keep the ontology declarative. Do not place executable business logic, backend-specific classes, HTTP handlers, UI state, or language-specific implementation code in `semantic/`.
- Until `semantic/` is created, the existing shared fixture remains the operative conformance source. Moving it must preserve both C++ and Rust test coverage.

### `core/` — C++

- Own C++ project lifecycle, DuckDB, native readers/algorithms, workflow execution, results, and C++ JSON/MCP entry points.
- Build without R, Python, pybind11, FastAPI, Node.js, or React.
- Provide the native API consumed by the Python private extension; it does not embed Python, FastAPI, React, Cogniflow, or R conversion code.
- Map every externally visible generic operation and domain Method to the canonical semantic identifier declared in `semantic/`.
- Run conformance tests against the shared semantic catalogue and fixtures for every supported shared capability.
- The C++ MCP server must derive or validate shared tool names, descriptions, parameter metadata, result semantics, and error documentation from `semantic/`; C++ MCP code keeps only dispatch/execution logic and implementation-specific runtime handling.

### `rust/` — Rust

- Own the independent Rust project, persistence, workflow, algorithms, Rust CLI, MCP, external-tool integration, and future Rust server/apps.
- Use Rust-owned APIs and dependencies. Rust may use appropriately isolated native libraries where needed, but it must not depend on `streamfind-core` or C++ project APIs.
- Map every externally visible generic operation and shared domain Method to the same canonical semantic identifier used by C++.
- Implement shared capabilities independently and prove compatibility by consuming the same semantic catalogue and fixtures.
- The Rust MCP server must derive or validate shared tool names, descriptions, parameter metadata, result semantics, and error documentation from `semantic/`; Rust MCP code keeps only dispatch/execution logic and implementation-specific runtime handling.

### `python/` — consolidated C++ distribution

- Own the package build, private `_core` pybind11 extension, public Python API, CLI, FastAPI service layer, React/TypeScript source, and packaged frontend assets.
- Public Python code, CLI commands, FastAPI routes, and integrations use `streamfind.core`, never `_core` directly.
- FastAPI routes call a Python service layer. Long workflows run outside request handlers and report structured job/progress state.
- The frontend calls the FastAPI/OpenAPI contract only; it never opens DuckDB or calls native bindings.
- Python functions, CLI commands, and FastAPI endpoints map to canonical semantic operations/methods; they do not define a competing StreamFind domain contract.
- The semantic catalogue may be used to generate or enrich documentation and operation metadata, but runtime business logic must remain in the backend/application layers.

### `bindings/r` and `integrations/`

- `bindings/r` remains an installable, functional R package as it is. During active C++/Python and Rust development, do not refactor it, redirect it to the C++ core, or add compatibility/migration helpers.
- `integrations/cf-streamfind` remains at its current boundary until final alignment. When that work is intentionally started, it translates Cogniflow contracts to the public Python API and must not compile C++, include C++ headers, link native runtimes, access DuckDB, or import `_core`.
- Final R and Cogniflow alignment must reference the same canonical semantic operations/methods rather than inventing parallel identifiers.

### Public capability documentation rule

Any newly added externally visible endpoint, function, Project operation, workflow Method, CLI command, MCP tool, or integration capability must map to a canonical ontology declaration.

A new public capability is incomplete until the semantic catalogue contains enough information to support:

- **documentation** — what the concept/capability is and when it is used;
- **verification** — which canonical identifier and domain/target it belongs to;
- **validation** — required parameters, result/error semantics, and SHACL completeness where applicable;
- **usage** — stable operation/method names and interface mappings;
- **harmonisation testing** — one or more shared fixtures that can be consumed by C++ and Rust when the capability is common to both backends.

For MCP mappings, this rule additionally means that shared tool descriptions and parameter/result/error documentation are maintained in the semantic catalogue, not duplicated separately in `core/tools/` and `rust/crates/mcp/`.

### Legacy-free development rule

- Do not create legacy fallbacks, compatibility shims, forwarding modules/packages, dual execution paths, duplicate source trees, transitional adapters, or migration helpers during the development phase.
- Do not retain an old interface or build path because a target implementation is incomplete; complete the target boundary instead.
- Keep relocations atomic: after a completed move, there is one owning implementation path.
- A compatibility or data-migration mechanism is allowed only for an explicitly approved, separately scoped released-version transition, with a removal date and dedicated tests. Never add one speculatively.

## Roadmap

### 1. Establish the semantic StreamFind contract catalogue — **Next / current work**

The purpose of this phase is to convert the compatibility that already exists between C++ and Rust into one simple, documented, backend-neutral semantic catalogue that can also drive conformance testing and user/developer documentation.

#### Immediate execution order

- Inventory the currently exposed generic operations and MCP tools from the C++ and Rust implementations; record intentional differences as issues, not silent drift.
- Create the minimal `semantic/` catalogue for the generic Project contract, MCP mappings, domains, methods, parameter metadata, and stable error identifiers.
- Add a small validator or test fixture reader that checks required declarations and canonical identifiers. Prefer repository scripts and existing language tooling over a new runtime dependency.
- Add one shared MCP catalogue fixture and compare C++ and Rust `tools/list` output after normalizing ordering and backend-specific server metadata.
- Add a session lifecycle fixture covering `initialize`, `project_connect`, pre-connect `tools/list`, post-connect domain filtering, domain-method dispatch, and `project_close`.
- Only after these checks pass, start the first domain slice and the Python distribution work.

1. Create `semantic/` with a compact initial structure. Do not add a generator, RDF runtime, or SHACL dependency until a concrete validation need requires it:

   ```text
   semantic/
   ├── streamfind.trig
   ├── vocabulary.ttl
   ├── shapes.trig
   ├── fixtures/
   │   ├── project/
   │   ├── workflow/
   │   └── mass_spec/
   └── README.md
   ```

2. Define the initial SKOS concept scheme and small StreamFind vocabulary. At minimum, represent:

   - `Project` and other externally visible core concepts;
   - analytical domains such as `MassSpec`;
   - generic public `sf:Operation` concepts such as `create`, `validate`, `get_metadata`, `set_metadata`, `get_workflow`, `set_workflow`, `get_cache`, `get_audit_trail`, and `run_method`;
   - workflow/domain `sf:Method` concepts such as future MassSpec processing methods;
   - parameters, result semantics, error codes, fixtures, and interface mappings needed for validation and usage.

3. Use canonical identifiers consistently. For example, a generic `get_workflow` operation and a domain method such as `mass_spec.load_chromatograms` each have one ontology identifier that is reused by C++, Rust, Python, CLI, MCP, FastAPI, R, and Cogniflow mappings where applicable.

4. Add concise labels and definitions for every externally visible capability. The ontology must be useful as documentation, not only as machine metadata.

5. Add SHACL shapes that validate semantic completeness without overengineering the model. Typical rules include requiring each public operation/method to have:

   - one canonical operation/method identifier;
   - a preferred label and definition;
   - an applicable Project target or domain;
   - declared parameters where relevant;
   - result/error semantics sufficient for verification and testing.

6. Reference the existing `project_conformance.json` fixture from the semantic catalogue without moving it until both consumers use the new path. Preserve both C++ and Rust tests. Add shared fixtures incrementally for workflow, cache, audit, errors, cancellation, progress, and later domain methods.

7. Keep small JSON input/expected-result examples directly in semantic fixture metadata when convenient. Store larger DuckDB files, chromatograms, spectra, or analytical datasets under `semantic/fixtures/` and reference them from TriG rather than embedding large payloads in RDF.

8. Update C++ and Rust conformance tests so both backends consume the same semantic declarations and fixtures. Tests should verify, as applicable:

   - canonical operation/method identifiers;
   - target/domain assignment;
   - parameter names, types, and required/optional status;
   - expected result and error behaviour;
   - persistence compatibility;
   - cross-open behaviour for C++-created and Rust-created projects;
   - audit/cache/workflow harmonisation;
   - cancellation and progress semantics.

9. Add common MCP mappings to the same ontology catalogue. Represent the common MCP tool name and its mapping to the canonical `sf:Operation` or `sf:Method`, while keeping MCP as a transport mapping rather than a second domain definition.

10. Harmonise **both MCP servers** from the semantic catalogue as the shared source for MCP-facing documentation and contract metadata:

    - C++ `core/tools/` and Rust `rust/crates/mcp/` must derive or validate common MCP tool names, labels/descriptions, parameter names/types/required status, result semantics, and shared error descriptions from the same semantic declarations;
    - the two MCP implementations must not maintain parallel hand-written descriptions for capabilities already documented in `semantic/`;
    - backend-specific code continues to own tool dispatch, execution, transport handling, cancellation/progress integration, and backend-specific diagnostics;
    - add conformance tests that compare each MCP server's advertised tool catalogue against the ontology and shared fixtures, including tool presence, canonical mapping, arguments, descriptions, result/error envelopes, and common examples;
     - start with a small build/test-time validator rather than runtime ontology loading; generate MCP metadata only if the validator demonstrates that static duplication is costly. The semantic declaration remains authoritative in all cases.

11. Keep transport definitions subordinate to the canonical capability. A FastAPI endpoint such as `GET /projects/{id}/workflow` or an MCP tool such as `streamfind_get_workflow` maps to `sf:GetWorkflow`; it does not create a second domain contract.

**Exit condition:** `semantic/` exists with the initial vocabulary, declarations, fixtures, and validation instructions; both backends consume or validate the same canonical identifiers; C++ and Rust MCP tests compare the common tool names/schemas and session lifecycle; pre-connect catalogues contain only generic tools; post-connect catalogues contain only methods for the connected domain; `project_close` clears the session in both implementations. New public shared capabilities cannot be considered complete without the same semantic declaration and conformance coverage.

### 2. Build the consolidated Python distribution — **Future / after Section 1**

1. Establish `python/pyproject.toml`, `python/CMakeLists.txt`, and `python/cpp/` using scikit-build-core and pybind11.
2. Keep `streamfind._core` private and minimal: bind stable, coarse-grained C++ services and release the GIL for long native operations.
3. Implement `streamfind.core` as the typed, Pythonic public API with exception mapping, resource lifecycle, and progress adapters.
4. Add `streamfind.cli` for generic project create, describe, validate, workflow, cache, audit, and execution operations.
5. Add `streamfind.server` with Pydantic schemas, a service layer, health/project/workflow/job/result endpoints, and job/progress handling.
6. Move the React/TypeScript source into `python/frontend/`; package its build output in `streamfind/frontend/`.
7. Remove the top-level `server/` and `frontend/` placeholders only after their contents have been relocated.
8. Map each public Python function, CLI command, and FastAPI endpoint to the canonical ontology operation/method. Reuse ontology labels/definitions where practical for generated or developer-facing documentation rather than maintaining duplicate descriptions.

**Exit condition:** an installed wheel can create and inspect a generic C++-backed project through the public Python API, CLI, and FastAPI, with no public consumer importing `_core` or opening DuckDB directly, and the externally visible operations map to the semantic StreamFind catalogue.

### 3. Deliver domain capabilities in paired, independent slices — **Future / after the first semantic slice**

Start with one vertical MassSpec slice:

```text
Semantic catalogue: define domain concept + Method + parameters + fixture

C++:  create project → import representative input → persist → run Method → result
Rust: independently implement the same slice → run the same semantic fixtures

C++ interfaces: Python API/CLI → FastAPI → React
```

For every shared domain capability:

1. add or update its ontology concept, canonical Method identifier, domain, parameters, result/error semantics, and representative fixture;
2. validate the semantic declaration with SHACL where applicable;
3. implement and test C++ behaviour against the shared fixture;
4. independently implement and test Rust behaviour against the same fixture;
5. compare persisted data, workflow/audit/cache records, results, errors, cancellation, and progress semantics where relevant;
6. expose the C++ slice through Python, CLI, server, and frontend where required, mapping each interface to the same canonical Method;
7. when the Method is exposed through MCP, add its MCP mapping and documentation once to `semantic/`, then verify that both C++ and Rust MCP servers expose compatible tool metadata from the same declaration.

Migrate NTA only after the first MassSpec slice is stable. Continue NTA in workflow dependency order: data/feature loading, processing, filtering, components, annotation, and external-tool adapters. Add Rust domain crates when a capability is large enough to justify one; do not put a parallel C++ wrapper behind a Rust crate.

**Exit condition:** the required C++/Python and independent Rust implementations, including their domain-specific capabilities, have completed their semantic conformance and interface matrices. Only then may final R and Cogniflow alignment start.

### 4. Distribute and harden the C++/Python and Rust paths — **Future**

- C++: install/export packages, runtime dependencies, static/shared CI, and clean-system tests.
- Python: cross-platform wheel builds, native-runtime repair/audit, CLI/API/frontend package tests, and source-build documentation.
- Rust: workspace CI, crate versioning, external-tool diagnostics, independent MCP testing, and future server/apps release boundaries.
- Semantic/shared: ontology validation, fixture integrity, cross-backend conformance, schema upgrade, concurrent-writer/failure, performance, and version-compatibility test matrices.
- MCP: test that C++ and Rust publish compatible common tool catalogues and that shared MCP documentation remains traceable to the semantic declarations rather than backend-local copies.
- Documentation: use ontology concepts, labels, definitions, operation/method metadata, and interface mappings to support generated or semi-generated API/method/MCP documentation where useful.

**Exit condition:** the full C++/Python and Rust paths are supported independently, including the completed domain capabilities and release-quality semantic/conformance coverage.

### 5. Align R and Cogniflow with the completed public C++ path — **Future, final phase**

This phase begins only after Sections 1–4 are complete. Until then, `bindings/r` remains functional as-is and `integrations/cf-streamfind` is not refactored for the new Python path.

1. Record the supported R workflows and retain regression fixtures before changing Rcpp-backed behaviour.
2. Replace R-owned duplicated generic/domain logic only after the equivalent completed C++ capability exists. Retain R-specific conversion, ergonomics, and reporting.
3. Map R public operations and methods to the canonical semantic identifiers where they represent the same StreamFind capability.
4. Update Cogniflow to use the installed public `streamfind` package and the canonical semantic operation/method catalogue.
5. Add integration tests proving R and Cogniflow do not access private bindings, native build steps, or DuckDB directly.
6. Remove only explicitly identified obsolete R/Cogniflow code after the replacement passes its full regression and semantic conformance suite. Do not add legacy fallbacks or migration helpers.

**Exit condition:** R and Cogniflow are thin, tested adapters over the completed public C++/Python path and map shared capabilities to the same semantic StreamFind catalogue, with no transition scaffolding added during the development phase.

## Definition of done for a shared capability

A capability is complete only when:

- it has one canonical semantic declaration in `semantic/`;
- its SKOS label/definition and StreamFind operation/method metadata are sufficient for documentation and usage;
- its parameters, result/error semantics, target/domain, and relevant interface mappings are declared;
- the semantic declaration passes SHACL completeness/consistency validation where applicable;
- at least one backend-neutral fixture exists when harmonised behaviour must be tested;
- C++ and Rust implementations are independently tested against the relevant shared fixtures when the capability is common to both backends;
- neither implementation calls or wraps the other;
- the C++ ecosystem exposes it through the public Python API when user-facing;
- CLI, FastAPI, React, R, MCP, and Cogniflow support is added only where required and maps to the canonical capability rather than bypassing the public boundary;
- MCP-exposed shared capabilities obtain their authoritative tool descriptions, parameter/result/error documentation, and canonical mappings from `semantic/`, with C++ and Rust MCP catalogues generated from or validated against the same declarations;
- persistence compatibility, structured errors, cancellation, progress, and representative results are tested where applicable;
- packaging and documentation are updated.

## Deliberately removed from this roadmap

The previous plan's completed relocation/bootstrap work, standalone top-level server/frontend target, C++-as-the-only-authoritative-backend model, JSON-schema-heavy `contracts/` hierarchy, and initial-agent task list are obsolete. They are not retained as pending tasks. Historical detail belongs in commits and `.plans/completed/`, not in the active implementation roadmap.
