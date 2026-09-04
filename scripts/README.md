# streamfind build & test scripts

Machine-independent helpers for building and testing the standalone C++ core
(`core/`) and the Rust workspace (`rust/`). All transient artifacts land under
the repository-local `tmp/` folder (see AGENTS.md "Repository Scratch, Build,
and Log Locations"): build trees in `tmp/build/`, release packages in
`tmp/release-output/`, and logs in `tmp/logs/`.

## Quick start

| Task | Command |
| --- | --- |
| Build the C++ core | `scripts\build\build-core.cmd` |
| C++ core + run CTest | `scripts\build\build-core.cmd -Tests` |
| Run C++ CTest only | `scripts\build\test-core.cmd` |
| Build the Rust workspace | `scripts\build\build-rust.cmd` |
| Rust workspace + run tests | `scripts\build\build-rust.cmd -Tests` |
| Run Rust tests only | `scripts\build\test-rust.cmd` |
| Run C++ built-MCP data test | `scripts/dev/test-data.ps1 -Backend Cpp` |
| Run Rust built-MCP data test | `scripts/dev/test-data.ps1 -Backend Rust` |
| Run C++ built-MCP NTA test | `scripts/dev/test-nta.ps1 -Backend Cpp` |
| Run Rust built-MCP NTA test | `scripts/dev/test-nta.ps1 -Backend Rust` |
| Run vendor reader parser test | `scripts/dev/test-vendor-readers.ps1 -Backend Cpp -Vendor Shimadzu` |
| Run data-backed NTA pipeline | Add `-RunPipeline` to `scripts/dev/test-nta.ps1` |
| Build release archives | `scripts/release/release.ps1 -Version <version>` |
| Publish a prepared GitHub Release | `scripts/release/publish-release.ps1 -Version <version>` |
| Clean build/test artifacts | `scripts\build\clean-build-temp.cmd` |

Every `.cmd` is a thin wrapper over its `.ps1`; use either form.

The official C++ suite is the framework, mass-spectrometry interface, and
lightweight NTA interface coverage registered by CMake. The official Rust
workspace suite follows the same boundary. Raw reader/parity tests and
data-backed NTA tests are development-stage checks under `scripts/dev/`; they
launch the built MCP executables and are not C++/Rust test-source targets.

## External example data

Large mass-spectrometry and Raman example datasets are maintained in the
auxiliary `streamfind.data` repository next to this checkout:

```text
<parent-directory>/streamfind.data
```

For example, when the repositories are under `C:/Users/cunha/Documents/GitHub`:

```text
C:/Users/cunha/Documents/GitHub/streamfind
C:/Users/cunha/Documents/GitHub/streamfind.data
```

The development PowerShell scripts detect the sibling repository's `data/`
directory automatically. Clone the auxiliary repository from:

```text
https://git.uni-due.de/odea-project/streamfind/streamfind.data
```

To use a different data directory, set:

```text
STREAMFIND_EXAMPLE_DATA_ROOT=<path-to-streamfind.data/data>
```

Only small backend-neutral fixtures remain under `tests/fixtures/`; large
example datasets are not release contents.

## Toolchain detection (recommended standards)

`scripts/build/build-common.ps1` resolves the toolchain with no hardcoded machine
paths, using the standard mechanisms:

- **Visual Studio / MSVC** — located via `vswhere.exe` (the official Visual
  Studio Installer query tool), selecting the latest installation with the
  VC++ x64 tools component; `vcvarsall.bat` is then derived from that install.
  Override with `$env:VSINSTALLDIR`.
- **cmake** — `$env:CMAKE` override, else `PATH` (`Get-Command`).
- **ctest** — resolved as the sibling of the resolved `cmake` (same
  installation), else `PATH`.
- **ninja** — `$env:NINJA` override, else `PATH`, else Visual Studio's bundled
  Ninja (`Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja\ninja.exe`).
- **cargo** — `$env:CARGO` override, else `PATH`.

Failures are explicit with a helpful message pointing at the missing tool or
install method.

## What each script does

- `scripts/build/build-core.ps1` — configures with Ninja into `tmp/build/core-default`
  (`STREAMFIND_BUILD_TESTS=ON`, `STREAMFIND_BUILD_SHARED=OFF`), builds, and
  optionally runs CTest. Flags: `-Clean`, `-Tests`, `-Target <name>`,
  `-Config <Debug|Release>`.
- `scripts/build/test-core.ps1` — runs `ctest --test-dir tmp/build/core-default
  --output-on-failure` for the official framework, mass-spec interface, and
  lightweight NTA interface suite. Data-backed parsing and NTA checks use the
  dedicated scripts in `scripts/dev/`.
- `scripts/build/build-rust.ps1` — sets `CARGO_TARGET_DIR=tmp/build/rust-target` and builds
  the workspace (or one `-Package`). Flags: `-Clean`, `-Tests`,
  `-Package <name>`, `-Release`.
- `scripts/build/test-rust.ps1` — `build-rust.ps1 -Tests` shorthand.
- `scripts/release/release.ps1` — builds, runs the official lightweight test suites, packages,
  and hashes the C++ and Rust release archives into `tmp/release-output/`. It
  does not run development-stage data or NTA scripts and does not create or
  upload a GitHub Release.
- `scripts/release/publish-release.ps1` — validates the versioned archives and checksums in
  `tmp/release-output/`, then creates a GitHub Release. Pass `-Replace` only
  when intentionally replacing assets in an existing release.

## Notes

- On a plain terminal, `TMP`/`TEMP` must be valid Windows paths for MSVC's
  `link.exe` and cargo doctests (the scripts assume a normal user
  environment).
- Build artifacts are gitignored; `scripts/build/clean-build-temp.cmd` removes
  them while preserving tracked scripts and `tmp/logs/`.