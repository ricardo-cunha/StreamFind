#!/usr/bin/env Rscript

devtools::load_all()

example_dir <- file.path("dev", "dev_reader", "example_files")
lcd_file <- file.path(example_dir, "260115_ADC.lcd")
txt_file <- file.path(example_dir, "260115_ADC.txt")

stream_bytes <- function(file, path) {
  listed <- rcpp_lcd_list_streams(file)
  size <- listed$size[listed$path == path]
  stopifnot(length(size) == 1)
  bytes <- rcpp_lcd_inspect_stream(file, path, max_bytes = size)
  as.integer(bytes$u8)
}

u16 <- function(x, pos) x[pos] + bitwShiftL(x[pos + 1L], 8L)
u32 <- function(x, pos) x[pos] + bitwShiftL(x[pos + 1L], 8L) + bitwShiftL(x[pos + 2L], 16L) + bitwShiftL(x[pos + 3L], 24L)

decode_delta <- function(value_bytes, little = FALSE) {
  value_bytes <- as.integer(value_bytes)
  total_bits <- 8L * length(value_bytes)
  value_bits <- total_bits - 4L
  x <- 0L
  iter <- if (little) rev(value_bytes) else value_bytes
  for (b in iter) x <- bitwOr(bitwShiftL(x, 8L), b)
  sign <- bitwAnd(bitwShiftR(x, value_bits), 0x0F)
  value <- bitwAnd(x, bitwShiftL(1L, value_bits) - 1L)
  if (sign %% 2L == 1L) -(bitwShiftL(1L, value_bits) - value) else value
}

decode_rc <- function(x, mode = c("add_be", "sub_be", "add_le", "sub_le", "continuous_add_be", "continuous_sub_be")) {
  mode <- match.arg(mode)
  n_points <- u32(x, 9L)
  signal <- numeric(n_points)
  count <- 1L
  accumulator <- 0
  pos <- 25L
  little <- grepl("_le$", mode)
  subtract <- grepl("sub", mode)
  continuous <- grepl("continuous", mode)

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
          delta <- decode_delta(x[pos:(pos + extra)], little = little)
          pos <- pos + 1L + extra
        }
      }
      accumulator <- if (subtract) accumulator - delta else accumulator + delta
      signal[count] <- accumulator
      count <- count + 1L
    }
    if (pos + 1L <= length(x)) pos <- pos + 2L
    if (!continuous) accumulator <- 0
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
    header <- which(block == "R.Time (min)\tIntensity")
    if (length(header) != 1L) next
    data_lines <- block[(header + 1L):length(block)]
    data_lines <- data_lines[nzchar(data_lines)]
    parts <- strsplit(data_lines, "\t")
    out[[name]] <- as.numeric(vapply(parts, `[`, character(1), 2))
  }
  out
}

score <- function(values, target) {
  candidates <- list(
    direct = values,
    plus_initial = c(target[1], values),
    drop_first = values[-1]
  )
  do.call(rbind, lapply(names(candidates), function(alignment) {
    v <- candidates[[alignment]]
    n <- min(length(v), length(target))
    if (n < 10L) return(NULL)
    v <- v[seq_len(n)]
    t <- target[seq_len(n)]
    fit <- lm(t ~ v)
    pred <- as.numeric(coef(fit)[1] + coef(fit)[2] * v)
    data.frame(
      alignment = alignment,
      n = n,
      first_rmse = sqrt(mean((v[1:min(50L, n)] - t[1:min(50L, n)])^2)),
      affine_rmse = sqrt(mean((pred - t)^2)),
      affine_intercept = unname(coef(fit)[1]),
      affine_slope = unname(coef(fit)[2]),
      cor = suppressWarnings(cor(v, t)),
      first_values = paste(head(v, 8), collapse = ", "),
      stringsAsFactors = FALSE
    )
  }))
}

txt <- read_txt_blocks(txt_file)
streams <- c("LC Raw Data/Chromatogram Ch1", "LC Raw Data/Chromatogram Ch5")
modes <- c("add_be", "sub_be", "add_le", "sub_le", "continuous_add_be", "continuous_sub_be")

for (stream in streams) {
  bytes <- stream_bytes(lcd_file, stream)
  message("\nStream: ", stream)
  for (mode in modes) {
    decoded <- decode_rc(bytes, mode)
    for (target_name in c("Detector A-Ch1", "AD1")) {
      result <- score(decoded, txt[[target_name]])
      result$mode <- mode
      result$target <- target_name
      result$decoded_n <- length(decoded)
      best <- result[order(result$affine_rmse, -abs(result$cor)), ][1, ]
      print(best[, c("target", "mode", "alignment", "decoded_n", "n", "first_rmse", "affine_rmse", "affine_intercept", "affine_slope", "cor", "first_values")], row.names = FALSE)
    }
  }
}

status_streams <- c(
  "LC Raw Data/StatusLog Ch1",
  "LC Raw Data/StatusLog Ch2",
  "LC Raw Data/StatusLog Ch4",
  "LC Raw Data/StatusLog Ch5",
  "LC Raw Data/StatusLog Ch6",
  "LC Raw Data/StatusLog Ch7"
)
status_targets <- setdiff(names(txt), c("Detector A-Ch1", "AD1"))

message("\nStatusLog best matches after metadata-like factors:")
for (stream in status_streams) {
  bytes <- stream_bytes(lcd_file, stream)
  decoded <- decode_rc(bytes, "add_be")
  best_rows <- list()
  for (factor in c(1, 0.1, 0.01)) {
    values <- decoded * factor
    for (target_name in status_targets) {
      result <- score(values, txt[[target_name]])
      result$target <- target_name
      result$factor <- factor
      best_rows[[length(best_rows) + 1L]] <- result[order(result$affine_rmse, -abs(result$cor)), ][1, ]
    }
  }
  all_rows <- do.call(rbind, best_rows)
  best <- all_rows[order(all_rows$first_rmse, all_rows$affine_rmse), ][1:3, ]
  message("\nStream: ", stream, " decoded_n=", length(decoded))
  print(best[, c("target", "factor", "alignment", "n", "first_rmse", "affine_rmse", "affine_intercept", "affine_slope", "cor", "first_values")], row.names = FALSE)
}

message("\ncompare_lcd_rc_to_txt.R completed.")
