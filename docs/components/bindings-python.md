# Python binding (future)

`bindings/python` is reserved for the future public Python package. It is not
available as an installable public package yet.

!!! warning "Not available yet"
    Do not use this directory as an installation or runtime entry point. The
    public Python boundary starts after the semantic, registry, and MCP
    contracts have stabilised.

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
