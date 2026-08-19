#!/usr/bin/env Rscript

devtools::load_all()

example_dir <- file.path("dev", "dev_reader", "example_files")
lcd_file <- file.path(example_dir, "260115_ADC.lcd")
txt_file <- file.path(example_dir, "260115_ADC.txt")
value_factor <- 0.00476837158203125

stream_bytes <- function(file, path, size) {
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

decode_rc <- function(x) {
  if (length(x) < 25L || rawToChar(as.raw(x[1:2])) != "RC") return(numeric())
  signal <- numeric(u32(x, 9L))
  count <- 1L
  pos <- 25L
  while (count < length(signal) && pos + 1L <= length(x)) {
    n_bytes <- u16(x, pos)
    pos <- pos + 2L
    if (n_bytes <= 0L || pos + n_bytes - 1L > length(x)) break
    end_payload <- pos + n_bytes - 1L
    accumulator <- 0
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
    if (pos + 1L <= length(x)) pos <- pos + 2L
  }
  signal
}

score <- function(values, target) {
  candidates <- list(
    raw = values,
    scaled = values * value_factor,
    scaled_plus_initial = c(target[1], values * value_factor)
  )
  rows <- lapply(names(candidates), function(mode) {
    v <- candidates[[mode]]
    n <- min(length(v), length(target))
    if (n < 100L) return(NULL)
    v <- v[seq_len(n)]
    t <- target[seq_len(n)]
    fit <- lm(t ~ v)
    pred <- as.numeric(coef(fit)[1] + coef(fit)[2] * v)
    data.frame(
      mode = mode,
      n = n,
      rmse_affine = sqrt(mean((pred - t)^2)),
      cor = suppressWarnings(cor(v, t)),
      intercept = unname(coef(fit)[1]),
      slope = unname(coef(fit)[2]),
      stringsAsFactors = FALSE
    )
  })
  rows <- do.call(rbind, rows)
  rows[order(rows$rmse_affine, -abs(rows$cor)), ][1, ]
}

target <- read_txt_chrom(txt_file, "Detector A-Ch1")
streams <- rcpp_lcd_list_streams(lcd_file)
streams <- streams[streams$size > 24, ]

rows <- list()
for (i in seq_len(nrow(streams))) {
  bytes <- stream_bytes(lcd_file, streams$path[i], streams$size[i])
  decoded <- tryCatch(decode_rc(bytes), error = function(e) numeric())
  if (length(decoded) < 100L) next
  s <- score(decoded, target)
  rows[[length(rows) + 1L]] <- data.frame(
    path = streams$path[i],
    size = streams$size[i],
    interval_ms = u32(bytes, 5L),
    count = u32(bytes, 9L),
    decoded_n = length(decoded),
    s,
    stringsAsFactors = FALSE
  )
}

rows <- do.call(rbind, rows)
rows <- rows[order(rows$rmse_affine, -abs(rows$cor)), ]
message("Best RC-like LCD streams against TXT Detector A-Ch1:")
print(head(rows, 30), row.names = FALSE)

message("\nfind_lcd_detector_ch1_stream.R completed.")
