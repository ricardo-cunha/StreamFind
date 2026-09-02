# Testing

Tests are organized per component against shared backend-neutral fixtures in
`tests/`. The C++ and Rust backends are tested independently; interoperability
comes from the shared schema, semantic catalogue, and fixtures rather than a
shared native implementation.

## Semantic contract

From the repository root:

```powershell
& .\.venv\Scripts\python.exe semantic\validate_semantic.py
& .\.venv\Scripts\python.exe semantic\generate_projection.py --check
```

After editing `semantic/ontology/`, regenerate the committed projection:

```powershell
& .\.venv\Scripts\python.exe semantic\generate_projection.py
```

## C++ core

The source build uses the `core/CMakePresets.json` preset and writes to
`tmp/build/core-default`:

```powershell
scripts\build-core.cmd
scripts\test-core.cmd
```

The default CTest command excludes tests labelled `reader-interface`. Those are
direct reader/vendor-fixture tests and are not part of the distribution-facing
suite. Run them explicitly when the local fixtures are available:

```powershell
scripts\test-core.cmd -IncludeReaderInterface
```

Equivalent CTest commands:

```powershell
ctest --test-dir tmp\build\core-default -C Debug `
  -LE reader-interface --output-on-failure
ctest --test-dir tmp\build\core-default -C Debug `
  -L reader-interface --output-on-failure
```

## Rust backend

From `rust/`:

```powershell
cargo build --workspace
cargo test --workspace
```

The default workspace suite excludes direct reader-interface and vendor-parity
integration-test targets. They are explicit Cargo targets requiring the
`reader-interface-tests` feature:

```powershell
cargo test -p streamfind-rust-mass-spec `
  --features reader-interface-tests
```

The repository helpers provide the same boundary:

```powershell
scripts\test-rust.cmd
scripts\test-rust.cmd `
  -Package streamfind-rust-mass-spec `
  -IncludeReaderInterface
```

The full default Rust suite includes the long NTA wastewater conformance test.
For fast feedback on MCP changes, run only the MCP package tests:

```powershell
cargo test -p streamfind-rust-mcp
```

## Shared fixtures and release validation

Shared project fixtures live under `tests/data/project/` and are consumed by
both backends. Mass-spectrometry fixtures live under
`tests/data/mass_spec/`. Some proprietary vendor-reader tests require local
fixture paths and are intentionally separate from the default distribution
suite.

Build both current Windows packages with:

```powershell
powershell -ExecutionPolicy Bypass `
  -File scripts\release.ps1 -Version 0.1.0
```

The release script runs the default C++ and Rust suites before packaging. The
resulting archives and checksums are documented on the [Releases](releases.md)
page.
