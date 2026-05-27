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
├─ src/cf_streamfind/data/test_data.mzML
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
│  ├─ r/                               # R/Rcpp bridge only
│  │  ├─ RcppExports.cpp
│  │  ├─ rcpp_asm_read_test.cpp
│  │  ├─ rcpp_duckdb_test.cpp
│  │  ├─ rcpp_json_schema_validation_test.cpp
│  │  ├─ rcpp_json_test.cpp
│  │  ├─ rcpp_project_export.cpp
│  │  └─ rcpp_project_nta_export.cpp
│  │
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
│     └─ data/
│        └─ test_data.mzML             # optional test/demo data
│
├─ tests-py/                           # Python tests copied from resources/cf_streamfind/tests
│  ├─ test_gcms_steps.py
│  ├─ test_gcms_datahive_integration.py
│  ├─ test_gcms_pipeline_engine_runtime.py
│  ├─ test_gcms_pipeline_manager_runtime.py
│  └─ fixtures/
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
6. Put R-only Rcpp bridge code under `src/r/`.
7. The shared C++ code must not include Python, CogniFlow, Rcpp, or R headers.
8. The R bridge may include Rcpp headers.
9. The CogniFlow bridge may include CogniFlow ABI headers.
10. Do not commit generated binaries such as `.dll`, `.so`, `.dylib`, `.pyd`, `build/`, `dist/`, or `*.egg-info`.

---

## Phase 1: (skipped)

This plan assumes the working branch `dev_filesystem` is already up-to-date and ready for implementation. Creating a separate safety branch is not required for this session — proceed directly with Phase 2.

---

## Phase 2: Move Native Source into Shared and R-Specific Areas

### 2.1 Create target folders

```bash
mkdir -p src/core
mkdir -p src/r
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

1. Leave or move the Rcpp-specific file to `src/r/`.
2. Move only reusable pure C++ files to `src/core/`.
3. Update includes accordingly.

### 2.3 Move Rcpp bridge files

Move root-level Rcpp bridge files into `src/r/`:

```bash
git mv src/RcppExports.cpp src/r/RcppExports.cpp
git mv src/rcpp_asm_read_test.cpp src/r/rcpp_asm_read_test.cpp
git mv src/rcpp_duckdb_test.cpp src/r/rcpp_duckdb_test.cpp
git mv src/rcpp_json_schema_validation_test.cpp src/r/rcpp_json_schema_validation_test.cpp
git mv src/rcpp_json_test.cpp src/r/rcpp_json_test.cpp
git mv src/rcpp_project_export.cpp src/r/rcpp_project_export.cpp
git mv src/rcpp_project_nta_export.cpp src/r/rcpp_project_nta_export.cpp
```

### 2.4 Update include paths in C++ files

Search for local includes:

```bash
grep -R "#include \"" -n src/core src/r | tee /tmp/streamfind_includes.txt
```

Update include statements so that files in `src/r/` can include shared headers from `src/core/`.

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

## Phase 3: Update R Build Files

Open `src/Makevars` and `src/Makevars.win`.

### 3.1 Add include directories

Ensure both files include at least:

```make
PKG_CPPFLAGS += -Icore -Icore/asm -Icore/external -Icore/json_core -Icore/mass_spec -Icore/nta -Icore/project
```

If files in `src/r/` include headers from `src/r/`, also add:

```make
PKG_CPPFLAGS += -Ir
```

### 3.2 Ensure R compiles files in subdirectories

R package compilation from `src/` does not always recursively compile arbitrary subdirectories without help.

Use an explicit object list if needed.

Example pattern:

```make
SOURCES = \
  r/RcppExports.cpp \
  r/rcpp_asm_read_test.cpp \
  r/rcpp_duckdb_test.cpp \
  r/rcpp_json_schema_validation_test.cpp \
  r/rcpp_json_test.cpp \
  r/rcpp_project_export.cpp \
  r/rcpp_project_nta_export.cpp \
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

## Phase 4: Add Python Package Files at Repository Root

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
mkdir -p python/cf_streamfind python/cf_streamfind/data
cp /mnt/c/Users/cunha/Documents/GitHub/cogniflow-playground/resources/cf_streamfind/src/cf_streamfind/__init__.py python/cf_streamfind/__init__.py
cp /mnt/c/Users/cunha/Documents/GitHub/cogniflow-playground/resources/cf_streamfind/src/cf_streamfind/steps.nq python/cf_streamfind/steps.nq
cp -r /mnt/c/Users/cunha/Documents/GitHub/cogniflow-playground/resources/cf_streamfind/src/cf_streamfind/data/* python/cf_streamfind/data/ || true
```

Fallback: if the local checkout is missing, extract the ZIP and copy from the extracted tree (POSIX example):

```bash
unzip .ai_plan/cogniflow-playground-20260527-122156.zip -d /tmp/cogniflow-playground
cp /tmp/cogniflow-playground/resources/cf_streamfind/src/cf_streamfind/__init__.py python/cf_streamfind/__init__.py
cp /tmp/cogniflow-playground/resources/cf_streamfind/src/cf_streamfind/steps.nq python/cf_streamfind/steps.nq
mkdir -p python/cf_streamfind/data
cp -r /tmp/cogniflow-playground/resources/cf_streamfind/src/cf_streamfind/data/* python/cf_streamfind/data/ 2>/dev/null || true
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

Create tests folder:

```bash
mkdir -p tests-py
```

Copy tests from extracted ZIP:

```bash
cp -r /tmp/cogniflow-playground/resources/cf_streamfind/tests/* tests-py/ || true
```

Or from local checkout (PowerShell):

```powershell
Copy-Item -Path 'C:\Users\cunha\Documents\GitHub\cogniflow-playground\resources\cf_streamfind\tests\*' -Destination tests-py\ -Recurse -ErrorAction SilentlyContinue
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

### 4.5 Implement simple CogniFlow steps that call `src/core` methods

Rather than copying a fully-featured `steps.cpp` implementation, add a minimal, easy-to-tune adapter that mirrors the `Method` child functions already implemented in `StreamFind` and will call the corresponding C++ functions exposed from `src/core`.

Goals:

- Provide an immediately usable adapter that exposes a small set of steps (one per high-level Method) to CogniFlow.
- Keep all heavy algorithm code in `src/core/` and only implement glue/ABI code in `python/cf_streamfind/cpp/steps.cpp`.
- Keep the Python `cf_streamfind` package lightweight: include `steps.nq` and a tiny `__init__.py` that exposes metadata.

Suggested files and minimal templates (copy into `python/cf_streamfind/` and `python/cf_streamfind/cpp/`):

`python/cf_streamfind/__init__.py` (simple exposure and helper):

```python
__all__ = ["steps_nq_path"]
import importlib.resources as pkg_resources
from pathlib import Path

def steps_nq_path():
    # returns path to bundled steps document
    return Path(pkg_resources.files(__package__) / "steps.nq")

```

`python/cf_streamfind/steps.nq` (minimal example describing two steps)

```nq
@prefix cf: <http://cogniflow.org/schema#> .

<cf.streamfind.find_features> a cf:Step ;
  cf:label "StreamFind: Find Features" ;
  cf:entryPoint "cf.streamfind:run_find_features" .

<cf.streamfind.group_features> a cf:Step ;
  cf:label "StreamFind: Group Features" ;
  cf:entryPoint "cf.streamfind:run_group_features" .
```

`python/cf_streamfind/cpp/steps.cpp` (minimal C++ CogniFlow ABI adapter)

```cpp
#include "cf_step_abi.h"
#include "cf_step_utils.h"
#include "cf_plugin_table.h"
#include "cf_streamfind_signature_hashes.h"

// Include shared core headers
#include "project/streamfind_core_api.hpp" // example header in src/core/project

extern "C" {

CF_EXPORT cf_status_t cf_step_init(cf_step_context_t* ctx) {
  // Initialize any global state if needed
  return CF_SUCCESS;
}

CF_EXPORT cf_status_t cf_step_run(cf_step_context_t* ctx) {
  // Example pattern:
  // 1. parse inputs from ctx
  // 2. call into src/core functions (thin wrappers)
  // 3. set outputs on ctx

  // Pseudo-code: replace with real argument parsing and calls
  try {
    // parse inputs (use cf_step_utils helpers)
    // e.g. cf_string_t csv_path = cf_step_input_get_string(ctx, "input_path");

    // call into shared core API
    // int rc = streamfind::run_find_features("input_path", "output_path");

    // set outputs on ctx
    // cf_step_output_set_string(ctx, "result", "ok");
    (void)ctx;
    return CF_SUCCESS;
  } catch(...) {
    return CF_FAILURE;
  }
}

CF_EXPORT void cf_step_shutdown() {
  // cleanup if needed
}

} // extern "C"
```

Notes:

- Replace `project/streamfind_core_api.hpp` and the example function names with the real headers and function names exported from `src/core/` once those are available.
- Keep parsing/serialization in `steps.cpp` minimal; prefer to have Python-side helpers for complex parameter composition and let `steps.cpp` accept simple inputs (file paths, serialized JSON) and call core functions.
- Use `cf_step_tooling.siggen` (invoked by CMake during build) to generate the `cf_streamfind_signature_hashes.h` file from `steps.nq` so signatures stay in sync.

This minimal adapter gives you a working scaffold that maps CogniFlow steps to the R package's `Method` implementations now relocated to `src/core/`. Tweak the exact step names and core function calls as you complete the `src/core` refactor.
```

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
license = { file = "LICENSE" }
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
cf_streamfind = ["steps.nq", "bin/*", "data/*"]
```

Important notes:

1. `project.name` must be `cf-streamfind`.
2. The import package remains `cf_streamfind`.
3. `packages = ["python/cf_streamfind"]` tells scikit-build-core where the package is.
4. `package-dir = {"" = "python"}` prevents setuptools from trying to package R folders.

---

## Phase 6: Create Root `MANIFEST.in`

Create `MANIFEST.in` at repository root:

```text
include README.md
include LICENSE
include CMakeLists.txt
include pyproject.toml
recursive-include python/cf_streamfind *.py *.nq
recursive-include python/cf_streamfind/data *
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

## Phase 7: Create Root `CMakeLists.txt` for Python Build

Create or replace root `CMakeLists.txt` with the Python/scikit-build build definition.

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
# Shared StreamFind core sources
# -----------------------------------------------------------------------------
# Replace this glob with an explicit list after the first successful build.
file(GLOB_RECURSE STREAMFIND_CORE_SOURCES CONFIGURE_DEPENDS
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core/*.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core/*.cc
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core/*.cxx
)

# If any files in src/core are R-only or test-only, remove them here.
# Example:
# list(FILTER STREAMFIND_CORE_SOURCES EXCLUDE REGEX ".*/rcpp_.*\\.cpp$")

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
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core/json_core
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core/mass_spec
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core/nta
  ${CMAKE_CURRENT_SOURCE_DIR}/src/core/project
)

if(CF_STREAMFIND_HAS_ZLIB)
  target_include_directories(cf_streamfind_steps PRIVATE ${ZLIB_INCLUDE_DIRS})
  target_link_libraries(cf_streamfind_steps PRIVATE ${CF_STREAMFIND_ZLIB_LIBS})
  target_compile_definitions(cf_streamfind_steps PRIVATE CF_STREAMFIND_HAS_ZLIB=1)
endif()

target_compile_definitions(cf_streamfind_steps PRIVATE
  CF_STEP_ABI_EXPORTS
  _USE_MATH_DEFINES
)

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

install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/python/cf_streamfind/data/
        DESTINATION cf_streamfind/data
        FILES_MATCHING PATTERN "*")
```

Important: the first build may fail if `file(GLOB_RECURSE STREAMFIND_CORE_SOURCES ...)` picks up files that are not truly shared. If that happens, replace the glob with an explicit list of valid core `.cpp` files.

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

## Phase 9: Update `.Rbuildignore`

The R package build should ignore Python packaging/build artifacts.

Add these lines to `.Rbuildignore`:

```regex
^pyproject\.toml$
^CMakeLists\.txt$
^MANIFEST\.in$
^python$
^python/.*
^tests-py$
^tests-py/.*
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

## Phase 11: Update README Installation Sections

Update `README.Rmd` and regenerate `README.md` if the project uses `README.Rmd` as the source.

Add a section like this:

```markdown
## Python / CogniFlow package

This repository also contains the Python CogniFlow package `cf-streamfind`.

Install from a local checkout:

```bash
pip install .
```

Install from GitHub:

```bash
pip install "git+https://github.com/odea-project/StreamFind.git@dev_filesystem"
```

Import in Python:

```python
import cf_streamfind
```

The Python package builds the CogniFlow native step library from the shared StreamFind C++ core under `src/core/` and the CogniFlow adapter under `python/cf_streamfind/cpp/`.
```

Keep the existing R installation instructions intact.

---

## Phase 12: Validation Commands

Run these commands after implementation.

### 12.1 Check file layout

```bash
test -f DESCRIPTION
test -f NAMESPACE
test -d R
test -d src/core
test -d src/r
test -f pyproject.toml
test -f CMakeLists.txt
test -d python/cf_streamfind
test -f python/cf_streamfind/__init__.py
test -f python/cf_streamfind/steps.nq
test -f python/cf_streamfind/cpp/steps.cpp
```

### 12.2 R package check

From repository root:

```bash
Rscript -e "install.packages(c('remotes', 'rcmdcheck'), repos='https://cloud.r-project.org')"
Rscript -e "rcmdcheck::rcmdcheck(args = c('--no-manual'), error_on = 'error')"
```

Minimum acceptable result:

```text
0 errors
```

Warnings and notes should be reviewed, but do not block the first structural PR unless they are caused by this migration.

### 12.3 Python local install

Use a fresh virtual environment:

```bash
python -m venv .venv
. .venv/bin/activate  # Linux/macOS
# .venv\Scripts\activate  # Windows PowerShell
python -m pip install --upgrade pip build pytest
python -m pip install .
python -c "import cf_streamfind; print(cf_streamfind.__file__)"
```

Expected: the import succeeds and prints a path inside the environment's site-packages.

### 12.4 Python tests

```bash
python -m pip install '.[test]'
python -m pytest tests-py
```

If CogniFlow runtime integration tests require unavailable services, mark those tests with `pytest.mark.integration` and exclude by default:

```bash
python -m pytest tests-py -m "not integration"
```

### 12.5 Build wheel and source distribution

```bash
python -m build
ls dist/
```

Expected outputs include something like:

```text
cf_streamfind-0.1.1.tar.gz
cf_streamfind-0.1.1-...whl
```

### 12.6 Test wheel install

```bash
python -m venv .venv-wheel
. .venv-wheel/bin/activate
python -m pip install --upgrade pip
python -m pip install dist/*.whl
python -c "import cf_streamfind; print(cf_streamfind.__file__)"
```

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
new file:   pyproject.toml
new file:   CMakeLists.txt
new file:   MANIFEST.in
new file:   python/cf_streamfind/...
new file:   tests-py/...
renamed:    src/<old> -> src/core/<old>
renamed:    src/RcppExports.cpp -> src/r/RcppExports.cpp
```

Commit:

```bash
git add .
git commit -m "Add cf-streamfind Python package using shared StreamFind C++ core"
```

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
9. R-specific C++ code lives under `src/r/`.
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
src/r/*.cpp
```

### Failure: Python wheel does not include `steps.nq`

Check:

```toml
[tool.setuptools.package-data]
cf_streamfind = ["steps.nq", "bin/*", "data/*"]
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
src/r/                            # R/Rcpp adapter
python/cf_streamfind/cpp/         # Python/CogniFlow adapter
```

This gives one shared C++ engine with two package frontends.
