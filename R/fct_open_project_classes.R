#' @title Projects Overview
#' @description Return metadata describing the public streamfind project classes.
#'   The overview includes the class name, user-facing label, project domain,
#'   supported input file formats, a short description, the corresponding
#'   `open_<ProjectClass>()` function name, app module owners, result module
#'   classes, and discovered project-owned method names for each concrete
#'   project class.
#' @param project_class Optional public project class name. If `NULL`, returns the full registry.
#' @return If `project_class` is `NULL`, a named list keyed by public project class.
#' Otherwise, a named list describing the selected project class.
#' @export
projects_overview <- function(project_class = NULL) {
  registry <- list(
    ProjectMassSpecSpectra = list(
      project_class = "ProjectMassSpecSpectra",
      label = "Mass Spec Spectra",
      domain = "mass_spec_spectra",
      formats = c("mzML", "mzXML", "d", "raw"),
      description = "Shared Mass Spec project focused on spectra import, raw spectra access, and spectra plots.",
      open_function = .project_open_function_name("ProjectMassSpecSpectra"),
      analyses_owner = "ProjectMassSpec",
      explorer_owner = "ProjectMassSpec",
      result_classes = character(),
      processing_methods = names(.discover_project_methods("ProjectMassSpecSpectra"))
    ),
    ProjectMassSpecChromatograms = list(
      project_class = "ProjectMassSpecChromatograms",
      label = "Mass Spec Chromatograms",
      domain = "mass_spec_chromatograms",
      formats = c("mzML", "mzXML", "d", "raw"),
      description = "Shared Mass Spec project focused on chromatogram extraction and chromatogram plots.",
      open_function = .project_open_function_name("ProjectMassSpecChromatograms"),
      analyses_owner = "ProjectMassSpec",
      explorer_owner = "ProjectMassSpec",
      result_classes = "ProjectMassSpecChromatograms",
      processing_methods = names(.discover_project_methods("ProjectMassSpecChromatograms"))
    ),
    ProjectNonTargetAnalysis = list(
      project_class = "ProjectNonTargetAnalysis",
      label = "Non-Target Analysis",
      domain = "mass_spec_nta",
      formats = c("mzML", "mzXML", "d", "raw"),
      description = "Shared Mass Spec project focused on non-target screening workflows, features, suspects, and downstream results.",
      open_function = .project_open_function_name("ProjectNonTargetAnalysis"),
      analyses_owner = "ProjectMassSpec",
      explorer_owner = "ProjectMassSpec",
      result_classes = "ProjectNonTargetAnalysis",
      processing_methods = names(.discover_project_methods("ProjectNonTargetAnalysis"))
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

#' @noRd
.project_class_from_domain <- function(domain, registry = projects_overview()) {
  checkmate::assert_character(domain, len = 1, any.missing = FALSE)
  matches <- names(Filter(function(entry) identical(entry$domain, domain), registry))
  if (length(matches) != 1) {
    return(NA_character_)
  }
  matches[[1]]
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
open_ProjectMassSpecSpectra <- function(
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
open_ProjectMassSpecChromatograms <- function(
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
#' @param file_paths Character vector with Mass Spec file paths.
#' @param replicates Optional character vector with replicate names.
#' @param blanks Optional character vector with blank names.
#' @return A `ProjectNonTargetAnalysis` object.
#' @export
open_ProjectNonTargetAnalysis <- function(
    db,
    project_id,
    file_paths = character(),
    replicates = character(),
    blanks = character()) {
  ProjectNonTargetAnalysis$new(
    db = db,
    project_id = project_id,
    file_paths = file_paths,
    replicates = replicates,
    blanks = blanks
  )
}
