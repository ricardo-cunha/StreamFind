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
  bytes <- rcpp_lcd_inspect_stream(file, path, max_bytes = size)
  as.integer(bytes$u8)
}
u16 <- function(x, pos) x[pos] + bitwShiftL(x[pos + 1L], 8L)
u32 <- function(x, pos) x[pos] + bitwShiftL(x[pos + 1L], 8L) + bitwShiftL(x[pos + 2L], 16L) + bitwShiftL(x[pos + 3L], 24L)
read_txt <- function(path) {
  lines <- readLines(path, warn = FALSE)
  start <- which(lines == "[LC Chromatogram(Detector A-Ch1)]")
  end <- start + which(lines[(start + 1L):length(lines)] == "")[1] - 1L
  block <- lines[start:end]
  header <- which(block == "R.Time (min)\tIntensity")
  parts <- strsplit(block[(header + 1L):length(block)], "\t")
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

decode <- function(x, reset_segments = integer()) {
  signal <- numeric(u32(x, 9L))
  rows <- list()
  count <- 1L
  pos <- 25L
  segment <- 1L
  accumulator <- 0
  while (count < length(signal) && pos + 1L <= length(x)) {
    n_bytes <- u16(x, pos)
    pos <- pos + 2L
    if (n_bytes <= 0L || pos + n_bytes - 1L > length(x)) break
    end_payload <- pos + n_bytes - 1L
    if (segment %in% reset_segments) accumulator <- 0
    first <- count
    while (pos <= end_payload && count < length(signal)) {
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
          if (pos + extra > end_payload) break
          delta <- decode_delta(x[pos:(pos + extra)])
          pos <- pos + 1L + extra
        }
      }
      accumulator <- accumulator + delta
      signal[count] <- accumulator
      count <- count + 1L
    }
    rows[[length(rows) + 1L]] <- data.frame(segment = segment, first = first, last = count - 1L)
    if (pos + 1L <= length(x)) pos <- pos + 2L
    segment <- segment + 1L
  }
  list(signal = signal, segments = do.call(rbind, rows))
}

score <- function(signal, txt, segments) {
  values <- c(txt[1], signal * value_factor)
  rows <- lapply(seq_len(nrow(segments)), function(i) {
    idx <- (segments$first[i] + 1L):(segments$last[i] + 1L)
    idx <- idx[idx <= length(txt) & idx <= length(values)]
    if (length(idx) < 10L) return(NULL)
    data.frame(
      segment = segments$segment[i],
      rmse = sqrt(mean((values[idx] - txt[idx])^2)),
      cor = suppressWarnings(cor(values[idx], txt[idx])),
      first_diff = values[idx[1]] - txt[idx[1]],
      last_diff = values[idx[length(idx)]] - txt[idx[length(idx)]],
      min_value = min(values[idx]),
      max_value = max(values[idx]),
      min_txt = min(txt[idx]),
      max_txt = max(txt[idx])
    )
  })
  do.call(rbind, rows)
}

bytes <- stream_bytes(lcd_file, stream_path)
txt <- read_txt(txt_file)

reset_sets <- list(
  reset_all = 1:17,
  continuous_all = integer(),
  reset_until_13 = 1:13,
  reset_until_14 = 1:14,
  reset_except_14_16 = setdiff(1:17, 14:16),
  reset_except_15_16 = setdiff(1:17, 15:16)
)

for (name in names(reset_sets)) {
  decoded <- decode(bytes, reset_sets[[name]])
  seg_scores <- score(decoded$signal, txt, decoded$segments)
  message("\nMode: ", name)
  print(data.frame(
    mode = name,
    whole_rmse = sqrt(mean((c(txt[1], decoded$signal * value_factor)[seq_along(txt)] - txt)^2)),
    peak_rmse = sqrt(mean((c(txt[1], decoded$signal * value_factor)[3330:3850] - txt[3330:3850])^2)),
    peak_cor = suppressWarnings(cor(c(txt[1], decoded$signal * value_factor)[3330:3850], txt[3330:3850]))
  ), row.names = FALSE)
  print(seg_scores[seg_scores$segment %in% 13:17, ], row.names = FALSE)
}

message("\ntest_lcd_ch1_reset_modes.R completed.")
