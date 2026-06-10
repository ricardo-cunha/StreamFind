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
.metfrag_database_types <- c(
  "KEGG",
  "PubChem",
  "ExtendedPubChem",
  "ChemSpiderRest",
  "LocalSDF",
  "LocalPSV",
  "LocalCSV"
)

#' @noRd
.normalize_metfrag_database_type <- function(database_type) {
  checkmate::assert_character(database_type, len = 1, any.missing = FALSE)
  idx <- match(tolower(database_type), tolower(.metfrag_database_types))
  if (is.na(idx)) {
    stop(
      "`database_type` must be one of: ",
      paste(.metfrag_database_types, collapse = ", "),
      ".",
      call. = FALSE
    )
  }
  .metfrag_database_types[[idx]]
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
    rt = numeric(),
    SMILES = character(),
    InChI = character(),
    InChIKey = character(),
    ms2_positive = character(),
    ms2_negative = character(),
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
    main_precursor_xLogP = numeric(),
    bt_product_title = character(),
    bt_precursor_title = character(),
    bt_reaction_type = character(),
    bt_biosystem = character(),
    transformation_detail = character()
  )
}

#' @title Method_NonTargetAnalysis_FindFeatures
#' @description Create a `Method` child object for the native non-target
#'   feature-detection step. In LC/HRMS non-target analysis, this routine scans
#'   chromatographic signal, estimates a local baseline, groups nearby mass
#'   traces within the specified m/z tolerance, and proposes chromatographic
#'   peaks that become the initial feature table used by later alignment,
#'   correction, and identification steps.
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
#' @description Create a `Method` child object for extracting feature-centred
#'   MS1 trace data after feature detection. This step loads chromatographic
#'   signal around each NTA feature using configurable RT and m/z windows so
#'   later workflow steps can inspect peak shape, build components, perform
#'   QC, and visualise raw signal around the detected apex.
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
#' @description Create a `Method` child object for extracting tandem-MS data
#'   associated with detected NTA features. The native routine searches for MS2
#'   scans linked to each precursor feature, applies precursor-isolation and
#'   fragment clustering tolerances, and stores feature-linked MS2 evidence for
#'   suspect screening, MetFrag, and internal-standard confirmation.
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
#' @description Create a `Method` child object for assembling detected features
#'   into chromatographic components. In NTA, co-eluting ions with correlated
#'   signal profiles often originate from the same compound; this step groups
#'   those related features so isotopes, adducts, and in-source fragments can
#'   be interpreted in a compound-centric way rather than as isolated peaks.
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
validate_nta_isotope_elements <- function(isotopeElements) {
  supported <- c("C", "H", "B", "N", "O", "Mg", "Si", "S", "Cl", "Br", "K", "Ca", "Fe", "Cu", "Zn", "Se")
  seen_elements <- character()
  checkmate::assert_character(
    isotopeElements,
    min.len = 1,
    any.missing = FALSE,
    unique = TRUE
  )

  for (spec in isotopeElements) {
    matches <- regexec("^([A-Z][a-z]?)(?::([0-9]+)-([0-9]+))?$", spec)
    parts <- regmatches(spec, matches)[[1]]
    checkmate::assert_true(
      length(parts) > 0,
      .var.name = sprintf("isotopeElements entry '%s'", spec),
      add = "must be formatted as 'Element' or 'Element:min-max', e.g. 'Cl' or 'C:1-60'."
    )
    element <- parts[2]
    checkmate::assert_true(
      element %in% supported,
      .var.name = sprintf("element '%s'", element),
      add = sprintf("must be one of: %s.", paste(supported, collapse = ", "))
    )
    checkmate::assert_true(
      !(element %in% seen_elements),
      .var.name = sprintf("element '%s'", element),
      add = "must not be specified more than once in `isotopeElements`."
    )
    seen_elements <- c(seen_elements, element)
    if (length(parts) >= 4 && nzchar(parts[3]) && nzchar(parts[4])) {
      min_n <- as.integer(parts[3])
      max_n <- as.integer(parts[4])
      checkmate::assert_true(
        min_n <= max_n,
        .var.name = sprintf("isotopeElements entry '%s'", spec),
        add = "must have min <= max."
      )
    }
  }

  invisible(NULL)
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
#' @description Create a `Method` child object for annotating ion-relationship
#'   patterns inside previously created components. The native algorithm checks
#'   expected isotope spacing, charge states, and mass differences consistent
#'   with adducts and in-source fragments, helping translate raw NTA peak lists
#'   into chemically meaningful ion annotations. Isotope annotation is resolved
#'   before adducts and neutral losses. Final isotope assignments must satisfy
#'   the configured `ppm` tolerance, respect the allowed `maxGaps` in the
#'   isotope chain, and match the expected relative-intensity window estimated
#'   from the isotope composition. For isotope candidates, mass accuracy and
#'   relative-intensity agreement are weighted more strongly than retention-time
#'   apex agreement, because low-intensity isotope peaks can show modest apex
#'   shifts. Simpler isotope explanations are ranked ahead of multi-isotope
#'   combinations, which are penalized during scoring.
#' @param maxIsotopes Integer(1) maximum number of isotopes to consider.
#' @param maxCharge Integer(1) maximum charge state to consider.
#' @param maxGaps Integer(1) maximum number of gaps allowed in isotope
#'   patterns. For example, `maxGaps = 0` only allows consecutive isotope steps,
#'   whereas larger values allow skipped intermediate steps before the chain is
#'   rejected.
#' @param ppm Numeric(1) maximum m/z tolerance in ppm used for the final
#'   isotope, adduct, and loss assignment checks.
#' @param isotopeElements Character vector describing which elements are
#'   considered during isotope annotation and, optionally, their plausible atom
#'   count range. Each entry must be either `"Element"` or
#'   `"Element:min-max"`, for example `"Cl"` or `"C:1-60"`. The defaults are
#'   tuned for common environmental organic compounds such as pharmaceuticals,
#'   pesticides, PFAS, and personal care products:
#'   `c("C:1-60", "N:0-10", "O:0-20", "S:0-4", "Cl:0-6", "Br:0-4")`.
#'   Supported element symbols are `"C"`, `"H"`, `"B"`, `"N"`, `"O"`, `"Mg"`,
#'   `"Si"`, `"S"`, `"Cl"`, `"Br"`, `"K"`, `"Ca"`, `"Fe"`, `"Cu"`, `"Zn"`,
#'   and `"Se"`. Use explicit ranges when the expected chemistry is narrower or
#'   broader than the defaults.
#' @param debugComponent Character(1) component identifier to debug.
#' @param debugAnalysis Character(1) analysis name to debug.
#' @return A `Method` object of class `Method_NonTargetAnalysis_AnnotateComponents`.
#' @export
Method_NonTargetAnalysis_AnnotateComponents <- function(
    maxIsotopes = 5L,
    maxCharge = 1L,
    maxGaps = 1L,
    ppm = 10,
    isotopeElements = c("C:1-60", "N:0-10", "O:0-20", "S:0-4", "Cl:0-6", "Br:0-4"),
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
          isotopeElements = as.character(isotopeElements),
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
  validate_nta_isotope_elements(x$parameters$isotopeElements)
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
    isotopeElements = as.character(params$isotopeElements),
    debugComponent = as.character(params$debugComponent),
    debugAnalysis = as.character(params$debugAnalysis)
  )
  .run_nta_method(success, proj, "Annotating feature components did not complete successfully.")
}

#' @title Method_NonTargetAnalysis_GroupFeatures
#' @description Create a `Method` child object for aligning and grouping the
#'   same chemical feature across analyses. This is a core NTA aggregation step
#'   that merges per-analysis detections into shared feature groups using RT and
#'   m/z tolerances, optionally guided by internal standards or chromatographic
#'   warping, so samples can be compared on a common feature table.
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
#' @description Create a `Method` child object for gap filling after feature
#'   grouping. In cross-sample NTA tables, some groups are absent in individual
#'   analyses because signals fall below the original detection threshold or
#'   were missed during peak picking; this step revisits the expected RT and m/z
#'   region to recover plausible peak intensities and improve table completeness.
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
#' @description Create a `Method` child object for blank correction of grouped
#'   features. In NTA workflows, procedural and instrumental blanks often carry
#'   background contaminants and carryover peaks; this step compares grouped
#'   sample features against the associated blank signal and removes or flags
#'   features that are not sufficiently above blank contribution.
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

#' @title Method_NonTargetAnalysis_CorrectMatrixSuppression
#' @description Create a `Method` child object for correcting matrix suppression
#'   in project-based non-target analysis workflows. In the context of NTA, the
#'   method estimates a retention-time-dependent suppression profile from the
#'   MS1 total ion chromatogram (TIC) relative to associated blank analyses and
#'   stores a per-feature `correction` factor that can later be used to adjust
#'   feature intensities for comparison across analyses with different matrix
#'   effects.
#'
#'   The native project implementation follows the TiChri concept described by
#'   \href{https://pubs.acs.org/doi/10.1021/acs.analchem.1c00357}{Tisler et al.
#'   (2021)} for TIC-based suppression profiling, but adapts the feature-level
#'   scaling for the current `ProjectNonTargetAnalysis` backend. When internal
#'   standards are available, the algorithm builds a local linear model between
#'   TIC-derived suppression and internal-standard suppression using surrounding
#'   standards in retention-time order. When no usable internal standards are
#'   available, the method falls back to TIC-only correction.
#'
#'   The resulting correction values are written into the existing feature
#'   `correction` column and can be used by downstream plotting and summary
#'   methods that support intensity correction.
#' @param refBlankReplicate Optional character scalar naming a replicate whose
#'   assigned blank replicate(s) should be used as the common reference for all
#'   analyses. Use `NA_character_` to use the blank assignment already stored
#'   for each analysis in the project. This mirrors the legacy behavior where a
#'   single reference blank can be enforced across the workflow.
#' @param mpRtWindow Numeric(1) retention-time window in seconds used to
#'   calculate the TIC matrix-suppression profile around each time point and to
#'   summarize suppression over each feature's retention-time range. Larger
#'   values smooth the profile more strongly, while smaller values keep the
#'   correction more local.
#' @return A `Method` object of class `Method_NonTargetAnalysis_CorrectMatrixSuppression`.
#' @export
Method_NonTargetAnalysis_CorrectMatrixSuppression <- function(
    refBlankReplicate = NA_character_,
    mpRtWindow = 10) {
  x <- do.call(
    Method,
    c(
      list(
        method = "CorrectMatrixSuppression",
        parameters = list(
          refBlankReplicate = as.character(refBlankReplicate),
          mpRtWindow = as.numeric(mpRtWindow)
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
validate_object.Method_NonTargetAnalysis_CorrectMatrixSuppression <- function(x, ...) {
  .validate_nta_method_base(x, "Method_NonTargetAnalysis_CorrectMatrixSuppression", "CorrectMatrixSuppression", 1)
  checkmate::assert_character(x$parameters$refBlankReplicate, len = 1, any.missing = TRUE)
  checkmate::assert_number(x$parameters$mpRtWindow, lower = 0, finite = TRUE)
  invisible(NULL)
}

#' @export
#' @noRd
run.Method_NonTargetAnalysis_CorrectMatrixSuppression <- function(x, proj, ...) {
  checkmate::assert_class(x, "Method_NonTargetAnalysis_CorrectMatrixSuppression")
  validate_object(x)
  checkmate::assert_class(proj, "ProjectNonTargetAnalysis")
  p <- x$parameters
  ref_blank <- if (length(p$refBlankReplicate) == 0 || is.na(p$refBlankReplicate)) NULL else as.character(p$refBlankReplicate)
  success <- rcpp_project_nta_correct_matrix_suppression(
    nta_xptr = proj$get_nts_ptr(),
    mpRtWindow = as.numeric(p$mpRtWindow),
    refBlankReplicate = ref_blank
  )
  .run_nta_method(success, proj, "Matrix-suppression correction did not complete successfully.")
}

#' @title Method_NonTargetAnalysis_FilterFeatures
#' @description Create a `Method` child object for rule-based filtering of the
#'   NTA feature table. This step reduces the raw feature space by applying
#'   analytical quality criteria such as signal strength, peak width, fit, and
#'   prevalence, helping focus downstream screening and interpretation on more
#'   robust and reproducible features.
#' @param minSN Optional numeric(1) minimum signal-to-noise threshold. Use
#'   `NA_real_` to disable.
#' @param minIntensity Optional numeric(1) minimum feature apex intensity. Use
#'   `NA_real_` to disable.
#' @param minArea Optional numeric(1) minimum integrated feature area. Use
#'   `NA_real_` to disable.
#' @param minWidth Optional numeric(1) minimum chromatographic peak width in
#'   seconds. Use `NA_real_` to disable.
#' @param maxWidth Optional numeric(1) maximum chromatographic peak width in
#'   seconds. Use `NA_real_` to disable.
#' @param maxPPM Optional numeric(1) maximum acceptable mass error in ppm. Use
#'   `NA_real_` to disable.
#' @param minFwhmRT Optional numeric(1) minimum RT full width at half maximum.
#'   Use `NA_real_` to disable.
#' @param maxFwhmRT Optional numeric(1) maximum RT full width at half maximum.
#'   Use `NA_real_` to disable.
#' @param minFwhmMZ Optional numeric(1) minimum m/z full width at half maximum.
#'   Use `NA_real_` to disable.
#' @param maxFwhmMZ Optional numeric(1) maximum m/z full width at half maximum.
#'   Use `NA_real_` to disable.
#' @param minGaussianA Optional numeric(1) minimum fitted Gaussian amplitude.
#'   Use `NA_real_` to disable.
#' @param minGaussianMu Optional numeric(1) minimum fitted Gaussian centre. Use
#'   `NA_real_` to disable.
#' @param maxGaussianMu Optional numeric(1) maximum fitted Gaussian centre. Use
#'   `NA_real_` to disable.
#' @param minGaussianSigma Optional numeric(1) minimum fitted Gaussian sigma.
#'   Use `NA_real_` to disable.
#' @param maxGaussianSigma Optional numeric(1) maximum fitted Gaussian sigma.
#'   Use `NA_real_` to disable.
#' @param minGaussianR2 Optional numeric(1) minimum Gaussian fit quality
#'   (`R^2`). Use `NA_real_` to disable.
#' @param maxJaggedness Optional numeric(1) maximum permitted peak jaggedness.
#'   Use `NA_real_` to disable.
#' @param minSharpness Optional numeric(1) minimum peak sharpness. Use
#'   `NA_real_` to disable.
#' @param minAsymmetry Optional numeric(1) minimum accepted peak asymmetry. Use
#'   `NA_real_` to disable.
#' @param maxAsymmetry Optional numeric(1) maximum accepted peak asymmetry. Use
#'   `NA_real_` to disable.
#' @param minPlates Optional numeric(1) minimum theoretical plate count. Use
#'   `NA_real_` to disable.
#' @param minRelPresenceReplicate Optional numeric(1) minimum relative presence
#'   within replicate analyses. Use `NA_real_` to disable.
#' @param maxModality Optional integer scalar for the maximum number of local
#'   maxima. Use `NA_integer_` to disable.
#' @param onlyFilled Optional logical scalar. Use `TRUE` to keep only filled
#'   features, `FALSE` to keep only non-filled, or `NA` to disable.
#' @param removeFilled Logical(1) whether features marked as filled should be
#'   removed.
#' @param removeIsotopes Logical(1) whether isotope annotations should be
#'   removed.
#' @param removeAdducts Logical(1) whether annotated adduct features should be
#'   removed.
#' @param removeLosses Logical(1) whether annotated neutral-loss or in-source
#'   fragment features should be removed.
#' @param minSizeEIC Optional integer(1) minimum number of points in the stored
#'   extracted-ion chromatogram. Use `NA_integer_` to disable.
#' @param minSizeMS1 Optional integer(1) minimum number of stored MS1 points.
#'   Use `NA_integer_` to disable.
#' @param minSizeMS2 Optional integer(1) minimum number of stored MS2 fragment
#'   peaks. Use `NA_integer_` to disable.
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
#'   user-supplied suspect list. In the NTA workflow this step compares grouped
#'   features with expected precursor masses, retention times, and optionally
#'   MS2 evidence from candidate compounds, yielding ranked feature-to-suspect
#'   matches for further curation and filtering.
#' @param suspects A data.frame/data.table with suspect information.
#' @param analyses Optional character vector restricting screening to selected
#'   analyses.
#' @param ppm Numeric(1) precursor mass tolerance in ppm used for MS1 matching.
#' @param sec Numeric(1) retention-time tolerance in seconds used when suspect
#'   entries include RT information.
#' @param ppmMS2 Numeric(1) fragment mass tolerance in ppm used for MS2
#'   matching.
#' @param mzrMS2 Numeric(1) minimum absolute fragment m/z tolerance used during
#'   MS2 matching.
#' @param minCosineSimilarity Numeric(1) minimum cosine similarity required for
#'   MS2-supported suspect matches.
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
  checkmate::assert_true(
    any(c("mass", "mz", "SMILES", "InChI") %in% names(suspects)) || nrow(suspects) == 0L
  )
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

#' @title Method_NonTargetAnalysis_FindInternalStandards
#' @description Create a `Method` child object for locating internal standards
#'   in the current NTA feature set. The workflow uses the same style of mass,
#'   retention-time, and optional MS2 matching as suspect screening, but is
#'   targeted at spiked reference compounds used for alignment, QC assessment,
#'   and matrix-suppression correction.
#' @param suspects A data.frame/data.table with internal-standard information.
#' @param analyses Optional character vector restricting screening to selected
#'   analyses.
#' @param ppm Numeric(1) precursor mass tolerance in ppm used for MS1 matching.
#' @param sec Numeric(1) retention-time tolerance in seconds used when
#'   internal-standard entries include RT information.
#' @param ppmMS2 Numeric(1) fragment mass tolerance in ppm used for MS2
#'   matching.
#' @param mzrMS2 Numeric(1) minimum absolute fragment m/z tolerance used during
#'   MS2 matching.
#' @param minCosineSimilarity Numeric(1) minimum cosine similarity required for
#'   MS2-supported internal-standard matches.
#' @param minSharedFragments Integer(1) minimum number of shared MS2 fragments.
#' @param filtered Logical(1) whether to include filtered features in the
#'   search.
#' @return A `Method` object of class
#'   `Method_NonTargetAnalysis_FindInternalStandards`.
#' @export
Method_NonTargetAnalysis_FindInternalStandards <- function(
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
        method = "FindInternalStandards",
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
validate_object.Method_NonTargetAnalysis_FindInternalStandards <- function(x, ...) {
  .validate_nta_method_base(x, "Method_NonTargetAnalysis_FindInternalStandards", "FindInternalStandards", Inf)
  suspects <- data.table::as.data.table(x$parameters$suspects)
  checkmate::assert_data_frame(suspects)
  checkmate::assert_true("name" %in% names(suspects))
  checkmate::assert_true(
    any(c("mass", "mz", "SMILES", "InChI") %in% names(suspects)) || nrow(suspects) == 0L
  )
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
run.Method_NonTargetAnalysis_FindInternalStandards <- function(x, proj, ...) {
  checkmate::assert_class(x, "Method_NonTargetAnalysis_FindInternalStandards")
  validate_object(x)
  checkmate::assert_class(proj, "ProjectNonTargetAnalysis")
  p <- x$parameters
  success <- rcpp_project_nta_find_internal_standards(
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
  .run_nta_method(success, proj, "Finding internal standards did not complete successfully.")
}

#' @title Method_NonTargetAnalysis_FilterSuspects
#' @description Create a `Method` child object for refining suspect-screening
#'   results after the initial match step. It applies score, RT error, mass
#'   error, fragment evidence, cosine similarity, and identification-level
#'   thresholds so downstream NTA interpretation focuses on the most defensible
#'   candidate assignments.
#' @param names Optional character vector of suspect names to match.
#' @param minScore Optional numeric(1) minimum suspect score to keep. Use
#'   `NA_real_` to disable.
#' @param maxErrorRT Optional numeric(1) maximum absolute retention-time error
#'   allowed for a suspect match. Use `NA_real_` to disable.
#' @param maxErrorMass Optional numeric(1) maximum absolute mass error allowed
#'   for a suspect match. Use `NA_real_` to disable.
#' @param minCosineSimilarity Optional numeric(1) minimum cosine similarity for
#'   MS2-supported suspect matches. Use `NA_real_` to disable.
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
#' @description Create a `Method` child object for refining internal-standard
#'   matches after detection. The filtering logic mirrors suspect-hit filtering
#'   but is aimed at retaining only high-confidence analytical reference peaks
#'   that can be trusted for RT alignment, system performance checks, and
#'   matrix-effect scaling.
#' @param names Optional character vector of internal-standard names to match.
#' @param minScore Optional numeric(1) minimum internal-standard score to keep.
#'   Use `NA_real_` to disable.
#' @param maxErrorRT Optional numeric(1) maximum absolute retention-time error
#'   allowed for an internal-standard match. Use `NA_real_` to disable.
#' @param maxErrorMass Optional numeric(1) maximum absolute mass error allowed
#'   for an internal-standard match. Use `NA_real_` to disable.
#' @param minCosineSimilarity Optional numeric(1) minimum cosine similarity for
#'   MS2-supported internal-standard matches. Use `NA_real_` to disable.
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
#' @description Create a `Method` child object for cleaning and reducing
#'   feature-linked MS2 data. This step keeps the most informative MS2 spectra,
#'   removes weak or poorly supported fragments, and can suppress fragments that
#'   are prevalent in blanks so later identification steps operate on cleaner
#'   tandem-MS evidence.
#' @param top Integer(1) number of top MS2 spectra to keep per feature. Use `0`
#'   to disable.
#' @param minIntensity Optional numeric(1) minimum fragment intensity required
#'   to keep an MS2 peak. Use `NA_real_` to disable.
#' @param relMinIntensity Optional numeric(1) minimum relative fragment
#'   intensity required to keep an MS2 peak. Use `NA_real_` to disable.
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
#' @description Create a `Method` child object for MetFrag-based candidate
#'   screening on NTA features with MS2 support. This workflow exports feature
#'   data to MetFrag, queries the selected candidate database, and ranks
#'   structure hypotheses using in silico fragmentation, extending simple
#'   suspect matching with fragment-informed annotation.
#' @param metfrag_path Character(1) path to the MetFrag executable or JAR.
#' @param database_type Character(1) MetFrag candidate-source type. Supported
#'   options are `"KEGG"`, `"PubChem"`, `"ExtendedPubChem"`,
#'   `"ChemSpiderRest"`, `"LocalSDF"`, `"LocalPSV"`, and `"LocalCSV"`.
#'   Local database types require `database_path`; `"ChemSpiderRest"` also
#'   requires a `ChemSpiderToken` entry in `extra_params`.
#' @param database_path Character(1) path to the local database file used by
#'   `"LocalSDF"`, `"LocalPSV"`, or `"LocalCSV"`.
#' @param analyses Optional character vector restricting screening to selected
#'   analyses.
#' @param ppm Numeric(1) precursor mass tolerance in ppm used when querying
#'   MetFrag candidates.
#' @param sec Numeric(1) retention-time tolerance in seconds used when
#'   post-filtering candidates against available RT information.
#' @param ppmMS2 Numeric(1) fragment mass tolerance in ppm used when comparing
#'   explained and experimental MS2 fragments.
#' @param mzrMS2 Numeric(1) minimum absolute fragment m/z tolerance used during
#'   MS2 comparison.
#' @param top_n Integer(1) maximum number of candidates to consider per
#'   feature.
#' @param score_types Character vector of MetFrag score types. The default uses
#'   `"FragmenterScore"`. Official predefined options include
#'   `"FragmenterScore"`, `"SmartsSubstructureInclusionScore"`,
#'   `"SmartsSubstructureExclusionScore"`, and `"SuspectListScore"`. MetFrag CL
#'   also supports database-dependent scoring terms, for example
#'   `"PubChemNumberPatents"` and `"PubChemNumberPubMedReferences"` with
#'   `"ExtendedPubChem"`, and additional numeric columns or tags from local
#'   `LocalCSV`, `LocalPSV`, or `LocalSDF` databases.
#' @param score_weights Numeric vector of MetFrag score weights. Must match the
#'   length and order of `score_types`; MetFrag combines the weighted scores
#'   into the final candidate ranking.
#' @param pre_processing_candidate_filter Character vector of MetFrag
#'   pre-processing candidate filters applied before fragmentation and scoring.
#'   Official options include `"UnconnectedCompoundFilter"`,
#'   `"IsotopeFilter"`, `"MinimumElementsFilter"`,
#'   `"MaximumElementsFilter"`, `"SmartsSubstructureInclusionFilter"`,
#'   `"SmartsSubstructureExclusionFilter"`, `"ElementInclusionFilter"`,
#'   `"ElementInclusionExclusiveFilter"`, and `"ElementExclusionFilter"`.
#'   Some of these require additional MetFrag settings, for example
#'   `FilterMinimumElements`, `FilterMaximumElements`,
#'   `FilterSmartsInclusionList`, `FilterSmartsExclusionList`,
#'   `FilterIncludedElements`, or `FilterExcludedElements`, which can be passed
#'   via `extra_params`.
#' @param post_processing_candidate_filter Character vector of MetFrag
#'   post-processing candidate filters applied after fragmentation and scoring.
#'   The official documented option is `"InChIKeyFilter"`, which collapses
#'   stereoisomeric candidates sharing the first block of the InChIKey so only
#'   the best-scoring structural skeleton remains in the result list.
#' @param maximum_tree_depth Integer(1) maximum MetFrag fragmentation tree
#'   depth.
#' @param number_threads Integer(1) number of threads requested from MetFrag.
#' @param use_smiles Logical(1) whether MetFrag should fragment candidate
#'   structures using SMILES instead of InChI.
#' @param filtered Logical(1) whether to include filtered features in the
#'   search.
#' @param java_path Character(1) path to the Java executable.
#' @param run_dir Character(1) output directory for MetFrag run files. When
#'   empty, a timestamped directory under `./log/metfrag/` is created
#'   automatically, for example `./log/metfrag/run_20260527_153045/`.
#' @param debug Logical(1) whether to keep debug output.
#' @param extra_params Named list of additional MetFrag parameters.
#' @return A `Method` object of class `Method_NonTargetAnalysis_MetFragScreening`.
#' @export
Method_NonTargetAnalysis_MetFragScreening <- function(
    metfrag_path = "",
    database_type = "PubChem",
    database_path = "",
    analyses = character(),
    ppm = 5,
    sec = 10,
    ppmMS2 = 10,
    mzrMS2 = 0.008,
    top_n = 5L,
    score_types = "FragmenterScore",
    score_weights = 1,
    pre_processing_candidate_filter = c("UnconnectedCompoundFilter", "IsotopeFilter"),
    post_processing_candidate_filter = "InChIKeyFilter",
    maximum_tree_depth = 3L,
    number_threads = 1L,
    use_smiles = TRUE,
    filtered = FALSE,
    java_path = "java",
    run_dir = "",
    debug = FALSE,
    extra_params = list()) {
  database_type <- .normalize_metfrag_database_type(database_type)
  x <- Method(
    method = "MetFragScreening",
    required = c("FindFeatures", "LoadFeaturesMS2"),
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
      score_types = as.character(score_types),
      score_weights = as.numeric(score_weights),
      pre_processing_candidate_filter = as.character(pre_processing_candidate_filter),
      post_processing_candidate_filter = as.character(post_processing_candidate_filter),
      maximum_tree_depth = as.integer(maximum_tree_depth),
      number_threads = as.integer(number_threads),
      use_smiles = as.logical(use_smiles),
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
  checkmate::assert_choice(x$parameters$database_type, .metfrag_database_types)
  checkmate::assert_character(x$parameters$database_path, len = 1, any.missing = FALSE)
  checkmate::assert_character(x$parameters$analyses, any.missing = FALSE)
  checkmate::assert_number(x$parameters$ppm, lower = 0, finite = TRUE)
  checkmate::assert_number(x$parameters$sec, lower = 0, finite = TRUE)
  checkmate::assert_number(x$parameters$ppmMS2, lower = 0, finite = TRUE)
  checkmate::assert_number(x$parameters$mzrMS2, lower = 0, finite = TRUE)
  checkmate::assert_integerish(x$parameters$top_n, len = 1, lower = 1)
  checkmate::assert_character(x$parameters$score_types, min.len = 1, any.missing = FALSE)
  checkmate::assert_numeric(x$parameters$score_weights, min.len = 1, any.missing = FALSE)
  checkmate::assert_true(length(x$parameters$score_types) == length(x$parameters$score_weights))
  checkmate::assert_character(x$parameters$pre_processing_candidate_filter, min.len = 1, any.missing = FALSE)
  checkmate::assert_character(x$parameters$post_processing_candidate_filter, min.len = 1, any.missing = FALSE)
  checkmate::assert_integerish(x$parameters$maximum_tree_depth, len = 1, lower = 1)
  checkmate::assert_integerish(x$parameters$number_threads, len = 1, lower = 1)
  checkmate::assert_logical(x$parameters$use_smiles, len = 1)
  checkmate::assert_logical(x$parameters$filtered, len = 1)
  checkmate::assert_character(x$parameters$java_path, len = 1, any.missing = FALSE)
  checkmate::assert_character(x$parameters$run_dir, len = 1, any.missing = FALSE)
  checkmate::assert_logical(x$parameters$debug, len = 1)
  checkmate::assert_list(x$parameters$extra_params, names = "named")
  if (x$parameters$database_type %in% c("LocalSDF", "LocalPSV", "LocalCSV")) {
    if (!nzchar(x$parameters$database_path)) {
      stop(
        "`database_path` must be provided for `database_type = \"",
        x$parameters$database_type,
        "\"`.",
        call. = FALSE
      )
    }
    if (!file.exists(x$parameters$database_path)) {
      stop(
        "MetFrag local database file does not exist: ",
        x$parameters$database_path,
        call. = FALSE
      )
    }
  }
  if (identical(x$parameters$database_type, "ChemSpiderRest")) {
    has_token <- "ChemSpiderToken" %in% names(x$parameters$extra_params) &&
      nzchar(as.character(x$parameters$extra_params[["ChemSpiderToken"]]))
    if (!has_token) {
      stop(
        "`database_type = \"ChemSpiderRest\"` requires `extra_params[['ChemSpiderToken']]`.",
        call. = FALSE
      )
    }
  }
  invisible(NULL)
}

#' @export
#' @noRd
run.Method_NonTargetAnalysis_MetFragScreening <- function(x, proj, ...) {
  checkmate::assert_class(x, "Method_NonTargetAnalysis_MetFragScreening")
  validate_object(x)
  checkmate::assert_class(proj, "ProjectNonTargetAnalysis")
  p <- x$parameters
  if (isTRUE(p$debug) && (!length(p$run_dir) || is.na(p$run_dir) || !nzchar(p$run_dir))) {
    p$run_dir <- file.path(
      ".",
      "log",
      "metfrag",
      paste0("run_", format(Sys.time(), "%Y%m%d_%H%M%S"))
    )
  }
  if (isTRUE(p$debug) && nzchar(p$run_dir)) {
    dir.create(p$run_dir, recursive = TRUE, showWarnings = FALSE)
  }
  log_debug <- function(message) {
    if (!isTRUE(p$debug) || !nzchar(p$run_dir)) {
      return(invisible(NULL))
    }
    cat(
      sprintf(
        "[R %s] %s\n",
        format(Sys.time(), "%Y-%m-%d %H:%M:%OS3"),
        message
      ),
      file = file.path(p$run_dir, "streamfind_metfrag_debug.log"),
      append = TRUE
    )
    invisible(NULL)
  }
  log_debug("run.Method_NonTargetAnalysis_MetFragScreening:start")
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
    score_types = as.character(p$score_types),
    score_weights = as.numeric(p$score_weights),
    pre_processing_candidate_filter = as.character(p$pre_processing_candidate_filter),
    post_processing_candidate_filter = as.character(p$post_processing_candidate_filter),
    maximum_tree_depth = as.integer(p$maximum_tree_depth),
    number_threads = as.integer(p$number_threads),
    use_smiles = isTRUE(p$use_smiles),
    filtered = isTRUE(p$filtered),
    java_path = as.character(p$java_path),
    run_dir = as.character(p$run_dir),
    debug = isTRUE(p$debug),
    extra_params = p$extra_params
  )
  log_debug(sprintf("run.Method_NonTargetAnalysis_MetFragScreening:after_call success=%s", success))
  log_debug("run.Method_NonTargetAnalysis_MetFragScreening:before_.run_nta_method")
  .run_nta_method(success, proj, "MetFrag screening did not complete successfully.")
  log_debug("run.Method_NonTargetAnalysis_MetFragScreening:done")
}

#' @title Method_NonTargetAnalysis_AssignTransformationProducts
#' @description Create a `Method` child object for assigning expected
#'   transformation products to detected features or suspect hits. This workflow
#'   uses a supplied precursor-product table together with chromatographic
#'   plausibility and optional MS2 fragment support to propose environmentally
#'   relevant parent-product relationships in NTA studies. Structure matching is
#'   normalized internally with precedence `InChIKey > InChI > SMILES`, and the
#'   resulting assignments resolve one direct precursor and one main precursor
#'   feature group per detected product feature group. When the input table was
#'   generated with `search_transformation_products_biotransformer()`, the
#'   helper already harmonizes structure fields and direct-precursor metadata
#'   before this method runs.
#' @param transformation_products A data.frame/data.table describing
#'   transformation products and their precursors. Required columns are
#'   `name`, `transformation`, `precursor_name`, `precursor_formula`,
#'   `precursor_mass`, `precursor_SMILES`, `precursor_InChI`,
#'   `precursor_InChIKey`, `precursor_xLogP`, `main_precursor_name`,
#'   `main_precursor_formula`, `main_precursor_mass`, `main_precursor_SMILES`,
#'   `main_precursor_InChI`, `main_precursor_InChIKey`, and
#'   `main_precursor_xLogP`. Product-level structure columns should include at
#'   least one of `SMILES`, `InChI`, or `InChIKey`. Matching is normalized
#'   internally with precedence `InChIKey > InChI > SMILES`, so no additional
#'   `structure_key` columns are required in the input table.
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
    required_cols <- c(
      "name", "transformation",
      "precursor_name", "precursor_formula", "precursor_mass",
      "precursor_SMILES", "precursor_InChI", "precursor_InChIKey", "precursor_xLogP",
      "main_precursor_name", "main_precursor_formula", "main_precursor_mass",
      "main_precursor_SMILES", "main_precursor_InChI", "main_precursor_InChIKey", "main_precursor_xLogP"
    )
    checkmate::assert_true(all(required_cols %in% names(tp)))
    checkmate::assert_true(any(c("SMILES", "InChI", "InChIKey") %in% names(tp)))
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
  debug_path <- file.path(".", "log", "assign_transformation_products_debug.log")
  dir.create(dirname(debug_path), recursive = TRUE, showWarnings = FALSE)
  log_debug <- function(message) {
    cat(
      sprintf(
        "[R %s] %s\n",
        format(Sys.time(), "%Y-%m-%d %H:%M:%OS3"),
        message
      ),
      file = debug_path,
      append = TRUE
    )
    invisible(NULL)
  }
  log_debug("run.Method_NonTargetAnalysis_AssignTransformationProducts:start")
  success <- rcpp_project_non_target_analysis_assign_transformation_products(
    nta_xptr = proj$get_nts_ptr(),
    transformation_products = as.data.frame(data.table::as.data.table(p$transformation_products)),
    chromatographic_phase = as.character(p$chromatographic_phase),
    mzrMS2 = as.numeric(p$mzrMS2)
  )
  log_debug(sprintf("run.Method_NonTargetAnalysis_AssignTransformationProducts:after_call success=%s", success))
  log_debug("run.Method_NonTargetAnalysis_AssignTransformationProducts:before_.run_nta_method")
  .run_nta_method(success, proj, "Assigning transformation products did not complete successfully.")
  log_debug("run.Method_NonTargetAnalysis_AssignTransformationProducts:done")
}
