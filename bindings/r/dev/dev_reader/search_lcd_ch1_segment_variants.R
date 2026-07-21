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

decode_delta <- function(value_bytes, negative_mode = c("twos", "mag"), sign_flip = FALSE) {
  negative_mode <- match.arg(negative_mode)
  value_bytes <- as.integer(value_bytes)
  value_bits <- 8L * length(value_bytes) - 4L
  x <- 0L
  for (b in value_bytes) x <- bitwOr(bitwShiftL(x, 8L), b)
  sign <- bitwAnd(bitwShiftR(x, value_bits), 0x0F)
  value <- bitwAnd(x, bitwShiftL(1L, value_bits) - 1L)
  negative <- sign %% 2L == 1L
  if (sign_flip) negative <- !negative
  if (!negative) return(value)
  if (negative_mode == "twos") -(bitwShiftL(1L, value_bits) - value) else -value
}

decode_segments <- function(x, combine = c("add", "subtract"), negative_mode = c("twos", "mag"), sign_flip = FALSE) {
  combine <- match.arg(combine)
  negative_mode <- match.arg(negative_mode)
  signal <- numeric(u32(x, 9L))
  rows <- list()
  count <- 1L
  pos <- 25L
  segment <- 1L
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
          delta <- decode_delta(x[pos:(pos + extra)], negative_mode, sign_flip)
          pos <- pos + 1L + extra
        }
      }
      accumulator <- if (combine == "add") accumulator + delta else accumulator - delta
      signal[count] <- accumulator
      count <- count + 1L
    }
    rows[[length(rows) + 1L]] <- data.frame(segment = segment, first = first, last = count - 1L)
    if (pos + 1L <= length(x)) pos <- pos + 2L
    segment <- segment + 1L
  }
  list(signal = signal, segments = do.call(rbind, rows))
}

score_segments <- function(decoded, txt) {
  values <- c(txt[1], decoded$signal * value_factor)
  do.call(rbind, lapply(seq_len(nrow(decoded$segments)), function(i) {
    seg <- decoded$segments[i, ]
    idx <- (seg$first + 1L):(seg$last + 1L)
    idx <- idx[idx <= length(txt)]
    if (length(idx) < 10L) return(NULL)
    fit <- lm(txt[idx] ~ values[idx])
    pred <- as.numeric(coef(fit)[1] + coef(fit)[2] * values[idx])
    data.frame(
      segment = seg$segment,
      rmse_direct = sqrt(mean((values[idx] - txt[idx])^2)),
      cor = suppressWarnings(cor(values[idx], txt[idx])),
      affine_slope = unname(coef(fit)[2]),
      affine_rmse = sqrt(mean((pred - txt[idx])^2)),
      first_values = paste(round(head(values[idx], 5), 1), collapse = ", "),
      first_txt = paste(head(txt[idx], 5), collapse = ", ")
    )
  }))
}

bytes <- stream_bytes(lcd_file, stream_path)
txt <- read_txt(txt_file)
grid <- expand.grid(
  combine = c("add", "subtract"),
  negative_mode = c("twos", "mag"),
  sign_flip = c(FALSE, TRUE),
  stringsAsFactors = FALSE
)

all <- list()
for (i in seq_len(nrow(grid))) {
  decoded <- do.call(decode_segments, c(list(x = bytes), grid[i, ]))
  scores <- score_segments(decoded, txt)
  scores <- cbind(grid[i, ], scores)
  all[[length(all) + 1L]] <- scores
}
all <- do.call(rbind, all)

message("Best variants by segment:")
best <- do.call(rbind, lapply(split(all, all$segment), function(df) df[order(df$affine_rmse, df$rmse_direct), ][1:3, ]))
print(best, row.names = FALSE)

message("\nPeak-region direct scores:")
print(all[all$segment %in% 14:16, ][order(all[all$segment %in% 14:16, ]$rmse_direct), ], row.names = FALSE)

message("\nsearch_lcd_ch1_segment_variants.R completed.")
