# Architecture

The centre of the architecture is the **streamfind semantic catalogue**, not
either backend and not MCP. The catalogue documents the externally visible
concepts and capabilities that define streamfind interoperability.

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
          ┌─────────────┴─────────────┐
          ▼                           ▼
 streamfind-core C++           streamfind Rust
 independent backend           independent backend
          │                           │
   MethodRegistry / OperationRegistry
          │                           │
          └────────────┬──────────────┘
                       ▼
              generic MCP adapters
           catalogue + registry join
```

## Generic project operations vs. domain capabilities

The ontology distinguishes two kinds of public capability:

- **`sf:Operation`** — direct project/domain capability, called through
  `run_operation`, exposed as an MCP tool, never a workflow step. Examples:
  `create`, `get_metadata`, `mass_spec.get_analyses_info`.
- **`sf:Method`** — workflow-executable capability owned by one domain, the
  only unit allowed in a `WorkflowStep`. Examples:
  `mass_spec.find_features`, `mass_spec.load_chromatograms`, and
  `mass_spec.filter_chromatograms_retention_time`.

Every public capability has one canonical semantic identifier. Transports and
language interfaces map to it; they do not create another domain contract.

## Backend independence

C++ and Rust implement the same project backend against the same DuckDB schema
(`PROJECT`, `CACHE`, `AUDIT_TRAIL` tables) and JSON contract. Shared behaviour
is established by semantic declarations and conformance fixtures in
`tests/`, not by a shared native implementation.

## Registry-driven MCP

Both MCP servers follow the same generic algorithm:

1. `initialize` — handshake.
2. Load the embedded semantic projection and compose the method/operation
   registries for the application.
3. `tools/list` — advertises generic capabilities before a project is
   connected. After `connect(project)`, it also advertises the intersection of
   the connected domain's capabilities and registered executables.
4. `tools/call` — resolves the tool name to a canonical ID, validates
   parameters against the projection, and invokes the matching registry.

Direct domain **Operations** are stateless: their request includes
`database_path` and `project_id`, and the server opens and closes the project
within that request. Workflow **Methods** are session-bound: call
`connect(project)` first, invoke Methods using the connected context, and call
`close` when the session ends.

The **intersection rule** is important: a semantic declaration alone must not
advertise an unavailable executable, and a registered executor without a
semantic declaration fails validation rather than becoming an undocumented
tool. Neither MCP server contains per-domain or per-method dispatch branches
for normal discovery.

## Design consequences

- **Add a method to an existing domain:** one semantic declaration + one
  registry registration per backend. No MCP edits.
- **Add a domain:** one semantic domain file + one backend domain module + one
  composition entry per application.
- **Change documentation:** edit the semantic catalogue once; both backends
  follow after regeneration.
