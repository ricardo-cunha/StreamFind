# Streamfind Rust CLI

The CLI currently supports project creation and description.

```powershell
cargo run --manifest-path rust/Cargo.toml -p streamfind-rust-cli -- create `
  --database-path "$HOME\.streamfind\projects\demo.duckdb" `
  --project-id demo
```

Replace `create` with `describe` to read an existing project. Both commands
require `--database-path` and `--project-id`.
