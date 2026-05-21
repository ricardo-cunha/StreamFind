#' @title Project Mass Spec Spectra R6 Class
#' @description R6 child of `ProjectMassSpec` exposing the spectra-focused MassSpec interface.
 #' @template arg-Project-db
 #' @template arg-Project-project-id
 #' @template arg-ProjectMassSpec-file-paths
 #' @template arg-ProjectMassSpec-analyses
 #' @template arg-ProjectMassSpec-replicates
 #' @template arg-ProjectMassSpec-blanks
 #' @template arg-Project-ellipsis
 #' @export
ProjectMassSpecSpectra <- R6::R6Class(
  classname = "ProjectMassSpecSpectra",
  inherit = ProjectMassSpec,
  cloneable = FALSE,
  private = list(
    .mass_spec_spectra_ptr = NULL
  ),
  public = list(
    #' @description Create a spectra-specific Mass Spec project wrapper.
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
      spectra_ptr_res <- .pull_internal_init_arg(mass_spec_ptr_res$dots, ".mass_spec_spectra_ptr")
      .mass_spec_spectra_ptr <- spectra_ptr_res$value
      .assert_only_internal_init_args(spectra_ptr_res$dots, "ProjectMassSpecSpectra$initialize()")
      super$initialize(
        db = db,
        project_id = project_id,
        .ptr = .ptr,
        .mass_spec_ptr = .mass_spec_ptr,
        file_paths = character(),
        replicates = character(),
        blanks = character()
      )
      private$.mass_spec_spectra_ptr <- if (is.null(.mass_spec_spectra_ptr)) {
        rcpp_project_mass_spec_spectra_new(self$get_ptr(), file_paths, replicates, blanks)
      } else {
        .mass_spec_spectra_ptr
      }
      if (length(file_paths) > 0 && !is.null(.mass_spec_spectra_ptr)) {
        self$add_analyses(file_paths = file_paths, replicates = replicates, blanks = blanks)
      }
    },
    #' @description Return the native spectra pointer.
    get_mass_spec_spectra_ptr = function() {
      private$.mass_spec_spectra_ptr
    },
    #' @description Return spectra-project method metadata.
    available_processing_methods = function() {
      available_processing_methods.Project(self)
    },
    #' @description Print a short summary.
    print = function(...) {
      print.ProjectMassSpecSpectra(self, ...)
    },
    #' @description Show a short summary.
    show = function(...) {
      show.ProjectMassSpecSpectra(self, ...)
    }
  )
)

#' @name ProjectMassSpecSpectraS3
#' @title ProjectMassSpecSpectra S3 Methods
#' @description S3 interface methods for `ProjectMassSpecSpectra`.
#' These methods are thin wrappers over the `ProjectMassSpecSpectra` R6
#' methods and expose the spectra-specific package generics.
#' @param x A `ProjectMassSpecSpectra` object.
#' @template arg-Project-ellipsis
NULL

#' @describeIn ProjectMassSpecSpectraS3 Return the native spectra pointer.
#' @export
get_mass_spec_spectra_ptr.ProjectMassSpecSpectra <- function(x) {
  checkmate::assert_class(x, "ProjectMassSpecSpectra")
  x$get_mass_spec_spectra_ptr()
}

#' @describeIn ProjectMassSpecSpectraS3 Return spectra processing methods.
#' @export
available_processing_methods.ProjectMassSpecSpectra <- function(x) {
  checkmate::assert_class(x, "ProjectMassSpecSpectra")
  x$available_processing_methods()
}

#' @describeIn ProjectMassSpecSpectraS3 Print a short summary.
#' @export
print.ProjectMassSpecSpectra <- function(x, ...) {
  checkmate::assert_class(x, "ProjectMassSpecSpectra")
  .print_project_mass_spec_summary(x, title = "ProjectMassSpecSpectra")
  invisible(x)
}

#' @describeIn ProjectMassSpecSpectraS3 Show a short summary.
#' @export
show.ProjectMassSpecSpectra <- function(x, ...) {
  checkmate::assert_class(x, "ProjectMassSpecSpectra")
  print.ProjectMassSpecSpectra(x, ...)
}

#' @describeIn ProjectMassSpecSpectraS3 Plot extracted ion chromatograms (EIC) for specified analyses and targets.
#' @method plot_raw_spectra_eic ProjectMassSpecSpectra
#' @export
plot_raw_spectra_eic.ProjectMassSpecSpectra <- function(x, ...) {
  checkmate::assert_class(x, "ProjectMassSpecSpectra")
  plot_raw_spectra_eic.ProjectMassSpec(x, ...)
}
