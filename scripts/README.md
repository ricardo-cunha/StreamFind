# StreamFind build & test scripts

Machine-independent helpers for building and testing the standalone C++ core
(`core/`) and the Rust workspace (`rust/`). All transient artifacts land under
the repository-local `tmp/` folder (see AGENTS.md "Repository Scratch, Build,
and Log Locations"): build trees in `tmp/build/`, logs in `tmp/logs/`.

## Quick start

| Task | Command |
| --- | --- |
| Build the C++ core | `scripts\build-core.cmd` |
| C++ core + run CTest | `scripts\build-core.cmd -Tests` |
| Run C++ CTest only | `scripts\test-core.cmd` |
| Build the Rust workspace | `scripts\build-rust.cmd` |
| Rust workspace + run tests | `scripts\build-rust.cmd -Tests` |
| Run Rust tests only | `scripts\test-rust.cmd` |
| Clean build/test artifacts | `scripts\clean-build-temp.cmd` (keeps `tmp/scripts`, `tmp/logs`; use `--all` to wipe them) |

Every `.cmd` is a thin wrapper over its `.ps1`; use either form.

## Toolchain detection (recommended standards)

`scripts/build-common.ps1` resolves the toolchain with no hardcoded machine
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

- `build-core.ps1` — configures with Ninja into `tmp/build/core-default`
  (`STREAMFIND_BUILD_TESTS=ON`, `STREAMFIND_BUILD_SHARED=OFF`), builds, and
  optionally runs CTest. Flags: `-Clean`, `-Tests`, `-Target <name>`,
  `-Config <Debug|Release>`.
- `test-core.ps1` — runs `ctest --test-dir tmp/build/core-default
  --output-on-failure`. Note the full 18-file `nta_wastewater_conformance`
  suite is intentionally heavy (~hours); the `--quantized` variant is the fast
  CI one.
- `build-rust.ps1` — sets `CARGO_TARGET_DIR=tmp/build/rust-target` and builds
  the workspace (or one `-Package`). Flags: `-Clean`, `-Tests`,
  `-Package <name>`, `-Release`.
- `test-rust.ps1` — `build-rust.ps1 -Tests` shorthand.

## Notes

- On a plain terminal, `TMP`/`TEMP` must be valid Windows paths for MSVC's
  `link.exe` and cargo doctests (the scripts assume a normal user
  environment).
- Build artifacts are gitignored; `clean-build-temp.cmd` removes them while
  preserving `tmp/scripts/` and `tmp/logs/` (use `--all` to wipe those too).