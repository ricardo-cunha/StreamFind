---
name: r-package-native-build
description: Use when compiling C++ or Rcpp code in the streamfind R package, validating native changes, or checking whether the relocated R package loads. Always run devtools::load_all() from bindings/r and never manually edit generated package files.
---

# R Package Native Build

Use this skill for native C++ and Rcpp work in the streamfind R package.

## Package Root

The R package root is:

```text
<repository-root>/bindings/r
```

Run all R package commands with `bindings/r` as the working directory. Do not
treat the repository root as the R package root.

## Required Validation

After native or R changes, load the package with `devtools::load_all()`:

```powershell
Rscript -e "devtools::load_all()"
```

Run that command from `bindings/r`. This is the required package compilation
and load check for this workflow. Do not substitute `R CMD check` for this
routine unless the user explicitly requests a full CRAN-style check.

## Generated Files

Never manually edit generated or compiled package outputs, including:

- `src/RcppExports.cpp`
- `R/RcppExports.R`
- `src/**/*.o`
- `src/**/*.dll`
- generated `man/*.Rd` files

Use the project’s R tooling to regenerate files when generation is explicitly
required. `devtools::load_all()` must be used to compile and load the package;
do not patch generated output to make a build pass.

## Native Change Workflow

1. Identify the package-relative native source under `bindings/r/src/`.
2. Make the smallest source change in the hand-authored C++ or R file.
3. Run `devtools::load_all()` from `bindings/r`.
4. Inspect the first compiler or loader error and fix the owning source.
5. Re-run `devtools::load_all()` until the package loads successfully.
6. Run the narrowest relevant R tests or development fixture after loading.

Keep the existing R package build authority in `bindings/r/src/Makevars` and
`bindings/r/src/Makevars.win` until a later migration phase replaces it with
the standalone core build. Do not move native code to `core/` as part of a
routine compilation check.

## Failure Rules

- Do not delete or rewrite generated exports to bypass an error.
- Do not compile from the repository root.
- Do not introduce a second package root or compatibility copy.
- Do not claim validation passed unless `devtools::load_all()` completed.
