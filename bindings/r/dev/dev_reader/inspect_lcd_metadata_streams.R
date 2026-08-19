#!/usr/bin/env Rscript

devtools::load_all()

example_dir <- file.path("dev", "dev_reader", "example_files")
lcd_file <- file.path(example_dir, "260115_ADC.lcd")

stream_bytes <- function(file, path) {
  listed <- rcpp_lcd_list_streams(file)
  size <- listed$size[listed$path == path]
  stopifnot(length(size) == 1)
  bytes <- rcpp_lcd_inspect_stream(file, path, max_bytes = size)
  as.integer(bytes$u8)
}

bytes_to_text <- function(bytes) {
  raw <- as.raw(bytes)
  raw <- raw[raw != as.raw(0)]
  raw <- raw[as.integer(raw) %in% c(9, 10, 13, 32:126)]
  rawToChar(raw, multiple = FALSE)
}

safe_text <- function(bytes) {
  tryCatch(bytes_to_text(bytes), error = function(e) "")
}

show_matches <- function(text, pattern, context = 120) {
  loc <- gregexpr(pattern, text, ignore.case = TRUE, perl = TRUE)[[1]]
  if (identical(loc, -1L)) {
    return(invisible(NULL))
  }
  for (pos in head(loc, 12)) {
    start <- max(1L, pos - context)
    end <- min(nchar(text), pos + attr(loc, "match.length")[1] + context)
    snippet <- substr(text, start, end)
    snippet <- gsub("[\r\n\t]+", " ", snippet)
    cat("  ...", snippet, "...\n", sep = "")
  }
}

stopifnot(file.exists(lcd_file))
streams <- rcpp_lcd_list_streams(lcd_file)

patterns <- c(
  "2d data item$",
  "detector channel",
  "multi chromato table$",
  "file property$",
  "method",
  "gumm_information",
  "chromatogram status",
  "statuslog status",
  "lc configuration$",
  "system configuration$"
)

is_candidate <- Reduce(`|`, lapply(patterns, function(pattern) {
  grepl(pattern, streams$normalized_path, ignore.case = TRUE)
}))
candidates <- streams[is_candidate & streams$size > 0, ]

message("Metadata-ish streams in: ", lcd_file)
print(candidates[, c("path", "size", "is_mini_stream")], row.names = FALSE)

for (path in candidates$path) {
  bytes <- stream_bytes(lcd_file, path)
  text <- safe_text(bytes)
  printable_ratio <- if (nchar(text) == 0) 0 else mean(as.integer(charToRaw(text)) >= 32 & as.integer(charToRaw(text)) <= 126)

  message("\nStream: ", path)
  message("Size: ", length(bytes), "; text chars after null stripping: ", nchar(text), "; printable ratio: ", round(printable_ratio, 3))
  if (nchar(text) == 0) {
    next
  }

  cat("First text snippet:\n")
  first <- substr(gsub("[\r\n\t]+", " ", text), 1, 500)
  cat(first, "\n")

  message("Matches for metadata markers:")
  show_matches(text, "(<DDI|<Axis|<VF>|<Unit>|<DN>|<DSCN>|<ADN>|detector|Detector|Intensity|Multiplier|Rate|DLT|AT|CF|GF|mV|nm|Status|Chromatogram)")
}

message("\ninspect_lcd_metadata_streams.R completed.")
