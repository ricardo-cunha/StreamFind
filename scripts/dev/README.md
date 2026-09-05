# Development-stage scripts

These scripts are deliberately outside the official C++ and Rust test suites.
They launch the already-built MCP executables and exercise data-backed parsing,
reader behavior, and NTA workflows through the public interfaces.

## Backends

```powershell
scripts/dev/test-data.ps1 -Backend Cpp
scripts/dev/test-data.ps1 -Backend Rust
scripts/dev/test-nta.ps1 -Backend Cpp
scripts/dev/test-nta.ps1 -Backend Rust
```

Add `-RunPipeline` to `test-nta.ps1` to run the computationally expensive
NTA method instead of only importing the wastewater analyses and discovering the
workflow method. Use `-MaxAnalyses 3` for a fast diagnostic run through all 12
methods; omit it (or use `0`) for the complete wastewater workflow.
Use `-StopAfter mass_spec.find_features` to inspect only feature detection and
its diagnostics without entering the later workflow methods.
Use `-KeepProject` to preserve the temporary DuckDB project file under
`tmp/projects` after the run for offline inspection.

The full diagnostic sequence is:

```text
find_features -> load_features_ms1 -> load_features_ms2 ->
create_components -> annotate_components -> find_internal_standards ->
group_features -> fill_features -> correct_matrix_suppression ->
subtract_blank -> filter_features -> suspect_screening
```

It uses `bindings/r/dev/dev_duckdb/internal_standards_v3.csv` for internal
standard targets and `bindings/r/dev/dev_duckdb/suspects_with_ms2_template.csv`
for suspect-screening targets. Each method prints its elapsed time, returned
result, and a follow-up result-table row count.

## External data

Generic mzML/NTA data is resolved from the sibling repository:

```text
<parent-directory>/streamfind.data/data
```

Override it with:

```text
$env:STREAMFIND_EXAMPLE_DATA_ROOT = '<path-to-data>'
```

Vendor readers use the development fixture root:

```text
E:\example_files\raw_vendor_files
```

Override it with:

```text
$env:STREAMFIND_VENDOR_DATA_ROOT = '<path-to-raw-vendor-files>'
```

Run a specific vendor parser check with:

```powershell
scripts/dev/test-vendor-readers.ps1 -Backend Cpp -Vendor Shimadzu
scripts/dev/test-vendor-readers.ps1 -Backend Rust -Vendor Shimadzu
```

Supported vendor selectors are `Shimadzu`, `Sciex`, `AgilentChemstation`,
`AgilentMassHunter`, and `Thermo`. Use `-InputPath` to select a particular
fixture instead of the default representative file.
