#' @title plot_lines_tabular_data
#' @description Generic utility to plot tabular data (data.table/data.frame) with user-specified x/y columns.
#' Other columns are used for hover text in interactive mode. Colors are auto-generated for groups.
#' @param data data.table or data.frame to plot (already processed, e.g., downsized).
#' @param xvar Name of column for x axis.
#' @param yvar Name of column for y axis.
#' @param groupBy Name of column for color grouping (optional, default: NULL).
#' @param basicGroupBy Name of column(s) to define individual traces (optional).
#'   Traces will be created for each unique value of `basicGroupBy`, while
#'   `groupBy` controls color mapping. Example: `basicGroupBy = "analysis"`,
#'   `groupBy = "replicate"` will draw one trace per `analysis` and color
#'   traces according to their `replicate` value.
#' @param interactive Logical, use plotly if TRUE, ggplot2 if FALSE.
#' @param title Plot title.
#' @param xLab X axis label.
#' @param yLab Y axis label.
#' @param colorPalette Optional vector of colors, otherwise uses .get_colors.
#' @return Plot object (plotly or ggplot2)
#' @export
#'
.plot_lines_tabular_data <- function(
  data,
  xvar,
  yvar,
  groupBy = NULL,
  basicGroupBy = NULL,
  interactive = TRUE,
  title = NULL,
  xLab = NULL,
  yLab = NULL,
  colorPalette = NULL,
  darkMode = FALSE
) {
  stopifnot(xvar %in% colnames(data), yvar %in% colnames(data))
  if (is.null(xLab)) xLab <- xvar
  if (is.null(yLab)) yLab <- yvar
  if (is.null(title)) title <- paste(yvar, "vs", xvar)

  # Color assignment
  if (!is.null(groupBy)) {
    # Handle multiple groupBy columns
    if (length(groupBy) > 1) {
      # Check all columns exist
      missing_cols <- setdiff(groupBy, colnames(data))
      if (length(missing_cols) > 0) {
        stop("groupBy columns not found in data: ", paste(missing_cols, collapse = ", "))
      } else {
        # Create combined group_uid by pasting columns together
        group_values <- lapply(groupBy, function(col) as.character(data[[col]]))
        data$color_group <- do.call(paste, c(group_values, sep = "-"))
        groups <- unique(data$color_group)
        colors <- if (!is.null(colorPalette)) colorPalette else .get_colors(groups, darkMode = darkMode)
      }
    } else if (groupBy %in% colnames(data)) {
      groups <- unique(data[[groupBy]])
      colors <- if (!is.null(colorPalette)) colorPalette else .get_colors(groups, darkMode = darkMode)
      data$color_group <- data[[groupBy]]
    } else {
      warning("groupBy column '", groupBy, "' not found in data")
      data$color_group <- "all"
      colors <- .get_colors("all", darkMode = darkMode)
    }
  } else {
    data$color_group <- "all"
    colors <- .get_colors("all", darkMode = darkMode)
  }

  # Trace grouping (basicGroupBy): determines the individual traces
  if (!is.null(basicGroupBy)) {
    # Handle multiple basicGroupBy columns
    if (length(basicGroupBy) > 1) {
      missing_cols <- setdiff(basicGroupBy, colnames(data))
      if (length(missing_cols) > 0) {
        stop("basicGroupBy columns not found in data: ", paste(missing_cols, collapse = ", "))
      } else {
        basic_values <- lapply(basicGroupBy, function(col) as.character(data[[col]]))
        data$basic_group <- do.call(paste, c(basic_values, sep = "-"))
      }
    } else if (basicGroupBy %in% colnames(data)) {
      data$basic_group <- as.character(data[[basicGroupBy]])
    } else {
      warning("basicGroupBy column '", basicGroupBy, "' not found in data; using color grouping as basic group")
      data$basic_group <- data$color_group
    }
  } else {
    # Fallback: each color_group acts as a trace if basicGroupBy not provided
    data$basic_group <- data$color_group
  }

  # Hover text: all columns except xvar, yvar, and internal grouping cols
  hover_cols <- setdiff(colnames(data), c(xvar, yvar, "color_group", "basic_group"))
  # Use ..hover_cols for data.table compatibility
  if (inherits(data, "data.table")) {
    hover_data <- data[, ..hover_cols]
  } else {
    hover_data <- data[, hover_cols, drop = FALSE]
  }
  hover_text <- apply(hover_data, 1, function(row) {
    paste(paste(hover_cols, row, sep = ": "), collapse = "<br>")
  })

  if (!interactive) {
    library(ggplot2)
    # For static ggplot: color is controlled by `groupBy` (color_group) but
    # each trace should be formed by `basic_group` so use that for grouping.
    p <- ggplot(data, aes(x = .data[[xvar]], y = .data[[yvar]], color = color_group, group = basic_group)) +
      geom_line() +
      scale_color_manual(values = colors) +
      .ggplot_plot_theme(darkMode = darkMode) +
      labs(x = xLab, y = yLab, title = title, color = groupBy)
    return(p)
  } else {
    library(plotly)
    color_groups <- unique(data$color_group)
    seen_color_groups <- character(0)
    traces <- vector("list", length(unique(data$basic_group)))
    basic_vals <- unique(data$basic_group)
    for (i in seq_along(basic_vals)) {
      trace_data <- data[data$basic_group == basic_vals[i], ]
      trace_hover_text <- paste0(
        hover_text[data$basic_group == basic_vals[i]],
        "<br>x: ", trace_data[[xvar]],
        "<br>y: ", trace_data[[yvar]]
      )
      cg_vals <- as.character(trace_data$color_group)
      cg_mode <- cg_vals[which.max(tabulate(match(cg_vals, unique(cg_vals))))]
      color_idx <- match(cg_mode, color_groups)
      if (is.na(color_idx) || color_idx > length(colors)) color_val <- colors[1] else color_val <- colors[color_idx]
      showlegend_flag <- !(cg_mode %in% seen_color_groups)
      if (showlegend_flag) seen_color_groups <- c(seen_color_groups, cg_mode)
      traces[[i]] <- list(
        x = trace_data[[xvar]],
        y = trace_data[[yvar]],
        type = "scattergl",
        mode = "lines",
        name = as.character(cg_mode),
        legendgroup = as.character(cg_mode),
        showlegend = showlegend_flag,
        line = list(color = color_val, width = 1),
        text = trace_hover_text,
        hoverinfo = "text"
      )
    }
    p <- plotly::plot_ly()
    for (tr in traces) {
      p <- do.call(plotly::add_trace, c(list(p), tr))
    }
    p <- plotly::layout(
      p,
      title = .plotly_title_spec(title, darkMode = darkMode),
      xaxis = .plotly_axis_spec(title = xLab, darkMode = darkMode),
      yaxis = .plotly_axis_spec(title = yLab, darkMode = darkMode),
      paper_bgcolor = .get_plot_theme(darkMode)$background,
      plot_bgcolor = .get_plot_theme(darkMode)$background,
      font = list(color = .get_plot_theme(darkMode)$text)
    )
    return(p)
  }
}

#' @title plot_raw_spectra_tabular_data
#' @description Internal utility to plot tabular MS1/MS2 spectra returned by raw spectra helpers.
#' @param data data.table or data.frame containing at least `mz` and `intensity` columns.
#' @param groupBy Name of column(s) used to color-label traces.
#' @param normalized Logical, normalize intensities within each trace.
#' @param interactive Logical, use plotly if TRUE, ggplot2 if FALSE.
#' @param title Plot title.
#' @param xLab X axis label.
#' @param yLab Y axis label.
#' @param showText Logical, annotate peaks with m/z labels.
#' @param precursorTol Optional numeric tolerance used to tag precursor peaks from `pre_mz`.
#' @return Plot object (plotly or ggplot2)
#' @noRd
#'
.plot_raw_spectra_tabular_data <- function(
  data,
  groupBy = "id",
  normalized = FALSE,
  interactive = TRUE,
  title = NULL,
  xLab = NULL,
  yLab = NULL,
  showText = TRUE,
  precursorTol = NULL,
  darkMode = FALSE
) {
  data <- data.table::as.data.table(data)
  if (nrow(data) == 0) {
    return(NULL)
  }

  required_cols <- c("analysis", "mz", "intensity")
  missing_cols <- setdiff(required_cols, colnames(data))
  if (length(missing_cols) > 0) {
    stop("Missing required spectrum columns: ", paste(missing_cols, collapse = ", "))
  }

  if (!"replicate" %in% colnames(data)) {
    data[, replicate := NA_character_]
  }
  if (!"id" %in% colnames(data)) {
    data[, id := NA_character_]
  }
  if (!"polarity" %in% colnames(data)) {
    data[, polarity := 0L]
  }

  if (!(is.character(groupBy) && length(groupBy) >= 1 && all(groupBy %in% colnames(data)))) {
    stop("groupBy columns not found in data: ", paste(setdiff(groupBy, colnames(data)), collapse = ", "))
  }

  vals <- lapply(groupBy, function(col) as.character(data[[col]]))
  data[, var := do.call(paste, c(vals, sep = " - "))]
  data[, trace_id := do.call(paste, c(.SD, sep = "|")), .SDcols = intersect(c("analysis", "replicate", "id", "polarity", "pre_mz"), colnames(data))]
  if (!"trace_id" %in% colnames(data) || all(is.na(data$trace_id)) || any(data$trace_id == "")) {
    data[, trace_id := paste0("trace_", seq_len(.N))]
  }

  if (normalized) {
    data[, intensity := {
      max_intensity <- max(intensity, na.rm = TRUE)
      if (is.finite(max_intensity) && max_intensity > 0) intensity / max_intensity else intensity
    }, by = trace_id]
  }

  if (!"is_pre" %in% colnames(data)) {
    data[, is_pre := FALSE]
    if (!is.null(precursorTol) && "pre_mz" %in% colnames(data)) {
      data[!is.na(pre_mz), is_pre := abs(mz - pre_mz) <= precursorTol]
    }
  }

  data[, text_string := if (showText) paste0(round(mz, 4)) else ""]
  if ("is_pre" %in% colnames(data)) {
    data[is_pre == TRUE & showText, text_string := paste0("Pre ", text_string)]
  }

  data[, line_size := 1]
  if ("is_pre" %in% colnames(data)) {
    data[is_pre == TRUE, line_size := 2]
  }

  cl <- .get_colors(unique(data$var), darkMode = darkMode)

  if (!interactive) {
    if (is.null(xLab)) xLab <- expression(italic("m/z ") / " Da")
    if (is.null(yLab)) yLab <- "Intensity / counts"
    plot <- ggplot2::ggplot(data, ggplot2::aes(x = mz, y = intensity, group = trace_id)) +
      ggplot2::geom_segment(ggplot2::aes(xend = mz, yend = 0, color = var, linewidth = line_size))

    if (showText) {
      plot <- plot + ggplot2::geom_text(
        ggplot2::aes(label = text_string),
        vjust = 0.2,
        hjust = -0.2,
        angle = 90,
        size = 2,
        show.legend = FALSE
      )
    }

    return(
      plot +
        ggplot2::scale_y_continuous(expand = c(0, 0), limits = c(0, max(data$intensity, na.rm = TRUE) * 1.5)) +
        ggplot2::labs(title = title, x = xLab, y = yLab) +
        ggplot2::scale_color_manual(values = cl) +
        ggplot2::scale_linewidth_continuous(range = c(1, 2), guide = "none") +
        .ggplot_plot_theme(darkMode = darkMode) +
        ggplot2::labs(color = paste(groupBy, collapse = ", "))
    )
  }

  if (is.null(xLab)) xLab <- "<i>m/z</i> / Da"
  if (is.null(yLab)) yLab <- "Intensity / counts"

  ticks_min <- plyr::round_any(min(data$mz, na.rm = TRUE) * 0.9, 10)
  ticks_max <- plyr::round_any(max(data$mz, na.rm = TRUE) * 1.1, 10)
  title_layout <- .plotly_title_spec(title, darkMode = darkMode)
  xaxis <- .plotly_axis_spec(
    title = xLab,
    darkMode = darkMode,
    range = c(ticks_min, ticks_max),
    dtick = round((max(data$mz, na.rm = TRUE) / 10), -1),
    ticks = "outside"
  )
  yaxis <- .plotly_axis_spec(
    title = yLab,
    darkMode = darkMode,
    range = c(0, max(data$intensity, na.rm = TRUE) * 1.5)
  )

  plot <- plotly::plot_ly()
  seen_vars <- character(0)
  for (trace_key in unique(data$trace_id)) {
    seg <- data[trace_id == trace_key]
    if (nrow(seg) == 0) next
    var_val <- seg$var[1]
    show_legend <- !(var_val %in% seen_vars)
    if (show_legend) seen_vars <- c(seen_vars, var_val)
    x_seg <- as.numeric(rbind(seg$mz, seg$mz, rep(NA_real_, nrow(seg))))
    y_seg <- as.numeric(rbind(rep(0, nrow(seg)), seg$intensity, rep(NA_real_, nrow(seg))))
    plot <- plot %>% plotly::add_trace(
      x = as.vector(x_seg),
      y = as.vector(y_seg),
      type = "scattergl",
      mode = "lines",
      line = list(color = cl[var_val], width = seg$line_size[1]),
      name = var_val,
      legendgroup = var_val,
      showlegend = show_legend,
      hoverinfo = "skip"
    )
    if (showText) {
      plot <- plot %>% plotly::add_trace(
        x = seg$mz,
        y = seg$intensity,
        type = "scattergl",
        mode = "markers+text",
        marker = list(size = 2, color = cl[var_val]),
        text = paste0(seg$text_string, "  "),
        textposition = "top center",
        textfont = list(size = 9, color = cl[var_val]),
        hoverinfo = "text",
        name = var_val,
        legendgroup = var_val,
        showlegend = FALSE
      )
    }
  }

  plot %>% plotly::layout(
    title = title_layout,
    xaxis = xaxis,
    yaxis = yaxis,
    paper_bgcolor = .get_plot_theme(darkMode)$background,
    plot_bgcolor = .get_plot_theme(darkMode)$background,
    font = list(color = .get_plot_theme(darkMode)$text),
    uniformtext = list(minsize = 6, mode = "show")
  )
}

#' @title plot_binned_heatmap_tabular_data
#' @description Internal utility to plot a binned heatmap from tabular data.
#' @param data data.table or data.frame containing binned x/y/z columns.
#' @param xvar Name of binned x-axis center column.
#' @param yvar Name of binned y-axis center column.
#' @param zvar Name of heatmap value column.
#' @param labelvar Optional label/hover text column for bin annotations.
#' @param interactive Logical, use plotly if TRUE, ggplot2 if FALSE.
#' @param title Plot title.
#' @param xLab X axis label.
#' @param yLab Y axis label.
#' @param colors Optional palette vector.
#' @param showLabels Logical, overlay text labels for populated bins.
#' @return Plot object (plotly or ggplot2)
#' @noRd
.plot_binned_heatmap_tabular_data <- function(
  data,
  xvar,
  yvar,
  zvar,
  labelvar = NULL,
  interactive = TRUE,
  title = NULL,
  xLab = NULL,
  yLab = NULL,
  colors = NULL,
  showLabels = FALSE,
  darkMode = FALSE
) {
  dt <- data.table::as.data.table(data)
  required_cols <- c(xvar, yvar, zvar)
  missing_cols <- setdiff(required_cols, colnames(dt))
  if (length(missing_cols) > 0) {
    stop("Missing required heatmap columns: ", paste(missing_cols, collapse = ", "))
  }

  if (nrow(dt) == 0) {
    return(NULL)
  }

  if (is.null(xLab)) xLab <- xvar
  if (is.null(yLab)) yLab <- yvar
  if (is.null(title)) title <- paste(zvar, "heatmap")
  if (is.null(colors)) colors <- viridisLite::viridis(256)

  x_vals <- sort(unique(dt[[xvar]]))
  y_vals <- sort(unique(dt[[yvar]]))
  x_index <- match(dt[[xvar]], x_vals)
  y_index <- match(dt[[yvar]], y_vals)

  z_mat <- matrix(NA_real_, nrow = length(y_vals), ncol = length(x_vals))
  z_mat[cbind(y_index, x_index)] <- as.numeric(dt[[zvar]])

  if (!interactive) {
    plot <- ggplot2::ggplot(
      dt,
      ggplot2::aes(x = .data[[xvar]], y = .data[[yvar]], fill = .data[[zvar]])
    ) +
      ggplot2::geom_raster() +
      ggplot2::scale_fill_gradientn(colours = colors) +
      .ggplot_plot_theme(darkMode = darkMode) +
      ggplot2::labs(title = title, x = xLab, y = yLab, fill = zvar)

    if (showLabels && !is.null(labelvar) && labelvar %in% colnames(dt)) {
      plot <- plot +
        ggplot2::geom_text(
          ggplot2::aes(label = .data[[labelvar]]),
          size = 2
        )
    }

    return(plot)
  }

  x0 <- min(x_vals)
  y0 <- min(y_vals)
  dx <- if (length(x_vals) > 1) stats::median(diff(x_vals)) else 1
  dy <- if (length(y_vals) > 1) stats::median(diff(y_vals)) else 1

  plot <- plotly::plot_ly(
    z = z_mat,
    type = "heatmapgl",
    x0 = x0,
    dx = dx,
    y0 = y0,
    dy = dy,
    colors = colors
  )

  if (!is.null(labelvar) && labelvar %in% colnames(dt)) {
    label_dt <- dt[!is.na(get(zvar)) & get(zvar) != 0]
    if (nrow(label_dt) > 0) {
      plot <- plotly::add_trace(
        plot,
        data = label_dt,
        x = as.formula(paste0("~", xvar)),
        y = as.formula(paste0("~", yvar)),
        text = as.formula(paste0("~", labelvar)),
        type = "scattergl",
        mode = if (showLabels) "text" else "markers",
        marker = list(size = 6, opacity = 0),
        hoverinfo = "text",
        showlegend = FALSE,
        textposition = "middle center",
        textfont = list(size = 8, color = .get_plot_theme(darkMode)$text)
      )
    }
  }

  plotly::layout(
    plot,
    title = .plotly_title_spec(title, darkMode = darkMode),
    xaxis = .plotly_axis_spec(title = xLab, darkMode = darkMode),
    yaxis = .plotly_axis_spec(title = yLab, darkMode = darkMode),
    paper_bgcolor = .get_plot_theme(darkMode)$background,
    plot_bgcolor = .get_plot_theme(darkMode)$background,
    font = list(color = .get_plot_theme(darkMode)$text)
  )
}

.build_trace_colorscale <- function(color) {
  rgb <- grDevices::col2rgb(color)[, 1]
  list(
    list(0, "rgba(255,255,255,0.05)"),
    list(0.15, sprintf("rgba(%d,%d,%d,0.20)", rgb[1], rgb[2], rgb[3])),
    list(0.5, sprintf("rgba(%d,%d,%d,0.55)", rgb[1], rgb[2], rgb[3])),
    list(1, sprintf("rgba(%d,%d,%d,0.95)", rgb[1], rgb[2], rgb[3]))
  )
}

.resolve_binned_marker_size <- function(x_vals, y_vals) {
  nx <- max(1L, length(unique(x_vals)))
  ny <- max(1L, length(unique(y_vals)))
  base <- floor(1200 / max(nx, ny))
  as.numeric(max(6, min(28, base)))
}

#' @title plot_grouped_binned_heatmap_tabular_data
#' @description Internal utility to plot grouped binned heatmaps from tabular data.
#' @param data data.table or data.frame containing grouped binned x/y/z columns.
#' @param xvar Name of binned x-axis center column.
#' @param yvar Name of binned y-axis center column.
#' @param zvar Name of heatmap value column.
#' @param tracevar Name of trace grouping column.
#' @param labelvar Optional label/hover text column for bin annotations.
#' @param interactive Logical, use plotly if TRUE, ggplot2 otherwise.
#' @param title Plot title.
#' @param xLab X axis label.
#' @param yLab Y axis label.
#' @param colorPalette Optional base colors, one per trace.
#' @param showLabels Logical, overlay labels for populated bins.
#' @return Plot object (plotly or ggplot2)
#' @noRd
.plot_grouped_binned_heatmap_tabular_data <- function(
  data,
  xvar,
  yvar,
  zvar,
  tracevar,
  labelvar = NULL,
  interactive = TRUE,
  title = NULL,
  xLab = NULL,
  yLab = NULL,
  colorPalette = NULL,
  showLabels = FALSE,
  darkMode = FALSE
) {
  dt <- data.table::as.data.table(data)
  required_cols <- c(xvar, yvar, zvar, tracevar)
  missing_cols <- setdiff(required_cols, colnames(dt))
  if (length(missing_cols) > 0) {
    stop("Missing required grouped heatmap columns: ", paste(missing_cols, collapse = ", "))
  }
  if (nrow(dt) == 0) {
    return(NULL)
  }

  if (is.null(xLab)) xLab <- xvar
  if (is.null(yLab)) yLab <- yvar
  if (is.null(title)) title <- paste(zvar, "heatmap")

  dt[, trace_label := as.character(get(tracevar))]
  trace_labels <- unique(dt$trace_label)
  if (is.null(colorPalette)) {
    base_colors <- .get_colors(trace_labels, darkMode = darkMode)
  } else {
    base_colors <- colorPalette
    if (length(base_colors) < length(trace_labels)) {
      base_colors <- rep(base_colors, length.out = length(trace_labels))
    }
    base_colors <- stats::setNames(base_colors[seq_along(trace_labels)], trace_labels)
  }

  if (!interactive) {
    plot <- ggplot2::ggplot(
      dt,
      ggplot2::aes(x = .data[[xvar]], y = .data[[yvar]], fill = .data[[zvar]])
    ) +
      ggplot2::geom_raster() +
      ggplot2::facet_wrap(stats::as.formula(paste("~", tracevar))) +
      ggplot2::scale_fill_viridis_c() +
      .ggplot_plot_theme(darkMode = darkMode) +
      ggplot2::labs(title = title, x = xLab, y = yLab, fill = zvar)

    if (showLabels && !is.null(labelvar) && labelvar %in% colnames(dt)) {
      plot <- plot +
        ggplot2::geom_text(
          ggplot2::aes(label = .data[[labelvar]]),
          size = 2
        )
    }

    return(plot)
  }

  plot <- plotly::plot_ly()
  for (i in seq_along(trace_labels)) {
    trace_label <- trace_labels[[i]]
    trace_label_value <- trace_label
    trace_dt <- dt[get("trace_label") == trace_label_value]
    trace_dt <- trace_dt[is.finite(get(zvar)) & get(zvar) > 0]
    if (nrow(trace_dt) == 0) {
      next
    }
    x_vals <- sort(unique(trace_dt[[xvar]]))
    y_vals <- sort(unique(trace_dt[[yvar]]))
    marker_size <- .resolve_binned_marker_size(x_vals, y_vals)
    if (!is.null(labelvar) && labelvar %in% colnames(trace_dt)) {
      hover_text <- paste0(
        tracevar, ": ", trace_label,
        "<br>", xLab, ": ", signif(trace_dt[[xvar]], 6),
        "<br>", yLab, ": ", signif(trace_dt[[yvar]], 6),
        "<br>", trace_dt[[labelvar]]
      )
    } else {
      hover_text <- paste0(
        tracevar, ": ", trace_label,
        "<br>", xLab, ": ", signif(trace_dt[[xvar]], 6),
        "<br>", yLab, ": ", signif(trace_dt[[yvar]], 6),
        "<br>", zvar, ": ", signif(trace_dt[[zvar]], 6)
      )
    }

    plot <- plotly::add_trace(
      plot,
      x = trace_dt[[xvar]],
      y = trace_dt[[yvar]],
      type = "scattergl",
      mode = "markers",
      text = hover_text,
      marker = list(
        symbol = "square",
        size = marker_size,
        color = trace_dt[[zvar]],
        colorscale = .build_trace_colorscale(base_colors[[trace_label]]),
        cmin = min(trace_dt[[zvar]], na.rm = TRUE),
        cmax = max(trace_dt[[zvar]], na.rm = TRUE),
        showscale = FALSE,
        line = list(width = 0)
      ),
      name = trace_label,
      legendgroup = trace_label,
      showlegend = TRUE,
      hoverinfo = "text"
    )

    if (showLabels && !is.null(labelvar) && labelvar %in% colnames(trace_dt)) {
      plot <- plotly::add_trace(
        plot,
        data = trace_dt,
        x = as.formula(paste0("~", xvar)),
        y = as.formula(paste0("~", yvar)),
        text = as.formula(paste0("~", labelvar)),
        type = "scattergl",
        mode = "text",
        textposition = "middle center",
        textfont = list(size = 8, color = base_colors[[trace_label]]),
        hoverinfo = "skip",
        name = trace_label,
        legendgroup = trace_label,
        showlegend = FALSE
      )
    }
  }

  plotly::layout(
    plot,
    title = .plotly_title_spec(title, darkMode = darkMode),
    xaxis = .plotly_axis_spec(title = xLab, darkMode = darkMode),
    yaxis = .plotly_axis_spec(title = yLab, darkMode = darkMode),
    paper_bgcolor = .get_plot_theme(darkMode)$background,
    plot_bgcolor = .get_plot_theme(darkMode)$background,
    font = list(color = .get_plot_theme(darkMode)$text)
  )
}

.interpolate_surface_matrix <- function(z_mat, x_vals, y_vals) {
  out <- z_mat

  for (col_idx in seq_len(ncol(out))) {
    observed <- which(is.finite(out[, col_idx]))
    if (length(observed) >= 2L) {
      out[, col_idx] <- stats::approx(
        x = y_vals[observed],
        y = out[observed, col_idx],
        xout = y_vals,
        rule = 1
      )$y
    }
  }

  for (row_idx in seq_len(nrow(out))) {
    observed <- which(is.finite(out[row_idx, ]))
    if (length(observed) >= 2L) {
      out[row_idx, ] <- stats::approx(
        x = x_vals[observed],
        y = out[row_idx, observed],
        xout = x_vals,
        rule = 1
      )$y
    }
  }

  if (all(!is.finite(out))) {
    return(out)
  }

  out[!is.finite(out)] <- 0
  out
}

#' @title plot_grouped_3d_surface_tabular_data
#' @description Internal utility to plot grouped 3D surfaces from tabular data.
#' @param data data.table or data.frame containing grouped binned x/y/z columns.
#' @param xvar Name of x-axis column.
#' @param yvar Name of y-axis column.
#' @param zvar Name of z-axis column.
#' @param tracevar Name of trace grouping column.
#' @param interactive Logical, use plotly if TRUE, ggplot2 otherwise.
#' @param title Plot title.
#' @param xLab X axis label.
#' @param yLab Y axis label.
#' @param zLab Z axis label.
#' @param colorPalette Optional base colors, one per trace.
#' @return Plot object.
#' @noRd
.plot_grouped_3d_surface_tabular_data <- function(
  data,
  xvar,
  yvar,
  zvar,
  tracevar,
  interactive = TRUE,
  title = NULL,
  xLab = NULL,
  yLab = NULL,
  zLab = NULL,
  colorPalette = NULL,
  darkMode = FALSE
) {
  dt <- data.table::as.data.table(data)
  required_cols <- c(xvar, yvar, zvar, tracevar)
  missing_cols <- setdiff(required_cols, colnames(dt))
  if (length(missing_cols) > 0) {
    stop("Missing required grouped 3D columns: ", paste(missing_cols, collapse = ", "))
  }
  if (nrow(dt) == 0) {
    return(NULL)
  }
  if (!interactive) {
    stop("3D surface plots are only available in interactive mode.")
  }

  if (is.null(xLab)) xLab <- xvar
  if (is.null(yLab)) yLab <- yvar
  if (is.null(zLab)) zLab <- zvar
  if (is.null(title)) title <- paste(zvar, "3D surface")

  dt[, trace_label := as.character(get(tracevar))]
  trace_labels <- unique(dt$trace_label)
  if (is.null(colorPalette)) {
    base_colors <- .get_colors(trace_labels, darkMode = darkMode)
  } else {
    base_colors <- colorPalette
    if (length(base_colors) < length(trace_labels)) {
      base_colors <- rep(base_colors, length.out = length(trace_labels))
    }
    base_colors <- stats::setNames(base_colors[seq_along(trace_labels)], trace_labels)
  }

  plot <- plotly::plot_ly()
  for (trace_label in trace_labels) {
    trace_label_value <- trace_label
    trace_dt <- dt[get("trace_label") == trace_label_value]
    if (nrow(trace_dt) == 0) {
      next
    }
    x_vals <- sort(unique(trace_dt[[xvar]]))
    y_vals <- sort(unique(trace_dt[[yvar]]))
    if (length(x_vals) < 2L || length(y_vals) < 2L) {
      next
    }
    x_index <- match(trace_dt[[xvar]], x_vals)
    y_index <- match(trace_dt[[yvar]], y_vals)
    z_mat <- matrix(NA_real_, nrow = length(y_vals), ncol = length(x_vals))
    z_mat[cbind(y_index, x_index)] <- as.numeric(trace_dt[[zvar]])
    z_mat <- .interpolate_surface_matrix(z_mat, x_vals = x_vals, y_vals = y_vals)
    if (all(!is.finite(z_mat)) || max(z_mat, na.rm = TRUE) <= 0) {
      next
    }
    text_mat <- matrix("", nrow = length(y_vals), ncol = length(x_vals))
    text_mat[cbind(y_index, x_index)] <- paste0(
      tracevar, ": ", trace_label,
      "<br>", xLab, ": ", signif(trace_dt[[xvar]], 6),
      "<br>", yLab, ": ", signif(trace_dt[[yvar]], 6),
      "<br>", zLab, ": ", signif(trace_dt[[zvar]], 6)
    )

    plot <- plotly::add_surface(
      plot,
      x = x_vals,
      y = y_vals,
      z = z_mat,
      text = text_mat,
      hoverinfo = "text",
      colorscale = .build_trace_colorscale(base_colors[[trace_label]]),
      showscale = FALSE,
      opacity = 0.9,
      name = trace_label,
      showlegend = TRUE,
      contours = list(
        z = list(show = TRUE, usecolormap = TRUE, highlightwidth = 1)
      )
    )
  }

  plotly::layout(
    plot,
    title = .plotly_title_spec(title, darkMode = darkMode),
    paper_bgcolor = .get_plot_theme(darkMode)$background,
    plot_bgcolor = .get_plot_theme(darkMode)$background,
    font = list(color = .get_plot_theme(darkMode)$text),
    scene = list(
      xaxis = .plotly_scene_axis_spec(title = xLab, darkMode = darkMode),
      yaxis = .plotly_scene_axis_spec(title = yLab, darkMode = darkMode),
      zaxis = .plotly_scene_axis_spec(title = zLab, darkMode = darkMode)
    )
  )
}
