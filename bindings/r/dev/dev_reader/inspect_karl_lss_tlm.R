#!/usr/bin/env Rscript

devtools::load_all()

example_dir <- file.path("dev", "dev_reader", "example_files")
lcd_file <- file.path(example_dir, "karl.lcd")
txt_file <- file.path(example_dir, "karl.txt")

stream_bytes <- function(path, size = NULL) {
  listed <- rcpp_lcd_list_streams(lcd_file)
  stream_size <- listed$size[listed$path == path]
  stopifnot(length(stream_size) == 1L)
  if (is.null(size)) size <- stream_size
  as.integer(rcpp_lcd_inspect_stream(lcd_file, path, max_bytes = size)$u8)
}

u16 <- function(x, pos) x[pos] + x[pos + 1L] * 256
u32 <- function(x, pos) x[pos] + x[pos + 1L] * 256 + x[pos + 2L] * 65536 + x[pos + 3L] * 16777216

hex <- function(x) paste(sprintf("%02X", x), collapse = " ")
ascii <- function(x) paste(ifelse(x >= 32L & x <= 126L, rawToChar(as.raw(x), multiple = TRUE), "."), collapse = "")

decode_delta <- function(value_bytes) {
  value_bytes <- as.integer(value_bytes)
  value_bits <- 8L * length(value_bytes) - 4L
  word <- 0L
  for (b in value_bytes) word <- bitwOr(bitwShiftL(word, 8L), b)
  sign <- bitwAnd(bitwShiftR(word, value_bits), 0x0F)
  value <- bitwAnd(word, bitwShiftL(1L, value_bits) - 1L)
  if (sign %% 2L == 1L) -(bitwShiftL(1L, value_bits) - value) else value
}

decode_rc <- function(x) {
  stopifnot(length(x) >= 24L, rawToChar(as.raw(x[1:2])) == "RC")
  n_points <- u32(x, 9L)
  signal <- numeric(n_points)
  count <- 1L
  pos <- 25L
  segments <- 0L
  marker_mismatches <- 0L
  while (count <= length(signal) && pos + 1L <= length(x)) {
    n_bytes <- u16(x, pos)
    pos <- pos + 2L
    if (n_bytes <= 0L || pos + n_bytes - 1L > length(x)) break
    segments <- segments + 1L
    end_payload <- pos + n_bytes - 1L
    accumulator <- 0
    while (pos <= end_payload && count <= length(signal)) {
      current <- x[pos]
      if (current == 0x82L) {
        pos <- pos + 1L
        next
      }
      if (current == 0x00L) {
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
    if (pos + 1L <= length(x)) {
      end_marker <- u16(x, pos)
      if (end_marker != n_bytes) marker_mismatches <- marker_mismatches + 1L
      pos <- pos + 2L
    }
  }
  list(
    values = signal,
    interval_ms = u32(x, 5L),
    expected_points = n_points,
    decoded_points = count - 1L,
    segments = segments,
    marker_mismatches = marker_mismatches
  )
}

read_lc_status_blocks <- function(path) {
  lines <- readLines(path, warn = FALSE)
  starts <- grep("^\\[LC Status Trace\\(", lines)
  out <- list()
  meta <- list()
  for (i in seq_along(starts)) {
    start <- starts[i]
    end <- if (i < length(starts)) starts[i + 1L] - 1L else length(lines)
    block <- lines[start:end]
    name <- sub("^\\[LC Status Trace\\((.*)\\)\\]$", "\\1", block[1])
    header <- which(block == "R.Time (min)\tIntensity")
    if (length(header) != 1L) next
    interval <- as.numeric(sub("^Interval\\(msec\\)\\t", "", block[grep("^Interval\\(msec\\)", block)[1]]))
    points <- as.integer(sub("^# of Points\\t", "", block[grep("^# of Points", block)[1]]))
    data_lines <- block[(header + 1L):length(block)]
    data_lines <- data_lines[nzchar(data_lines)]
    parts <- strsplit(data_lines, "\t")
    out[[name]] <- as.numeric(vapply(parts, `[`, character(1), 2))
    meta[[name]] <- data.frame(name = name, interval_ms = interval, points = points)
  }
  list(values = out, meta = do.call(rbind, meta))
}

score <- function(values, target) {
  candidates <- list(direct = values, plus_initial = c(target[1], values))
  do.call(rbind, lapply(names(candidates), function(alignment) {
    v <- candidates[[alignment]]
    n <- min(length(v), length(target))
    if (n < 10L) return(NULL)
    v <- v[seq_len(n)]
    t <- target[seq_len(n)]
    data.frame(
      alignment = alignment,
      n = n,
      first_rmse = sqrt(mean((v[seq_len(min(50L, n))] - t[seq_len(min(50L, n))])^2)),
      rmse = sqrt(mean((v - t)^2)),
      cor = suppressWarnings(cor(v, t)),
      first_values = paste(head(v, 8), collapse = ", "),
      stringsAsFactors = FALSE
    )
  }))
}

status <- read_lc_status_blocks(txt_file)
message("TXT LC status blocks:")
print(status$meta, row.names = FALSE)

streams <- rcpp_lcd_list_streams(lcd_file)
raw_streams <- streams[streams$size > 0 & grepl("^(LSS Raw Data|TLM Raw Data)", streams$path), ]
message("\nNon-empty LSS/TLM raw streams:")
print(raw_streams[, c("path", "size", "is_chromatogram_candidate")], row.names = FALSE)

for (path in raw_streams$path) {
  bytes <- stream_bytes(path, min(raw_streams$size[raw_streams$path == path][1], 64))
  message("\nStream header: ", path)
  cat("HEX: ", hex(bytes), "\n", sep = "")
  cat("ASCII: ", ascii(bytes), "\n", sep = "")
}

message("\nLSS RC status-log scores:")
for (path in raw_streams$path[grepl("^LSS Raw Data/StatusLog Ch", raw_streams$path)]) {
  bytes <- stream_bytes(path)
  if (length(bytes) < 24L || rawToChar(as.raw(bytes[1:2])) != "RC") next
  decoded <- decode_rc(bytes)
  rows <- list()
  for (factor in c(1, 0.1, 0.01)) {
    values <- decoded$values * factor
    for (target_name in names(status$values)) {
      result <- score(values, status$values[[target_name]])
      result$stream <- path
      result$factor <- factor
      result$target <- target_name
      rows[[length(rows) + 1L]] <- result[order(result$first_rmse, result$rmse), ][1, ]
    }
  }
  all_rows <- do.call(rbind, rows)
  best <- all_rows[order(all_rows$first_rmse, all_rows$rmse), ][1:min(5L, nrow(all_rows)), ]
  message("\nStream: ", path, "; interval_ms=", decoded$interval_ms, "; expected=", decoded$expected_points, "; decoded=", decoded$decoded_points, "; segments=", decoded$segments, "; marker_mismatches=", decoded$marker_mismatches)
  print(best[, c("stream", "target", "factor", "alignment", "n", "first_rmse", "rmse", "cor", "first_values")], row.names = FALSE)
}

message("\ninspect_karl_lss_tlm.R completed.")
