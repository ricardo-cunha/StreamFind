#' @title Project Mass Spec Chromatograms R6 Class
#' @description R6 child of `ProjectMassSpec` exposing the chromatogram-focused MassSpec interface.
#' @template arg-Project-db
#' @template arg-Project-project-id
#' @template arg-ProjectMassSpec-file-paths
#' @template arg-ProjectMassSpec-analyses
#' @template arg-ProjectMassSpec-replicates
#' @template arg-ProjectMassSpec-blanks
#' @template arg-ProjectMassSpec-chromatograms
#' @template arg-ProjectMassSpec-rtmin
#' @template arg-ProjectMassSpec-rtmax
#' @template arg-ProjectMassSpec-minIntensity
#' @template arg-ProjectMassSpec-plot-downsize
#' @template arg-ProjectMassSpec-plot-xLab
#' @template arg-ProjectMassSpec-plot-yLab
#' @template arg-ProjectMassSpec-plot-title
#' @template arg-ProjectMassSpec-plot-groupBy
#' @template arg-ProjectMassSpec-plot-interactive
#' @template arg-ProjectMassSpec-plot-colorPalette
#' @template arg-ProjectMassSpec-darkMode
#' @template arg-Project-ellipsis
#' @keywords internal
#' @export
ProjectMassSpecChromatograms <- R6::R6Class(
  classname = "ProjectMassSpecChromatograms",
  inherit = ProjectMassSpec,
  cloneable = FALSE,
  private = list(
    .mass_spec_chromatograms_ptr = NULL
  ),
  public = list(
    #' @description Create a chromatogram-specific Mass Spec project wrapper.
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
      chromatograms_ptr_res <- .pull_internal_init_arg(mass_spec_ptr_res$dots, ".mass_spec_chromatograms_ptr")
      .mass_spec_chromatograms_ptr <- chromatograms_ptr_res$value
      .assert_only_internal_init_args(chromatograms_ptr_res$dots, "ProjectMassSpecChromatograms$initialize()")
      super$initialize(
        db = db,
        project_id = project_id,
        .ptr = .ptr,
        .mass_spec_ptr = .mass_spec_ptr,
        file_paths = character(),
        replicates = character(),
        blanks = character()
      )
      private$.mass_spec_chromatograms_ptr <- if (is.null(.mass_spec_chromatograms_ptr)) {
        rcpp_project_mass_spec_chromatograms_new(self$get_ptr(), file_paths, replicates, blanks)
      } else {
        .mass_spec_chromatograms_ptr
      }
      if (length(file_paths) > 0 && !is.null(.mass_spec_chromatograms_ptr)) {
        self$add_analyses(file_paths = file_paths, replicates = replicates, blanks = blanks)
      }
    },
    #' @description Return the native chromatograms pointer.
    get_mass_spec_chromatograms_ptr = function() {
      private$.mass_spec_chromatograms_ptr
    },
    #' @description Return chromatogram-project method metadata.
    available_processing_methods = function() {
      available_processing_methods.Project(self)
    },
    #' @description Return chromatogram headers for selected analyses.
    get_chromatograms_headers = function(analyses = NULL) {
      analyses_info <- data.table::as.data.table(self$get_analyses())
      all_names <- analyses_info$analysis
      sel_names <- .resolve_analyses_selection(analyses, all_names)
      if (length(sel_names) == 0) {
        return(data.table::data.table())
      }
      hd <- data.table::as.data.table(rcpp_project_mass_spec_get_chromatograms_headers(self$get_mass_spec_ptr(), sel_names))
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
    },
    #' @description Return loaded chromatograms from the MS_CHROMATOGRAMS table.
    get_chromatograms = function(analyses = NULL, chromatograms = NULL, rtmin = 0, rtmax = 0, minIntensity = NULL) {
      analyses_info <- data.table::as.data.table(self$get_analyses())
      all_names <- analyses_info$analysis
      sel_names <- .resolve_analyses_selection(analyses, all_names)
      chrom_dt <- data.table::as.data.table(
        rcpp_project_mass_spec_chromatograms_get_chromatograms(
          chromatograms_xptr = self$get_mass_spec_chromatograms_ptr(),
          analyses = sel_names
        )
      )
      if (nrow(chrom_dt) == 0) {
        return(data.table::data.table())
      }
      if (is.character(chromatograms) && length(chromatograms) > 0) {
        chrom_dt <- chrom_dt[chrom_dt$chromatogram_id %in% chromatograms, ]
      }
      if (is.numeric(minIntensity)) {
        chrom_dt <- chrom_dt[chrom_dt$intensity > minIntensity, ]
      }
      if (is.numeric(rtmin) && is.numeric(rtmax) && rtmax > 0) {
        chrom_dt <- chrom_dt[chrom_dt$rt >= rtmin & chrom_dt$rt <= rtmax]
      }
      replicates <- analyses_info$replicate
      names(replicates) <- analyses_info$analysis
      chrom_dt$replicate <- replicates[chrom_dt$analysis]
      if ("project_id" %in% colnames(chrom_dt)) {
        chrom_dt[, project_id := NULL]
      }
      data.table::setcolorder(chrom_dt, c("analysis", "replicate"))
      chrom_dt
    },
    #' @description Plot chromatograms from the MS_CHROMATOGRAMS table.
    plot_chromatograms = function(analyses = NULL,
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
                                  colorPalette = NULL,
                                  darkMode = FALSE) {
      plot_chromatograms.ProjectMassSpecChromatograms(
        self,
        analyses = analyses,
        chromatograms = chromatograms,
        rtmin = rtmin,
        rtmax = rtmax,
        minIntensity = minIntensity,
        downsize = downsize,
        xLab = xLab,
        yLab = yLab,
        title = title,
        groupBy = groupBy,
        interactive = interactive,
        colorPalette = colorPalette,
        darkMode = darkMode
      )
    },
    #' @description Print a short summary.
    print = function(...) {
      print.ProjectMassSpecChromatograms(self, ...)
    },
    #' @description Show a short summary.
    show = function(...) {
      show.ProjectMassSpecChromatograms(self, ...)
    }
  )
)

#' @name ProjectMassSpecChromatogramsS3
#' @title ProjectMassSpecChromatograms S3 Methods
#' @description S3 interface methods for `ProjectMassSpecChromatograms`.
#' These methods are thin wrappers over the `ProjectMassSpecChromatograms` R6
#' methods and expose the chromatogram-specific package generics.
#' @param x A `ProjectMassSpecChromatograms` object.
#' @template arg-ProjectMassSpec-analyses
#' @template arg-Project-ellipsis
NULL

#' @describeIn ProjectMassSpecChromatogramsS3 Return chromatogram headers for selected analyses.
#' @export
get_chromatograms_headers.ProjectMassSpecChromatograms <- function(x, analyses = NULL) {
  checkmate::assert_class(x, "ProjectMassSpecChromatograms")
  x$get_chromatograms_headers(analyses = analyses)
}

#' @describeIn ProjectMassSpecChromatogramsS3 Return loaded chromatograms from the MS_CHROMATOGRAMS table.
#' @export
get_chromatograms.ProjectMassSpecChromatograms <- function(x, analyses = NULL, chromatograms = NULL, rtmin = 0, rtmax = 0, minIntensity = NULL) {
  checkmate::assert_class(x, "ProjectMassSpecChromatograms")
  x$get_chromatograms(analyses = analyses, chromatograms = chromatograms, rtmin = rtmin, rtmax = rtmax, minIntensity = minIntensity)
}

#' @describeIn ProjectMassSpecChromatogramsS3 Plot chromatograms from the MS_CHROMATOGRAMS table.
#' @export
plot_chromatograms.ProjectMassSpecChromatograms <- function(
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
  colorPalette = NULL,
  darkMode = FALSE
) {
  checkmate::assert_class(x, "ProjectMassSpecChromatograms")
  chrom <- get_chromatograms.ProjectMassSpecChromatograms(x, analyses, chromatograms, rtmin, rtmax, minIntensity)
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
    }), by = .(rt, analysis, chromatogram_id)]
  }
  if (is.null(xLab)) xLab <- "Retention time / seconds"
  if (is.null(yLab)) yLab <- "Intensity / counts"
  .plot_lines_tabular_data(
    data = chrom,
    xvar = "rt",
    yvar = "intensity",
    groupBy = groupBy,
    basicGroupBy = c("analysis", "chromatogram_id"),
    interactive = interactive,
    title = title,
    xLab = xLab,
    yLab = yLab,
    colorPalette = colorPalette,
    darkMode = darkMode
  )
}

#' @describeIn ProjectMassSpecChromatogramsS3 Print a short summary.
#' @export
print.ProjectMassSpecChromatograms <- function(x, ...) {
  checkmate::assert_class(x, "ProjectMassSpecChromatograms")
  .print_project_mass_spec_summary(x, title = "ProjectMassSpecChromatograms")
  invisible(x)
}

#' @describeIn ProjectMassSpecChromatogramsS3 Show a short summary.
#' @export
show.ProjectMassSpecChromatograms <- function(x, ...) {
  checkmate::assert_class(x, "ProjectMassSpecChromatograms")
  print.ProjectMassSpecChromatograms(x, ...)
}
