# Releases

The repository currently publishes versioned **development releases** for the
native C++ and Rust backends. These archives are self-contained runtime
packages for Windows x64; they are not yet compatibility-stable SDK releases.

The release assets are managed by GitHub Releases rather than committed into
the source tree. The repository keeps the release build script, while the
GitHub Release is the authoritative distribution location.

## Current Windows release: 0.1.0

| Backend | Archive | Size | SHA-256 |
| --- | --- | ---: | --- |
| C++ core | [Download `streamfind-core-cpp-0.1.0-Windows-x86_64.zip`](https://github.com/odea-project/streamfind/releases/download/v0.1.0/streamfind-core-cpp-0.1.0-Windows-x86_64.zip) | 33,040,640 bytes | `cfcd1b58f26e2e56816dbb353f461a81a862a9cb538db5966fe7e7aa14feb468` |
| Rust backend | [Download `streamfind-rust-0.1.0-Windows-x86_64.zip`](https://github.com/odea-project/streamfind/releases/download/v0.1.0/streamfind-rust-0.1.0-Windows-x86_64.zip) | 21,228,775 bytes | `89fb929dffa659a7e28f268031cfd20e1e9ef545c034482ea432c2f44bf56ba4` |

The complete checksum list is available as the
[`sha256sums.txt`](https://github.com/odea-project/streamfind/releases/download/v0.1.0/sha256sums.txt)
asset attached to the GitHub Release.

## Package contents

### C++ core archive

The C++ archive contains:

- the `streamfind_mcp.exe` MCP server and C++ runtime libraries;
- public C++ headers and libraries;
- `share/streamfind/catalogue.duckdb`;
- the native runtime dependencies assembled by CPack.

### Rust archive

The Rust archive contains:

- `bin/streamfind-rust-cli.exe`;
- `bin/streamfind-rust-mcp.exe`;
- `share/streamfind/catalogue.duckdb`;
- `share/streamfind/catalogue.json`.

The catalogue files are required runtime data. Do not remove them from the
package or distribute the MCP executable without them.

## Extract and run

Extract either archive as a single directory. The MCP server can then be
launched directly by an MCP client over stdio. For the complete request flow,
see the [C++ MCP quickstart](quickstart/cpp-mcp.md) or
[Rust MCP quickstart](quickstart/rust-mcp.md).

Example Rust package layout:

```text
streamfind-rust-0.1.0-Windows-x86_64/
├── bin/
│   ├── streamfind-rust-cli.exe
│   └── streamfind-rust-mcp.exe
└── share/streamfind/
    ├── catalogue.duckdb
    └── catalogue.json
```

## Publishing workflow

Build the packages locally, then publish the archives and checksum file as
assets on a GitHub Release. The repository's release script performs the
backend builds, default release tests, packaging, and checksum generation:

```powershell
powershell -ExecutionPolicy Bypass `
  -File scripts\release.ps1 -Version 0.1.0
```

Create the corresponding tag and GitHub Release with the three generated
assets. Future releases should update the version and asset URLs on this page;
the binary archives do not need to be committed to the source repository.

## Release scope

The native archives are useful for testing the current C++/Rust backends and
MCP interfaces. They do not provide:

- a stable cross-version API or ABI guarantee;
- the public Python package;
- automatic installation of optional scientific tools;
- the preserved R package or its Shiny application.

Optional tools such as Java and MetFrag remain explicit user-installed
components. The release packages do not download them at runtime.
