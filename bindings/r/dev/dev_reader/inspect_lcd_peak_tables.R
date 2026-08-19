#!/usr/bin/env Rscript

devtools::load_all()

example_dir <- file.path("dev", "dev_reader", "example_files")
lcd_file <- file.path(example_dir, "260115_ADC.lcd")
txt_file <- file.path(example_dir, "260115_ADC.txt")

stream_bytes <- function(path, size) {
  as.integer(rcpp_lcd_inspect_stream(lcd_file, path, max_bytes = size)$u8)
}

read_txt <- function(path) {
  lines <- readLines(path, warn = FALSE)
  start <- which(lines == "[LC Chromatogram(Detector A-Ch1)]")
  end <- start + which(lines[(start + 1L):length(lines)] == "")[1] - 1L
  block <- lines[start:end]
  header <- which(block == "R.Time (min)\tIntensity")
  parts <- strsplit(block[(header + 1L):length(block)], "\t")
  data.frame(
    rt = as.numeric(vapply(parts, `[`, character(1), 1)),
    intensity = as.numeric(vapply(parts, `[`, character(1), 2))
  )
}

u16 <- function(x, pos) if (pos + 1L <= length(x)) x[pos] + bitwShiftL(x[pos + 1L], 8L) else NA_integer_
u32 <- function(x, pos) if (pos + 3L <= length(x)) x[pos] + bitwShiftL(x[pos + 1L], 8L) + bitwShiftL(x[pos + 2L], 16L) + bitwShiftL(x[pos + 3L], 24L) else NA_real_
i32 <- function(x, pos) { v <- u32(x, pos); ifelse(is.na(v), NA_real_, ifelse(v >= 2^31, v - 2^32, v)) }
f32 <- function(x, pos) if (pos + 3L <= length(x)) readBin(as.raw(x[pos:(pos + 3L)]), "numeric", n = 1, size = 4, endian = "little") else NA_real_
f64 <- function(x, pos) if (pos + 7L <= length(x)) readBin(as.raw(x[pos:(pos + 7L)]), "numeric", n = 1, size = 8, endian = "little") else NA_real_
ascii <- function(x) paste(ifelse(x >= 32L & x <= 126L, rawToChar(as.raw(x), multiple = TRUE), "."), collapse = "")
hex <- function(x) paste(sprintf("%02X", x), collapse = " ")

numeric_offsets <- function(bytes) {
  offsets <- seq_len(length(bytes))
  rows <- data.frame(
    offset0 = offsets - 1L,
    u16 = vapply(offsets, function(pos) u16(bytes, pos), integer(1)),
    i32 = vapply(offsets, function(pos) i32(bytes, pos), numeric(1)),
    f32 = vapply(offsets, function(pos) f32(bytes, pos), numeric(1)),
    f64 = vapply(offsets, function(pos) f64(bytes, pos), numeric(1))
  )
  rows <- rows[
    (is.finite(rows$f64) & abs(rows$f64) > 1e-9 & abs(rows$f64) < 1e8) |
      (is.finite(rows$f32) & abs(rows$f32) > 1e-9 & abs(rows$f32) < 1e8) |
      (rows$i32 != 0 & abs(rows$i32) < 1e8) |
      rows$u16 != 0,
  ]
  rows
}

show_records <- function(bytes, record_size) {
  n <- floor(length(bytes) / record_size)
  if (n == 0L) return(invisible(NULL))
  message("\nRecord size ", record_size, ": records=", n, ", remainder=", length(bytes) %% record_size)
  for (i in seq_len(min(n, 6L))) {
    start <- (i - 1L) * record_size + 1L
    rec <- bytes[start:(start + record_size - 1L)]
    cat(sprintf("record %d offset %d ascii %s\n", i, start - 1L, ascii(rec)))
    vals <- data.frame(
      offset0 = seq(0L, min(record_size - 1L, 120L), by = 4L),
      i32 = vapply(seq(1L, min(record_size, 121L), by = 4L), function(pos) i32(rec, pos), numeric(1)),
      f32 = vapply(seq(1L, min(record_size, 121L), by = 4L), function(pos) f32(rec, pos), numeric(1)),
      f64 = vapply(seq(1L, min(record_size, 121L), by = 4L), function(pos) f64(rec, pos), numeric(1))
    )
    print(vals, row.names = FALSE)
  }
}

txt <- read_txt(txt_file)
message("TXT apex idx=", which.max(txt$intensity), " rt=", txt$rt[which.max(txt$intensity)], " intensity=", max(txt$intensity))

streams <- rcpp_lcd_list_streams(lcd_file)
candidate <- grepl("Peak Table|Slice Data|Multi Chromato|Peak Pick|Compound Results|GPC PeakDetail|GPC SliceData|Noise Spectrum", streams$path, ignore.case = TRUE)
streams <- streams[candidate & streams$size > 0, ]

for (i in seq_len(nrow(streams))) {
  path <- streams$path[i]
  bytes <- stream_bytes(path, streams$size[i])
  message("\n========================================")
  message("Stream: ", path, " size=", length(bytes))
  cat("ASCII: ", ascii(bytes[1:min(length(bytes), 240L)]), "\n", sep = "")
  cat("HEX: ", hex(bytes[1:min(length(bytes), 160L)]), "\n", sep = "")
  nums <- numeric_offsets(bytes)
  interesting <- nums[
    (is.finite(nums$f64) & (between <- nums$f64 >= -10000 & nums$f64 <= 150000)) |
      (is.finite(nums$f32) & nums$f32 >= -10000 & nums$f32 <= 150000) |
      (nums$i32 >= -10000 & nums$i32 <= 150000),
  ]
  message("Interesting numeric offsets:")
  print(head(interesting, 80), row.names = FALSE)
  for (record_size in c(32L, 56L, 72L, 88L, 136L, 184L, 264L, 288L, 336L, 552L, 568L)) {
    if (length(bytes) >= record_size && length(bytes) %% record_size == 0L) {
      show_records(bytes, record_size)
    }
  }
}

message("\ninspect_lcd_peak_tables.R completed.")
