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
workflow method.

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
