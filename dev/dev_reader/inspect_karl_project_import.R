#!/usr/bin/env Rscript

devtools::load_all()

example_dir <- file.path("dev", "dev_reader", "example_files")
work_dir <- tempfile("karl_project_import_")
dir.create(work_dir)

lcd_file <- file.path(work_dir, "karl_lcd.lcd")
mzml_file <- file.path(work_dir, "karl_mzml.mzML")
txt_file <- file.path(work_dir, "karl_txt.txt")
file.copy(file.path(example_dir, "karl.lcd"), lcd_file, overwrite = TRUE)
file.copy(file.path(example_dir, "karl.mzML"), mzml_file, overwrite = TRUE)
file.copy(file.path(example_dir, "karl.txt"), txt_file, overwrite = TRUE)

project <- ProjectMassSpec$new(
  tempfile(fileext = ".duckdb"),
  "karl_lcd_mzml_representation_check",
  file_paths = c(lcd_file, mzml_file, txt_file)
)

message("Analyses:")
analyses <- project$get_analyses()
print(analyses[, c("analysis", "format", "type", "number_spectra", "number_chromatograms", "start_rt", "end_rt")])

message("\nChromatogram headers:")
chrom_headers <- project$get_chromatograms_headers()
chrom_id_col <- intersect(c("id", "chromatogram_id", "chromatogram", "name"), names(chrom_headers))[1]
if (nrow(chrom_headers) > 0L && is.na(chrom_id_col)) {
  stop("No chromatogram id column found. Columns: ", paste(names(chrom_headers), collapse = ", "))
}
if (nrow(chrom_headers) == 0L) {
  message("No chromatogram headers.")
} else {
  chrom_cols <- intersect(c("analysis", "index", chrom_id_col, "array_length", "signal_type", "chromatogram_type", "units", "polarity", "pre_mz", "pre_ce", "pro_mz", "interval_ms", "start_time", "end_time"), names(chrom_headers))
  print(chrom_headers[, chrom_cols, with = FALSE])
}

message("\nLCD vs TXT status trace comparison:")
raw_chrom <- project$get_raw_chromatograms()
status_ids <- intersect(
  unique(chrom_headers[[chrom_id_col]][chrom_headers$analysis == "karl_lcd" & chrom_headers$signal_type == "LC Status"]),
  unique(chrom_headers[[chrom_id_col]][chrom_headers$analysis == "karl_txt" & chrom_headers$signal_type == "LC Status"])
)
if (length(status_ids) == 0L) {
  message("No shared LCD/TXT status ids.")
} else {
  comparisons <- lapply(status_ids, function(status_id) {
    raw_id_col <- intersect(c("id", "chromatogram_id", "chromatogram", "name"), names(raw_chrom))[1]
    lcd <- raw_chrom[analysis == "karl_lcd" & get(raw_id_col) == status_id][order(rt)]
    txt <- raw_chrom[analysis == "karl_txt" & get(raw_id_col) == status_id][order(rt)]
    n <- min(nrow(lcd), nrow(txt))
    data.frame(
      id = status_id,
      n_lcd = nrow(lcd),
      n_txt = nrow(txt),
      rmse = sqrt(mean((lcd$intensity[seq_len(n)] - txt$intensity[seq_len(n)])^2)),
      max_abs = max(abs(lcd$intensity[seq_len(n)] - txt$intensity[seq_len(n)])),
      first_lcd = paste(head(lcd$intensity, 5), collapse = ", "),
      first_txt = paste(head(txt$intensity, 5), collapse = ", "),
      stringsAsFactors = FALSE
    )
  })
  print(do.call(rbind, comparisons), row.names = FALSE)
}

message("\nFirst LCD-derived MS chromatograms:")
  lcd_ms_chrom <- chrom_headers[analysis == "karl_lcd" & signal_type == "MS"]
if (nrow(lcd_ms_chrom) == 0L) {
  message("No LCD-derived MS chromatograms.")
} else {
  lcd_ms_cols <- intersect(c("index", chrom_id_col, "array_length", "chromatogram_type", "polarity", "precursor_mz", "pre_mz", "activation_ce", "pre_ce", "product_mz", "pro_mz", "channel"), names(lcd_ms_chrom))
  print(head(lcd_ms_chrom[, ..lcd_ms_cols], 12))

  txt_ms_chrom <- chrom_headers[analysis == "karl_txt" & signal_type == "MS"]
  lcd_tic_ids <- sort(lcd_ms_chrom$chromatogram_id[lcd_ms_chrom$chromatogram_type == "TIC"])
  txt_tic_ids <- sort(txt_ms_chrom$chromatogram_id[txt_ms_chrom$chromatogram_type == "TIC"])
  lcd_mrm_ids <- sort(lcd_ms_chrom$chromatogram_id[lcd_ms_chrom$chromatogram_type == "MRM"])
  txt_mrm_ids <- sort(txt_ms_chrom$chromatogram_id[!is.na(txt_ms_chrom$pre_mz) & !is.na(txt_ms_chrom$pro_mz)])
  txt_bpc_expected <- sort(sub("m/z MIC1$", " BPC", txt_ms_chrom$chromatogram_id[grepl("m/z MIC1$", txt_ms_chrom$chromatogram_id)]))
  lcd_bpc_ids <- sort(lcd_ms_chrom$chromatogram_id[lcd_ms_chrom$chromatogram_type == "BPC"])
  same_tic <- setequal(lcd_tic_ids, txt_tic_ids)
  same_bpc <- setequal(lcd_bpc_ids, txt_bpc_expected)
  same_mrm <- setequal(lcd_mrm_ids, txt_mrm_ids)
  message("\nLCD/TXT MS id parity:")
  print(data.frame(
    class = c("TIC", "BPC", "MRM"),
    lcd = c(length(lcd_tic_ids), length(lcd_bpc_ids), length(lcd_mrm_ids)),
    txt_reference = c(length(txt_tic_ids), length(txt_bpc_expected), length(txt_mrm_ids)),
    exact_ids = c(same_tic, same_bpc, same_mrm)
  ), row.names = FALSE)
  if (!same_tic) print(data.frame(missing_from_lcd = setdiff(txt_tic_ids, lcd_tic_ids), extra_in_lcd = setdiff(lcd_tic_ids, txt_tic_ids)))
  if (!same_bpc) print(data.frame(missing_from_lcd = setdiff(txt_bpc_expected, lcd_bpc_ids), extra_in_lcd = setdiff(lcd_bpc_ids, txt_bpc_expected)))
  if (!same_mrm) print(data.frame(missing_from_lcd = setdiff(txt_mrm_ids, lcd_mrm_ids), extra_in_lcd = setdiff(lcd_mrm_ids, txt_mrm_ids)))
  stopifnot(same_tic, same_bpc, same_mrm)
}

message("\nSpectra headers summary:")
spectra_headers <- project$get_spectra_headers()
if (nrow(spectra_headers) == 0L) {
  message("No spectra headers.")
} else {
  print(spectra_headers[, .(
    spectra = .N,
    rt_min = min(rt, na.rm = TRUE),
    rt_max = max(rt, na.rm = TRUE),
    level_min = min(level, na.rm = TRUE),
    level_max = max(level, na.rm = TRUE),
    polarity = paste(sort(unique(polarity)), collapse = ", "),
    array_length_min = min(array_length, na.rm = TRUE),
    array_length_max = max(array_length, na.rm = TRUE),
    tic_min = min(tic, na.rm = TRUE),
    tic_max = max(tic, na.rm = TRUE)
  ), by = analysis])
  message("\nFirst spectra headers:")
  columns <- intersect(
    c("analysis", "index", "scan", "array_length", "level", "polarity", "rt", "lowmz", "highmz", "tic", "precursor_mz", "pre_ce", "activation_ce", "product_mz"),
    names(spectra_headers)
  )
  print(head(spectra_headers[, ..columns], 20))

  lcd_headers <- spectra_headers[analysis == "karl_lcd"][order(index)]
  mzml_headers <- spectra_headers[analysis == "karl_mzml"][order(index)]
  if (nrow(lcd_headers) == nrow(mzml_headers)) {
    message("\nLCD/mzML spectra metadata parity:")
    parity <- data.frame(
      field = c("polarity", "rt", "lowmz", "highmz", "tic"),
      exact_or_close = c(
        identical(lcd_headers$polarity, mzml_headers$polarity),
        max(abs(lcd_headers$rt - mzml_headers$rt), na.rm = TRUE) < 1e-6,
        max(abs(lcd_headers$lowmz - mzml_headers$lowmz), na.rm = TRUE) < 1e-6,
        max(abs(lcd_headers$highmz - mzml_headers$highmz), na.rm = TRUE) < 1e-6,
        max(abs(lcd_headers$tic - mzml_headers$tic), na.rm = TRUE) <= 4
      ),
      max_abs = c(
        max(abs(lcd_headers$polarity - mzml_headers$polarity), na.rm = TRUE),
        max(abs(lcd_headers$rt - mzml_headers$rt), na.rm = TRUE),
        max(abs(lcd_headers$lowmz - mzml_headers$lowmz), na.rm = TRUE),
        max(abs(lcd_headers$highmz - mzml_headers$highmz), na.rm = TRUE),
        max(abs(lcd_headers$tic - mzml_headers$tic), na.rm = TRUE)
      )
    )
    print(parity, row.names = FALSE)
    stopifnot(all(parity$exact_or_close))
  }
  if ("pre_ce" %in% names(lcd_headers)) {
    message("\nLCD spectra collision energies:")
    print(lcd_headers[, .(n = .N), by = pre_ce][order(pre_ce)])
    stopifnot(identical(sort(unique(lcd_headers$pre_ce)), 30))
  }

  first_negative <- mzml_headers[polarity < 0, index][1]
  if (!is.na(first_negative)) {
    message("\nPolarity transition around first mzML negative spectrum:")
    window <- seq(max(0L, first_negative - 3L), min(max(mzml_headers$index), first_negative + 3L))
    print(spectra_headers[analysis %in% c("karl_lcd", "karl_mzml") & index %in% window][order(index, analysis), ..columns])

    message("\nUnique mzML m/z pairs by polarity:")
    print(mzml_headers[, .(n = .N), by = .(polarity, lowmz, highmz)][order(polarity, lowmz, highmz)])
  }
}

message("\ninspect_karl_project_import.R completed.")
