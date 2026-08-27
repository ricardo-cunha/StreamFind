# Plan: catalogue.duckdb — semantic knowledge base for MCP

Status: proposed
Owner: dev_refactoring (main worktree)

## Problem

The semantic projection is delivered to the C++ and Rust backends as **generated
string literals** embedded in headers/rs files:

- `core/include/streamfind/generated_metadata.hpp` — `tools[]` + `catalogue[]`
  raw literals (~511 KB total), parsed at startup by `mcp.cpp` and `register.cpp`
- `rust/crates/mcp/src/generated_metadata.rs` — `TOOLS` + `CATALOGUE`
- `rust/crates/mass-spec/src/generated_metadata.rs` — `CATALOGUE`

This design is unsustainable:

1. **MSVC `C2026`** — a single string literal is limited to ~16K chars; the
   catalogue is ~480 KB. The C++ core fails at compile time (mcp.cpp includes
   the header), and it will only get worse as Raman/sensors methods land.
2. The ontology is re-baked into binaries instead of being a queryable artifact.
3. Parameter `skos:definition`s are dropped from the projection (only name/type/
   required/schema/example/default/constraints survive), so MCP/frontend cannot
   describe parameters to users.
4. `database_path`/`project_id` are baked into every operation's parameters —
   session/project plumbing, not user-supplied tool arguments.
5. C++ and Rust re-parse large JSON blobs at every startup.

## Design

`semantic/generate_projection.py` gains a second output: **`semantic/generated/catalogue.duckdb`** —
a DuckDB database whose single table `catalogue_entries` holds one document per
method/operation. The MCP servers and registries query this database instead of
parsing embedded literals. The `.duckdb` file is a **required installation
artifact** shipped with the binaries.

`catalogue.json` remains as the SHACL-validation/fixture artifact (the
`operations.json` fixture and `validate_semantic.py` depend on it); it is the
genesis source for building the `.duckdb`. The embedded literals are deleted.

### `catalogue_entries` schema

```sql
CREATE TABLE catalogue_entries (
  canonical_id      VARCHAR PRIMARY KEY,   -- mass_spec.get_features | mass_spec.find_features
  kind              VARCHAR CHECK (kind IN ('operation','method')),
  domain            VARCHAR,               -- streamfind | mass_spec | raman | sensors
  label             VARCHAR,
  definition        VARCHAR,
  executable        BOOLEAN,               -- registered in C++ AND Rust
  exposed           BOOLEAN,               -- advertised via MCP (operations) / available-methods (methods)
  mcp_name          VARCHAR,               -- operations: tool name; methods: NULL (never a tool)
  input_schema      JSON,                  -- operations ONLY: {type:object, properties:(params only), required}
  parameters        JSON,                  -- ordered param docs incl. NEW description field
  result_schema     JSON,                  -- JSON-Schema table description
  reads_tables      JSON,                  -- DuckDB tables read (same in C++ and Rust)
  writes_tables     JSON,                  -- DuckDB tables written
  cacheable         BOOLEAN,               -- methods only
  single_occurrence BOOLEAN,               -- methods only
  mutates_project   BOOLEAN,               -- operations + methods
  required_methods  JSON                   -- methods only: ordered [canonical_id, ...]
);
CREATE INDEX catalogue_kind_domain ON catalogue_entries (kind, domain);
CREATE INDEX catalogue_executable ON catalogue_entries (executable);
```

### Operation vs method exposure (the contract rule)

- **Operations** (`kind='operation'`): appear in MCP `tools/list` as callable
  tools with `mcp_name` + `input_schema` built from **their own parameters
  including `database_path` + `project_id`** — an operation is an **independent,
  stateless call**: the caller supplies the database path + project id, and the
  backend opens the DuckDB file, runs the operation, and closes the connection.
  No session/injected context.
- **Methods** (`kind='method'`): **never tools**. `mcp_name`/`input_schema` are
  NULL. They are *referenced* (not called) by the workflow ops
  (`add_method`, `remove_method`, `set_workflow`, `run_workflow`, `run_method`,
  `validate_workflow`) and discoverable via `get_available_methods`.
  The workflow-assembly UX queries `parameters` + `required_methods` + `cacheable`
  to render the method form; the user supplies
  `{"method": "...", "parameters": {...}}`.

### Parameter descriptions

The generator must add `description` to each parameter document, sourced from the
Turtle `skos:definition` of the parameter. Every `inputSchema` property and every
method parameter doc then carries:
`{type, description, default, minimum, maximum (constraints), examples}`.

## Work items

### 1. Generator — `semantic/generate_projection.py`

1. Add `SKOS.definition` → `description` to each parameter value object
   (parameter docs: `parameters[*].description`).
2. Build `catalogue.duckdb` (python `duckdb` 1.5.5 is already in `.venv`):
   - `CREATE TABLE catalogue_entries (...)` per schema above.
   - Insert one row per entry: for operations populate `mcp_name` +
     `input_schema` (the full parameter list **including** `database_path` and
     `project_id` — operations are independent stateless calls that open/close
     the DuckDB file); for methods leave `mcp_name`/`input_schema` NULL and
     populate the method contract fields.
   - `--check` mode verifies a rebuild yields an identical file (deterministic
     order; or compare row count + a content hash).
3. Stop emitting the four generated literal files:
   - `core/include/streamfind/generated_metadata.hpp`
   - `rust/crates/mcp/src/generated_metadata.rs`
   - `rust/crates/mass-spec/src/generated_metadata.rs`
   Delete them from the repo (git rm). Keep `semantic/generated/catalogue.json`.
4. `--check` now also verifies `catalogue.duckdb` freshness.

### 2. C++ runtime — read the catalogue DB

1. New `core/src/catalogue.cpp` + `core/include/streamfind/catalogue.hpp`
   (`streamfind::catalogue` namespace):
   - `std::optional<Json> load(path_or_nullopt)` — open `catalogue.duckdb`
     read-only via the existing vendored duckdb C API; path resolution:
     `STREAMFIND_CATALOGUE` env → next-to-binary → install data dir.
     Returns parsed `Json` (list of entry documents) or nullopt on failure.
   - Query helpers: `tools_json()` (operations → MCP tools, params-only schema),
     `entries_json()` (all rows), `methods_json()` (for available-methods).
2. `core/src/mcp.cpp` — replace `Json::parse(generated::tools)` with
   `catalogue::tools_json()`; on catalog-miss, degrade to a minimal toolset +
   clear error (same graceful behaviour already used for tools).
3. `core/domains/mass_spec/src/register.cpp` + `core/domains/raman/src/register.cpp` —
   replace `Json::parse(generated::catalogue)` with `catalogue::entries_json()`.
4. Remove `#include "streamfind/generated_metadata.hpp"` from all three files.

### 3. Rust runtime — read the catalogue DB

1. `rust/crates/mcp`: replace `generated_metadata::TOOLS`/`CATALOGUE` with a
   `catalogue` module that opens `catalogue.duckdb` via the existing `duckdb`
   crate (read-only) and builds the same JSON. Path resolution mirrors C++
   (`STREAMFIND_CATALOGUE` env → next-to-binary → data dir).
2. `rust/crates/mass-spec/src/lib.rs` — replace
   `generated_metadata::CATALOGUE` with the same module.
3. Delete `mod generated_metadata;` + the rs files. Keep `cargo test` green.

### 4. Installation — `catalogue.duckdb` is a required file

C++ / CMake (`core/CMakeLists.txt`, next to the existing DuckDB runtime install):
```cmake
install(FILES "${STREAMFIND_SEMANTIC_DIR}/catalogue.duckdb" DESTINATION share/streamfind)
# plus: a cmake-configured path constant (compile-time default data dir) so the
# runtime lookup resolves the installed location when env is unset
```
Rust: install the file via the crate's packaging (or the same `share/streamfind`
directory consumed by the C++ side — single shared location) and resolve it in
the same order (env → binary-relative → installed data dir).

Minimum requirement spelled out in docs: an installation is complete only when
`catalogue.duckdb` is present alongside the runtime; the MCP server refuses to
start with a clear error if it cannot locate it after the search chain.

### 5. Runtime search-chain helper (shared behaviour, both backends)

1. `STREAMFIND_CATALOGUE` env var (explicit override)
2. `catalogue.duckdb` next to the executable
3. `share/streamfind/catalogue.duckdb` relative to the install prefix
   (CMake `STREAMFIND_SEMANTIC_DIR`; Rust reads the same path convention)

### 6. Projection semantics cleanup (fold into the generator work)

- Operations keep `database_path`/`project_id` as leading required parameters
  (independent stateless calls: open the DuckDB file, run, close — matching the
  current `mcp.cpp` flow). No session/injected context is introduced.
- Method entries: `mcp_name`/`input_schema` absent/NULL.
- `description` on every parameter (from Turtle `skos:definition`).

## Removal list (git rm)

- `core/include/streamfind/generated_metadata.hpp`
- `rust/crates/mcp/src/generated_metadata.rs`
- `rust/crates/mass-spec/src/generated_metadata.rs`
- any `#include`/`mod`/`generated_metadata::` references in
  `mcp.cpp`, `register.cpp` (mass_spec, raman), `rust/crates/mcp/src/lib.rs`,
  `rust/crates/mass-spec/src/lib.rs`

## Validation

- `semantic/validate_semantic.py` — unchanged, still reads `catalogue.json`; must pass.
- `semantic/generate_projection.py --check` — now also checks `catalogue.duckdb`.
- C++: build via vcvarsall x64 + Ninja (`-DSTREAMFIND_BUILD_TESTS=ON`);
  run fast mass-spec tests; run `streamfind_mcp.exe` and exercise
  `tools/list` + one operation + one `run_workflow` (method path) in a session —
  confirm methods are NOT in tools/list and add_method/run_workflow still work.
- Rust: `cargo test -p streamfind-rust-mass-spec`; MCP crate tests.
- Both: confirm no `C2026` at any ontology size; confirm `catalogue.duckdb`
  missing → graceful refusal with clear message.

## Decisions (resolved)

- **Commit `semantic/generated/catalogue.duckdb` alongside `catalogue.json`**
  (simple `--check` determinism; no build-time derivation). The `.json` stays
  for SHACL validation + fixtures; the `.duckdb` is the runtime knowledge base.
- **Operations keep `database_path`/`project_id` as tool arguments** — an
  operation is an independent, stateless call to the DuckDB file (open, run,
  close). No session-injected context in this change.

## Rollout

Do this in `dev_refactoring` directly (it is the integration line; the reader
worktree is unaffected). Land as one commit:

`feat(semantic): serve MCP from catalogue.duckdb — remove embedded generated literals`