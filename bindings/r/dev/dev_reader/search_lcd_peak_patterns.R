#!/usr/bin/env Rscript

devtools::load_all()

example_dir <- file.path("dev", "dev_reader", "example_files")
lcd_file <- file.path(example_dir, "260115_ADC.lcd")
txt_file <- file.path(example_dir, "260115_ADC.txt")
factor_ch1 <- 0.00476837158203125

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

to_i32_le <- function(value) {
  if (value < 0) value <- value + 2^32
  as.integer(c(value %% 256, floor(value / 256) %% 256, floor(value / 65536) %% 256, floor(value / 16777216) %% 256))
}

to_f64_le <- function(value) as.integer(writeBin(as.numeric(value), raw(), size = 8, endian = "little"))
to_f32_le <- function(value) as.integer(writeBin(as.numeric(value), raw(), size = 4, endian = "little"))

find_pattern <- function(bytes, pattern) {
  if (length(bytes) < length(pattern)) return(integer())
  starts <- seq_len(length(bytes) - length(pattern) + 1L)
  starts[vapply(starts, function(pos) all(bytes[pos:(pos + length(pattern) - 1L)] == pattern), logical(1))] - 1L
}

ascii <- function(x) paste(ifelse(x >= 32L & x <= 126L, rawToChar(as.raw(x), multiple = TRUE), "."), collapse = "")
hex <- function(x) paste(sprintf("%02X", x), collapse = " ")

txt <- read_txt(txt_file)
apex_idx <- which.max(txt$intensity)
apex <- txt$intensity[apex_idx]
apex_rt <- txt$rt[apex_idx]
raw_equiv <- apex / factor_ch1

patterns <- list(
  txt_apex_i32 = to_i32_le(apex),
  txt_apex_f64 = to_f64_le(apex),
  raw_equiv_i32 = to_i32_le(round(raw_equiv)),
  raw_equiv_f64 = to_f64_le(raw_equiv),
  apex_idx_i32 = to_i32_le(apex_idx),
  apex_zero_idx_i32 = to_i32_le(apex_idx - 1L),
  apex_time_min_f64 = to_f64_le(apex_rt),
  apex_time_ms_i32 = to_i32_le(round(apex_rt * 60000)),
  factor_f64 = to_f64_le(factor_ch1),
  factor_f32 = to_f32_le(factor_ch1),
  wavelength_280_i32 = to_i32_le(280),
  wavelength_280_f32 = to_f32_le(280),
  minus500_i32 = to_i32_le(-500)
)

message("Search targets:")
print(data.frame(
  name = names(patterns),
  hex = vapply(patterns, hex, character(1)),
  stringsAsFactors = FALSE
), row.names = FALSE)

streams <- rcpp_lcd_list_streams(lcd_file)
interesting <- grepl("Data Processing|Raw Data|Chromato|Peak|Slice|Spectrum|Detector|Noise|Status|Configuration", streams$path, ignore.case = TRUE)
streams <- streams[interesting & streams$size > 0, ]

rows <- list()
for (i in seq_len(nrow(streams))) {
  bytes <- stream_bytes(streams$path[i], streams$size[i])
  for (name in names(patterns)) {
    offsets <- find_pattern(bytes, patterns[[name]])
    for (offset in offsets) {
      start <- max(1L, offset + 1L - 24L)
      end <- min(length(bytes), offset + 1L + length(patterns[[name]]) + 48L)
      rows[[length(rows) + 1L]] <- data.frame(
        path = streams$path[i],
        size = streams$size[i],
        pattern = name,
        offset0 = offset,
        context_hex = hex(bytes[start:end]),
        context_ascii = ascii(bytes[start:end]),
        stringsAsFactors = FALSE
      )
    }
  }
}

hits <- if (length(rows) == 0L) data.frame() else do.call(rbind, rows)
message("\nPattern hit summary:")
if (nrow(hits) == 0L) {
  message("No pattern hits.")
} else {
  print(as.data.frame(table(hits$pattern, hits$path)), row.names = FALSE)
  message("\nDetailed hits:")
  print(hits, row.names = FALSE)
}

message("\nsearch_lcd_peak_patterns.R completed.")
