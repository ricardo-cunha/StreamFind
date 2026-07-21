#!/usr/bin/env Rscript

source(file.path("dev", "dev_reader", "analyze_lcd_ch1_baseline.R"), local = TRUE)

segments <- decoded$segments
values <- scaled

message("Best shifts per segment for scaled Ch1 vs TXT:")
rows <- lapply(seq_len(nrow(segments)), function(i) {
  seg <- segments[i, ]
  idx_dec <- seg$first_point:seg$last_point
  best <- NULL
  for (shift in -300:300) {
    idx_txt <- idx_dec + 1L + shift
    keep <- idx_txt >= 1L & idx_txt <= length(txt)
    if (sum(keep) < 30L) next
    v <- values[idx_dec[keep]]
    t <- txt[idx_txt[keep]]
    fit <- lm(t ~ v)
    pred <- as.numeric(coef(fit)[1] + coef(fit)[2] * v)
    row <- data.frame(
      segment = seg$segment,
      shift = shift,
      n = length(v),
      cor = suppressWarnings(cor(v, t)),
      affine_rmse = sqrt(mean((pred - t)^2)),
      slope = unname(coef(fit)[2]),
      intercept = unname(coef(fit)[1]),
      direct_rmse = sqrt(mean((v - t)^2))
    )
    best <- rbind(best, row)
  }
  best[order(best$affine_rmse, -abs(best$cor)), ][1:5, ]
})
rows <- do.call(rbind, rows)
print(rows, row.names = FALSE)

message("\nDirect best shifts around main peak:")
print(rows[rows$segment %in% 13:17, ][order(rows[rows$segment %in% 13:17, ]$direct_rmse), ], row.names = FALSE)

message("\nsearch_lcd_ch1_alignment.R completed.")
