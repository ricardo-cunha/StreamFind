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

decode_value <- function(bytes, endian, negative_mode, high_source) {
  bytes <- as.integer(bytes)
  iter <- if (endian == "le") rev(bytes) else bytes
  packed <- 0L
  for (b in iter) packed <- bitwOr(bitwShiftL(packed, 8L), b)
  total_bits <- length(bytes) * 8L
  value_bits <- total_bits - 4L
  high <- if (high_source == "first") bitwShiftR(bytes[1], 4L) else bitwAnd(bytes[1], 0x0F)
  value <- bitwAnd(packed, bitwShiftL(1L, value_bits) - 1L)
  negative <- high %% 2L == 1L
  if (!negative) return(value)
  if (negative_mode == "twos") return(-(bitwShiftL(1L, value_bits) - value))
  -value
}

total_bytes_for <- function(high, mode) {
  switch(mode,
    upstream = 1L + high %/% 2L,
    ceil_half = max(1L, ceiling(high / 2L)),
    floor_half = max(1L, high %/% 2L),
    high_minus_one = max(1L, high - 1L),
    one = 1L,
    1L + high %/% 2L
  )
}

decode_variant <- function(x, start_pos, length_mode, endian, negative_mode, combine_mode, reset_mode, zero_mode, high_source) {
  n_points <- u32(x, 9L)
  signal <- numeric(n_points)
  count <- 1L
  accumulator <- 0
  pos <- start_pos
  while (count < length(signal) && pos + 1L <= length(x)) {
    n_bytes <- u16(x, pos)
    pos <- pos + 2L
    if (n_bytes <= 0L || pos + n_bytes - 1L > length(x)) break
    end_payload <- pos + n_bytes - 1L
    while (pos <= end_payload && count < length(signal)) {
      current <- x[pos]
      if (current == 0x82L) {
        pos <- pos + 1L
        next
      }
      if (current == 0x00L && zero_mode == "zero_delta") {
        delta <- 0L
        pos <- pos + 1L
      } else {
        high <- if (high_source == "first") bitwShiftR(current, 4L) else bitwAnd(current, 0x0F)
        total_bytes <- if (high == 0L && length_mode != "one") 1L else total_bytes_for(high, length_mode)
        if (pos + total_bytes - 1L > end_payload) break
        if (high == 0L && zero_mode == "literal_byte") {
          delta <- current
        } else {
          delta <- decode_value(x[pos:(pos + total_bytes - 1L)], endian, negative_mode, high_source)
        }
        pos <- pos + total_bytes
      }
      accumulator <- if (combine_mode == "subtract") accumulator - delta else accumulator + delta
      signal[count] <- accumulator
      count <- count + 1L
    }
    if (pos + 1L <= length(x)) pos <- pos + 2L
    if (reset_mode == "segment") accumulator <- 0
  }
  signal
}

score <- function(values, target) {
  alignments <- list(direct = values, plus_initial = c(target[1], values), drop_first = values[-1])
  best <- NULL
  for (name in names(alignments)) {
    v <- alignments[[name]]
    n <- min(length(v), length(target))
    if (n < 100L) next
    v <- v[seq_len(n)]
    t <- target[seq_len(n)]
    first_n <- min(50L, n)
    cor_value <- suppressWarnings(cor(v, t))
    row <- data.frame(
      alignment = name,
      n = n,
      first_rmse = sqrt(mean((v[seq_len(first_n)] - t[seq_len(first_n)])^2)),
      cor = cor_value,
      first_values = paste(head(v, 10), collapse = ", "),
      stringsAsFactors = FALSE
    )
    best <- rbind(best, row)
  }
  best[order(best$first_rmse, -abs(best$cor)), ][1, ]
}

bytes <- stream_bytes(lcd_file, stream_path)
target <- read_txt_chrom(txt_file, "Detector A-Ch1")

grid <- expand.grid(
  start_pos = c(25L),
  length_mode = c("upstream", "ceil_half", "floor_half", "high_minus_one", "one"),
  endian = c("be", "le"),
  negative_mode = c("twos", "signed_mag"),
  combine_mode = c("add", "subtract"),
  reset_mode = c("segment", "continuous"),
  zero_mode = c("zero_delta", "literal_byte"),
  high_source = c("first"),
  stringsAsFactors = FALSE
)

rows <- lapply(seq_len(nrow(grid)), function(i) {
  params <- grid[i, ]
  values <- tryCatch(do.call(decode_variant, c(list(x = bytes), params)), error = function(e) numeric())
  if (length(values) == 0L) return(NULL)
  s <- score(values, target)
  cbind(params, decoded_n = length(values), s)
})
rows <- do.call(rbind, rows)
rows <- rows[order(rows$first_rmse, -abs(rows$cor)), ]

message("Best Ch1 codec variants against Detector A-Ch1 raw TXT:")
print(head(rows, 30), row.names = FALSE)

message("\nsearch_lcd_ch1_codec_variants.R completed.")
