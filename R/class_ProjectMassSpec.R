#' @title Internal Project Mass Spec Base R6 Class
#' @description Internal R6 child of `Project` exposing shared Mass Spec tables and native helpers.
#' @template arg-Project-db
#' @template arg-Project-project-id
#' @template arg-ProjectMassSpec-analyses
#' @template arg-ProjectMassSpec-chromatograms
#' @template arg-ProjectMassSpec-levels
#' @template arg-ProjectMassSpec-rt
#' @template arg-ProjectMassSpec-rtmin
#' @template arg-ProjectMassSpec-rtmax
#' @template arg-ProjectMassSpec-mass
#' @template arg-ProjectMassSpec-mz
#' @template arg-ProjectMassSpec-mobility
#' @template arg-ProjectMassSpec-ppm
#' @template arg-ProjectMassSpec-sec
#' @template arg-ProjectMassSpec-millisec
#' @template arg-ProjectMassSpec-id
#' @template arg-ProjectMassSpec-allTraces
#' @template arg-ProjectMassSpec-isolationWindow
#' @template arg-ProjectMassSpec-minIntensityMS1
#' @template arg-ProjectMassSpec-minIntensityMS2
#' @template arg-ProjectMassSpec-plot-downsize
#' @template arg-ProjectMassSpec-plot-xLab
#' @template arg-ProjectMassSpec-plot-yLab
#' @template arg-ProjectMassSpec-plot-title
#' @template arg-ProjectMassSpec-plot-groupBy
#' @template arg-ProjectMassSpec-plot-interactive
#' @template arg-ProjectMassSpec-plot-colorPalette
#' @template arg-ProjectMassSpec-normalized
#' @template arg-ProjectMassSpec-showText
#' @template arg-ProjectMassSpec-mzClust
#' @template arg-ProjectMassSpec-presence
#' @template arg-ProjectMassSpec-minIntensity
#' @template arg-Project-ellipsis
#' @template arg-ProjectMassSpec-import-file
#' @template arg-ProjectMassSpec-file-paths
#' @template arg-ProjectMassSpec-replicates
#' @template arg-ProjectMassSpec-blanks
#' @template arg-ProjectMassSpec-analysis
#' @template arg-Project-value
#' @keywords internal
#'
ProjectMassSpec <- R6::R6Class(
  classname = "ProjectMassSpec",
  inherit = Project,
  cloneable = FALSE,
  private = list(
    .mass_spec_ptr = NULL
  ),
  public = list(
    #' @description Create a Mass Spec domain wrapper for a shared `Project`.
    initialize = function(db,
                          project_id,
                          ...,
                          file_paths = character(),
                          replicates = character(),
                          blanks = character()) {
      dots <- list(...)
      ptr_res <- .pull_internal_init_arg(dots, ".ptr")
      .ptr <- ptr_res$value
      mass_spec_ptr_res <- .pull_internal_init_arg(ptr_res$dots, ".mass_spec_ptr")
      .mass_spec_ptr <- mass_spec_ptr_res$value
      .assert_only_internal_init_args(mass_spec_ptr_res$dots, "ProjectMassSpec$initialize()")
      super$initialize(db = db, project_id = project_id, .ptr = .ptr)
      private$.mass_spec_ptr <- if (is.null(.mass_spec_ptr)) {
        rcpp_project_mass_spec_new(self$get_ptr(), file_paths, replicates, blanks)
      } else {
        .mass_spec_ptr
      }
      if (!is.null(.mass_spec_ptr) && length(file_paths) > 0) {
        self$add_analyses(file_paths = file_paths, replicates = replicates, blanks = blanks)
      }
    },
    #' @description Return the native Mass Spec pointer.
    get_mass_spec_ptr = function() {
      private$.mass_spec_ptr
    },
    #' @description Add multiple Mass Spec files into the shared DB as analyses.
    add_analyses = function(file_paths, replicates = character(), blanks = character()) {
      add_analyses.ProjectMassSpec(self, file_paths = file_paths, replicates = replicates, blanks = blanks)
    },
    #' @description Remove analyses from the shared DB.
    remove_analyses = function(analyses) {
      remove_analyses.ProjectMassSpec(self, analyses = analyses)
    },
    #' @description Return imported analyses.
    get_analyses = function() {
      get_analyses.ProjectMassSpec(self)
    },
    #' @description Get analysis names.
    get_analysis_names = function() {
      get_analysis_names.ProjectMassSpec(self)
    },
    #' @description Get replicate names named by analysis.
    get_replicate_names = function() {
      get_replicate_names.ProjectMassSpec(self)
    },
    #' @description Set replicate names by analysis order.
    set_replicate_names = function(value) {
      set_replicate_names.ProjectMassSpec(self, value)
    },
    #' @description Get blank names named by analysis.
    get_blank_names = function() {
      get_blank_names.ProjectMassSpec(self)
    },
    #' @description Set blank names by analysis order.
    set_blank_names = function(value) {
      set_blank_names.ProjectMassSpec(self, value)
    },
    #' @description Get concentrations named by analysis.
    get_concentrations = function() {
      get_concentrations.ProjectMassSpec(self)
    },
    #' @description Set concentrations by analysis order.
    set_concentrations = function(value) {
      set_concentrations.ProjectMassSpec(self, value)
    },
    #' @description Return spectra headers for selected analyses.
    get_spectra_headers = function(analyses = NULL) {
      get_spectra_headers.ProjectMassSpec(self, analyses = analyses)
    },
    #' @description Return spectra TIC rows for selected analyses.
    get_spectra_tic = function(analyses = NULL, levels = NULL, rtmin = NULL, rtmax = NULL) {
      get_spectra_tic.ProjectMassSpec(self, analyses = analyses, levels = levels, rtmin = rtmin, rtmax = rtmax)
    },
    #' @description Return chromatogram headers for selected analyses.
    get_chromatograms_headers = function(analyses = NULL) {
      get_chromatograms_headers.ProjectMassSpec(self, analyses = analyses)
    },
    #' @description Get raw chromatograms for selected analyses.
    get_raw_chromatograms = function(analyses = NULL,
                                     chromatograms = NULL,
                                     rtmin = 0,
                                     rtmax = 0,
                                     minIntensity = NULL) {
      get_raw_chromatograms.ProjectMassSpec(self, analyses = analyses, chromatograms = chromatograms, rtmin = rtmin, rtmax = rtmax, minIntensity = minIntensity)
    },
    #' @description Plot raw chromatograms for selected analyses.
    plot_raw_chromatograms = function(analyses = NULL,
                                      chromatograms = NULL,
                                      rtmin = 0,
                                      rtmax = 0,
                                      minIntensity = NULL,
                                      downsize = NULL,
                                      xLab = NULL,
                                      yLab = NULL,
                                      title = NULL,
                                      groupBy = "analysis",
                                      interactive = TRUE,
                                      colorPalette = NULL) {
      plot_raw_chromatograms.ProjectMassSpec(self, analyses = analyses, chromatograms = chromatograms, rtmin = rtmin, rtmax = rtmax, minIntensity = minIntensity, downsize = downsize, xLab = xLab, yLab = yLab, title = title, groupBy = groupBy, interactive = interactive, colorPalette = colorPalette)
    },
    #' @description Get raw spectra data for selected analyses.
    get_raw_spectra = function(analyses = character(),
                               levels = integer(),
                               mass = numeric(),
                               mz = numeric(),
                               rt = numeric(),
                               mobility = numeric(),
                               ppm = 20,
                               sec = 60,
                               millisec = 5,
                               id = character(),
                               allTraces = TRUE,
                               isolationWindow = 1.3,
                               minIntensityMS1 = 0,
                               minIntensityMS2 = 0) {
      get_raw_spectra.ProjectMassSpec(self, analyses = analyses, levels = levels, mass = mass, mz = mz, rt = rt, mobility = mobility, ppm = ppm, sec = sec, millisec = millisec, id = id, allTraces = allTraces, isolationWindow = isolationWindow, minIntensityMS1 = minIntensityMS1, minIntensityMS2 = minIntensityMS2)
    },
    #' @description Plot total ion current traces for selected analyses.
    plot_spectra_tic = function(analyses = NULL,
                                levels = c(1, 2),
                                rtmin = NULL,
                                rtmax = NULL,
                                downsize = NULL,
                                xLab = NULL,
                                yLab = NULL,
                                title = NULL,
                                groupBy = "analysis",
                                interactive = TRUE,
                                colorPalette = NULL) {
      plot_spectra_tic.ProjectMassSpec(self, analyses = analyses, levels = levels, rtmin = rtmin, rtmax = rtmax, downsize = downsize, xLab = xLab, yLab = yLab, title = title, groupBy = groupBy, interactive = interactive, colorPalette = colorPalette)
    },
    #' @description Plot base peak chromatogram traces for selected analyses.
    plot_spectra_bpc = function(analyses = NULL,
                                levels = c(1, 2),
                                rtmin = NULL,
                                rtmax = NULL,
                                downsize = NULL,
                                xLab = NULL,
                                yLab = NULL,
                                title = NULL,
                                groupBy = "analysis",
                                interactive = TRUE,
                                colorPalette = NULL) {
      plot_spectra_bpc.ProjectMassSpec(self, analyses = analyses, levels = levels, rtmin = rtmin, rtmax = rtmax, downsize = downsize, xLab = xLab, yLab = yLab, title = title, groupBy = groupBy, interactive = interactive, colorPalette = colorPalette)
    },
    #' @description Get extracted ion chromatograms for selected analyses.
    get_raw_spectra_eic = function(analyses = NULL,
                                   mass = NULL,
                                   mz = NULL,
                                   rt = NULL,
                                   mobility = NULL,
                                   ppm = 20,
                                   sec = 60,
                                   millisec = 5,
                                   id = NULL) {
      get_raw_spectra_eic.ProjectMassSpec(self, analyses = analyses, mass = mass, mz = mz, rt = rt, mobility = mobility, ppm = ppm, sec = sec, millisec = millisec, id = id)
    },
    #' @description Plot extracted ion chromatograms for selected analyses.
    plot_raw_spectra_eic = function(analyses = NULL,
                                    mass = NULL,
                                    mz = NULL,
                                    rt = NULL,
                                    mobility = NULL,
                                    ppm = 20,
                                    sec = 60,
                                    millisec = 5,
                                    id = NULL,
                                    downsize = NULL,
                                    xLab = NULL,
                                    yLab = NULL,
                                    title = NULL,
                                    groupBy = c("analysis", "id"),
                                    interactive = TRUE,
                                    colorPalette = NULL) {
      plot_raw_spectra_eic.ProjectMassSpec(self, analyses = analyses, mass = mass, mz = mz, rt = rt, mobility = mobility, ppm = ppm, sec = sec, millisec = millisec, id = id, downsize = downsize, xLab = xLab, yLab = yLab, title = title, groupBy = groupBy, interactive = interactive, colorPalette = colorPalette)
    },
    #' @description Get clustered MS1 spectra for selected analyses.
    get_raw_spectra_ms1 = function(analyses = NULL,
                                   mass = NULL,
                                   mz = NULL,
                                   rt = NULL,
                                   mobility = NULL,
                                   ppm = 20,
                                   sec = 60,
                                   millisec = 5,
                                   id = NULL,
                                   mzClust = 0.003,
                                   presence = 0.8,
                                   minIntensity = 1000) {
      get_raw_spectra_ms1.ProjectMassSpec(self, analyses = analyses, mass = mass, mz = mz, rt = rt, mobility = mobility, ppm = ppm, sec = sec, millisec = millisec, id = id, mzClust = mzClust, presence = presence, minIntensity = minIntensity)
    },
    #' @description Get clustered MS2 spectra for selected analyses.
    get_raw_spectra_ms2 = function(analyses = NULL,
                                   mass = NULL,
                                   mz = NULL,
                                   rt = NULL,
                                   mobility = NULL,
                                   ppm = 20,
                                   sec = 60,
                                   millisec = 5,
                                   id = NULL,
                                   isolationWindow = 1.3,
                                   mzClust = 0.005,
                                   presence = 0,
                                   minIntensity = 0) {
      get_raw_spectra_ms2.ProjectMassSpec(self, analyses = analyses, mass = mass, mz = mz, rt = rt, mobility = mobility, ppm = ppm, sec = sec, millisec = millisec, id = id, isolationWindow = isolationWindow, mzClust = mzClust, presence = presence, minIntensity = minIntensity)
    },
    #' @description Plot clustered MS1 spectra for selected analyses.
    plot_raw_spectra_ms1 = function(analyses = NULL,
                                    mass = NULL,
                                    mz = NULL,
                                    rt = NULL,
                                    mobility = NULL,
                                    ppm = 20,
                                    sec = 60,
                                    millisec = 5,
                                    id = NULL,
                                    mzClust = 0.003,
                                    presence = 0.8,
                                    minIntensity = 1000,
                                    normalized = FALSE,
                                    xLab = NULL,
                                    yLab = NULL,
                                    title = NULL,
                                    groupBy = "id",
                                    showText = TRUE,
                                    interactive = TRUE) {
      plot_raw_spectra_ms1.ProjectMassSpec(self, analyses = analyses, mass = mass, mz = mz, rt = rt, mobility = mobility, ppm = ppm, sec = sec, millisec = millisec, id = id, mzClust = mzClust, presence = presence, minIntensity = minIntensity, normalized = normalized, xLab = xLab, yLab = yLab, title = title, groupBy = groupBy, showText = showText, interactive = interactive)
    },
    #' @description Plot clustered MS2 spectra for selected analyses.
    plot_raw_spectra_ms2 = function(analyses = NULL,
                                    mass = NULL,
                                    mz = NULL,
                                    rt = NULL,
                                    mobility = NULL,
                                    ppm = 20,
                                    sec = 60,
                                    millisec = 5,
                                    id = NULL,
                                    isolationWindow = 1.3,
                                    mzClust = 0.005,
                                    presence = 0,
                                    minIntensity = 0,
                                    normalized = TRUE,
                                    xLab = NULL,
                                    yLab = NULL,
                                    title = NULL,
                                    groupBy = "id",
                                    showText = TRUE,
                                    interactive = TRUE) {
      plot_raw_spectra_ms2.ProjectMassSpec(self, analyses = analyses, mass = mass, mz = mz, rt = rt, mobility = mobility, ppm = ppm, sec = sec, millisec = millisec, id = id, isolationWindow = isolationWindow, mzClust = mzClust, presence = presence, minIntensity = minIntensity, normalized = normalized, xLab = xLab, yLab = yLab, title = title, groupBy = groupBy, showText = showText, interactive = interactive)
    },
    #' @description Print a short summary.
    print = function(...) {
      print.ProjectMassSpec(self, ...)
    },
    #' @description Show a short summary.
    show = function(...) {
      show.ProjectMassSpec(self, ...)
    }
  )
)

#' @name ProjectMassSpecS3
#' @title ProjectMassSpec S3 Methods
#' @description S3 interface methods for `ProjectMassSpec`.
#' @param x A `ProjectMassSpec` object.
#' @template arg-ProjectMassSpec-file-paths
#' @template arg-ProjectMassSpec-replicates
#' @template arg-ProjectMassSpec-blanks
#' @template arg-ProjectMassSpec-analyses
#' @template arg-ProjectMassSpec-chromatograms
#' @template arg-ProjectMassSpec-levels
#' @template arg-ProjectMassSpec-rt
#' @template arg-ProjectMassSpec-rtmin
#' @template arg-ProjectMassSpec-rtmax
#' @template arg-ProjectMassSpec-mass
#' @template arg-ProjectMassSpec-mz
#' @template arg-ProjectMassSpec-mobility
#' @template arg-ProjectMassSpec-ppm
#' @template arg-ProjectMassSpec-sec
#' @template arg-ProjectMassSpec-millisec
#' @template arg-ProjectMassSpec-id
#' @template arg-ProjectMassSpec-allTraces
#' @template arg-ProjectMassSpec-isolationWindow
#' @template arg-ProjectMassSpec-minIntensityMS1
#' @template arg-ProjectMassSpec-minIntensityMS2
#' @template arg-ProjectMassSpec-plot-downsize
#' @template arg-ProjectMassSpec-plot-xLab
#' @template arg-ProjectMassSpec-plot-yLab
#' @template arg-ProjectMassSpec-plot-title
#' @template arg-ProjectMassSpec-plot-groupBy
#' @template arg-ProjectMassSpec-plot-interactive
#' @template arg-ProjectMassSpec-plot-colorPalette
#' @template arg-ProjectMassSpec-normalized
#' @template arg-ProjectMassSpec-showText
#' @template arg-Project-db
#' @template arg-Project-project-id
#' @template arg-ProjectMassSpec-mzClust
#' @template arg-ProjectMassSpec-presence
#' @template arg-ProjectMassSpec-minIntensity
#' @template arg-Project-ellipsis
#' @template arg-ProjectMassSpec-import-file
#' @template arg-ProjectMassSpec-analysis
#' @template arg-Project-value
NULL

#' @describeIn ProjectMassSpecS3 Print a short information table for the project analyses.
#' @method info ProjectMassSpec
#' @export
info.ProjectMassSpec <- function(x) {
  checkmate::assert_class(x, "ProjectMassSpec")
  data.table::as.data.table(x$get_analyses())
}

#' @noRd
.print_project_mass_spec_summary <- function(x, title = class(x)[1]) {
  .print_project_summary_base(x, title = title)
  analyses <- try(get_analyses.ProjectMassSpec(x), silent = TRUE)
  if (!inherits(analyses, "try-error")) {
    cat("analyses: ", nrow(analyses), "\n", sep = "")
  }
  invisible(x)
}

#' @describeIn ProjectMassSpecS3 Print a short summary.
#' @method print ProjectMassSpec
#' @export
print.ProjectMassSpec <- function(x, ...) {
  checkmate::assert_class(x, "ProjectMassSpec")
  .print_project_mass_spec_summary(x, title = "ProjectMassSpec")
}

#' @describeIn ProjectMassSpecS3 Show a short summary.
#' @method show ProjectMassSpec
#' @export
show.ProjectMassSpec <- function(x, ...) {
  checkmate::assert_class(x, "ProjectMassSpec")
  print.ProjectMassSpec(x, ...)
}

#' @describeIn ProjectMassSpecS3 Return imported analyses.
#' @method get_analyses ProjectMassSpec
#' @export
get_analyses.ProjectMassSpec <- function(x) {
  checkmate::assert_class(x, "ProjectMassSpec")
  rcpp_project_mass_spec_list_analyses(x$get_mass_spec_ptr())
}

#' @describeIn ProjectMassSpecS3 Import one or more data files into the project as analyses.
#' @method add_analyses ProjectMassSpec
#' @export
add_analyses.ProjectMassSpec <- function(x, file_paths = character(), replicates = character(), blanks = character()) {
  checkmate::assert_class(x, "ProjectMassSpec")
  checkmate::assert_character(file_paths, min.len = 1, any.missing = FALSE)
  checkmate::assert_character(replicates, any.missing = FALSE)
  checkmate::assert_character(blanks, any.missing = FALSE)
  rcpp_project_mass_spec_import_files(x$get_mass_spec_ptr(), file_paths, replicates, blanks)
  invisible(x)
}

#' @describeIn ProjectMassSpecS3 Remove analyses from the project by name or index.
#' @method remove_analyses ProjectMassSpec
#' @export
remove_analyses.ProjectMassSpec <- function(x, analyses = character()) {
  checkmate::assert_class(x, "ProjectMassSpec")
  analyses_info <- data.table::as.data.table(get_analyses.ProjectMassSpec(x))
  sel_names <- .resolve_analyses_selection(analyses, analyses_info$analysis)
  for (analysis in sel_names) {
    rcpp_project_mass_spec_remove_analysis(x$get_mass_spec_ptr(), analysis)
  }
  invisible(x)
}

#' @describeIn ProjectMassSpecS3 Return analysis names for the project.
#' @method get_analysis_names ProjectMassSpec
#' @export
get_analysis_names.ProjectMassSpec <- function(x) {
  checkmate::assert_class(x, "ProjectMassSpec")
  rcpp_project_mass_spec_get_analysis_names(x$get_mass_spec_ptr())
}

#' @describeIn ProjectMassSpecS3 Return replicate names for the project.
#' @method get_replicate_names ProjectMassSpec
#' @export
get_replicate_names.ProjectMassSpec <- function(x) {
  checkmate::assert_class(x, "ProjectMassSpec")
  rcpp_project_mass_spec_get_replicate_names(x$get_mass_spec_ptr())
}

#' @describeIn ProjectMassSpecS3 Set replicate names for the project analyses.
#' @method set_replicate_names ProjectMassSpec
#' @export
set_replicate_names.ProjectMassSpec <- function(x, value) {
  checkmate::assert_class(x, "ProjectMassSpec")
  checkmate::assert_character(value, any.missing = FALSE)
  rcpp_project_mass_spec_set_replicate_names(x$get_mass_spec_ptr(), value)
  invisible(x)
}

#' @describeIn ProjectMassSpecS3 Return blank names for the project.
#' @method get_blank_names ProjectMassSpec
#' @export
get_blank_names.ProjectMassSpec <- function(x) {
  checkmate::assert_class(x, "ProjectMassSpec")
  rcpp_project_mass_spec_get_blank_names(x$get_mass_spec_ptr())
}

#' @describeIn ProjectMassSpecS3 Set blank names for the project analyses.
#' @method set_blank_names ProjectMassSpec
#' @export
set_blank_names.ProjectMassSpec <- function(x, value) {
  checkmate::assert_class(x, "ProjectMassSpec")
  checkmate::assert_character(value, any.missing = FALSE)
  rcpp_project_mass_spec_set_blank_names(x$get_mass_spec_ptr(), value)
  invisible(x)
}

#' @describeIn ProjectMassSpecS3 Return concentrations vector for the project.
#' @method get_concentrations ProjectMassSpec
#' @export
get_concentrations.ProjectMassSpec <- function(x) {
  checkmate::assert_class(x, "ProjectMassSpec")
  rcpp_project_mass_spec_get_concentrations(x$get_mass_spec_ptr())
}

#' @describeIn ProjectMassSpecS3 Set concentrations for the project analyses.
#' @method set_concentrations ProjectMassSpec
#' @export
set_concentrations.ProjectMassSpec <- function(x, value) {
  checkmate::assert_class(x, "ProjectMassSpec")
  if (!is.numeric(value)) stop("value must be numeric.")
  rcpp_project_mass_spec_set_concentrations(x$get_mass_spec_ptr(), value)
  invisible(x)
}

#' @describeIn ProjectMassSpecS3 Fetch spectra headers for specified analyses.
#' @method get_spectra_headers ProjectMassSpec
#' @export
get_spectra_headers.ProjectMassSpec <- function(x, analyses = character()) {
  checkmate::assert_class(x, "ProjectMassSpec")
  if (is.null(analyses)) analyses <- character()
  analyses_info <- data.table::as.data.table(x$get_analyses())
  hd <- data.table::as.data.table(rcpp_project_mass_spec_get_spectra_headers(x$get_mass_spec_ptr(), analyses))
  if (nrow(hd) == 0) {
    return(data.table::data.table())
  }
  replicates <- analyses_info$replicate
  names(replicates) <- analyses_info$analysis
  if ("project_id" %in% colnames(hd)) {
    hd[, project_id := NULL]
  }
  hd$replicate <- replicates[hd$analysis]
  data.table::setcolorder(hd, c("analysis", "replicate"))
  hd
}

#' @describeIn ProjectMassSpecS3 Return spectra TIC rows for selected analyses.
#' @method get_spectra_tic ProjectMassSpec
#' @export
get_spectra_tic.ProjectMassSpec <- function(x, analyses = character(), levels = integer(), rtmin = numeric(), rtmax = numeric()) {
  checkmate::assert_class(x, "ProjectMassSpec")
  if (is.null(analyses)) analyses <- character()
  if (is.null(levels)) levels <- integer()
  rt_min <- 0
  rt_max <- 0
  if (!is.null(rtmin) && length(rtmin) > 0 && !is.null(rtmax) && length(rtmax) > 0) {
    rt_min <- min(as.numeric(rtmin)[1], as.numeric(rtmax)[1])
    rt_max <- max(as.numeric(rtmin)[1], as.numeric(rtmax)[1])
  }
  data.table::as.data.table(rcpp_project_mass_spec_get_spectra_tic(
    x$get_mass_spec_ptr(),
    analyses,
    as.integer(levels),
    as.numeric(rt_min),
    as.numeric(rt_max)
  ))
}

#' @describeIn ProjectMassSpecS3 Plot total ion current (TIC) spectra for specified analyses.
#' @method plot_spectra_tic ProjectMassSpec
#' @export
plot_spectra_tic.ProjectMassSpec <- function(
  x,
  analyses = character(),
  levels = c(1, 2),
  rtmin = numeric(),
  rtmax = numeric(),
  downsize = NULL,
  xLab = NULL,
  yLab = NULL,
  title = NULL,
  groupBy = "analysis",
  interactive = TRUE,
  colorPalette = NULL
) {
  checkmate::assert_class(x, "ProjectMassSpec")
  tic <- data.table::as.data.table(get_spectra_tic.ProjectMassSpec(x, analyses, levels, rtmin, rtmax))
  if (nrow(tic) == 0) {
    message("\U2717 TIC not found for the analyses!")
    return(NULL)
  }
  tic <- tic[, .(analysis, replicate, polarity, level, rt, tic)]
  if (!is.null(downsize) && downsize > 0 && nrow(tic) > downsize) {
    tic[, rt := floor(rt / downsize) * downsize]
    tic <- tic[, lapply(.SD, function(col) {
      if (is.numeric(col)) {
        mean(col, na.rm = TRUE)
      } else if (is.character(col)) {
        col[1]
      } else {
        col[1]
      }
    }), by = .(rt, analysis)]
  }
  if (is.null(xLab)) xLab <- "Retention time / seconds"
  if (is.null(yLab)) yLab <- "Intensity / counts"
  .plot_lines_tabular_data(
    data = tic,
    xvar = "rt",
    yvar = "tic",
    groupBy = groupBy,
    basicGroupBy = "analysis",
    interactive = interactive,
    title = title,
    xLab = xLab,
    yLab = yLab,
    colorPalette = colorPalette
  )
}

#' @describeIn ProjectMassSpecS3 Plot base peak chromatogram (BPC) spectra for specified analyses.
#' @method plot_spectra_bpc ProjectMassSpec
#' @export
plot_spectra_bpc.ProjectMassSpec <- function(
  x,
  analyses = character(),
  levels = c(1, 2),
  rtmin = numeric(),
  rtmax = numeric(),
  downsize = NULL,
  xLab = NULL,
  yLab = NULL,
  title = NULL,
  groupBy = "analysis",
  interactive = TRUE,
  colorPalette = NULL
) {
  checkmate::assert_class(x, "ProjectMassSpec")
  bpc <- data.table::as.data.table(get_spectra_tic.ProjectMassSpec(x, analyses, levels, rtmin, rtmax))
  if (nrow(bpc) == 0) {
    message("\U2717 BPC not found for the analyses!")
    return(NULL)
  }
  bpc <- bpc[, .(analysis, replicate, polarity, level, rt, bpmz, bpint)]
  if (!is.null(downsize) && downsize > 0 && nrow(bpc) > downsize) {
    bpc[, rt := floor(rt / downsize) * downsize]
    bpc <- bpc[, lapply(.SD, function(col) {
      if (is.numeric(col)) {
        mean(col, na.rm = TRUE)
      } else if (is.character(col)) {
        col[1]
      } else {
        col[1]
      }
    }), by = .(rt, analysis)]
  }
  if (is.null(xLab)) xLab <- "Retention time / seconds"
  if (is.null(yLab)) yLab <- "Intensity / counts"
  .plot_lines_tabular_data(
    data = bpc,
    xvar = "rt",
    yvar = "bpint",
    groupBy = groupBy,
    basicGroupBy = "analysis",
    interactive = interactive,
    title = title,
    xLab = xLab,
    yLab = yLab,
    colorPalette = colorPalette
  )
}

#' @describeIn ProjectMassSpecS3 Get raw spectra data for specified analyses; returns a data.table with spectra rows.
#' @method get_raw_spectra ProjectMassSpec
#' @export
get_raw_spectra.ProjectMassSpec <- function(
  x,
  analyses = character(),
  levels = integer(),
  mass = numeric(),
  mz = numeric(),
  rt = numeric(),
  mobility = numeric(),
  ppm = 20,
  sec = 60,
  millisec = 5,
  id = character(),
  allTraces = TRUE,
  isolationWindow = 1.3,
  minIntensityMS1 = 0,
  minIntensityMS2 = 0
) {
  checkmate::assert_class(x, "ProjectMassSpec")
  if (is.null(analyses)) {
    analyses <- character()
  }
  if (is.null(mass)) {
    mass <- numeric()
  }
  if (is.null(mz)) {
    mz <- numeric()
  }
  if (is.null(rt)) {
    rt <- numeric()
  }
  if (is.null(mobility)) {
    mobility <- numeric()
  }
  if (is.null(id)) {
    id <- character()
  }
  if (is.null(levels)) {
    levels <- integer()
  }
  if (!(checkmate::test_character(analyses, any.missing = FALSE) || checkmate::test_integerish(analyses, any.missing = FALSE, lower = 1))) {
    stop("`analyses` must be a character vector of names or a numeric vector of 1-based indices.")
  }
  checkmate::assert_integerish(levels, any.missing = FALSE, lower = 1)
  if (!(checkmate::test_numeric(mass, any.missing = FALSE) || checkmate::test_data_frame(mass))) {
    stop("`mass` must be a numeric vector or a data.frame.")
  }
  if (!(checkmate::test_numeric(mz, any.missing = FALSE) || checkmate::test_data_frame(mz))) {
    stop("`mz` must be a numeric vector or a data.frame.")
  }
  if (!(checkmate::test_numeric(rt, any.missing = FALSE) || checkmate::test_data_frame(rt))) {
    stop("`rt` must be a numeric vector or a data.frame.")
  }
  if (!(checkmate::test_numeric(mobility, any.missing = FALSE) || checkmate::test_data_frame(mobility))) {
    stop("`mobility` must be a numeric vector or a data.frame.")
  }
  checkmate::assert_character(id, any.missing = FALSE)
  checkmate::assert_number(ppm, lower = 0, finite = TRUE)
  checkmate::assert_number(sec, lower = 0, finite = TRUE)
  checkmate::assert_number(millisec, lower = 0, finite = TRUE)
  checkmate::assert_flag(allTraces)
  checkmate::assert_number(isolationWindow, lower = 0, finite = TRUE)
  checkmate::assert_number(minIntensityMS1, lower = 0, finite = TRUE)
  checkmate::assert_number(minIntensityMS2, lower = 0, finite = TRUE)
  spec <- data.table::as.data.table(rcpp_project_mass_spec_get_raw_spectra(
    x$get_mass_spec_ptr(),
    analyses,
    as.integer(levels),
    mass,
    mz,
    rt,
    mobility,
    as.character(id),
    ppm,
    sec,
    millisec,
    allTraces,
    isolationWindow,
    minIntensityMS1,
    minIntensityMS2
  ))
  if (nrow(spec) > 0) {
    if (!any(spec$mobility > 0)) spec$mobility <- NULL
    data.table::setcolorder(spec, c("analysis", "replicate"))
  }
  spec
}

#' @describeIn ProjectMassSpecS3 Get extracted ion chromatograms (EIC) for specified analyses.
#' @method get_raw_spectra_eic ProjectMassSpec
#' @export
get_raw_spectra_eic.ProjectMassSpec <- function(
  x,
  analyses = NULL,
  mass = NULL,
  mz = NULL,
  rt = NULL,
  mobility = NULL,
  ppm = 20,
  sec = 60,
  millisec = 5,
  id = NULL
) {
  checkmate::assert_class(x, "ProjectMassSpec")
  data.table::as.data.table(rcpp_project_mass_spec_get_raw_spectra_eic(
    x$get_mass_spec_ptr(),
    analyses,
    mass,
    mz,
    rt,
    mobility,
    as.character(id),
    ppm,
    sec,
    millisec
  ))
}

#' @describeIn ProjectMassSpecS3 Plot extracted ion chromatograms (EIC) for specified analyses and targets.
#' @method plot_raw_spectra_eic ProjectMassSpec
#' @export
plot_raw_spectra_eic.ProjectMassSpec <- function(
  x,
  analyses = NULL,
  mass = NULL,
  mz = NULL,
  rt = NULL,
  mobility = NULL,
  ppm = 20,
  sec = 60,
  millisec = 5,
  id = NULL,
  downsize = NULL,
  xLab = NULL,
  yLab = NULL,
  title = NULL,
  groupBy = c("analysis", "id"),
  interactive = TRUE,
  colorPalette = NULL
) {
  checkmate::assert_class(x, "ProjectMassSpec")
  eic <- get_raw_spectra_eic.ProjectMassSpec(x, analyses, mass, mz, rt, mobility, ppm, sec, millisec, id)
  if (nrow(eic) == 0) {
    message("\U2717 EIC not found for the analyses!")
    return(NULL)
  }
  if (!is.null(downsize) && downsize > 0 && nrow(eic) > downsize) {
    eic <- data.table::as.data.table(eic)
    eic$rt <- floor(eic$rt / downsize) * downsize
    group_cols <- c("rt", "analysis", "id")
    eic <- eic[, lapply(.SD, function(col) {
      if (is.numeric(col)) {
        mean(col, na.rm = TRUE)
      } else if (is.character(col)) {
        col[1]
      } else {
        col[1]
      }
    }), by = group_cols]
  }
  if (is.null(xLab)) xLab <- "Retention time / seconds"
  if (is.null(yLab)) yLab <- "Intensity / counts"
  .plot_lines_tabular_data(
    data = eic,
    xvar = "rt",
    yvar = "intensity",
    groupBy = groupBy,
    basicGroupBy = c("analysis", "id"),
    interactive = interactive,
    title = title,
    xLab = xLab,
    yLab = yLab,
    colorPalette = colorPalette
  )
}

#' @describeIn ProjectMassSpecS3 Plot clustered MS1 spectra for specified analyses and targets.
#' @method plot_raw_spectra_ms1 ProjectMassSpec
#' @export
plot_raw_spectra_ms1.ProjectMassSpec <- function(
  x,
  analyses = NULL,
  mass = NULL,
  mz = NULL,
  rt = NULL,
  mobility = NULL,
  ppm = 20,
  sec = 60,
  millisec = 5,
  id = NULL,
  mzClust = 0.003,
  presence = 0.8,
  minIntensity = 1000,
  normalized = FALSE,
  xLab = NULL,
  yLab = NULL,
  title = NULL,
  groupBy = "id",
  showText = TRUE,
  interactive = TRUE
) {
  checkmate::assert_class(x, "ProjectMassSpec")
  ms1 <- get_raw_spectra_ms1.ProjectMassSpec(
    x = x,
    analyses = analyses,
    mass = mass,
    mz = mz,
    rt = rt,
    mobility = mobility,
    ppm = ppm,
    sec = sec,
    millisec = millisec,
    id = id,
    mzClust = mzClust,
    presence = presence,
    minIntensity = minIntensity
  )
  if (nrow(ms1) == 0) {
    message("\U2717 MS1 traces not found for the targets!")
    return(NULL)
  }
  .plot_raw_spectra_tabular_data(
    data = ms1,
    groupBy = groupBy,
    normalized = normalized,
    interactive = interactive,
    title = title,
    xLab = xLab,
    yLab = yLab,
    showText = showText
  )
}

#' @describeIn ProjectMassSpecS3 Plot clustered MS2 spectra for specified analyses and targets.
#' @method plot_raw_spectra_ms2 ProjectMassSpec
#' @export
plot_raw_spectra_ms2.ProjectMassSpec <- function(
  x,
  analyses = NULL,
  mass = NULL,
  mz = NULL,
  rt = NULL,
  mobility = NULL,
  ppm = 20,
  sec = 60,
  millisec = 5,
  id = NULL,
  isolationWindow = 1.3,
  mzClust = 0.005,
  presence = 0,
  minIntensity = 0,
  normalized = TRUE,
  xLab = NULL,
  yLab = NULL,
  title = NULL,
  groupBy = "id",
  showText = TRUE,
  interactive = TRUE
) {
  checkmate::assert_class(x, "ProjectMassSpec")
  ms2 <- get_raw_spectra_ms2.ProjectMassSpec(
    x = x,
    analyses = analyses,
    mass = mass,
    mz = mz,
    rt = rt,
    mobility = mobility,
    ppm = ppm,
    sec = sec,
    millisec = millisec,
    id = id,
    isolationWindow = isolationWindow,
    mzClust = mzClust,
    presence = presence,
    minIntensity = minIntensity
  )
  if (nrow(ms2) == 0) {
    message("\U2717 MS2 traces not found for the targets!")
    return(NULL)
  }
  .plot_raw_spectra_tabular_data(
    data = ms2,
    groupBy = groupBy,
    normalized = normalized,
    interactive = interactive,
    title = title,
    xLab = xLab,
    yLab = yLab,
    showText = showText,
    precursorTol = mzClust
  )
}

#' @describeIn ProjectMassSpecS3 Get clustered MS1 spectra for specified analyses and targets.
#' @method get_raw_spectra_ms1 ProjectMassSpec
#' @export
get_raw_spectra_ms1.ProjectMassSpec <- function(
  x,
  analyses = NULL,
  mass = NULL,
  mz = NULL,
  rt = NULL,
  mobility = NULL,
  ppm = 20,
  sec = 60,
  millisec = 5,
  id = NULL,
  mzClust = 0.003,
  presence = 0.8,
  minIntensity = 1000
) {
  checkmate::assert_class(x, "ProjectMassSpec")
  data.table::as.data.table(rcpp_project_mass_spec_get_raw_spectra_ms1(
    x$get_mass_spec_ptr(),
    analyses,
    mass,
    mz,
    rt,
    mobility,
    as.character(id),
    ppm,
    sec,
    millisec,
    as.numeric(mzClust),
    as.numeric(presence),
    as.numeric(minIntensity)
  ))
}

#' @describeIn ProjectMassSpecS3 Get clustered MS2 spectra for specified analyses and targets.
#' @method get_raw_spectra_ms2 ProjectMassSpec
#' @export
get_raw_spectra_ms2.ProjectMassSpec <- function(
  x,
  analyses = NULL,
  mass = NULL,
  mz = NULL,
  rt = NULL,
  mobility = NULL,
  ppm = 20,
  sec = 60,
  millisec = 5,
  id = NULL,
  isolationWindow = 1.3,
  mzClust = 0.005,
  presence = 0,
  minIntensity = 0
) {
  checkmate::assert_class(x, "ProjectMassSpec")
  data.table::as.data.table(rcpp_project_mass_spec_get_raw_spectra_ms2(
    x$get_mass_spec_ptr(),
    analyses,
    mass,
    mz,
    rt,
    mobility,
    as.character(id),
    ppm,
    sec,
    millisec,
    as.numeric(isolationWindow),
    as.numeric(mzClust),
    as.numeric(presence),
    as.numeric(minIntensity)
  ))
}

#' @describeIn ProjectMassSpecS3 Return chromatogram headers for selected analyses.
#' @method get_chromatograms_headers ProjectMassSpec
#' @export
get_chromatograms_headers.ProjectMassSpec <- function(x, analyses = NULL) {
  checkmate::assert_class(x, "ProjectMassSpec")
  if (is.null(analyses)) {
    analyses <- character()
  }
  analyses_info <- data.table::as.data.table(x$get_analyses())
  hd <- data.table::as.data.table(rcpp_project_mass_spec_get_chromatograms_headers(x$get_mass_spec_ptr(), analyses))
  if (nrow(hd) == 0) {
    return(data.table::data.table())
  }
  replicates <- analyses_info$replicate
  names(replicates) <- analyses_info$analysis
  if ("project_id" %in% colnames(hd)) {
    hd[, project_id := NULL]
  }
  hd$replicate <- replicates[hd$analysis]
  data.table::setcolorder(hd, c("analysis", "replicate"))
  hd
}

#' @describeIn ProjectMassSpecS3 Get raw chromatograms for selected analyses.
#' @method get_raw_chromatograms ProjectMassSpec
#' @export
get_raw_chromatograms.ProjectMassSpec <- function(
  x,
  analyses = NULL,
  chromatograms = NULL,
  rtmin = 0,
  rtmax = 0,
  minIntensity = NULL
) {
  checkmate::assert_class(x, "ProjectMassSpec")
  chrom_hd <- get_chromatograms_headers.ProjectMassSpec(x, analyses)
  if (nrow(chrom_hd) == 0) {
    message("\U2717 No chromatograms found for the analyses!")
    return(data.table::data.table())
  }
  if (is.numeric(chromatograms)) {
    chrom_hd <- chrom_hd[as.integer(chrom_hd$index) == as.integer(chromatograms), ]
  } else if (is.character(chromatograms)) {
    chrom_hd <- chrom_hd[chrom_hd$id %in% chromatograms, ]
  }
  if (nrow(chrom_hd) == 0) {
    message("\U2717 No chromatograms found for the specified IDs/indices!")
    return(data.table::data.table())
  }
  sel_analyses <- unique(chrom_hd$analysis)
  chrom_hd_list <- split(chrom_hd, chrom_hd$analysis)
  chrom_list <- lapply(sel_analyses, function(aname) {
    chrom_hd_a <- chrom_hd_list[[aname]]
    data.table::as.data.table(rcpp_project_mass_spec_get_raw_chromatograms(
      x$get_mass_spec_ptr(),
      aname,
      as.integer(chrom_hd_a$index)
    ))
  })
  chrom_dt <- data.table::rbindlist(chrom_list, fill = TRUE)
  if (nrow(chrom_dt) == 0) {
    message("\U2717 No chromatogram data found for the specified analyses!")
    return(data.table::data.table())
  }
  if (is.numeric(minIntensity)) {
    chrom_dt <- chrom_dt[chrom_dt$intensity > minIntensity, ]
  }
  if (is.numeric(rtmin) && is.numeric(rtmax) && rtmax > 0) {
    chrom_dt <- chrom_dt[chrom_dt$rt >= rtmin & chrom_dt$rt <= rtmax]
  }
  data.table::setcolorder(chrom_dt, c("analysis", "replicate"))
  chrom_dt
}

#' @describeIn ProjectMassSpecS3 Plot raw chromatograms for selected analyses.
#' @method plot_raw_chromatograms ProjectMassSpec
#' @export
plot_raw_chromatograms.ProjectMassSpec <- function(
  x,
  analyses = NULL,
  chromatograms = NULL,
  rtmin = 0,
  rtmax = 0,
  minIntensity = NULL,
  downsize = NULL,
  xLab = NULL,
  yLab = NULL,
  title = NULL,
  groupBy = "analysis",
  interactive = TRUE,
  colorPalette = NULL
) {
  checkmate::assert_class(x, "ProjectMassSpec")
  chrom <- get_raw_chromatograms.ProjectMassSpec(x, analyses, chromatograms, rtmin, rtmax, minIntensity)
  if (nrow(chrom) == 0) {
    message("\U2717 No chromatogram data found for plotting!")
    return(NULL)
  }
  if (!is.null(downsize) && downsize > 0 && nrow(chrom) > downsize) {
    chrom <- data.table::as.data.table(chrom)
    chrom$rt <- floor(chrom$rt / downsize) * downsize
    chrom <- chrom[, lapply(.SD, function(col) {
      if (is.numeric(col)) {
        mean(col, na.rm = TRUE)
      } else if (is.character(col)) {
        col[1]
      } else {
        col[1]
      }
    }), by = .(rt, analysis, id)]
  }
  if (is.null(xLab)) xLab <- "Retention time / seconds"
  if (is.null(yLab)) yLab <- "Intensity / counts"
  .plot_lines_tabular_data(
    data = chrom,
    xvar = "rt",
    yvar = "intensity",
    groupBy = groupBy,
    basicGroupBy = c("analysis", "id"),
    interactive = interactive,
    title = title,
    xLab = xLab,
    yLab = yLab,
    colorPalette = colorPalette
  )
}
