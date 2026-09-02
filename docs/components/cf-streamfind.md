# Cogniflow integration

`integrations/cf-streamfind` is a separate Cogniflow adapter boundary. It is not
part of the current C++ or Rust native release packages and is not a supported
replacement for either MCP server.

!!! note "Not part of the current release path"
    Do not use this integration as the installation or runtime entry point for
    the native backends. Use the versioned packages on the [Releases](../releases.md)
    page for C++ and Rust MCP usage.

The integration remains separately scoped while the native C++/Rust contracts,
semantic catalogue, and public language boundaries evolve. Its presence in the
repository does not imply that a public Python package or a Cogniflow runtime
based on the new backend path is available.
