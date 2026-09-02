# Python package

There is currently **no public Python package release** in StreamFind. The
`bindings/python` directory is a reserved boundary and is not an installation
or runtime entry point for the C++ or Rust releases.

!!! warning "Not released"
    Do not configure an MCP client or application to use `bindings/python`.
    Use the [C++ release](../releases.md) or [Rust release](../releases.md)
    and their native MCP servers instead.

The current native packages provide CLI/MCP access directly. A future Python
binding may be designed around the shared semantic catalogue, but no Python API
or compatibility promise should be inferred from this directory today.
