# Semantic catalogue

`semantic/` is the backend-neutral contract for StreamFind operations, workflow
Methods, domains, parameters, results, errors, fixtures, and MCP interface
metadata. Runtime code belongs in `core/` or `rust/`; the catalogue is
declarative and contains no executable analytical logic.

## Current projection

The current catalogue projection contains 70 entries:

- 49 callable Operations, exposed through the native MCP servers;
- 21 workflow Methods, returned by `get_available_methods`;
- 23 mass-spectrometry Operations;
- 19 mass-spectrometry workflow Methods.

The same generated catalogue drives both C++ and Rust tool names, descriptions,
JSON input schemas, annotations, result metadata, and agent-facing guidance.

## Source layout

```text
semantic/
├── ontology/
│   ├── vocabulary.ttl          # StreamFind vocabulary
│   ├── shapes.ttl              # SHACL completeness constraints
│   ├── core/                   # generic operations, parameters, results, errors
│   └── domains/
│       ├── mass_spec/
│       ├── raman/
│       └── sensors/
├── generated/
│   ├── catalogue.json          # generated JSON projection
│   └── catalogue.duckdb        # generated runtime projection
└── README.md
```

Turtle (`.ttl`) is the authoritative authoring format, using SKOS concepts and
SHACL consistency checks. The generated files are projections and must not be
hand-edited.

## Runtime use

The C++ and Rust MCP servers load the generated DuckDB catalogue at runtime.
The native release packages include the required catalogue files under
`share/streamfind/`; an MCP executable without its catalogue is incomplete.
The server can also use an explicit `STREAMFIND_CATALOGUE` path for development
or deployment overrides.

## Interface metadata

The ontology describes more than names and short labels. Operation and Method
entries may include:

- invocation model (`stateless` or `workflow`);
- whether a connected session is required;
- parameter types, defaults, constraints, examples, and nested object schemas;
- result fields, units, and nullability;
- agent-facing guidance and suggested next operations.

This lets human users and AI agents discover how to use the same operation
contract through either native backend.

## Development

Use the repository-local `.venv`:

```powershell
& .\.venv\Scripts\python.exe semantic\validate_semantic.py
& .\.venv\Scripts\python.exe semantic\generate_projection.py
& .\.venv\Scripts\python.exe semantic\generate_projection.py --check
```

## Adding a capability

1. Declare the `sf:Method` or `sf:Operation` with label, definition,
   interface metadata, parameters, results, and errors in the matching Turtle
   file.
2. Add backend-neutral fixtures under `tests/` where appropriate.
3. Register an executor under the same canonical qualified ID in each matching
   backend registry.
4. Regenerate and validate the projection.
5. Add C++ and Rust tests. MCP descriptions and schemas should come from the
   catalogue rather than duplicated dispatch code.

See the [architecture](../architecture.md) page and the
[living roadmap](https://github.com/odea-project/StreamFind/blob/master/.plans/streamfind_migration_plan.md)
for the implementation boundary.
