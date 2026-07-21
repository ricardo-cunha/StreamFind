#!/usr/bin/env Rscript

devtools::load_all()

example_dir <- file.path("dev", "dev_reader", "example_files")
lcd_file <- file.path(example_dir, "260115_ADC.lcd")
txt_file <- file.path(example_dir, "260115_ADC.txt")
stream_path <- "LC Raw Data/Chromatogram Ch1"
value_factor <- 0.00476837158203125

stream_bytes <- function(file, path) {
  listed <- rcpp_lcd_list_streams(file)
  size <- listed$size[listed$path == path]
  stopifnot(length(size) == 1)
  bytes <- rcpp_lcd_inspect_stream(file, path, max_bytes = size)
  as.integer(bytes$u8)
}

u16 <- function(x, pos) x[pos] + bitwShiftL(x[pos + 1L], 8L)
u32 <- function(x, pos) x[pos] + bitwShiftL(x[pos + 1L], 8L) + bitwShiftL(x[pos + 2L], 16L) + bitwShiftL(x[pos + 3L], 24L)

read_txt_chrom <- function(path, name) {
  lines <- readLines(path, warn = FALSE)
  start <- which(lines == paste0("[LC Chromatogram(", name, ")]"))
  end <- start + which(lines[(start + 1L):length(lines)] == "")[1] - 1L
  block <- lines[start:end]
  header <- which(block == "R.Time (min)\tIntensity")
  data_lines <- block[(header + 1L):length(block)]
  data_lines <- data_lines[nzchar(data_lines)]
  parts <- strsplit(data_lines, "\t")
  as.numeric(vapply(parts, `[`, character(1), 2))
}

decode_delta <- function(value_bytes) {
  value_bits <- 8L * length(value_bytes) - 4L
  x <- 0L
  for (b in as.integer(value_bytes)) x <- bitwOr(bitwShiftL(x, 8L), b)
  sign <- bitwAnd(bitwShiftR(x, value_bits), 0x0F)
  value <- bitwAnd(x, bitwShiftL(1L, value_bits) - 1L)
  if (sign %% 2L == 1L) -(bitwShiftL(1L, value_bits) - value) else value
}

decode_segments <- function(x) {
  signal <- numeric(u32(x, 9L))
  rows <- list()
  count <- 1L
  pos <- 25L
  segment <- 1L
  while (count < length(signal) && pos + 1L <= length(x)) {
    marker_pos <- pos
    n_bytes <- u16(x, pos)
    pos <- pos + 2L
    if (n_bytes <= 0L || pos + n_bytes - 1L > length(x)) break
    payload_start <- pos
    payload_end <- pos + n_bytes - 1L
    accumulator <- 0
    first_point <- count
    while (pos <= payload_end && count < length(signal)) {
      current <- x[pos]
      if (current == 0x82L) {
        pos <- pos + 1L
        next
      } else if (current == 0x00L) {
        delta <- 0L
        pos <- pos + 1L
      } else {
        high <- bitwShiftR(current, 4L)
        if (high == 0L) {
          delta <- current
          pos <- pos + 1L
        } else {
          extra <- if (high == 1L) 0L else high %/% 2L
          if (pos + extra > payload_end) break
          delta <- decode_delta(x[pos:(pos + extra)])
          pos <- pos + 1L + extra
        }
      }
      accumulator <- accumulator + delta
      signal[count] <- accumulator
      count <- count + 1L
    }
    end_marker <- if (pos + 1L <= length(x)) u16(x, pos) else NA_integer_
    pos <- pos + 2L
    rows[[length(rows) + 1L]] <- data.frame(
      segment = segment,
      marker_offset0 = marker_pos - 1L,
      payload_offset0 = payload_start - 1L,
      n_bytes = n_bytes,
      end_marker = end_marker,
      first_point = first_point,
      last_point = count - 1L,
      stringsAsFactors = FALSE
    )
    segment <- segment + 1L
  }
  list(signal = signal, segments = do.call(rbind, rows))
}

bytes <- stream_bytes(lcd_file, stream_path)
txt <- read_txt_chrom(txt_file, "Detector A-Ch1")
decoded <- decode_segments(bytes)
scaled <- decoded$signal * value_factor

rows <- lapply(seq_len(nrow(decoded$segments)), function(i) {
  seg <- decoded$segments[i, ]
  # Decoded point 1 maps to TXT point 2; TXT point 1 is the initial sample.
  txt_start <- seg$first_point + 1L
  txt_end <- min(seg$last_point + 1L, length(txt))
  idx_dec <- seg$first_point:seg$last_point
  idx_txt <- txt_start:txt_end
  n <- min(length(idx_dec), length(idx_txt))
  idx_dec <- idx_dec[seq_len(n)]
  idx_txt <- idx_txt[seq_len(n)]
  residual <- txt[idx_txt] - scaled[idx_dec]
  data.frame(
    segment = seg$segment,
    decoded_start = seg$first_point,
    txt_start = txt_start,
    n = n,
    scaled_first = scaled[idx_dec[1]],
    txt_first = txt[idx_txt[1]],
    offset_first = residual[1],
    offset_median = median(residual),
    offset_mean = mean(residual),
    residual_sd = sd(residual),
    residual_min = min(residual),
    residual_max = max(residual),
    prev_txt = if (txt_start > 1L) txt[txt_start - 1L] else NA_real_,
    prev_scaled = if (seg$first_point > 1L) scaled[seg$first_point - 1L] else NA_real_,
    marker_offset0 = seg$marker_offset0,
    n_bytes = seg$n_bytes,
    stringsAsFactors = FALSE
  )
})
rows <- do.call(rbind, rows)

message("Segment offsets using detector value factor ", value_factor, ":")
print(rows, row.names = FALSE)

message("\nOffset differences:")
rows$offset_delta <- c(NA, diff(rows$offset_median))
print(rows[, c("segment", "offset_median", "offset_delta", "prev_txt", "txt_first", "scaled_first")], row.names = FALSE)

message("\nWhole-trace RMSE if each segment uses median residual offset:")
corrected <- rep(NA_real_, length(txt))
corrected[1] <- txt[1]
for (i in seq_len(nrow(decoded$segments))) {
  seg <- decoded$segments[i, ]
  idx_dec <- seg$first_point:seg$last_point
  idx_txt <- (seg$first_point + 1L):(seg$last_point + 1L)
  keep <- idx_txt <= length(txt)
  corrected[idx_txt[keep]] <- scaled[idx_dec[keep]] + rows$offset_median[i]
}
print(data.frame(
  rmse = sqrt(mean((corrected - txt)^2, na.rm = TRUE)),
  max_abs = max(abs(corrected - txt), na.rm = TRUE),
  exact_rounded = identical(round(corrected), txt),
  first_corrected = paste(head(round(corrected), 20), collapse = ", "),
  first_txt = paste(head(txt, 20), collapse = ", ")
), row.names = FALSE)

message("\nanalyze_lcd_ch1_baseline.R completed.")
