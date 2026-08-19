#!/usr/bin/env Rscript

devtools::load_all()

lcd_file <- file.path("dev", "dev_reader", "example_files", "karl.lcd")
txt_file <- file.path("dev", "dev_reader", "example_files", "karl.txt")

stream_bytes <- function(path) {
  listed <- rcpp_lcd_list_streams(lcd_file)
  size <- listed$size[listed$path == path]
  stopifnot(length(size) == 1L)
  as.integer(rcpp_lcd_inspect_stream(lcd_file, path, max_bytes = size)$u8)
}

hex <- function(x) paste(sprintf("%02X", x), collapse = " ")
ascii <- function(x) paste(ifelse(x >= 32L & x <= 126L, rawToChar(as.raw(x), multiple = TRUE), "."), collapse = "")
u16 <- function(x, pos) if (pos + 1L <= length(x)) x[pos] + x[pos + 1L] * 256 else NA_real_
u32 <- function(x, pos) if (pos + 3L <= length(x)) x[pos] + x[pos + 1L] * 256 + x[pos + 2L] * 65536 + x[pos + 3L] * 16777216 else NA_real_
i32 <- function(x, pos) { v <- u32(x, pos); ifelse(is.na(v), NA_real_, ifelse(v >= 2^31, v - 2^32, v)) }
f32 <- function(x, pos) if (pos + 3L <= length(x)) readBin(as.raw(x[pos:(pos + 3L)]), "numeric", n = 1, size = 4, endian = "little") else NA_real_
f64 <- function(x, pos) if (pos + 7L <= length(x)) readBin(as.raw(x[pos:(pos + 7L)]), "numeric", n = 1, size = 8, endian = "little") else NA_real_

bytes <- stream_bytes("TLM Raw Data/Mass Parameters")
message("Mass Parameters length: ", length(bytes))

message("\nTXT MS chromatogram reference:")
project <- ProjectMassSpec$new(tempfile(fileext = ".duckdb"), "karl_txt_tlm_reference", file_paths = txt_file)
txt_headers <- project$get_chromatograms_headers()
txt_ms <- txt_headers[signal_type == "MS"]
txt_cols <- intersect(c("index", "id", "chromatogram_id", "polarity", "precursor_mz", "pre_mz", "activation_ce", "pre_ce", "product_mz", "pro_mz"), names(txt_ms))
print(txt_ms[, ..txt_cols], row.names = FALSE)

message("\nASCII strings in Mass Parameters:")
chars <- bytes >= 32L & bytes <= 126L
runs <- rle(chars)
ends <- cumsum(runs$lengths)
starts <- ends - runs$lengths + 1L
strings <- data.frame()
for (i in seq_along(runs$values)) {
  if (isTRUE(runs$values[i]) && runs$lengths[i] >= 3L) {
    pos <- starts[i]:ends[i]
    strings <- rbind(strings, data.frame(offset0 = starts[i] - 1L, text = paste(rawToChar(as.raw(bytes[pos]), multiple = TRUE), collapse = "")))
  }
}
print(strings, row.names = FALSE)

message("\nDecoded 760-byte compound records:")
read_c_string <- function(x, pos, max_len) {
  end <- min(length(x), pos + max_len - 1L)
  raw <- x[pos:end]
  nul <- which(raw == 0L)[1]
  if (!is.na(nul)) raw <- raw[seq_len(nul - 1L)]
  paste(rawToChar(as.raw(raw), multiple = TRUE), collapse = "")
}
records <- list()
for (compound in seq_len(20L)) {
  start0 <- 256L + (compound - 1L) * 760L
  pos <- start0 + 1L
  compound_name <- read_c_string(bytes, pos + 16L, 128L)
  records[[compound]] <- data.frame(
    compound = compound,
    offset0 = start0,
    header_u32_0 = u32(bytes, pos),
    method_type = u16(bytes, pos + 4L),
    compound_index = u16(bytes, pos + 6L),
    name_len = u32(bytes, pos + 8L),
    window_start = u32(bytes, pos + 144L) / 1000,
    window_end = u32(bytes, pos + 148L) / 1000,
    record_ce = u32(bytes, pos + 152L),
    transition_count = u32(bytes, pos + 156L),
    field_160 = u32(bytes, pos + 160L),
    field_164 = u32(bytes, pos + 164L),
    name = compound_name,
    stringsAsFactors = FALSE
  )
}
compound_records <- do.call(rbind, records)
print(compound_records, row.names = FALSE)

message("\nDecoded transition subrecords:")
transition_records <- list()
for (compound in seq_len(20L)) {
  start0 <- 256L + (compound - 1L) * 760L
  compound_name <- compound_records$name[compound]
  for (slot in 0:1) {
    t0 <- start0 + 512L + slot * 110L
    pos <- t0 + 1L
    precursor <- u32(bytes, pos + 6L) / 10000
    product <- u32(bytes, pos + 10L) / 10000
    if (!is.finite(precursor) || precursor <= 0 || product <= 0) next
    transition_records[[length(transition_records) + 1L]] <- data.frame(
      compound = compound,
      name = compound_name,
      slot = slot + 1L,
      offset0 = t0,
      rec_len = u32(bytes, pos),
      type = u16(bytes, pos + 4L),
      precursor_mz = precursor,
      product_mz = product,
      ce = u32(bytes, pos + 14L),
      dwell = u32(bytes, pos + 18L),
      flag22 = u32(bytes, pos + 22L),
      flag26 = u32(bytes, pos + 26L),
      i32_30 = i32(bytes, pos + 30L),
      i32_34 = i32(bytes, pos + 34L),
      i32_38 = i32(bytes, pos + 38L),
      u32_42 = u32(bytes, pos + 42L),
      stringsAsFactors = FALSE
    )
  }
}
transition_records <- do.call(rbind, transition_records)
print(transition_records, row.names = FALSE)

message("\nTransition records joined to TXT product chromatograms by m/z:")
txt_products <- txt_ms[!is.na(pre_mz) & !is.na(pro_mz)]
joined <- merge(
  transition_records,
  as.data.frame(txt_products[, .(txt_id = chromatogram_id, txt_polarity = polarity, txt_pre_mz = pre_mz, txt_pro_mz = pro_mz)]),
  by.x = c("precursor_mz", "product_mz"),
  by.y = c("txt_pre_mz", "txt_pro_mz"),
  all.x = TRUE,
  sort = FALSE
)
print(joined[, c("compound", "name", "slot", "precursor_mz", "product_mz", "ce", "dwell", "flag22", "flag26", "txt_polarity", "txt_id")], row.names = FALSE)

message("\nFirst bytes:")
for (off in seq(0L, min(length(bytes) - 1L, 2048L), by = 64L)) {
  rng <- (off + 1L):min(length(bytes), off + 64L)
  cat(sprintf("%05d  %s  %s\n", off, hex(bytes[rng]), ascii(bytes[rng])))
}

message("\nPotential record sizes:")
for (record_size in c(32L, 36L, 40L, 44L, 48L, 52L, 56L, 60L, 64L, 68L, 72L, 76L, 80L, 84L, 88L, 92L, 96L, 100L, 104L, 108L, 112L, 116L, 120L, 124L, 128L, 132L, 136L, 140L, 144L, 148L, 152L, 156L, 160L, 164L, 168L, 172L, 176L, 180L, 184L, 188L, 192L)) {
  if (length(bytes) %% record_size == 0L) {
    message("record_size=", record_size, " records=", length(bytes) / record_size)
  }
}

scan_records <- function(record_size, offset0 = 0L, n = 20L) {
  starts <- offset0 + (seq_len(min(n, floor((length(bytes) - offset0) / record_size))) - 1L) * record_size + 1L
  data.frame(
    rec = seq_along(starts),
    offset0 = starts - 1L,
    u32_0 = vapply(starts, function(pos) u32(bytes, pos), numeric(1)),
    u32_4 = vapply(starts, function(pos) u32(bytes, pos + 4L), numeric(1)),
    u32_8 = vapply(starts, function(pos) u32(bytes, pos + 8L), numeric(1)),
    u32_12 = vapply(starts, function(pos) u32(bytes, pos + 12L), numeric(1)),
    u32_16 = vapply(starts, function(pos) u32(bytes, pos + 16L), numeric(1)),
    f32_0 = vapply(starts, function(pos) f32(bytes, pos), numeric(1)),
    f32_4 = vapply(starts, function(pos) f32(bytes, pos + 4L), numeric(1)),
    f32_8 = vapply(starts, function(pos) f32(bytes, pos + 8L), numeric(1)),
    f32_12 = vapply(starts, function(pos) f32(bytes, pos + 12L), numeric(1)),
    f32_16 = vapply(starts, function(pos) f32(bytes, pos + 16L), numeric(1))
  )
}

message("\nRecord previews:")
for (record_size in c(72L, 76L, 80L, 84L, 88L, 92L, 96L, 100L, 104L, 108L, 112L, 116L, 120L, 124L, 128L, 132L, 136L, 140L, 144L, 148L, 152L, 156L, 160L, 164L, 168L, 172L, 176L, 180L, 184L, 188L, 192L)) {
  if (length(bytes) %% record_size == 0L) {
    message("\nrecord_size=", record_size)
    print(utils::head(scan_records(record_size), 12), row.names = FALSE)
  }
}

message("\nValues near expected m/z or CE by offset:")
hits <- data.frame()
for (pos in seq_len(length(bytes) - 3L)) {
  vals <- c(u32 = u32(bytes, pos), i32 = i32(bytes, pos), f32 = f32(bytes, pos))
  scaled100 <- vals[c("u32", "i32")] / 100
  scaled1000 <- vals[c("u32", "i32")] / 1000
  candidates <- c(vals, scaled100 = scaled100, scaled1000 = scaled1000)
  good <- is.finite(candidates) & ((candidates >= 50 & candidates <= 400) | (candidates >= 1 & candidates <= 80))
  if (any(good)) {
    hits <- rbind(hits, data.frame(offset0 = pos - 1L, kind = names(candidates)[good], value = unname(candidates[good])))
  }
}
print(utils::head(hits, 200), row.names = FALSE)

message("\ninspect_karl_tlm_mass_parameters.R completed.")
