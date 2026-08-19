# Testing

Tests are organized per component against the shared backend-neutral fixtures
in `tests/`.

## Shared fixtures

- `tests/data/` — analytical sample data (mass spectrometry, Raman, sensors)
  plus project conformance fixtures such as
  `tests/data/project/project_conformance.json`.
- `tests/fixtures/` — semantic and MCP JSON fixtures.

Both backends run the same conformance fixtures to prove shared behaviour
without sharing native code.

## Semantic

```powershell
& .\semantic\validate.ps1
```

Validates the Turtle catalogue with SHACL. After changing the ontology,
regenerate the projection and ensure it is committed:

```powershell
& .\.venv\Scripts\python.exe .\semantic\generate_projection.py
```

## C++ core

```powershell
cmake --preset default
cmake --build --preset default --config Debug
ctest --test-dir build/cmake/default -C Debug --output-on-failure
```

Conformance tests live in `core/tests/`, including the project conformance
test in `core/tests/unit/conformance.cpp`.

## Rust backend

From `rust/`:

```powershell
cargo fmt --all -- --check
cargo test --workspace
```

Conformance tests live in `rust/crates/core/tests/`.

## Interoperability

The C++ and Rust implementations are validated against each other through the
shared fixtures, not through a shared runtime:

```text
tests/data/project/project_conformance.json
core/tests/unit/conformance.cpp
rust/crates/core/tests/conformance.rs
```
