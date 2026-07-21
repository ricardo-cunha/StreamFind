#!/usr/bin/env Rscript

devtools::load_all()

example_dir <- file.path("dev", "dev_reader", "example_files")
lcd_files <- file.path(example_dir, c("260115_ADC.lcd", "karl.lcd"))
expected_signature <- as.raw(c(0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1))
expected_message <- "Shimadzu LCD detected, but native LCD chromatogram decoding is not implemented yet. Export to TXT or ASC for now."

file <- lcd_files

check_lcd <- function(file) {
  message("\nChecking: ", file)
  stopifnot(file.exists(file))

  con <- file(file, "rb")
  on.exit(close(con), add = TRUE)
  signature <- readBin(con, what = "raw", n = 8)
  print(signature)
  stopifnot(identical(signature, expected_signature))

  result <- try(
    ProjectMassSpec$new(tempfile(fileext = ".duckdb"), "lcd_signature", file_paths = file),
    silent = TRUE
  )
  stopifnot(inherits(result, "try-error"))
  msg <- conditionMessage(attr(result, "condition"))
  message("Reader message: ", msg)
  stopifnot(identical(msg, expected_message))

  invisible(NULL)
}

invisible(lapply(lcd_files, check_lcd))
message("\ninspect_lcd_signature.R completed.")
