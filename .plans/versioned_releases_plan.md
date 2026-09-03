# Plan: separately versioned releases for core C++ and Rust

Status: proposed (design agreed 2026-08-27)
Owner: dev_refactoring

## Goal

Two strictly separate, self-contained release artifacts — one for the C++ core,
one for the Rust workspace — each with everything a user needs to run the MCP
executables on Windows and Linux (libs, DLLs/SOs, headers, data, catalogue).
Versioned independently, built by CI, published as GitHub Releases.

## Decisions (agreed)

1. **Strictly separate artifacts** — one zip per backend, each self-contained
   (no combined bundle).
2. **Catalogue contract = content hash** — automatic, authoritative, no
   bookkeeping. Both backends embed the hash of `catalogue.duckdb`/`catalogue.json`
   they were built against; MCP `get_metadata` reports it.
3. **Linux packaging = bare TGZ** with the standard layout; build target is
   "latest Ubuntu" (no wide-glibc matrix for the first release).
4. **MSVC runtime bundled** via CMake `install(RUNTIME_DEPENDENCIES)` — max
   portability across clean Windows machines.

## Current state (facts)

- C++ version is hardcoded `"0.1.0"` in `core/src/version.cpp` (not CMake-driven).
- `install()` rules exist for `streamfind_core`, vendored `inchi`/`openbabel`/
  `zlib`, headers, CMake export, DuckDB runtime, openbabel data, and
  `catalogue.duckdb` (to `share/streamfind`).
- **No CPack**, no release CI (only `docs.yml`), no git tags yet.
- DuckDB: Windows = `duckdb.dll`+`duckdb.lib` (shared runtime — must ship),
  Linux = `libduckdb_static.a` (static — no runtime dep). OpenBabel DLLs on
  Windows + data dir both platforms.
- Rust: 8 crates at `0.1.0`, executables `streamfind-rust-mcp` +
  `streamfind-rust-cli`; no install/packaging story.
- Scripts for build/test now exist under `scripts/` (build-core/test-core,
  build-rust/test-rust) with tmp/ artifact centralization.

## Target artifact layout

C++ (`streamfind-core-<ver>-<os>-<arch>.<ext>`):

```
bin/          streamfind_mcp.exe|streamfind_mcp (+ duckdb.dll, openbabel DLLs,
              MSVC vcruntime DLLs via RUNTIME_DEPENDENCIES)
lib/          streamfind_core .lib|.a|.so*, streamfind_mass_spec, streamfind_raman,
              inchi/openbabel/zlib libs, streamfind-core-targets.cmake (find_package)
include/      public headers streamfind/*.hpp
share/streamfind/  catalogue.duckdb, openbabel data
```

Rust (`streamfind-rust-<ver>-<os>-<arch>.<ext>`):

```
bin/          streamfind-rust-mcp(.exe), streamfind-rust-cli(.exe)
share/streamfind/  catalogue.duckdb
```

## Work items

### 1. C++ version single-source (CMake-driven)

- `project(streamfind_core VERSION 0.1.0)` in `core/CMakeLists.txt`.
- `configure_file` a `version.hpp.in` (or generate `version.cpp`) so
  `streamfind::version()` returns the CMake version — one source of truth.
- Keep `version.cpp` as generated output (regenerate in build); add to
  gitignore if generated into the source tree, or better: generate into the
  build tree and include from there (add include dir).

### 2. Catalogue content hash (both backends)

- Generator (`generate_projection.py`) emits `catalogue.sha256` next to
  `catalogue.duckdb`/`catalogue.json` (hash of the .duckdb bytes).
- C++: build-time step (`file(SHA256 ...)` in CMake) embeds the hash as a
  compile definition or generated header; MCP `get_metadata` result includes
  `catalogue_hash`.
- Rust: `include_str!`/`env!` the hash from a generated file or `build.rs`
  reads `catalogue.sha256`; exposes it in the same metadata result.
- Authoritative: any semantic change → new hash automatically; two backends
  agree iff their hashes match. No version bookkeeping.

### 3. CPack for C++ (ZIP on Windows, TGZ on Linux)

- `include(CPack)` with `CPACK_GENERATOR` = ZIP (WIN32) / TGZ (non-WIN32).
- `CPACK_PACKAGE_NAME streamfind-core`, version from project(), package
  file name `streamfind-core-<ver>-<os>-<arch>`.
- Add missing install() targets: `streamfind_mcp` executable, domain libs
  (mass_spec, raman — check they're exported), sensors when present.

### 4. Runtime dependency bundling (C++)

- `install(RUNTIME_DEPENDENCIES)` (CMake ≥3.21; repo uses 4.2) after the
  executable install: gathers duckdb.dll, openbabel DLLs, MSVC runtime DLLs on
  Windows; shared libs on Linux (RPATH `$ORIGIN`-relative).
- Verify openbabel DLL names and the MSVC redist list actually land in bin/.
- Linux: set `CMAKE_INSTALL_RPATH`/`$ORIGIN` so lib resolution works from the
  unpacked layout.

### 5. Rust release packaging

- `cargo build --release --workspace` (or per-crate), strip binaries
  (profile.release strip = true).
- A small script (`scripts/package-rust.ps1` or shell) assembles the layout:
  `bin/` (both exes) + `share/streamfind/catalogue.duckdb` + `catalogue.sha256`
  → zip (Windows) / tar.gz (Linux). Powershell `Compress-Archive` / `tar` on
  both platforms (Windows 10+ ships tar).
- Report crate versions from Cargo.toml; embed catalogue hash at build time.

### 6. Release CI (GitHub Actions)

- New `release.yml`: on tag push `core-cpp-v*` and/or `rust-v*`.
- Matrix: `windows-latest` × `ubuntu-latest`.
- Steps per job: checkout → python .venv (centralized) → build via
  `scripts/build-core.cmd`/`build-rust.cmd` (toolchain detection) →
  fast tests (skip the ~9 min wastewater conformance in CI; run the
  `--quantized` variant) → cpack / package script → upload artifacts.
- Two independent jobs so the two backends can release on their own cadence.
- GitHub Release publishes the platform artifacts per tag.

### 7. Verification

- Build each artifact from a clean checkout using only the release path.
- Unpack on Windows: run `streamfind_mcp` tools/list (catalogue found,
  duckdb.dll beside exe); same for `streamfind-rust-mcp`.
- Linux: run both from the unpacked TGZ; ldd shows no missing libs.
- `get_metadata` on both reports catalogue hash; hashes match the generated
  catalogue.sha256.

## Local releases workflow (implemented 2026-08-28)

`releases/` holds the committed, versioned archives (one per backend × platform):

```
releases/
├── streamfind-core-cpp-0.1.0-Windows-x86_64.zip     (C++ core, CPack ZIP)
├── streamfind-rust-0.1.0-Windows-x86_64.zip         (Rust, assembled)
├── streamfind-core-cpp-0.1.0-Linux-x86_64.tgz       (Linux, via WSL)
├── streamfind-rust-0.1.0-Linux-x86_64.tgz           (Linux, via WSL)
└── sha256sums.txt
```

Driven by **`scripts/release.ps1 -Version <ver> [-Core] [-Rust] [-Linux] [-SkipTests]`**:

- C++: Release build → CPack ZIP from the install tree (libs + headers + CMake
  package + duckdb.dll + catalogue.duckdb + openbabel data). `project(VERSION)`
  is the single version source; `version.cpp` is generated from
  `src/version.cpp.in`, and the MCP `initialize` reports it.
- Rust: `cargo build --release` (workspace profile `strip = true`) → assembled
  `bin/` + `share/streamfind/catalogue.*` → `Compress-Archive`.
- Linux (`-Linux`): delegates to **WSL** (`scripts/release-linux.sh` in the
  distro). WSL2 Ubuntu is a real glibc Linux, so the C++ core (vendored static
  duckdb/openbabel) and Rust compile natively. The build tree lives on the
  **ext4 filesystem** (`$HOME/streamfind-release/<ver>`) because building inside
  `/mnt/c` (drivefs) is 10-50x slower; sources are read from the `/mnt/c`
  mount and the resulting TGZs are copied back to the Windows `releases/` dir.
  One-time WSL setup: `apt-get install cmake ninja-build g++ pkg-config curl
  unzip` + rustup.
- `sha256sums.txt` computed for every archive (content hash — authoritative,
  no version bookkeeping).

CMake packaging notes (learned while implementing):

- `cmake_minimum_required` must be ≥ 3.21 for runtime-dependency tooling.
- `install(TARGETS ... RUNTIME_DEPENDENCY_SET <name>)` in CMake 4.x requires
  the keyword **before** the artifact-kind groups; on the installed 4.2.1 the
  exclusion-regex keywords on `install(RUNTIME_DEPENDENCY_SET)` are rejected.
- Domain targets exporting `target_include_directories(... PUBLIC include)`
  must use the `$<BUILD_INTERFACE:...>`/`$<INSTALL_INTERFACE:include>` split
  or the installed CMake package fails with "prefixed in the source directory".
- The exes link everything static except the DuckDB runtime DLL on Windows;
  no `RUNTIME_DEPENDENCIES` scan is needed (it pulled in system API-set DLLs).
  The explicit `install(FILES ${STREAMFIND_DUCKDB_RUNTIME} → bin)` covers it.
- Catalogue search chain extended with a binary-relative `../share/streamfind`
  candidate so unpacked archives are relocatable (no compile-time prefix).

Verification (done 2026-08-28, Release, -SkipTests):

```
streamfind-core-cpp-0.1.0-Windows-x86_64.zip   30.9 MB   bin(2 exes+duckdb.dll)
                                                         lib(7 .lib + cmake pkg)
                                                         include (headers)
                                                         share (catalogue+openbabel)
streamfind-rust-0.1.0-Windows-x86_64.zip       19.8 MB   bin(2 exes) + share
```

Both archived servers unpacked and served `initialize` (version `0.1.0`) and
`tools/list` (26 tools), and the C++ archived CLI ran `tools status`.

## Out of scope (later)

- DEB/RPM packaging, wide-glibc build matrix, code signing, offline
  MetFrag/openbabel tool bundling (tools resolver installs those separately).

## External tools parity (agreed 2026-08-28)

The `~/.streamfind` tool provisioning must be surface-identical everywhere:
**four operations, four skins** (Rust CLI, C++ CLI, Rust MCP, C++ MCP), all
user-initiated (explicit install only — never silent auto-install).

Semantic operations (declared once, in the core/streamfind domain):

```
streamfind.tools_status          {} → {home, java, metfrag}
streamfind.tools_install         {} → {java, metfrag}
streamfind.tools_install_java    {} → {java}
streamfind.tools_install_metfrag {} → {metfrag}
```

- All `sf:Operation` (stateless; mutate `~/.streamfind`, NOT the project DB →
  `mutatesProject: false`; description notes "downloads to ~/.streamfind; may
  take minutes" for the install ones).
- Expectation: absent tools stay absent until the user calls an install op;
  `tools_status` reports paths or "not found"; the MetFrag method error already
  points at `streamfind tools install`.

Work items:
1. Semantic: declare the four operations (core domain), regenerate projection.
2. C++: register the four operations (registry) so MCP serves them via the
   existing generic dispatch; verify against the catalogue.
3. C++ CLI: new `streamfind-cli` executable (core/tools/) mirroring the Rust
   CLI: `create`, `describe`, and the four `tools` subcommands, calling
   `streamfind::tools::*` directly.
4. Rust: register the four operations in the MCP dispatch (semantic-driven),
   matching the catalogue.
5. Tests: at minimum a tool-status smoke test per backend and a
   semantic-validation pass; install tests stay manual/optional (network).

## Rollout

Implement on `dev_refactoring` (or a `releases` worktree if preferred).
Land in a few commits:
1. C++ version single-source + catalogue hash embedding
2. CPack + RUNTIME_DEPENDENCIES + install fixes
3. Rust release packaging script
4. release.yml CI workflow
5. External-tools parity (semantic ops + C++ CLI + MCP registration both) —
   can land first, independently of the packaging work.