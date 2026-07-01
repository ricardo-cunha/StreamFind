#!/usr/bin/env Rscript

devtools::load_all()

example_dir <- file.path("dev", "dev_reader", "example_files")
karl_txt <- file.path(example_dir, "karl.txt")
karl_mzml <- file.path(example_dir, "karl.mzML")
adc_txt <- file.path("dev/dev_reader/example_files", "260115_ADC.txt")

stopifnot(file.exists(karl_txt), file.exists(karl_mzml))

make_project <- function(file, project_id) {
  ProjectMassSpec$new(tempfile(fileext = ".duckdb"), project_id, file_paths = file)
}

txt <- make_project(karl_txt, "karl_txt_compare")
mzml <- make_project(karl_mzml, "karl_mzml_compare")
acd <- make_project(adc_txt, "karl_mzml_compare")

# plot_raw_chromatograms(txt, groupBy = "id")
plot_raw_chromatograms(mzml, groupBy = "id")

plot_raw_chromatograms(acd, groupBy = "id")


spec <- get_raw_spectra(mzml, mz = 176.2, levels = 2, allTraces = FALSE)
plot(spec$rt[spec$mz > 150], spec$intensity[spec$mz > 150], type = "l")

txt_analysis <- txt$get_analyses()
mzml_analysis <- mzml$get_analyses()
acd_analysis <- acd$get_analyses()

message("\nAnalysis summaries")
print(txt_analysis[, c("analysis", "format", "type", "number_spectra", "number_chromatograms", "start_rt", "end_rt")])
print(mzml_analysis[, c("analysis", "format", "type", "number_spectra", "number_chromatograms", "start_rt", "end_rt")])
print(acd_analysis[, c("analysis", "format", "type", "number_spectra", "number_chromatograms", "start_rt", "end_rt")])

txt_headers <- txt$get_chromatograms_headers()
mzml_headers <- mzml$get_chromatograms_headers()
mzml_spectra_headers <- mzml$get_spectra_headers()

message("\nFirst TXT chromatogram headers")
print(utils::head(txt_headers[, c("index", "id", "array_length", "signal_type", "chromatogram_type", "polarity")], 5))

message("\nFirst mzML chromatogram headers")
print(utils::head(mzml_headers[, c("index", "id", "array_length", "signal_type", "chromatogram_type", "polarity")], 5))

message("\nFirst mzML spectra headers")
print(utils::head(mzml_spectra_headers, 5))

find_tic_index <- function(headers) {
  idx <- which(toupper(headers$chromatogram_type) == "TIC" | grepl("TIC", headers$id, ignore.case = TRUE))
  if (length(idx) == 0) {
    return(headers$index[1])
  }
  headers$index[idx[1]]
}

summarize_chromatogram <- function(project, headers, label) {
  analysis <- project$get_analysis_names()[1]
  index <- find_tic_index(headers)
  raw <- project$get_raw_chromatograms(analyses = analysis, chromatograms = index)
  out <- data.frame(
    source = label,
    index = index,
    rows = nrow(raw),
    rt_min = if (nrow(raw) > 0) min(raw$rt, na.rm = TRUE) else NA_real_,
    rt_max = if (nrow(raw) > 0) max(raw$rt, na.rm = TRUE) else NA_real_,
    intensity_min = if (nrow(raw) > 0) min(raw$intensity, na.rm = TRUE) else NA_real_,
    intensity_max = if (nrow(raw) > 0) max(raw$intensity, na.rm = TRUE) else NA_real_,
    rt_sorted = if (nrow(raw) > 1) all(diff(raw$rt) >= 0) else TRUE
  )
  out
}

message("\nTIC-like trace summaries")
comparison <- rbind(
  summarize_chromatogram(txt, txt_headers, "karl.txt"),
  summarize_chromatogram(mzml, mzml_headers, "karl.mzML")
)
print(comparison)

stopifnot(txt_analysis$format[1] == "ShimadzuTXT")
stopifnot(mzml_analysis$format[1] == "mzML")
stopifnot(txt_analysis$number_chromatograms[1] > 0)
stopifnot(mzml_analysis$number_chromatograms[1] > 0)
stopifnot(all(comparison$rows > 0))
stopifnot(all(comparison$rt_sorted))

message("\ncompare_txt_mzml.R completed.")
