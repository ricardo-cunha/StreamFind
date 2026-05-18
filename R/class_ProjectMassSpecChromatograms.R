#' @title Project Mass Spec Chromatograms R6 Class
#' @description R6 child of `ProjectMassSpec` exposing the chromatogram-focused MassSpec interface.
#' @template arg-db-path
#' @template arg-project-id
#' @template arg-file-paths
#' @template arg-analyses
#' @template arg-replicates
#' @template arg-blanks
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
#' @template arg-ellipsis
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
    #' @description Return chromatogram-project processing-step metadata.
    available_processing_methods = function() {
      list()
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
    #' @description Get chromatograms for selected analyses.
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
    print = function(...) {
      cat("\nProjectMassSpecChromatograms\n")
      cat("db: ", self$db, "\n", sep = "")
      cat("project_id: ", self$project_id, "\n", sep = "")
      domain <- try(self$get_domain(), silent = TRUE)
      if (!inherits(domain, "try-error") && !is.null(domain)) {
        cat("domain: ", domain, "\n", sep = "")
      }
      analyses <- try(self$get_analyses(), silent = TRUE)
      if (!inherits(analyses, "try-error")) {
        cat("analyses: ", nrow(analyses), "\n", sep = "")
      }
      invisible(self)
    },
    #' @description Show a short summary.
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
#' @template arg-ellipsis
NULL

#' @describeIn ProjectMassSpecChromatogramsS3 Return chromatogram headers for selected analyses.
#' @export
get_chromatograms_headers.ProjectMassSpecChromatograms <- function(x, analyses = NULL) {
  checkmate::assert_class(x, "ProjectMassSpecChromatograms")
  x$get_chromatograms_headers(analyses = analyses)
}

#' @describeIn ProjectMassSpecChromatogramsS3 Get chromatograms for selected analyses.
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

#' @describeIn ProjectMassSpecChromatogramsS3 Plot chromatograms for selected analyses.
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
