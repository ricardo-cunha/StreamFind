#!/usr/bin/env Rscript

devtools::load_all()

example_dir <- file.path("dev", "dev_reader", "example_files")
lcd_file <- file.path(example_dir, "260115_ADC.lcd")

paths <- c(
  "LC Data Processing Original/Detector Channel Information",
  "LC Data Processing/Detector Channel Information",
  "LC Data Processing Original/Multi Chromato Table",
  "LC Data Processing/Multi Chromato Table",
  "LC Data Processing Original/Peak Picking Parameter-1",
  "LC Data Processing/Peak Pick Parameter-100",
  "LC Data Processing/Noise Spectrum Parameter",
  "LC Raw Data/Chromatogram Status"
)

stream_bytes <- function(path) {
  listed <- rcpp_lcd_list_streams(lcd_file)
  size <- listed$size[listed$path == path]
  stopifnot(length(size) == 1)
  as.integer(rcpp_lcd_inspect_stream(lcd_file, path, max_bytes = size)$u8)
}

u16 <- function(x, pos) if (pos + 1L <= length(x)) x[pos] + bitwShiftL(x[pos + 1L], 8L) else NA_integer_
u32 <- function(x, pos) if (pos + 3L <= length(x)) x[pos] + bitwShiftL(x[pos + 1L], 8L) + bitwShiftL(x[pos + 2L], 16L) + bitwShiftL(x[pos + 3L], 24L) else NA_real_
i32 <- function(x, pos) { v <- u32(x, pos); ifelse(is.na(v), NA_real_, ifelse(v >= 2^31, v - 2^32, v)) }
f32 <- function(x, pos) if (pos + 3L <= length(x)) readBin(as.raw(x[pos:(pos + 3L)]), "numeric", n = 1, size = 4, endian = "little") else NA_real_
f64 <- function(x, pos) if (pos + 7L <= length(x)) readBin(as.raw(x[pos:(pos + 7L)]), "numeric", n = 1, size = 8, endian = "little") else NA_real_
ascii <- function(x) paste(ifelse(x >= 32L & x <= 126L, rawToChar(as.raw(x), multiple = TRUE), "."), collapse = "")
hex <- function(x) paste(sprintf("%02X", x), collapse = " ")

scan_numbers <- function(bytes) {
  offsets <- seq(1L, length(bytes), by = 4L)
  vals <- data.frame(
    offset0 = offsets - 1L,
    u16 = vapply(offsets, function(pos) u16(bytes, pos), integer(1)),
    i32 = vapply(offsets, function(pos) i32(bytes, pos), numeric(1)),
    f32 = vapply(offsets, function(pos) f32(bytes, pos), numeric(1)),
    f64 = vapply(offsets, function(pos) f64(bytes, pos), numeric(1))
  )
  vals[is.finite(vals$f64) & abs(vals$f64) > 1e-12 & abs(vals$f64) < 1e9 |
         is.finite(vals$f32) & abs(vals$f32) > 1e-12 & abs(vals$f32) < 1e9 |
         vals$u16 != 0, ]
}

for (path in paths) {
  listed <- rcpp_lcd_list_streams(lcd_file)
  if (!path %in% listed$path || listed$size[listed$path == path] == 0) next
  bytes <- stream_bytes(path)
  message("\n========================================")
  message("Stream: ", path, " size=", length(bytes))
  cat("ASCII:\n", ascii(bytes), "\n", sep = "")
  cat("First 256 hex:\n", hex(bytes[1:min(256, length(bytes))]), "\n", sep = "")
  message("Numeric scan at 4-byte offsets:")
  print(scan_numbers(bytes), row.names = FALSE)
  if (length(bytes) >= 64L) {
    message("64-byte records:")
    for (start in seq(1L, length(bytes), by = 64L)) {
      rec <- bytes[start:min(start + 63L, length(bytes))]
      cat(sprintf("offset %04d txt %s\n", start - 1L, ascii(rec)))
      cat(sprintf("offset %04d hex %s\n", start - 1L, hex(rec)))
    }
  }
}

message("\ninspect_lcd_detector_processing_metadata.R completed.")
