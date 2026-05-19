#' @title ProjectClasses Registry
#' @description Return metadata describing the public StreamFind project classes.
#'   The registry includes the class name, user-facing label, project domain,
#'   supported input file formats, a short description, and the available
#'   project-owned processing method names for each concrete project class.
#' @param project_class Optional public project class name. If `NULL`, returns the full registry.
#' @return If `project_class` is `NULL`, a named list keyed by public project class.
#' Otherwise, a named list describing the selected project class.
#' @export
ProjectClasses <- function(project_class = NULL) {
  registry <- list(
    ProjectMassSpecSpectra = list(
      project_class = "ProjectMassSpecSpectra",
      label = "Mass Spec Spectra",
      domain = "mass_spec_spectra",
      formats = c("mzML", "mzXML", "d", "raw"),
      description = "Shared Mass Spec project focused on spectra import, raw spectra access, and spectra plots.",
      processing_methods = list()
    ),
    ProjectMassSpecChromatograms = list(
      project_class = "ProjectMassSpecChromatograms",
      label = "Mass Spec Chromatograms",
      domain = "mass_spec_chromatograms",
      formats = c("mzML", "mzXML", "d", "raw"),
      description = "Shared Mass Spec project focused on chromatogram extraction and chromatogram plots.",
      processing_methods = list()
    ),
    ProjectNonTargetAnalysis = list(
      project_class = "ProjectNonTargetAnalysis",
      label = "Non-Target Analysis",
      domain = "mass_spec_nts",
      formats = c("mzML", "mzXML", "d", "raw"),
      description = "Shared Mass Spec project focused on non-target screening workflows, features, suspects, and downstream results.",
      processing_methods = unique(vapply(.project_non_target_analysis_processing_methods(), `[[`, character(1), "method"))
    )
  )

  if (is.null(project_class)) {
    return(registry)
  }

  checkmate::assert_character(project_class, len = 1, any.missing = FALSE)
  if (!project_class %in% names(registry)) {
    stop(
      "Unknown project class '", project_class, "'. Available classes are: ",
      paste(names(registry), collapse = ", "), ".",
      call. = FALSE
    )
  }

  registry[[project_class]]
}

#' @title Open or Create a Mass Spec Spectra Project
#' @description Open an existing `ProjectMassSpecSpectra` or construct a new one.
#'   This wrapper is safer named to reflect that a connection to an existing
#'   project may be returned rather than always creating a fresh project.
#' @param db Path to the project DuckDB file.
#' @param project_id Active project identifier.
#' @param file_paths Character vector with Mass Spec file paths.
#' @param replicates Optional character vector with replicate names.
#' @param blanks Optional character vector with blank names.
#' @return A `ProjectMassSpecSpectra` object.
#' @export
OpenProjectMassSpecSpectra <- function(
    db,
    project_id,
    file_paths = character(),
    replicates = character(),
    blanks = character()) {
  ProjectMassSpecSpectra$new(
    db = db,
    project_id = project_id,
    file_paths = file_paths,
    replicates = replicates,
    blanks = blanks
  )
}

#' @title Construct a Mass Spec Chromatograms Project
#' @title Open or Create a Mass Spec Chromatograms Project
#' @description Open an existing `ProjectMassSpecChromatograms` or construct a new one.
#'   This wrapper is named to reflect that a connection to an existing project
#'   may be returned rather than always creating a fresh project.
#' @param db Path to the project DuckDB file.
#' @param project_id Active project identifier.
#' @param file_paths Character vector with Mass Spec file paths.
#' @param replicates Optional character vector with replicate names.
#' @param blanks Optional character vector with blank names.
#' @return A `ProjectMassSpecChromatograms` object.
#' @export
OpenProjectMassSpecChromatograms <- function(
    db,
    project_id,
    file_paths = character(),
    replicates = character(),
    blanks = character()) {
  ProjectMassSpecChromatograms$new(
    db = db,
    project_id = project_id,
    file_paths = file_paths,
    replicates = replicates,
    blanks = blanks
  )
}

#' @title Open or Create a Non-Target Analysis Project
#' @description Open an existing `ProjectNonTargetAnalysis` or construct a new one.
#'   This wrapper is named to reflect that a connection to an existing project
#'   may be returned rather than always creating a fresh project.
#' @param db Path to the project DuckDB file.
#' @param project_id Active project identifier.
#' @return A `ProjectNonTargetAnalysis` object.
#' @export
OpenProjectNonTargetAnalysis <- function(db, project_id) {
  ProjectNonTargetAnalysis$new(db = db, project_id = project_id)
}
