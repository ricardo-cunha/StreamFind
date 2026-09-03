# Releases

The repository currently publishes versioned **preview releases** for the
native C++ and Rust backends. These archives are self-contained runtime
packages for Windows x64 and Linux x86_64; they are not yet
compatibility-stable SDK releases.

The GitHub Release is the authoritative distribution location.

The project source is maintained at
<https://github.com/ricardo-cunha/streamfind>. The `v0.1.0` assets listed below
are historical downloads that remain hosted at their original release location;
new releases will be published from the current repository.

## Project version: {{ streamfind_version }}

The native C++ and Rust project metadata now targets version **{{ streamfind_version }}**. The
latest downloadable GitHub assets remain version **0.1.0** until the new
versioned archives are published.

The currently listed `v0.1.0` archives predate the expanded attribution
payload. New archives built from the current source are expected to include
`NOTICE.md`, `LICENSE.md`, and the backend-specific attribution payload
(`licenses/` for C++ or `LICENSES.md` for Rust) at the package root.

## Latest downloadable release: 0.1.0

| Backend | Archive | Size | SHA-256 |
| --- | --- | ---: | --- |
| C++ core | [Download `streamfind-core-cpp-0.1.0-Windows-x86_64.zip`](https://github.com/odea-project/streamfind/releases/download/v0.1.0/streamfind-core-cpp-0.1.0-Windows-x86_64.zip) | 33,040,640 bytes | `cfcd1b58f26e2e56816dbb353f461a81a862a9cb538db5966fe7e7aa14feb468` |
| Rust backend | [Download `streamfind-rust-0.1.0-Windows-x86_64.zip`](https://github.com/odea-project/streamfind/releases/download/v0.1.0/streamfind-rust-0.1.0-Windows-x86_64.zip) | 21,228,775 bytes | `89fb929dffa659a7e28f268031cfd20e1e9ef545c034482ea432c2f44bf56ba4` |
| C++ core | [Download `streamfind-core-cpp-0.1.0-Linux-x86_64.tgz`](https://github.com/odea-project/streamfind/releases/download/v0.1.0/streamfind-core-cpp-0.1.0-Linux-x86_64.tgz) | 85,094,150 bytes | `77b00db14fbf820162e820ca96a9306e3e7becc82303b8f19bd22fa33517f87f` |
| Rust backend | [Download `streamfind-rust-0.1.0-Linux-x86_64.tgz`](https://github.com/odea-project/streamfind/releases/download/v0.1.0/streamfind-rust-0.1.0-Linux-x86_64.tgz) | 30,863,068 bytes | `e2c04e447a10bac99e0b4e4d7aaa4c8dc1ba85cebf66ac2890c7c17c64357451` |

The complete checksum list is available as the
[`sha256sums.txt`](https://github.com/odea-project/streamfind/releases/download/v0.1.0/sha256sums.txt)
asset attached to the GitHub Release.

## Package contents

### C++ core archive

The C++ archives contain:

- the `streamfind_mcp.exe` or `streamfind_mcp` MCP server and C++ runtime libraries;
- public C++ headers and libraries;
- `share/streamfind/catalogue.duckdb`;
- the native runtime dependencies assembled by CPack.

### Rust archive

The Rust archives contain:

- `bin/streamfind-rust-cli.exe` or `bin/streamfind-rust-cli`;
- `bin/streamfind-rust-mcp.exe` or `bin/streamfind-rust-mcp`;
- `share/streamfind/catalogue.duckdb`;
- the native runtime dependencies assembled for the package.

`share/streamfind/catalogue.duckdb` is required runtime data for both native
backends. Do not remove it from the package or distribute an MCP executable
without it.

## Legal and attribution files

Native archives should be distributed together with the project notice and
the backend-specific attribution payload:

```text
NOTICE.md
LICENSE.md
C++: vendor licence texts from `core/vendor/`
Rust: LICENSES.md
```

These files identify streamfind's licence, bundled third-party components, and
the licence terms that apply to the packaged runtime. Native archives do not
include vendor SDKs, vendor DLLs, proprietary vendor software, development-only
oracle tools, or external vendor sample files.

See the repository [`NOTICE.md`](https://github.com/ricardo-cunha/streamfind/blob/dev_refactoring/NOTICE.md)
for the current attribution and legal-review boundary.

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
    └── catalogue.duckdb
```

## Release scope

The native archives are useful for testing the current C++/Rust backends and
MCP interfaces. They do not provide:

- a stable cross-version API or ABI guarantee;
- the public Python package;
- automatic installation of optional scientific tools;
- the preserved R package or its Shiny application.

Optional tools such as Java and MetFrag remain explicit user-installed
components. The release packages do not download them at runtime.
