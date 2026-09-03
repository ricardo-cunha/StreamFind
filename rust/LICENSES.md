# Rust dependency licence inventory

This inventory is generated from the locked Cargo package metadata for the
streamfind workspace. The package registry/source remains authoritative for
the exact licence text and copyright notices. Native Rust release archives must
ship the required licence texts or an equivalent complete attribution payload.

## Direct and bundled dependencies

| Package | Version | Declared licence |
| --- | --- | --- |
| `duckdb` | 1.10505.0 | MIT |
| `libduckdb-sys` | 1.10505.0 | MIT |
| `arrow` | 58.4.0 | Apache-2.0 |
| `cfb` | 0.14.0 | MIT |
| `quick-xml` | 0.38.4 | MIT |
| `base64` | 0.22.1 / 0.23.1 | MIT OR Apache-2.0 |
| `flate2` | 1.1.9 | MIT OR Apache-2.0 |
| `zstd` | 0.13.3 | MIT |
| `zstd-sys` | 2.0.16+zstd.1.5.7 | MIT/Apache-2.0 |
| `regex` | 1.13.1 | MIT OR Apache-2.0 |
| `serde` | 1.0.229 | MIT OR Apache-2.0 |
| `serde_json` | 1.0.151 | MIT OR Apache-2.0 |
| `chrono` | 0.4.45 | MIT OR Apache-2.0 |
| `uuid` | 1.26.0 | Apache-2.0 OR MIT |
| `ureq` | 3.4.0 | MIT OR Apache-2.0 |
| `tar` | 0.4.46 | MIT OR Apache-2.0 |
| `zip` | 6.0.0 | MIT |

This table is a release-audit starting point, not a substitute for auditing
all transitive packages in `rust/Cargo.lock`. Re-run the dependency audit when
Cargo.lock changes and preserve the exact upstream MIT/Apache and other licence
texts required by the final release model.
