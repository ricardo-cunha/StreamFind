#pragma once

// Test-output location policy (AGENTS.md "Repository Scratch, Build, and Log
// Locations (tmp/)") — every transient artifact must land under the
// repository-local tmp/ folder, never in the CWD, the source tree, or the
// system temp directory.
//
// DuckDB project files created by tests belong in <repo-root>/tmp/projects/.

#include <filesystem>
#include <string>

namespace streamfind::test {

// Returns <repo-root>/tmp/projects, creating it (and any missing parents) on
// first use. The repository root is located from this file's expected position
// (core/tests/) so the helper works regardless of the test executable's
// working directory, for every core test target that includes it.
inline std::filesystem::path tmp_projects_dir() {
    std::filesystem::path here = std::filesystem::path(__FILE__);
    std::filesystem::path repo = here.parent_path()   // core/tests
                                     .parent_path()   // core
                                     .parent_path();  // <repo-root>
    std::filesystem::path dir = repo / "tmp" / "projects";
    std::error_code error;
    std::filesystem::create_directories(dir, error);
    return dir;
}

}  // namespace streamfind::test