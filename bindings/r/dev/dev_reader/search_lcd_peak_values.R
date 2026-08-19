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

u16 <- function(x, pos) if (pos + 1L <= length(x)) x[pos] + bitwShiftL(x[pos + 1L], 8L) else NA_real_
u32 <- function(x, pos) if (pos + 3L <= length(x)) x[pos] + bitwShiftL(x[pos + 1L], 8L) + bitwShiftL(x[pos + 2L], 16L) + bitwShiftL(x[pos + 3L], 24L) else NA_real_
i32 <- function(x, pos) { v <- u32(x, pos); ifelse(is.na(v), NA_real_, ifelse(v >= 2^31, v - 2^32, v)) }
f32 <- function(x, pos) if (pos + 3L <= length(x)) readBin(as.raw(x[pos:(pos + 3L)]), "numeric", n = 1, size = 4, endian = "little") else NA_real_
f64 <- function(x, pos) if (pos + 7L <= length(x)) readBin(as.raw(x[pos:(pos + 7L)]), "numeric", n = 1, size = 8, endian = "little") else NA_real_
ascii <- function(x) paste(ifelse(x >= 32L & x <= 126L, rawToChar(as.raw(x), multiple = TRUE), "."), collapse = "")

scan_near <- function(bytes, targets) {
  rows <- list()
  for (pos in seq_len(length(bytes))) {
    vals <- c(u16 = u16(bytes, pos), i32 = i32(bytes, pos), f32 = f32(bytes, pos), f64 = f64(bytes, pos))
    for (target_name in names(targets)) {
      target <- targets[[target_name]]
      tolerance <- max(abs(target) * 1e-4, 0.25)
      hits <- names(vals)[is.finite(vals) & abs(vals - target) <= tolerance]
      for (kind in hits) {
        context_start <- max(1L, pos - 24L)
        context_end <- min(length(bytes), pos + 48L)
        rows[[length(rows) + 1L]] <- data.frame(
          offset0 = pos - 1L,
          kind = kind,
          target = target_name,
          value = vals[[kind]],
          context_ascii = ascii(bytes[context_start:context_end]),
          stringsAsFactors = FALSE
        )
      }
    }
  }
  if (length(rows) == 0L) return(data.frame())
  do.call(rbind, rows)
}

txt <- read_txt(txt_file)
apex_idx <- which.max(txt$intensity)
apex <- txt$intensity[apex_idx]
apex_rt <- txt$rt[apex_idx]
raw_equiv <- apex / factor_ch1

targets <- c(
  txt_apex = apex,
  raw_equiv = raw_equiv,
  apex_idx_1based = apex_idx,
  apex_idx_0based = apex_idx - 1,
  apex_time_min = apex_rt,
  apex_time_ms = apex_rt * 60000,
  segment14_start_idx = 3329,
  segment15_start_idx = 3585,
  segment16_start_idx = 3841,
  ch1_factor = factor_ch1,
  wavelength_280 = 280,
  baseline_minus500 = -500
)

message("Search targets:")
print(data.frame(name = names(targets), value = as.numeric(targets)), row.names = FALSE)

streams <- rcpp_lcd_list_streams(lcd_file)
streams <- streams[streams$size > 0, ]

all_hits <- list()
for (i in seq_len(nrow(streams))) {
  bytes <- stream_bytes(streams$path[i], streams$size[i])
  hits <- scan_near(bytes, targets)
  if (nrow(hits) == 0L) next
  hits$path <- streams$path[i]
  hits$size <- streams$size[i]
  all_hits[[length(all_hits) + 1L]] <- hits
}

hits <- if (length(all_hits) == 0L) data.frame() else do.call(rbind, all_hits)
if (nrow(hits) > 0L) {
  hits <- hits[, c("path", "size", "offset0", "kind", "target", "value", "context_ascii")]
  message("\nHits:")
  print(hits, row.names = FALSE)
} else {
  message("No hits found.")
}

message("\nsearch_lcd_peak_values.R completed.")
