# C++ core

`core/` is the standalone C++20 backend (`streamfind-core`) for project
persistence and generic workflow execution. It does not depend on R, Python,
FastAPI, or React. Domain libraries depend on the generic core; the generic
core never depends on domains.

!!! note "Maturity"
    The C++ backend is an active developer-preview foundation, not yet a
    released compatibility-stable library. It is the native backend planned
    for the future public Python distribution.

## Build and test

```powershell
cmake --preset default
cmake --build --preset default --config Debug
ctest --test-dir build/cmake/default -C Debug --output-on-failure
```

## Project API

`streamfind::Project` owns one DuckDB-backed project selected by
`ProjectOptions`:

```cpp
streamfind::ProjectOptions options{
    "project.duckdb", "demo", std::nullopt, false, false, "mass_spec"
};
auto project = streamfind::Project::create(options);
```

Canonical methods use these prefixes:

- `get_*` — read project state, metadata, workflow, cache, audit, identity,
  or database path.
- `set_*` — mutate metadata, workflow, or cache entries.
- `run_*` — execute one method or the persisted workflow.
- `delete_*` — remove project-owned cache data.

`Project` is move-only and owns its native DuckDB state. `close()` marks the
handle closed; later operations fail. Domains are assigned at creation and
cannot be changed afterward.

## JSON API

`streamfind::api::run()` exposes the same operations through
`streamfind::api::ProjectCommand`. Requests select a project with:

```json
{"database_path": "project.duckdb", "project_id": "demo"}
```

Canonical commands:

```text
create, describe, validate
get_metadata, set_metadata
get_domain
get_workflow, set_workflow, validate_workflow, run_workflow
get_methods, run_method
copy
get_cache, get_cache_size, delete_cache
get_audit_trail
close
```

Mutating commands require a writable project; `get_*`, `describe`, and
validation commands are read-only.

## Execution and persistence contracts

Workflow execution returns an `ExecutionResult` envelope; long-running
callers may provide a `CancellationToken` and `ProgressCallback`. Errors use
the stable `ErrorCode` enum. The core uses the shared `PROJECT`, `CACHE`, and
`AUDIT_TRAIL` DuckDB tables and is tested against the Rust implementation
using the shared fixtures in `tests/data`.

See `core/README.md` for the full contracts.

The [development status](../status.md) lists the currently migrated domain
capabilities and the remaining migration boundary.
