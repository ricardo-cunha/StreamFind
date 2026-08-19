#!/usr/bin/env Rscript

devtools::load_all()

example_dir <- file.path("dev", "dev_reader", "example_files")
lcd_src <- file.path(example_dir, "260115_ADC_angepasst.lcd")
txt_src <- file.path(example_dir, "260115_ADC_angepasst.txt")
out_dir <- file.path("dev", "dev_reader", "output")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

work_dir <- tempfile("lcd_project_plot_")
dir.create(work_dir)
lcd_file <- file.path(work_dir, "260115_ADC_angepasst_lcd.lcd")
txt_file <- file.path(work_dir, "260115_ADC_angepasst_txt.txt")
file.copy(lcd_src, lcd_file, overwrite = TRUE)
file.copy(txt_src, txt_file, overwrite = TRUE)

project <- ProjectMassSpec$new(
  tempfile(fileext = ".duckdb"),
  "lcd_current_decode_visual_check",
  file_paths = c(lcd_file, txt_file)
)

message("Analyses:")
print(project$get_analyses()[, c("analysis", "format", "type", "number_chromatograms", "start_rt", "end_rt")])

headers <- project$get_chromatograms_headers()
message("\nChromatogram headers:")
header_id_col <- intersect(c("id", "chromatogram_id", "chromatogram", "name"), names(headers))[1]
header_cols <- intersect(c("analysis", "index", header_id_col, "array_length", "signal_type", "chromatogram_type", "units", "wavelength_nm", "interval_ms"), names(headers))
print(headers[, header_cols, with = FALSE])

plot_file <- file.path(out_dir, "lcd_project_plot_raw_chromatograms.png")
p <- plot_raw_chromatograms(
  project,
  chromatograms = "Detector A-Ch1",
  groupBy = "analysis",
  interactive = FALSE,
  title = "LCD vs TXT Detector A-Ch1",
  yLab = "Intensity / mV-like raw export units"
)
ggplot2::ggsave(plot_file, p, width = 11, height = 6, dpi = 150)
message("\nSaved plot_raw_chromatograms PNG: ", plot_file)

raw <- project$get_raw_chromatograms(
  chromatograms = "Detector A-Ch1"
)
id_col <- intersect(c("id", "chromatogram_id", "chromatogram", "name"), names(raw))[1]
if (is.na(id_col)) {
  stop("No chromatogram id column found in raw chromatograms. Columns: ", paste(names(raw), collapse = ", "))
}

focused <- raw[raw[[id_col]] == "Detector A-Ch1", ]
focused_file <- file.path(out_dir, "lcd_txt_detector_ch1_focused_overlay.png")
focused_plot <- ggplot2::ggplot(focused, ggplot2::aes(x = rt, y = intensity, colour = paste(analysis, .data[[id_col]]))) +
  ggplot2::geom_line(linewidth = 0.35) +
  ggplot2::coord_cartesian(xlim = c(0, 35)) +
  ggplot2::labs(
    title = "Detector A-Ch1: LCD vs TXT Export",
    x = "Retention time / min",
    y = "Intensity",
    colour = "Trace"
  ) +
  ggplot2::theme_minimal(base_size = 12)
ggplot2::ggsave(focused_file, focused_plot, width = 11, height = 6, dpi = 150)
message("Saved focused overlay PNG: ", focused_file)

peak_file <- file.path(out_dir, "lcd_txt_detector_ch1_peak_overlay.png")
peak_plot <- focused_plot +
  ggplot2::coord_cartesian(xlim = c(27, 33)) +
  ggplot2::labs(title = "Detector A-Ch1 Peak Region: LCD vs TXT Export")
ggplot2::ggsave(peak_file, peak_plot, width = 11, height = 6, dpi = 150)
message("Saved peak overlay PNG: ", peak_file)

summary <- focused[, .(
  n = .N,
  rt_min = min(rt, na.rm = TRUE),
  rt_max = max(rt, na.rm = TRUE),
  intensity_min = min(intensity, na.rm = TRUE),
  intensity_max = max(intensity, na.rm = TRUE),
  apex_rt = rt[which.max(intensity)],
  apex_intensity = max(intensity, na.rm = TRUE)
), by = c("analysis", id_col)]
message("\nTrace summary:")
print(summary)

message("\nplot_lcd_project_chromatograms.R completed.")
