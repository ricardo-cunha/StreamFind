# NTA BATCH PERSISTENCE BRIEF — make C++ NTA persistence match R's DuckDB Appender

Repo root: C:/Users/cunha/Documents/GitHub/streamfind (branch dev_refactoring). Windows; bash terminal; use C:/ paths for native tools. Read AGENTS.md first (no anonymous namespaces — use `streamfind::detail` or file-local `static`; don't touch core/vendor/). C++20.

## Problem (the bug the user identified)
The C++ NTA pipeline is extremely slow because feature/suspect/internal-standard persistence does **one string-built `execute_sql("INSERT ... VALUES (...)")` per row** and runs after EVERY pipeline method. For thousands of features across 18 files × ~10 pipeline steps this is tens of thousands of individual DuckDB round-trips — the ~3h runtime. The R package instead uses a **DuckDB Appender** (`duckdb_appender_create` / `duckdb_appender_begin_row` / `duckdb_append_*` / `duckdb_appender_end_row`), a true batched columnar insert that is orders of magnitude faster.

AUTHORITATIVE R REFERENCE (do not modify): `bindings/r/src/core/nta/nta.cpp` lines ~15-90 define `APPENDER_GUARD`, `appender_error_message`, `check_append_state`, `append_optional_varchar`, and `insert_features_table(duckdb_connection con, const api::NTA_FEATURES_TABLE &features)` — the exact Appender pattern to reproduce, and the `insert_features_table` body shows the precise column-bind order for the NTA_FEATURES table. There are analogous `insert_suspects_table` / `insert_internal_standards_table` in the same file — find and mirror them.

## What to do

### 1. Add a batch Appender capability to the core `Project` API
The core is at `core/` (ninja build, MSVC via vcvarsall; the existing extension subagent build scripts `msbuild_env.sh`/`_vs_build.bat` set up the env — read them). The core `Project` currently exposes only `execute_sql(sql)` and `query_json(sql)` which do one query per call. The mass-spec domain (which links `streamfind::core`) needs a batched insert method.

Design (reuse the existing core Connection/prepared infrastructure in `core/src/project.cpp`):
- Add a method on `streamfind::Project` (declare in `core/include/streamfind/project.hpp`, implement in `core/src/project.cpp`) such as:
  `void batch_insert_flexible(const std::string &table_name, const std::vector<std::string> &column_names, const std::vector<std::vector<std::optional<std::string>>> &rows);`
  — but a cleaner, more faithful approach is a generic `void append_rows(...)` that:
    1. takes the table name, an ordered list of column names, and rows where each cell is `std::optional<std::string>` (null = SQL NULL, else already-stringified scalar/varchar);
    2. acquires the connection under the same mutex/ensure_active discipline as `execute_sql`;
    3. creates a `duckdb_appender` for the table schema and appends all rows in one flush (`duckdb_appender_create` -> for each row `begin_row` + typed appends + `end_row`, then `duckdb_appender_flush`/destroy), with proper error handling and RAII guard mirroring R's `APPENDER_GUARD`.
  - Because the core table is `MASS_SPEC_NTA_FEATURES` in the mass_spec domain (sourced from `semantic/.../tables.ttl`), and the domain already has `row_sql` string helpers, keep this generic at the core level: it takes a table name + rows of optional strings. Type fidelity: have the caller pass only the columns that exist; the appender binds by the DuckDB column types using the DuckDB C API's typed `duckdb_append_varchar/double/int64/bool` as appropriate — OR simpler and still correct: pre-create/ensure the exact schema and bind each cell as varchar where the schema column is VARCHAR and as double/int for numeric (read the column types reflectively via `duckdb_duckdb_types`/`duckdb_column_type` from the appender's result, or bind via the known schema). Pick the robust approach: fetch column types from the opened appender and dispatch `duckdb_append_varchar`, `duckdb_append_double`, `duckdb_append_int64`, `duckdb_append_bool`, or `duckdb_append_null` per cell. This preserves numeric values as numbers (not text) so downstream `query_json`/filters behave identically to R.
- Follow the existing core error style (`streamfind::Error(ErrorCode::DatabaseError, msg)`), `idx_t`/`duckdb_` API, and the `impl_->mutex`/`ensure_active`/`Connection` pattern already used in project.cpp.

### 2. Route all NTA persistence through the batch appender
In `core/domains/mass_spec/src/processing_methods_nta.cpp`:
- Replace `detail::persist_features` (currently DELETE + per-row `execute_sql INSERT`) with: DELETE once, then build the full row set for all buffers as optional-string cells and call the new core batch insert in ONE call (with a flushes/batches of e.g. 1000 rows if the appender API prefers, but one appender session).
- Same for `detail::persist_suspects` and `detail::persist_internal_standards` (they currently do per-row INSERT into MASS_SPEC_NTA_SUSPECTS / MASS_SPEC_NTA_INTERNAL_STANDARDS).
- Ensure the SQL type mapping matches: the row_sql helpers already encode NULL for non-finite doubles and string-quote varchar; adapt them into the new optional-string cell representation (NULL stays null; finite doubles -> stringified; bools -> "true"/"false" or a typed marker). Bind by the reflected column type so numbers stay numeric.
- Keep the existing behaviour and the exact persisted values identical to now (just faster). Existing `load_features_test`, `nta_processing_test`, and the wastewater conformance test must still pass — the quantized conformance in particular must now finish in seconds-to-a-couple-of-minutes instead of being killed at multi-minute timeouts.

### 3. Verify performance explicitly
- Build (vcvarsall x64 + Ninja, `cmake -G Ninja -DSTREAMFIND_BUILD_TESTS=ON -B build/cmake/default -S core` then `cmake --build ... --target streamfind_mass_spec_nta_wastewater_conformance streamfind_mass_spec_nta_processing_tests streamfind_mass_spec_load_features_tests`).
- Run `streamfind_mass_spec_nta_wastewater_conformance.exe --quantized` and TIME it (it processes 3 positive-only wastewater files over a narrow RT window — it should now complete in well under a few minutes, ideally ~seconds after find_features is batched). Record the wall time before/after if possible.
- Run the two existing fast tests (load_features, nta_processing) to confirm no regression.
- Report the actual quantized wall-clock time as evidence the batch fix worked.

## Constraints
- Faithful to R's Appender approach; do not change algorithm logic or persisted semantics.
- No anonymous namespaces; don't touch core/vendor/; keep `find_features` itself (the CPU algorithm) unchanged — the fix is the DB persistence path.
- Reuse the repo-local `.venv` for any python; the C++ build uses the existing configured build dir.

## Report
List files changed; describe the new Project batch-insert method and how it binds types; describe the routing change in persist_features/persist_suspects/persist_internal_standards; paste the build output (exit 0) and the QUANTIZED wall-clock time + the pass/fail of the three tests. Report any remaining slowness and where it comes from if the time is still high.
