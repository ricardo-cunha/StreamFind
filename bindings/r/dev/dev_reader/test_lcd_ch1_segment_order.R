#!/usr/bin/env Rscript

source(file.path("dev", "dev_reader", "analyze_lcd_ch1_baseline.R"), local = TRUE)

value_factor <- 0.00476837158203125
segments <- decoded$segments

make_values <- function(reverse_segments = integer(), negate_segments = integer()) {
  sig <- decoded$signal
  for (seg_id in reverse_segments) {
    seg <- segments[segments$segment == seg_id, ]
    idx <- seg$first_point:seg$last_point
    sig[idx] <- rev(sig[idx])
  }
  for (seg_id in negate_segments) {
    seg <- segments[segments$segment == seg_id, ]
    idx <- seg$first_point:seg$last_point
    sig[idx] <- -sig[idx]
  }
  c(txt[1], sig * value_factor)
}

score <- function(values, label) {
  idx <- seq_along(txt)
  peak <- 3330:4096
  data.frame(
    label = label,
    whole_rmse = sqrt(mean((values[idx] - txt)^2)),
    peak_rmse = sqrt(mean((values[peak] - txt[peak])^2)),
    peak_cor = suppressWarnings(cor(values[peak], txt[peak])),
    stringsAsFactors = FALSE
  )
}

candidates <- list(
  normal = make_values(),
  reverse_14 = make_values(14),
  reverse_15 = make_values(15),
  reverse_16 = make_values(16),
  reverse_14_15 = make_values(c(14, 15)),
  reverse_15_16 = make_values(c(15, 16)),
  reverse_14_16 = make_values(14:16),
  reverse_14_17 = make_values(14:17),
  negate_15 = make_values(integer(), 15),
  reverse_negate_15 = make_values(15, 15),
  reverse_negate_14_16 = make_values(14:16, 14:16)
)

scores <- do.call(rbind, lapply(names(candidates), function(name) score(candidates[[name]], name)))
message("Segment order candidates:")
print(scores[order(scores$peak_rmse), ], row.names = FALSE)

best <- candidates[[scores$label[order(scores$peak_rmse)][1]]]
message("\nBest peak windows:")
for (start in c(3328, 3584, 3840)) {
  end <- start + 15L
  print(data.frame(idx = start:end, txt = txt[start:end], value = round(best[start:end], 1), diff = round(best[start:end]) - txt[start:end]), row.names = FALSE)
}

message("\ntest_lcd_ch1_segment_order.R completed.")
