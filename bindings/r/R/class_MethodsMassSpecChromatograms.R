#' @noRd
.ms_chrom_method_defaults <- function(required = character(), number_permitted = 1) {
  list(
    required = required,
    owner_class = "ProjectMassSpecChromatograms",
    number_permitted = number_permitted,
    developer = "Ricardo Cunha",
    contact = "cunha@iuta.de",
    link = "https://odea-project.github.io/streamfind",
    doi = NA_character_
  )
}

#' @noRd
.validate_ms_chrom_method_base <- function(x, class_name, method, number_permitted = NULL) {
  validate_object.Method(x)
  checkmate::assert_class(x, class_name)
  checkmate::assert_choice(x$method, method)
  checkmate::assert_choice(x$owner_class, "ProjectMassSpecChromatograms")
  if (!is.null(number_permitted)) {
    checkmate::assert_true(identical(x$number_permitted, number_permitted))
  }
  invisible(NULL)
}

#' @noRd
.run_ms_chrom_method <- function(success, proj, warning_text) {
  if (!isTRUE(success)) {
    warning(warning_text)
  }
  invisible(proj)
}

#' @title Method_MassSpecChromatograms_LoadChromatograms
#' @description Create a `Method` child object for loading raw chromatograms
#'   from mass spectrometry files into the project database. Chromatograms are
#'   selected by regular-expression rules applied to the chromatogram id/name
#'   from the raw file headers.
#' @param chromatogramIdRegex Character vector of regular expressions matched
#'   against chromatogram ids/names.
#' @param ignoreCase Logical(1) whether to use case-insensitive regex matching.
#' @param invert Logical(1) whether to keep non-matching chromatograms.
#' @return A `Method` object of class `Method_MassSpecChromatograms_LoadChromatograms`.
#' @export
Method_MassSpecChromatograms_LoadChromatograms <- function(
    chromatogramIdRegex = ".*",
    ignoreCase = TRUE,
    invert = FALSE) {
  x <- do.call(
    Method,
    c(
      list(
        method = "LoadChromatograms",
        parameters = list(
          chromatogramIdRegex = as.character(chromatogramIdRegex),
          ignoreCase = as.logical(ignoreCase),
          invert = as.logical(invert)
        )
      ),
      .ms_chrom_method_defaults(required = character(), number_permitted = 1)
    )
  )
  validate_object(x)
  x
}

#' @export
#' @noRd
validate_object.Method_MassSpecChromatograms_LoadChromatograms <- function(x, ...) {
  .validate_ms_chrom_method_base(x, "Method_MassSpecChromatograms_LoadChromatograms", "LoadChromatograms", 1)
  checkmate::assert_character(x$parameters$chromatogramIdRegex, min.len = 1, any.missing = FALSE)
  checkmate::assert_logical(x$parameters$ignoreCase, len = 1, any.missing = FALSE)
  checkmate::assert_logical(x$parameters$invert, len = 1, any.missing = FALSE)
  invisible(NULL)
}

#' @export
#' @noRd
run.Method_MassSpecChromatograms_LoadChromatograms <- function(x, proj, ...) {
  checkmate::assert_class(x, "Method_MassSpecChromatograms_LoadChromatograms")
  validate_object(x)
  checkmate::assert_class(proj, "ProjectMassSpecChromatograms")
  params <- x$parameters
  success <- rcpp_project_mass_spec_chromatograms_load(
    chromatograms_xptr = proj$get_mass_spec_chromatograms_ptr(),
    analyses = character(),
    chromatogramIdRegex = as.character(params$chromatogramIdRegex),
    ignoreCase = isTRUE(params$ignoreCase),
    invert = isTRUE(params$invert)
  )
  .run_ms_chrom_method(success, proj, "Loading chromatograms did not complete successfully.")
}

#' @title Method_MassSpecChromatograms_FilterChromatogramsRetentionTime
#' @description Create a `Method` child object for filtering loaded chromatograms
#'   by retention time. Points outside the specified RT window are removed from
#'   the `MS_CHROMATOGRAMS` table.
#' @param rtmin Numeric(1) minimum retention time to keep (in seconds).
#' @param rtmax Numeric(1) maximum retention time to keep (in seconds).
#' @return A `Method` object of class `Method_MassSpecChromatograms_FilterChromatogramsRetentionTime`.
#' @export
Method_MassSpecChromatograms_FilterChromatogramsRetentionTime <- function(
    rtmin,
    rtmax) {
  x <- do.call(
    Method,
    c(
      list(
        method = "FilterChromatogramsRetentionTime",
        parameters = list(
          rtmin = as.numeric(rtmin),
          rtmax = as.numeric(rtmax)
        )
      ),
      .ms_chrom_method_defaults(required = "LoadChromatograms", number_permitted = Inf)
    )
  )
  validate_object(x)
  x
}

#' @export
#' @noRd
validate_object.Method_MassSpecChromatograms_FilterChromatogramsRetentionTime <- function(x, ...) {
  .validate_ms_chrom_method_base(x, "Method_MassSpecChromatograms_FilterChromatogramsRetentionTime", "FilterChromatogramsRetentionTime", Inf)
  checkmate::assert_number(x$parameters$rtmin, finite = TRUE)
  checkmate::assert_number(x$parameters$rtmax, finite = TRUE)
  checkmate::assert_true(x$parameters$rtmin < x$parameters$rtmax)
  invisible(NULL)
}

#' @export
#' @noRd
run.Method_MassSpecChromatograms_FilterChromatogramsRetentionTime <- function(x, proj, ...) {
  checkmate::assert_class(x, "Method_MassSpecChromatograms_FilterChromatogramsRetentionTime")
  validate_object(x)
  checkmate::assert_class(proj, "ProjectMassSpecChromatograms")
  params <- x$parameters
  success <- rcpp_project_mass_spec_chromatograms_filter_rt(
    chromatograms_xptr = proj$get_mass_spec_chromatograms_ptr(),
    analyses = character(),
    rtmin = as.numeric(params$rtmin),
    rtmax = as.numeric(params$rtmax)
  )
  .run_ms_chrom_method(success, proj, "Retention-time filtering of chromatograms did not complete successfully.")
}
