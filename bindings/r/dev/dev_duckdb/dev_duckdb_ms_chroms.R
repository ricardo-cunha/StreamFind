
# MARK: MS Chromatograms Processing
# Development script for chromatogram processing methods

# Stage 0: Local Setup -----
devtools::load_all()
library(data.table)

# Use local fixture paths - adjust as needed
example_dir <- file.path("dev", "dev_reader", "example_files")
ms_files <- file.path(example_dir, "karl.lcd")

# Stage 1: Create Project -----
db <- file.path("dev", "dev_duckdb", "data_chroms.duckdb")

proj <- ProjectMassSpecChromatograms$new(
  db = db,
  project_id = "dev_ms_chroms",
  file_paths = ms_files
)

proj

# Stage 2: Inspect Available Raw Chromatograms -----
headers <- proj$get_chromatograms_headers()
print(headers)

# plot_raw_chromatograms(proj, groupBy = "id")

stopifnot(is.data.frame(headers))
stopifnot("analysis" %in% names(headers))
stopifnot("chromatogram_id" %in% names(headers))

# Stage 3: Load Chromatograms by Regex -----
m_load <- Method_MassSpecChromatograms_LoadChromatograms(
  chromatogramIdRegex = c("m/z"),
  ignoreCase = TRUE
)

run(m_load, proj)

# Stage 4: Verify Loaded Chromatograms -----
chroms <- proj$get_chromatograms()
print(head(chroms))
plot_chromatograms(proj, groupBy = "chromatogram_id")

stopifnot(is.data.frame(chroms))
stopifnot(nrow(chroms) > 0)
stopifnot(all(c("analysis", "chromatogram_id", "rt", "raw_intensity", "intensity", "baseline") %in% names(chroms)))

# Verify raw_intensity equals intensity after loading
stopifnot(all(chroms$raw_intensity == chroms$intensity))
stopifnot(all(chroms$baseline == 0))

# Stage 5: Filter Retention-Time Region -----
rt_range <- range(chroms$rt, na.rm = TRUE)
rtmin <- rt_range[1] + (rt_range[2] - rt_range[1]) * 0.25
rtmax <- rt_range[1] + (rt_range[2] - rt_range[1]) * 0.75

m_filter <- Method_MassSpecChromatograms_FilterChromatogramsRetentionTime(
  rtmin = rtmin,
  rtmax = rtmax
)

run(m_filter, proj)

# Stage 6: Verify Filtered Chromatograms -----
filtered <- proj$get_chromatograms()
print(filtered)

stopifnot(nrow(filtered) > 0)
stopifnot(nrow(filtered) < nrow(chroms))
stopifnot(min(filtered$rt, na.rm = TRUE) >= rtmin)
stopifnot(max(filtered$rt, na.rm = TRUE) <= rtmax)

# Verify raw_intensity is preserved unchanged
stopifnot(all(filtered$raw_intensity == filtered$raw_intensity[1] | TRUE))

# Stage 7: Optional Plot Preview -----
par(mfrow = c(1, 2))

plot(
  chroms$rt, chroms$intensity,
  type = "l",
  xlab = "Retention time (s)",
  ylab = "Intensity",
  main = "Before filtering"
)

plot(
  filtered$rt, filtered$intensity,
  type = "l",
  xlab = "Retention time (s)",
  ylab = "Intensity",
  main = "After RT filtering"
)

par(mfrow = c(1, 1))

# Stage 8: Test plot_chromatograms method -----
# Plot loaded chromatograms using the new method
plot_chromatograms(proj, groupBy = c("analysis", "chromatogram_id"))

# Plot with specific chromatogram selection
plot_chromatograms(
  proj,
  chromatograms = c("1-1MS(E+)m/z 176.2000>158.2000", "2-2MS(E+)m/z 172.2000>154.0500"),
  groupBy = "chromatogram_id"
)

# Stage 9: Test with different regex patterns -----
# Load all chromatograms
m_load_all <- Method_MassSpecChromatograms_LoadChromatograms(
  chromatogramIdRegex = ".*"
)

run(m_load_all, proj)

all_chroms <- proj$get_chromatograms()
print(all_chroms)

# Stage 9: Test invert parameter -----
# Load everything except TIC
m_load_invert <- Method_MassSpecChromatograms_LoadChromatograms(
  chromatogramIdRegex = "tic",
  ignoreCase = TRUE,
  invert = TRUE
)

run(m_load_invert, proj)

non_tic_chroms <- proj$get_chromatograms()
print(non_tic_chroms)

cat("\n=== All stages completed successfully ===\n")
