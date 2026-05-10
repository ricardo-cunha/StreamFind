#' @title Project Mass Spec Spectra R6 Class
#' @description R6 child of `ProjectMassSpec` exposing the spectra-focused Mass
#'   Spec interface backed by the native C++ spectra facade. Shared raw spectra
#'   access remains on `ProjectMassSpec` so both `ProjectMassSpecSpectra` and
#'   `ProjectNonTargetAnalysis` inherit the same base spectra helpers.
#' @details
#' This is a public user-facing project class.
#'
#' In addition to the methods documented on this page, it inherits shared project
#' runtime methods such as `run_app()`, `run_workflow()`, `report_quarto()`,
#' `metadata`, `workflow`, `get_audit()`, and `list_tables()`, plus shared Mass
#' Spec methods such as `import_files()`, `list_analyses()`, `get_spectra_headers()`,
#' `get_raw_spectra()`, `get_raw_spectra_tic()`, `get_raw_spectra_bpc()`,
#' `get_raw_spectra_eic()`, `get_raw_spectra_ms1()`, `get_raw_spectra_ms2()`,
#' `plot_spectra_tic()`, `plot_spectra_bpc()`, and `plot_spectra_eic()`.
#'
#' See `?Project` for shared project/runtime methods and `?ProjectMassSpec` for
#' inherited shared Mass Spec methods.
#'
#' Use `?ProjectMassSpecSpectra` as the main entry point for the spectra-specific
#' interface on top of those base classes.
#' @param db Path to the project DuckDB file.
#' @param project_id Active project identifier.
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
    #' @param db Path to the DuckDB project file.
    #' @param project_id Active project identifier.
    #' @param .ptr Existing native project pointer for internal use.
    #' @param .mass_spec_ptr Existing native shared Mass Spec pointer for internal use.
    #' @param .mass_spec_spectra_ptr Existing native spectra pointer for internal use.
    initialize = function(db, project_id, .ptr = NULL, .mass_spec_ptr = NULL, .mass_spec_spectra_ptr = NULL) {
      super$initialize(db = db, project_id = project_id, .ptr = .ptr, .mass_spec_ptr = .mass_spec_ptr)
      private$.mass_spec_spectra_ptr <- if (is.null(.mass_spec_spectra_ptr)) {
        rcpp_project_mass_spec_spectra_new(self$get_ptr())
      } else {
        .mass_spec_spectra_ptr
      }
    },
    #' @description Return the native spectra pointer.
    get_mass_spec_spectra_ptr = function() {
      private$.mass_spec_spectra_ptr
    },
    #' @description Return spectra-project processing-step metadata.
    #' @return A named list of `ProcessingStep` metadata objects.
    available_processing_methods = function() {
      list()
    },
    #' @description Print a short summary.
    #' @param ... Additional arguments ignored.
    print = function(...) {
      cat("\nProjectMassSpecSpectra\n")
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
