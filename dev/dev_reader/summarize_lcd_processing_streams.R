#!/usr/bin/env Rscript

devtools::load_all()

example_dir <- file.path("dev", "dev_reader", "example_files")
lcd_file <- file.path(example_dir, "260115_ADC.lcd")
txt_file <- file.path(example_dir, "260115_ADC.txt")

stream_bytes <- function(path, size) {
  as.integer(rcpp_lcd_inspect_stream(lcd_file, path, max_bytes = size)$u8)
}

read_txt_ch1 <- function(path) {
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

u32 <- function(x, pos) {
  if (pos + 3L > length(x)) return(NA_real_)
  x[pos] + x[pos + 1L] * 256 + x[pos + 2L] * 65536 + x[pos + 3L] * 16777216
}

i32 <- function(x, pos) {
  value <- u32(x, pos)
  if (is.na(value)) return(NA_real_)
  if (value >= 2^31) value - 2^32 else value
}

f32 <- function(x, pos) {
  if (pos + 3L > length(x)) return(NA_real_)
  readBin(as.raw(x[pos:(pos + 3L)]), "numeric", n = 1, size = 4, endian = "little")
}

f64 <- function(x, pos) {
  if (pos + 7L > length(x)) return(NA_real_)
  readBin(as.raw(x[pos:(pos + 7L)]), "numeric", n = 1, size = 8, endian = "little")
}

hex <- function(x) paste(sprintf("%02X", x), collapse = " ")
ascii <- function(x) paste(ifelse(x >= 32L & x <= 126L, rawToChar(as.raw(x), multiple = TRUE), "."), collapse = "")

interesting_values <- function(bytes) {
  if (length(bytes) < 8L) return(data.frame())
  offsets <- seq_len(length(bytes))
  rows <- data.frame(
    offset0 = offsets - 1L,
    i32 = vapply(offsets, function(pos) i32(bytes, pos), numeric(1)),
    f32 = vapply(offsets, function(pos) f32(bytes, pos), numeric(1)),
    f64 = vapply(offsets, function(pos) f64(bytes, pos), numeric(1))
  )
  rows[
    (is.finite(rows$i32) & rows$i32 != 0 & rows$i32 >= -10000 & rows$i32 <= 200000) |
      (is.finite(rows$f32) & abs(rows$f32) > 1e-9 & rows$f32 >= -10000 & rows$f32 <= 200000) |
      (is.finite(rows$f64) & abs(rows$f64) > 1e-9 & rows$f64 >= -10000 & rows$f64 <= 200000),
  ]
}

context_for_offsets <- function(bytes, offsets0) {
  if (length(offsets0) == 0L) return(data.frame())
  do.call(rbind, lapply(offsets0, function(offset0) {
    start <- max(1L, offset0 + 1L - 16L)
    end <- min(length(bytes), offset0 + 1L + 32L)
    data.frame(
      offset0 = offset0,
      context_hex = hex(bytes[start:end]),
      context_ascii = ascii(bytes[start:end]),
      stringsAsFactors = FALSE
    )
  }))
}

txt <- read_txt_ch1(txt_file)
apex_idx <- which.max(txt$intensity)
targets <- c(
  txt_apex = txt$intensity[apex_idx],
  txt_apex_time = txt$rt[apex_idx],
  txt_apex_index = apex_idx,
  project_scaled_apex = txt$intensity[apex_idx] * 0.001,
  lcd_scaled_apex = 128.0242,
  detector_factor = 0.00476837158203125,
  wavelength = 280,
  baseline_or_range = -500
)
integer_targets <- c("txt_apex_index", "wavelength", "baseline_or_range")

streams <- rcpp_lcd_list_streams(lcd_file)
candidate <- grepl(
  "Data Processing|Peak Table|Slice Data|Spectrum Table|Multi Chromato|Noise Spectrum|Detector Channel",
  streams$path,
  ignore.case = TRUE
)
streams <- streams[candidate & streams$size > 0, ]

summary_rows <- list()
for (i in seq_len(nrow(streams))) {
  bytes <- stream_bytes(streams$path[i], streams$size[i])
  nonzero <- which(bytes != 0L)
  values <- interesting_values(bytes)
  target_hits <- values[FALSE, ]
  for (target_name in names(targets)) {
    target <- targets[[target_name]]
    i32_hit <- target_name %in% integer_targets & is.finite(values$i32) & values$i32 == target
    f32_hit <- is.finite(values$f32) & abs(values$f32 - target) <= max(1e-6, abs(target) * 1e-5)
    f64_hit <- is.finite(values$f64) & abs(values$f64 - target) <= max(1e-9, abs(target) * 1e-8)
    hits <- values[i32_hit | f32_hit | f64_hit, ]
    if (nrow(hits) > 0L) {
      hits$target <- target_name
      target_hits <- rbind(target_hits, hits)
    }
  }
  summary_rows[[length(summary_rows) + 1L]] <- data.frame(
    path = streams$path[i],
    size = streams$size[i],
    nonzero_bytes = length(nonzero),
    first_nonzero_offset0 = if (length(nonzero) > 0L) min(nonzero) - 1L else NA_integer_,
    last_nonzero_offset0 = if (length(nonzero) > 0L) max(nonzero) - 1L else NA_integer_,
    interesting_values = nrow(values),
    target_hits = nrow(target_hits),
    stringsAsFactors = FALSE
  )
  if (length(nonzero) > 0L || nrow(target_hits) > 0L) {
    message("\nStream: ", streams$path[i], " size=", streams$size[i])
    message("Nonzero bytes: ", length(nonzero), " first=", if (length(nonzero) > 0L) min(nonzero) - 1L else NA_integer_, " last=", if (length(nonzero) > 0L) max(nonzero) - 1L else NA_integer_)
    if (length(nonzero) > 0L) {
      print(context_for_offsets(bytes, unique(c(head(nonzero - 1L, 3L), tail(nonzero - 1L, 3L)))), row.names = FALSE)
    }
    if (nrow(target_hits) > 0L) {
      message("Target hits:")
      print(target_hits[, c("target", "offset0", "i32", "f32", "f64")], row.names = FALSE)
    }
    if (nrow(values) > 0L) {
      message("First interesting numeric offsets:")
      print(head(values, 20), row.names = FALSE)
    }
  }
}

summary <- do.call(rbind, summary_rows)
message("\nProcessing stream summary:")
print(summary[order(-summary$nonzero_bytes, summary$path), ], row.names = FALSE)

message("\nsummarize_lcd_processing_streams.R completed.")
