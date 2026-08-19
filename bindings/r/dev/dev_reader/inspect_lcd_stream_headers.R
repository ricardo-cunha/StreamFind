#!/usr/bin/env Rscript

devtools::load_all()

example_dir <- file.path("dev", "dev_reader", "example_files")
lcd_file <- file.path(example_dir, "260115_ADC.lcd")

format_hex_line <- function(hex, width = 16) {
  if (length(hex) == 0) {
    return(character())
  }
  starts <- seq(1, length(hex), by = width)
  vapply(starts, function(start) {
    end <- min(start + width - 1, length(hex))
    sprintf("%04X: %s", start - 1, paste(hex[start:end], collapse = " "))
  }, character(1))
}

inspect_stream <- function(file, stream_path, max_bytes = 128) {
  message("\nStream: ", stream_path)
  bytes <- rcpp_lcd_inspect_stream(file, stream_path, max_bytes = max_bytes)
  stream_size <- attr(bytes, "stream_size")
  message("Size: ", stream_size)

  message("First bytes:")
  cat(paste(format_hex_line(bytes$hex), collapse = "\n"), "\n")

  offsets <- c(0, 4, 8, 12, 16, 20, 24, 28, 32, 36, 40, 44, 48, 52, 56, 60)
  rows <- bytes[bytes$offset %in% offsets, c("offset", "u16_le", "u32_le", "f32_le")]
  message("Little-endian interpretations at common offsets:")
  print(rows, row.names = FALSE)

  invisible(bytes)
}

stopifnot(file.exists(lcd_file))
streams <- rcpp_lcd_list_streams(lcd_file)
candidates <- streams[streams$is_chromatogram_candidate & streams$size > 0, ]

message("Inspecting non-empty candidate streams in: ", lcd_file)
print(candidates[, c("path", "size", "is_mini_stream")], row.names = FALSE)

invisible(lapply(candidates$path, function(path) inspect_stream(lcd_file, path)))

message("\ninspect_lcd_stream_headers.R completed.")
