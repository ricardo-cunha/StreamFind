#!/usr/bin/env Rscript

devtools::load_all()

example_dir <- file.path("dev", "dev_reader", "example_files")
lcd_file <- file.path(example_dir, "260115_ADC.lcd")
streams_to_inspect <- c(
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

i32 <- function(x, pos) {
  value <- u32(x, pos)
  if (is.na(value)) return(NA_real_)
  if (value >= 2^31) value - 2^32 else value
}

f32 <- function(x, pos) {
  if (pos + 3L > length(x)) return(NA_real_)
  raw <- as.raw(x[pos:(pos + 3L)])
  readBin(raw, what = "numeric", n = 1, size = 4, endian = "little")
}

f64 <- function(x, pos) {
  if (pos + 7L > length(x)) return(NA_real_)
  raw <- as.raw(x[pos:(pos + 7L)])
  readBin(raw, what = "numeric", n = 1, size = 8, endian = "little")
}

hex_line <- function(x) paste(sprintf("%02X", x), collapse = " ")

printable <- function(x) {
  chars <- ifelse(x >= 32L & x <= 126L, rawToChar(as.raw(x), multiple = TRUE), ".")
  paste(chars, collapse = "")
}

numeric_summary <- function(record, offsets) {
  data.frame(
    offset = offsets - 1L,
    u16 = vapply(offsets, function(pos) u16(record, pos), integer(1)),
    i32 = vapply(offsets, function(pos) i32(record, pos), numeric(1)),
    f32 = vapply(offsets, function(pos) f32(record, pos), numeric(1)),
    f64 = vapply(offsets, function(pos) f64(record, pos), numeric(1))
  )
}

inspect_records <- function(path, bytes, record_size, header_size = 0L, max_records = 12L) {
  payload <- bytes[(header_size + 1L):length(bytes)]
  n_records <- floor(length(payload) / record_size)
  remainder <- length(payload) %% record_size
  message("\nRecord size ", record_size, ", header ", header_size, ": records=", n_records, ", remainder=", remainder)

  for (i in seq_len(min(n_records, max_records))) {
    start <- (i - 1L) * record_size + 1L
    record <- payload[start:(start + record_size - 1L)]
    message("\n  Record ", i, " byte range ", header_size + start - 1L, "-", header_size + start + record_size - 2L)
    cat("  hex: ", hex_line(record), "\n", sep = "")
    cat("  txt: ", printable(record), "\n", sep = "")
    offsets <- seq(1L, min(record_size, 57L), by = 4L)
    print(numeric_summary(record, offsets), row.names = FALSE)
  }
}

inspect_raw_offsets <- function(path, bytes) {
  message("\nWhole-stream common offsets for ", path)
  offsets <- c(1L, 5L, 9L, 13L, 17L, 21L, 25L, 29L, 33L, 37L, 41L, 45L, 49L, 53L, 57L, 61L)
  print(numeric_summary(bytes, offsets), row.names = FALSE)
}

stopifnot(file.exists(lcd_file))

for (path in streams_to_inspect) {
  bytes <- stream_bytes(lcd_file, path)
  message("\n========================================")
  message("Stream: ", path)
  message("Size: ", length(bytes))
  cat("First 128 hex:\n", hex_line(bytes[1:min(128, length(bytes))]), "\n", sep = "")
  cat("First 128 txt:\n", printable(bytes[1:min(128, length(bytes))]), "\n", sep = "")
  inspect_raw_offsets(path, bytes)

  for (header_size in c(0L, 16L, 32L, 40L, 48L, 64L)) {
    for (record_size in c(16L, 24L, 28L, 32L, 40L, 48L, 56L, 64L, 80L, 96L, 128L)) {
      if (header_size < length(bytes) && (length(bytes) - header_size) >= record_size) {
        rem <- (length(bytes) - header_size) %% record_size
        if (rem == 0L || record_size %in% c(32L, 64L)) {
          inspect_records(path, bytes, record_size = record_size, header_size = header_size, max_records = 4L)
        }
      }
    }
  }
}

message("\ninspect_lcd_status_records.R completed.")
