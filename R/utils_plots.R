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
  colorPalette = NULL
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
        colors <- if (!is.null(colorPalette)) colorPalette else .get_colors(groups)
      }
    } else if (groupBy %in% colnames(data)) {
      groups <- unique(data[[groupBy]])
      colors <- if (!is.null(colorPalette)) colorPalette else .get_colors(groups)
      data$color_group <- data[[groupBy]]
    } else {
      warning("groupBy column '", groupBy, "' not found in data")
      data$color_group <- "all"
      colors <- .get_colors("all")
    }
  } else {
    data$color_group <- "all"
    colors <- .get_colors("all")
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
      theme_classic() +
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
      title = list(text = title, font = list(size = 12, color = "black")),
      xaxis = list(title = xLab, linecolor = "black", titlefont = list(size = 12, color = "black")),
      yaxis = list(title = yLab, linecolor = "black", titlefont = list(size = 12, color = "black"))
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
  precursorTol = NULL
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

  cl <- .get_colors(unique(data$var))

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
        ggplot2::theme_classic() +
        ggplot2::labs(color = paste(groupBy, collapse = ", "))
    )
  }

  if (is.null(xLab)) xLab <- "<i>m/z</i> / Da"
  if (is.null(yLab)) yLab <- "Intensity / counts"

  ticks_min <- plyr::round_any(min(data$mz, na.rm = TRUE) * 0.9, 10)
  ticks_max <- plyr::round_any(max(data$mz, na.rm = TRUE) * 1.1, 10)
  title_layout <- list(text = title, font = list(size = 12, color = "black"))
  xaxis <- list(
    linecolor = "black",
    title = xLab,
    titlefont = list(size = 12, color = "black"),
    range = c(ticks_min, ticks_max),
    dtick = round((max(data$mz, na.rm = TRUE) / 10), -1),
    ticks = "outside"
  )
  yaxis <- list(
    linecolor = "black",
    title = yLab,
    titlefont = list(size = 12, color = "black"),
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
    uniformtext = list(minsize = 6, mode = "show")
  )
}