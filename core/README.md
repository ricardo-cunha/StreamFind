# streamfind-core

Standalone C++20 core for project persistence and generic workflow execution.
The core does not depend on R, Python, FastAPI, or React.

## Build And Test

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

- `get_*`: read project state, metadata, workflow, cache, audit, identity, or
  database path.
- `set_*`: mutate metadata, workflow, or cache entries.
- `run_*`: execute one method or the persisted workflow.
- `delete_*`: remove project-owned cache data.

Canonical `Project` methods:

```text
get_metadata() / set_metadata(Json)
get_database_path()
get_project_id()
get_domain()
validate()
get_workflow() / set_workflow(Workflow)
copy(ProjectOptions)
list_tables()
get_cache() / get_cache_size() / get_cache_entry(hash)
set_cache(name, description, hash, Json)
delete_cache()
get_audit_trail()
run_method(method_id, parameters)
run_workflow()
close()
```

`Project` is move-only and owns its native DuckDB state. `close()` marks the
handle closed; later operations fail. Destruction closes the handle as well.
Project domains are assigned in `ProjectOptions` during creation and cannot be
changed afterward. Opening a project does not modify its domain.

## JSON API

`streamfind::api::run()` exposes the same operations through
`streamfind::api::ProjectCommand`. Requests select a project with:

```json
{"database_path":"project.duckdb","project_id":"demo"}
```

Canonical commands are:

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

`set_metadata`, `set_workflow`, `run_method`, `run_workflow`, `delete_cache`,
and `copy` require a writable project. `get_*`, `describe`, and validation
commands are read-only.

## Execution Contracts

Workflow execution returns `ExecutionResult`:

```json
{"results": [], "cancelled": false}
```

Long-running callers may provide a `CancellationToken` and `ProgressCallback`.
Cancellation is cooperative. Progress events contain `operation`, `completed`,
and `total`.

Errors use the stable `ErrorCode` enum, including invalid arguments, missing or
existing projects, schema/database failures, workflow validation, method
execution, closed projects, and cancellation.

## Persistence Contract

The C++ core uses the shared `PROJECT`, `CACHE`, and `AUDIT_TRAIL` DuckDB tables.
Workflow, metadata, cache, audit, and result JSON are backend-neutral and are
tested against the Rust implementation in `core/tests/fixtures`.
