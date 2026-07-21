#!/usr/bin/env Rscript

devtools::load_all()

example_dir <- file.path("dev", "dev_reader", "example_files")
work_dir <- tempfile("angepasst_project_import_")
dir.create(work_dir)

lcd_file <- file.path(work_dir, "260115_ADC_angepasst_lcd.lcd")
txt_file <- file.path(work_dir, "260115_ADC_angepasst_txt.txt")
file.copy(file.path(example_dir, "260115_ADC_angepasst.lcd"), lcd_file, overwrite = TRUE)
file.copy(file.path(example_dir, "260115_ADC_angepasst.txt"), txt_file, overwrite = TRUE)

project <- ProjectMassSpec$new(
  tempfile(fileext = ".duckdb"),
  "angepasst_lcd_txt_check",
  file_paths = c(lcd_file, txt_file)
)

message("Analyses:")
analyses <- project$get_analyses()
print(analyses[, c("analysis", "format", "type", "number_spectra", "number_chromatograms", "start_rt", "end_rt")])

message("\nChromatogram headers:")
headers <- project$get_chromatograms_headers()
header_cols <- intersect(c("analysis", "index", "id", "chromatogram", "array_length", "signal_type", "chromatogram_type", "units", "interval_ms", "start_time", "end_time"), names(headers))
print(headers[, ..header_cols])

message("\nLCD vs TXT chromatogram comparison:")
raw <- project$get_raw_chromatograms()
id_col <- intersect(c("id", "chromatogram_id", "chromatogram", "name"), names(raw))[1]
if (is.na(id_col)) {
  stop("No chromatogram id column found in raw chromatograms. Columns: ", paste(names(raw), collapse = ", "))
}
ids <- intersect(unique(raw[[id_col]][raw$analysis == "260115_ADC_angepasst_lcd"]), unique(raw[[id_col]][raw$analysis == "260115_ADC_angepasst_txt"]))
if (length(ids) == 0L) {
  message("No shared raw chromatogram ids. Raw columns: ", paste(names(raw), collapse = ", "))
  print(unique(raw[, c("analysis", id_col), with = FALSE]))
}
comparisons <- lapply(ids, function(id_value) {
  lcd <- raw[analysis == "260115_ADC_angepasst_lcd" & get(id_col) == id_value][order(rt)]
  txt <- raw[analysis == "260115_ADC_angepasst_txt" & get(id_col) == id_value][order(rt)]
  n <- min(nrow(lcd), nrow(txt))
  data.frame(
    id = id_value,
    n_lcd = nrow(lcd),
    n_txt = nrow(txt),
    rmse = sqrt(mean((lcd$intensity[seq_len(n)] - txt$intensity[seq_len(n)])^2)),
    max_abs = max(abs(lcd$intensity[seq_len(n)] - txt$intensity[seq_len(n)])),
    cor = suppressWarnings(cor(lcd$intensity[seq_len(n)], txt$intensity[seq_len(n)])),
    first_lcd = paste(head(lcd$intensity, 6), collapse = ", "),
    first_txt = paste(head(txt$intensity, 6), collapse = ", "),
    stringsAsFactors = FALSE
  )
})
print(do.call(rbind, comparisons), row.names = FALSE)

message("\ninspect_angepasst_project_import.R completed.")
