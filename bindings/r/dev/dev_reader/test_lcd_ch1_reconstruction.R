#!/usr/bin/env Rscript

source(file.path("dev", "dev_reader", "analyze_lcd_ch1_baseline.R"), local = TRUE)

# Objects created by sourced script: txt, decoded, scaled, rows, value_factor.
segments <- decoded$segments

evaluate <- function(name, reconstructed) {
  n <- min(length(reconstructed), length(txt))
  x <- reconstructed[seq_len(n)]
  y <- txt[seq_len(n)]
  data.frame(
    method = name,
    n = n,
    rmse = sqrt(mean((x - y)^2, na.rm = TRUE)),
    mae = mean(abs(x - y), na.rm = TRUE),
    max_abs = max(abs(x - y), na.rm = TRUE),
    exact_round = identical(round(x), y),
    within_1 = mean(abs(round(x) - y) <= 1, na.rm = TRUE),
    within_10 = mean(abs(round(x) - y) <= 10, na.rm = TRUE),
    stringsAsFactors = FALSE
  )
}

make_segment_fit <- function(kind = c("first", "median", "mean", "linear"), train_start = 1L, train_end = Inf) {
  kind <- match.arg(kind)
  out <- rep(NA_real_, length(txt))
  out[1] <- txt[1]
  for (i in seq_len(nrow(segments))) {
    seg <- segments[i, ]
    idx_dec <- seg$first_point:seg$last_point
    idx_txt <- (seg$first_point + 1L):(seg$last_point + 1L)
    keep <- idx_txt <= length(txt)
    idx_dec <- idx_dec[keep]
    idx_txt <- idx_txt[keep]
    train <- seq_along(idx_txt)
    train <- train[train >= train_start & train <= min(train_end, length(train))]
    if (length(train) == 0L) train <- seq_along(idx_txt)
    residual <- txt[idx_txt[train]] - scaled[idx_dec[train]]
    if (kind == "first") {
      out[idx_txt] <- scaled[idx_dec] + residual[1]
    } else if (kind == "median") {
      out[idx_txt] <- scaled[idx_dec] + median(residual)
    } else if (kind == "mean") {
      out[idx_txt] <- scaled[idx_dec] + mean(residual)
    } else {
      fit <- lm(txt[idx_txt[train]] ~ decoded$signal[idx_dec[train]])
      out[idx_txt] <- as.numeric(coef(fit)[1] + coef(fit)[2] * decoded$signal[idx_dec])
    }
  }
  out
}

methods <- list(
  scaled_only = c(txt[1], scaled),
  segment_first_offset = make_segment_fit("first"),
  segment_median_offset = make_segment_fit("median"),
  segment_mean_offset = make_segment_fit("mean"),
  segment_linear_all = make_segment_fit("linear"),
  segment_linear_first32 = make_segment_fit("linear", train_start = 1L, train_end = 32L),
  segment_median_first32 = make_segment_fit("median", train_start = 1L, train_end = 32L),
  segment_median_last32 = make_segment_fit("median", train_start = 225L, train_end = 256L)
)

message("Reconstruction candidates against TXT Detector A-Ch1:")
scores <- do.call(rbind, lapply(names(methods), function(name) evaluate(name, methods[[name]])))
print(scores[order(scores$rmse), ], row.names = FALSE)

best_name <- scores$method[order(scores$rmse)][1]
best <- methods[[best_name]]
message("\nBest method: ", best_name)
for (start in c(1, 2, 250, 512, 768, 1024, 2048, 3072, 3328, 3584, 3840, 4096)) {
  end <- min(start + 15L, length(txt), length(best))
  message("\nWindow ", start, "-", end)
  print(data.frame(
    idx = start:end,
    txt = txt[start:end],
    reconstructed = round(best[start:end], 3),
    rounded = round(best[start:end]),
    diff = round(best[start:end]) - txt[start:end]
  ), row.names = FALSE)
}

message("\ntest_lcd_ch1_reconstruction.R completed.")
