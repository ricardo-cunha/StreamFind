# Architecture

The centre of the architecture is the **streamfind semantic catalogue**, not
either backend and not MCP. The catalogue documents the externally visible
concepts and capabilities that define interoperability.

```text
              semantic/ontology/**/*.ttl
    concepts • domains • operations • methods • parameters
       results • errors • interface guidance • schemas
                        │
                validate with SHACL
                        │
                        ▼
         generated semantic projection
     deterministic JSON + DuckDB catalogue
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

## Operations and Methods

The ontology distinguishes two kinds of capability:

- **`sf:Operation`** — a callable project or domain operation exposed as an MCP
  tool. Direct domain Operations are stateless; examples include `create`,
  `describe`, and `mass_spec.get_analyses_info`.
- **`sf:Method`** — a workflow-executable capability owned by one domain. A
  Method is placed in a `WorkflowStep` and is discovered through
  `get_available_methods`; it is not advertised as an MCP tool.

Every public capability has one canonical semantic identifier. Transports and
language interfaces map to that identifier; they do not create another domain
contract.

## Backend independence

C++ and Rust implement the same project backend against the shared DuckDB
schema (`PROJECT`, `CACHE`, `AUDIT_TRAIL`, and domain tables) and JSON contract.
Shared behavior is established by semantic declarations, generated schemas, and
conformance fixtures, not by a shared native implementation.

## Catalogue-driven MCP

Both MCP servers follow the same generic algorithm:

1. `initialize` performs the MCP handshake and returns catalogue-derived,
   agent-facing interface instructions.
2. The server loads the generated catalogue and composes the backend's method
   and operation registries.
3. `tools/list` joins catalogue declarations with registered **Operations** and
   advertises the callable operations immediately, before any project is
   connected. The list contains no workflow Methods.
4. `tools/call` resolves a canonical operation or project command, validates its
   arguments at the backend boundary, and invokes the matching registry.
5. `get_available_methods` returns catalogue-enriched Method definitions,
   including their complete input schemas and workflow interface metadata.

Direct domain Operations require `database_path` and `project_id` on every
request. The server opens and closes the selected project for that request;
`connect` and `close` are not required for this stateless path.

Workflow Methods are session-bound. Call `connect` with an existing project,
then use `get_available_methods` to discover Methods and their schemas. Execute
them through `add_method`/`set_workflow`, `validate_workflow`, `run_method`, or
`run_workflow`, and call `close` when finished.

The important intersection rule still applies: a semantic declaration alone
must not advertise an unavailable executable, and a registered executor
without a semantic declaration must not become an undocumented capability.
Neither backend relies on per-method MCP dispatch code for normal discovery.

## Release packaging

The native Windows packages contain the backend runtime and the generated
catalogue required by MCP:

- the C++ CPack archive contains `bin/streamfind_mcp.exe`, native libraries,
  headers, and `share/streamfind/catalogue.duckdb`;
- the Rust archive contains `bin/streamfind-rust-cli.exe`,
  `bin/streamfind-rust-mcp.exe`, and the catalogue files under
  `share/streamfind/`.

See [Releases](releases.md) for download links, hashes, and package layout.

## Design consequences

- **Add an Operation or Method:** declare it in the semantic catalogue and add
  the corresponding backend registry entry. MCP descriptions and schemas are
  generated from the catalogue.
- **Add a domain:** add its semantic domain declarations, backend module, and
  composition entry.
- **Change interface guidance:** update the ontology, regenerate the projection,
  and verify both MCP servers against the shared catalogue.
