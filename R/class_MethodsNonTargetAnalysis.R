#' @noRd
.nta_method_defaults <- function(required = character(), number_permitted = 1) {
  list(
    required = required,
    owner_class = "ProjectNonTargetAnalysis",
    number_permitted = number_permitted,
    developer = "Ricardo Cunha",
    contact = "cunha@iuta.de",
    link = "https://odea-project.github.io/StreamFind",
    doi = NA_character_
  )
}

#' @noRd
.validate_nta_method_base <- function(x, class_name, method, number_permitted = NULL) {
  validate_object.Method(x)
  checkmate::assert_class(x, class_name)
  checkmate::assert_choice(x$method, method)
  checkmate::assert_choice(x$owner_class, "ProjectNonTargetAnalysis")
  if (!is.null(number_permitted)) {
    checkmate::assert_true(identical(x$number_permitted, number_permitted))
  }
  invisible(NULL)
}

#' @noRd
.run_nta_method <- function(success, proj, warning_text) {
  if (!isTRUE(success)) {
    warning(warning_text)
  }
  invisible(proj)
}

#' @noRd
.empty_nta_suspects <- function() {
  data.table::data.table(
    name = character(),
    mass = numeric(),
    mz = numeric(),
    rt = numeric(),
    formula = character(),
    SMILES = character(),
    InChI = character(),
    InChIKey = character(),
    xLogP = numeric(),
    ms2_positive = character(),
    ms2_negative = character()
  )
}

#' @noRd
.empty_nta_transformation_products <- function() {
  data.table::data.table(
    name = character(),
    formula = character(),
    mass = numeric(),
    SMILES = character(),
    InChI = character(),
    InChIKey = character(),
    xLogP = numeric(),
    transformation = character(),
    precursor_name = character(),
    precursor_formula = character(),
    precursor_mass = numeric(),
    precursor_SMILES = character(),
    precursor_InChI = character(),
    precursor_InChIKey = character(),
    precursor_xLogP = numeric(),
    main_precursor_name = character(),
    main_precursor_formula = character(),
    main_precursor_mass = numeric(),
    main_precursor_SMILES = character(),
    main_precursor_InChI = character(),
    main_precursor_InChIKey = character(),
    main_precursor_xLogP = numeric()
  )
}

#' @title Method_NonTargetAnalysis_FindFeatures
#' @description Create a `Method` child object for the native non-target
#'   feature-finding routine.
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
#' @param debugAnalysis Character(1) analysis name for debug logging.
#' @param debugMZ Numeric(1) target m/z for debug logging.
#' @param debugSpecIdx Integer(1) spectrum index for debug logging.
#' @return A `Method` object of class `Method_NonTargetAnalysis_FindFeatures`.
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
  x <- do.call(
    Method,
    c(
      list(
        method = "FindFeatures",
        parameters = list(
          rtWindows = data.table::data.table(
            rtmin = as.numeric(rt_windows$rtmin),
            rtmax = as.numeric(rt_windows$rtmax)
          ),
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
      ),
      .nta_method_defaults(required = character(), number_permitted = 1)
    )
  )
  validate_object(x)
  x
}

#' @export
#' @noRd
validate_object.Method_NonTargetAnalysis_FindFeatures <- function(x, ...) {
  .validate_nta_method_base(x, "Method_NonTargetAnalysis_FindFeatures", "FindFeatures", 1)
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
  success <- rcpp_project_nta_find_features(
    nta_xptr = proj$get_nts_ptr(),
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
  .run_nta_method(success, proj, "Feature finding did not complete successfully.")
}

#' @title Method_NonTargetAnalysis_LoadFeaturesMS1
#' @description Create a `Method` child object for loading MS1 traces into NTA
#'   features.
#' @param filtered Logical(1) whether to include features already marked as
#'   filtered.
#' @param rtWindow Numeric length-2 vector of retention-time offsets in
#'   seconds.
#' @param mzWindow Numeric length-2 vector of m/z offsets in Da.
#' @param minTracesIntensity Numeric(1) minimum trace intensity to extract.
#' @param mzClust Numeric(1) m/z tolerance used when clustering traces.
#' @param presence Numeric(1) minimum fraction of scans required to keep a
#'   cluster.
#' @return A `Method` object of class `Method_NonTargetAnalysis_LoadFeaturesMS1`.
#' @export
Method_NonTargetAnalysis_LoadFeaturesMS1 <- function(
    filtered = FALSE,
    rtWindow = c(-2, 2),
    mzWindow = c(-1, 6),
    minTracesIntensity = 250,
    mzClust = 0.005,
    presence = 0.8) {
  x <- do.call(
    Method,
    c(
      list(
        method = "LoadFeaturesMS1",
        parameters = list(
          filtered = as.logical(filtered),
          rtWindow = as.numeric(rtWindow),
          mzWindow = as.numeric(mzWindow),
          minTracesIntensity = as.numeric(minTracesIntensity),
          mzClust = as.numeric(mzClust),
          presence = as.numeric(presence)
        )
      ),
      .nta_method_defaults(required = "FindFeatures", number_permitted = 1)
    )
  )
  validate_object(x)
  x
}

#' @export
#' @noRd
validate_object.Method_NonTargetAnalysis_LoadFeaturesMS1 <- function(x, ...) {
  .validate_nta_method_base(x, "Method_NonTargetAnalysis_LoadFeaturesMS1", "LoadFeaturesMS1", 1)
  checkmate::assert_logical(x$parameters$filtered, len = 1)
  checkmate::assert_numeric(x$parameters$rtWindow, len = 2, any.missing = FALSE)
  checkmate::assert_numeric(x$parameters$mzWindow, len = 2, any.missing = FALSE)
  checkmate::assert_number(x$parameters$minTracesIntensity, lower = 0, finite = TRUE)
  checkmate::assert_number(x$parameters$mzClust, lower = 0, finite = TRUE)
  checkmate::assert_number(x$parameters$presence, lower = 0, upper = 1, finite = TRUE)
  invisible(NULL)
}

#' @export
#' @noRd
run.Method_NonTargetAnalysis_LoadFeaturesMS1 <- function(x, proj, ...) {
  checkmate::assert_class(x, "Method_NonTargetAnalysis_LoadFeaturesMS1")
  validate_object(x)
  checkmate::assert_class(proj, "ProjectNonTargetAnalysis")
  params <- x$parameters
  success <- rcpp_project_nta_load_features_ms1(
    nta_xptr = proj$get_nts_ptr(),
    filtered = isTRUE(params$filtered),
    rtWindow = as.numeric(params$rtWindow),
    mzWindow = as.numeric(params$mzWindow),
    minTracesIntensity = as.numeric(params$minTracesIntensity),
    mzClust = as.numeric(params$mzClust),
    presence = as.numeric(params$presence)
  )
  .run_nta_method(success, proj, "Loading feature MS1 traces did not complete successfully.")
}

#' @title Method_NonTargetAnalysis_LoadFeaturesMS2
#' @description Create a `Method` child object for loading MS2 spectra into NTA
#'   features.
#' @param filtered Logical(1) whether to include features already marked as
#'   filtered.
#' @param minTracesIntensity Numeric(1) minimum trace intensity to extract.
#' @param isolationWindow Numeric(1) isolation window around precursor m/z.
#' @param mzClust Numeric(1) m/z tolerance used when clustering traces.
#' @param presence Numeric(1) minimum fraction of scans required to keep a
#'   cluster.
#' @return A `Method` object of class `Method_NonTargetAnalysis_LoadFeaturesMS2`.
#' @export
Method_NonTargetAnalysis_LoadFeaturesMS2 <- function(
    filtered = FALSE,
    minTracesIntensity = 10,
    isolationWindow = 1.3,
    mzClust = 0.005,
    presence = 0.8) {
  x <- do.call(
    Method,
    c(
      list(
        method = "LoadFeaturesMS2",
        parameters = list(
          filtered = as.logical(filtered),
          minTracesIntensity = as.numeric(minTracesIntensity),
          isolationWindow = as.numeric(isolationWindow),
          mzClust = as.numeric(mzClust),
          presence = as.numeric(presence)
        )
      ),
      .nta_method_defaults(required = "FindFeatures", number_permitted = 1)
    )
  )
  validate_object(x)
  x
}

#' @export
#' @noRd
validate_object.Method_NonTargetAnalysis_LoadFeaturesMS2 <- function(x, ...) {
  .validate_nta_method_base(x, "Method_NonTargetAnalysis_LoadFeaturesMS2", "LoadFeaturesMS2", 1)
  checkmate::assert_logical(x$parameters$filtered, len = 1)
  checkmate::assert_number(x$parameters$minTracesIntensity, lower = 0, finite = TRUE)
  checkmate::assert_number(x$parameters$isolationWindow, lower = 0, finite = TRUE)
  checkmate::assert_number(x$parameters$mzClust, lower = 0, finite = TRUE)
  checkmate::assert_number(x$parameters$presence, lower = 0, upper = 1, finite = TRUE)
  invisible(NULL)
}

#' @export
#' @noRd
run.Method_NonTargetAnalysis_LoadFeaturesMS2 <- function(x, proj, ...) {
  checkmate::assert_class(x, "Method_NonTargetAnalysis_LoadFeaturesMS2")
  validate_object(x)
  checkmate::assert_class(proj, "ProjectNonTargetAnalysis")
  params <- x$parameters
  success <- rcpp_project_nta_load_features_ms2(
    nta_xptr = proj$get_nts_ptr(),
    filtered = isTRUE(params$filtered),
    minTracesIntensity = as.numeric(params$minTracesIntensity),
    isolationWindow = as.numeric(params$isolationWindow),
    mzClust = as.numeric(params$mzClust),
    presence = as.numeric(params$presence)
  )
  .run_nta_method(success, proj, "Loading feature MS2 spectra did not complete successfully.")
}

#' @title Method_NonTargetAnalysis_CreateComponents
#' @description Create a `Method` child object for clustering features into
#'   components.
#' @param rtWindow Numeric length-2 vector of retention-time offsets in
#'   seconds.
#' @param minCorrelation Numeric(1) minimum Pearson correlation to keep
#'   features in one component.
#' @param debugRT Numeric(1) retention time in seconds to debug.
#' @param debugAnalysis Character(1) analysis name to debug.
#' @return A `Method` object of class `Method_NonTargetAnalysis_CreateComponents`.
#' @export
Method_NonTargetAnalysis_CreateComponents <- function(
    rtWindow = c(0, 0),
    minCorrelation = 0.8,
    debugRT = 0,
    debugAnalysis = "") {
  x <- do.call(
    Method,
    c(
      list(
        method = "CreateComponents",
        parameters = list(
          rtWindow = as.numeric(rtWindow),
          minCorrelation = as.numeric(minCorrelation),
          debugRT = as.numeric(debugRT),
          debugAnalysis = as.character(debugAnalysis)
        )
      ),
      .nta_method_defaults(required = "FindFeatures", number_permitted = 1)
    )
  )
  validate_object(x)
  x
}

#' @export
#' @noRd
validate_object.Method_NonTargetAnalysis_CreateComponents <- function(x, ...) {
  .validate_nta_method_base(x, "Method_NonTargetAnalysis_CreateComponents", "CreateComponents", 1)
  checkmate::assert_numeric(x$parameters$rtWindow, len = 2, any.missing = FALSE)
  checkmate::assert_number(x$parameters$minCorrelation, lower = 0, upper = 1, finite = TRUE)
  checkmate::assert_number(x$parameters$debugRT, lower = 0, finite = TRUE)
  checkmate::assert_string(x$parameters$debugAnalysis)
  invisible(NULL)
}

#' @export
#' @noRd
run.Method_NonTargetAnalysis_CreateComponents <- function(x, proj, ...) {
  checkmate::assert_class(x, "Method_NonTargetAnalysis_CreateComponents")
  validate_object(x)
  checkmate::assert_class(proj, "ProjectNonTargetAnalysis")
  params <- x$parameters
  success <- rcpp_project_nta_create_components(
    nta_xptr = proj$get_nts_ptr(),
    rtWindow = as.numeric(params$rtWindow),
    minCorrelation = as.numeric(params$minCorrelation),
    debugRT = as.numeric(params$debugRT),
    debugAnalysis = as.character(params$debugAnalysis)
  )
  .run_nta_method(success, proj, "Creating feature components did not complete successfully.")
}

#' @title Method_NonTargetAnalysis_AnnotateComponents
#' @description Create a `Method` child object for annotating isotopes,
#'   adducts, and in-source fragments within components.
#' @param maxIsotopes Integer(1) maximum number of isotopes to consider.
#' @param maxCharge Integer(1) maximum charge state to consider.
#' @param maxGaps Integer(1) maximum number of gaps allowed in isotope
#'   patterns.
#' @param ppm Numeric(1) minimum m/z tolerance in ppm.
#' @param debugComponent Character(1) component identifier to debug.
#' @param debugAnalysis Character(1) analysis name to debug.
#' @return A `Method` object of class `Method_NonTargetAnalysis_AnnotateComponents`.
#' @export
Method_NonTargetAnalysis_AnnotateComponents <- function(
    maxIsotopes = 5L,
    maxCharge = 1L,
    maxGaps = 1L,
    ppm = 10,
    debugComponent = "",
    debugAnalysis = "") {
  x <- do.call(
    Method,
    c(
      list(
        method = "AnnotateComponents",
        parameters = list(
          maxIsotopes = as.integer(maxIsotopes),
          maxCharge = as.integer(maxCharge),
          maxGaps = as.integer(maxGaps),
          ppm = as.numeric(ppm),
          debugComponent = as.character(debugComponent),
          debugAnalysis = as.character(debugAnalysis)
        )
      ),
      .nta_method_defaults(required = "CreateComponents", number_permitted = 1)
    )
  )
  validate_object(x)
  x
}

#' @export
#' @noRd
validate_object.Method_NonTargetAnalysis_AnnotateComponents <- function(x, ...) {
  .validate_nta_method_base(x, "Method_NonTargetAnalysis_AnnotateComponents", "AnnotateComponents", 1)
  checkmate::assert_integerish(x$parameters$maxIsotopes, len = 1, lower = 1)
  checkmate::assert_integerish(x$parameters$maxCharge, len = 1, lower = 1)
  checkmate::assert_integerish(x$parameters$maxGaps, len = 1, lower = 0)
  checkmate::assert_number(x$parameters$ppm, lower = 0, finite = TRUE)
  checkmate::assert_string(x$parameters$debugComponent)
  checkmate::assert_string(x$parameters$debugAnalysis)
  invisible(NULL)
}

#' @export
#' @noRd
run.Method_NonTargetAnalysis_AnnotateComponents <- function(x, proj, ...) {
  checkmate::assert_class(x, "Method_NonTargetAnalysis_AnnotateComponents")
  validate_object(x)
  checkmate::assert_class(proj, "ProjectNonTargetAnalysis")
  params <- x$parameters
  success <- rcpp_project_nta_annotate_components(
    nta_xptr = proj$get_nts_ptr(),
    maxIsotopes = as.integer(params$maxIsotopes),
    maxCharge = as.integer(params$maxCharge),
    maxGaps = as.integer(params$maxGaps),
    ppm = as.numeric(params$ppm),
    debugComponent = as.character(params$debugComponent),
    debugAnalysis = as.character(params$debugAnalysis)
  )
  .run_nta_method(success, proj, "Annotating feature components did not complete successfully.")
}

#' @title Method_NonTargetAnalysis_GroupFeatures
#' @description Create a `Method` child object for grouping aligned features
#'   across analyses.
#' @param method Character(1) alignment method, usually `"internal_standards"`
#'   or `"obi_warp"`.
#' @param rtDeviation Numeric(1) retention-time tolerance in seconds.
#' @param ppm Numeric(1) mass tolerance in ppm.
#' @param minSamples Integer(1) minimum number of samples a feature must appear
#'   in.
#' @param binSize Numeric(1) RT bin size in seconds.
#' @param debug Logical(1) whether to create a debug log.
#' @param debugRT Numeric(1) RT value to focus debugging on.
#' @return A `Method` object of class `Method_NonTargetAnalysis_GroupFeatures`.
#' @export
Method_NonTargetAnalysis_GroupFeatures <- function(
    method = "internal_standards",
    rtDeviation = 5,
    ppm = 10,
    minSamples = 1L,
    binSize = 5,
    debug = FALSE,
    debugRT = 0) {
  x <- do.call(
    Method,
    c(
      list(
        method = "GroupFeatures",
        parameters = list(
          method = as.character(method),
          rtDeviation = as.numeric(rtDeviation),
          ppm = as.numeric(ppm),
          minSamples = as.integer(minSamples),
          binSize = as.numeric(binSize),
          debug = as.logical(debug),
          debugRT = as.numeric(debugRT)
        )
      ),
      .nta_method_defaults(required = "FindFeatures", number_permitted = 1)
    )
  )
  validate_object(x)
  x
}

#' @export
#' @noRd
validate_object.Method_NonTargetAnalysis_GroupFeatures <- function(x, ...) {
  .validate_nta_method_base(x, "Method_NonTargetAnalysis_GroupFeatures", "GroupFeatures", 1)
  checkmate::assert_choice(x$parameters$method, c("internal_standards", "obi_warp"))
  checkmate::assert_number(x$parameters$rtDeviation, lower = 0, finite = TRUE)
  checkmate::assert_number(x$parameters$ppm, lower = 0, finite = TRUE)
  checkmate::assert_integerish(x$parameters$minSamples, len = 1, lower = 1)
  checkmate::assert_number(x$parameters$binSize, lower = 0, finite = TRUE)
  checkmate::assert_logical(x$parameters$debug, len = 1)
  checkmate::assert_number(x$parameters$debugRT, lower = 0, finite = TRUE)
  invisible(NULL)
}

#' @export
#' @noRd
run.Method_NonTargetAnalysis_GroupFeatures <- function(x, proj, ...) {
  checkmate::assert_class(x, "Method_NonTargetAnalysis_GroupFeatures")
  validate_object(x)
  checkmate::assert_class(proj, "ProjectNonTargetAnalysis")
  params <- x$parameters
  success <- rcpp_project_nta_group_features(
    nta_xptr = proj$get_nts_ptr(),
    method = as.character(params$method),
    rtDeviation = as.numeric(params$rtDeviation),
    ppm = as.numeric(params$ppm),
    minSamples = as.integer(params$minSamples),
    binSize = as.numeric(params$binSize),
    debug = isTRUE(params$debug),
    debugRT = as.numeric(params$debugRT)
  )
  .run_nta_method(success, proj, "Grouping features did not complete successfully.")
}

#' @title Method_NonTargetAnalysis_FillFeatures
#' @description Create a `Method` child object for filling missing features
#'   across analyses.
#' @param withinReplicate Logical(1) whether to fill features only within
#'   replicates.
#' @param filtered Logical(1) whether to consider filtered features.
#' @param rtExpand Numeric(1) retention-time expansion window in seconds.
#' @param mzExpand Numeric(1) m/z expansion window in Da.
#' @param maxPeakWidth Numeric(1) maximum peak width in seconds.
#' @param minTracesIntensity Numeric(1) minimum trace intensity for EIC
#'   extraction.
#' @param minNumberTraces Integer(1) minimum number of traces required.
#' @param minIntensity Numeric(1) minimum peak intensity.
#' @param rtApexDeviation Numeric(1) maximum RT deviation from target apex in
#'   seconds.
#' @param minSignalToNoiseRatio Numeric(1) minimum signal-to-noise ratio.
#' @param minGaussianFit Numeric(1) minimum Gaussian fit R-squared.
#' @param debugFG Character(1) feature-group identifier to debug.
#' @return A `Method` object of class `Method_NonTargetAnalysis_FillFeatures`.
#' @export
Method_NonTargetAnalysis_FillFeatures <- function(
    withinReplicate = FALSE,
    filtered = FALSE,
    rtExpand = 10,
    mzExpand = 0.01,
    maxPeakWidth = 30,
    minTracesIntensity = 1000,
    minNumberTraces = 5L,
    minIntensity = 5000,
    rtApexDeviation = 5,
    minSignalToNoiseRatio = 3,
    minGaussianFit = 0.2,
    debugFG = "") {
  x <- do.call(
    Method,
    c(
      list(
        method = "FillFeatures",
        parameters = list(
          withinReplicate = as.logical(withinReplicate),
          filtered = as.logical(filtered),
          rtExpand = as.numeric(rtExpand),
          mzExpand = as.numeric(mzExpand),
          maxPeakWidth = as.numeric(maxPeakWidth),
          minTracesIntensity = as.numeric(minTracesIntensity),
          minNumberTraces = as.integer(minNumberTraces),
          minIntensity = as.numeric(minIntensity),
          rtApexDeviation = as.numeric(rtApexDeviation),
          minSignalToNoiseRatio = as.numeric(minSignalToNoiseRatio),
          minGaussianFit = as.numeric(minGaussianFit),
          debugFG = as.character(debugFG)
        )
      ),
      .nta_method_defaults(required = c("FindFeatures", "GroupFeatures"), number_permitted = 1)
    )
  )
  validate_object(x)
  x
}

#' @export
#' @noRd
validate_object.Method_NonTargetAnalysis_FillFeatures <- function(x, ...) {
  .validate_nta_method_base(x, "Method_NonTargetAnalysis_FillFeatures", "FillFeatures", 1)
  checkmate::assert_logical(x$parameters$withinReplicate, len = 1)
  checkmate::assert_logical(x$parameters$filtered, len = 1)
  checkmate::assert_number(x$parameters$rtExpand, lower = 0, finite = TRUE)
  checkmate::assert_number(x$parameters$mzExpand, lower = 0, finite = TRUE)
  checkmate::assert_number(x$parameters$maxPeakWidth, lower = 0, finite = TRUE)
  checkmate::assert_number(x$parameters$minTracesIntensity, lower = 0, finite = TRUE)
  checkmate::assert_integerish(x$parameters$minNumberTraces, len = 1, lower = 1)
  checkmate::assert_number(x$parameters$minIntensity, lower = 0, finite = TRUE)
  checkmate::assert_number(x$parameters$rtApexDeviation, lower = 0, finite = TRUE)
  checkmate::assert_number(x$parameters$minSignalToNoiseRatio, lower = 0, finite = TRUE)
  checkmate::assert_number(x$parameters$minGaussianFit, lower = 0, upper = 1, finite = TRUE)
  checkmate::assert_string(x$parameters$debugFG)
  invisible(NULL)
}

#' @export
#' @noRd
run.Method_NonTargetAnalysis_FillFeatures <- function(x, proj, ...) {
  checkmate::assert_class(x, "Method_NonTargetAnalysis_FillFeatures")
  validate_object(x)
  checkmate::assert_class(proj, "ProjectNonTargetAnalysis")
  params <- x$parameters
  success <- rcpp_project_nta_fill_features(
    nta_xptr = proj$get_nts_ptr(),
    withinReplicate = isTRUE(params$withinReplicate),
    filtered = isTRUE(params$filtered),
    rtExpand = as.numeric(params$rtExpand),
    mzExpand = as.numeric(params$mzExpand),
    maxPeakWidth = as.numeric(params$maxPeakWidth),
    minTracesIntensity = as.numeric(params$minTracesIntensity),
    minNumberTraces = as.integer(params$minNumberTraces),
    minIntensity = as.numeric(params$minIntensity),
    rtApexDeviation = as.numeric(params$rtApexDeviation),
    minSignalToNoiseRatio = as.numeric(params$minSignalToNoiseRatio),
    minGaussianFit = as.numeric(params$minGaussianFit),
    debugFG = as.character(params$debugFG)
  )
  .run_nta_method(success, proj, "Filling features did not complete successfully.")
}

#' @title Method_NonTargetAnalysis_BlankSubtraction
#' @description Create a `Method` child object for subtracting blank-derived
#'   features.
#' @param blankThreshold Numeric(1) threshold multiplier for blank feature
#'   intensities.
#' @param rtExpand Numeric(1) retention-time expansion window in seconds.
#' @param mzExpand Numeric(1) m/z expansion window in Da.
#' @return A `Method` object of class `Method_NonTargetAnalysis_BlankSubtraction`.
#' @export
Method_NonTargetAnalysis_BlankSubtraction <- function(
    blankThreshold = 5,
    rtExpand = 10,
    mzExpand = 0.005) {
  x <- do.call(
    Method,
    c(
      list(
        method = "BlankSubtraction",
        parameters = list(
          blankThreshold = as.numeric(blankThreshold),
          rtExpand = as.numeric(rtExpand),
          mzExpand = as.numeric(mzExpand)
        )
      ),
      .nta_method_defaults(required = "FindFeatures", number_permitted = 1)
    )
  )
  validate_object(x)
  x
}

#' @export
#' @noRd
validate_object.Method_NonTargetAnalysis_BlankSubtraction <- function(x, ...) {
  .validate_nta_method_base(x, "Method_NonTargetAnalysis_BlankSubtraction", "BlankSubtraction", 1)
  checkmate::assert_number(x$parameters$blankThreshold, lower = 0, finite = TRUE)
  checkmate::assert_number(x$parameters$rtExpand, lower = 0, finite = TRUE)
  checkmate::assert_number(x$parameters$mzExpand, lower = 0, finite = TRUE)
  invisible(NULL)
}

#' @export
#' @noRd
run.Method_NonTargetAnalysis_BlankSubtraction <- function(x, proj, ...) {
  checkmate::assert_class(x, "Method_NonTargetAnalysis_BlankSubtraction")
  validate_object(x)
  checkmate::assert_class(proj, "ProjectNonTargetAnalysis")
  params <- x$parameters
  success <- rcpp_project_nta_blank_subtraction(
    nta_xptr = proj$get_nts_ptr(),
    blankThreshold = as.numeric(params$blankThreshold),
    rtExpand = as.numeric(params$rtExpand),
    mzExpand = as.numeric(params$mzExpand)
  )
  .run_nta_method(success, proj, "Blank subtraction did not complete successfully.")
}

#' @title Method_NonTargetAnalysis_FilterFeatures
#' @description Create a `Method` child object for filtering features by
#'   quality criteria.
#' @param minSN,minIntensity,minArea,minWidth,maxWidth,maxPPM,minFwhmRT,maxFwhmRT,minFwhmMZ,maxFwhmMZ,minGaussianA,minGaussianMu,maxGaussianMu,minGaussianSigma,maxGaussianSigma,minGaussianR2,maxJaggedness,minSharpness,minAsymmetry,maxAsymmetry,minPlates,minRelPresenceReplicate
#'   Optional numeric scalar thresholds. Use `NA_real_` to disable a threshold.
#' @param maxModality Optional integer scalar for the maximum number of local
#'   maxima. Use `NA_integer_` to disable.
#' @param onlyFilled Optional logical scalar. Use `TRUE` to keep only filled
#'   features, `FALSE` to keep only non-filled, or `NA` to disable.
#' @param removeFilled,removeIsotopes,removeAdducts,removeLosses Logical scalar
#'   flags controlling feature removal.
#' @param minSizeEIC,minSizeMS1,minSizeMS2 Optional integer scalar minimum data
#'   point counts. Use `NA_integer_` to disable.
#' @return A `Method` object of class `Method_NonTargetAnalysis_FilterFeatures`.
#' @export
Method_NonTargetAnalysis_FilterFeatures <- function(
    minSN = NA_real_,
    minIntensity = NA_real_,
    minArea = NA_real_,
    minWidth = NA_real_,
    maxWidth = NA_real_,
    maxPPM = NA_real_,
    minFwhmRT = NA_real_,
    maxFwhmRT = NA_real_,
    minFwhmMZ = NA_real_,
    maxFwhmMZ = NA_real_,
    minGaussianA = NA_real_,
    minGaussianMu = NA_real_,
    maxGaussianMu = NA_real_,
    minGaussianSigma = NA_real_,
    maxGaussianSigma = NA_real_,
    minGaussianR2 = NA_real_,
    maxJaggedness = NA_real_,
    minSharpness = NA_real_,
    minAsymmetry = NA_real_,
    maxAsymmetry = NA_real_,
    maxModality = NA_integer_,
    minPlates = NA_real_,
    onlyFilled = NA,
    removeFilled = FALSE,
    minSizeEIC = NA_integer_,
    minSizeMS1 = NA_integer_,
    minSizeMS2 = NA_integer_,
    minRelPresenceReplicate = NA_real_,
    removeIsotopes = FALSE,
    removeAdducts = FALSE,
    removeLosses = FALSE) {
  x <- do.call(
    Method,
    c(
      list(
        method = "FilterFeatures",
        parameters = list(
          minSN = as.numeric(minSN),
          minIntensity = as.numeric(minIntensity),
          minArea = as.numeric(minArea),
          minWidth = as.numeric(minWidth),
          maxWidth = as.numeric(maxWidth),
          maxPPM = as.numeric(maxPPM),
          minFwhmRT = as.numeric(minFwhmRT),
          maxFwhmRT = as.numeric(maxFwhmRT),
          minFwhmMZ = as.numeric(minFwhmMZ),
          maxFwhmMZ = as.numeric(maxFwhmMZ),
          minGaussianA = as.numeric(minGaussianA),
          minGaussianMu = as.numeric(minGaussianMu),
          maxGaussianMu = as.numeric(maxGaussianMu),
          minGaussianSigma = as.numeric(minGaussianSigma),
          maxGaussianSigma = as.numeric(maxGaussianSigma),
          minGaussianR2 = as.numeric(minGaussianR2),
          maxJaggedness = as.numeric(maxJaggedness),
          minSharpness = as.numeric(minSharpness),
          minAsymmetry = as.numeric(minAsymmetry),
          maxAsymmetry = as.numeric(maxAsymmetry),
          maxModality = as.integer(maxModality),
          minPlates = as.numeric(minPlates),
          onlyFilled = as.logical(onlyFilled),
          removeFilled = as.logical(removeFilled),
          minSizeEIC = as.integer(minSizeEIC),
          minSizeMS1 = as.integer(minSizeMS1),
          minSizeMS2 = as.integer(minSizeMS2),
          minRelPresenceReplicate = as.numeric(minRelPresenceReplicate),
          removeIsotopes = as.logical(removeIsotopes),
          removeAdducts = as.logical(removeAdducts),
          removeLosses = as.logical(removeLosses)
        )
      ),
      .nta_method_defaults(required = "FindFeatures", number_permitted = Inf)
    )
  )
  validate_object(x)
  x
}

#' @export
#' @noRd
validate_object.Method_NonTargetAnalysis_FilterFeatures <- function(x, ...) {
  .validate_nta_method_base(x, "Method_NonTargetAnalysis_FilterFeatures", "FilterFeatures", Inf)
  numeric_names <- c(
    "minSN", "minIntensity", "minArea", "minWidth", "maxWidth", "maxPPM",
    "minFwhmRT", "maxFwhmRT", "minFwhmMZ", "maxFwhmMZ", "minGaussianA",
    "minGaussianMu", "maxGaussianMu", "minGaussianSigma", "maxGaussianSigma",
    "minGaussianR2", "maxJaggedness", "minSharpness", "minAsymmetry",
    "maxAsymmetry", "minPlates", "minRelPresenceReplicate"
  )
  for (nm in numeric_names) {
    checkmate::assert_numeric(x$parameters[[nm]], len = 1)
  }
  checkmate::assert_integerish(x$parameters$maxModality, len = 1, any.missing = TRUE)
  checkmate::assert_logical(x$parameters$onlyFilled, len = 1, any.missing = TRUE)
  checkmate::assert_logical(x$parameters$removeFilled, len = 1)
  checkmate::assert_integerish(x$parameters$minSizeEIC, len = 1, any.missing = TRUE)
  checkmate::assert_integerish(x$parameters$minSizeMS1, len = 1, any.missing = TRUE)
  checkmate::assert_integerish(x$parameters$minSizeMS2, len = 1, any.missing = TRUE)
  checkmate::assert_logical(x$parameters$removeIsotopes, len = 1)
  checkmate::assert_logical(x$parameters$removeAdducts, len = 1)
  checkmate::assert_logical(x$parameters$removeLosses, len = 1)
  invisible(NULL)
}

#' @export
#' @noRd
run.Method_NonTargetAnalysis_FilterFeatures <- function(x, proj, ...) {
  checkmate::assert_class(x, "Method_NonTargetAnalysis_FilterFeatures")
  validate_object(x)
  checkmate::assert_class(proj, "ProjectNonTargetAnalysis")
  p <- x$parameters
  success <- rcpp_project_nta_filter_features(
    nta_xptr = proj$get_nts_ptr(),
    minSN = p$minSN,
    minIntensity = p$minIntensity,
    minArea = p$minArea,
    minWidth = p$minWidth,
    maxWidth = p$maxWidth,
    maxPPM = p$maxPPM,
    minFwhmRT = p$minFwhmRT,
    maxFwhmRT = p$maxFwhmRT,
    minFwhmMZ = p$minFwhmMZ,
    maxFwhmMZ = p$maxFwhmMZ,
    minGaussianA = p$minGaussianA,
    minGaussianMu = p$minGaussianMu,
    maxGaussianMu = p$maxGaussianMu,
    minGaussianSigma = p$minGaussianSigma,
    maxGaussianSigma = p$maxGaussianSigma,
    minGaussianR2 = p$minGaussianR2,
    maxJaggedness = p$maxJaggedness,
    minSharpness = p$minSharpness,
    minAsymmetry = p$minAsymmetry,
    maxAsymmetry = p$maxAsymmetry,
    maxModality = p$maxModality,
    minPlates = p$minPlates,
    onlyFilled = p$onlyFilled,
    removeFilled = isTRUE(p$removeFilled),
    minSizeEIC = p$minSizeEIC,
    minSizeMS1 = p$minSizeMS1,
    minSizeMS2 = p$minSizeMS2,
    minRelPresenceReplicate = p$minRelPresenceReplicate,
    removeIsotopes = isTRUE(p$removeIsotopes),
    removeAdducts = isTRUE(p$removeAdducts),
    removeLosses = isTRUE(p$removeLosses)
  )
  .run_nta_method(success, proj, "Filtering features did not complete successfully.")
}

#' @title Method_NonTargetAnalysis_SuspectScreening
#' @description Create a `Method` child object for suspect screening against a
#'   provided suspect table.
#' @param suspects A data.frame/data.table with suspect information.
#' @param analyses Optional character vector restricting screening to selected
#'   analyses.
#' @param ppm,sec,ppmMS2,mzrMS2,minCosineSimilarity Numeric scalar thresholds
#'   used during matching.
#' @param minSharedFragments Integer(1) minimum number of shared MS2 fragments.
#' @param filtered Logical(1) whether to include filtered features in the
#'   search.
#' @return A `Method` object of class `Method_NonTargetAnalysis_SuspectScreening`.
#' @export
Method_NonTargetAnalysis_SuspectScreening <- function(
    suspects = NULL,
    analyses = character(),
    ppm = 5,
    sec = 10,
    ppmMS2 = 10,
    mzrMS2 = 0.008,
    minCosineSimilarity = 0.7,
    minSharedFragments = 3L,
    filtered = TRUE) {
  suspects_dt <- if (is.null(suspects)) .empty_nta_suspects() else data.table::as.data.table(suspects)
  x <- do.call(
    Method,
    c(
      list(
        method = "SuspectScreening",
        parameters = list(
          suspects = suspects_dt,
          analyses = as.character(analyses),
          ppm = as.numeric(ppm),
          sec = as.numeric(sec),
          ppmMS2 = as.numeric(ppmMS2),
          mzrMS2 = as.numeric(mzrMS2),
          minCosineSimilarity = as.numeric(minCosineSimilarity),
          minSharedFragments = as.integer(minSharedFragments),
          filtered = as.logical(filtered)
        )
      ),
      .nta_method_defaults(required = "FindFeatures", number_permitted = Inf)
    )
  )
  validate_object(x)
  x
}

#' @export
#' @noRd
validate_object.Method_NonTargetAnalysis_SuspectScreening <- function(x, ...) {
  .validate_nta_method_base(x, "Method_NonTargetAnalysis_SuspectScreening", "SuspectScreening", Inf)
  suspects <- data.table::as.data.table(x$parameters$suspects)
  checkmate::assert_data_frame(suspects)
  checkmate::assert_true("name" %in% names(suspects))
  checkmate::assert_true(any(c("mass", "mz") %in% names(suspects)) || nrow(suspects) == 0L)
  checkmate::assert_character(x$parameters$analyses, any.missing = FALSE)
  checkmate::assert_number(x$parameters$ppm, lower = 0, finite = TRUE)
  checkmate::assert_number(x$parameters$sec, lower = 0, finite = TRUE)
  checkmate::assert_number(x$parameters$ppmMS2, lower = 0, finite = TRUE)
  checkmate::assert_number(x$parameters$mzrMS2, lower = 0, finite = TRUE)
  checkmate::assert_number(x$parameters$minCosineSimilarity, lower = 0, upper = 1, finite = TRUE)
  checkmate::assert_integerish(x$parameters$minSharedFragments, len = 1, lower = 0)
  checkmate::assert_logical(x$parameters$filtered, len = 1)
  invisible(NULL)
}

#' @export
#' @noRd
run.Method_NonTargetAnalysis_SuspectScreening <- function(x, proj, ...) {
  checkmate::assert_class(x, "Method_NonTargetAnalysis_SuspectScreening")
  validate_object(x)
  checkmate::assert_class(proj, "ProjectNonTargetAnalysis")
  p <- x$parameters
  success <- rcpp_project_nta_suspect_screening(
    nta_xptr = proj$get_nts_ptr(),
    suspects = as.data.frame(data.table::as.data.table(p$suspects)),
    analyses = as.character(p$analyses),
    ppm = as.numeric(p$ppm),
    sec = as.numeric(p$sec),
    ppmMS2 = as.numeric(p$ppmMS2),
    mzrMS2 = as.numeric(p$mzrMS2),
    minCosineSimilarity = as.numeric(p$minCosineSimilarity),
    minSharedFragments = as.integer(p$minSharedFragments),
    filtered = isTRUE(p$filtered)
  )
  .run_nta_method(success, proj, "Suspect screening did not complete successfully.")
}

#' @title Method_NonTargetAnalysis_FilterSuspects
#' @description Create a `Method` child object for filtering suspect hits.
#' @param names Optional character vector of suspect names to match.
#' @param minScore,maxErrorRT,maxErrorMass,minCosineSimilarity Optional numeric
#'   scalar thresholds. Use `NA_real_` to disable a threshold.
#' @param idLevels Optional integer vector of identification levels to keep.
#' @param minSharedFragments Integer(1) minimum number of shared fragments.
#' @return A `Method` object of class `Method_NonTargetAnalysis_FilterSuspects`.
#' @export
Method_NonTargetAnalysis_FilterSuspects <- function(
    names = character(),
    minScore = NA_real_,
    maxErrorRT = NA_real_,
    maxErrorMass = NA_real_,
    idLevels = integer(),
    minSharedFragments = 0L,
    minCosineSimilarity = NA_real_) {
  x <- do.call(
    Method,
    c(
      list(
        method = "FilterSuspects",
        parameters = list(
          names = as.character(names),
          minScore = as.numeric(minScore),
          maxErrorRT = as.numeric(maxErrorRT),
          maxErrorMass = as.numeric(maxErrorMass),
          idLevels = as.integer(idLevels),
          minSharedFragments = as.integer(minSharedFragments),
          minCosineSimilarity = as.numeric(minCosineSimilarity)
        )
      ),
      .nta_method_defaults(required = character(), number_permitted = Inf)
    )
  )
  validate_object(x)
  x
}

#' @export
#' @noRd
validate_object.Method_NonTargetAnalysis_FilterSuspects <- function(x, ...) {
  .validate_nta_method_base(x, "Method_NonTargetAnalysis_FilterSuspects", "FilterSuspects", Inf)
  checkmate::assert_character(x$parameters$names, any.missing = FALSE)
  checkmate::assert_numeric(x$parameters$minScore, len = 1)
  checkmate::assert_numeric(x$parameters$maxErrorRT, len = 1)
  checkmate::assert_numeric(x$parameters$maxErrorMass, len = 1)
  checkmate::assert_integerish(x$parameters$idLevels, any.missing = FALSE)
  checkmate::assert_integerish(x$parameters$minSharedFragments, len = 1, lower = 0)
  checkmate::assert_numeric(x$parameters$minCosineSimilarity, len = 1)
  invisible(NULL)
}

#' @export
#' @noRd
run.Method_NonTargetAnalysis_FilterSuspects <- function(x, proj, ...) {
  checkmate::assert_class(x, "Method_NonTargetAnalysis_FilterSuspects")
  validate_object(x)
  checkmate::assert_class(proj, "ProjectNonTargetAnalysis")
  p <- x$parameters
  success <- rcpp_project_nta_filter_suspects(
    nta_xptr = proj$get_nts_ptr(),
    names = as.character(p$names),
    minScore = p$minScore,
    maxErrorRT = p$maxErrorRT,
    maxErrorMass = p$maxErrorMass,
    idLevels = as.integer(p$idLevels),
    minSharedFragments = as.integer(p$minSharedFragments),
    minCosineSimilarity = p$minCosineSimilarity
  )
  .run_nta_method(success, proj, "Filtering suspects did not complete successfully.")
}

#' @title Method_NonTargetAnalysis_FilterInternalStandards
#' @description Create a `Method` child object for filtering internal-standard
#'   hits.
#' @param names Optional character vector of internal-standard names to match.
#' @param minScore,maxErrorRT,maxErrorMass,minCosineSimilarity Optional numeric
#'   scalar thresholds. Use `NA_real_` to disable a threshold.
#' @param idLevels Optional integer vector of identification levels to keep.
#' @param minSharedFragments Integer(1) minimum number of shared fragments.
#' @return A `Method` object of class
#'   `Method_NonTargetAnalysis_FilterInternalStandards`.
#' @export
Method_NonTargetAnalysis_FilterInternalStandards <- function(
    names = character(),
    minScore = NA_real_,
    maxErrorRT = NA_real_,
    maxErrorMass = NA_real_,
    idLevels = integer(),
    minSharedFragments = 0L,
    minCosineSimilarity = NA_real_) {
  x <- do.call(
    Method,
    c(
      list(
        method = "FilterInternalStandards",
        parameters = list(
          names = as.character(names),
          minScore = as.numeric(minScore),
          maxErrorRT = as.numeric(maxErrorRT),
          maxErrorMass = as.numeric(maxErrorMass),
          idLevels = as.integer(idLevels),
          minSharedFragments = as.integer(minSharedFragments),
          minCosineSimilarity = as.numeric(minCosineSimilarity)
        )
      ),
      .nta_method_defaults(required = character(), number_permitted = Inf)
    )
  )
  validate_object(x)
  x
}

#' @export
#' @noRd
validate_object.Method_NonTargetAnalysis_FilterInternalStandards <- function(x, ...) {
  .validate_nta_method_base(x, "Method_NonTargetAnalysis_FilterInternalStandards", "FilterInternalStandards", Inf)
  checkmate::assert_character(x$parameters$names, any.missing = FALSE)
  checkmate::assert_numeric(x$parameters$minScore, len = 1)
  checkmate::assert_numeric(x$parameters$maxErrorRT, len = 1)
  checkmate::assert_numeric(x$parameters$maxErrorMass, len = 1)
  checkmate::assert_integerish(x$parameters$idLevels, any.missing = FALSE)
  checkmate::assert_integerish(x$parameters$minSharedFragments, len = 1, lower = 0)
  checkmate::assert_numeric(x$parameters$minCosineSimilarity, len = 1)
  invisible(NULL)
}

#' @export
#' @noRd
run.Method_NonTargetAnalysis_FilterInternalStandards <- function(x, proj, ...) {
  checkmate::assert_class(x, "Method_NonTargetAnalysis_FilterInternalStandards")
  validate_object(x)
  checkmate::assert_class(proj, "ProjectNonTargetAnalysis")
  p <- x$parameters
  success <- rcpp_project_nta_filter_internal_standards(
    nta_xptr = proj$get_nts_ptr(),
    names = as.character(p$names),
    minScore = p$minScore,
    maxErrorRT = p$maxErrorRT,
    maxErrorMass = p$maxErrorMass,
    idLevels = as.integer(p$idLevels),
    minSharedFragments = as.integer(p$minSharedFragments),
    minCosineSimilarity = p$minCosineSimilarity
  )
  .run_nta_method(success, proj, "Filtering internal standards did not complete successfully.")
}

#' @title Method_NonTargetAnalysis_FilterFeaturesMS2
#' @description Create a `Method` child object for filtering MS2 traces loaded
#'   onto features.
#' @param top Integer(1) number of top MS2 spectra to keep per feature. Use `0`
#'   to disable.
#' @param minIntensity,relMinIntensity Optional numeric scalar thresholds. Use
#'   `NA_real_` to disable.
#' @param blankClean Logical(1) whether to remove fragments prevalent in
#'   blanks.
#' @param mzClust Numeric(1) m/z clustering tolerance.
#' @param blankPresenceThreshold Numeric(1) blank presence threshold.
#' @param globalPresenceThreshold Numeric(1) global presence threshold.
#' @return A `Method` object of class `Method_NonTargetAnalysis_FilterFeaturesMS2`.
#' @export
Method_NonTargetAnalysis_FilterFeaturesMS2 <- function(
    top = 0L,
    minIntensity = NA_real_,
    relMinIntensity = NA_real_,
    blankClean = FALSE,
    mzClust = 0.005,
    blankPresenceThreshold = 0.8,
    globalPresenceThreshold = 0.1) {
  x <- do.call(
    Method,
    c(
      list(
        method = "FilterFeaturesMS2",
        parameters = list(
          top = as.integer(top),
          minIntensity = as.numeric(minIntensity),
          relMinIntensity = as.numeric(relMinIntensity),
          blankClean = as.logical(blankClean),
          mzClust = as.numeric(mzClust),
          blankPresenceThreshold = as.numeric(blankPresenceThreshold),
          globalPresenceThreshold = as.numeric(globalPresenceThreshold)
        )
      ),
      .nta_method_defaults(required = "LoadFeaturesMS2", number_permitted = Inf)
    )
  )
  validate_object(x)
  x
}

#' @export
#' @noRd
validate_object.Method_NonTargetAnalysis_FilterFeaturesMS2 <- function(x, ...) {
  .validate_nta_method_base(x, "Method_NonTargetAnalysis_FilterFeaturesMS2", "FilterFeaturesMS2", Inf)
  checkmate::assert_integerish(x$parameters$top, len = 1, lower = 0)
  checkmate::assert_numeric(x$parameters$minIntensity, len = 1)
  checkmate::assert_numeric(x$parameters$relMinIntensity, len = 1)
  checkmate::assert_logical(x$parameters$blankClean, len = 1)
  checkmate::assert_number(x$parameters$mzClust, lower = 0, finite = TRUE)
  checkmate::assert_number(x$parameters$blankPresenceThreshold, lower = 0, upper = 1, finite = TRUE)
  checkmate::assert_number(x$parameters$globalPresenceThreshold, lower = 0, upper = 1, finite = TRUE)
  invisible(NULL)
}

#' @export
#' @noRd
run.Method_NonTargetAnalysis_FilterFeaturesMS2 <- function(x, proj, ...) {
  checkmate::assert_class(x, "Method_NonTargetAnalysis_FilterFeaturesMS2")
  validate_object(x)
  checkmate::assert_class(proj, "ProjectNonTargetAnalysis")
  p <- x$parameters
  success <- rcpp_project_nta_filter_features_ms2(
    nta_xptr = proj$get_nts_ptr(),
    top = as.integer(p$top),
    minIntensity = p$minIntensity,
    relMinIntensity = p$relMinIntensity,
    blankClean = isTRUE(p$blankClean),
    mzClust = as.numeric(p$mzClust),
    blankPresenceThreshold = as.numeric(p$blankPresenceThreshold),
    globalPresenceThreshold = as.numeric(p$globalPresenceThreshold)
  )
  .run_nta_method(success, proj, "Filtering feature MS2 data did not complete successfully.")
}

#' @title Method_NonTargetAnalysis_MetFragScreening
#' @description Create a `Method` child object for MetFrag-based suspect
#'   screening.
#' @param metfrag_path Character(1) path to the MetFrag executable or JAR.
#' @param database_type Character(1) MetFrag database type.
#' @param database_path Character(1) path to the local database file when
#'   applicable.
#' @param analyses Optional character vector restricting screening to selected
#'   analyses.
#' @param ppm,sec,ppmMS2,mzrMS2 Numeric scalar thresholds used during matching.
#' @param top_n Integer(1) maximum number of candidates to consider per
#'   feature.
#' @param filtered Logical(1) whether to include filtered features in the
#'   search.
#' @param java_path Character(1) path to the Java executable.
#' @param run_dir Character(1) output directory for MetFrag runs.
#' @param debug Logical(1) whether to keep debug output.
#' @param extra_params Named list of additional MetFrag parameters.
#' @return A `Method` object of class `Method_NonTargetAnalysis_MetFragScreening`.
#' @export
Method_NonTargetAnalysis_MetFragScreening <- function(
    metfrag_path = "",
    database_type = "LocalCSV",
    database_path = "",
    analyses = character(),
    ppm = 5,
    sec = 10,
    ppmMS2 = 10,
    mzrMS2 = 0.008,
    top_n = 1L,
    filtered = FALSE,
    java_path = "java",
    run_dir = "",
    debug = FALSE,
    extra_params = list()) {
  x <- Method(
    method = "MetFragScreening",
    required = c("FindFeatures", "LoadFeaturesMS1", "LoadFeaturesMS2"),
    owner_class = "ProjectNonTargetAnalysis",
    number_permitted = Inf,
    developer = "Christoph Ruttkies and Emma L. Schymanski",
    contact = "cruttkie@ipb-halle.de",
    link = "https://ipb-halle.github.io/MetFrag/projects/metfragcl/",
    doi = "https://doi.org/10.1186/s13321-016-0115-9",
    parameters = list(
      metfrag_path = as.character(metfrag_path),
      database_type = as.character(database_type),
      database_path = as.character(database_path),
      analyses = as.character(analyses),
      ppm = as.numeric(ppm),
      sec = as.numeric(sec),
      ppmMS2 = as.numeric(ppmMS2),
      mzrMS2 = as.numeric(mzrMS2),
      top_n = as.integer(top_n),
      filtered = as.logical(filtered),
      java_path = as.character(java_path),
      run_dir = as.character(run_dir),
      debug = as.logical(debug),
      extra_params = extra_params
    )
  )
  validate_object(x)
  x
}

#' @export
#' @noRd
validate_object.Method_NonTargetAnalysis_MetFragScreening <- function(x, ...) {
  validate_object.Method(x)
  checkmate::assert_class(x, "Method_NonTargetAnalysis_MetFragScreening")
  checkmate::assert_choice(x$method, "MetFragScreening")
  checkmate::assert_choice(x$owner_class, "ProjectNonTargetAnalysis")
  checkmate::assert_true(identical(x$number_permitted, Inf))
  checkmate::assert_character(x$parameters$metfrag_path, len = 1, any.missing = FALSE)
  checkmate::assert_character(x$parameters$database_type, len = 1, any.missing = FALSE)
  checkmate::assert_character(x$parameters$database_path, len = 1, any.missing = FALSE)
  checkmate::assert_character(x$parameters$analyses, any.missing = FALSE)
  checkmate::assert_number(x$parameters$ppm, lower = 0, finite = TRUE)
  checkmate::assert_number(x$parameters$sec, lower = 0, finite = TRUE)
  checkmate::assert_number(x$parameters$ppmMS2, lower = 0, finite = TRUE)
  checkmate::assert_number(x$parameters$mzrMS2, lower = 0, finite = TRUE)
  checkmate::assert_integerish(x$parameters$top_n, len = 1, lower = 1)
  checkmate::assert_logical(x$parameters$filtered, len = 1)
  checkmate::assert_character(x$parameters$java_path, len = 1, any.missing = FALSE)
  checkmate::assert_character(x$parameters$run_dir, len = 1, any.missing = FALSE)
  checkmate::assert_logical(x$parameters$debug, len = 1)
  checkmate::assert_list(x$parameters$extra_params, names = "named")
  invisible(NULL)
}

#' @export
#' @noRd
run.Method_NonTargetAnalysis_MetFragScreening <- function(x, proj, ...) {
  checkmate::assert_class(x, "Method_NonTargetAnalysis_MetFragScreening")
  validate_object(x)
  checkmate::assert_class(proj, "ProjectNonTargetAnalysis")
  p <- x$parameters
  success <- rcpp_project_nta_metfrag_screening(
    nta_xptr = proj$get_nts_ptr(),
    metfrag_path = as.character(p$metfrag_path),
    database_type = as.character(p$database_type),
    database_path = as.character(p$database_path),
    analyses = as.character(p$analyses),
    ppm = as.numeric(p$ppm),
    sec = as.numeric(p$sec),
    ppmMS2 = as.numeric(p$ppmMS2),
    mzrMS2 = as.numeric(p$mzrMS2),
    top_n = as.integer(p$top_n),
    filtered = isTRUE(p$filtered),
    java_path = as.character(p$java_path),
    run_dir = as.character(p$run_dir),
    debug = isTRUE(p$debug),
    extra_params = p$extra_params
  )
  .run_nta_method(success, proj, "MetFrag screening did not complete successfully.")
}

#' @title Method_NonTargetAnalysis_AssignTransformationProducts
#' @description Create a `Method` child object for assigning transformation
#'   products to suspect hits.
#' @param transformation_products A data.frame/data.table describing
#'   transformation products and their precursors.
#' @param chromatographic_phase Character(1) chromatographic phase used for RT
#'   plausibility checks.
#' @param mzrMS2 Numeric(1) absolute m/z tolerance for MS2 fragment matching.
#' @return A `Method` object of class
#'   `Method_NonTargetAnalysis_AssignTransformationProducts`.
#' @export
Method_NonTargetAnalysis_AssignTransformationProducts <- function(
    transformation_products = NULL,
    chromatographic_phase = c("reverse_phase", "hilic"),
    mzrMS2 = 0.008) {
  transformation_products_dt <- if (is.null(transformation_products)) {
    .empty_nta_transformation_products()
  } else {
    data.table::as.data.table(transformation_products)
  }
  x <- do.call(
    Method,
    c(
      list(
        method = "AssignTransformationProducts",
        parameters = list(
          transformation_products = transformation_products_dt,
          chromatographic_phase = match.arg(chromatographic_phase),
          mzrMS2 = as.numeric(mzrMS2)
        )
      ),
      .nta_method_defaults(required = character(), number_permitted = Inf)
    )
  )
  validate_object(x)
  x
}

#' @export
#' @noRd
validate_object.Method_NonTargetAnalysis_AssignTransformationProducts <- function(x, ...) {
  .validate_nta_method_base(x, "Method_NonTargetAnalysis_AssignTransformationProducts", "AssignTransformationProducts", Inf)
  tp <- data.table::as.data.table(x$parameters$transformation_products)
  checkmate::assert_data_frame(tp)
  checkmate::assert_choice(x$parameters$chromatographic_phase, c("reverse_phase", "hilic"))
  checkmate::assert_number(x$parameters$mzrMS2, lower = 0, finite = TRUE)
  if (nrow(tp) > 0) {
    checkmate::assert_true("name" %in% names(tp))
    checkmate::assert_true("SMILES" %in% names(tp))
  }
  invisible(NULL)
}

#' @export
#' @noRd
run.Method_NonTargetAnalysis_AssignTransformationProducts <- function(x, proj, ...) {
  checkmate::assert_class(x, "Method_NonTargetAnalysis_AssignTransformationProducts")
  validate_object(x)
  checkmate::assert_class(proj, "ProjectNonTargetAnalysis")
  p <- x$parameters
  success <- rcpp_project_non_target_analysis_assign_transformation_products(
    nta_xptr = proj$get_nts_ptr(),
    transformation_products = as.data.frame(data.table::as.data.table(p$transformation_products)),
    chromatographic_phase = as.character(p$chromatographic_phase),
    mzrMS2 = as.numeric(p$mzrMS2)
  )
  .run_nta_method(success, proj, "Assigning transformation products did not complete successfully.")
}
