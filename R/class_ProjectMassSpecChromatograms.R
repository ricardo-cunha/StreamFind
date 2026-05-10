#' @title Project Mass Spec Chromatograms R6 Class
#' @description R6 child of `ProjectMassSpec` exposing the chromatogram-focused
#'   Mass Spec interface backed by the native C++ chromatograms facade.
#' @details
#' This is a public user-facing project class.
#'
#' In addition to the methods documented on this page, it inherits shared project
#' runtime methods such as `run_app()`, `run_workflow()`, `report_quarto()`,
#' `metadata`, `workflow`, `get_audit()`, and `list_tables()`, plus shared Mass
#' Spec methods such as `import_files()`, `list_analyses()`, `get_analysis_names()`,
#' `get_replicate_names()`, `set_replicate_names()`, `get_blank_names()`,
#' `set_blank_names()`, and `get_concentrations()`.
#'
#' See `?Project` for shared project/runtime methods and `?ProjectMassSpec` for
#' inherited shared Mass Spec methods.
#'
#' Use `?ProjectMassSpecChromatograms` as the main entry point for the
#' chromatogram-specific interface on top of those base classes.
#' @param db Path to the project DuckDB file.
#' @param project_id Active project identifier.
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
    #' @param db Path to the DuckDB project file.
    #' @param project_id Active project identifier.
    #' @param .ptr Existing native project pointer for internal use.
    #' @param .mass_spec_ptr Existing native shared Mass Spec pointer for internal use.
    #' @param .mass_spec_chromatograms_ptr Existing native chromatograms pointer for internal use.
    initialize = function(db, project_id, .ptr = NULL, .mass_spec_ptr = NULL, .mass_spec_chromatograms_ptr = NULL) {
      super$initialize(db = db, project_id = project_id, .ptr = .ptr, .mass_spec_ptr = .mass_spec_ptr)
      private$.mass_spec_chromatograms_ptr <- if (is.null(.mass_spec_chromatograms_ptr)) {
        rcpp_project_mass_spec_chromatograms_new(self$get_ptr())
      } else {
        .mass_spec_chromatograms_ptr
      }
    },
    #' @description Return the native chromatograms pointer.
    get_mass_spec_chromatograms_ptr = function() {
      private$.mass_spec_chromatograms_ptr
    },
    #' @description Return chromatogram-project processing-step metadata.
    #' @return A named list of `ProcessingStep` metadata objects.
    available_processing_methods = function() {
      list()
    },
    #' @description Return chromatogram headers for selected analyses.
    #' @template arg-analyses
    get_chromatograms_headers = function(analyses = NULL) {
      analyses_info <- data.table::as.data.table(self$list_analyses())
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
    #' @description Get chromatograms for selected analyses.
    #' @template arg-analyses
    #' @template arg-chromatograms
    #' @template arg-ms-rtmin
    #' @template arg-ms-rtmax
    #' @template arg-ms-minIntensity
    get_chromatograms = function(
        analyses = NULL,
        chromatograms = NULL,
        rtmin = 0,
        rtmax = 0,
        minIntensity = NULL) {
      chrom_hd <- self$get_chromatograms_headers(analyses)
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
        data.table::as.data.table(rcpp_project_mass_spec_chromatograms_extract(
          private$.mass_spec_chromatograms_ptr,
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
    },
    #' @description Plot chromatograms for selected analyses.
    #' @template arg-analyses
    #' @template arg-chromatograms
    #' @template arg-ms-rtmin
    #' @template arg-ms-rtmax
    #' @template arg-ms-minIntensity
    #' @template arg-plot-downsize
    #' @template arg-plot-xLab
    #' @template arg-plot-yLab
    #' @template arg-plot-title
    #' @template arg-plot-groupBy
    #' @template arg-plot-interactive
    #' @template arg-plot-colorPalette
    plot_chromatograms = function(
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
        colorPalette = NULL) {
      chrom <- self$get_chromatograms(analyses, chromatograms, rtmin, rtmax, minIntensity)
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
        basicGroupBy = "id",
        interactive = interactive,
        title = title,
        xLab = xLab,
        yLab = yLab,
        colorPalette = colorPalette
      )
    },
    #' @description Print a short summary.
    #' @param ... Additional arguments ignored.
    print = function(...) {
      cat("\nProjectMassSpecChromatograms\n")
      cat("db: ", self$db, "\n", sep = "")
      cat("project_id: ", self$project_id, "\n", sep = "")
      domain <- try(self$get_domain(), silent = TRUE)
      if (!inherits(domain, "try-error") && !is.null(domain)) {
        cat("domain: ", domain, "\n", sep = "")
      }
      analyses <- try(self$list_analyses(), silent = TRUE)
      if (!inherits(analyses, "try-error")) {
        cat("analyses: ", nrow(analyses), "\n", sep = "")
      }
      invisible(self)
    },
    #' @description Show a short summary.
    #' @param ... Additional arguments ignored.
    show = function(...) {
      self$print(...)
    }
  )
)

#' @name ProjectMassSpecChromatogramsS3
#' @title ProjectMassSpecChromatograms S3 Methods
#' @description S3 interface methods for `ProjectMassSpecChromatograms`.
#' These methods are thin wrappers over the `ProjectMassSpecChromatograms` R6
#' methods and expose the chromatogram-specific package generics.
#' @details
#' Available methods are:
#'
#' Header methods:
#' - `get_chromatograms_headers()`: Fetch chromatogram headers for the specified analyses.
#'
#' Chromatogram methods:
#' - `get_chromatograms()`: Get chromatograms for the specified analyses and chromatogram IDs/indices.
#' - `plot_chromatograms()`: Plot chromatograms for the specified analyses and chromatogram IDs/indices.
#' @aliases get_chromatograms_headers.ProjectMassSpecChromatograms
#'   get_chromatograms.ProjectMassSpecChromatograms
#'   plot_chromatograms.ProjectMassSpecChromatograms
#' @param x A `ProjectMassSpecChromatograms` object.
#' @rdname ProjectMassSpecChromatogramsS3
#' @template arg-analyses
#' @export
get_chromatograms_headers.ProjectMassSpecChromatograms <- function(x, analyses = NULL) {
  checkmate::assert_class(x, "ProjectMassSpecChromatograms")
  x$get_chromatograms_headers(analyses = analyses)
}

#' @rdname ProjectMassSpecChromatogramsS3
#' @param x A `ProjectMassSpecChromatograms` object.
#' @template arg-analyses
#' @template arg-chromatograms
#' @template arg-ms-rtmin
#' @template arg-ms-rtmax
#' @template arg-ms-minIntensity
#' @export
get_chromatograms.ProjectMassSpecChromatograms <- function(
    x,
    analyses = NULL,
    chromatograms = NULL,
    rtmin = 0,
    rtmax = 0,
    minIntensity = NULL) {
  checkmate::assert_class(x, "ProjectMassSpecChromatograms")
  x$get_chromatograms(
    analyses = analyses,
    chromatograms = chromatograms,
    rtmin = rtmin,
    rtmax = rtmax,
    minIntensity = minIntensity
  )
}

#' @rdname ProjectMassSpecChromatogramsS3
#' @param x A `ProjectMassSpecChromatograms` object.
#' @template arg-analyses
#' @template arg-chromatograms
#' @template arg-ms-rtmin
#' @template arg-ms-rtmax
#' @template arg-ms-minIntensity
#' @template arg-plot-downsize
#' @template arg-plot-xLab
#' @template arg-plot-yLab
#' @template arg-plot-title
#' @template arg-plot-groupBy
#' @template arg-plot-interactive
#' @template arg-plot-colorPalette
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
    colorPalette = NULL) {
  checkmate::assert_class(x, "ProjectMassSpecChromatograms")
  x$plot_chromatograms(
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
    colorPalette = colorPalette
  )
}
