#!/usr/bin/env Rscript

devtools::load_all()

example_dir <- file.path("dev", "dev_reader", "example_files")
lcd_file <- file.path(example_dir, "260115_ADC.lcd")
txt_file <- file.path(example_dir, "260115_ADC.txt")

status_streams <- c(
  "LC Raw Data/Chromatogram Status",
  "LC Raw Data/StatusLog Status"
)

stream_bytes <- function(file, path) {
  listed <- rcpp_lcd_list_streams(file)
  size <- listed$size[listed$path == path]
  stopifnot(length(size) == 1)
  bytes <- rcpp_lcd_inspect_stream(file, path, max_bytes = size)
  as.integer(bytes$u8)
}

u16 <- function(x, pos) {
  if (pos + 1L > length(x)) return(NA_integer_)
  x[pos] + bitwShiftL(x[pos + 1L], 8L)
}

u32 <- function(x, pos) {
  if (pos + 3L > length(x)) return(NA_real_)
  x[pos] + bitwShiftL(x[pos + 1L], 8L) + bitwShiftL(x[pos + 2L], 16L) + bitwShiftL(x[pos + 3L], 24L)
}

f64 <- function(x, pos) {
  if (pos + 7L > length(x)) return(NA_real_)
  readBin(as.raw(x[pos:(pos + 7L)]), what = "numeric", n = 1, size = 8, endian = "little")
}

ascii <- function(x) {
  x <- x[x != 0L]
  x <- x[x >= 32L & x <= 126L]
  if (length(x) == 0L) return("")
  rawToChar(as.raw(x), multiple = FALSE)
}

scan_records <- function(path, bytes) {
  starts <- which(
    bytes == 1L &
      seq_along(bytes) + 63L <= length(bytes) &
      bytes[seq_along(bytes) + 8L] == 8L &
      bytes[seq_along(bytes) + 9L] == 15L &
      bytes[seq_along(bytes) + 10L] == 32L
  )

  records <- lapply(starts, function(pos) {
    data.frame(
      offset0 = pos - 1L,
      flag = u32(bytes, pos),
      code = u16(bytes, pos + 4L),
      stream_channel = bytes[pos + 6L],
      descriptor_byte7 = bytes[pos + 7L],
      descriptor_u32_8 = u32(bytes, pos + 8L),
      descriptor_u32_12 = u32(bytes, pos + 12L),
      value_factor = f64(bytes, pos + 16L),
      field_double_24 = f64(bytes, pos + 24L),
      field_double_32 = f64(bytes, pos + 32L),
      unit = ascii(bytes[(pos + 40L):min(pos + 63L, length(bytes))])
    )
  })
  if (length(records) == 0L) {
    return(data.frame())
  }
  do.call(rbind, records)
}

find_ascii <- function(bytes, needle) {
  pattern <- as.integer(charToRaw(needle))
  if (length(bytes) < length(pattern)) return(integer())
  starts <- seq_len(length(bytes) - length(pattern) + 1L)
  starts[vapply(starts, function(pos) all(bytes[pos:(pos + length(pattern) - 1L)] == pattern), logical(1))]
}

scan_units <- function(bytes, needles = c("mV", "kgf/cm2", "C")) {
  rows <- list()
  for (needle in needles) {
    starts <- find_ascii(bytes, needle)
    for (pos in starts) {
      base <- max(1L, pos - 48L)
      end <- min(length(bytes), pos + 48L)
      rows[[length(rows) + 1L]] <- data.frame(
        unit = needle,
        unit_offset0 = pos - 1L,
        context_offset0 = base - 1L,
        context_ascii = ascii(bytes[base:end]),
        d_m40 = f64(bytes, pos - 40L),
        d_m32 = f64(bytes, pos - 32L),
        d_m24 = f64(bytes, pos - 24L),
        d_m16 = f64(bytes, pos - 16L),
        d_m8 = f64(bytes, pos - 8L),
        d_p8 = f64(bytes, pos + 8L),
        u16_m8 = u16(bytes, pos - 8L),
        u16_m6 = u16(bytes, pos - 6L),
        u16_m4 = u16(bytes, pos - 4L),
        u16_m2 = u16(bytes, pos - 2L),
        stringsAsFactors = FALSE
      )
    }
  }
  if (length(rows) == 0L) return(data.frame())
  do.call(rbind, rows)
}

parse_txt_blocks <- function(path) {
  lines <- readLines(path, warn = FALSE)
  block_starts <- grep("^\\[LC (Chromatogram|Status Trace)\\(", lines)
  rows <- lapply(seq_along(block_starts), function(i) {
    start <- block_starts[i]
    end <- if (i < length(block_starts)) block_starts[i + 1L] - 1L else length(lines)
    block <- lines[start:end]
    header <- block[1]
    signal <- sub("^\\[(.*)\\]$", "\\1", header)
    name <- sub("^LC (Chromatogram|Status Trace)\\((.*)\\)$", "\\2", signal)
    type <- sub("^LC (Chromatogram|Status Trace)\\(.*$", "\\1", signal)
    get_value <- function(key) {
      hit <- grep(paste0("^", key, "\t"), block, fixed = FALSE, value = TRUE)
      if (length(hit) == 0L) return(NA_character_)
      sub(paste0("^", key, "\t"), "", hit[1])
    }
    data.frame(
      type = type,
      name = name,
      intensity_units = get_value("Intensity Units"),
      intensity_multiplier = suppressWarnings(as.numeric(get_value("Intensity Multiplier"))),
      sampling_interval = suppressWarnings(as.numeric(get_value("Sampling Interval"))),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

stopifnot(file.exists(lcd_file), file.exists(txt_file))

for (path in status_streams) {
  bytes <- stream_bytes(lcd_file, path)
  message("\nStream: ", path, " size=", length(bytes))
  records <- scan_records(path, bytes)
  print(records, row.names = FALSE)
  message("Unit occurrences with nearby numeric fields:")
  print(scan_units(bytes), row.names = FALSE)
}

message("\nTXT block metadata:")
print(parse_txt_blocks(txt_file), row.names = FALSE)

message("\nscan_lcd_status_metadata.R completed.")
