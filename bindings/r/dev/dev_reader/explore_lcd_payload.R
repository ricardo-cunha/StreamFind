#!/usr/bin/env Rscript

devtools::load_all()

example_dir <- file.path("dev", "dev_reader", "example_files")
lcd_file <- file.path(example_dir, "260115_ADC.lcd")
txt_file <- file.path(example_dir, "260115_ADC.txt")
stream_path <- "LC Raw Data/Chromatogram Ch1"

read_txt_chromatogram <- function(file, block_name) {
  lines <- readLines(file, warn = FALSE)
  start <- which(lines == paste0("[LC Chromatogram(", block_name, ")]"))
  stopifnot(length(start) == 1)
  end <- start + which(lines[(start + 1):length(lines)] == "")[1] - 1
  block <- lines[start:end]
  multiplier <- as.numeric(strsplit(block[grepl("^Intensity Multiplier\t", block)], "\t")[[1]][2])
  header <- which(block == "R.Time (min)\tIntensity")
  data_lines <- block[(header + 1):length(block)]
  parts <- strsplit(data_lines, "\t")
  rt <- as.numeric(vapply(parts, `[`, character(1), 1))
  intensity <- as.numeric(vapply(parts, `[`, character(1), 2))
  data.frame(rt = rt, intensity = intensity * multiplier, raw_intensity = intensity)
}

inspect_full_stream <- function(file, path) {
  listed <- rcpp_lcd_list_streams(file)
  size <- listed$size[listed$path == path]
  stopifnot(length(size) == 1)
  bytes <- rcpp_lcd_inspect_stream(file, path, max_bytes = size)
  list(
    size = attr(bytes, "stream_size"),
    u8 = as.integer(bytes$u8)
  )
}

as_i8 <- function(x) ifelse(x >= 128L, x - 256L, x)

read_i16_le <- function(x, offset) {
  n <- floor((length(x) - offset + 1) / 2)
  if (n <= 0) {
    return(integer())
  }
  i <- offset + (seq_len(n) - 1L) * 2L
  value <- x[i] + bitwShiftL(x[i + 1L], 8L)
  ifelse(value >= 32768L, value - 65536L, value)
}

read_i16_be <- function(x, offset) {
  n <- floor((length(x) - offset + 1) / 2)
  if (n <= 0) {
    return(integer())
  }
  i <- offset + (seq_len(n) - 1L) * 2L
  value <- bitwShiftL(x[i], 8L) + x[i + 1L]
  ifelse(value >= 32768L, value - 65536L, value)
}

signed_nibbles <- function(x, offset) {
  payload <- x[offset:length(x)]
  hi <- bitwShiftR(payload, 4L)
  lo <- bitwAnd(payload, 0x0F)
  vals <- as.vector(rbind(hi, lo))
  ifelse(vals >= 8L, vals - 16L, vals)
}

zigzag_varints <- function(x, offset) {
  out <- integer()
  value <- 0L
  shift <- 0L
  for (b in x[offset:length(x)]) {
    value <- value + bitwShiftL(bitwAnd(b, 0x7F), shift)
    if (bitwAnd(b, 0x80) == 0L) {
      decoded <- if (bitwAnd(value, 1L) == 0L) bitwShiftR(value, 1L) else -bitwShiftR(value + 1L, 1L)
      out <- c(out, decoded)
      value <- 0L
      shift <- 0L
    } else {
      shift <- shift + 7L
    }
  }
  out
}

plain_varints <- function(x, offset) {
  out <- integer()
  value <- 0L
  shift <- 0L
  for (b in x[offset:length(x)]) {
    value <- value + bitwShiftL(bitwAnd(b, 0x7F), shift)
    if (bitwAnd(b, 0x80) == 0L) {
      out <- c(out, value)
      value <- 0L
      shift <- 0L
    } else {
      shift <- shift + 7L
    }
  }
  out
}

read_u16_vec <- function(x, pos) {
  x[pos] + bitwShiftL(x[pos + 1L], 8L)
}

decode_shimadzu_delta <- function(value_bytes) {
  value_bytes <- as.integer(value_bytes)
  total_bits <- 8L * length(value_bytes)
  value_bits <- total_bits - 4L
  x <- 0L
  for (b in value_bytes) {
    x <- bitwOr(bitwShiftL(x, 8L), b)
  }
  sign <- bitwAnd(bitwShiftR(x, value_bits), 0x0F)
  value <- bitwAnd(x, bitwShiftL(1L, value_bits) - 1L)
  if (sign %% 2L == 1L) {
    -(bitwShiftL(1L, value_bits) - value)
  } else {
    value
  }
}

decode_rc_subsegments <- function(x) {
  n_points_minus_one <- read_u16_vec(x, 9L)
  signal <- numeric(n_points_minus_one)
  count <- 1L
  accumulator <- 0
  pos <- 25L

  while (count < length(signal) && pos + 1L <= length(x)) {
    n_bytes <- read_u16_vec(x, pos)
    pos <- pos + 2L
    if (n_bytes <= 0L || pos + n_bytes - 1L > length(x)) {
      break
    }
    end_payload <- pos + n_bytes - 1L
    while (pos <= end_payload && count < length(signal)) {
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
          delta <- decode_shimadzu_delta(current)
          pos <- pos + 1L
        } else {
          extra_bytes <- sign_nibble %/% 2L
          if (pos + extra_bytes > end_payload) {
            break
          }
          delta <- decode_shimadzu_delta(x[pos:(pos + extra_bytes)])
          pos <- pos + 1L + extra_bytes
        }
      }
      accumulator <- accumulator + delta
      signal[count] <- accumulator
      count <- count + 1L
    }
    if (pos + 1L <= length(x)) {
      end_marker <- read_u16_vec(x, pos)
      pos <- pos + 2L
      if (end_marker != n_bytes) {
        message("Subsegment marker mismatch at byte ", pos - 2L, ": start=", n_bytes, " end=", end_marker)
      }
    }
    accumulator <- 0
  }
  signal
}

score_candidate <- function(name, values, target, expected_n) {
  if (length(values) == 0) {
    return(NULL)
  }
  n <- min(length(values), length(target), expected_n)
  first_n <- min(n, 50L)
  data.frame(
    decoder = name,
    decoded_n = length(values),
    first_rmse = sqrt(mean((values[seq_len(first_n)] - target[seq_len(first_n)])^2)),
    first_max_abs = max(abs(values[seq_len(first_n)] - target[seq_len(first_n)])),
    first_values = paste(utils::head(values, 12), collapse = ", "),
    stringsAsFactors = FALSE
  )
}

stride_values <- function(values, stride, phase) {
  if (length(values) < phase) {
    return(numeric())
  }
  values[seq.int(phase, length(values), by = stride)]
}

try_mem_decompress <- function(bytes, offset, type) {
  raw_payload <- as.raw(bytes[offset:length(bytes)])
  result <- try(memDecompress(raw_payload, type = type), silent = TRUE)
  if (inherits(result, "try-error")) {
    return(NULL)
  }
  as.integer(result)
}

txt <- read_txt_chromatogram(txt_file, "Detector A-Ch1")
stream <- inspect_full_stream(lcd_file, stream_path)
bytes <- stream$u8

magic <- rawToChar(as.raw(bytes[1:2]))
interval_ms <- bytes[5] + bitwShiftL(bytes[6], 8L) + bitwShiftL(bytes[7], 16L) + bitwShiftL(bytes[8], 24L)
interval_count <- bytes[9] + bitwShiftL(bytes[10], 8L) + bitwShiftL(bytes[11], 16L) + bitwShiftL(bytes[12], 24L)
declared_size <- bytes[13] + bitwShiftL(bytes[14], 8L) + bitwShiftL(bytes[15], 16L) + bitwShiftL(bytes[16], 24L)
expected_n <- interval_count + 1L

message("Stream: ", stream_path)
message("Magic: ", magic)
message("Interval ms: ", interval_ms)
message("Interval count: ", interval_count)
message("Expected points: ", expected_n)
message("Declared size: ", declared_size)
message("Actual size: ", stream$size)
message("TXT points: ", nrow(txt))
message("TXT first raw values: ", paste(head(txt$raw_intensity, 12), collapse = ", "))

cc_style <- decode_rc_subsegments(bytes)
message("\nDocumented RC subsegment decoder candidate:")
message("Decoded points: ", length(cc_style))
message("First values: ", paste(head(cc_style, 12), collapse = ", "))
message("First 12 TXT excluding first point: ", paste(head(txt$raw_intensity[-1], 12), collapse = ", "))
message("Matches TXT[-1] exactly: ", identical(as.numeric(cc_style), as.numeric(txt$raw_intensity[-1])))
message("Max abs diff vs TXT[-1]: ", max(abs(cc_style - txt$raw_intensity[-1]), na.rm = TRUE))

candidate_rows <- list()
for (offset in 17:65) {
  payload_i8 <- as_i8(bytes[offset:length(bytes)])
  candidate_rows[[length(candidate_rows) + 1L]] <- score_candidate(paste0("i8 direct @", offset - 1L), payload_i8, txt$raw_intensity, expected_n)
  candidate_rows[[length(candidate_rows) + 1L]] <- score_candidate(paste0("i8 cumsum @", offset - 1L), cumsum(payload_i8), txt$raw_intensity, expected_n)

  i16_le <- read_i16_le(bytes, offset)
  i16_be <- read_i16_be(bytes, offset)
  candidate_rows[[length(candidate_rows) + 1L]] <- score_candidate(paste0("i16le direct @", offset - 1L), i16_le, txt$raw_intensity, expected_n)
  candidate_rows[[length(candidate_rows) + 1L]] <- score_candidate(paste0("i16le cumsum @", offset - 1L), cumsum(i16_le), txt$raw_intensity, expected_n)
  candidate_rows[[length(candidate_rows) + 1L]] <- score_candidate(paste0("i16be direct @", offset - 1L), i16_be, txt$raw_intensity, expected_n)
  candidate_rows[[length(candidate_rows) + 1L]] <- score_candidate(paste0("i16be cumsum @", offset - 1L), cumsum(i16_be), txt$raw_intensity, expected_n)

  nib <- signed_nibbles(bytes, offset)
  nib_cumsum <- cumsum(nib)
  candidate_rows[[length(candidate_rows) + 1L]] <- score_candidate(paste0("nibble cumsum @", offset - 1L), nib_cumsum, txt$raw_intensity, expected_n)
  for (stride in 2:8) {
    for (phase in seq_len(stride)) {
      candidate_rows[[length(candidate_rows) + 1L]] <- score_candidate(
        paste0("nibble cumsum stride", stride, " phase", phase, " @", offset - 1L),
        stride_values(nib_cumsum, stride, phase),
        txt$raw_intensity,
        expected_n
      )
    }
  }

  zz <- zigzag_varints(bytes, offset)
  pv <- plain_varints(bytes, offset)
  candidate_rows[[length(candidate_rows) + 1L]] <- score_candidate(paste0("zigzag varint @", offset - 1L), zz, txt$raw_intensity, expected_n)
  candidate_rows[[length(candidate_rows) + 1L]] <- score_candidate(paste0("zigzag varint cumsum @", offset - 1L), cumsum(zz), txt$raw_intensity, expected_n)
  candidate_rows[[length(candidate_rows) + 1L]] <- score_candidate(paste0("plain varint @", offset - 1L), pv, txt$raw_intensity, expected_n)
}

for (type in c("gzip", "zlib")) {
  for (offset in 1:65) {
    decompressed <- try_mem_decompress(bytes, offset, type)
    if (!is.null(decompressed)) {
      candidate_rows[[length(candidate_rows) + 1L]] <- score_candidate(paste0(type, " bytes @", offset - 1L), decompressed, txt$raw_intensity, expected_n)
      candidate_rows[[length(candidate_rows) + 1L]] <- score_candidate(paste0(type, " i8 cumsum @", offset - 1L), cumsum(as_i8(decompressed)), txt$raw_intensity, expected_n)
    }
  }
}

scores <- do.call(rbind, candidate_rows)
scores <- scores[order(scores$first_rmse, scores$first_max_abs, abs(scores$decoded_n - expected_n)), ]

message("\nBest candidate decoders by first 50-point RMSE:")
print(utils::head(scores, 30), row.names = FALSE)

message("\nCandidates with decoded length near expected point count:")
near_n <- scores[abs(scores$decoded_n - expected_n) <= 25, ]
print(utils::head(near_n, 30), row.names = FALSE)

message("\nBest stride-5 nibble candidates:")
stride5 <- scores[grepl("nibble cumsum stride5", scores$decoder), ]
print(utils::head(stride5, 30), row.names = FALSE)

message("\nexplore_lcd_payload.R completed.")
