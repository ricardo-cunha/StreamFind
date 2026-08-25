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

The implementation now has three permanent ownership boundaries:

- `semantic/` owns the backend-neutral public contract;
- `core/` owns the independent C++ implementation;
- `rust/` owns the independent Rust implementation.

`bindings/r/src/` is the functional former implementation and migration reference. It is not a future implementation location and must not receive new domain work during this migration. The centre of the architecture is the **streamfind semantic catalogue**, not either backend and not MCP. The catalogue documents the externally visible concepts and capabilities that define streamfind interoperability.

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
│   ├── tables.ttl
│   ├── fields.ttl
│   └── columns.ttl
└── domains/
    ├── mass_spec/
    │   ├── domain.ttl
    │   ├── operations.ttl
    │   ├── results.ttl
    │   ├── tables.ttl
    │   ├── fields.ttl
    │   ├── columns.ttl
    │   ├── methods.ttl
    │   └── parameters.ttl
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

For MCP, the semantic catalogue is the authoritative source for tool-facing labels, descriptions, parameter metadata, result semantics, shared errors, and examples. MCP code owns protocol handling, session state for Methods, stateless project selection for Operations, registry lookup, execution, cancellation/progress, and backend-specific diagnostics only.

## Current implementation status

| Area | Status | Evidence in this branch | Roadmap implication |
| --- | --- | --- | --- |
| C++ backend | **Complete foundation / active implementation** | Standalone C++20 `core/` has Project/JSON APIs, DuckDB persistence (incl. batched Appender writes), workflow, cache, audit, cancellation, progress, generic MCP, MassSpec reader, and a full registered NTA method suite. | Put all new C++ operations and processing methods in `core/`; extend domain modules rather than the generic project kernel. |
| Rust backend | **Complete foundation / full NTA parity** | `rust/` is an independent Cargo workspace with core, CLI, external, MCP, MassSpec, Raman, and sensors crates. MassSpec registers the **full NTA method suite** (all 19 `sf:Method`s incl. MetFrag + transformation products) plus all 23 operations (incl. the NTA table queries), matching the C++ registry ID-for-ID. | Preserve independence from C++; extend `rust/` when adding future methods. |
| Semantic catalogue | **Active implementation** | `semantic/` contains Turtle ontology sources, SHACL validation, deterministic projection generation, and generated metadata embedded by both MCP implementations. Declares all 19 NTA methods + 23 operations (66 catalogue entries). | Add or revise a semantic declaration, result/error contract, and fixture before registering each migrated capability. |
| C++/Rust MCP | **Complete generic foundation / lifecycle split** | Both stdio servers consume generated semantic metadata and registry entries. Direct Operations are stateless; workflow Methods are connected-session capabilities. | Preserve the split; add progress/cancellation handling before exposing long-running NTA Methods via MCP. |
| Domain composition | **Active** | C++ and Rust compose MassSpec, Raman, and sensors registration points; MassSpec registers the full NTA method suite on both. | Continue with real MassSpec/NTA capabilities; no placeholder production tools. |
| R binding | **Complete relocation / deferred alignment** | Complete R package under `bindings/r/`. | Keep functional as-is until new backends/domain paths are mature. |
| Cogniflow integration | **Complete relocation / deferred alignment** | Integration boundary under `integrations/cf-streamfind/`. | Align only after the public Python path is stable. |
| Frontend | **Future** | No frontend in the active implementation path. | Start only after migrated operations/methods are available through MCP. |
| NTA domain capabilities (C++) | **Complete (all 16 R method families)** | C++ core builds a columnar NTA model and registers all NTA `sf:Method`s: detection/loading (`find_features`, `load_features_ms1/2`), processing (`create_components`, `group_features`, `fill_features`, `subtract_blank`, `filter_features` full ~30-param surface, `filter_features_ms2`), annotation (`annotate_components`, `suspect_screening`, `find_internal_standards`, `filter_suspects`, `filter_internal_standards`), correction (`correct_matrix_suppression`), plus `assign_transformation_products` and `metfrag_screening` (MetFragCL via the `~/.streamfind` Java+jar layout, graceful tool-missing error). Parameter defaults + semantics align to the R package. | Reproduce R behaviour with meaningful fixtures; keep R functional as-is. |
| NTA domain capabilities (Rust) | **Complete (all 16 R method families)** | Rust registers the identical 19 `sf:Method`s + 23 operations as C++ (ID-for-ID parity), incl. the NTA table query Operations (`get_suspects`, `get_internal_standards`, `get_transformation_products`). Each algorithm lives in its own `nta_*.rs` file, fed from `processing_methods_nta.rs` executors on the columnar `NTA_FEATURES` model; suspects/IS/TP persisted; `streamfind_external::tools` resolves Open Babel (`obabel`/`obprop`) and MetFrag CL. A quantized wastewater conformance test (`rust/crates/mass-spec/tests/nta_conformance.rs`) runs the full pipeline; detection parity with C++ verified feature-by-feature. | NTA capability surface is complete; remaining work is CI, MCP progress/cancellation, reader hardening, and distribution. |
| Semantic NTA contract + validation | **Implemented** | Ontology now declares the complete suspect-target schema (id/name/mass/mz/rt/formula/SMILES/InChI/InChIKey/xLogP/score/database_id + pos/neg fragment pairs), `sf:requiredMethods` chains for all NTA methods, and the persisted suspects/internal-standards tables (66 columns). `find_features` RT windows are optional (R full-range semantics). SHACL hardened (column-name pattern for `SMILES`-style columns; required-method references must resolve; object parameters need property schemas). Generator fixed to emit method IDs (not IRIs) in `required_methods`. Backends enforce ordering at workflow-set time and run per-method value validators (in-range checks + target structure) via `Method` validator hooks (C++ `register.cpp` `detail::nta_validator`; Rust `Method::with_validator` + `nta_validator` in `lib.rs`), with negative tests on both sides. Raw-data operations (`getRawSpectra*`, `getFeatures`) accept chemical `targets` (SMILES/InChI → exact mass via Open Babel, polarity-aware adduct windows). External tools provisioned through the `~/.streamfind` layout (R-compatible: Temurin JDK 21 + MetFragCL 2.6.11) with Rust `external::tools` + CLI `streamfind tools status|install*` and the C++ `tools_resolver` mirror. Ontology now at 66 entries incl. `assign_transformation_products`, `metfrag_screening`, and the three NTA table query Operations. | Keep the validators' numeric domains in sync with the executors when methods evolve. |

### Current migration boundary

`bindings/r/src/core/mass_spec/` and `bindings/r/src/core/nta/` are the source
inventory for remaining MassSpec and NTA behaviour. The Rcpp export files
define the public operation inventory to assess; helper functions alone are
not migration units. For every accepted capability, implement the target
architecture directly in `semantic/`, `core/`, and `rust/`. Do not wrap, call,
or redirect to the former R implementation.

### Remaining public capability inventory

The current inventory classifies exported capabilities by their target boundary.
Constructors and pointer lifecycle helpers are binding mechanics, not migration
units.

| Capability group | Target kind | Migration order |
| --- | --- | --- |
| `rcpp_decode_string` (Sciex), `rcpp_lcd_list_streams`, `rcpp_lcd_inspect_stream` | `sf:Operation` | MassSpec reader hardening (active worktree `mass_spec_reader_extension`) |
| NTA feature detection: `find_features` | `sf:Method` | **Migrated: `mass_spec.find_features` (C++ + Rust)** |
| NTA feature loading MS1/MS2 | `sf:Method` | **Migrated: `mass_spec.load_features_ms1/2` (C++, Rust)** |
| NTA feature processing: components, grouping, filling, blank subtraction, filtering | `sf:Method` | **Migrated in C++ and Rust** (`create_components`, `group_features`, `fill_features`, `subtract_blank`, `filter_features`, `filter_features_ms2`) |
| NTA annotation: isotopes/adducts/losses, suspects, internal standards | `sf:Method` | **Migrated in C++ and Rust** (`annotate_components`, `suspect_screening`, `find_internal_standards`, `filter_suspects`, `filter_internal_standards`) |
| NTA matrix-suppression correction | `sf:Method` | **Migrated in C++ and Rust** (`correct_matrix_suppression`) |
| NTA MetFrag screening | `sf:Method` | **Migrated in C++ and Rust** (`metfrag_screening`; external Java tool via `~/.streamfind`, graceful tool-missing error) |
| NTA transformation-product assignment | `sf:Method` | **Migrated in C++ and Rust** (`assign_transformation_products`) |
| NTA table queries (features/suspects/IS/TP) | `sf:Operation` | **Migrated in C++ and Rust**: `get_features`, `get_suspects`, `get_internal_standards`, `get_transformation_products` (all with `get_features`-style target filtering; default returns the whole table) |
| Pure transformation-product assignment over supplied records | `sf:Operation` | After the shared record contract is defined |

The NTA feature-detection baseline is `mass_spec.find_features`: MS1 centroid
grouping within supplied RT windows, ppm tolerance, noise/SNR threshold, and
minimum trace count. Representative fixtures: the three files under
`tests/data/mass_spec/basic_tof/` ending in `00_tof_s_is_pos_cent-r00[123].mzML`,
and the wastewater suite under `tests/data/mass_spec/wastewater/`.

### Completed workflow and NTA foundation

The current branch now includes the following completed work:

- NTA model is **columnar (SoA)** in core and Rust: `MASS_SPEC_NTA_FEATURES`
  columns match the persisted DuckDB table and the columnar semantic results;
  existing methods (`find_features`, `load_features_ms1/2`) were migrated onto it.
- Full C++ **and Rust** NTA method suites (all 16 R method families, 19 `sf:Method`s
  + 23 operations incl. the table queries), each registered generically through
  the semantic catalogue; Rust and C++ registries are ID-for-ID identical.
- Parameters and default values reproduce the R package
  (`bindings/r/R/class_MethodsNonTargetAnalysis.R`): e.g. `filter_features` exposes
  the full ~30-parameter surface; `find_features`/others use R defaults; empty RT
  windows = full range; `filtered` default true for suspect/IS steps.
- `Project::append_rows` batched DuckDB Appender persistence (mirrors
  `bindings/r/src/core/nta/nta.cpp`), replacing per-row `execute_sql` inserts for
  the NTA result tables. This cut the wastewater run from ~3 h to under a minute.
- **Analysis-container harmonization**: `add_analyses` enumerates container
  catalogs (Sciex WIFF) into one row per logical analysis (`analysis_index` /
  `source_analysis_number` / `analysis_count`); every operation and NTA method
  selects the logical analysis internally by unique name (never a user argument);
  fixed `query_json` stringification handling for integer columns.
- **Chromatogram R-scheme harmonization**: `MASS_SPEC_CHROMATOGRAMS` carries the
  reader-derived per-point columns (`index`, `polarity`, `precursor_mz`,
  `activation_ce`, `product_mz`); `get_chromatograms` / `get_raw_chromatograms`
  return the R-interface scheme (`replicate` joined from `MASS_SPEC_ANALYSES`,
  not stored); `load_chromatograms` uses the batched Appender.
- OpenBabel C-API + `sf::obabel` adapter ported into core, made robust
  (`openbabel_available()` returns false rather than crashing when the DLL is absent);
  Rust resolves `obabel`/`obprop` via `streamfind_external::tools`.
- MetFrag CL + transformation-product assignment implemented in both backends,
  provisioned through the `~/.streamfind` layout (R-compatible Temurin JDK + jar),
  with graceful tool-missing errors.
- No anonymous namespaces anywhere in project C++ (converted to named
  `streamfind::*_detail` namespaces or file-local `static`).
- Semantic NTA contract + validation: witness/suspect target schemas,
  `sf:requiredMethods` chains, persisted suspects/IS tables, both backends enforce
  ordering + value validators with negative tests.
- **NTA table query Operations**: `get_suspects`, `get_internal_standards`,
  `get_transformation_products` implemented and registered in C++ and Rust via a
  shared `get_features`-style filter engine (analysis, polarity, mass/mz ±ppm
  incl. SMILES/InChI exact-mass, rt ±tolerance; default = whole table).
  Transformation products now persist to a dedicated
  `MASS_SPEC_NTA_TRANSFORMATION_PRODUCTS` table (semantic `tp*` columns), read
  by `get_transformation_products`.
- Workflow execution is ordered and tracked per project, revision, and step index;
  cache keys chain method identity/version/params/previous-step; cacheable outputs
  snapshot declared `sf:writes` tables.
- Tests: basic_tof feature detection + Metoprolol-D7 retrieval, load_features,
  full NTA processing pipeline, a **wastewater conformance** test with a fast
  `--quantized` CI variant (C++ and Rust), plus Rust's full crate suite
  (reader incl. multi-experiment Sciex WIFF, NTA, project, tools).

### Next work

With all 16 R NTA method families complete, parity achieved between the C++ and
Rust backends, and the NTA table query Operations migrated, the remaining units
are:

1. **CI adoption** — wire the quantized conformance targets + the existing fast
   tests into the repo's CI workflow; decide whether the full 18-file wastewater
   run is a nightly optional gate.
2. **MCP progress/cancellation boundary** before exposing long-running NTA
   Methods through MCP (shared execution context in core, Rust core, and both
   MCP adapters).
3. **MassSpec reader hardening** — finish the Sciex reader extension
   (`mass_spec_reader_extension` worktree; multi-analysis WIFF, LCD), then migrate
   the LCT/LCD reader operations.
4. **Pure transformation-product assignment over supplied records** — after the
   shared record contract is defined.
5. **Python distribution + frontend** — build the C++-backed Python binding, then
   the frontend; align Cogniflow only after the public Python path is stable.
6. **Distribution/CI/docs hardening** — packaging, wheel/install-test, semantic
   catalogue versioning, and (semi-)generated documentation.

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

Both MCP implementations follow the same generic algorithm, with separate lifecycle
rules for direct Operations and workflow Methods:

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
tools/list
   │
   ├── generic operations
   ├── stateless domain Operations with database/project context parameters
   └── connected-session Methods after `connect(project)`
       │
       └── read immutable project domain
   │
   ▼
intersection of:
     semantic capabilities
     AND registered executable IDs
   │
   ▼
tools/call
   │
   ├── Operation: open the request's project, invoke, audit, close
   └── Method: resolve against the connected project session
       │
       ├── resolve advertised name to canonical ID
       ├── validate parameters using projected contract
       └── matching registry invokes the canonical ID
```

The **intersection rule** is important: a semantic declaration alone must not advertise an unavailable executable, and a registered executor without a semantic declaration must fail validation/build tests rather than become an undocumented tool.

The MCP servers must not contain per-domain or per-method `if`, `switch`, or match branches for normal method discovery/dispatch.

### Long-running processing Methods

Processing Methods may take minutes and must not require a second ad hoc job
system per domain. The first execution contract is:

- keep the MCP call open while the backend method runs;
- pass an MCP `progressToken` into the backend execution context;
- emit standard MCP progress notifications at meaningful stages;
- propagate cancellation to the existing core cancellation token;
- return one final result or structured error after completion;
- keep progress payloads backend-neutral: `{completed, total, message}`.

Do not add persistent background jobs, queues, or a database-backed job table yet.
Add that framework only when clients need calls to survive server disconnects or
methods must be scheduled across processes. Before the first long-running NTA
Method is exposed, add the shared execution-context/progress boundary in core,
Rust core, and both MCP adapters.

### Domain and method identity rules

- Generic operations retain canonical generic IDs.
- Domain methods always use `<domain>.<method>` internally and in workflows.
- The connected project has one immutable domain.
- Direct domain Operations receive `database_path` and `project_id` and do not require `connect`.
- Workflow Methods require a connected project session and must use that session's domain.
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

### 1. Migrate remaining former R capabilities — **Substantially complete**

The remaining public operations and processing methods represented by
`bindings/r/src/` are largely migrated into the target architecture.
The NTA dependency chain below is now complete in both backends
(feature detection/deconvolution, blank subtraction and corrections, feature
filtering, alignment and gap filling, componentization, annotation, suspect
screening, internal standards, MetFrag integration, transformation-product
assignment, and the NTA table query Operations). The inventory above records the
one remaining open work stream:

- the MassSpec reader hardening (Sciex/LCD) in the active
  `mass_spec_reader_extension` worktree.

Historical steps 1–7 below remain the executed procedure for each capability
(kept for reference, not as pending work).

1. Inventory the Rcpp-exported MassSpec and NTA public capabilities and map each to a canonical semantic ID, target type (`sf:Operation` or `sf:Method`), dependencies, input/output contract, and representative fixture.
2. Treat the existing MassSpec analysis, spectra, chromatogram, and three chromatogram/NTA workflow methods as migrated baseline; close behavioural and fixture gaps before using them as NTA dependencies.
3. Migrate the remaining MassSpec processing primitives required by NTA.
4. Migrate NTA in dependency order: feature detection/deconvolution, blank subtraction and corrections, feature filtering, alignment and gap filling, componentization, annotation, suspect screening, MetFrag integration, and transformation-product assignment.
5. For every capability, update `semantic/` first, implement it independently in `core/` and `rust/`, register it in the matching registry, and add backend and conformance tests.
6. Keep R functional and unchanged except for necessary build repairs. Do not create wrappers, fallbacks, or dual execution paths.
7. Before exposing a long-running NTA Method, implement the shared execution context, progress notification, and cancellation boundary in both backends and both MCP adapters.

**Exit condition:** every accepted former R public operation and processing method has one semantic contract and independently tested C++ and Rust implementations, or is explicitly retired by a separate decision.

### 2. Expose migrated capabilities through MCP — **Active, per capability**

MCP is the interface layer immediately after each capability is implemented,
not a separate reimplementation phase.

1. Regenerate the semantic projection after each ontology change.
2. Verify both MCP servers advertise only the intersection of semantic executable IDs and registered C++/Rust executors; Operations use request project context and Methods use the connected domain.
3. Add a shared MCP fixture and one C++ and Rust protocol test for each migrated capability or tightly coupled processing slice.
4. Verify parameter validation, result shape, errors, cancellation, and progress where applicable.
5. Do not add a method-specific tool definition, description, schema, or dispatch branch.
6. Test stateless Operations with multiple projects in one MCP process, and test connected-session Methods separately.
7. For long-running Methods, verify progress, cancellation, final result delivery, and structured failure without introducing persistent jobs prematurely.

**Exit condition:** all migrated capabilities are callable and documented through both MCP implementations using only the semantic projection and registry registrations.

Frontend development, packaging/release hardening, and R/Cogniflow alignment are
explicitly deferred until the remaining MassSpec/NTA capability boundary is
stable and the required long-running Method execution contract is covered.

### 3. Develop the frontend — **Future, after required MCP coverage**

1. Define the frontend's service boundary from the MCP-exposed contracts and generated semantic metadata; do not duplicate operation schemas or descriptions.
2. Build the minimal application/API host needed to create projects, manage analyses, run methods, show progress, and inspect results.
3. Implement the frontend against that public service boundary, never against DuckDB, C++, Rust internals, or `bindings/r`.
4. Add end-to-end coverage for the migrated workflows users can execute from the frontend.

**Exit condition:** users can perform the selected migrated workflows through the frontend using the same public contracts exposed through MCP.

### 4. Distribution, CI, and documentation hardening — **Future**

- C++: install/export packages, runtime dependencies, static/shared CI, clean-system tests.
- Python: cross-platform wheels, native-runtime repair/audit, package/frontend tests.
- Rust: workspace CI, crate versioning, external-tool diagnostics, server/apps release boundaries.
- Semantic: catalogue versioning, SHACL, fixture integrity, projection regeneration, documentation generation.
- MCP: common lifecycle/domain conformance and proof that tool catalogues remain semantic/registry driven.
- Documentation: generate or semi-generate method/domain/MCP references from the semantic catalogue rather than maintaining parallel hand-written inventories.

### 5. Align R and Cogniflow with the completed public path — **Future, final phase**

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
