#!/usr/bin/env Rscript

devtools::load_all()

example_dir <- file.path("dev", "dev_reader", "example_files")
files <- file.path(example_dir, c(
  "260115_ADC.txt",
  "260115_ADC.lcd",
  "karl.txt",
  "karl.lcd",
  "karl.mzML"
))

expected_lcd_message <- "Shimadzu LCD detected, but native LCD chromatogram decoding is not implemented yet. Export to TXT or ASC for now."

print_preview <- function(x, n = 6) {
  if (is.null(x) || nrow(x) == 0) {
    print(x)
    return(invisible(NULL))
  }
  print(utils::head(x, n))
}

inspect_file <- function(file) {
  message("\nReading: ", file)
  stopifnot(file.exists(file))

  db <- tempfile(fileext = ".duckdb")
  result <- try(
    ProjectMassSpec$new(db, "reader_inspect", file_paths = file),
    silent = TRUE
  )

  if (inherits(result, "try-error")) {
    msg <- conditionMessage(attr(result, "condition"))
    message("Error: ", msg)
    if (tolower(tools::file_ext(file)) == "lcd") {
      stopifnot(identical(msg, expected_lcd_message))
      message("LCD unsupported-native-decoding message matched.")
      return(invisible(NULL))
    }
    stop(result)
  }

  analyses <- result$get_analyses()
  print_preview(analyses[, c(
    "analysis", "format", "type", "number_spectra", "number_chromatograms",
    "start_rt", "end_rt"
  )])

  headers <- result$get_chromatograms_headers()
  if (nrow(headers) > 0) {
    print_preview(headers[, c(
      "analysis", "index", "id", "array_length", "signal_type",
      "chromatogram_type", "detector", "channel", "units", "polarity",
      "pre_mz", "pro_mz", "start_time", "end_time", "intensity_multiplier"
    )])

    analysis <- result$get_analysis_names()[1]
    raw <- result$get_raw_chromatograms(analyses = analysis, chromatograms = headers$index[1])
    message("First chromatogram rows: ", nrow(raw))
    print_preview(raw[, c("analysis", "index", "id", "rt", "intensity")])
  }

  invisible(NULL)
}

invisible(lapply(files, inspect_file))
message("\ninspect_reader.R completed.")
