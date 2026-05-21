#' @title Method_NonTargetAnalysis_FindFeatures
#' @description Create a `Method` child object for the native
#'   non-target-analysis feature finding routine.
#' @param rtWindows A data.frame/data.table with `rtmin` and `rtmax` columns
#'   defining retention-time windows in seconds to include during feature
#'   finding.
#' @param ppmThreshold Numeric(1) maximum allowed mass error in ppm for
#'   clustering traces into one feature.
#' @param noiseThreshold Numeric(1) lowest intensity threshold applied before
#'   feature finding.
#' @param minSNR Numeric(1) minimum signal-to-noise ratio for keeping traces
#'   and candidate peaks.
#' @param minTraces Integer(1) minimum number of traces required to keep one
#'   mass cluster.
#' @param baselineWindow Numeric(1) retention-time window in seconds used to
#'   estimate the local baseline.
#' @param maxWidth Numeric(1) expected maximum chromatographic peak width in
#'   seconds.
#' @param baseQuantile Numeric(1) quantile used to estimate the baseline.
#' @param debugAnalysis Character(1) analysis name for debug logging. Use an
#'   empty string to disable or to include all analyses depending on the native
#'   implementation.
#' @param debugMZ Numeric(1) target m/z for debug logging. Use `0` to disable.
#' @param debugSpecIdx Integer(1) spectrum index for debug logging. Use `-1` to
#'   disable.
#' @return A `Method` object of class
#'   `Method_NonTargetAnalysis_FindFeatures`.
#' @export
Method_NonTargetAnalysis_FindFeatures <- function(
    rtWindows = data.frame(rtmin = numeric(), rtmax = numeric()),
    ppmThreshold = 15,
    noiseThreshold = 250,
    minSNR = 3,
    minTraces = 3L,
    baselineWindow = 200,
    maxWidth = 100,
    baseQuantile = 0.1,
    debugAnalysis = "",
    debugMZ = 0,
    debugSpecIdx = -1L) {
  rt_windows <- data.table::as.data.table(rtWindows)
  if (nrow(rt_windows) == 0L) {
    rt_windows <- data.table::data.table(rtmin = numeric(), rtmax = numeric())
  }
  if (!all(c("rtmin", "rtmax") %in% names(rt_windows))) {
    stop("`rtWindows` must contain `rtmin` and `rtmax` columns.")
  }
  rt_windows <- data.table::data.table(
    rtmin = as.numeric(rt_windows$rtmin),
    rtmax = as.numeric(rt_windows$rtmax)
  )

  x <- Method(
    method = "FindFeatures",
    required = character(),
    owner_class = "ProjectNonTargetAnalysis",
    number_permitted = 1,
    developer = "Ricardo Cunha",
    contact = "cunha@iuta.de",
    link = "https://odea-project.github.io/StreamFind",
    doi = NA_character_,
    parameters = list(
      rtWindows = rt_windows,
      ppmThreshold = as.numeric(ppmThreshold),
      noiseThreshold = as.numeric(noiseThreshold),
      minSNR = as.numeric(minSNR),
      minTraces = as.integer(minTraces),
      baselineWindow = as.numeric(baselineWindow),
      maxWidth = as.numeric(maxWidth),
      baseQuantile = as.numeric(baseQuantile),
      debugAnalysis = as.character(debugAnalysis),
      debugMZ = as.numeric(debugMZ),
      debugSpecIdx = as.integer(debugSpecIdx)
    )
  )
  validate_object(x)
  x
}

#' @export
#' @noRd
validate_object.Method_NonTargetAnalysis_FindFeatures <- function(x, ...) {
  validate_object.Method(x)
  checkmate::assert_class(x, "Method_NonTargetAnalysis_FindFeatures")
  checkmate::assert_choice(x$method, "FindFeatures")
  checkmate::assert_choice(x$owner_class, "ProjectNonTargetAnalysis")
  rt_windows <- data.table::as.data.table(x$parameters$rtWindows)
  checkmate::assert_data_frame(rt_windows)
  checkmate::assert_true(all(c("rtmin", "rtmax") %in% names(rt_windows)))
  checkmate::assert_numeric(rt_windows$rtmin, any.missing = FALSE)
  checkmate::assert_numeric(rt_windows$rtmax, any.missing = FALSE)
  checkmate::assert_number(x$parameters$ppmThreshold, lower = 0, finite = TRUE)
  checkmate::assert_number(x$parameters$noiseThreshold, lower = 0, finite = TRUE)
  checkmate::assert_number(x$parameters$minSNR, lower = 0, finite = TRUE)
  checkmate::assert_integerish(x$parameters$minTraces, len = 1, lower = 1)
  checkmate::assert_number(x$parameters$baselineWindow, lower = 0, finite = TRUE)
  checkmate::assert_number(x$parameters$maxWidth, lower = 0, finite = TRUE)
  checkmate::assert_number(x$parameters$baseQuantile, lower = 0, upper = 1, finite = TRUE)
  checkmate::assert_character(x$parameters$debugAnalysis, len = 1, any.missing = FALSE)
  checkmate::assert_number(x$parameters$debugMZ, lower = 0, finite = TRUE)
  checkmate::assert_integerish(x$parameters$debugSpecIdx, len = 1, lower = -1)
  invisible(NULL)
}

#' @export
#' @noRd
run.Method_NonTargetAnalysis_FindFeatures <- function(x, proj, ...) {
  checkmate::assert_class(x, "Method_NonTargetAnalysis_FindFeatures")
  validate_object(x)
  checkmate::assert_class(proj, "ProjectNonTargetAnalysis")

  params <- x$parameters
  rt_windows <- data.table::as.data.table(params$rtWindows)
  success <- rcpp_nts_find_features(
    nts_xptr = proj$get_nts_ptr(),
    rtWindowsMin = as.numeric(rt_windows$rtmin),
    rtWindowsMax = as.numeric(rt_windows$rtmax),
    ppmThreshold = as.numeric(params$ppmThreshold),
    noiseThreshold = as.numeric(params$noiseThreshold),
    minSNR = as.numeric(params$minSNR),
    minTraces = as.integer(params$minTraces),
    baselineWindow = as.numeric(params$baselineWindow),
    maxWidth = as.numeric(params$maxWidth),
    baseQuantile = as.numeric(params$baseQuantile),
    debugAnalysis = as.character(params$debugAnalysis),
    debugMZ = as.numeric(params$debugMZ),
    debugSpecIdx = as.integer(params$debugSpecIdx)
  )

  if (!isTRUE(success)) {
    warning("Feature finding did not complete successfully.")
  }
  invisible(proj)
}
