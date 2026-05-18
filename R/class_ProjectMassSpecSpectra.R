#' @title Project Mass Spec Spectra R6 Class
#' @description R6 child of `ProjectMassSpec` exposing the spectra-focused MassSpec interface.
 #' @template arg-db-path
 #' @template arg-project-id
 #' @template arg-file-paths
 #' @template arg-analyses
 #' @template arg-replicates
 #' @template arg-blanks
 #' @template arg-ellipsis
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
    #' @description Return spectra-project processing-step metadata.
    available_processing_methods = function() {
      list()
    },
    #' @description Print a short summary.
    print = function(...) {
      cat("\nProjectMassSpecSpectra\n")
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

#' @name ProjectMassSpecSpectraS3
#' @title ProjectMassSpecSpectra S3 Methods
#' @description S3 interface methods for `ProjectMassSpecSpectra`.
#' These methods are thin wrappers over the `ProjectMassSpecSpectra` R6
#' methods and expose the spectra-specific package generics.
#' @param x A `ProjectMassSpecSpectra` object.
#' @template arg-ellipsis
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
  x$print(...)
}

#' @describeIn ProjectMassSpecSpectraS3 Show a short summary.
#' @export
show.ProjectMassSpecSpectra <- function(x, ...) {
  checkmate::assert_class(x, "ProjectMassSpecSpectra")
  x$show(...)
}
