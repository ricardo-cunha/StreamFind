# streamfind Semantic Catalogue

This directory is the backend-neutral contract for shared streamfind
operations, workflow methods, domains, parameters, results, errors, fixtures,
and interface mappings.

Phase 1 starts with declarations and fixtures only. Runtime code belongs in
`core/` or `rust/`; do not add backend classes or business logic here.

Validation uses the repository-local `.venv` with `rdflib` and `pyshacl`:

```powershell
& .\semantic\validate.ps1
```

Regenerate the semantic projection and embedded MCP metadata after changing
`streamfind.trig`:

```powershell
& .\.venv\Scripts\python.exe .\semantic\generate_projection.py
```

The canonical generated projection is `semantic/generated/catalogue.json`.
The generated C++ and Rust source embeds its MCP subset. Built libraries do
not read `semantic/` at runtime.

Initial work:

- Define the vocabulary in `vocabulary.ttl`.
- Declare shared operations and methods in `streamfind.trig`.
- Declare domain identities and later methods in `domains/*.trig`.
- Enforce mandatory SKOS labels and definitions with the basic shapes in
  `shapes.trig`.
- Keep shared JSON fixtures under `fixtures/` and reference existing fixtures
  before moving them.
