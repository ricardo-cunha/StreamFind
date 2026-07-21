#!/usr/bin/env Rscript

devtools::load_all()

example_dir <- file.path("dev", "dev_reader", "example_files")
lcd_files <- file.path(example_dir, c("260115_ADC.lcd", "karl.lcd"))

inspect_lcd <- function(file) {
  message("\nInspecting: ", file)
  stopifnot(file.exists(file))

  streams <- rcpp_lcd_list_streams(file)
  print(streams)

  candidates <- streams[streams$is_chromatogram_candidate, , drop = FALSE]
  message("Stream count: ", nrow(streams))
  message("Chromatogram/status candidate count: ", nrow(candidates))
  if (nrow(candidates) > 0) {
    print(candidates)
  }

  invisible(streams)
}

invisible(lapply(lcd_files, inspect_lcd))
message("\ninspect_lcd_streams.R completed.")
