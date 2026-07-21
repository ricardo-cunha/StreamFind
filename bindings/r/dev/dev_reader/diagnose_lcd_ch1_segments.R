#!/usr/bin/env Rscript

devtools::load_all()

example_dir <- file.path("dev", "dev_reader", "example_files")
lcd_file <- file.path(example_dir, "260115_ADC.lcd")
txt_file <- file.path(example_dir, "260115_ADC.txt")
stream_path <- "LC Raw Data/Chromatogram Ch1"

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
  stopifnot(length(start) == 1L)
  end <- start + which(lines[(start + 1L):length(lines)] == "")[1] - 1L
  block <- lines[start:end]
  header <- which(block == "R.Time (min)\tIntensity")
  data_lines <- block[(header + 1L):length(block)]
  data_lines <- data_lines[nzchar(data_lines)]
  parts <- strsplit(data_lines, "\t")
  as.numeric(vapply(parts, `[`, character(1), 2))
}

decode_delta <- function(value_bytes) {
  value_bytes <- as.integer(value_bytes)
  total_bits <- 8L * length(value_bytes)
  value_bits <- total_bits - 4L
  x <- 0L
  for (b in value_bytes) x <- bitwOr(bitwShiftL(x, 8L), b)
  sign <- bitwAnd(bitwShiftR(x, value_bits), 0x0F)
  value <- bitwAnd(x, bitwShiftL(1L, value_bits) - 1L)
  if (sign %% 2L == 1L) -(bitwShiftL(1L, value_bits) - value) else value
}

decode_segments <- function(x, mode = c("upstream", "one_byte_subtract")) {
  mode <- match.arg(mode)
  signal <- numeric(u32(x, 9L))
  rows <- list()
  count <- 1L
  pos <- 25L
  segment <- 1L
  while (count < length(signal) && pos + 1L <= length(x)) {
    start_marker_pos <- pos
    n_bytes <- u16(x, pos)
    pos <- pos + 2L
    if (n_bytes <= 0L || pos + n_bytes - 1L > length(x)) break
    payload_start <- pos
    payload_end <- pos + n_bytes - 1L
    accumulator <- 0
    first_point <- count
    n_values <- 0L
    first_deltas <- numeric()
    while (pos <= payload_end && count < length(signal)) {
      current <- x[pos]
      if (current == 0x82L) {
        pos <- pos + 1L
        next
      }
      if (current == 0x00L) {
        delta <- 0L
        pos <- pos + 1L
      } else if (mode == "one_byte_subtract") {
        high <- bitwShiftR(current, 4L)
        low <- bitwAnd(current, 0x0F)
        delta <- if (high %% 2L == 1L) -low else low
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
      accumulator <- if (mode == "one_byte_subtract") accumulator - delta else accumulator + delta
      signal[count] <- accumulator
      count <- count + 1L
      n_values <- n_values + 1L
      if (length(first_deltas) < 12L) first_deltas <- c(first_deltas, delta)
    }
    end_marker <- if (pos + 1L <= length(x)) u16(x, pos) else NA_integer_
    pos <- pos + 2L
    rows[[length(rows) + 1L]] <- data.frame(
      segment = segment,
      marker_offset0 = start_marker_pos - 1L,
      payload_offset0 = payload_start - 1L,
      n_bytes = n_bytes,
      end_marker = end_marker,
      first_point = first_point,
      last_point = count - 1L,
      n_values = n_values,
      first_payload_hex = paste(sprintf("%02X", x[payload_start:min(payload_start + 23L, payload_end)]), collapse = " "),
      first_deltas = paste(first_deltas, collapse = ", "),
      first_values = paste(signal[first_point:min(first_point + 11L, count - 1L)], collapse = ", "),
      stringsAsFactors = FALSE
    )
    segment <- segment + 1L
  }
  list(signal = signal, segments = do.call(rbind, rows))
}

best_affine_by_segment <- function(decoded, target, segments, prepend_initial = TRUE) {
  values <- if (prepend_initial) c(target[1], decoded) else decoded
  rows <- lapply(seq_len(nrow(segments)), function(i) {
    start <- segments$first_point[i] + if (prepend_initial) 1L else 0L
    end <- min(segments$last_point[i] + if (prepend_initial) 1L else 0L, length(values), length(target))
    if (end - start < 10L) return(NULL)
    v <- values[start:end]
    t <- target[start:end]
    fit <- lm(t ~ v)
    pred <- as.numeric(coef(fit)[1] + coef(fit)[2] * v)
    data.frame(
      segment = segments$segment[i],
      start = start,
      end = end,
      decoded_min = min(v),
      decoded_max = max(v),
      target_min = min(t),
      target_max = max(t),
      intercept = unname(coef(fit)[1]),
      slope = unname(coef(fit)[2]),
      rmse = sqrt(mean((pred - t)^2)),
      cor = suppressWarnings(cor(v, t))
    )
  })
  do.call(rbind, rows)
}

bytes <- stream_bytes(lcd_file, stream_path)
target <- read_txt_chrom(txt_file, "Detector A-Ch1")

message("Stream header:")
print(data.frame(
  magic = rawToChar(as.raw(bytes[1:2])),
  interval_ms = u32(bytes, 5L),
  interval_count = u32(bytes, 9L),
  declared_size = u32(bytes, 13L),
  actual_size = length(bytes)
), row.names = FALSE)

for (mode in c("upstream", "one_byte_subtract")) {
  decoded <- decode_segments(bytes, mode)
  message("\nMode: ", mode)
  print(decoded$segments[, c("segment", "marker_offset0", "n_bytes", "end_marker", "first_point", "last_point", "n_values", "first_payload_hex", "first_deltas", "first_values")], row.names = FALSE)
  message("Segment affine summaries vs TXT Detector A-Ch1:")
  print(best_affine_by_segment(decoded$signal, target, decoded$segments), row.names = FALSE)
}

message("\ndiagnose_lcd_ch1_segments.R completed.")
