#!/usr/bin/env Rscript

devtools::load_all()

example_dir <- file.path("dev", "dev_reader", "example_files")
lcd_files <- file.path(example_dir, c("260115_ADC.lcd", "karl.lcd"))

stream_bytes <- function(file, path) {
  listed <- rcpp_lcd_list_streams(file)
  size <- listed$size[listed$path == path]
  stopifnot(length(size) == 1)
  bytes <- rcpp_lcd_inspect_stream(file, path, max_bytes = size)
  as.integer(bytes$u8)
}

u16 <- function(x, pos) x[pos] + bitwShiftL(x[pos + 1L], 8L)
u32 <- function(x, pos) {
  x[pos] + bitwShiftL(x[pos + 1L], 8L) + bitwShiftL(x[pos + 2L], 16L) + bitwShiftL(x[pos + 3L], 24L)
}

decode_delta <- function(value_bytes, endian = c("big", "little"), mode = c("twos", "signed_magnitude")) {
  endian <- match.arg(endian)
  mode <- match.arg(mode)
  value_bytes <- as.integer(value_bytes)
  if (endian == "little" && length(value_bytes) > 1) {
    value_bytes <- rev(value_bytes)
  }
  total_bits <- 8L * length(value_bytes)
  value_bits <- total_bits - 4L
  word <- 0L
  for (b in value_bytes) {
    word <- bitwOr(bitwShiftL(word, 8L), b)
  }
  sign <- bitwAnd(bitwShiftR(word, value_bits), 0x0F)
  value <- bitwAnd(word, bitwShiftL(1L, value_bits) - 1L)
  if (sign %% 2L == 0L) {
    value
  } else if (mode == "twos") {
    -(bitwShiftL(1L, value_bits) - value)
  } else {
    -value
  }
}

decode_rc <- function(x, op = c("add", "subtract"), endian = c("big", "little"), mode = c("twos", "signed_magnitude")) {
  op <- match.arg(op)
  endian <- match.arg(endian)
  mode <- match.arg(mode)
  if (length(x) < 24 || rawToChar(as.raw(x[1:2])) != "RC") {
    return(NULL)
  }
  expected <- u32(x, 9L)
  declared_size <- u32(x, 13L)
  signal <- numeric(expected)
  count <- 1L
  accumulator <- 0
  pos <- 25L
  segments <- 0L
  marker_mismatches <- 0L
  invalid_segments <- 0L

  while (count <= length(signal) && pos + 1L <= length(x)) {
    n_bytes <- u16(x, pos)
    pos <- pos + 2L
    if (n_bytes <= 0L || pos + n_bytes - 1L > length(x)) {
      invalid_segments <- invalid_segments + 1L
      break
    }
    segments <- segments + 1L
    end_payload <- pos + n_bytes - 1L
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
        sign_nibble <- bitwShiftR(current, 4L)
        if (sign_nibble == 0L) {
          delta <- current
          pos <- pos + 1L
        } else if (sign_nibble == 1L) {
          delta <- decode_delta(current, endian = endian, mode = mode)
          pos <- pos + 1L
        } else {
          extra_bytes <- sign_nibble %/% 2L
          if (pos + extra_bytes > end_payload) {
            invalid_segments <- invalid_segments + 1L
            pos <- end_payload + 1L
            break
          }
          delta <- decode_delta(x[pos:(pos + extra_bytes)], endian = endian, mode = mode)
          pos <- pos + 1L + extra_bytes
        }
      }
      accumulator <- if (op == "add") accumulator + delta else accumulator - delta
      signal[count] <- accumulator
      count <- count + 1L
    }
    if (pos + 1L <= length(x)) {
      end_marker <- u16(x, pos)
      if (end_marker != n_bytes) marker_mismatches <- marker_mismatches + 1L
      pos <- pos + 2L
    }
    accumulator <- 0
  }
  list(
    interval_ms = u32(x, 5L),
    expected_points = expected,
    declared_size = declared_size,
    decoded_points = count - 1L,
    segments = segments,
    marker_mismatches = marker_mismatches,
    invalid_segments = invalid_segments,
    first_values = paste(utils::head(signal, 12), collapse = ", ")
  )
}

scan_file <- function(file) {
  message("\nFile: ", file)
  streams <- rcpp_lcd_list_streams(file)
  candidates <- streams[streams$is_chromatogram_candidate & streams$size > 0, ]
  rows <- list()
  for (path in candidates$path) {
    bytes <- stream_bytes(file, path)
    magic <- if (length(bytes) >= 2) rawToChar(as.raw(bytes[1:2])) else ""
    if (magic != "RC") {
      rows[[length(rows) + 1L]] <- data.frame(
        file = basename(file), path = path, size = length(bytes), variant = "not RC",
        interval_ms = NA_integer_, expected_points = NA_integer_, declared_size = NA_integer_,
        decoded_points = NA_integer_, segments = NA_integer_, marker_mismatches = NA_integer_,
        invalid_segments = NA_integer_, first_values = "", stringsAsFactors = FALSE
      )
      next
    }
    for (op in c("add", "subtract")) {
      for (endian in c("big", "little")) {
        for (mode in c("twos", "signed_magnitude")) {
          decoded <- decode_rc(bytes, op = op, endian = endian, mode = mode)
          rows[[length(rows) + 1L]] <- data.frame(
            file = basename(file), path = path, size = length(bytes),
            variant = paste(op, endian, mode, sep = "/"),
            interval_ms = decoded$interval_ms,
            expected_points = decoded$expected_points,
            declared_size = decoded$declared_size,
            decoded_points = decoded$decoded_points,
            segments = decoded$segments,
            marker_mismatches = decoded$marker_mismatches,
            invalid_segments = decoded$invalid_segments,
            first_values = decoded$first_values,
            stringsAsFactors = FALSE
          )
        }
      }
    }
  }
  out <- do.call(rbind, rows)
  print(out[order(out$path, out$marker_mismatches, -out$decoded_points), ], row.names = FALSE)
  invisible(out)
}

result <- do.call(rbind, lapply(lcd_files, scan_file))
message("\nCompact successful-framing rows:")
ok <- result[!is.na(result$marker_mismatches) & result$marker_mismatches == 0 & result$invalid_segments == 0, ]
print(ok[, c("file", "path", "variant", "interval_ms", "expected_points", "decoded_points", "segments", "first_values")], row.names = FALSE)

message("\nscan_lcd_rc_streams.R completed.")
