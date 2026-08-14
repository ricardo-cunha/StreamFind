# Python binding (future)

`bindings/python` is reserved for the future public Python package. It is not
developed yet.

## Planned design

- Built on the C++ backend with pybind11; `streamfind._core` stays private
  and minimal.
- `streamfind.core` as the typed public Python API.
- `streamfind.cli` for generic project and workflow operations.
- `streamfind.server` with Pydantic schemas, a service layer, and
  project/workflow/job/result endpoints.
- A packaged React/TypeScript frontend under `bindings/python/frontend/`.

Work starts only after the semantic, registry, and MCP contracts are stable,
so the Python distribution can reuse the generated catalogue instead of
maintaining a second method catalogue.
