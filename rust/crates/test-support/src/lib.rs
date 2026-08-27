//! Test-support helpers, per AGENTS.md "Repository Scratch, Build, and Log
//! Locations (tmp/)".
//!
//! Every transient artifact a test or ad-hoc run creates must live under the
//! repository-local `tmp/` folder — never in the system temp directory
//! (`std::env::temp_dir()`), the CWD, or the source tree. This crate provides
//! the canonical path for test-created DuckDB projects and other disposable
//! files: `<repo-root>/tmp/projects/`.

use std::path::PathBuf;

/// Returns `<repo-root>/tmp/projects`, creating it (and any missing parents)
/// on first use.
///
/// The repository root is located from this crate's expected position inside
/// the workspace (`rust/crates/test-support/src/`), so the helper works
/// regardless of the test executable's working directory.
pub fn tmp_projects_dir() -> PathBuf {
    let here = PathBuf::from(env!("CARGO_MANIFEST_DIR")); // rust/crates/test-support
    let repo = here
        .parent() // rust/crates
        .and_then(|p| p.parent()) // rust
        .and_then(|p| p.parent()) // <repo-root>
        .expect("test-support crate must live at rust/crates/test-support");
    let dir = repo.join("tmp").join("projects");
    std::fs::create_dir_all(&dir).expect("cannot create repository tmp/projects directory");
    dir
}