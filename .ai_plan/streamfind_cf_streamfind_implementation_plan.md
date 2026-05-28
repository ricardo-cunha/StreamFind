# Implementation Plan: Add `cf-streamfind` Python Package to the `StreamFind` Repository

## Goal

Modify the existing `odea-project/StreamFind` repository on branch `dev_filesystem` so that the same repository provides:

1. The existing R package named `StreamFind`, installable with:

   ```r
   remotes::install_github("odea-project/StreamFind@dev_filesystem")
   ```

2. A Python package named `cf-streamfind`, installable locally from the repository root with:

   ```bash
   pip install .
   ```

3. A Python import module named `cf_streamfind`:

   ```python
   import cf_streamfind
   ```

4. A future PyPI distribution named `cf-streamfind`, buildable from the repository root with:

   ```bash
   python -m build
   ```

5. One shared native C++ implementation used by both R and Python/CogniFlow.

---

## Big-Picture Architecture

The repository should end in a dual-frontend layout:

1. The repository root remains a valid R package named `StreamFind`.
2. The repository root also becomes a valid Python build root for a package named `cf-streamfind`.
3. The native code is split into three layers:
   - `src/core/`: shared, framework-agnostic C++ implementation
   - `src/`: Rcpp bridge files kept at the top level so `Rcpp::compileAttributes()` and `devtools::load_all()` continue to work normally
   - `python/cf_streamfind/cpp/`: CogniFlow bridge used only by the Python package
4. R and Python must each compile only their own bridge layer plus the shared core.
5. The first success criterion is structural separation with the R package still building; the Python package is added only after that split is stable.

In practical terms, this migration is really: extract one reusable C++ core from the current R-native layout, then attach two packaging frontends to that core.

---

## Recommended Delivery Sequence

Implement this migration in three checkpoints rather than as one continuous file-copy exercise.

### Checkpoint A: Native split only

Scope:

- Create `src/core/`
- Move shared native sources into `src/core/`
- Keep Rcpp bridge sources in top-level `src/`
- Update `src/Makevars` and `src/Makevars.win`
- Confirm the R package still compiles

Exit condition:

- `devtools::load_all('.')` or equivalent succeeds
- No Python integration is blocking the R-native refactor

### Checkpoint B: Python packaging scaffold

Scope:

- Add `pyproject.toml`, root `CMakeLists.txt`, and `MANIFEST.in`
- Add `python/cf_streamfind/`
- Copy minimal CogniFlow package assets and Python tests
- Keep `steps.cpp` thin and adapter-only

Exit condition:

- `python -m pip install .` at least reaches the native build stage against the new layout

### Checkpoint C: Cross-frontend validation

Scope:

- Finish wiring `steps.cpp` to the real shared APIs
- Update ignore files and README
- Validate R check, Python install, and wheel build

Exit condition:

- R build passes
- Python import passes
- `python -m build` produces distributable artifacts

This sequence matters because the current repository is already a working R package. The highest-risk work is the native refactor, not the Python metadata.

---

## Current Repository Facts

The current `StreamFind` repository is already an R package at the repository root. Keep that layout.

The current branch contains these important root-level R package files and folders:

```text
StreamFind/
├─ DESCRIPTION
├─ NAMESPACE
├─ R/
├─ inst/
├─ man/
├─ tests/
├─ vignettes/
├─ src/
├─ README.Rmd
├─ README.md
├─ LICENSE
├─ .Rbuildignore
└─ .gitignore
```

The current `src/` folder contains native code and Rcpp-related files similar to:

```text
src/
├─ asm/
├─ external/
├─ json_core/
├─ mass_spec/
├─ nta/
├─ project/
├─ Makevars
├─ Makevars.win
├─ RcppExports.cpp
├─ rcpp_asm_read_test.cpp
├─ rcpp_duckdb_test.cpp
├─ rcpp_json_schema_validation_test.cpp
├─ rcpp_json_test.cpp
├─ rcpp_project_export.cpp
└─ rcpp_project_nta_export.cpp
```

The attached CogniFlow playground contains the Python package currently at:

```text
resources/cf_streamfind/
├─ pyproject.toml
├─ CMakeLists.txt
├─ README.md
├─ cmake/Repackaged.cmake
├─ src/cf_streamfind/__init__.py
├─ src/cf_streamfind/steps.nq
├─ src/cf_streamfind/cpp/steps.cpp
├─ src/cf_streamfind/cpp/CMakeLists.txt
├─ src/cf_streamfind/cpp/cf_streamfind_signature_hashes.h
└─ tests/
```

---

## Target Repository Layout

Implement this final structure:

```text
StreamFind/
├─ DESCRIPTION                         # R package metadata: Package: StreamFind
├─ NAMESPACE
├─ R/
├─ inst/
├─ man/
├─ tests/                              # existing R tests
├─ vignettes/
├─ README.Rmd
├─ README.md
├─ LICENSE
├─ .Rbuildignore
├─ .gitignore
│
├─ src/                                # R native source root and shared C++ root
│  ├─ core/                            # new shared C++ implementation namespace
│  │  ├─ asm/                          # moved/copied from src/asm if shared
│  │  ├─ external/                     # moved/copied from src/external if shared
│  │  ├─ json_core/                    # moved/copied from src/json_core if shared
│  │  ├─ mass_spec/                    # moved/copied from src/mass_spec if shared
│  │  ├─ nta/                          # moved/copied from src/nta if shared
│  │  ├─ project/                      # moved/copied from src/project if shared
│  │  └─ CMakeLists.txt                # optional helper for shared C++ only
│  │
│  ├─ RcppExports.cpp                  # R/Rcpp bridge files remain in top-level src/
│  ├─ rcpp_asm_read_test.cpp
│  ├─ rcpp_duckdb_test.cpp
│  ├─ rcpp_json_schema_validation_test.cpp
│  ├─ rcpp_json_test.cpp
│  ├─ rcpp_project_export.cpp
│  ├─ rcpp_project_nta_export.cpp
│  ├─ Makevars
│  └─ Makevars.win
│
├─ pyproject.toml                      # Python package metadata: name = "cf-streamfind"
├─ CMakeLists.txt                      # Python/scikit-build-core build entrypoint
├─ MANIFEST.in                         # Python source distribution include rules
│
├─ python/
│  └─ cf_streamfind/
│     ├─ __init__.py
│     ├─ steps.nq
│     ├─ cpp/
│     │  ├─ steps.cpp                  # CogniFlow ABI bridge only
│     │  └─ CMakeLists.txt             # optional local helper
│     ├─ bin/                          # generated/native runtime library lands here in wheel
│
├─ tests/
│  ├─ ...                              # existing R tests
│  └─ python/                          # Python tests copied from resources/cf_streamfind/tests
│     ├─ test_gcms_steps.py
│     ├─ test_gcms_datahive_integration.py
│     ├─ test_gcms_pipeline_engine_runtime.py
│     ├─ test_gcms_pipeline_manager_runtime.py
│     └─ fixtures/
│
├─ cmake/
│  └─ Repackaged.cmake                 # copied from resources/cf_streamfind/cmake if still needed
│
└─ .github/workflows/
   ├─ r-check.yml                      # existing or new R CI
   ├─ python-build.yml                 # new Python package CI
   └─ publish-pypi.yml                 # future PyPI publishing workflow
```

---

## Naming Rules

Use these names exactly:

| Surface | Name |
|---|---|
| GitHub repository | `StreamFind` |
| R package | `StreamFind` |
| Python PyPI package | `cf-streamfind` |
| Python import package | `cf_streamfind` |
| CogniFlow entry point group | `cogniflow.steps` |
| CogniFlow entry point name | `cf.streamfind` |

Do not rename the R package to `cf-streamfind`. R package names cannot use hyphens.

---

## Implementation Rules for the Agent

Follow these rules strictly:

1. Preserve the repository root as a valid R package.
2. Add Python packaging files at the repository root.
3. Put the importable Python module in `python/cf_streamfind/`.
4. Put CogniFlow-only C++ bridge code in `python/cf_streamfind/cpp/`.
5. Put shared C++ code under `src/core/`.
6. Keep the R-only Rcpp bridge `.cpp` files in top-level `src/` so standard Rcpp attribute generation continues to work.
7. The shared C++ code must not include Python, CogniFlow, Rcpp, or R headers.
8. The R bridge may include Rcpp headers.
9. The CogniFlow bridge may include CogniFlow ABI headers.
10. Do not commit generated binaries such as `.dll`, `.so`, `.dylib`, `.pyd`, `build/`, `dist/`, or `*.egg-info`.

---

## Phase 1: (skipped)

This plan assumes the working branch `dev_filesystem` is already up-to-date and ready for implementation. Creating a separate safety branch is not required for this session — proceed directly with Phase 2.

---

## Phase 2: Restructure Native Code into Core and R Bridge

This phase is the architectural pivot of the migration. Do not mix it with Python adapter work yet beyond what is needed for planning.

Primary objective:

- Preserve current R behavior while changing the native code layout so Python can consume the same implementation later.

Phase completion criteria:

- Shared code is under `src/core/`
- Rcpp bridge code remains in top-level `src/`
- `Makevars` and `Makevars.win` build from the new layout
- The R package still compiles after the move

### 2.1 Create target folders

```bash
mkdir -p src/core
```

### 2.2 Move shared C++ folders

Move these existing folders into `src/core/` if they are used by the algorithmic implementation and do not directly depend on Rcpp:

```bash
git mv src/asm src/core/asm
git mv src/external src/core/external
git mv src/json_core src/core/json_core
git mv src/mass_spec src/core/mass_spec
git mv src/nta src/core/nta
git mv src/project src/core/project
```

If any of these folders contain Rcpp-specific code, do not move that specific file blindly. Instead:

1. Leave the Rcpp-specific bridge file in top-level `src/`.
2. Move only reusable pure C++ files to `src/core/`.
3. Update includes accordingly.

### 2.3 Keep Rcpp bridge files in top-level `src/`

Keep these files where they already are:

```text
src/RcppExports.cpp
src/rcpp_asm_read_test.cpp
src/rcpp_duckdb_test.cpp
src/rcpp_json_schema_validation_test.cpp
src/rcpp_json_test.cpp
src/rcpp_project_export.cpp
src/rcpp_project_nta_export.cpp
```

Reason:

- `Rcpp::compileAttributes()` and `devtools::load_all()` expect exported Rcpp translation units in top-level `src/`.
- Moving them into `src/r/` breaks standard auto-generation of `R/RcppExports.R` unless non-standard extra build steps are added.

### 2.4 Update include paths in C++ files

Search for local includes:

```bash
grep -R "#include \"" -n src/core src | tee /tmp/streamfind_includes.txt
```

Update include statements so that files in top-level `src/` can include shared headers from `src/core/`.

Preferred include style from R bridge files:

```cpp
#include "project/some_header.hpp"
#include "mass_spec/some_header.hpp"
#include "nta/some_header.hpp"
```

Avoid include style that depends on fragile relative paths like:

```cpp
#include "../core/project/some_header.hpp"
```

The include directories in `Makevars` and CMake should make this unnecessary.

---

### Phase 2 Conclusion

After Phase 2, the repository should have a stable hybrid native layout:

- `src/core/` contains the reusable shared C++ implementation.
- Top-level `src/` still contains the Rcpp bridge translation units used by the R package.
- This is intentional, not transitional: keeping the R bridge in top-level `src/` preserves standard `Rcpp::compileAttributes()` and `devtools::load_all()` behavior, while `src/core/` becomes the shared source root for future Python/CogniFlow compilation.

This means later development should treat `src/core/` as the portable engine layer and top-level `src/*.cpp` as the R-specific binding layer.

---

## Phase 3: Update R Build Files

This phase closes Checkpoint A. Treat any R compilation or linkage failure here as a blocker for Phase 4 and beyond.

Open `src/Makevars` and `src/Makevars.win`.

### 3.1 Add include directories

Ensure both files include at least:

```make
PKG_CPPFLAGS += -Icore -Icore/asm -Icore/external -Icore/json_core -Icore/mass_spec -Icore/nta -Icore/project
```

### 3.2 Ensure R compiles files in subdirectories

R package compilation from `src/` does not always recursively compile arbitrary subdirectories without help.

Use an explicit object list if needed.

Example pattern:

```make
SOURCES = \
  RcppExports.cpp \
  rcpp_asm_read_test.cpp \
  rcpp_duckdb_test.cpp \
  rcpp_json_schema_validation_test.cpp \
  rcpp_json_test.cpp \
  rcpp_project_export.cpp \
  rcpp_project_nta_export.cpp \
  core/asm/file1.cpp \
  core/mass_spec/file2.cpp \
  core/nta/file3.cpp \
  core/project/file4.cpp

OBJECTS = $(SOURCES:.cpp=.o)
```

Do not use the placeholder filenames above. Replace them with real `.cpp` files from the repository.

Note: during development use `devtools::load_all()` to compile and load the package in-place and quickly surface C++ compilation or linking errors. For example, run in an R session:

```r
devtools::load_all()
```

Or from the shell:

```bash
R -e "devtools::load_all('.')"
```

This is faster than a full `R CMD build`/`R CMD INSTALL` cycle and is useful for iterating on `src/` changes.

### 3.3 Keep CogniFlow files out of the R build

The R build must not compile:

```text
python/cf_streamfind/cpp/steps.cpp
```

The R build must not include CogniFlow headers such as:

```cpp
#include "cf_step_abi.h"
#include "cf_step_utils.h"
#include "cf_plugin_table.h"
```

---

### Phase 3 Inspection Conclusion

Phase 3 is complete for the current refactor checkpoint.

- `src/Makevars` and `src/Makevars.win` now build the moved shared sources from `src/core/` explicitly.
- The Rcpp bridge translation units remain in top-level `src/`, so `Rcpp::compileAttributes()` and `devtools::load_all()` still follow standard package behavior.
- The refactored package was validated with `Rcpp::compileAttributes('.')` and `devtools::load_all('.')`, which completed successfully after the source split.

This means no additional structural R-build work is currently required before Phase 4. Further R-side changes should now be limited to fixes discovered while adding the Python frontend, not to the core Phase 3 layout itself.

---

## Phase 4: Add Python Package Files at Repository Root

Only start this phase after the Phase 2-3 refactor builds correctly from R. If the shared core is not stable yet, Python integration will widen the failure surface and slow debugging.

The Cogniflow playground sources are available locally and as a ZIP archive. Prefer copying directly from the local checkout `C:/Users/cunha/Documents/GitHub/cogniflow-playground/resources/cf_streamfind`. If the local path is not present, fall back to extracting `.ai_plan/cogniflow-playground-20260527-122156.zip`.

Reshape that package into the new root-based structure.

### 4.1 Copy Python runtime module

Create target folder:

```bash
mkdir -p python/cf_streamfind
```

Preferred: copy from the local Cogniflow checkout (Windows PowerShell):

```powershell
New-Item -ItemType Directory -Force -Path python\cf_streamfind
Copy-Item -Path 'C:\Users\cunha\Documents\GitHub\cogniflow-playground\resources\cf_streamfind\src\cf_streamfind\__init__.py' -Destination python\cf_streamfind\
Copy-Item -Path 'C:\Users\cunha\Documents\GitHub\cogniflow-playground\resources\cf_streamfind\src\cf_streamfind\steps.nq' -Destination python\cf_streamfind\
New-Item -ItemType Directory -Force -Path python\cf_streamfind\data
Copy-Item -Path 'C:\Users\cunha\Documents\GitHub\cogniflow-playground\resources\cf_streamfind\src\cf_streamfind\data\*' -Destination python\cf_streamfind\data\ -Recurse -ErrorAction SilentlyContinue
```

Or (POSIX shell) copy from the local checkout:

```bash
mkdir -p python/cf_streamfind
cp /mnt/c/Users/cunha/Documents/GitHub/cogniflow-playground/resources/cf_streamfind/src/cf_streamfind/__init__.py python/cf_streamfind/__init__.py
cp /mnt/c/Users/cunha/Documents/GitHub/cogniflow-playground/resources/cf_streamfind/src/cf_streamfind/steps.nq python/cf_streamfind/steps.nq
```

Fallback: if the local checkout is missing, extract the ZIP and copy from the extracted tree (POSIX example):

```bash
unzip .ai_plan/cogniflow-playground-20260527-122156.zip -d /tmp/cogniflow-playground
cp /tmp/cogniflow-playground/resources/cf_streamfind/src/cf_streamfind/__init__.py python/cf_streamfind/__init__.py
cp /tmp/cogniflow-playground/resources/cf_streamfind/src/cf_streamfind/steps.nq python/cf_streamfind/steps.nq
```

Do not copy generated binaries from the `bin/` directory in the source archive.

### 4.2 Copy CogniFlow bridge code

Create target folder:

```bash
mkdir -p python/cf_streamfind/cpp
```

Copy the C++ bridge files (Linux/macOS example using extracted ZIP):

```bash
cp /tmp/cogniflow-playground/resources/cf_streamfind/src/cf_streamfind/cpp/steps.cpp python/cf_streamfind/cpp/steps.cpp
cp /tmp/cogniflow-playground/resources/cf_streamfind/src/cf_streamfind/cpp/CMakeLists.txt python/cf_streamfind/cpp/CMakeLists.txt
```

Or Windows PowerShell (local checkout):

```powershell
Copy-Item -Path 'C:\Users\cunha\Documents\GitHub\cogniflow-playground\resources\cf_streamfind\src\cf_streamfind\cpp\steps.cpp' -Destination python\cf_streamfind\cpp\
Copy-Item -Path 'C:\Users\cunha\Documents\GitHub\cogniflow-playground\resources\cf_streamfind\src\cf_streamfind\cpp\CMakeLists.txt' -Destination python\cf_streamfind\cpp\
```

Do not copy generated `cf_streamfind_signature_hashes.h` if CMake generates it during build; if copied for reference, remove it before committing.

### 4.3 Copy Python tests

Create Python tests folder under the existing repository `tests/` tree:

```bash
mkdir -p tests/python
```

Copy tests from extracted ZIP:

```bash
cp -r /tmp/cogniflow-playground/resources/cf_streamfind/tests/* tests/python/ || true
```

Or from local checkout (PowerShell):

```powershell
Copy-Item -Path 'C:\Users\cunha\Documents\GitHub\cogniflow-playground\resources\cf_streamfind\tests\*' -Destination tests\python\ -Recurse -ErrorAction SilentlyContinue
```

### 4.4 Copy CMake helper

Create `cmake/` and copy helper file:

```bash
mkdir -p cmake
cp /tmp/cogniflow-playground/resources/cf_streamfind/cmake/Repackaged.cmake cmake/Repackaged.cmake || true
```

Or (PowerShell):

```powershell
Copy-Item -Path 'C:\Users\cunha\Documents\GitHub\cogniflow-playground\resources\cf_streamfind\cmake\Repackaged.cmake' -Destination cmake\ -ErrorAction SilentlyContinue
```

### 4.5 Keep `steps.cpp` as a temporary scaffold in Phase 4

Phase 4 only needs to establish the Python package file layout and preserve the known CogniFlow assets in-repo.

At this checkpoint it is acceptable to copy the existing playground `steps.cpp` as a temporary scaffold so the future Python build has the expected source tree. That is a staging move, not the final architecture.

The architectural cleanup still belongs to a later step:

1. Keep the copied `python/cf_streamfind/cpp/steps.cpp` as a reference implementation during packaging setup.
2. Do not treat its current algorithmic content as final shared-code structure.
3. Refactor it in a later phase so shared logic moves into `src/core/` and `steps.cpp` becomes a thin CogniFlow adapter.

This means the Phase 4 deliverable is a scaffolded package tree, not yet the final bridge implementation.

The target end state remains:

- Keep all heavy algorithm code in `src/core/`.
- Keep only glue/ABI code in `python/cf_streamfind/cpp/steps.cpp`.
- Reuse the same underlying C++ classes/functions the R package uses.

Example future strategy:

1. Expose a small set of pure C++ callable functions from `src/core/`.
2. Keep CogniFlow ABI setup and value marshalling in `python/cf_streamfind/cpp/steps.cpp`.
3. Use `cf_step_tooling.siggen` during CMake builds to generate `cf_streamfind_signature_hashes.h` from `steps.nq`.

Notes:

- Replace playground-local algorithm code in `steps.cpp` incrementally rather than trying to redesign it during the initial file import.
- Keep parsing and serialization in `steps.cpp` minimal once the refactor starts; prefer Python-side helpers for complex parameter composition and let `steps.cpp` accept simple inputs and call core functions.
- The final adapter should map CogniFlow steps to the R package's `Method` implementations now relocated to `src/core/`.

---

### Phase 4 Conclusion

Phase 4 is complete as a packaging scaffold checkpoint.

- `python/cf_streamfind/` now exists with `__init__.py`, `steps.nq`, and `cpp/`.
- `tests/python/` now holds the Python-side tests and fixtures, while the R package keeps its standard `tests/testthat/` layout unchanged.
- `cmake/Repackaged.cmake` has been brought into the repository so the later root CMake build can reference the same helper.
- The current `python/cf_streamfind/cpp/steps.cpp` is intentionally only a temporary imported scaffold from the playground package.

Inspection result:

- Phase 4 has established the expected Python-facing file structure without changing the validated R build arrangement from Phases 2-3.
- The remaining Python work is now packaging and integration work: root `pyproject.toml`, root `CMakeLists.txt`, `MANIFEST.in`, and the later refactor that reduces `steps.cpp` to a thin adapter over `src/core/`.

This means further development should treat Phase 4 as structurally complete, but not as the point where Python/native integration is finished.

---

## Phase 5: Create Root `pyproject.toml`

Create `pyproject.toml` at repository root.

Use this starting content:

```toml
[build-system]
requires = [
  "scikit-build-core>=0.10",
  "cf-package-contracts",
  "cf-step-tooling"
]
build-backend = "scikit_build_core.build"

[project]
name = "cf-streamfind"
version = "0.1.1"
description = "CogniFlow package with processing steps based on the StreamFind native algorithms."
readme = "README.md"
requires-python = ">=3.10"
license = { file = "LICENSE.md" }
authors = [
  { name = "IUTA" }
]
dependencies = []

[project.optional-dependencies]
test = [
  "pytest>=8.0,<9.0"
]

[project.entry-points."cogniflow.steps"]
"cf.streamfind" = "cf_streamfind:steps.nq"

[tool.scikit-build]
minimum-version = "0.10"

[tool.scikit-build.wheel]
packages = ["python/cf_streamfind"]

[tool.scikit-build.experimental]
wheels = true

[tool.setuptools]
package-dir = {"" = "python"}

[tool.setuptools.packages.find]
where = ["python"]

[tool.setuptools.package-data]
cf_streamfind = ["steps.nq", "bin/*"]
```

Important notes:

1. `project.name` must be `cf-streamfind`.
2. The import package remains `cf_streamfind`.
3. `packages = ["python/cf_streamfind"]` tells scikit-build-core where the package is.
4. `package-dir = {"" = "python"}` prevents setuptools from trying to package R folders.
5. Use the actual repository license filename in metadata. In this repository that is currently `LICENSE.md`, not `LICENSE`.

---

### Phase 5 Conclusion

Phase 5 is complete.

- A root `pyproject.toml` now defines the Python package metadata for `cf-streamfind`.
- The build backend is set to `scikit-build-core`, which matches the planned native-build path for the CogniFlow bridge.
- The Python package discovery rules are scoped to `python/cf_streamfind`, so the repository can remain an R package at the root without setuptools attempting to package R-specific folders.
- The `cogniflow.steps` entry point is now declared, pointing `cf.streamfind` at the bundled `steps.nq` document.

Inspection result:

- The Python package metadata layer is now present and consistent with the current repository structure.
- Phase 5 does not yet make the package installable by itself; that still depends on Phase 6 and Phase 7 adding the source-distribution rules and root CMake build entrypoint.

This means the repository now has the required Python project identity, but not yet the full Python build pipeline.

---

## Phase 6: Create Root `MANIFEST.in`

Create `MANIFEST.in` at repository root:

```text
include README.md
include LICENSE.md
include CMakeLists.txt
include pyproject.toml
recursive-include python/cf_streamfind *.py *.nq
recursive-include python/cf_streamfind/cpp *.cpp *.hpp *.h CMakeLists.txt
recursive-include src/core *.cpp *.hpp *.h *.c *.cc *.hh *.ipp
recursive-include cmake *.cmake
exclude python/cf_streamfind/bin/*.dll
exclude python/cf_streamfind/bin/*.so
exclude python/cf_streamfind/bin/*.dylib
prune build
prune dist
prune *.egg-info
```

---

### Phase 6 Conclusion

Phase 6 is complete.

- A root `MANIFEST.in` now defines which non-Python files must ship in the source distribution.
- The manifest includes the Python package files, `src/core/`, and the CMake helper directory, which are all required for later native builds from an sdist.
- Generated binaries and transient build artifacts remain excluded from the distributed source package.

Inspection result:

- The source-distribution rules now match the current repository structure, including the actual root license filename `LICENSE.md`.
- Phase 6 does not yet make the package buildable; it only ensures the future build inputs are present when packaging the source tree.

This means the packaging inputs are now declared, but the root native build entrypoint still needs to be added in Phase 7.

---

## Phase 7: Create Root `CMakeLists.txt` for Python Build

Create or replace root `CMakeLists.txt` with the Python/scikit-build build definition.

### Expected Python build environment

Phase 7 assumes the Python package is built in a normal PEP 517 environment where `pip` creates an isolated build environment from `pyproject.toml`.

Expected flow:

1. `pip install .` or `python -m build` reads `[build-system].requires` from `pyproject.toml`.
2. `pip` installs the Python build-time requirements into an isolated build environment.
3. `scikit-build-core` invokes the root `CMakeLists.txt`.
4. CMake uses the installed CogniFlow helper packages to locate headers and generate the signature header from `steps.nq`.

Expected Python-side build requirements:

- `scikit-build-core`
- `cf-package-contracts`
- `cf-step-tooling`

Expected native/system-side build requirements:

- Python with development headers available to CMake
- CMake 3.20 or newer
- a C++17 compiler
- zlib available to the toolchain if mzML decompression support is needed
- OpenMP available to the toolchain if parallel compilation/linkage should match the R-side build behavior

Expected behavior of the CogniFlow packages:

- `cf-package-contracts` is installed from PyPI and provides the public contract headers, including `cf_step_abi.h`
- `cf-step-tooling` is installed from PyPI and provides `python -m cf_step_tooling.siggen`

At the time of writing, both packages are available from PyPI:

- `cf-package-contracts` on PyPI: released May 8, 2026, install command `pip install cf-package-contracts`
- `cf-step-tooling` on PyPI: released May 8, 2026, install command `pip install cf-step-tooling`

This means the plan can assume a standard pip-resolved build environment rather than a private local dependency bootstrap for these two packages.

Use this as the starting template:

```cmake
cmake_minimum_required(VERSION 3.20)
project(cf_streamfind_steps LANGUAGES CXX)

find_package(Python3 REQUIRED COMPONENTS Interpreter Development)

include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/Repackaged.cmake OPTIONAL RESULT_VARIABLE _skbuild_cmake_repkg)
if(_skbuild_cmake_repkg STREQUAL "_skbuild_cmake_repkg")
  unset(_skbuild_cmake_repkg)
  set(_SKBUILD_REPACKAGED FALSE)
else()
  set(_SKBUILD_REPACKAGED TRUE)
endif()

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# -----------------------------------------------------------------------------
# Locate CogniFlow contract headers
# -----------------------------------------------------------------------------
if(NOT DEFINED CF_CONTRACTS_INCLUDE OR CF_CONTRACTS_INCLUDE STREQUAL "")
  execute_process(
    COMMAND ${Python3_EXECUTABLE} -c "import cf_package_contracts as c; p = getattr(c, 'cf_contracts_include_path', lambda: '')(); print(p if p else '')"
    OUTPUT_VARIABLE _CF_PY_INCLUDE
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET
  )
  if(NOT _CF_PY_INCLUDE STREQUAL "" AND EXISTS "${_CF_PY_INCLUDE}/cf_step_abi.h")
    set(CF_CONTRACTS_INCLUDE "${_CF_PY_INCLUDE}")
  endif()
endif()

if(NOT DEFINED CF_CONTRACTS_INCLUDE OR CF_CONTRACTS_INCLUDE STREQUAL "")
  message(FATAL_ERROR "cf_package_contracts include path not found. Install cf-package-contracts.")
endif()

if(NOT EXISTS "${CF_CONTRACTS_INCLUDE}/cf_step_abi.h")
  message(FATAL_ERROR "cf_step_abi.h not found in '${CF_CONTRACTS_INCLUDE}'")
endif()

# -----------------------------------------------------------------------------
# zlib
# -----------------------------------------------------------------------------
find_package(ZLIB QUIET)
if(ZLIB_FOUND)
  set(CF_STREAMFIND_ZLIB_LIBS ZLIB::ZLIB)
  set(CF_STREAMFIND_HAS_ZLIB TRUE)
else()
  set(CF_STREAMFIND_HAS_ZLIB FALSE)
  message(WARNING "zlib not found; mzML zlib decompression will not be available.")
endif()

# -----------------------------------------------------------------------------
# Generate CogniFlow signature hash header from steps.nq
# -----------------------------------------------------------------------------
set(GENERATED_DIR ${CMAKE_CURRENT_BINARY_DIR}/generated)
file(MAKE_DIRECTORY ${GENERATED_DIR})

set(STEPS_DOCUMENT ${CMAKE_CURRENT_SOURCE_DIR}/python/cf_streamfind/steps.nq)
set(SIG_HEADER ${GENERATED_DIR}/cf_streamfind_signature_hashes.h)

set(CF_SIGGEN_COMMAND ${Python3_EXECUTABLE} -m cf_step_tooling.siggen)
execute_process(
  COMMAND ${Python3_EXECUTABLE} -c
          "import inspect, pathlib, cf_step_tooling.siggen as sig, cf_step_tooling._signatures as impl, cf_step_tooling._step_document as doc, cf_step_tooling._rdf as rdf; print(pathlib.Path(inspect.getsourcefile(sig)).resolve()); print(pathlib.Path(inspect.getsourcefile(impl)).resolve()); print(pathlib.Path(inspect.getsourcefile(doc)).resolve()); print(pathlib.Path(inspect.getsourcefile(rdf)).resolve())"
  OUTPUT_VARIABLE CF_SIGGEN_DEPENDENCY_OUTPUT
  OUTPUT_STRIP_TRAILING_WHITESPACE
)
string(REPLACE "\r\n" "\n" CF_SIGGEN_DEPENDENCY_OUTPUT "${CF_SIGGEN_DEPENDENCY_OUTPUT}")
string(REPLACE "\n" ";" CF_SIGGEN_DEPENDENCIES "${CF_SIGGEN_DEPENDENCY_OUTPUT}")

add_custom_command(
  OUTPUT ${SIG_HEADER}
  COMMAND ${CF_SIGGEN_COMMAND} --steps ${STEPS_DOCUMENT} --out ${SIG_HEADER} --scratch
  DEPENDS ${STEPS_DOCUMENT} ${CF_SIGGEN_DEPENDENCIES}
  COMMENT "Generating cf_streamfind signature hashes"
  VERBATIM
)

# -----------------------------------------------------------------------------
# OpenMP
# -----------------------------------------------------------------------------
find_package(OpenMP QUIET)

# -----------------------------------------------------------------------------
# Shared StreamFind sources
# -----------------------------------------------------------------------------
file(GLOB JSON_SCHEMA_VALIDATOR_SOURCES CONFIGURE_DEPENDS
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core/external/json-schema-validator/src/*.cpp
)
file(GLOB JSON_CORE_SOURCES CONFIGURE_DEPENDS
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core/json_core/*.cpp
)
file(GLOB ASM_SOURCES CONFIGURE_DEPENDS
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core/asm/*.cpp
)
file(GLOB PROJECT_SOURCES CONFIGURE_DEPENDS
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core/project/*.cpp
)
file(GLOB NTA_SOURCES CONFIGURE_DEPENDS
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core/nta/*.cpp
)
file(GLOB MASS_SPEC_SOURCES CONFIGURE_DEPENDS
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core/mass_spec/*.cpp
)

set(STREAMFIND_CORE_SOURCES
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core/external/simdutf_wrapper.cpp
  ${JSON_SCHEMA_VALIDATOR_SOURCES}
  ${JSON_CORE_SOURCES}
  ${ASM_SOURCES}
  ${PROJECT_SOURCES}
  ${NTA_SOURCES}
  ${MASS_SPEC_SOURCES}
)

# -----------------------------------------------------------------------------
# Vendored DuckDB
# -----------------------------------------------------------------------------
if(WIN32)
  set(CF_STREAMFIND_DUCKDB_INCLUDE ${CMAKE_CURRENT_SOURCE_DIR}/src/core/external/duckdb/windows)
  set(CF_STREAMFIND_DUCKDB_LIB ${CMAKE_CURRENT_SOURCE_DIR}/src/core/external/duckdb/windows/duckdb.lib)
elseif(APPLE)
  message(FATAL_ERROR "Vendored DuckDB linkage is not configured for macOS yet.")
else()
  set(CF_STREAMFIND_DUCKDB_INCLUDE ${CMAKE_CURRENT_SOURCE_DIR}/src/core/external/duckdb/linux)
  set(CF_STREAMFIND_DUCKDB_LIB ${CMAKE_CURRENT_SOURCE_DIR}/src/core/external/duckdb/linux/libduckdb_static.a)
endif()

add_library(cf_streamfind_steps SHARED
  ${CMAKE_CURRENT_SOURCE_DIR}/python/cf_streamfind/cpp/steps.cpp
  ${STREAMFIND_CORE_SOURCES}
  ${SIG_HEADER}
)

target_include_directories(cf_streamfind_steps PRIVATE
  ${CF_CONTRACTS_INCLUDE}
  ${GENERATED_DIR}
  ${CMAKE_CURRENT_SOURCE_DIR}/python/cf_streamfind/cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core/asm
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core/external
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core/external/simdutf
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core/external/nlohmann
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core/external/json-schema-validator/src
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core/external/pugixml-1.14/src
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core/json_core
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core/mass_spec
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core/nta
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core/project
  ${CF_STREAMFIND_DUCKDB_INCLUDE}
)

target_link_libraries(cf_streamfind_steps PRIVATE ${CF_STREAMFIND_DUCKDB_LIB})

if(CF_STREAMFIND_HAS_ZLIB)
  target_include_directories(cf_streamfind_steps PRIVATE ${ZLIB_INCLUDE_DIRS})
  target_link_libraries(cf_streamfind_steps PRIVATE ${CF_STREAMFIND_ZLIB_LIBS})
  target_compile_definitions(cf_streamfind_steps PRIVATE CF_STREAMFIND_HAS_ZLIB=1)
endif()

if(OpenMP_CXX_FOUND)
  target_link_libraries(cf_streamfind_steps PRIVATE OpenMP::OpenMP_CXX)
endif()

target_compile_definitions(cf_streamfind_steps PRIVATE
  CF_STEP_ABI_EXPORTS
  _USE_MATH_DEFINES
)

if(WIN32)
  target_compile_definitions(cf_streamfind_steps PRIVATE __USE_MINGW_ANSI_STDIO=1)
endif()

# -----------------------------------------------------------------------------
# Output name and wheel installation
# -----------------------------------------------------------------------------
set_target_properties(cf_streamfind_steps PROPERTIES
  PREFIX ""
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/cf_streamfind/bin"
  LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/cf_streamfind/bin"
  ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/cf_streamfind/bin"
)

if(WIN32)
  set(_CF_STREAMFIND_NATIVE_NAME libcf_streamfind_steps.dll)
elseif(APPLE)
  set(_CF_STREAMFIND_NATIVE_NAME libcf_streamfind_steps.dylib)
else()
  set(_CF_STREAMFIND_NATIVE_NAME libcf_streamfind_steps.so)
endif()

add_custom_command(TARGET cf_streamfind_steps POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_CURRENT_BINARY_DIR}/cf_streamfind/bin
  COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:cf_streamfind_steps> ${CMAKE_CURRENT_BINARY_DIR}/cf_streamfind/bin/${_CF_STREAMFIND_NATIVE_NAME}
)

install(DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/cf_streamfind/bin/
        DESTINATION cf_streamfind/bin
        FILES_MATCHING
        PATTERN "*.dll"
        PATTERN "*.so"
        PATTERN "*.dylib")

install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/python/cf_streamfind/steps.nq
        DESTINATION cf_streamfind)

install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/python/cf_streamfind/__init__.py
        DESTINATION cf_streamfind)

```

Important notes:

1. The root CMake should avoid recursively compiling all of `src/core/external/`, because vendored trees may contain tests, examples, or helper files that are not part of the intended build.
2. The current implementation follows the same source grouping strategy as `src/Makevars` and `src/Makevars.win`, which is safer than a catch-all recursive glob.
3. DuckDB is linked from the vendored library under `src/core/external/duckdb/`, so the Python build does not currently expect a system DuckDB install.
4. The current root CMake explicitly errors on macOS for DuckDB linkage because that vendored path is not configured yet.

---

### Phase 7 Conclusion

Phase 7 is complete as a root native-build entrypoint checkpoint.

- A root `CMakeLists.txt` now exists for the Python/scikit-build build path.
- The build definition resolves CogniFlow contract headers through `cf-package-contracts` and generates the signature header from `steps.nq` using `cf-step-tooling`.
- The shared native sources are selected explicitly in groups that mirror the working R build, instead of recursively compiling the entire vendored tree.
- The build definition also wires in vendored DuckDB, optional zlib support, optional OpenMP linkage, and wheel-install rules for the native library.

Inspection result:

- The repository now has the necessary root build entrypoint for the Python package.
- Phase 7 does not prove the full Python build succeeds yet; that still depends on the local toolchain, pip-installed CogniFlow build dependencies, and later cleanup of the temporary imported `steps.cpp` scaffold.
- macOS is not yet configured for the vendored DuckDB linkage path and remains an explicit gap in the current build definition.

This means the Python build pipeline is now structurally wired from `pyproject.toml` into CMake, but it is not yet the same thing as a validated cross-platform package build.

---

## Phase 8: Update `steps.cpp` to Use Shared Core

Open:

```text
python/cf_streamfind/cpp/steps.cpp
```

Currently, this file may contain standalone duplicated logic such as mzML parsing, base64 decoding, zlib decompression, and algorithm code.

Refactor it so that:

1. CogniFlow ABI setup remains in `steps.cpp`.
2. Actual algorithms are called from `src/core/`.
3. No shared algorithm implementation remains duplicated in `steps.cpp` unless it is a tiny adapter.

Target pattern:

```cpp
#include "cf_step_abi.h"
#include "cf_step_utils.h"
#include "cf_plugin_table.h"
#include "cf_streamfind_signature_hashes.h"

#include "mass_spec/mzml_reader.hpp"
#include "nta/feature_detection.hpp"
#include "project/streamfind_project.hpp"

extern "C" {
  // CogniFlow exported step functions here.
}
```

Do not include Rcpp headers here.

---

### Phase 8 Implementation Direction

For this repository, Phase 8 should now stop using the older demo-style step semantics and move to a `Method`-shaped step contract that mirrors the R-side non-target-analysis workflow.

The first concrete step should be:

- Step name: `sf_nta_find_features`
- Display label: `SF NTA Find Features`
- Input: one JSON project reference containing `db_path` and `project_id`
- Output: the same JSON project reference

This step shape is intentionally simple:

1. CogniFlow passes a JSON project reference into the step.
2. The step binds method parameters from the step parameter set.
3. The step opens the exact StreamFind project identified by `db_path` plus `project_id`.
4. The step calls the shared `ProjectNonTargetAnalysis` core implementation.
5. The step returns the same JSON project reference so later steps can continue operating on the same project.

Recommended project-reference shape:

```json
{
  "db_path": "C:/path/to/project.duckdb",
  "project_id": "my_project_id"
}
```

The parameters should mirror the current R method constructor `Method_NonTargetAnalysis_FindFeatures(...)` and its `run(...)` implementation:

- `rt_windows`
- `ppm_threshold`
- `noise_threshold`
- `min_snr`
- `min_traces`
- `baseline_window`
- `max_width`
- `base_quantile`
- `debug_analysis`
- `debug_mz`
- `debug_spec_idx`

These parameters should be treated as the CogniFlow-side serialization of the existing `FindFeatures` method call rather than as a new algorithm API. In other words, the step contract should follow the R method contract, and the C++ bridge should just translate from CogniFlow values into the shared core call.

### 8.1 Clean `steps.nq` down to the real step contract

Remove the older semantic/demo step descriptions and keep only the plugin/package metadata plus the single `sf_nta_find_features` step definition.

The `steps.nq` document should describe:

- the generated plugin artifact
- the StreamFind step package
- one processing step: `sf_nta_find_features`
- one JSON input port for the project reference
- one JSON output port for the same project reference
- the parameter set listed above

This keeps the generated signature header aligned with the actual first supported StreamFind/CogniFlow integration path instead of the earlier playground scaffolding.

In the current implementation, `steps.nq` should also carry the human-facing help metadata used by CogniFlow tooling:

- `skos:prefLabel`
- `skos:definition`
- `skos:example`
- `skos:scopeNote`
- parameter defaults and value-contract typing

The wording for those fields can be derived from the existing roxygen documentation in `R/class_MethodsNonTargetAnalysis.R`, but the canonical CogniFlow-facing documentation still needs to live in `steps.nq`.

### 8.2 Reduce `steps.cpp` to one thin adapter

`python/cf_streamfind/cpp/steps.cpp` should now hold only one exported step implementation for `sf_nta_find_features`.

That adapter should:

1. Read the JSON project reference from the CogniFlow runtime.
2. Read the `FindFeatures` parameters from the generated signature slots.
3. Parse `rt_windows` from a serialized representation into `rtmin`/`rtmax` vectors.
4. Parse `db_path` and `project_id` from the JSON project reference.
5. Open the StreamFind project using shared `src/core/` classes.
6. Call the shared `nta::PROJECT_NON_TARGET_ANALYSIS::find_features(...)` implementation.
7. Write the same JSON project reference back to the output slot.

No copied mzML parsing logic, base64 logic, or unrelated demo step logic should remain in this file after this phase. The file should only contain:

- CogniFlow ABI helpers
- lightweight parameter decoding
- project opening glue
- the direct call into the shared core method
- the step table for the supported step(s)

### 8.3 Project opening behavior

The current Phase 8 implementation should treat project selection as explicit, not inferred.

The input handle must provide both:

- `db_path`
- `project_id`

This is preferable to a path-only contract because one DuckDB file may contain more than one StreamFind project. The step therefore should not guess which project row to open from the database; it should fail clearly if either field is missing or invalid.

### Phase 8 Conclusion

Phase 8 is complete as the first real core-backed CogniFlow step implementation checkpoint.

- The old playground-style step semantics have been replaced by one StreamFind-native step contract: `sf_nta_find_features`.
- `python/cf_streamfind/steps.nq` now describes only the package metadata and the single `FindFeatures` step instead of carrying the earlier demo semantics.
- The manifest now also contains step, port, and parameter help metadata aligned with the existing R roxygen documentation, so the first CogniFlow step has a real documentation surface rather than only names and defaults.
- `python/cf_streamfind/cpp/steps.cpp` has been reduced to one thin adapter that binds CogniFlow values, parses `projectRef` and `rt_windows`, opens the selected StreamFind project, calls the shared `ProjectNonTargetAnalysis::find_features(...)` core method, and returns the same JSON project handle.

Inspection result:

- The new step contract now mirrors the existing R `Method_NonTargetAnalysis_FindFeatures` parameter model rather than inventing a separate Python-only algorithm shape.
- The first Python/CogniFlow step is intentionally project-oriented: it operates on an existing StreamFind DuckDB project selected by `db_path` plus `project_id`, and preserves that JSON handle for downstream workflow chaining.
- The project-selection contract is now explicit, which aligns better with the core API and avoids ambiguous selection when one DuckDB file stores multiple projects.
- The remaining work after Phase 8 is no longer step-scaffold cleanup; it is build validation, generated-signature validation, packaging validation, and later expansion to additional Method-shaped steps.

Validation note:

- Phase 8 is structurally complete, but it is not yet fully validated end-to-end in the local Python build path.
- In particular, `cf_streamfind_signature_hashes.h` is generated during the CogniFlow/scikit-build flow, so the exact generated symbol names used by `steps.cpp` still need confirmation through a real `cf-step-tooling` run in the build environment.

This means the Python bridge has now crossed from generic scaffold status into the first actual shared-core workflow step, while still keeping the adapter layer narrow and aligned with the R-side method contract.

---

## Phase 9: Update `.Rbuildignore`

The R package build should ignore Python packaging/build artifacts.

Add these lines to `.Rbuildignore`:

```regex
^pyproject\.toml$
^CMakeLists\.txt$
^MANIFEST\.in$
^python$
^python/.*
^tests/python$
^tests/python/.*
^cmake$
^cmake/.*
^build$
^build/.*
^dist$
^dist/.*
^.*\.egg-info$
^.*\.egg-info/.*
```

Do not ignore `src/`, because R still needs it.

---

### Phase 9 Conclusion

Phase 9 is complete.

- `.Rbuildignore` now excludes the Python packaging layer, the root CMake/scikit-build files, `tests/python/`, the helper `cmake/` directory, and common Python build outputs such as `build/`, `dist/`, and `*.egg-info`.
- The ignore rules are intentionally scoped to packaging and build artifacts only; they do not hide `src/`, which the R package still needs for native compilation.

Inspection result:

- The repository can now carry the Python frontend files without causing them to be bundled into the R package source build.
- The Phase 9 change is structural and preventative: it reduces the risk of `R CMD build` or related R package workflows picking up Python/CMake files that are irrelevant to the R package.

This means the repository layout is now better isolated across the R and Python packaging frontends while preserving the shared native source tree for both.

---

## Phase 10: Update `.gitignore`

Add:

```gitignore
# Python build artifacts
/build/
/dist/
/*.egg-info/
*.egg-info/
__pycache__/
*.py[cod]
.pytest_cache/

# Native build artifacts
*.dll
*.so
*.dylib
*.pyd
*.o
*.obj
*.a
*.lib

# Python package runtime native output
python/cf_streamfind/bin/

# CMake
CMakeCache.txt
CMakeFiles/
cmake-build-*/
_skbuild/
```

---

### Phase 10 Conclusion

Phase 10 is complete.

- `.gitignore` now excludes the Python packaging outputs, additional native-build artifacts, the generated runtime library directory `python/cf_streamfind/bin/`, and the CMake/scikit-build working directories.
- The updated ignore rules complement Phase 9: `.Rbuildignore` protects the R package build inputs, while `.gitignore` keeps local build products and generated binaries out of version control.

Inspection result:

- Common Python build directories such as `build/`, `dist/`, `*.egg-info`, `__pycache__/`, and `.pytest_cache/` are now ignored.
- Native outputs and toolchain products such as `.dll`, `.so`, `.dylib`, `.pyd`, `.obj`, `.a`, and `.lib` are now covered consistently.
- The CogniFlow runtime output folder `python/cf_streamfind/bin/` and CMake/scikit-build directories such as `CMakeFiles/`, `CMakeCache.txt`, `cmake-build-*`, and `_skbuild/` are also ignored.

This means the repository is now better protected against accidentally staging Python/native build products while continuing to track the source layout required for both frontends.

---

## Phase 11: Update README Installation Sections

Update `README.Rmd` and regenerate `README.md` if the project uses `README.Rmd` as the source.

Add a section like this:

## Python / CogniFlow package

This repository also contains the Python CogniFlow package `cf-streamfind`.

Install from a local checkout:

```bash
pip install .
```

### Phase 11 Conclusion

Phase 11 is complete.

- `README.Rmd` now includes a dedicated `Python / CogniFlow package` section.
- `README.md` has been updated to match the README source so the checked-in rendered README reflects the same Python/CogniFlow guidance.
- The new section keeps the existing R installation instructions intact while documenting the local `pip install .` workflow and the role of `cf-streamfind` as a Cogniflow step package.

Inspection result:

- The README now presents the repository as a dual-frontend project instead of only an R package.
- The Python section now describes `cf-streamfind` in the way it is actually intended to be consumed: through the Cogniflow framework contracts/runtime path and the `cogniflow.steps` entry-point mechanism, not as a standalone user-facing Python API.
- The section also explains the native build layout briefly by pointing readers to the shared C++ core under `src/core/` and the CogniFlow adapter under `python/cf_streamfind/cpp/`.
- The current README change is intentionally minimal: it documents the local package/install path and framework role without expanding into full validation, CI, or publishing guidance.

This means the user-facing top-level documentation now acknowledges the Python/CogniFlow frontend and the shared-core architecture without disrupting the established R package usage notes.


## Phase 12: Validation Commands

Run these commands after implementation.

### 12.1 Check file layout

```bash
test -f DESCRIPTION
test -f NAMESPACE
test -d R
test -d src/core
test -f pyproject.toml
test -f CMakeLists.txt
test -d python/cf_streamfind
test -f python/cf_streamfind/__init__.py
test -f python/cf_streamfind/steps.nq
test -f python/cf_streamfind/cpp/steps.cpp
```

### 12.2 R development validation

From repository root:

```bash
R -e "devtools::load_all('.')"
```

Minimum acceptable result:

```text
The package compiles and loads successfully in the current R session.
```

At the current checkpoint, there is not yet a dedicated R validation suite for this migration beyond successful `devtools::load_all('.')`. Additional R-side tests can be added later once the Python/CogniFlow integration surface stabilizes.

### 12.3 Python local install

Use a fresh virtual environment:

```bash
python -m venv .venv
. .venv/bin/activate  # Linux/macOS
# .venv\Scripts\activate  # Windows PowerShell
python -m pip install --upgrade pip build
python -m pip install .
```

Expected: the package installation completes successfully in the working-directory virtual environment.

Current checkpoint result:

- A local `.venv` install from the repository root now succeeds with `python -m pip install .`.
- The Python/scikit-build path now compiles against the vendored zlib source under `src/core/external/zlib/zlib-develop`.
- This vendored zlib wiring is intentionally limited to the Python/CMake build path; the R package build continues to use the toolchain zlib provided through RTools / `-lz` in `src/Makevars` and `src/Makevars.win`.

### 12.4 Test status

At the current checkpoint, the existing Python tests should not be treated as valid verification for the new `cf-streamfind` package surface.

- The current `tests/python/` content still reflects earlier scaffolding assumptions and is not yet aligned with the new Method-shaped step contract.
- New Python-side validation should be added later for the `projectRef` input contract, `sf_nta_find_features` step behavior, and package/build integration.
- No dedicated R test suite for this migration checkpoint is available yet either; for now, the practical R-side verification remains successful `devtools::load_all('.')`.

### 12.5 Build wheel and source distribution

```bash
python -m build
```

Expected outputs include something like:

```text
cf_streamfind-0.1.1.tar.gz
cf_streamfind-0.1.1-...whl
```

Note: local `pip install .` now works, but `python -m build` should still be treated as a separate packaging validation step and has not yet replaced the smoke-install checkpoint as the primary Phase 12 success signal.

### 12.6 Test wheel install

```bash
python -m venv .venv-wheel
. .venv-wheel/bin/activate
python -m pip install --upgrade pip
python -m pip install dist/*.whl
```

### Phase 12 Validation Conclusion

Phase 12 should currently be treated as a smoke-validation checkpoint, not a complete automated-test checkpoint.

- The practical R-side verification for now is `devtools::load_all('.')`, because no dedicated R test expansion has been added yet for this migration.
- The practical Python-side verification for now is creating a local `.venv` in the working directory and completing `pip install .`.
- Existing Python tests are not yet expected to work against the revised `cf-streamfind` package contract and should be replaced or rewritten later.

Inspection result:

- The current validation strategy is intentionally narrower than a full release gate: it confirms that the refactored R package still loads and that the Python package now builds and installs successfully through the local virtual-environment path.
- The previous Python build blocker caused by missing `zlib.h` in the scikit-build/MSVC path has been resolved by wiring vendored zlib into the root CMake build without changing the R package toolchain path.
- Proper test coverage for the new Cogniflow step contract, package behavior, wheel contents, and cross-frontend integration remains future work.

This means Phase 12 is currently complete as a local smoke-validation checkpoint:

- `devtools::load_all('.')` succeeds for the R package.
- `python -m pip install .` succeeds in a fresh local `.venv`.
- Dedicated R migration tests and rewritten Python package/step tests are still pending and should be added in a later validation-focused phase.

---

## Phase 13: Optional CI Workflows

Note: Create and enable CI workflows only when explicitly requested. Do not add or activate these workflows automatically as part of the initial migration — wait until local builds, tests, and wheel generation are verified and a manual decision to enable CI has been made.

### 13.1 Python build workflow

Create `.github/workflows/python-build.yml`:

```yaml
name: Python build

on:
  push:
    branches: [dev_filesystem, main, master]
  pull_request:

jobs:
  build:
    runs-on: ${{ matrix.os }}
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, windows-latest]
        python-version: ['3.10', '3.11', '3.12']

    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: ${{ matrix.python-version }}
      - name: Install build tools
        run: |
          python -m pip install --upgrade pip build pytest
      - name: Install package
        run: |
          python -m pip install .
      - name: Import check
        run: |
          python -c "import cf_streamfind; print(cf_streamfind.__file__)"
      - name: Build distributions
        run: |
          python -m build
```

### 13.2 R check workflow

Create `.github/workflows/r-check.yml` if not already present:

```yaml
name: R check

on:
  push:
    branches: [dev_filesystem, main, master]
  pull_request:

jobs:
  r-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: r-lib/actions/setup-r@v2
      - uses: r-lib/actions/setup-r-dependencies@v2
        with:
          extra-packages: any::rcmdcheck
          needs: check
      - uses: r-lib/actions/check-r-package@v2
        with:
          args: 'c("--no-manual")'
```

### 13.3 Future PyPI publishing workflow

Do not enable PyPI publishing until local wheel builds pass reliably on all supported OSes.

Later, create `.github/workflows/publish-pypi.yml` with trusted publishing or an API token.

---

## Phase 14: Commit Checklist

Before committing, run:

```bash
git status --short
```

Ensure no generated binary files are staged:

```bash
git diff --cached --name-only | grep -E '\.(dll|so|dylib|pyd|o|obj|a|lib)$' && echo "ERROR: generated binary staged" || true
```

Expected staged categories:

```text
modified:   src/Makevars
modified:   src/Makevars.win
modified:   .Rbuildignore
modified:   .gitignore
modified:   README.Rmd or README.md
modified:   .ai_plan/streamfind_cf_streamfind_implementation_plan.md
new file:   pyproject.toml
new file:   CMakeLists.txt
new file:   MANIFEST.in
new file:   cmake/Repackaged.cmake
new file:   python/cf_streamfind/...
new file:   tests/python/README.md
new file:   src/core/external/zlib/zlib-develop/...
renamed:    src/<old> -> src/core/<old>
renamed:    src/external/<old> -> src/core/external/<old>
deleted:    vendored upstream extras no longer needed after dependency cleanup
kept:       src/RcppExports.cpp
```

Notes for the current checkpoint:

- `tests/python/` is now intentionally only a placeholder directory with `README.md`; the copied playground scaffold tests and bundled fixtures were removed because they are not valid verification for the current `cf-streamfind` contract.
- `src/core/external/json-schema-validator/` has been reduced to the minimal library sources, headers, `LICENSE`, and `README.md`; upstream tests, CI files, examples, and packaging metadata should appear as deletions from the old vendored tree and should not be restored before commit.
- `src/core/external/zlib/zlib-develop/` is intentionally vendored for the Python/CMake build path only; `src/Makevars` and `src/Makevars.win` should remain on the R toolchain zlib path.
- Review any modified top-level Rcpp bridge file such as `src/rcpp_json_test.cpp` and confirm the change is part of the include-path/layout refactor before staging.

Commit:

```bash
git add .
git commit -m "Add cf-streamfind Python package using shared StreamFind C++ core"
```

### Phase 14 Conclusion

Phase 14 is complete.

- The migration changes have been committed as `799b329` with message `Add Python package and move shared C++ to src/core`.
- The repository worktree is clean after the commit, which means the intended Phase 2-12 changes are now captured in version control.
- The committed scope matches the current architecture: shared native code moved to `src/core/`, the Python/CogniFlow frontend added at the repository root and under `python/cf_streamfind/`, root Python packaging files added, and the R build kept functional through updated `Makevars` files.
- The commit also includes the vendored `zlib` source for the Python/CMake build path, the reduced `json-schema-validator` vendored tree, and the placeholder-only `tests/python/README.md` instead of the earlier scaffold tests.

Inspection result:

- The commit is not just a file move; it also captures the dependency-vendoring decisions needed to make local `pip install .` succeed without relying on RTools for Python users.
- The `json-schema-validator` vendor cleanup is preserved as explicit deletions of upstream extras, which keeps the repository leaner while retaining the library sources and provenance files actually used by StreamFind.
- The current commit still includes vendored DuckDB binary artifacts under `src/core/external/duckdb/`, which is expected and intentional for the present build strategy rather than an accidental generated-build staging issue.
- The validation level represented by this commit remains a local smoke-validation level: `devtools::load_all('.')` and local `.venv` `pip install .` succeeded, while dedicated new R tests and rewritten Python tests remain future work.

This means the migration has now crossed from an in-progress working tree into a recorded repository checkpoint with a clean post-commit state, ready either for follow-up validation work or for any later CI/publishing decisions.

---

## Acceptance Criteria

The implementation is complete when all of these are true:

1. `Rscript -e "rcmdcheck::rcmdcheck(args = c('--no-manual'), error_on = 'error')"` passes with zero errors.
2. `python -m pip install .` succeeds from repository root.
3. `python -c "import cf_streamfind"` succeeds.
4. `python -m build` creates a wheel and source distribution.
5. The wheel contains:

   ```text
   cf_streamfind/__init__.py
   cf_streamfind/steps.nq
   cf_streamfind/bin/<native-library>
   ```

6. The R build does not try to compile CogniFlow adapter files.
7. The Python build does not try to compile Rcpp adapter files.
8. Shared C++ code lives under `src/core/`.
9. R-specific C++ bridge files live in top-level `src/`.
10. Python/CogniFlow-specific C++ code lives under `python/cf_streamfind/cpp/`.

---

## Common Failure Modes and Fixes

### Failure: R build cannot find headers after moving files

Fix `src/Makevars` and `src/Makevars.win` include paths. Prefer:

```make
PKG_CPPFLAGS += -Icore -Icore/mass_spec -Icore/project -Icore/nta -Icore/json_core -Icore/external -Icore/asm -Ir
```

### Failure: R does not compile `.cpp` files under `src/core/`

Use explicit `SOURCES` and `OBJECTS` in `Makevars` and `Makevars.win`.

### Failure: Python build picks up Rcpp files

Check root `CMakeLists.txt`. It should compile:

```text
python/cf_streamfind/cpp/steps.cpp
src/core/**/*.cpp
```

It should not compile:

```text
src/RcppExports.cpp
src/rcpp_*.cpp
```

### Failure: Python wheel does not include `steps.nq`

Check:

```toml
[tool.setuptools.package-data]
cf_streamfind = ["steps.nq", "bin/*"]
```

and the CMake install rule:

```cmake
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/python/cf_streamfind/steps.nq DESTINATION cf_streamfind)
```

### Failure: Native library name is Windows-only

The old package copied only:

```text
libcf_streamfind_steps.dll
```

The new root CMake must support:

```text
libcf_streamfind_steps.dll
libcf_streamfind_steps.so
libcf_streamfind_steps.dylib
```

### Failure: `cf_package_contracts` headers not found

Install build dependencies first:

```bash
python -m pip install cf-package-contracts cf-step-tooling
```

Then retry:

```bash
python -m pip install .
```

---

## Final Architecture Summary

The repository remains `StreamFind` and the R package remains `StreamFind`.

The Python package is added at the same repository root using `pyproject.toml`, but its importable code lives under:

```text
python/cf_streamfind/
```

The native code is split by responsibility:

```text
src/core/                         # shared C++ implementation
src/                              # R/Rcpp adapter files at top level plus src/core shared sources
python/cf_streamfind/cpp/         # Python/CogniFlow adapter
```

This gives one shared C++ engine with two package frontends.
