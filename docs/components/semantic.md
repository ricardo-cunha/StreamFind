# Semantic catalogue

`semantic/` is the backend-neutral contract for shared streamfind operations,
workflow methods, domains, parameters, results, errors, fixtures, and
interface mappings. Runtime code belongs in `core/` or `rust/`; the catalogue
is declarative and contains no executable analytical logic.

## Source layout

```text
semantic/
├── ontology/
│   ├── vocabulary.ttl          # streamfind vocabulary
│   ├── shapes.ttl              # SHACL completeness constraints
│   ├── core/                   # generic operations, parameters, results, errors, tables
│   └── domains/
│       ├── mass_spec/
│       ├── raman/
│       └── sensors/
├── generated/
│   └── catalogue.json          # generated projection; never hand-edited
└── README.md
```

Turtle (`.ttl`) is the authoritative authoring format, using SKOS for
concepts and SHACL for consistency checks.

## Generated projection

One repository tool compiles the Turtle catalogue into
`semantic/generated/catalogue.json`, the deterministic projection consumed by
the C++ and Rust backends and their MCP servers. Built libraries embed this
projection; they do not parse RDF at runtime.

## Development

Uses the repository-local `.venv` with `rdflib` and `pyshacl`:

```powershell
& .\semantic\validate.ps1
```

Regenerate the projection after changing `semantic/ontology/`:

```powershell
& .\.venv\Scripts\python.exe .\semantic\generate_projection.py
```

## Adding a capability

1. Declare the `sf:Method` or `sf:Operation` with label, definition,
   parameters, results, and errors in the matching domain Turtle.
2. Add backend-neutral fixtures under `tests/`.
3. Register an executor under the same canonical qualified ID in the matching
   backend registry.
4. Add backend tests. No MCP description or dispatch code is edited.

See the
[living roadmap](https://github.com/odea-project/StreamFind/blob/master/.plans/streamfind_migration_plan.md)
for the full rules and the definition of done.
