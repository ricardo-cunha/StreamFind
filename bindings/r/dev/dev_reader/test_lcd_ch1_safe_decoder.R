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
  as.integer(rcpp_lcd_inspect_stream(file, path, max_bytes = size)$u8)
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

decode_delta_safe <- function(value_bytes) {
  value_bytes <- as.numeric(value_bytes)
  total_bits <- 8 * length(value_bytes)
  value_bits <- total_bits - 4
  x <- 0
  for (b in value_bytes) x <- x * 256 + b
  sign <- floor(x / 2^value_bits)
  value <- x - sign * 2^value_bits
  if (sign %% 2 == 1) -(2^value_bits - value) else value
}

decode_safe <- function(x) {
  signal <- numeric(u32(x, 9L))
  rows <- list()
  count <- 1L
  pos <- 25L
  segment <- 1L
  high_counts <- integer(16)
  while (count < length(signal) && pos + 1L <= length(x)) {
    n_bytes <- u16(x, pos)
    pos <- pos + 2L
    if (n_bytes <= 0L || pos + n_bytes - 1L > length(x)) break
    end_payload <- pos + n_bytes - 1L
    accumulator <- 0
    first <- count
    while (pos <= end_payload && count < length(signal)) {
      current <- x[pos]
      if (current == 0x82L) {
        pos <- pos + 1L
        next
      } else if (current == 0x00L) {
        delta <- 0
        pos <- pos + 1L
      } else {
        high <- bitwShiftR(current, 4L)
        high_counts[high + 1L] <- high_counts[high + 1L] + 1L
        if (high == 0L) {
          delta <- current
          pos <- pos + 1L
        } else {
          extra <- if (high == 1L) 0L else high %/% 2L
          if (pos + extra > end_payload) break
          delta <- decode_delta_safe(x[pos:(pos + extra)])
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
  list(signal = signal, segments = do.call(rbind, rows), high_counts = high_counts)
}

bytes <- stream_bytes(lcd_file, stream_path)
txt <- read_txt(txt_file)
decoded <- decode_safe(bytes)
values <- c(txt[1], decoded$signal * value_factor)

message("Parsed current-byte high-nibble counts:")
print(data.frame(high = 0:15, n = decoded$high_counts), row.names = FALSE)

message("\nSafe decoder segment scores:")
scores <- do.call(rbind, lapply(seq_len(nrow(decoded$segments)), function(i) {
  seg <- decoded$segments[i, ]
  idx <- (seg$first + 1L):(seg$last + 1L)
  idx <- idx[idx <= length(txt)]
  fit <- lm(txt[idx] ~ values[idx])
  pred <- as.numeric(coef(fit)[1] + coef(fit)[2] * values[idx])
  data.frame(
    segment = seg$segment,
    first = seg$first,
    last = seg$last,
    direct_rmse = sqrt(mean((values[idx] - txt[idx])^2)),
    affine_rmse = sqrt(mean((pred - txt[idx])^2)),
    cor = suppressWarnings(cor(values[idx], txt[idx])),
    slope = unname(coef(fit)[2]),
    intercept = unname(coef(fit)[1]),
    min_value = min(values[idx]),
    max_value = max(values[idx]),
    min_txt = min(txt[idx]),
    max_txt = max(txt[idx])
  )
}))
print(scores, row.names = FALSE)

message("\nWhole trace:")
print(data.frame(
  rmse = sqrt(mean((values[seq_along(txt)] - txt)^2)),
  cor = suppressWarnings(cor(values[seq_along(txt)], txt)),
  first_values = paste(round(head(values, 20), 3), collapse = ", "),
  first_txt = paste(head(txt, 20), collapse = ", ")
), row.names = FALSE)

message("\nMain peak windows:")
for (start in c(3328, 3584, 3840)) {
  end <- start + 12L
  print(data.frame(idx = start:end, txt = txt[start:end], decoded = round(values[start:end], 3), diff = round(values[start:end]) - txt[start:end]), row.names = FALSE)
}

message("\ntest_lcd_ch1_safe_decoder.R completed.")
