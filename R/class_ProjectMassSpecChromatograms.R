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
