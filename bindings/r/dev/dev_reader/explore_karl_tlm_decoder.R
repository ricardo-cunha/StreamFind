#!/usr/bin/env Rscript

devtools::load_all()

example_dir <- file.path("dev", "dev_reader", "example_files")
lcd_file <- file.path(example_dir, "karl.lcd")
mzml_file <- file.path(example_dir, "karl.mzML")

stream_bytes <- function(path) {
  listed <- rcpp_lcd_list_streams(lcd_file)
  size <- listed$size[listed$path == path]
  stopifnot(length(size) == 1L)
  as.integer(rcpp_lcd_inspect_stream(lcd_file, path, max_bytes = size)$u8)
}

u16 <- function(x, pos) if (pos + 1L <= length(x)) x[pos] + x[pos + 1L] * 256 else NA_real_
u32 <- function(x, pos) if (pos + 3L <= length(x)) x[pos] + x[pos + 1L] * 256 + x[pos + 2L] * 65536 + x[pos + 3L] * 16777216 else NA_real_
i32 <- function(x, pos) { v <- u32(x, pos); ifelse(is.na(v), NA_real_, ifelse(v >= 2^31, v - 2^32, v)) }
f32 <- function(x, pos) if (pos + 3L <= length(x)) readBin(as.raw(x[pos:(pos + 3L)]), "numeric", n = 1, size = 4, endian = "little") else NA_real_
f64 <- function(x, pos) if (pos + 7L <= length(x)) readBin(as.raw(x[pos:(pos + 7L)]), "numeric", n = 1, size = 8, endian = "little") else NA_real_
hex <- function(x) paste(sprintf("%02X", x), collapse = " ")
ascii <- function(x) paste(ifelse(x >= 32L & x <= 126L, rawToChar(as.raw(x), multiple = TRUE), "."), collapse = "")

u32_seq <- function(bytes, offset0 = 0L, stride = 4L) {
  starts <- seq(offset0 + 1L, length(bytes) - 3L, by = stride)
  vapply(starts, function(pos) u32(bytes, pos), numeric(1))
}

i64ish_records <- function(bytes, record_size) {
  n <- floor(length(bytes) / record_size)
  starts <- (seq_len(n) - 1L) * record_size + 1L
  data.frame(
    record = seq_len(n),
    offset0 = starts - 1L,
    u32_0 = vapply(starts, function(pos) u32(bytes, pos), numeric(1)),
    u32_4 = vapply(starts, function(pos) u32(bytes, pos + 4L), numeric(1)),
    u32_8 = vapply(starts, function(pos) u32(bytes, pos + 8L), numeric(1)),
    u32_12 = vapply(starts, function(pos) u32(bytes, pos + 12L), numeric(1))
  )
}

message("TLM stream summaries:")
streams <- rcpp_lcd_list_streams(lcd_file)
tlm <- streams[grepl("^TLM Raw Data", streams$path) & streams$size > 0, ]
print(tlm[, c("path", "size")], row.names = FALSE)

for (path in tlm$path) {
  bytes <- stream_bytes(path)
  message("\nStream: ", path, " size=", length(bytes))
  cat("HEX64: ", hex(bytes[1:min(64L, length(bytes))]), "\n", sep = "")
  cat("ASCII64: ", ascii(bytes[1:min(64L, length(bytes))]), "\n", sep = "")
  cat("u32 first 24: ", paste(head(u32_seq(bytes), 24), collapse = ", "), "\n", sep = "")
}

rt_bytes <- stream_bytes("TLM Raw Data/Retention Time")
rt_u32 <- u32_seq(rt_bytes)
message("\nRetention Time u32 summary:")
print(data.frame(
  n = length(rt_u32),
  first = paste(head(rt_u32, 12), collapse = ", "),
  diff_first = paste(head(diff(rt_u32), 12), collapse = ", "),
  min = min(rt_u32),
  max = max(rt_u32)
), row.names = FALSE)

sumtic <- stream_bytes("TLM Raw Data/SumTIC Data")
message("\nSumTIC 12-byte records:")
sumtic12 <- i64ish_records(sumtic, 12L)
print(head(sumtic12, 20), row.names = FALSE)
message("record count=", nrow(sumtic12))

tic <- stream_bytes("TLM Raw Data/TIC Data")
message("\nTIC 8-byte records:")
tic8 <- i64ish_records(tic, 8L)
print(head(tic8, 20), row.names = FALSE)
message("record count=", nrow(tic8))

status_curve <- stream_bytes("TLM Raw Data/Status Curve")
message("\nStatus Curve 28-byte and 32-byte record previews:")
print(head(i64ish_records(status_curve, 28L), 20), row.names = FALSE)
print(head(i64ish_records(status_curve, 32L), 20), row.names = FALSE)

index <- stream_bytes("TLM Raw Data/Spectrum Index")
message("\nSpectrum Index previews:")
for (record_size in c(16L, 20L, 24L, 28L, 32L, 36L, 40L, 44L, 48L, 52L, 56L, 60L, 64L, 68L)) {
  if (length(index) %% record_size == 0L) {
    message("record_size=", record_size, " records=", length(index) / record_size)
    print(head(i64ish_records(index, record_size), 12), row.names = FALSE)
  }
}

ms_raw <- stream_bytes("TLM Raw Data/MS Raw Data")
index24 <- i64ish_records(index, 24L)
message("\nSpectrum Index 24-byte first rows:")
print(head(index24, 30), row.names = FALSE)

decompress_chunk <- function(offset0, size) {
  start <- offset0 + 1L
  chunk <- as.raw(ms_raw[start:(start + size - 1L)])
  declared_size <- readBin(chunk[5:8], "integer", n = 1, size = 4, endian = "little", signed = FALSE)
  declared_uncompressed <- readBin(chunk[9:12], "integer", n = 1, size = 4, endian = "little", signed = FALSE)
  payload <- chunk[13:length(chunk)]
  out <- tryCatch(memDecompress(payload, type = "gzip"), error = function(e) raw())
  if (length(out) == 0L) out <- tryCatch(memDecompress(payload, type = "unknown"), error = function(e) raw())
  list(
    declared_size = declared_size,
    declared_uncompressed = declared_uncompressed,
    payload_size = length(payload),
    raw = out
  )
}

message("\nMS Raw decompressed chunk previews:")
for (i in seq_len(12L)) {
  row <- index24[i, ]
  dec <- decompress_chunk(row$u32_8, row$u32_0)
  bytes <- as.integer(dec$raw)
  cat(sprintf(
    "chunk %d offset=%d size=%d type=%d scanish=%d declared_size=%d declared_uncompressed=%d decompressed=%d\n",
    i, row$u32_8, row$u32_0, row$u32_4, row$u32_12, dec$declared_size, dec$declared_uncompressed, length(bytes)
  ))
  if (length(bytes) > 0L) {
    cat("  hex: ", hex(bytes[1:min(96L, length(bytes))]), "\n", sep = "")
    cat("  u32: ", paste(vapply(seq(1L, min(length(bytes) - 3L, 80L), by = 4L), function(pos) u32(bytes, pos), numeric(1)), collapse = ", "), "\n", sep = "")
    cat("  f32: ", paste(signif(vapply(seq(1L, min(length(bytes) - 3L, 80L), by = 4L), function(pos) f32(bytes, pos), numeric(1)), 8), collapse = ", "), "\n", sep = "")
  }
}

message("\nmzML via ProjectMassSpec:")
work_dir <- tempfile("tlm_mzml_project_")
dir.create(work_dir)
mzml_copy <- file.path(work_dir, "karl_mzml.mzML")
file.copy(mzml_file, mzml_copy, overwrite = TRUE)
project <- ProjectMassSpec$new(tempfile(fileext = ".duckdb"), "tlm_mzml_reference", file_paths = mzml_copy)
analyses <- project$get_analyses()
print(analyses[, c("analysis", "format", "type", "number_spectra", "number_chromatograms", "start_rt", "end_rt")])
sh <- project$get_spectra_headers()
message("Spectra first rows:")
print(head(sh[, c("index", "array_length", "level", "polarity", "rt", "lowmz", "highmz", "tic")], 24), row.names = FALSE)
ch <- project$get_chromatograms_headers()
message("Chromatogram headers:")
ch_cols <- intersect(c("index", "id", "array_length", "chromatogram_type", "precursor_mz", "product_mz", "polarity"), names(ch))
print(ch[, ..ch_cols], row.names = FALSE)
raw_ch <- project$get_raw_chromatograms(chromatograms = head(ch$id, 4))
message("First mzML chromatogram raw points:")
print(head(raw_ch, 30), row.names = FALSE)

message("\nexplore_karl_tlm_decoder.R completed.")
