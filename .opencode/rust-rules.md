# Rust Project Rules

- Put Rust tests in the owning crate's `tests/` directory. Do not add inline
  `#[cfg(test)] mod tests` modules to implementation files.
- Keep integration tests under the relevant crate, such as
  `rust/crates/core/tests/` or `rust/crates/cli/tests/`.
