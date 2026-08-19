#!/usr/bin/env Rscript

devtools::load_all()

example_dir <- file.path("dev", "dev_reader", "example_files")
lcd_file <- file.path(example_dir, "260115_ADC_angepasst.lcd")
txt_file <- file.path(example_dir, "260115_ADC_angepasst.txt")

stream_bytes <- function(file, path) {
  listed <- rcpp_lcd_list_streams(file)
  size <- listed$size[listed$path == path]
  stopifnot(length(size) == 1)
  bytes <- rcpp_lcd_inspect_stream(file, path, max_bytes = size)
  as.integer(bytes$u8)
}

u16 <- function(x, pos) x[pos] + bitwShiftL(x[pos + 1L], 8L)
u32 <- function(x, pos) x[pos] + bitwShiftL(x[pos + 1L], 8L) + bitwShiftL(x[pos + 2L], 16L) + bitwShiftL(x[pos + 3L], 24L)

decode_delta <- function(value_bytes) {
  value_bytes <- as.integer(value_bytes)
  value_bits <- 8L * length(value_bytes) - 4L
  x <- 0L
  for (b in value_bytes) x <- bitwOr(bitwShiftL(x, 8L), b)
  sign <- bitwAnd(bitwShiftR(x, value_bits), 0x0F)
  value <- bitwAnd(x, bitwShiftL(1L, value_bits) - 1L)
  if (sign %% 2L == 1L) -(bitwShiftL(1L, value_bits) - value) else value
}

decode_rc <- function(x) {
  n_points <- u32(x, 9L)
  signal <- numeric(n_points)
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

read_txt_blocks <- function(path) {
  lines <- readLines(path, warn = FALSE)
  starts <- grep("^\\[LC (Chromatogram|Status Trace)\\(", lines)
  out <- list()
  for (i in seq_along(starts)) {
    start <- starts[i]
    end <- if (i < length(starts)) starts[i + 1L] - 1L else length(lines)
    block <- lines[start:end]
    name <- sub("^\\[LC (Chromatogram|Status Trace)\\((.*)\\)\\]$", "\\2", block[1])
    multiplier <- 1
    mult_line <- grep("^Intensity Multiplier\\t", block, value = TRUE)
    if (length(mult_line) == 1L) multiplier <- as.numeric(strsplit(mult_line, "\\t")[[1]][2])
    header <- which(block == "R.Time (min)\tIntensity")
    if (length(header) != 1L) next
    data_lines <- block[(header + 1L):length(block)]
    data_lines <- data_lines[nzchar(data_lines)]
    parts <- strsplit(data_lines, "\t")
    out[[name]] <- data.frame(
      rt = as.numeric(vapply(parts, `[`, character(1), 1)),
      intensity = as.numeric(vapply(parts, `[`, character(1), 2)) * multiplier,
      stringsAsFactors = FALSE
    )
  }
  out
}

score_trace <- function(rt, intensity, target) {
  n <- min(length(intensity), nrow(target))
  d <- data.frame(
    n = n,
    rmse = sqrt(mean((intensity[seq_len(n)] - target$intensity[seq_len(n)])^2)),
    max_abs = max(abs(intensity[seq_len(n)] - target$intensity[seq_len(n)])),
    cor = suppressWarnings(cor(intensity[seq_len(n)], target$intensity[seq_len(n)])),
    first_lcd = paste(head(intensity, 8), collapse = ", "),
    first_txt = paste(head(target$intensity, 8), collapse = ", "),
    stringsAsFactors = FALSE
  )
  d
}

best_alignment <- function(decoded, interval_ms, factor, target, prepend = FALSE) {
  candidates <- list(direct = decoded)
  candidates$prepended_first <- c(decoded[1], decoded)
  do.call(rbind, lapply(names(candidates), function(alignment) {
    values <- candidates[[alignment]]
    rt <- seq_along(values) - 1L
    rt <- rt * interval_ms / 60000
    result <- score_trace(rt, values * factor, target)
    data.frame(alignment = alignment, result, stringsAsFactors = FALSE)
  }))
}

txt <- read_txt_blocks(txt_file)

checks <- list(
  list(stream = "LC Raw Data/Chromatogram Ch1", id = "Detector A-Ch1", factor = 0.00476837158203125 * 0.001),
  list(stream = "LC Raw Data/Chromatogram Ch5", id = "AD1", factor = 0.2 * 0.001),
  list(stream = "LC Raw Data/StatusLog Ch1", id = "Pump A Pressure", factor = 0.1),
  list(stream = "LC Raw Data/StatusLog Ch2", id = "Pump B Pressure", factor = 0.1),
  list(stream = "LC Raw Data/StatusLog Ch4", id = "Oven Temp.", factor = 0.01),
  list(stream = "LC Raw Data/StatusLog Ch5", id = "Room Temp.", factor = 0.01),
  list(stream = "LC Raw Data/StatusLog Ch6", id = "Sample Cooler Temp.", factor = 0.01),
  list(stream = "LC Raw Data/StatusLog Ch7", id = "UV Cell Temp.", factor = 0.01)
)

rows <- lapply(checks, function(check) {
  bytes <- stream_bytes(lcd_file, check$stream)
  interval_ms <- u32(bytes, 5L)
  decoded <- decode_rc(bytes)
  aligned <- best_alignment(decoded, interval_ms, check$factor, txt[[check$id]])
  if (startsWith(check$stream, "LC Raw Data/StatusLog")) {
    best <- aligned[aligned$alignment == "prepended_first", ]
    n_lcd <- length(decoded) + 1L
  } else {
    best <- aligned[order(aligned$rmse), ][1, ]
    n_lcd <- if (best$alignment == "prepended_first") length(decoded) + 1L else length(decoded)
  }
  data.frame(id = check$id, stream = check$stream, n_lcd = n_lcd, n_txt = nrow(txt[[check$id]]), best, stringsAsFactors = FALSE)
})

out <- do.call(rbind, rows)
print(out[, c("id", "stream", "alignment", "n_lcd", "n_txt", "n", "rmse", "max_abs", "cor", "first_lcd", "first_txt")], row.names = FALSE)

message("\ncompare_lcd_angepasst_to_txt.R completed.")
