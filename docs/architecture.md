# How streamfind works

streamfind presents one public contract through several interfaces. The shared
semantic catalogue describes operations, workflow Methods, parameters, schemas,
results, and usage guidance. Native backends implement that contract, and MCP
adapters make it available to applications and AI agents.

```text
                 Shared semantic catalogue
       operations • methods • parameters • results
                         │
          ┌──────────────┴──────────────┐
          ▼                             ▼
       C++ backend                   Rust backend
          │                             │
          └──────────────┬──────────────┘
                         ▼
                   MCP over stdio
```

## Operations and workflow Methods

The public contract distinguishes two kinds of capability:

- **Operations** are callable project or domain actions. Domain Operations are
  stateless and include their project selection in every request.
- **Workflow Methods** are ordered processing steps. They are discovered with
  `get_available_methods` and executed in a connected project session.

Methods are not MCP tools. `tools/list` is the discovery endpoint for callable
Operations; `get_available_methods` is the discovery endpoint for workflow
Methods.

## Project usage model

A typical application or agent follows this sequence:

1. create or open a project;
2. inspect its identity, domain, metadata, and available analyses;
3. invoke stateless domain Operations for direct queries;
4. connect when a workflow is required;
5. discover Methods and their schemas;
6. validate and execute the workflow;
7. close the connected session.

The C++ and Rust MCP servers return the same operation names and catalogue-
derived schemas. Their implementations are independent and can be selected
according to the host application.

## Data and runtime assets

Native packages include the runtime data needed by the MCP servers, especially
the semantic catalogue under `share/streamfind/`. Keep the catalogue with the
server executable. Optional scientific tools remain separate user-installed
components.

See [Releases](releases.md) for package layouts and
[Availability](status.md) for compatibility scope.
