#' @noRd
.project_non_target_analysis_processing_methods <- function() {
  owner <- "ProjectNonTargetAnalysis"
  methods <- list(
    find_features = .make_project_processing_step(
      method = "find_features",
      required = NA_character_,
      owner_class = owner,
      parameters = list(
        rtWindows = data.frame(rtmin = numeric(), rtmax = numeric()),
        ppmThreshold = 15,
        noiseThreshold = 250,
        minSNR = 3,
        minTraces = 3,
        baselineWindow = 200,
        maxWidth = 100,
        baseQuantile = 0.1,
        debugAnalysis = "",
        debugMZ = 0,
        debugSpecIdx = -1L
      ),
      parameter_docs = list(
        analyses = .make_processing_parameter_doc("Analyses selection to process.", "character"),
        rtWindows = .make_processing_parameter_doc("Data frame with 'rtmin' and 'rtmax' columns.", "data.frame", TRUE),
        ppmThreshold = .make_processing_parameter_doc("Mass error threshold in ppm.", "numeric", TRUE),
        noiseThreshold = .make_processing_parameter_doc("Minimum intensity threshold for denoising.", "numeric", TRUE),
        minSNR = .make_processing_parameter_doc("Minimum signal-to-noise ratio.", "numeric", TRUE),
        minTraces = .make_processing_parameter_doc("Minimum number of traces for a candidate feature.", "integer", TRUE),
        baselineWindow = .make_processing_parameter_doc("Baseline estimation window.", "numeric", TRUE),
        maxWidth = .make_processing_parameter_doc("Maximum expected peak width.", "numeric", TRUE),
        baseQuantile = .make_processing_parameter_doc("Baseline quantile.", "numeric", TRUE),
        debugAnalysis = .make_processing_parameter_doc("Optional analysis name to debug.", "character"),
        debugMZ = .make_processing_parameter_doc("Optional m/z value to debug.", "numeric"),
        debugSpecIdx = .make_processing_parameter_doc("Optional spectrum index to debug.", "integer")
      ),
      algorithm = "native",
      title = "Find Features",
      description = "Run project-owned feature detection using shared Mass Spec tables.",
      details = "Native StreamFind feature finding over the active project analyses. Results are persisted into shared NTS feature tables for the owning project."
    ),
    load_features_ms1 = .make_project_processing_step(
      method = "load_features_ms1",
      required = "find_features",
      owner_class = owner,
      parameters = list(
        rtWindow = c(-2, 2),
        mzWindow = c(-1, 6),
        mzClust = 0.005,
        presence = 0.8,
        minIntensity = 250,
        filtered = FALSE
      ),
      parameter_docs = list(
        analyses = .make_processing_parameter_doc("Analyses selection to process.", "character"),
        rtWindow = .make_processing_parameter_doc("Numeric length-2 vector of RT offsets.", "numeric", TRUE),
        mzWindow = .make_processing_parameter_doc("Numeric length-2 vector of m/z offsets.", "numeric", TRUE),
        mzClust = .make_processing_parameter_doc("Clustering tolerance.", "numeric", TRUE),
        presence = .make_processing_parameter_doc("Minimum cluster presence fraction.", "numeric", TRUE),
        minIntensity = .make_processing_parameter_doc("Minimum trace intensity.", "numeric", TRUE),
        filtered = .make_processing_parameter_doc("Include filtered features when TRUE.", "logical", TRUE)
      ),
      algorithm = "native",
      title = "Load Features MS1",
      description = "Load MS1 traces into shared project features.",
      details = "Loads MS1 trace summaries for existing project features and updates the shared NTS feature store."
    ),
    load_features_ms2 = .make_project_processing_step(
      method = "load_features_ms2",
      required = "find_features",
      owner_class = owner,
      parameters = list(
        isolationWindow = 1.3,
        mzClust = 0.005,
        presence = 0.8,
        minIntensity = 10,
        filtered = FALSE
      ),
      parameter_docs = list(
        analyses = .make_processing_parameter_doc("Analyses selection to process.", "character"),
        isolationWindow = .make_processing_parameter_doc("Precursor isolation window.", "numeric", TRUE),
        mzClust = .make_processing_parameter_doc("Clustering tolerance.", "numeric", TRUE),
        presence = .make_processing_parameter_doc("Minimum cluster presence fraction.", "numeric", TRUE),
        minIntensity = .make_processing_parameter_doc("Minimum trace intensity.", "numeric", TRUE),
        filtered = .make_processing_parameter_doc("Include filtered features when TRUE.", "logical", TRUE)
      ),
      algorithm = "native",
      title = "Load Features MS2",
      description = "Load MS2 spectra into shared project features.",
      details = "Loads MS2 summaries for existing project features and updates the shared NTS feature store."
    ),
    create_components = .make_project_processing_step(
      method = "create_components",
      required = "find_features",
      owner_class = owner,
      parameters = list(
        rtWindow = c(0, 0),
        minCorrelation = 0.8,
        debugRT = 0,
        debugAnalysis = ""
      ),
      parameter_docs = list(
        analyses = .make_processing_parameter_doc("Analyses selection to process.", "character"),
        rtWindow = .make_processing_parameter_doc("Numeric length-2 vector of RT offsets.", "numeric", TRUE),
        minCorrelation = .make_processing_parameter_doc("Minimum EIC correlation.", "numeric", TRUE),
        debugRT = .make_processing_parameter_doc("Optional debug RT.", "numeric"),
        debugAnalysis = .make_processing_parameter_doc("Optional analysis name to debug.", "character")
      ),
      algorithm = "native",
      title = "Create Components",
      description = "Create feature components and update shared NTS features.",
      details = "Clusters related features into components using shared project feature state."
    ),
    annotate_components = .make_project_processing_step(
      method = "annotate_components",
      required = "create_components",
      owner_class = owner,
      parameters = list(
        maxIsotopes = 5L,
        maxCharge = 1L,
        maxGaps = 1L,
        ppm = 10,
        debugComponent = "",
        debugAnalysis = ""
      ),
      parameter_docs = list(
        analyses = .make_processing_parameter_doc("Analyses selection to process.", "character"),
        maxIsotopes = .make_processing_parameter_doc("Maximum isotope count.", "integer", TRUE),
        maxCharge = .make_processing_parameter_doc("Maximum charge state.", "integer", TRUE),
        maxGaps = .make_processing_parameter_doc("Maximum isotope gaps.", "integer", TRUE),
        ppm = .make_processing_parameter_doc("Mass tolerance in ppm.", "numeric", TRUE),
        debugComponent = .make_processing_parameter_doc("Optional component id to debug.", "character"),
        debugAnalysis = .make_processing_parameter_doc("Optional analysis name to debug.", "character")
      ),
      algorithm = "native",
      title = "Annotate Components",
      description = "Annotate components with isotope, adduct, and fragment relationships.",
      details = "Runs native component annotation against shared project feature data and persists the resulting annotations."
    ),
    group_features = .make_project_processing_step(
      method = "group_features",
      required = "find_features",
      owner_class = owner,
      parameters = list(
        method = "internal_standards",
        rtDeviation = 5,
        ppm = 10,
        minSamples = 1L,
        binSize = 5,
        filtered = FALSE,
        debug = FALSE,
        debugRT = 0
      ),
      parameter_docs = list(
        analyses = .make_processing_parameter_doc("Analyses selection to process.", "character"),
        method = .make_processing_parameter_doc("Alignment method.", "character", TRUE),
        rtDeviation = .make_processing_parameter_doc("RT tolerance.", "numeric", TRUE),
        ppm = .make_processing_parameter_doc("Mass tolerance in ppm.", "numeric", TRUE),
        minSamples = .make_processing_parameter_doc("Minimum sample count.", "integer", TRUE),
        binSize = .make_processing_parameter_doc("RT bin size.", "numeric", TRUE),
        filtered = .make_processing_parameter_doc("Include filtered features when TRUE.", "logical", TRUE),
        debug = .make_processing_parameter_doc("Enable native debug output.", "logical", TRUE),
        debugRT = .make_processing_parameter_doc("Optional debug RT.", "numeric")
      ),
      algorithm = "native",
      title = "Group Features",
      description = "Group features across analyses and update shared NTS features.",
      details = "Assigns feature groups across analyses using the configured alignment strategy."
    ),
    fill_features = .make_project_processing_step(
      method = "fill_features",
      required = c("find_features", "group_features"),
      owner_class = owner,
      parameters = list(
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
        debugFG = ""
      ),
      parameter_docs = list(
        analyses = .make_processing_parameter_doc("Analyses selection to process.", "character"),
        withinReplicate = .make_processing_parameter_doc("Fill only within replicate when TRUE.", "logical", TRUE),
        filtered = .make_processing_parameter_doc("Include filtered features when TRUE.", "logical", TRUE),
        rtExpand = .make_processing_parameter_doc("RT expansion.", "numeric", TRUE),
        mzExpand = .make_processing_parameter_doc("m/z expansion.", "numeric", TRUE),
        maxPeakWidth = .make_processing_parameter_doc("Maximum peak width.", "numeric", TRUE),
        minTracesIntensity = .make_processing_parameter_doc("Minimum trace intensity.", "numeric", TRUE),
        minNumberTraces = .make_processing_parameter_doc("Minimum number of traces.", "integer", TRUE),
        minIntensity = .make_processing_parameter_doc("Minimum feature intensity.", "numeric", TRUE),
        rtApexDeviation = .make_processing_parameter_doc("RT apex deviation.", "numeric", TRUE),
        minSignalToNoiseRatio = .make_processing_parameter_doc("Minimum signal-to-noise ratio.", "numeric", TRUE),
        minGaussianFit = .make_processing_parameter_doc("Minimum Gaussian fit.", "numeric", TRUE),
        debugFG = .make_processing_parameter_doc("Optional feature-group id to debug.", "character")
      ),
      algorithm = "native",
      title = "Fill Features",
      description = "Fill grouped feature gaps and update shared NTS features.",
      details = "Expands grouped features to fill missing measurements using the shared project feature tables."
    ),
    blank_subtraction = .make_project_processing_step(
      method = "blank_subtraction",
      required = "find_features",
      owner_class = owner,
      parameters = list(
        blankThreshold = 5,
        rtExpand = 10,
        mzExpand = 0.005
      ),
      parameter_docs = list(
        analyses = .make_processing_parameter_doc("Analyses selection to process.", "character"),
        blankThreshold = .make_processing_parameter_doc("Blank threshold.", "numeric", TRUE),
        rtExpand = .make_processing_parameter_doc("RT expansion.", "numeric", TRUE),
        mzExpand = .make_processing_parameter_doc("m/z expansion.", "numeric", TRUE)
      ),
      algorithm = "native",
      title = "Blank Subtraction",
      description = "Apply blank subtraction and update shared NTS features.",
      details = "Removes features associated with blank samples using configured RT and m/z expansion rules."
    ),
    filter_features = .make_project_processing_step(
      method = "filter_features",
      required = "find_features",
      owner_class = owner,
      parameters = list(
        minSN = NA_real_, minIntensity = NA_real_, minArea = NA_real_, minWidth = NA_real_, maxWidth = NA_real_,
        maxPPM = NA_real_, minFwhmRT = NA_real_, maxFwhmRT = NA_real_, minFwhmMZ = NA_real_, maxFwhmMZ = NA_real_,
        minGaussianA = NA_real_, minGaussianMu = NA_real_, maxGaussianMu = NA_real_, minGaussianSigma = NA_real_,
        maxGaussianSigma = NA_real_, minGaussianR2 = NA_real_, maxJaggedness = NA_real_, minSharpness = NA_real_,
        minAsymmetry = NA_real_, maxAsymmetry = NA_real_, maxModality = NA_integer_, minPlates = NA_real_, onlyFilled = NA,
        removeFilled = FALSE, minSizeEIC = NA_integer_, minSizeMS1 = NA_integer_, minSizeMS2 = NA_integer_,
        minRelPresenceReplicate = NA_real_, removeIsotopes = FALSE, removeAdducts = FALSE, removeLosses = FALSE
      ),
      parameter_docs = list(
        analyses = .make_processing_parameter_doc("Analyses selection to process.", "character"),
        minSN = .make_processing_parameter_doc("Minimum signal-to-noise ratio.", "numeric"),
        minIntensity = .make_processing_parameter_doc("Minimum intensity.", "numeric"),
        minArea = .make_processing_parameter_doc("Minimum peak area.", "numeric"),
        minWidth = .make_processing_parameter_doc("Minimum peak width.", "numeric"),
        maxWidth = .make_processing_parameter_doc("Maximum peak width.", "numeric"),
        maxPPM = .make_processing_parameter_doc("Maximum ppm error.", "numeric"),
        minFwhmRT = .make_processing_parameter_doc("Minimum FWHM in RT.", "numeric"),
        maxFwhmRT = .make_processing_parameter_doc("Maximum FWHM in RT.", "numeric"),
        minFwhmMZ = .make_processing_parameter_doc("Minimum FWHM in m/z.", "numeric"),
        maxFwhmMZ = .make_processing_parameter_doc("Maximum FWHM in m/z.", "numeric"),
        minGaussianA = .make_processing_parameter_doc("Minimum Gaussian amplitude.", "numeric"),
        minGaussianMu = .make_processing_parameter_doc("Minimum Gaussian mean.", "numeric"),
        maxGaussianMu = .make_processing_parameter_doc("Maximum Gaussian mean.", "numeric"),
        minGaussianSigma = .make_processing_parameter_doc("Minimum Gaussian sigma.", "numeric"),
        maxGaussianSigma = .make_processing_parameter_doc("Maximum Gaussian sigma.", "numeric"),
        minGaussianR2 = .make_processing_parameter_doc("Minimum Gaussian fit.", "numeric"),
        maxJaggedness = .make_processing_parameter_doc("Maximum jaggedness.", "numeric"),
        minSharpness = .make_processing_parameter_doc("Minimum sharpness.", "numeric"),
        minAsymmetry = .make_processing_parameter_doc("Minimum asymmetry.", "numeric"),
        maxAsymmetry = .make_processing_parameter_doc("Maximum asymmetry.", "numeric"),
        maxModality = .make_processing_parameter_doc("Maximum modality.", "integer"),
        minPlates = .make_processing_parameter_doc("Minimum plates.", "numeric"),
        onlyFilled = .make_processing_parameter_doc("Logical or NA selection for filled features.", "logical"),
        removeFilled = .make_processing_parameter_doc("Remove filled features when TRUE.", "logical", TRUE),
        minSizeEIC = .make_processing_parameter_doc("Minimum EIC size.", "integer"),
        minSizeMS1 = .make_processing_parameter_doc("Minimum MS1 size.", "integer"),
        minSizeMS2 = .make_processing_parameter_doc("Minimum MS2 size.", "integer"),
        minRelPresenceReplicate = .make_processing_parameter_doc("Minimum replicate presence.", "numeric"),
        removeIsotopes = .make_processing_parameter_doc("Remove isotope annotations when TRUE.", "logical", TRUE),
        removeAdducts = .make_processing_parameter_doc("Remove adduct annotations when TRUE.", "logical", TRUE),
        removeLosses = .make_processing_parameter_doc("Remove loss annotations when TRUE.", "logical", TRUE)
      ),
      algorithm = "native",
      title = "Filter Features",
      description = "Filter shared project features and update NTS features.",
      details = "Applies feature-level filtering thresholds and annotation-based exclusion rules to the shared NTS feature table.",
      number_permitted = Inf
    ),
    filter_features_ms2 = .make_project_processing_step(
      method = "filter_features_ms2",
      required = "load_features_ms2",
      owner_class = owner,
      parameters = list(
        top = 0L, minIntensity = NA_real_, relMinIntensity = NA_real_, blankClean = FALSE,
        mzClust = 0.005, blankPresenceThreshold = 0.8, globalPresenceThreshold = 0.1
      ),
      parameter_docs = list(
        analyses = .make_processing_parameter_doc("Analyses selection to process.", "character"),
        top = .make_processing_parameter_doc("Maximum number of peaks to keep.", "integer", TRUE),
        minIntensity = .make_processing_parameter_doc("Minimum absolute peak intensity.", "numeric"),
        relMinIntensity = .make_processing_parameter_doc("Minimum relative peak intensity.", "numeric"),
        blankClean = .make_processing_parameter_doc("Remove blank-associated MS2 peaks when TRUE.", "logical", TRUE),
        mzClust = .make_processing_parameter_doc("m/z clustering tolerance.", "numeric", TRUE),
        blankPresenceThreshold = .make_processing_parameter_doc("Blank presence threshold.", "numeric", TRUE),
        globalPresenceThreshold = .make_processing_parameter_doc("Global presence threshold.", "numeric", TRUE)
      ),
      algorithm = "native",
      title = "Filter Features MS2",
      description = "Filter MS2 spectra stored on shared project features.",
      details = "Cleans and reduces feature-linked MS2 spectra using intensity and blank-presence criteria.",
      number_permitted = Inf
    ),
    suspect_screening = .make_project_processing_step(
      method = "suspect_screening",
      required = "find_features",
      owner_class = owner,
      parameters = list(
        suspects = data.frame(), ppm = 5, sec = 10, ppmMS2 = 10, mzrMS2 = 0.008,
        minCosineSimilarity = 0.7, minSharedFragments = 3L, filtered = FALSE
      ),
      parameter_docs = list(
        analyses = .make_processing_parameter_doc("Analyses selection to process.", "character"),
        suspects = .make_processing_parameter_doc("Data frame with suspect information.", "data.frame", TRUE),
        ppm = .make_processing_parameter_doc("Mass tolerance in ppm.", "numeric", TRUE),
        sec = .make_processing_parameter_doc("Retention time tolerance in seconds.", "numeric", TRUE),
        ppmMS2 = .make_processing_parameter_doc("MS2 fragment mass tolerance in ppm.", "numeric", TRUE),
        mzrMS2 = .make_processing_parameter_doc("Minimum absolute MS2 fragment tolerance.", "numeric", TRUE),
        minCosineSimilarity = .make_processing_parameter_doc("Minimum cosine similarity threshold.", "numeric", TRUE),
        minSharedFragments = .make_processing_parameter_doc("Minimum number of shared fragments.", "integer", TRUE),
        filtered = .make_processing_parameter_doc("Include filtered features when TRUE.", "logical", TRUE)
      ),
      algorithm = "native",
      title = "Suspect Screening",
      description = "Run project-owned suspect screening and persist shared suspect tables.",
      details = "Matches supplied suspect metadata against project features and stores results in shared NTS suspect tables."
    ),
    metfrag_screening = .make_project_processing_step(
      method = "metfrag_screening",
      required = c("find_features", "load_features_ms1", "load_features_ms2"),
      owner_class = owner,
      parameters = list(
        metfrag_path = "", database_type = "LocalCSV", database_path = "", ppm = 5, sec = 10,
        ppmMS2 = 10, mzrMS2 = 0.008, top_n = 1L, filtered = FALSE, java_path = "java",
        run_dir = "", debug = FALSE, extra_params = list()
      ),
      parameter_docs = list(
        analyses = .make_processing_parameter_doc("Analyses selection to process.", "character"),
        metfrag_path = .make_processing_parameter_doc("Path to the MetFrag executable or jar wrapper.", "character", TRUE),
        database_type = .make_processing_parameter_doc("Database type string.", "character", TRUE),
        database_path = .make_processing_parameter_doc("Optional MetFrag database path.", "character"),
        ppm = .make_processing_parameter_doc("Precursor mass tolerance in ppm.", "numeric", TRUE),
        sec = .make_processing_parameter_doc("Retention time tolerance in seconds.", "numeric", TRUE),
        ppmMS2 = .make_processing_parameter_doc("MS2 tolerance in ppm.", "numeric", TRUE),
        mzrMS2 = .make_processing_parameter_doc("Absolute MS2 tolerance.", "numeric", TRUE),
        top_n = .make_processing_parameter_doc("Number of candidates per feature.", "integer", TRUE),
        filtered = .make_processing_parameter_doc("Include filtered features when TRUE.", "logical", TRUE),
        java_path = .make_processing_parameter_doc("Path to the Java executable.", "character", TRUE),
        run_dir = .make_processing_parameter_doc("Optional MetFrag run directory.", "character"),
        debug = .make_processing_parameter_doc("Enable debug mode.", "logical", TRUE),
        extra_params = .make_processing_parameter_doc("Named list of additional MetFrag parameters.", "list")
      ),
      algorithm = "metfrag",
      title = "MetFrag Screening",
      description = "Run project-owned MetFrag screening and update shared suspect tables.",
      details = "Executes MetFrag-based suspect screening against project feature data and persists matched candidates."
    ),
    find_internal_standards = .make_project_processing_step(
      method = "find_internal_standards",
      required = "find_features",
      owner_class = owner,
      parameters = list(
        suspects = data.frame(), ppm = 5, sec = 10, ppmMS2 = 10, mzrMS2 = 0.008,
        minCosineSimilarity = 0.7, minSharedFragments = 3L, filtered = TRUE
      ),
      parameter_docs = list(
        analyses = .make_processing_parameter_doc("Analyses selection to process.", "character"),
        suspects = .make_processing_parameter_doc("Data frame with internal-standard candidate information.", "data.frame", TRUE),
        ppm = .make_processing_parameter_doc("Mass tolerance in ppm.", "numeric", TRUE),
        sec = .make_processing_parameter_doc("Retention time tolerance in seconds.", "numeric", TRUE),
        ppmMS2 = .make_processing_parameter_doc("MS2 fragment mass tolerance in ppm.", "numeric", TRUE),
        mzrMS2 = .make_processing_parameter_doc("Minimum absolute MS2 fragment tolerance.", "numeric", TRUE),
        minCosineSimilarity = .make_processing_parameter_doc("Minimum cosine similarity threshold.", "numeric", TRUE),
        minSharedFragments = .make_processing_parameter_doc("Minimum number of shared fragments.", "integer", TRUE),
        filtered = .make_processing_parameter_doc("Include filtered features when TRUE.", "logical", TRUE)
      ),
      algorithm = "native",
      title = "Find Internal Standards",
      description = "Run project-owned internal-standard finding and persist shared internal-standard tables.",
      details = "Matches candidate internal standards against project features and stores the resulting annotations."
    ),
    filter_suspects = .make_project_processing_step(
      method = "filter_suspects",
      required = "suspect_screening",
      owner_class = owner,
      parameters = list(
        names = character(0), minScore = NA_real_, maxErrorRT = NA_real_, maxErrorMass = NA_real_,
        idLevels = integer(0), minSharedFragments = 0L, minCosineSimilarity = NA_real_
      ),
      parameter_docs = list(
        analyses = .make_processing_parameter_doc("Analyses selection to process.", "character"),
        names = .make_processing_parameter_doc("Suspect names to keep.", "character"),
        minScore = .make_processing_parameter_doc("Minimum score.", "numeric"),
        maxErrorRT = .make_processing_parameter_doc("Maximum RT error.", "numeric"),
        maxErrorMass = .make_processing_parameter_doc("Maximum mass error.", "numeric"),
        idLevels = .make_processing_parameter_doc("Allowed ID levels.", "integer"),
        minSharedFragments = .make_processing_parameter_doc("Minimum shared fragments.", "integer", TRUE),
        minCosineSimilarity = .make_processing_parameter_doc("Minimum cosine similarity.", "numeric")
      ),
      algorithm = "native",
      title = "Filter Suspects",
      description = "Filter shared project suspects and update NTS suspect results.",
      details = "Applies score, error, and fragment-based filters to existing shared suspect matches.",
      number_permitted = Inf
    ),
    filter_internal_standards = .make_project_processing_step(
      method = "filter_internal_standards",
      required = "find_internal_standards",
      owner_class = owner,
      parameters = list(
        names = character(0), minScore = NA_real_, maxErrorRT = NA_real_, maxErrorMass = NA_real_,
        idLevels = integer(0), minSharedFragments = 0L, minCosineSimilarity = NA_real_
      ),
      parameter_docs = list(
        analyses = .make_processing_parameter_doc("Analyses selection to process.", "character"),
        names = .make_processing_parameter_doc("Internal-standard names to keep.", "character"),
        minScore = .make_processing_parameter_doc("Minimum score.", "numeric"),
        maxErrorRT = .make_processing_parameter_doc("Maximum RT error.", "numeric"),
        maxErrorMass = .make_processing_parameter_doc("Maximum mass error.", "numeric"),
        idLevels = .make_processing_parameter_doc("Allowed ID levels.", "integer"),
        minSharedFragments = .make_processing_parameter_doc("Minimum shared fragments.", "integer", TRUE),
        minCosineSimilarity = .make_processing_parameter_doc("Minimum cosine similarity.", "numeric")
      ),
      algorithm = "native",
      title = "Filter Internal Standards",
      description = "Filter shared project internal standards and update results.",
      details = "Applies score, error, and fragment-based filters to existing shared internal-standard matches.",
      number_permitted = Inf
    ),
    assign_transformation_products = .make_project_processing_step(
      method = "assign_transformation_products",
      required = "suspect_screening",
      owner_class = owner,
      parameters = list(
        transformation_products = data.frame(), chromatographic_phase = "reverse_phase", mzrMS2 = 0.008
      ),
      parameter_docs = list(
        transformation_products = .make_processing_parameter_doc("Data frame with transformation-product definitions.", "data.frame", TRUE),
        chromatographic_phase = .make_processing_parameter_doc("Chromatographic phase for RT plausibility.", "character", TRUE),
        mzrMS2 = .make_processing_parameter_doc("Absolute MS2 tolerance.", "numeric", TRUE)
      ),
      algorithm = "native",
      title = "Assign Transformation Products",
      description = "Assign transformation products and update shared transformation-product tables.",
      details = "Links transformation-product definitions to existing suspect annotations and persists the resulting network in the shared project DB."
    )
  )
  methods
}

#' @title Project Non-Target Analysis R6 Class
#' @description R6 child of `ProjectMassSpec` that anchors NTS-specific schema and
#'   NTS processing/query methods in the shared project DuckDB.
#' @details
#' This is a public user-facing project class.
#'
#' `ProjectNonTargetAnalysis` includes all NTS-specific methods documented on this
#' page and also inherits shared project/runtime methods such as `run_app()`,
#' `run_workflow()`, `report_quarto()`, `metadata`, `workflow`, `get_audit()`,
#' `list_tables()`, `validate()`, and `get_domain()`.
#'
#' It also inherits shared Mass Spec methods such as `import_files()`,
#' `list_analyses()`, `get_analysis_names()`, `get_replicate_names()`,
#' `set_replicate_names()`, `get_blank_names()`, `set_blank_names()`,
#' `get_concentrations()`, `set_concentrations()`, `get_spectra_headers()`,
#' `get_raw_spectra()`, `get_raw_spectra_tic()`, `get_raw_spectra_bpc()`,
#' `get_raw_spectra_eic()`, `get_raw_spectra_ms1()`, `get_raw_spectra_ms2()`,
#' `plot_spectra_tic()`, `plot_spectra_bpc()`, and `plot_spectra_eic()`.
#'
#' See `?Project` for shared project/runtime methods and `?ProjectMassSpec` for
#' inherited shared Mass Spec methods.
#'
#' Use `?ProjectNonTargetAnalysis` as the main entry point for the NTS-specific
#' interface on top of those base classes.
#' @param db Path to the project DuckDB file.
#' @param project_id Active project identifier.
#' @export
ProjectNonTargetAnalysis <- R6::R6Class(
  classname = "ProjectNonTargetAnalysis",
  inherit = ProjectMassSpec,
  cloneable = FALSE,
  private = list(
    .nts_ptr = NULL,
    .resolve_selected_analyses = function(analyses = NULL) {
      analyses_info <- data.table::as.data.table(self$list_analyses())
      all_names <- analyses_info$analysis
      list(
        info = analyses_info,
        selected = .resolve_analyses_selection(analyses, all_names)
      )
    },
    .parse_selection = function(sel, column, aliases = character(0)) {
      res <- list(values = NULL, analyses = NULL, ids = NULL)
      if (is.null(sel)) {
        return(res)
      }
      col_opts <- c(column, aliases)
      if (is.data.frame(sel)) {
        col_match <- col_opts[col_opts %in% colnames(sel)]
        if (length(col_match) == 0) {
          stop(sprintf(
            "Selection for '%s' must include one of the following columns: %s",
            column,
            paste(col_opts, collapse = ", ")
          ))
        }
        res$values <- sel[[col_match[1]]]
        if ("analysis" %in% colnames(sel)) {
          res$analyses <- unique(sel$analysis)
        }
        if ("name" %in% colnames(sel)) {
          res$ids <- sel$name
        }
      } else {
        res$values <- sel
        if (!is.null(names(sel))) {
          res$ids <- names(sel)
        }
      }
      if (!is.null(res$ids)) {
        names(res$ids) <- res$values
      }
      res
    },
    .build_targets = function(analyses_info, sel_names, mass, mz, rt, mobility, ppm, sec, millisec) {
      pols <- analyses_info$polarity
      names(pols) <- analyses_info$analysis
      pols <- pols[sel_names]
      if (!is.null(pols)) {
        pols_chr <- as.character(pols)
        if (any(grepl("[,;/ ]", pols_chr))) {
          pol_tokens <- unique(unlist(strsplit(pols_chr, "[,;/ ]+")))
          pol_tokens <- pol_tokens[pol_tokens != ""]
          pol_tokens[pol_tokens %in% "positive"] <- "1"
          pol_tokens[pol_tokens %in% "negative"] <- "-1"
          pols <- pol_tokens
          names(pols) <- NULL
        }
      }
      MassSpecTargets(mass, mz, rt, mobility, ppm, sec, millisec, NULL, sel_names, pols)
    },
    .format_feature_rows = function(rows, analyses_info = NULL) {
      fts <- data.table::as.data.table(rows)
      if (nrow(fts) == 0) {
        return(data.table::data.table())
      }
      if ("project_id" %in% colnames(fts)) {
        fts[, project_id := NULL]
      }
      if (!is.null(analyses_info) && nrow(analyses_info) > 0) {
        rep_map <- data.table::data.table(
          analysis = analyses_info$analysis,
          replicate = analyses_info$replicate
        )
        fts <- merge(fts, rep_map, by = "analysis", all.x = TRUE)
        desired_order <- c("analysis", "replicate", "feature")
        data.table::setcolorder(fts, c(desired_order, setdiff(colnames(fts), desired_order)))
      }
      fts
    }
  ),
  public = list(
    #' @description Create an NTS domain wrapper on top of a shared Mass Spec project.
    #' @param db Path to the DuckDB project file.
    #' @param project_id Active project identifier.
    #' @param .ptr Existing native project pointer for internal use.
    #' @param .mass_spec_ptr Existing native Mass Spec pointer for internal use.
    #' @param .nts_ptr Existing native NTS pointer for internal use.
    initialize = function(db, project_id, .ptr = NULL, .mass_spec_ptr = NULL, .nts_ptr = NULL) {
      super$initialize(db = db, project_id = project_id, .ptr = .ptr, .mass_spec_ptr = .mass_spec_ptr)
      private$.nts_ptr <- if (is.null(.nts_ptr)) {
        rcpp_project_non_target_analysis_new(self$get_ptr())
      } else {
        .nts_ptr
      }
    },
    #' @description Return the native NTS pointer.
    get_nts_ptr = function() {
      private$.nts_ptr
    },
    #' @description Return project-owned NTS processing-step metadata.
    #' @return A named list of `ProcessingStep` metadata objects.
    available_processing_methods = function() {
      .project_non_target_analysis_processing_methods()
    },
#' @description Run project-owned feature detection using shared Mass Spec tables.
#' @return Logical `TRUE` when execution completes. Use `get_features()` to read persisted results.
#' @template arg-analyses
    #' @param rtWindows Data frame with `rtmin` and `rtmax` columns.
    #' @param ppmThreshold Numeric mass error threshold in ppm.
    #' @param noiseThreshold Numeric minimum intensity threshold for denoising.
    #' @param minSNR Numeric minimum signal-to-noise ratio.
    #' @param minTraces Integer minimum number of traces for a feature candidate.
    #' @param baselineWindow Numeric baseline estimation window.
    #' @param maxWidth Numeric maximum expected peak width.
    #' @param baseQuantile Numeric baseline quantile.
    #' @param debugAnalysis Optional analysis name to debug.
    #' @param debugMZ Optional m/z value to debug.
    #' @param debugSpecIdx Optional spectrum index to debug.
    find_features = function(
        analyses = NULL,
        rtWindows = data.frame(rtmin = numeric(), rtmax = numeric()),
        ppmThreshold = 15,
        noiseThreshold = 250,
        minSNR = 3,
        minTraces = 3,
        baselineWindow = 200,
        maxWidth = 100,
        baseQuantile = 0.1,
        debugAnalysis = "",
        debugMZ = 0,
        debugSpecIdx = -1) {
      selection <- private$.resolve_selected_analyses(analyses)
      sel_names <- selection$selected
      if (length(sel_names) == 0) {
        return(TRUE)
      }
      rtWindows <- data.table::as.data.table(rtWindows)
      if (!all(c("rtmin", "rtmax") %in% colnames(rtWindows))) {
        stop("rtWindows must contain 'rtmin' and 'rtmax' columns")
      }
      rcpp_project_non_target_analysis_find_features(
        private$.nts_ptr,
        sel_names,
        as.numeric(rtWindows$rtmin),
        as.numeric(rtWindows$rtmax),
        as.numeric(ppmThreshold),
        as.numeric(noiseThreshold),
        as.numeric(minSNR),
        as.integer(minTraces),
        as.numeric(baselineWindow),
        as.numeric(maxWidth),
        as.numeric(baseQuantile),
        as.character(debugAnalysis),
        as.numeric(debugMZ),
        as.integer(debugSpecIdx)
      )
    },
#' @description Load MS1 traces into shared project features and update `NTS_FEATURES`.
#' @return Logical `TRUE` when execution completes. Use `get_features()` to read persisted results.
#' @template arg-analyses
    #' @param rtWindow Numeric length-2 vector of RT offsets.
    #' @param mzWindow Numeric length-2 vector of m/z offsets.
    #' @param mzClust Numeric clustering tolerance.
    #' @param presence Numeric minimum cluster presence fraction.
    #' @param minIntensity Numeric minimum trace intensity.
    #' @param filtered Logical; include filtered features when `TRUE`.
    load_features_ms1 = function(
        analyses = NULL,
        rtWindow = c(-2, 2),
        mzWindow = c(-1, 6),
        mzClust = 0.005,
        presence = 0.8,
        minIntensity = 250,
        filtered = FALSE) {
      selection <- private$.resolve_selected_analyses(analyses)
      if (length(selection$selected) == 0) {
        return(TRUE)
      }
      rcpp_project_non_target_analysis_load_features_ms1(
        private$.nts_ptr,
        selection$selected,
        as.logical(filtered),
        as.numeric(rtWindow),
        as.numeric(mzWindow),
        as.numeric(minIntensity),
        as.numeric(mzClust),
        as.numeric(presence)
      )
    },
#' @description Load MS2 spectra into shared project features and update `NTS_FEATURES`.
#' @return Logical `TRUE` when execution completes. Use `get_features()` to read persisted results.
#' @template arg-analyses
    #' @param isolationWindow Numeric precursor isolation window.
    #' @param mzClust Numeric clustering tolerance.
    #' @param presence Numeric minimum cluster presence fraction.
    #' @param minIntensity Numeric minimum trace intensity.
    #' @param filtered Logical; include filtered features when `TRUE`.
    load_features_ms2 = function(
        analyses = NULL,
        isolationWindow = 1.3,
        mzClust = 0.005,
        presence = 0.8,
        minIntensity = 10,
        filtered = FALSE) {
      selection <- private$.resolve_selected_analyses(analyses)
      if (length(selection$selected) == 0) {
        return(TRUE)
      }
      rcpp_project_non_target_analysis_load_features_ms2(
        private$.nts_ptr,
        selection$selected,
        as.logical(filtered),
        as.numeric(minIntensity),
        as.numeric(isolationWindow),
        as.numeric(mzClust),
        as.numeric(presence)
      )
    },
#' @description Create feature components and update `NTS_FEATURES`.
#' @return Logical `TRUE` when execution completes. Use `get_features()` to read persisted results.
#' @template arg-analyses
    #' @param rtWindow Numeric length-2 vector of RT offsets.
    #' @param minCorrelation Numeric minimum EIC correlation.
    #' @param debugRT Optional debug RT.
    #' @param debugAnalysis Optional analysis name to debug.
    create_components = function(
        analyses = NULL,
        rtWindow = c(0, 0),
        minCorrelation = 0.8,
        debugRT = 0,
        debugAnalysis = "") {
      selection <- private$.resolve_selected_analyses(analyses)
      if (length(selection$selected) == 0) {
        return(TRUE)
      }
      rcpp_project_non_target_analysis_create_components(
        private$.nts_ptr,
        selection$selected,
        as.numeric(rtWindow),
        as.numeric(minCorrelation),
        as.numeric(debugRT),
        as.character(debugAnalysis)
      )
    },
#' @description Annotate feature components and update `NTS_FEATURES`.
#' @return Logical `TRUE` when execution completes. Use `get_features()` to read persisted results.
#' @template arg-analyses
    #' @param maxIsotopes Integer maximum isotope count.
    #' @param maxCharge Integer maximum charge state.
    #' @param maxGaps Integer maximum isotope gaps.
    #' @param ppm Numeric mass tolerance in ppm.
    #' @param debugComponent Optional component ID to debug.
    #' @param debugAnalysis Optional analysis name to debug.
    annotate_components = function(
        analyses = NULL,
        maxIsotopes = 5,
        maxCharge = 1,
        maxGaps = 1,
        ppm = 10,
        debugComponent = "",
        debugAnalysis = "") {
      selection <- private$.resolve_selected_analyses(analyses)
      if (length(selection$selected) == 0) {
        return(TRUE)
      }
      rcpp_project_non_target_analysis_annotate_components(
        private$.nts_ptr,
        selection$selected,
        as.integer(maxIsotopes),
        as.integer(maxCharge),
        as.integer(maxGaps),
        as.numeric(ppm),
        as.character(debugComponent),
        as.character(debugAnalysis)
      )
    },
#' @description Group features across analyses and update `NTS_FEATURES`.
#' @return Logical `TRUE` when execution completes. Use `get_features()` to read persisted results.
#' @template arg-analyses
    #' @param method Alignment method.
    #' @param rtDeviation Numeric RT tolerance.
    #' @param ppm Numeric mass tolerance in ppm.
    #' @param minSamples Integer minimum sample count.
    #' @param binSize Numeric RT bin size.
    #' @param filtered Logical; include filtered features when `TRUE`.
    #' @param debug Logical; enable native debug output.
    #' @param debugRT Optional debug RT.
    group_features = function(
        analyses = NULL,
        method = "internal_standards",
        rtDeviation = 5,
        ppm = 10,
        minSamples = 1,
        binSize = 5,
        filtered = FALSE,
        debug = FALSE,
        debugRT = 0) {
      selection <- private$.resolve_selected_analyses(analyses)
      if (length(selection$selected) == 0) {
        return(TRUE)
      }
      rcpp_project_non_target_analysis_group_features(
        private$.nts_ptr,
        selection$selected,
        as.character(method),
        as.numeric(rtDeviation),
        as.numeric(ppm),
        as.integer(minSamples),
        as.numeric(binSize),
        as.logical(filtered),
        as.logical(debug),
        as.numeric(debugRT)
      )
    },
#' @description Fill grouped feature gaps and update `NTS_FEATURES`.
#' @return Logical `TRUE` when execution completes. Use `get_features()` to read persisted results.
#' @template arg-analyses
    #' @param withinReplicate Logical; fill only within replicate when `TRUE`.
    #' @param filtered Logical; include filtered features when `TRUE`.
    #' @param rtExpand Numeric RT expansion.
    #' @param mzExpand Numeric m/z expansion.
    #' @param maxPeakWidth Numeric maximum peak width.
    #' @param minTracesIntensity Numeric minimum trace intensity.
    #' @param minNumberTraces Integer minimum number of traces.
    #' @param minIntensity Numeric minimum feature intensity.
    #' @param rtApexDeviation Numeric RT apex deviation.
    #' @param minSignalToNoiseRatio Numeric minimum S/N ratio.
    #' @param minGaussianFit Numeric minimum Gaussian fit.
    #' @param debugFG Optional feature-group ID to debug.
    fill_features = function(
        analyses = NULL,
        withinReplicate = FALSE,
        filtered = FALSE,
        rtExpand = 10,
        mzExpand = 0.01,
        maxPeakWidth = 30,
        minTracesIntensity = 1000,
        minNumberTraces = 5,
        minIntensity = 5000,
        rtApexDeviation = 5,
        minSignalToNoiseRatio = 3,
        minGaussianFit = 0.2,
        debugFG = "") {
      selection <- private$.resolve_selected_analyses(analyses)
      if (length(selection$selected) == 0) {
        return(TRUE)
      }
      rcpp_project_non_target_analysis_fill_features(
        private$.nts_ptr,
        selection$selected,
        as.logical(withinReplicate),
        as.logical(filtered),
        as.numeric(rtExpand),
        as.numeric(mzExpand),
        as.numeric(maxPeakWidth),
        as.numeric(minTracesIntensity),
        as.integer(minNumberTraces),
        as.numeric(minIntensity),
        as.numeric(rtApexDeviation),
        as.numeric(minSignalToNoiseRatio),
        as.numeric(minGaussianFit),
        as.character(debugFG)
      )
    },
#' @description Apply blank subtraction and update `NTS_FEATURES`.
#' @return Logical `TRUE` when execution completes. Use `get_features()` to read persisted results.
#' @template arg-analyses
    #' @param blankThreshold Numeric blank threshold.
    #' @param rtExpand Numeric RT expansion.
    #' @param mzExpand Numeric m/z expansion.
    blank_subtraction = function(
        analyses = NULL,
        blankThreshold = 5,
        rtExpand = 10,
        mzExpand = 0.005) {
      selection <- private$.resolve_selected_analyses(analyses)
      if (length(selection$selected) == 0) {
        return(TRUE)
      }
      rcpp_project_non_target_analysis_blank_subtraction(
        private$.nts_ptr,
        selection$selected,
        as.numeric(blankThreshold),
        as.numeric(rtExpand),
        as.numeric(mzExpand)
      )
    },
#' @description Filter shared project features and update `NTS_FEATURES`.
#' @return Logical `TRUE` when execution completes. Use `get_features()` to read persisted results.
#' @template arg-analyses
    #' @param minSN Numeric minimum signal-to-noise ratio.
    #' @param minIntensity Numeric minimum intensity.
    #' @param minArea Numeric minimum peak area.
    #' @param minWidth Numeric minimum peak width.
    #' @param maxWidth Numeric maximum peak width.
    #' @param maxPPM Numeric maximum ppm error.
    #' @param minFwhmRT Numeric minimum FWHM in RT.
    #' @param maxFwhmRT Numeric maximum FWHM in RT.
    #' @param minFwhmMZ Numeric minimum FWHM in m/z.
    #' @param maxFwhmMZ Numeric maximum FWHM in m/z.
    #' @param minGaussianA Numeric minimum Gaussian amplitude.
    #' @param minGaussianMu Numeric minimum Gaussian mean.
    #' @param maxGaussianMu Numeric maximum Gaussian mean.
    #' @param minGaussianSigma Numeric minimum Gaussian sigma.
    #' @param maxGaussianSigma Numeric maximum Gaussian sigma.
    #' @param minGaussianR2 Numeric minimum Gaussian fit.
    #' @param maxJaggedness Numeric maximum jaggedness.
    #' @param minSharpness Numeric minimum sharpness.
    #' @param minAsymmetry Numeric minimum asymmetry.
    #' @param maxAsymmetry Numeric maximum asymmetry.
    #' @param maxModality Integer maximum modality.
    #' @param minPlates Numeric minimum plates.
    #' @param onlyFilled Logical or `NA`.
    #' @param removeFilled Logical remove filled features.
    #' @param minSizeEIC Integer minimum EIC size.
    #' @param minSizeMS1 Integer minimum MS1 size.
    #' @param minSizeMS2 Integer minimum MS2 size.
    #' @param minRelPresenceReplicate Numeric minimum replicate presence.
    #' @param removeIsotopes Logical remove isotope annotations.
    #' @param removeAdducts Logical remove adduct annotations.
    #' @param removeLosses Logical remove loss annotations.
    filter_features = function(
        analyses = NULL,
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
      selection <- private$.resolve_selected_analyses(analyses)
      if (length(selection$selected) == 0) {
        return(TRUE)
      }
      rcpp_project_non_target_analysis_filter_features(
        private$.nts_ptr,
        selection$selected,
        minSN,
        minIntensity,
        minArea,
        minWidth,
        maxWidth,
        maxPPM,
        minFwhmRT,
        maxFwhmRT,
        minFwhmMZ,
        maxFwhmMZ,
        minGaussianA,
        minGaussianMu,
        maxGaussianMu,
        minGaussianSigma,
        maxGaussianSigma,
        minGaussianR2,
        maxJaggedness,
        minSharpness,
        minAsymmetry,
        maxAsymmetry,
        maxModality,
        minPlates,
        onlyFilled,
        as.logical(removeFilled),
        minSizeEIC,
        minSizeMS1,
        minSizeMS2,
        minRelPresenceReplicate,
        as.logical(removeIsotopes),
        as.logical(removeAdducts),
        as.logical(removeLosses)
      )
    },
#' @description Filter MS2 spectra stored on shared project features and update `NTS_FEATURES`.
#' @return Logical `TRUE` when execution completes. Use `get_features()` to read persisted results.
#' @template arg-analyses
    #' @param top Integer maximum number of peaks to keep.
    #' @param minIntensity Numeric minimum absolute peak intensity.
    #' @param relMinIntensity Numeric minimum relative peak intensity.
    #' @param blankClean Logical remove blank-associated MS2 peaks.
    #' @param mzClust Numeric m/z clustering tolerance.
    #' @param blankPresenceThreshold Numeric blank presence threshold.
    #' @param globalPresenceThreshold Numeric global presence threshold.
    filter_features_ms2 = function(
        analyses = NULL,
        top = 0,
        minIntensity = NA_real_,
        relMinIntensity = NA_real_,
        blankClean = FALSE,
        mzClust = 0.005,
        blankPresenceThreshold = 0.8,
        globalPresenceThreshold = 0.1) {
      selection <- private$.resolve_selected_analyses(analyses)
      if (length(selection$selected) == 0) {
        return(TRUE)
      }
      rcpp_project_non_target_analysis_filter_features_ms2(
        private$.nts_ptr,
        selection$selected,
        as.integer(top),
        as.numeric(minIntensity),
        as.numeric(relMinIntensity),
        as.logical(blankClean),
        as.numeric(mzClust),
        as.numeric(blankPresenceThreshold),
        as.numeric(globalPresenceThreshold)
      )
    },
#' @description Run project-owned suspect screening and persist into shared NTS suspect tables.
#' @return Logical `TRUE` when execution completes. Use `get_suspects()` to read persisted results.
#' @template arg-analyses
    #' @param suspects A data frame with suspect information.
    #' @param ppm Numeric mass tolerance in ppm.
    #' @param sec Numeric retention time tolerance in seconds.
    #' @param ppmMS2 Numeric MS2 fragment mass tolerance in ppm.
    #' @param mzrMS2 Numeric minimum absolute MS2 fragment tolerance.
    #' @param minCosineSimilarity Numeric minimum cosine similarity threshold.
    #' @param minSharedFragments Integer minimum number of shared fragments.
    #' @param filtered Logical; include filtered features when `TRUE`.
    suspect_screening = function(
        suspects,
        analyses = NULL,
        ppm = 5,
        sec = 10,
        ppmMS2 = 10,
        mzrMS2 = 0.008,
        minCosineSimilarity = 0.7,
        minSharedFragments = 3,
        filtered = FALSE) {
      selection <- private$.resolve_selected_analyses(analyses)
      sel_names <- selection$selected
      if (length(sel_names) == 0) {
        return(TRUE)
      }
      suspects <- data.table::as.data.table(suspects)
      rcpp_project_non_target_analysis_suspect_screening(
        private$.nts_ptr,
        suspects,
        sel_names,
        as.numeric(ppm),
        as.numeric(sec),
        as.numeric(ppmMS2),
        as.numeric(mzrMS2),
        as.numeric(minCosineSimilarity),
        as.integer(minSharedFragments),
        as.logical(filtered)
      )
    },
#' @description Run project-owned internal-standard finding and persist into shared NTS internal-standard tables.
#' @return Logical `TRUE` when execution completes. Use `get_internal_standards()` to read persisted results.
#' @template arg-analyses
    #' @param suspects A data frame with internal-standard candidate information.
    #' @param ppm Numeric mass tolerance in ppm.
    #' @param sec Numeric retention time tolerance in seconds.
    #' @param ppmMS2 Numeric MS2 fragment mass tolerance in ppm.
    #' @param mzrMS2 Numeric minimum absolute MS2 fragment tolerance.
    #' @param minCosineSimilarity Numeric minimum cosine similarity threshold.
    #' @param minSharedFragments Integer minimum number of shared fragments.
    #' @param filtered Logical; include filtered features when `TRUE`.
    find_internal_standards = function(
        suspects,
        analyses = NULL,
        ppm = 5,
        sec = 10,
        ppmMS2 = 10,
        mzrMS2 = 0.008,
        minCosineSimilarity = 0.7,
        minSharedFragments = 3,
        filtered = TRUE) {
      selection <- private$.resolve_selected_analyses(analyses)
      sel_names <- selection$selected
      if (length(sel_names) == 0) {
        return(TRUE)
      }
      suspects <- data.table::as.data.table(suspects)
      rcpp_project_non_target_analysis_find_internal_standards(
        private$.nts_ptr,
        suspects,
        sel_names,
        as.numeric(ppm),
        as.numeric(sec),
        as.numeric(ppmMS2),
        as.numeric(mzrMS2),
        as.numeric(minCosineSimilarity),
        as.integer(minSharedFragments),
        as.logical(filtered)
      )
    },
#' @description Filter shared project suspects and update `NTS_SUSPECTS`.
#' @return Logical `TRUE` when execution completes. Use `get_suspects()` to read persisted results.
#' @template arg-analyses
    #' @param names Character vector of suspect names to keep.
    #' @param minScore Numeric minimum score.
    #' @param maxErrorRT Numeric maximum RT error.
    #' @param maxErrorMass Numeric maximum mass error.
    #' @param idLevels Integer vector of allowed ID levels.
    #' @param minSharedFragments Integer minimum shared fragments.
    #' @param minCosineSimilarity Numeric minimum cosine similarity.
    filter_suspects = function(
        analyses = NULL,
        names = character(0),
        minScore = NA_real_,
        maxErrorRT = NA_real_,
        maxErrorMass = NA_real_,
        idLevels = integer(0),
        minSharedFragments = 0,
        minCosineSimilarity = NA_real_) {
      selection <- private$.resolve_selected_analyses(analyses)
      if (length(selection$selected) == 0) {
        return(TRUE)
      }
      rcpp_project_non_target_analysis_filter_suspects(
        private$.nts_ptr,
        selection$selected,
        as.character(names),
        as.numeric(minScore),
        as.numeric(maxErrorRT),
        as.numeric(maxErrorMass),
        as.integer(idLevels),
        as.integer(minSharedFragments),
        as.numeric(minCosineSimilarity)
      )
    },
#' @description Filter shared project internal standards and update `NTS_INTERNAL_STANDARDS`.
#' @return Logical `TRUE` when execution completes. Use `get_internal_standards()` to read persisted results.
#' @template arg-analyses
    #' @param names Character vector of internal-standard names to keep.
    #' @param minScore Numeric minimum score.
    #' @param maxErrorRT Numeric maximum RT error.
    #' @param maxErrorMass Numeric maximum mass error.
    #' @param idLevels Integer vector of allowed ID levels.
    #' @param minSharedFragments Integer minimum shared fragments.
    #' @param minCosineSimilarity Numeric minimum cosine similarity.
    filter_internal_standards = function(
        analyses = NULL,
        names = character(0),
        minScore = NA_real_,
        maxErrorRT = NA_real_,
        maxErrorMass = NA_real_,
        idLevels = integer(0),
        minSharedFragments = 0,
        minCosineSimilarity = NA_real_) {
      selection <- private$.resolve_selected_analyses(analyses)
      if (length(selection$selected) == 0) {
        return(TRUE)
      }
      rcpp_project_non_target_analysis_filter_internal_standards(
        private$.nts_ptr,
        selection$selected,
        as.character(names),
        as.numeric(minScore),
        as.numeric(maxErrorRT),
        as.numeric(maxErrorMass),
        as.integer(idLevels),
        as.integer(minSharedFragments),
        as.numeric(minCosineSimilarity)
      )
    },
#' @description Run project-owned MetFrag screening and update `NTS_SUSPECTS`.
#' @return Logical `TRUE` when execution completes. Use `get_suspects()` to read persisted results.
#' @template arg-analyses
    #' @param metfrag_path Path to the MetFrag executable or jar wrapper.
    #' @param database_type Database type string.
    #' @param database_path Optional MetFrag database path.
    #' @param ppm Numeric precursor mass tolerance in ppm.
    #' @param sec Numeric retention time tolerance in seconds.
    #' @param ppmMS2 Numeric MS2 tolerance in ppm.
    #' @param mzrMS2 Numeric absolute MS2 tolerance.
    #' @param top_n Integer number of candidates per feature.
    #' @param filtered Logical; include filtered features when `TRUE`.
    #' @param java_path Path to the Java executable.
    #' @param run_dir Optional MetFrag run directory.
    #' @param debug Logical debug flag.
    #' @param extra_params Named list of extra MetFrag parameters.
    metfrag_screening = function(
        metfrag_path,
        analyses = NULL,
        database_type = "LocalCSV",
        database_path = "",
        ppm = 5,
        sec = 10,
        ppmMS2 = 10,
        mzrMS2 = 0.008,
        top_n = 1,
        filtered = FALSE,
        java_path = "java",
        run_dir = "",
        debug = FALSE,
        extra_params = list()) {
      selection <- private$.resolve_selected_analyses(analyses)
      if (length(selection$selected) == 0) {
        return(TRUE)
      }
      rcpp_project_non_target_analysis_metfrag_screening(
        private$.nts_ptr,
        as.character(metfrag_path),
        selection$selected,
        as.character(database_type),
        as.character(database_path),
        as.numeric(ppm),
        as.numeric(sec),
        as.numeric(ppmMS2),
        as.numeric(mzrMS2),
        as.integer(top_n),
        as.logical(filtered),
        as.character(java_path),
        as.character(run_dir),
        as.logical(debug),
        extra_params
      )
    },
#' @description Assign transformation products and update `NTS_TRANSFORMATION_PRODUCTS`.
#' @return Logical `TRUE` when execution completes. Use `get_transformation_products()` to read persisted results.
#' @param transformation_products A data frame with transformation-product definitions.
    #' @param chromatographic_phase Chromatographic phase for RT plausibility.
    #' @param mzrMS2 Numeric absolute MS2 tolerance.
    assign_transformation_products = function(
        transformation_products,
        chromatographic_phase = c("reverse_phase", "hilic"),
        mzrMS2 = 0.008) {
      chromatographic_phase <- match.arg(chromatographic_phase)
      transformation_products <- data.table::as.data.table(transformation_products)
      rcpp_project_non_target_analysis_assign_transformation_products(
        private$.nts_ptr,
        transformation_products,
        as.character(chromatographic_phase),
        as.numeric(mzrMS2)
      )
    },
    #' @description Return shared `NTS_SUSPECTS` rows for selected analyses.
    #' @template arg-analyses
    #' @template arg-ms-features
    #' @template arg-ms-groups
    #' @template arg-ms-mass
    #' @template arg-ms-mz
    #' @template arg-ms-rt
    #' @template arg-ms-mobility
    #' @template arg-ms-ppm
    #' @template arg-ms-sec
    #' @template arg-ms-millisec
    get_suspects = function(
        analyses = NULL,
        features = NULL,
        groups = NULL,
        mass = NULL,
        mz = NULL,
        rt = NULL,
        mobility = NULL,
        ppm = 20,
        sec = 60,
        millisec = 5) {
      selection <- private$.resolve_selected_analyses(analyses)
      analyses_info <- selection$info
      sel_names <- selection$selected
      if (length(sel_names) == 0) {
        return(data.table::data.table())
      }
      targets <- private$.build_targets(analyses_info, sel_names, mass, mz, rt, mobility, ppm, sec, millisec)
      suspects <- data.table::as.data.table(
        rcpp_project_non_target_analysis_get_suspects(
          private$.nts_ptr,
          sel_names,
          features,
          groups,
          targets,
          ppm,
          sec,
          millisec
        )
      )
      if (nrow(suspects) == 0) {
        return(data.table::data.table())
      }
      if ("project_id" %in% colnames(suspects)) {
        suspects[, project_id := NULL]
      }
      rep_map <- data.table::data.table(
        analysis = analyses_info$analysis,
        replicate = analyses_info$replicate
      )
      suspects <- merge(suspects, rep_map, by = "analysis", all.x = TRUE)
      feature_map <- self$get_features(analyses = sel_names, filtered = TRUE)[
        , .(analysis, feature, feature_group)
      ]
      if (nrow(feature_map) > 0) {
        suspects <- merge(suspects, feature_map, by = c("analysis", "feature"), all.x = TRUE)
      } else {
        suspects[, feature_group := NA_character_]
      }
      desired_order <- c("analysis", "replicate", "feature", "feature_group")
      data.table::setcolorder(suspects, c(intersect(desired_order, colnames(suspects)), setdiff(colnames(suspects), desired_order)))
      suspects
    },
    #' @description Return shared `NTS_INTERNAL_STANDARDS` rows for selected analyses.
    #' @template arg-analyses
    #' @template arg-ms-features
    #' @template arg-ms-groups
    #' @template arg-ms-mass
    #' @template arg-ms-mz
    #' @template arg-ms-rt
    #' @template arg-ms-mobility
    #' @template arg-ms-ppm
    #' @template arg-ms-sec
    #' @template arg-ms-millisec
    get_internal_standards = function(
        analyses = NULL,
        features = NULL,
        groups = NULL,
        mass = NULL,
        mz = NULL,
        rt = NULL,
        mobility = NULL,
        ppm = 20,
        sec = 60,
        millisec = 5) {
      selection <- private$.resolve_selected_analyses(analyses)
      analyses_info <- selection$info
      sel_names <- selection$selected
      if (length(sel_names) == 0) {
        return(data.table::data.table())
      }
      targets <- private$.build_targets(analyses_info, sel_names, mass, mz, rt, mobility, ppm, sec, millisec)
      internal_standards <- data.table::as.data.table(
        rcpp_project_non_target_analysis_get_internal_standards(
          private$.nts_ptr,
          sel_names,
          features,
          groups,
          targets,
          ppm,
          sec,
          millisec
        )
      )
      if (nrow(internal_standards) == 0) {
        return(data.table::data.table())
      }
      if ("project_id" %in% colnames(internal_standards)) {
        internal_standards[, project_id := NULL]
      }
      rep_map <- data.table::data.table(
        analysis = analyses_info$analysis,
        replicate = analyses_info$replicate
      )
      internal_standards <- merge(internal_standards, rep_map, by = "analysis", all.x = TRUE)
      feature_map <- self$get_features(analyses = sel_names, filtered = TRUE)[
        , .(analysis, feature, feature_group, feature_component, adduct)
      ]
      if (nrow(feature_map) > 0) {
        internal_standards <- merge(internal_standards, feature_map, by = c("analysis", "feature"), all.x = TRUE)
      } else {
        internal_standards[, `:=`(feature_group = NA_character_, feature_component = NA_character_, adduct = NA_character_)]
      }
      col_order <- c("analysis", "replicate", "feature", "feature_group", "feature_component", "adduct", "polarity")
      data.table::setcolorder(internal_standards, c(intersect(col_order, colnames(internal_standards)), setdiff(colnames(internal_standards), col_order)))
      internal_standards
    },
    #' @description Return shared `NTS_TRANSFORMATION_PRODUCTS` rows.
    #' @param parents Optional parent names to keep.
    #' @param groups Optional feature-group IDs used to expand a connected network selection.
    get_transformation_products = function(parents = NULL, groups = NULL) {
      tps <- data.table::as.data.table(
        rcpp_project_non_target_analysis_get_transformation_products(private$.nts_ptr)
      )
      if (nrow(tps) == 0) {
        return(data.table::data.table())
      }
      if ("project_id" %in% colnames(tps)) {
        tps[, project_id := NULL]
      }
      if (!is.null(groups)) {
        groups <- trimws(groups)
        groups <- groups[groups != ""]
        if (length(groups) > 0) {
          match_group <- function(x) {
            if (is.na(x) || !nzchar(x)) return(FALSE)
            trimws(as.character(x)) %in% groups
          }
          seed_rows <- tps[
            vapply(feature_group, match_group, logical(1)) |
              vapply(precursor_feature_group, match_group, logical(1)) |
              vapply(main_precursor_feature_group, match_group, logical(1))
          ]
          if (nrow(seed_rows) > 0) {
            nodes <- unique(c(seed_rows$SMILES, seed_rows$precursor_SMILES, seed_rows$main_precursor_SMILES))
            nodes <- nodes[!is.na(nodes) & nodes != ""]
            repeat {
              sel <- tps[SMILES %in% nodes | precursor_SMILES %in% nodes | main_precursor_SMILES %in% nodes]
              group_keep <- vapply(sel$feature_group, match_group, logical(1)) |
                vapply(sel$precursor_feature_group, match_group, logical(1)) |
                vapply(sel$main_precursor_feature_group, match_group, logical(1))
              empty_keep <- (is.na(sel$feature_group) | sel$feature_group == "") &
                (is.na(sel$precursor_feature_group) | sel$precursor_feature_group == "") &
                (is.na(sel$main_precursor_feature_group) | sel$main_precursor_feature_group == "")
              sel <- sel[group_keep | empty_keep]
              new_nodes <- unique(c(sel$SMILES, sel$precursor_SMILES, sel$main_precursor_SMILES))
              new_nodes <- new_nodes[!is.na(new_nodes) & new_nodes != ""]
              if (setequal(nodes, new_nodes)) break
              nodes <- new_nodes
            }
            tps <- tps[SMILES %in% nodes | precursor_SMILES %in% nodes | main_precursor_SMILES %in% nodes]
          } else {
            tps <- tps[0]
          }
        }
      }
      if (is.null(parents)) {
        return(tps)
      }
      if (!"precursor_name" %in% colnames(tps)) {
        return(data.table::data.table())
      }
      tps[precursor_name %in% parents | name %in% parents]
    },
    #' @description Return shared `NTS_FEATURES` rows for selected analyses.
    #' @template arg-analyses
    #' @template arg-ms-features
    #' @template arg-ms-groups
    #' @template arg-ms-components
    #' @template arg-ms-mass
    #' @template arg-ms-mz
    #' @template arg-ms-rt
    #' @template arg-ms-mobility
    #' @template arg-ms-ppm
    #' @template arg-ms-sec
    #' @template arg-ms-millisec
    #' @template arg-ms-filtered
    get_features = function(
        analyses = NULL,
        features = NULL,
        groups = NULL,
        components = NULL,
        mass = NULL,
        mz = NULL,
        rt = NULL,
        mobility = NULL,
        ppm = 20,
        sec = 60,
        millisec = 5,
        filtered = FALSE) {
      feat_sel <- private$.parse_selection(features, "feature")
      grp_sel <- private$.parse_selection(groups, "feature_group", c("group"))
      comp_sel <- private$.parse_selection(components, "feature_component", c("component"))
      selection <- private$.resolve_selected_analyses(unique(c(analyses, feat_sel$analyses, grp_sel$analyses, comp_sel$analyses)))
      analyses_info <- selection$info
      sel_names <- selection$selected
      if (length(sel_names) == 0) {
        return(data.table::data.table())
      }
      fts <- private$.format_feature_rows(
        rcpp_project_non_target_analysis_get_features(private$.nts_ptr, sel_names, filtered)
      , analyses_info = analyses_info)
      if (nrow(fts) == 0) {
        return(fts)
      }
      if (!is.null(feat_sel$values)) {
        fts <- fts[feature %in% feat_sel$values]
      }
      if (!is.null(grp_sel$values)) {
        fts <- fts[feature_group %in% grp_sel$values]
      }
      if (!is.null(comp_sel$values)) {
        fts <- fts[feature_component %in% comp_sel$values]
      }
      if (!is.null(mass) || !is.null(mz) || !is.null(rt) || !is.null(mobility)) {
        targets <- private$.build_targets(analyses_info, sel_names, mass, mz, rt, mobility, ppm, sec, millisec)
        if (nrow(targets) > 0) {
          keep_idx <- rep(FALSE, nrow(fts))
          for (i in seq_len(nrow(targets))) {
            tgt <- targets[i, ]
            match_idx <- fts$analysis %in% tgt$analysis
            if ("polarity" %in% colnames(fts)) {
              match_idx <- match_idx & fts$polarity %in% tgt$polarity
            }
            if ((tgt$mzmin > 0 || tgt$mzmax > 0)) {
              match_idx <- match_idx & fts$mz >= tgt$mzmin & fts$mz <= tgt$mzmax
            }
            if ((tgt$rtmin > 0 || tgt$rtmax > 0)) {
              match_idx <- match_idx & fts$rt >= tgt$rtmin & fts$rt <= tgt$rtmax
            }
            keep_idx <- keep_idx | match_idx
            if (!is.na(tgt$id) && tgt$id != "") {
              fts$name[match_idx] <- tgt$id
            }
          }
          fts <- fts[keep_idx]
        } else {
          fts <- fts[0]
        }
      }
      if (!is.null(feat_sel$ids)) fts$name <- feat_sel$ids[fts$feature]
      if (!is.null(grp_sel$ids)) fts$name <- grp_sel$ids[fts$feature_group]
      if (!is.null(comp_sel$ids)) fts$name <- comp_sel$ids[fts$feature_component]
      fts
    },
    #' @description Return feature-group profiles across analyses.
    #' @template arg-analyses
    #' @template arg-ms-groups
    #' @template arg-ms-mass
    #' @template arg-ms-mz
    #' @template arg-ms-rt
    #' @template arg-ms-mobility
    #' @template arg-ms-ppm
    #' @template arg-ms-sec
    #' @template arg-ms-millisec
    #' @template arg-ms-filtered
    get_features_profile = function(
        analyses = NULL,
        groups = NULL,
        mass = NULL,
        mz = NULL,
        rt = NULL,
        mobility = NULL,
        ppm = 20,
        sec = 60,
        millisec = 5,
        filtered = FALSE) {
      fts <- self$get_features(
        analyses = analyses,
        groups = groups,
        mass = mass,
        mz = mz,
        rt = rt,
        mobility = mobility,
        ppm = ppm,
        sec = sec,
        millisec = millisec,
        filtered = filtered
      )
      if (nrow(fts) == 0) {
        return(data.table::data.table())
      }
      if (!is.null(groups)) {
        group_values <- if (is.data.frame(groups)) {
          col_name <- intersect(c("feature_group", "group"), colnames(groups))[1]
          if (is.na(col_name)) stop("Selection for 'groups' must include 'feature_group' or 'group'")
          groups[[col_name]]
        } else {
          groups
        }
        fts <- fts[feature_group %in% group_values]
      }
      if (nrow(fts) == 0) {
        return(data.table::data.table())
      }
      if (!"feature_group" %in% colnames(fts)) {
        warning("Feature groups not found!")
        return(data.table::data.table())
      }
      fts <- fts[!is.na(feature_group) & feature_group != ""]
      if (nrow(fts) == 0) {
        return(data.table::data.table())
      }
      prof <- fts[, .(intensity = max(intensity, na.rm = TRUE)), by = c("feature_group", "analysis")]
      prof$intensity[is.na(prof$intensity) | is.infinite(prof$intensity)] <- 0
      if ("replicate" %in% colnames(fts)) {
        rep_map <- unique(fts[, .(analysis, replicate)])
        prof <- merge(prof, rep_map, by = "analysis", all.x = TRUE)
      }
      desired_order <- c("analysis", "replicate", "feature_group", "intensity")
      desired_order <- desired_order[desired_order %in% colnames(prof)]
      data.table::setcolorder(prof, c(desired_order, setdiff(colnames(prof), desired_order)))
      prof
    },
    #' @description Return a per-analysis summary of shared `NTS_FEATURES` rows.
    #' @template arg-analyses
    get_features_count = function(analyses = NULL, filtered = FALSE) {
      analyses_info <- data.table::as.data.table(self$list_analyses())
      all_names <- analyses_info$analysis
      sel_names <- .resolve_analyses_selection(analyses, all_names)
      if (length(sel_names) == 0) {
        return(data.table::data.table())
      }
      counts <- data.table::as.data.table(
        rcpp_project_non_target_analysis_get_features_count(private$.nts_ptr, sel_names, filtered)
      )
      info <- data.table::data.table(
        analysis = sel_names,
        replicate = analyses_info$replicate[match(sel_names, analyses_info$analysis)]
      )
      if (nrow(counts) == 0) {
        info$features <- 0
        info$filtered <- 0
        info$components <- 0
        info$groups <- 0
        return(info)
      }
      counts$total[is.na(counts$total)] <- 0
      counts$filtered[is.na(counts$filtered)] <- 0
      info$features <- counts$total[match(info$analysis, counts$analysis)]
      info$filtered <- counts$filtered[match(info$analysis, counts$analysis)]
      info$features[is.na(info$features)] <- 0
      info$filtered[is.na(info$filtered)] <- 0
      info$groups <- counts$groups[match(info$analysis, counts$analysis)]
      info$components <- counts$components[match(info$analysis, counts$analysis)]
      info$groups[is.na(info$groups)] <- 0
      info$components[is.na(info$components)] <- 0
      info
    },
    #' @description Return a compact per-analysis feature summary.
    info = function() {
      analyses_info <- data.table::as.data.table(self$list_analyses())
      if (nrow(analyses_info) == 0) {
        return(data.table::data.table())
      }
      counts <- self$get_features_count(filtered = FALSE)
      data.table::data.table(
        analysis = analyses_info$analysis,
        replicate = analyses_info$replicate,
        blank = analyses_info$blank,
        polarity = analyses_info$polarity,
        features = counts$features[match(analyses_info$analysis, counts$analysis)],
        filtered = counts$filtered[match(analyses_info$analysis, counts$analysis)],
        feature_groups = counts$groups[match(analyses_info$analysis, counts$analysis)]
      )
    },
    #' @description Plot the number of features for selected analyses.
    #' @template arg-analyses
    #' @template arg-ms-filtered
    #' @template arg-yLab
    #' @template arg-title
    #' @template arg-plot-groupBy
    #' @template arg-showLegend
    #' @template arg-showHoverText
    plot_features_count = function(
        analyses = NULL,
        filtered = FALSE,
        yLab = NULL,
        title = NULL,
        groupBy = "analysis",
        showLegend = TRUE,
        showHoverText = TRUE) {
      info <- self$get_features_count(analyses = analyses, filtered = filtered)
      if (nrow(info) == 0) {
        return(NULL)
      }
      allowed_group_by <- c("analysis", "replicate")
      if (!is.character(groupBy) || length(groupBy) != 1 || !(groupBy %in% allowed_group_by)) {
        stop("groupBy must be one of: ", paste(allowed_group_by, collapse = ", "))
      }
      analyses_info <- data.table::as.data.table(self$list_analyses())
      analyses_info$analysis <- as.character(analyses_info$analysis)
      analyses_info$replicate <- as.character(analyses_info$replicate)
      sel_names <- .resolve_analyses_selection(analyses, analyses_info$analysis)
      analyses_info <- analyses_info[analysis %in% sel_names, .(analysis, replicate)]
      if (groupBy == "replicate") {
        info$analysis <- info$replicate
      }
      info <- info[, .(
        features = round(mean(features), digits = 0),
        features_sd = round(stats::sd(features), digits = 0),
        n_analysis = length(features)
      ), by = c("analysis")]
      info$features_sd[is.na(info$features_sd)] <- 0
      info <- unique(info)
      info$hover_text <- if (showHoverText) {
        paste(
          info$analysis,
          "<br>",
          "N.: ",
          info$n_analysis,
          "<br>",
          "Features: ",
          info$features,
          " (SD: ",
          info$features_sd,
          ")"
        )
      } else {
        ""
      }
      info <- info[order(info$analysis), ]
      colors_tag <- .get_colors(info$analysis)
      if (is.null(yLab)) {
        yLab <- "Number of features"
      }
      plotly::plot_ly(
        x = info$analysis,
        y = info$features,
        marker = list(color = unname(colors_tag)),
        type = "bar",
        text = info$hover_text,
        hoverinfo = "text",
        error_y = list(
          type = "data",
          array = info$features_sd,
          color = "darkred",
          symmetric = FALSE,
          visible = TRUE
        ),
        name = names(colors_tag),
        showlegend = showLegend
      ) %>%
        plotly::layout(
          title = title,
          xaxis = list(title = NULL, tickfont = list(size = 14)),
          yaxis = list(
            title = yLab,
            tickfont = list(size = 14),
            titlefont = list(size = 18)
          )
        )
    },
    #' @description Plot feature-group profiles across analyses or replicates.
    #' @template arg-analyses
    #' @template arg-ms-groups
    #' @template arg-ms-mass
    #' @template arg-ms-mz
    #' @template arg-ms-rt
    #' @template arg-ms-mobility
    #' @template arg-ms-ppm
    #' @template arg-ms-sec
    #' @template arg-ms-millisec
    #' @template arg-ms-filtered
    #' @template arg-plot-groupBy
    #' @template arg-normalized
    #' @template arg-yLab
    #' @template arg-title
    #' @template arg-interactive
    #' @template arg-showLegend
    plot_features_profile = function(
        analyses = NULL,
        groups = NULL,
        mass = NULL,
        mz = NULL,
        rt = NULL,
        mobility = NULL,
        ppm = 20,
        sec = 60,
        millisec = 5,
        filtered = FALSE,
        groupBy = "analysis",
        normalized = FALSE,
        yLab = NULL,
        title = NULL,
        interactive = TRUE,
        showLegend = TRUE) {
      prof <- self$get_features_profile(
        analyses = analyses,
        groups = groups,
        mass = mass,
        mz = mz,
        rt = rt,
        mobility = mobility,
        ppm = ppm,
        sec = sec,
        millisec = millisec,
        filtered = filtered
      )

      if (nrow(prof) == 0) {
        return(NULL)
      }

      allowed_group_by <- c("analysis", "replicate")
      if (!is.character(groupBy) || length(groupBy) != 1 || !(groupBy %in% allowed_group_by)) {
        stop("groupBy must be one of: ", paste(allowed_group_by, collapse = ", "))
      }

      analyses_info <- data.table::as.data.table(self$list_analyses())
      analysis_in_prof <- unique(as.character(prof$analysis))
      analysis_order <- analyses_info$analysis[analyses_info$analysis %in% analysis_in_prof]
      missing_analyses <- setdiff(analysis_in_prof, analysis_order)
      if (length(missing_analyses) > 0) {
        analysis_order <- c(analysis_order, missing_analyses)
      }

      replicate_order <- unique(analyses_info$replicate[analyses_info$analysis %in% analysis_order])
      replicate_order <- as.character(replicate_order[!is.na(replicate_order)])
      if ("replicate" %in% colnames(prof)) {
        replicate_in_prof <- unique(as.character(prof$replicate))
        missing_replicates <- setdiff(replicate_in_prof, replicate_order)
        if (length(missing_replicates) > 0) {
          replicate_order <- c(replicate_order, missing_replicates)
        }
      }

      if (normalized) {
        prof[, intensity := {
          max_int <- max(intensity, na.rm = TRUE)
          if (!is.finite(max_int) || max_int == 0) 0 else intensity / max_int
        }, by = feature_group]
      }

      if (groupBy == "replicate") {
        if (!"replicate" %in% colnames(prof)) {
          warning("Replicate information not available for feature profiles.")
          return(NULL)
        }
        prof <- prof[, .(
          intensity = mean(intensity, na.rm = TRUE),
          analysis_sd = stats::sd(intensity, na.rm = TRUE)
        ), by = c("feature_group", "replicate")]
        prof$analysis_sd[is.na(prof$analysis_sd)] <- 0
      }

      x_col <- if (groupBy == "replicate") "replicate" else "analysis"
      prof$feature_group <- as.character(prof$feature_group)

      if (groupBy == "replicate") {
        ord <- replicate_order[replicate_order %in% as.character(prof$replicate)]
        if (length(ord) == 0) ord <- unique(as.character(prof$replicate))
        prof$replicate <- factor(as.character(prof$replicate), levels = ord)
      } else {
        ord <- analysis_order[analysis_order %in% as.character(prof$analysis)]
        if (length(ord) == 0) ord <- unique(as.character(prof$analysis))
        prof$analysis <- factor(as.character(prof$analysis), levels = ord)
      }
      data.table::setorderv(prof, c("feature_group", x_col))

      if (is.null(yLab)) {
        yLab <- if (normalized) "Relative intensity" else "Intensity"
      }
      xLab <- if (groupBy == "replicate") "Replicate" else "Analysis"

      if (!interactive) {
        plot <- ggplot2::ggplot(
          prof,
          ggplot2::aes(x = .data[[x_col]], y = intensity, group = feature_group, color = feature_group)
        ) +
          ggplot2::geom_line() +
          ggplot2::geom_point()
        if (groupBy == "replicate") {
          plot <- plot +
            ggplot2::geom_errorbar(
              ggplot2::aes(ymin = intensity - analysis_sd, ymax = intensity + analysis_sd),
              width = 0.2,
              alpha = 0.6
            )
        }
        plot <- plot +
          ggplot2::theme_classic() +
          ggplot2::labs(x = xLab, y = yLab, title = title, color = "feature_group")
        return(plot)
      }

      colors_tag <- .get_colors(unique(prof$feature_group))
      hover_text <- paste0(
        "group: ", prof$feature_group,
        "<br>", xLab, ": ", as.character(prof[[x_col]]),
        "<br>intensity: ", round(prof$intensity, 3)
      )

      error_y <- NULL
      if (groupBy == "replicate") {
        error_y <- list(type = "data", array = prof$analysis_sd, visible = TRUE)
      }

      plotly::plot_ly(
        data = prof,
        x = as.character(prof[[x_col]]),
        y = ~intensity,
        type = "scattergl",
        mode = "lines+markers",
        color = ~feature_group,
        colors = colors_tag,
        text = hover_text,
        hoverinfo = "text",
        error_y = error_y,
        showlegend = showLegend
      ) %>%
        plotly::layout(
          title = title,
          xaxis = list(
            title = NULL,
            tickfont = list(size = 12),
            type = "category",
            categoryorder = "array",
            categoryarray = as.list(ord)
          ),
          yaxis = list(title = yLab, tickfont = list(size = 12)),
          legend = list(title = list(text = "feature_group"))
        )
    },
    #' @description Plot EIC traces for selected features.
    #' @template arg-analyses
    #' @template arg-ms-features
    #' @template arg-ms-groups
    #' @template arg-ms-components
    #' @template arg-ms-mass
    #' @template arg-ms-mz
    #' @template arg-ms-rt
    #' @template arg-ms-mobility
    #' @template arg-ms-ppm
    #' @template arg-ms-sec
    #' @template arg-ms-millisec
    #' @template arg-ms-filtered
    #' @template arg-labs
    #' @template arg-plot-groupBy
    #' @template arg-interactive
    #' @param showDetails Logical, show hover details in interactive plots.
    plot_features = function(
        analyses = NULL,
        features = NULL,
        groups = NULL,
        components = NULL,
        mass = NULL,
        mz = NULL,
        rt = NULL,
        mobility = NULL,
        ppm = 20,
        sec = 60,
        millisec = 5,
        filtered = FALSE,
        xLab = NULL,
        yLab = NULL,
        title = NULL,
        groupBy = "feature",
        interactive = TRUE,
        showDetails = FALSE) {
      fts <- self$get_features(
        analyses = analyses,
        features = features,
        groups = groups,
        components = components,
        mass = mass,
        mz = mz,
        rt = rt,
        mobility = mobility,
        ppm = ppm,
        sec = sec,
        millisec = millisec,
        filtered = filtered
      )

      if (nrow(fts) == 0) {
        message("\u2717 Features not found for the targets!")
        return(NULL)
      }

      eic_list <- list()
      for (i in seq_len(nrow(fts))) {
        ft <- fts[i, ]
        sel <- !is.na(ft$eic_rt) && !is.na(ft$eic_intensity)
        sel <- sel && nchar(ft$eic_rt) > 0 && nchar(ft$eic_intensity) > 0
        if (sel) {
          rt_decoded <- rcpp_streamcraft_decode_string(ft$eic_rt)
          intensity_decoded <- rcpp_streamcraft_decode_string(ft$eic_intensity)
          baseline_decoded <- NULL
          if (!is.na(ft$eic_baseline) && nchar(ft$eic_baseline) > 0) {
            baseline_decoded <- rcpp_streamcraft_decode_string(ft$eic_baseline)
          }
          sel2 <- length(rt_decoded) > 0 && length(intensity_decoded) > 0
          sel2 <- sel2 && length(rt_decoded) == length(intensity_decoded)
          if (sel2) {
            ord <- order(rt_decoded)
            rt_decoded <- rt_decoded[ord]
            intensity_decoded <- intensity_decoded[ord]
            if (!is.null(baseline_decoded) && length(baseline_decoded) == length(rt_decoded)) {
              baseline_decoded <- baseline_decoded[ord]
            }
            eic_data <- data.table::data.table(
              analysis = ft$analysis,
              feature = ft$feature,
              rt = rt_decoded,
              intensity = intensity_decoded
            )
            if (!is.null(baseline_decoded) && length(baseline_decoded) == length(rt_decoded)) {
              eic_data$baseline <- baseline_decoded
            } else {
              eic_data$baseline <- 0
            }
            eic_list[[i]] <- eic_data
          }
        }
      }

      eic_list <- eic_list[!sapply(eic_list, is.null)]
      if (length(eic_list) == 0) {
        message("\u2717 No valid EIC data found for plotting!")
        return(NULL)
      }

      eic <- data.table::rbindlist(eic_list, fill = TRUE)
      if (!(is.character(groupBy) && length(groupBy) >= 1 && all(groupBy %in% colnames(fts)))) {
        warning("groupBy columns not found in feature data")
        return(NULL)
      }
      order_idx <- do.call(order, fts[, groupBy, with = FALSE])
      fts <- fts[order_idx]
      vals <- lapply(groupBy, function(col) as.character(fts[[col]]))
      fts$var <- do.call(paste, c(vals, sep = " - "))
      var_levels <- unique(fts$var)
      fts$var <- factor(fts$var, levels = var_levels)
      cl <- .get_colors(var_levels)
      cl50 <- paste(cl, "50", sep = "")
      names(cl50) <- names(cl)

      if (!interactive) {
        plot <- ggplot2::ggplot(eic, ggplot2::aes(x = rt))
        for (i in seq_len(nrow(fts))) {
          ft <- fts[i, ]
          ft_var <- ft$var
          temp <- eic[eic$analysis == ft$analysis & eic$feature == ft$feature, ]
          if (nrow(temp) > 0) {
            temp$var <- ft_var
            plot <- plot +
              ggplot2::geom_line(data = temp, ggplot2::aes(y = intensity, color = var))
            peak_region <- temp[temp$rt >= ft$rtmin & temp$rt <= ft$rtmax, ]
            if (nrow(peak_region) > 0) {
              plot <- plot +
                ggplot2::geom_ribbon(
                  data = peak_region,
                  ggplot2::aes(ymin = rep(0, nrow(peak_region)), ymax = intensity, fill = var),
                  alpha = 0.3
                )
            }
          }
        }
        return(
          plot +
            ggplot2::scale_color_manual(values = cl) +
            ggplot2::scale_fill_manual(values = cl50, guide = "none") +
            ggplot2::theme_classic() +
            ggplot2::labs(x = xLab, y = yLab, title = title) +
            ggplot2::labs(color = groupBy)
        )
      }

      title <- list(text = title, font = list(size = 12, color = "black"))
      xaxis <- list(linecolor = "black", title = xLab, titlefont = list(size = 12, color = "black"))
      yaxis <- list(linecolor = "black", title = yLab, titlefont = list(size = 12, color = "black"))
      make_hover_text <- function(pk_row) {
        fmt_num <- function(x, digits = 2) {
          if (is.null(x)) return(NA_real_)
          ifelse(is.na(x), NA, round(as.numeric(x), digits))
        }
        base_lines <- c(
          paste0("analysis: ", pk_row$analysis),
          paste0("feature: ", pk_row$feature),
          paste0("feature_component: ", pk_row$feature_component),
          paste0("feature_group: ", pk_row$feature_group),
          paste0("adduct: ", pk_row$adduct),
          paste0("rt: ", round(pk_row$rt, 2)),
          paste0("m/z: ", round(pk_row$mz, 4)),
          paste0("mass: ", fmt_num(pk_row$mass, 4)),
          paste0("noise: ", fmt_num(pk_row$noise, 0)),
          paste0("intensity: ", round(pk_row$intensity, 0)),
          paste0("sn: ", fmt_num(pk_row$sn, 1)),
          paste0("area: ", fmt_num(pk_row$area, 0)),
          paste0("rtmin: ", fmt_num(pk_row$rtmin, 2)),
          paste0("rtmax: ", fmt_num(pk_row$rtmax, 2)),
          paste0("width: ", fmt_num(pk_row$width, 2)),
          paste0("mzmin: ", fmt_num(pk_row$mzmin, 4)),
          paste0("mzmax: ", fmt_num(pk_row$mzmax, 4)),
          paste0("ppm: ", fmt_num(pk_row$ppm, 1)),
          paste0("fwhm_rt: ", fmt_num(pk_row$fwhm_rt, 2)),
          paste0("fwhm_mz: ", fmt_num(pk_row$fwhm_mz, 4)),
          paste0("gaussian_A: ", fmt_num(pk_row$gaussian_A, 2)),
          paste0("gaussian_mu: ", fmt_num(pk_row$gaussian_mu, 2)),
          paste0("gaussian_sigma: ", fmt_num(pk_row$gaussian_sigma, 2)),
          paste0("gaussian_r2: ", fmt_num(pk_row$gaussian_r2, 4)),
          paste0("jaggedness: ", fmt_num(pk_row$jaggedness, 4)),
          paste0("sharpness: ", fmt_num(pk_row$sharpness, 2)),
          paste0("asymmetry: ", fmt_num(pk_row$asymmetry, 2)),
          paste0("modality: ", pk_row$modality),
          paste0("plates: ", fmt_num(pk_row$plates, 0)),
          paste0("polarity: ", pk_row$polarity),
          paste0("filtered: ", pk_row$filtered),
          paste0("filter: ", pk_row$filter),
          paste0("filled: ", pk_row$filled),
          paste0("correction: ", fmt_num(pk_row$correction, 4)),
          paste0("eic_size: ", pk_row$eic_size),
          paste0("ms1_size: ", pk_row$ms1_size),
          paste0("ms2_size: ", pk_row$ms2_size)
        )
        paste(c(base_lines), collapse = "<br>")
      }
      show_legend <- rep(TRUE, length(cl))
      names(show_legend) <- names(cl)
      plot <- plot_ly()
      for (i in seq_len(nrow(fts))) {
        pk <- fts[i, ]
        ft_var <- pk$var
        hT <- if (showDetails) make_hover_text(pk) else ""
        hoverinfo_val <- if (showDetails) "text" else "skip"
        temp <- eic[eic$analysis == pk$analysis & eic$feature == pk$feature, ]
        if (nrow(temp) > 0) {
          peak_region <- temp[temp$rt >= pk$rtmin & temp$rt <= pk$rtmax, ]
          if (nrow(peak_region) > 0) {
            plot <- plot %>%
              add_trace(
                data = peak_region,
                x = ~rt,
                y = ~intensity,
                type = "scattergl",
                mode = "markers",
                marker = list(color = cl[ft_var], size = 5),
                text = if (showDetails) paste(hT, "<br>RT: ", round(peak_region$rt, 2), "<br>Intensity: ", round(peak_region$intensity, 0)) else NULL,
                hoverinfo = hoverinfo_val,
                name = ft_var,
                legendgroup = ft_var,
                showlegend = FALSE
              )
            plot <- plot %>%
              plotly::add_ribbons(
                data = peak_region,
                x = ~rt,
                ymin = ~baseline,
                ymax = ~intensity,
                line = list(color = cl[ft_var], width = 1.5),
                fillcolor = cl50[ft_var],
                text = if (showDetails) paste(hT, "<br>RT: ", round(peak_region$rt, 2), "<br>Intensity: ", round(peak_region$intensity, 0)) else NULL,
                hoverinfo = hoverinfo_val,
                name = ft_var,
                legendgroup = ft_var,
                showlegend = show_legend[ft_var]
              )
            show_legend[ft_var] <- FALSE
          }
        }
      }
      for (i in seq_len(nrow(fts))) {
        pk <- fts[i, ]
        ft_var <- pk$var
        temp <- eic[eic$analysis == pk$analysis & eic$feature == pk$feature, ]
        if (nrow(temp) > 0) {
          plot <- plot %>%
            add_trace(
              data = temp,
              x = ~rt,
              y = ~intensity,
              type = "scattergl",
              mode = "lines",
              line = list(color = cl[ft_var], width = 0.5),
              name = ft_var,
              legendgroup = ft_var,
              showlegend = FALSE,
              hoverinfo = "skip"
            )
        }
      }
      plot %>% plotly::layout(xaxis = xaxis, yaxis = yaxis, title = title)
    },
    #' @description Plot RT versus m/z traces for selected features.
    #' @template arg-analyses
    #' @template arg-ms-features
    #' @template arg-ms-groups
    #' @template arg-ms-components
    #' @template arg-ms-mass
    #' @template arg-ms-mz
    #' @template arg-ms-rt
    #' @template arg-ms-mobility
    #' @template arg-ms-ppm
    #' @template arg-ms-sec
    #' @template arg-ms-millisec
    #' @template arg-ms-filtered
    #' @template arg-labs
    #' @template arg-plot-title
    #' @template arg-plot-groupBy
    #' @template arg-interactive
    #' @param globalNormalization Logical, when TRUE normalize intensities globally across all selected features.
    #' @param showDetails Logical, show hover details in interactive plots.
    map_features = function(
        analyses = NULL,
        features = NULL,
        groups = NULL,
        components = NULL,
        mass = NULL,
        mz = NULL,
        rt = NULL,
        mobility = NULL,
        ppm = 20,
        sec = 60,
        millisec = 5,
        filtered = FALSE,
        xLab = NULL,
        yLab = NULL,
        title = NULL,
        groupBy = "feature",
        globalNormalization = FALSE,
        interactive = TRUE,
        showDetails = FALSE) {
      fts <- self$get_features(
        analyses = analyses,
        features = features,
        groups = groups,
        components = components,
        mass = mass,
        mz = mz,
        rt = rt,
        mobility = mobility,
        ppm = ppm,
        sec = sec,
        millisec = millisec,
        filtered = filtered
      )

      if (nrow(fts) == 0) {
        message("\u2717 Features not found for the targets!")
        return(NULL)
      }

      if (!(is.character(groupBy) && length(groupBy) >= 1 && all(groupBy %in% colnames(fts)))) {
        warning("groupBy columns not found in feature data")
        return(NULL)
      }
      order_idx <- do.call(order, fts[, groupBy, with = FALSE])
      fts <- fts[order_idx]
      vals <- lapply(groupBy, function(col) as.character(fts[[col]]))
      fts$var <- do.call(paste, c(vals, sep = " - "))
      var_levels <- unique(fts$var)
      fts$var <- factor(fts$var, levels = var_levels)
      cl <- .get_colors(var_levels)

      pt_list <- list()
      for (i in seq_len(nrow(fts))) {
        ft <- fts[i, ]
        has_eic <- !is.na(ft$eic_rt) && !is.na(ft$eic_mz) && !is.na(ft$eic_intensity)
        has_eic <- has_eic && nchar(ft$eic_rt) > 0 && nchar(ft$eic_mz) > 0 && nchar(ft$eic_intensity) > 0
        if (!has_eic) next
        rt_dec <- rcpp_streamcraft_decode_string(ft$eic_rt)
        mz_dec <- rcpp_streamcraft_decode_string(ft$eic_mz)
        int_dec <- rcpp_streamcraft_decode_string(ft$eic_intensity)
        if (length(rt_dec) == 0 || length(mz_dec) == 0 || length(int_dec) == 0) next
        if (!(length(rt_dec) == length(mz_dec) && length(rt_dec) == length(int_dec))) next
        ord <- order(rt_dec)
        rt_dec <- rt_dec[ord]
        mz_dec <- mz_dec[ord]
        int_dec <- int_dec[ord]
        max_int <- max(int_dec, na.rm = TRUE)
        if (!is.finite(max_int) || max_int == 0) next
        norm_int <- int_dec / max_int
        pt_list[[length(pt_list) + 1]] <- data.table::data.table(
          analysis = ft$analysis,
          replicate = ft$replicate,
          feature = ft$feature,
          feature_component = ft$feature_component,
          feature_group = ft$feature_group,
          adduct = ft$adduct,
          rt = rt_dec,
          mz = mz_dec,
          raw_intensity = int_dec,
          intensity = norm_int,
          var = ft$var
        )
      }

      pt_list <- pt_list[!sapply(pt_list, is.null)]
      if (length(pt_list) == 0) {
        message("\u2717 No valid EIC data found for mapping!")
        return(NULL)
      }

      pts <- data.table::rbindlist(pt_list, fill = TRUE)
      if (isTRUE(globalNormalization)) {
        global_max <- max(pts$raw_intensity, na.rm = TRUE)
        if (is.finite(global_max) && global_max > 0) {
          pts[, intensity := raw_intensity / global_max]
        }
      }
      size_scaled <- pts$intensity
      size_scaled[is.na(size_scaled)] <- 0
      size_scaled <- size_scaled * 8 + 2

      if (!interactive) {
        return(
          ggplot2::ggplot(pts, ggplot2::aes(x = rt, y = mz, color = var, size = intensity)) +
            ggplot2::geom_point(alpha = 0.7) +
            ggplot2::scale_color_manual(values = cl) +
            ggplot2::scale_size(range = c(2, 10), guide = "none") +
            ggplot2::theme_classic() +
            ggplot2::labs(x = xLab, y = yLab, title = title, color = groupBy)
        )
      }

      title <- list(text = title, font = list(size = 12, color = "black"))
      xaxis <- list(linecolor = "black", title = xLab, titlefont = list(size = 12, color = "black"))
      yaxis <- list(linecolor = "black", title = yLab, titlefont = list(size = 12, color = "black"))
      hover_vals <- if (showDetails) {
        paste0(
          "analysis: ", pts$analysis,
          "<br>replicate: ", pts$replicate,
          "<br>feature: ", pts$feature,
          "<br>component: ", pts$feature_component,
          "<br>group: ", pts$feature_group,
          "<br>adduct: ", pts$adduct,
          "<br>rt: ", round(pts$rt, 2),
          "<br>m/z: ", round(pts$mz, 4),
          "<br>intensity: ", round(pts$raw_intensity, 3)
        )
      } else {
        ""
      }

      plot_ly(
        data = pts,
        x = ~rt,
        y = ~mz,
        type = "scattergl",
        mode = "markers",
        color = ~var,
        colors = cl,
        marker = list(size = size_scaled, sizemode = "diameter", opacity = 0.7),
        text = hover_vals,
        hoverinfo = if (showDetails) "text" else "skip"
      ) %>%
        plotly::layout(title = title, xaxis = xaxis, yaxis = yaxis, legend = list(title = list(text = groupBy)))
    },
    #' @description Plot MS1 spectra for selected features.
    #' @template arg-analyses
    #' @template arg-ms-features
    #' @template arg-ms-groups
    #' @template arg-ms-components
    #' @template arg-ms-mass
    #' @template arg-ms-mz
    #' @template arg-ms-rt
    #' @template arg-ms-mobility
    #' @template arg-ms-ppm
    #' @template arg-ms-sec
    #' @template arg-ms-millisec
    #' @template arg-normalized
    #' @template arg-ms-filtered
    #' @template arg-plot-groupBy
    #' @param showText Logical; annotate peaks with m/z labels.
    plot_features_ms1 = function(
        analyses = NULL,
        features = NULL,
        groups = NULL,
        components = NULL,
        mass = NULL,
        mz = NULL,
        rt = NULL,
        mobility = NULL,
        ppm = 20,
        sec = 60,
        millisec = 5,
        normalized = FALSE,
        filtered = FALSE,
        xLab = NULL,
        yLab = NULL,
        title = NULL,
        groupBy = "feature",
        showText = TRUE,
        interactive = TRUE) {
      fts <- self$get_features(
        analyses = analyses,
        features = features,
        groups = groups,
        components = components,
        mass = mass,
        mz = mz,
        rt = rt,
        mobility = mobility,
        ppm = ppm,
        sec = sec,
        millisec = millisec,
        filtered = filtered
      )

      if (nrow(fts) == 0) {
        message("\u2717 MS1 traces not found for the targets!")
        return(NULL)
      }

      ms1_list <- lapply(seq_len(nrow(fts)), function(i) {
        ft <- fts[i, ]
        sel <- !is.na(ft$ms1_mz) && nchar(ft$ms1_mz) > 0 && !is.na(ft$ms1_intensity) && nchar(ft$ms1_intensity) > 0
        if (!sel) return(data.table::data.table())
        mz_dec <- rcpp_streamcraft_decode_string(ft$ms1_mz)
        int_dec <- rcpp_streamcraft_decode_string(ft$ms1_intensity)
        if (length(mz_dec) == 0 || length(mz_dec) != length(int_dec)) return(data.table::data.table())
        data.table::data.table(mz = mz_dec, intensity = int_dec, analysis = ft$analysis, feature = ft$feature)
      })

      if (normalized) {
        ms1_list <- lapply(ms1_list, function(z) {
          if (!is.null(z) && nrow(z) > 0) {
            max_int <- max(z$intensity)
            if (max_int > 0) z$intensity <- z$intensity / max_int
          }
          z
        })
      }

      ms1 <- data.table::rbindlist(ms1_list, fill = TRUE)
      if (nrow(ms1) == 0) {
        message("\u2717 MS1 traces not found for the targets!")
        return(NULL)
      }

      analyses_info <- data.table::as.data.table(self$list_analyses())
      rpl_map <- analyses_info$replicate
      names(rpl_map) <- analyses_info$analysis
      ms1$replicate <- rpl_map[ms1$analysis]
      data.table::setcolorder(ms1, c("analysis", "replicate", "feature"))

      unique_fts_id <- paste0(fts$analysis, "-", fts$feature)
      unique_ms1_id <- paste0(ms1$analysis, "-", ms1$feature)
      if ("feature_group" %in% colnames(fts)) {
        fgs <- fts$feature_group
        names(fgs) <- unique_fts_id
        ms1$feature_group <- fgs[unique_ms1_id]
      } else if ("group" %in% colnames(fts)) {
        fgs <- fts$group
        names(fgs) <- unique_fts_id
        ms1$feature_group <- fgs[unique_ms1_id]
      }
      if ("feature_component" %in% colnames(fts)) {
        fcs <- fts$feature_component
        names(fcs) <- unique_fts_id
        ms1$feature_component <- fcs[unique_ms1_id]
      } else if ("component" %in% colnames(fts)) {
        fcs <- fts$component
        names(fcs) <- unique_fts_id
        ms1$feature_component <- fcs[unique_ms1_id]
      }
      if ("name" %in% colnames(fts)) {
        tar_ids <- fts$name
        names(tar_ids) <- unique_fts_id
        ms1$name <- tar_ids[unique_ms1_id]
        data.table::setcolorder(ms1, c("analysis", "replicate", "name"))
      }

      desired_order <- c("analysis", "replicate", "feature", "feature_group", "feature_component")
      data.table::setcolorder(ms1, c(desired_order, setdiff(colnames(ms1), desired_order)))

      if (!(is.character(groupBy) && length(groupBy) >= 1 && all(groupBy %in% colnames(ms1)))) {
        warning("groupBy columns not found in MS1 data")
        return(NULL)
      }
      vals <- lapply(groupBy, function(col) as.character(ms1[[col]]))
      ms1$var <- do.call(paste, c(vals, sep = " - "))
      ms1$loop <- paste0(ms1$analysis, ms1$replicate, ms1$id, ms1$var)
      cl <- .get_colors(unique(ms1$var))
      ms1$text_string <- if (showText) paste0(round(ms1$mz, 4)) else ""

      if (!interactive) {
        if (is.null(xLab)) xLab <- expression(italic("m/z ") / " Da")
        if (is.null(yLab)) yLab <- "Intensity / counts"
        return(
          ggplot2::ggplot(ms1, ggplot2::aes(x = mz, y = intensity, group = loop)) +
            ggplot2::geom_segment(ggplot2::aes(xend = mz, yend = 0, color = var), linewidth = 1) +
            {if (showText) ggplot2::geom_text(ggplot2::aes(label = text_string), vjust = 0.2, hjust = -0.2, angle = 90, size = 2, show.legend = FALSE)} +
            ggplot2::scale_y_continuous(expand = c(0, 0), limits = c(0, max(ms1$intensity) * 1.5)) +
            ggplot2::labs(title = title, x = xLab, y = yLab) +
            ggplot2::scale_color_manual(values = cl) +
            ggplot2::theme_classic() +
            ggplot2::labs(color = groupBy)
        )
      }

      if (is.null(xLab)) xLab <- "<i>m/z</i> / Da"
      if (is.null(yLab)) yLab <- "Intensity / counts"
      ticksMin <- plyr::round_any(min(ms1$mz, na.rm = TRUE) * 0.9, 10)
      ticksMax <- plyr::round_any(max(ms1$mz, na.rm = TRUE) * 1.1, 10)
      title <- list(text = title, font = list(size = 12, color = "black"))
      xaxis <- list(linecolor = "black", title = xLab, titlefont = list(size = 12, color = "black"), range = c(ticksMin, ticksMax), dtick = round((max(ms1$mz) / 10), -1), ticks = "outside")
      yaxis <- list(linecolor = "black", title = yLab, titlefont = list(size = 12, color = "black"), range = c(0, max(ms1$intensity) * 1.5))
      plot <- plot_ly()
      seen_vars <- character(0)
      for (lp in unique(ms1$loop)) {
        seg <- ms1[ms1$loop == lp, ]
        if (nrow(seg) == 0) next
        var_val <- seg$var[1]
        show_leg <- !(var_val %in% seen_vars)
        if (show_leg) seen_vars <- c(seen_vars, var_val)
        x_seg <- as.numeric(rbind(seg$mz, seg$mz, rep(NA, nrow(seg))))
        y_seg <- as.numeric(rbind(rep(0, nrow(seg)), seg$intensity, rep(NA, nrow(seg))))
        plot <- plot %>% add_trace(x = as.vector(x_seg), y = as.vector(y_seg), type = "scattergl", mode = "lines", line = list(color = cl[var_val], width = 1), name = var_val, legendgroup = var_val, showlegend = show_leg, hoverinfo = "skip")
        if (showText) {
          plot <- plot %>% add_trace(x = seg$mz, y = seg$intensity, type = "scattergl", mode = "markers+text", marker = list(size = 2, color = cl[var_val]), text = seg$text_string, textposition = "top center", textfont = list(size = 9, color = cl[var_val]), hoverinfo = "text", name = var_val, legendgroup = var_val, showlegend = FALSE)
        }
      }
      plot %>% plotly::layout(title = title, xaxis = xaxis, yaxis = yaxis, uniformtext = list(minsize = 6, mode = "show"))
    },
    #' @description Plot MS2 spectra for selected features.
    #' @template arg-analyses
    #' @template arg-ms-features
    #' @template arg-ms-groups
    #' @template arg-ms-components
    #' @template arg-ms-mass
    #' @template arg-ms-mz
    #' @template arg-ms-rt
    #' @template arg-ms-mobility
    #' @template arg-ms-ppm
    #' @template arg-ms-sec
    #' @template arg-ms-millisec
    #' @template arg-normalized
    #' @template arg-ms-filtered
    #' @template arg-plot-groupBy
    #' @param showText Logical; annotate peaks with m/z labels.
    plot_features_ms2 = function(
        analyses = NULL,
        features = NULL,
        groups = NULL,
        components = NULL,
        mass = NULL,
        mz = NULL,
        rt = NULL,
        mobility = NULL,
        ppm = 20,
        sec = 60,
        millisec = 5,
        normalized = TRUE,
        filtered = FALSE,
        xLab = NULL,
        yLab = NULL,
        title = NULL,
        groupBy = "feature",
        showText = TRUE,
        interactive = TRUE) {
      fts <- self$get_features(
        analyses = analyses,
        features = features,
        groups = groups,
        components = components,
        mass = mass,
        mz = mz,
        rt = rt,
        mobility = mobility,
        ppm = ppm,
        sec = sec,
        millisec = millisec,
        filtered = filtered
      )

      if (nrow(fts) == 0) {
        message("\u2717 MS2 traces not found for the targets!")
        return(NULL)
      }

      ms2_list <- lapply(seq_len(nrow(fts)), function(i) {
        ft <- fts[i, ]
        sel <- !is.na(ft$ms2_mz) && nchar(ft$ms2_mz) > 0 && !is.na(ft$ms2_intensity) && nchar(ft$ms2_intensity) > 0
        if (!sel) return(data.table::data.table())
        mz_dec <- rcpp_streamcraft_decode_string(ft$ms2_mz)
        int_dec <- rcpp_streamcraft_decode_string(ft$ms2_intensity)
        if (length(mz_dec) == 0 || length(mz_dec) != length(int_dec)) return(data.table::data.table())
        data.table::data.table(mz = mz_dec, intensity = int_dec, analysis = ft$analysis, feature = ft$feature, is_pre = FALSE)
      })

      if (normalized) {
        ms2_list <- lapply(ms2_list, function(z) {
          if (!is.null(z) && nrow(z) > 0) {
            max_int <- max(z$intensity)
            if (max_int > 0) z$intensity <- z$intensity / max_int
          }
          z
        })
      }

      ms2 <- data.table::rbindlist(ms2_list, fill = TRUE)
      if (nrow(ms2) == 0) {
        message("\u2717 MS2 traces not found for the targets!")
        return(NULL)
      }

      analyses_info <- data.table::as.data.table(self$list_analyses())
      rpl_map <- analyses_info$replicate
      names(rpl_map) <- analyses_info$analysis
      ms2$replicate <- rpl_map[ms2$analysis]
      data.table::setcolorder(ms2, c("analysis", "replicate", "feature"))

      unique_fts_id <- paste0(fts$analysis, "-", fts$feature)
      unique_ms2_id <- paste0(ms2$analysis, "-", ms2$feature)
      if ("feature_group" %in% colnames(fts)) {
        fgs <- fts$feature_group
        names(fgs) <- unique_fts_id
        ms2$feature_group <- fgs[unique_ms2_id]
      } else if ("group" %in% colnames(fts)) {
        fgs <- fts$group
        names(fgs) <- unique_fts_id
        ms2$feature_group <- fgs[unique_ms2_id]
      }
      if ("feature_component" %in% colnames(fts)) {
        fcs <- fts$feature_component
        names(fcs) <- unique_fts_id
        ms2$feature_component <- fcs[unique_ms2_id]
      } else if ("component" %in% colnames(fts)) {
        fcs <- fts$component
        names(fcs) <- unique_fts_id
        ms2$feature_component <- fcs[unique_ms2_id]
      }
      if ("name" %in% colnames(fts)) {
        tar_ids <- fts$name
        names(tar_ids) <- unique_fts_id
        ms2$name <- tar_ids[unique_ms2_id]
        data.table::setcolorder(ms2, c("analysis", "replicate", "name"))
      }

      desired_order <- c("analysis", "replicate", "feature", "feature_group", "feature_component")
      data.table::setcolorder(ms2, c(desired_order, setdiff(colnames(ms2), desired_order)))

      if (!(is.character(groupBy) && length(groupBy) >= 1 && all(groupBy %in% colnames(ms2)))) {
        warning("groupBy columns not found in MS2 data")
        return(NULL)
      }
      vals <- lapply(groupBy, function(col) as.character(ms2[[col]]))
      ms2$var <- do.call(paste, c(vals, sep = " - "))
      ms2$text_string <- if (showText) paste0(round(ms2$mz, 4)) else ""
      ms2$text_string[ms2$is_pre] <- paste0("Pre ", ms2$text_string[ms2$is_pre])
      ms2$loop <- paste0(ms2$analysis, ms2$replicate, ms2$id, ms2$var)
      cl <- .get_colors(unique(ms2$var))

      if (!interactive) {
        if (is.null(xLab)) xLab <- expression(italic("m/z ") / " Da")
        if (is.null(yLab)) yLab <- "Intensity / counts"
        ms2$linesize <- 1
        ms2$linesize[ms2$is_pre] <- 2
        plot <- ggplot2::ggplot(ms2, ggplot2::aes(x = mz, y = intensity, group = loop)) +
          ggplot2::geom_segment(ggplot2::aes(xend = mz, yend = 0, color = var, linewidth = linesize))
        if (showText) {
          plot <- plot + ggplot2::geom_text(ggplot2::aes(label = text_string), vjust = 0.2, hjust = -0.2, angle = 90, size = 2, show.legend = FALSE)
        }
        return(
          plot +
            ggplot2::scale_y_continuous(expand = c(0, 0), limits = c(0, max(ms2$intensity) * 1.5)) +
            ggplot2::labs(title = title, x = xLab, y = yLab) +
            ggplot2::scale_color_manual(values = cl) +
            ggplot2::scale_linewidth_continuous(range = c(1, 2), guide = "none") +
            ggplot2::theme_classic() +
            ggplot2::labs(color = groupBy)
        )
      }

      if (is.null(xLab)) xLab <- "<i>m/z</i> / Da"
      if (is.null(yLab)) yLab <- "Intensity / counts"
      ms2$linesize <- 1
      ms2$linesize[ms2$is_pre] <- 2
      ticksMin <- plyr::round_any(min(ms2$mz, na.rm = TRUE) * 0.9, 10)
      ticksMax <- plyr::round_any(max(ms2$mz, na.rm = TRUE) * 1.1, 10)
      title <- list(text = title, font = list(size = 12, color = "black"))
      xaxis <- list(linecolor = "black", title = xLab, titlefont = list(size = 12, color = "black"), range = c(ticksMin, ticksMax), dtick = round((max(ms2$mz) / 10), -1), ticks = "outside")
      yaxis <- list(linecolor = "black", title = yLab, titlefont = list(size = 12, color = "black"), range = c(0, max(ms2$intensity) * 1.5))
      plot <- plot_ly()
      seen_vars <- character(0)
      for (lp in unique(ms2$loop)) {
        seg <- ms2[ms2$loop == lp, ]
        if (nrow(seg) == 0) next
        var_val <- seg$var[1]
        show_leg <- !(var_val %in% seen_vars)
        if (show_leg) seen_vars <- c(seen_vars, var_val)
        x_seg <- as.numeric(rbind(seg$mz, seg$mz, rep(NA, nrow(seg))))
        y_seg <- as.numeric(rbind(rep(0, nrow(seg)), seg$intensity, rep(NA, nrow(seg))))
        plot <- plot %>% add_trace(x = as.vector(x_seg), y = as.vector(y_seg), type = "scattergl", mode = "lines", line = list(color = cl[var_val], width = seg$linesize[1]), name = var_val, legendgroup = var_val, showlegend = show_leg, hoverinfo = "skip")
        if (showText) {
          plot <- plot %>% add_trace(x = seg$mz, y = seg$intensity, type = "scattergl", mode = "markers+text", marker = list(size = 2, color = cl[var_val]), text = paste0(seg$text_string, "  "), textposition = "top center", textfont = list(size = 9, color = cl[var_val]), hoverinfo = "text", name = var_val, legendgroup = var_val, showlegend = FALSE)
        }
      }
      plot %>% plotly::layout(title = title, xaxis = xaxis, yaxis = yaxis, uniformtext = list(minsize = 6, mode = "show"))
    },
    #' @description Plot suspect MS2 spectra for selected features.
    #' @template arg-analyses
    #' @template arg-ms-features
    #' @template arg-ms-groups
    #' @template arg-ms-mass
    #' @template arg-ms-mz
    #' @template arg-ms-rt
    #' @template arg-ms-mobility
    #' @template arg-ms-ppm
    #' @template arg-ms-sec
    #' @template arg-ms-millisec
    #' @template arg-normalized
    #' @template arg-ms-filtered
    #' @template arg-plot-groupBy
    #' @param showText Logical; annotate peaks with m/z or fragment labels.
    plot_suspects_ms2 = function(
        analyses = NULL,
        features = NULL,
        groups = NULL,
        mass = NULL,
        mz = NULL,
        rt = NULL,
        mobility = NULL,
        ppm = 20,
        sec = 60,
        millisec = 5,
        normalized = TRUE,
        filtered = FALSE,
        xLab = NULL,
        yLab = NULL,
        title = NULL,
        groupBy = c("feature", "name"),
        showText = TRUE,
        interactive = TRUE,
        showLegend = TRUE) {
      suspects <- self$get_suspects(
        analyses = analyses,
        features = features,
        groups = groups,
        mass = mass,
        mz = mz,
        rt = rt,
        mobility = mobility,
        ppm = ppm,
        sec = sec,
        millisec = millisec
      )

      if (nrow(suspects) == 0) {
        message("\u2717 Suspect MS2 traces not found for the targets!")
        return(NULL)
      }

      spec_list <- vector("list", nrow(suspects))
      for (i in seq_len(nrow(suspects))) {
        sp <- suspects[i, ]
        out <- list()
        if (!is.na(sp$exp_ms2_mz) && nzchar(sp$exp_ms2_mz) && !is.na(sp$exp_ms2_intensity) && nzchar(sp$exp_ms2_intensity)) {
          mz_dec <- rcpp_streamcraft_decode_string(sp$exp_ms2_mz)
          int_dec <- rcpp_streamcraft_decode_string(sp$exp_ms2_intensity)
          if (length(mz_dec) > 0 && length(mz_dec) == length(int_dec)) {
            out[[1]] <- data.table::data.table(mz = mz_dec, intensity = int_dec, analysis = sp$analysis, feature = sp$feature, name = sp$name, formula_fragment = NA_character_, source = "exp")
          }
        }
        if (!is.na(sp$db_ms2_mz) && nzchar(sp$db_ms2_mz) && !is.na(sp$db_ms2_intensity) && nzchar(sp$db_ms2_intensity)) {
          mz_dec <- rcpp_streamcraft_decode_string(sp$db_ms2_mz)
          int_dec <- rcpp_streamcraft_decode_string(sp$db_ms2_intensity)
          if (length(mz_dec) > 0 && length(mz_dec) == length(int_dec)) {
            formula_vec <- rep(NA_character_, length(mz_dec))
            if (!is.na(sp$db_ms2_formula) && nzchar(sp$db_ms2_formula)) {
              formula_split <- trimws(strsplit(sp$db_ms2_formula, ";", fixed = TRUE)[[1]])
              n_formulas <- length(formula_split)
              if (n_formulas > 0) {
                formula_vec[seq_len(min(n_formulas, length(mz_dec)))] <- formula_split[seq_len(min(n_formulas, length(mz_dec)))]
              }
            }
            out[[2]] <- data.table::data.table(mz = mz_dec, intensity = -abs(int_dec), analysis = sp$analysis, feature = sp$feature, name = sp$name, formula_fragment = formula_vec, source = "db")
          }
        }
        if (length(out) > 0) {
          spec_list[[i]] <- data.table::rbindlist(out, fill = TRUE)
        }
      }

      spec_list <- Filter(Negate(is.null), spec_list)
      suspects_ms2 <- data.table::rbindlist(spec_list, fill = TRUE)
      if (nrow(suspects_ms2) == 0) {
        message("\u2717 Suspect MS2 traces not found for the targets!")
        return(NULL)
      }
      suspects_ms2 <- suspects_ms2[is.finite(mz) & is.finite(intensity)]
      if (nrow(suspects_ms2) == 0) {
        message("\u2717 Suspect MS2 traces not found for the targets!")
        return(NULL)
      }

      if (normalized) {
        suspects_ms2[, intensity := {
          max_int <- max(abs(intensity), na.rm = TRUE)
          if (is.finite(max_int) && max_int > 0) intensity / max_int else intensity
        }, by = .(analysis, feature, name, source)]
      }

      exclude_cols <- c("db_ms2_size", "db_ms2_mz", "db_ms2_intensity", "db_ms2_formula", "exp_ms2_size", "exp_ms2_mz", "exp_ms2_intensity")
      detail_cols <- setdiff(colnames(suspects), exclude_cols)
      detail_cols <- setdiff(detail_cols, colnames(suspects_ms2))
      detail_cols <- unique(c("analysis", "feature", "name", detail_cols))
      detail_cols <- intersect(detail_cols, colnames(suspects))
      if (length(detail_cols) > 3) {
        suspects_details <- suspects[, detail_cols, with = FALSE]
        suspects_ms2 <- merge(suspects_ms2, suspects_details, by = c("analysis", "feature", "name"), all.x = TRUE)
      }

      if (!(is.character(groupBy) && length(groupBy) >= 1 && all(groupBy %in% colnames(suspects_ms2)))) {
        warning("groupBy columns not found in suspect MS2 data")
        return(NULL)
      }
      vals <- lapply(groupBy, function(col) as.character(suspects_ms2[[col]]))
      suspects_ms2$var <- do.call(paste, c(vals, sep = " - "))
      suspects_ms2$loop <- paste0(suspects_ms2$analysis, "-", suspects_ms2$feature, "-", suspects_ms2$name, "-", suspects_ms2$source, "-", suspects_ms2$var)
      cl <- .get_colors(unique(suspects_ms2$var))
      max_abs_int <- max(abs(suspects_ms2$intensity), na.rm = TRUE)
      if (!is.finite(max_abs_int) || max_abs_int == 0) max_abs_int <- 1

      if (showText) {
        suspects_ms2$text_label <- sprintf("%.4f", suspects_ms2$mz)
        formula_mask <- suspects_ms2$source == "db" & !is.na(suspects_ms2$formula_fragment) & nzchar(suspects_ms2$formula_fragment)
        suspects_ms2$text_label[formula_mask] <- paste0(suspects_ms2$text_label[formula_mask], " - ", suspects_ms2$formula_fragment[formula_mask])
      } else {
        suspects_ms2$text_label <- ""
      }

      if (!interactive) {
        if (is.null(xLab)) xLab <- expression(italic("m/z ") / " Da")
        if (is.null(yLab)) yLab <- "Intensity / counts"
        suspects_ms2$linesize <- ifelse(suspects_ms2$source == "db", 1.5, 1)
        min_mz <- min(suspects_ms2$mz, na.rm = TRUE)
        max_mz <- max(suspects_ms2$mz, na.rm = TRUE)
        x_breaks <- scales::pretty_breaks(n = 6)(c(min_mz, max_mz))
        x_breaks <- x_breaks[x_breaks >= min_mz & x_breaks <= max_mz]
        plot <- ggplot2::ggplot(suspects_ms2, ggplot2::aes(x = mz, y = intensity, group = loop, color = var)) +
          ggplot2::geom_segment(ggplot2::aes(xend = mz, yend = 0, linewidth = linesize)) +
          ggplot2::scale_linewidth_continuous(range = c(1, 2), guide = "none")
        if (showText) {
          plot <- plot + ggplot2::geom_text(ggplot2::aes(label = text_label), angle = 90, hjust = -0.2, size = 3.5, show.legend = FALSE)
        }
        return(
          plot +
            ggplot2::scale_y_continuous(expand = c(0, 0), limits = c(-max_abs_int * 1.5, max_abs_int * 1.5)) +
            ggplot2::annotate("segment", x = min_mz, xend = max_mz, y = 0, yend = 0, color = "black", linewidth = 0.3) +
            ggplot2::geom_segment(data = data.table::data.table(x = x_breaks), ggplot2::aes(x = x, xend = x, y = 0, yend = -max_abs_int * 0.04), inherit.aes = FALSE, color = "black", linewidth = 0.3) +
            ggplot2::geom_text(data = data.table::data.table(x = x_breaks), ggplot2::aes(x = x, y = -max_abs_int * 0.09, label = round(x, 2)), inherit.aes = FALSE, size = 3) +
            ggplot2::scale_color_manual(values = cl, name = paste(groupBy, collapse = " - ")) +
            ggplot2::labs(x = xLab, y = yLab, title = title) +
            ggplot2::theme_classic() +
            ggplot2::theme(
              axis.line.x = ggplot2::element_blank(),
              axis.ticks.x = ggplot2::element_blank(),
              axis.text.x = ggplot2::element_blank(),
              axis.title.x = ggplot2::element_blank(),
              legend.position = if (isTRUE(showLegend)) "right" else "none"
            )
        )
      }

      if (is.null(xLab)) xLab <- "<i>m/z</i> / Da"
      if (is.null(yLab)) yLab <- "Intensity / counts"
      ticksMin <- plyr::round_any(min(suspects_ms2$mz, na.rm = TRUE) * 0.9, 10)
      ticksMax <- plyr::round_any(max(suspects_ms2$mz, na.rm = TRUE) * 1.1, 10)
      title <- list(text = title, font = list(size = 12, color = "black"))
      xaxis <- list(linecolor = "black", title = xLab, titlefont = list(size = 12, color = "black"), range = c(ticksMin, ticksMax), dtick = round((max(suspects_ms2$mz) / 10), -1), ticks = "outside")
      yaxis <- list(linecolor = "black", title = yLab, titlefont = list(size = 12, color = "black"), range = c(-max_abs_int * 1.2, max_abs_int * 1.2))
      plot <- plot_ly()
      seen_vars <- character(0)
      for (lp in unique(suspects_ms2$loop)) {
        seg <- suspects_ms2[loop == lp]
        if (nrow(seg) == 0) next
        var_val <- seg$var[1]
        show_leg <- !(var_val %in% seen_vars)
        if (show_leg) seen_vars <- c(seen_vars, var_val)
        line_width <- if (seg$source[1] == "db") 1.5 else 1
        hover_fields <- setdiff(colnames(seg), c("mz", "intensity", "var", "loop", "text_label", "source", "formula_fragment", "InChI", "SMILES", "linesize"))
        hover_fields <- intersect(hover_fields, colnames(seg))
        hover_text <- vapply(seq_len(nrow(seg)), function(i) {
          row_vals <- as.character(seg[i, hover_fields, with = FALSE])
          row_vals[is.na(row_vals)] <- ""
          base_info <- paste0("source: ", seg$source[i], "<br>m/z: ", sprintf("%.4f", seg$mz[i]), "<br>intensity: ", sprintf("%.4f", seg$intensity[i]))
          if (seg$source[i] == "db" && !is.na(seg$formula_fragment[i]) && nzchar(seg$formula_fragment[i])) {
            base_info <- paste0(base_info, "<br>formula: ", seg$formula_fragment[i])
          }
          if (length(hover_fields) > 0) {
            detail_info <- paste(paste0(hover_fields, ": ", row_vals), collapse = "<br>")
            paste0(base_info, "<br>", detail_info)
          } else {
            base_info
          }
        }, character(1))
        x_seg <- as.numeric(rbind(seg$mz, seg$mz, rep(NA, nrow(seg))))
        y_seg <- as.numeric(rbind(rep(0, nrow(seg)), seg$intensity, rep(NA, nrow(seg))))
        text_seg <- as.vector(rbind(hover_text, hover_text, rep(NA_character_, nrow(seg))))
        plot <- plot %>% add_trace(x = x_seg, y = y_seg, type = "scattergl", mode = "lines", line = list(color = cl[var_val], width = line_width), name = var_val, legendgroup = var_val, showlegend = show_leg, hoverinfo = "text", text = text_seg)
        if (showText) {
          text_pos <- ifelse(seg$source[1] == "db", "bottom center", "top center")
          plot <- plot %>% add_trace(x = seg$mz, y = seg$intensity, type = "scattergl", mode = "text", text = seg$text_label, textposition = text_pos, textfont = list(size = 9, color = cl[var_val]), hoverinfo = "text", hovertext = hover_text, name = var_val, legendgroup = var_val, showlegend = FALSE)
        }
      }
      plot %>% plotly::layout(title = title, xaxis = xaxis, yaxis = yaxis, uniformtext = list(minsize = 6, mode = "show"), showlegend = showLegend, hoverlabel = list(align = "left"))
    },
    #' @description Return fold-change categories between replicate groups.
    #' @param replicatesIn Character vector with replicate names used as denominator.
    #' @param replicatesOut Character vector with replicate names used as numerator.
    #' @template arg-ms-groups
    #' @template arg-ms-mass
    #' @template arg-ms-mz
    #' @template arg-ms-rt
    #' @template arg-ms-mobility
    #' @template arg-ms-ppm
    #' @template arg-ms-sec
    #' @template arg-ms-millisec
    #' @template arg-ms-filtered
    #' @param constantThreshold Numeric threshold used to mark features as constant.
    #' @param eliminationThreshold Numeric threshold used to mark features as eliminated.
    #' @template arg-ms-correctIntensity
    #' @param fillZerosWithLowerLimit Logical; replace zeros before fold-change calculation.
    #' @param lowerLimit Optional lower limit used when filling zeros.
    get_fold_change = function(
        replicatesIn = NULL,
        replicatesOut = NULL,
        groups = NULL,
        mass = NULL,
        mz = NULL,
        rt = NULL,
        mobility = NULL,
        ppm = 4,
        sec = 10,
        millisec = 5,
        filtered = FALSE,
        constantThreshold = 0.5,
        eliminationThreshold = 0.2,
        correctIntensity = FALSE,
        fillZerosWithLowerLimit = FALSE,
        lowerLimit = NA_real_) {
      info_analyses <- data.table::as.data.table(self$list_analyses())
      all_names <- info_analyses$analysis
      rpls <- info_analyses$replicate

      if (is.numeric(replicatesIn)) {
        replicatesIn <- unique(rpls[replicatesIn])
      }
      if (is.numeric(replicatesOut)) {
        replicatesOut <- unique(rpls[replicatesOut])
      }

      if (any(is.na(replicatesIn)) || any(is.na(replicatesOut))) {
        message("\u2717 Replicates not found!")
        return(NULL)
      }

      if (length(replicatesIn) == 1 && length(replicatesOut) > 1) {
        replicatesIn <- rep(replicatesIn, length(replicatesOut))
      }

      fts <- self$get_features(
        analyses = NULL,
        groups = groups,
        mass = mass,
        mz = mz,
        rt = rt,
        mobility = mobility,
        ppm = ppm,
        sec = sec,
        millisec = millisec,
        filtered = filtered
      )

      if (!"feature_group" %in% colnames(fts)) {
        warning("\u2717 Feature groups not found!")
        return(NULL)
      }

      if (correctIntensity && "correction" %in% colnames(fts)) {
        fts$intensity <- fts$intensity * fts$correction
      }

      fts <- fts[!is.na(fts$feature_group) & fts$feature_group != "", ]
      if (nrow(fts) == 0) {
        message("\u2717 Feature groups not found for the targets!")
        return(NULL)
      }

      fts_av <- fts[, .(intensity = max(intensity, na.rm = TRUE)), by = c("feature_group", "analysis")]
      fts_av <- data.table::dcast(fts_av, feature_group ~ analysis, value.var = "intensity")
      fts_av[is.na(fts_av)] <- 0
      data.table::setnames(fts_av, "feature_group", "group")
      groups_dt <- fts_av

      comb <- data.table::data.table()
      for (rep in seq_len(length(replicatesOut))) {
        out_temp <- all_names[rpls %in% replicatesOut[rep]]
        in_temp <- all_names[rpls %in% replicatesIn[rep]]
        comb_temp <- expand.grid(
          analysisIn = in_temp,
          analysisOut = out_temp,
          replicateIn = replicatesIn[rep],
          replicateOut = replicatesOut[rep]
        )
        comb <- data.table::rbindlist(list(comb, comb_temp), fill = TRUE)
      }

      if (nrow(comb) == 0) {
        warning("\u2717 Combinations could not be made, check replicates IN and OUT!")
        return(NULL)
      }

      fc <- lapply(
        seq_len(nrow(comb)),
        function(z, comb, groups_dt, fillZerosWithLowerLimit) {
          anaIn <- comb$analysisIn[z]
          anaOut <- comb$analysisOut[z]

          selOut <- colnames(groups_dt) %in% as.character(anaOut)
          vecOut <- groups_dt[, selOut, with = FALSE][[1]]

          selIn <- colnames(groups_dt) %in% as.character(anaIn)
          vecIn <- groups_dt[, selIn, with = FALSE][[1]]

          if (fillZerosWithLowerLimit) {
            if (is.na(lowerLimit)) {
              vecOut[vecOut == 0] <- min(vecOut[vecOut > 0])
              vecIn[vecIn == 0] <- min(vecIn[vecIn > 0])
            } else {
              vecOut[vecOut == 0] <- lowerLimit
              vecIn[vecIn == 0] <- lowerLimit
            }
          }

          fc_vec <- as.numeric(vecOut) / as.numeric(vecIn)

          res <- data.table::data.table("group" = groups_dt$group, "fc" = fc_vec)
          res$analysis_in <- anaIn
          res$analysis_out <- anaOut
          res$replicate_in <- comb$replicateIn[z]
          res$replicate_out <- comb$replicateOut[z]
          res$combination <- z
          res
        },
        comb = comb,
        groups_dt = groups_dt,
        fillZerosWithLowerLimit = fillZerosWithLowerLimit
      )

      fc <- data.table::rbindlist(fc)
      fc <- fc[!is.nan(fc$fc), ]
      fc_category <- list(
        "Elimination" = c(0, eliminationThreshold),
        "Decrease" = c(eliminationThreshold, constantThreshold),
        "Constant" = c(constantThreshold, 1 / constantThreshold),
        "Increase" = c(1 / constantThreshold, 1 / eliminationThreshold),
        "Formation" = c(1 / eliminationThreshold, Inf)
      )
      fc_boundaries <- c(
        paste0("(", 0, "-", eliminationThreshold, ")"),
        paste0("(", eliminationThreshold, "-", constantThreshold, ")"),
        paste0("(", constantThreshold, "-", 1 / constantThreshold, ")"),
        paste0("(", 1 / constantThreshold, "-", 1 / eliminationThreshold, ")"),
        paste0("(", 1 / eliminationThreshold, "-Inf)")
      )
      names(fc_boundaries) <- names(fc_category)
      for (i in seq_along(fc_category)) {
        fc$category[fc$fc >= fc_category[[i]][1] & fc$fc <= fc_category[[i]][2]] <- names(fc_category)[i]
      }
      fc <- fc[!is.na(fc$category), ]
      fc$category <- factor(fc$category, levels = names(fc_category))
      fc$bondaries <- paste(fc$category, fc_boundaries[fc$category], sep = "\n")
      fc$bondaries <- factor(fc$bondaries, levels = paste(names(fc_category), fc_boundaries, sep = "\n"))
      fc
    },
    #' @description Plot fold-change categories between replicate groups.
    #' @param replicatesIn Character vector with replicate names used as denominator.
    #' @param replicatesOut Character vector with replicate names used as numerator.
    #' @template arg-ms-groups
    #' @template arg-ms-mass
    #' @template arg-ms-mz
    #' @template arg-ms-rt
    #' @template arg-ms-mobility
    #' @template arg-ms-ppm
    #' @template arg-ms-sec
    #' @template arg-ms-millisec
    #' @template arg-ms-filtered
    #' @param constantThreshold Numeric threshold used to mark features as constant.
    #' @param eliminationThreshold Numeric threshold used to mark features as eliminated.
    #' @template arg-ms-correctIntensity
    #' @param fillZerosWithLowerLimit Logical; replace zeros before fold-change calculation.
    #' @param lowerLimit Optional lower limit used when filling zeros.
    #' @template arg-normalized
    #' @template arg-yLab
    #' @template arg-title
    #' @template arg-interactive
    #' @template arg-showLegend
    plot_fold_change = function(
        replicatesIn = NULL,
        replicatesOut = NULL,
        groups = NULL,
        mass = NULL,
        mz = NULL,
        rt = NULL,
        mobility = NULL,
        ppm = 4,
        sec = 10,
        millisec = 5,
        filtered = FALSE,
        constantThreshold = 0.5,
        eliminationThreshold = 0.2,
        correctIntensity = FALSE,
        fillZerosWithLowerLimit = FALSE,
        lowerLimit = NA_real_,
        normalized = TRUE,
        yLab = NULL,
        title = NULL,
        interactive = TRUE,
        showLegend = TRUE) {
      fc <- self$get_fold_change(
        replicatesIn = replicatesIn,
        replicatesOut = replicatesOut,
        groups = groups,
        mass = mass,
        mz = mz,
        rt = rt,
        mobility = mobility,
        ppm = ppm,
        sec = sec,
        millisec = millisec,
        filtered = filtered,
        constantThreshold = constantThreshold,
        eliminationThreshold = eliminationThreshold,
        correctIntensity = correctIntensity,
        fillZerosWithLowerLimit = fillZerosWithLowerLimit,
        lowerLimit = lowerLimit
      )

      if (is.null(fc) || nrow(fc) == 0) {
        return(NULL)
      }

      fc_summary_count <- fc[, .(count = .N), by = c("combination", "bondaries", "replicate_out", "replicate_in")]

      info_analyses <- data.table::as.data.table(self$list_analyses())
      fts_all <- self$get_features(analyses = NULL, filtered = filtered)
      groups_counts <- data.table::data.table(
        analysis = info_analyses$analysis,
        replicate = info_analyses$replicate,
        groups = 0
      )
      if ("feature_group" %in% colnames(fts_all)) {
        fts_all <- fts_all[!is.na(fts_all$feature_group) & fts_all$feature_group != "", ]
        if (nrow(fts_all) > 0) {
          group_counts <- fts_all[, .(groups = data.table::uniqueN(feature_group)), by = analysis]
          groups_counts$groups <- group_counts$groups[match(groups_counts$analysis, group_counts$analysis)]
          groups_counts$groups[is.na(groups_counts$groups)] <- 0
        }
      }
      all_fts <- groups_counts[groups_counts$replicate %in% replicatesIn, ]

      unique_combinations_max <- unique(fc_summary_count[, c("combination", "replicate_out", "replicate_in"), with = FALSE])
      unique_combinations_min <- unique_combinations_max

      unique_combinations_max$count <- vapply(
        unique_combinations_max$replicate_in,
        function(z, all_fts) max(all_fts$groups[all_fts$replicate == z]),
        all_fts = all_fts,
        0
      )
      unique_combinations_min$count <- vapply(
        unique_combinations_min$replicate_in,
        function(z, all_fts) min(all_fts$groups[all_fts$replicate == z]),
        all_fts = all_fts,
        0
      )

      unique_combinations_max$bondaries <- "Total\nfeatures in"
      unique_combinations_min$bondaries <- "Total\nfeatures in"

      fc_summary_count <- data.table::rbindlist(
        list(unique_combinations_max, unique_combinations_min, fc_summary_count),
        use.names = TRUE
      )

      if (is.null(yLab)) {
        yLab <- if (normalized) "Relative number of feature groups" else "Number of feature groups"
      }

      if (!interactive) {
        fc_summary_count$bondaries <- paste(fc_summary_count$replicate_out, fc_summary_count$bondaries, sep = "\n")
        fc_summary_count$bondaries <- factor(fc_summary_count$bondaries, levels = unique(fc_summary_count$bondaries))
        fc_levels <- unique(fc_summary_count[, .(replicate_out, bondaries)])
        colours <- .get_colors(unique(fc_levels$replicate_out))
        colours_key <- colours[fc_levels$replicate_out]

        if (normalized) {
          fc_summary_count$uid <- paste0(fc_summary_count$replicate_out, "_", fc_summary_count$combination)
          for (i in unique(fc_summary_count$uid)) {
            sel <- fc_summary_count$uid %in% i
            fc_summary_count$count[sel] <- fc_summary_count$count[sel] / max(fc_summary_count$count[sel])
          }
        }

        graphics::boxplot(
          fc_summary_count$count ~ fc_summary_count$bondaries,
          data = fc_summary_count,
          col = paste0(colours_key, "50"),
          border = colours_key,
          main = title,
          xlab = NULL,
          ylab = yLab,
          outline = TRUE,
          ylim = c(0, max(fc_summary_count$count) + 1)
        )
        if (showLegend) {
          legend("topright", legend = names(colours), fill = colours)
        }
        return(invisible(NULL))
      }

      if (normalized) {
        fc_summary_count$uid <- paste0(fc_summary_count$replicate_out, "_", fc_summary_count$combination)
        for (i in unique(fc_summary_count$uid)) {
          sel <- fc_summary_count$uid %in% i
          fc_summary_count$count[sel] <- fc_summary_count$count[sel] / max(fc_summary_count$count[sel])
        }
      }

      plotly::plot_ly(
        data = fc_summary_count,
        x = ~bondaries,
        y = ~count,
        color = ~replicate_out,
        colors = .get_colors(unique(fc_summary_count$replicate_out)),
        type = "box",
        jitter = 0.03,
        showlegend = showLegend
      ) %>%
        plotly::layout(
          title = title,
          xaxis = list(title = ""),
          yaxis = list(
            title = yLab,
            range = c(0, max(fc_summary_count$count) * 1.1)
          )
        )
    },
    #' @description Plot a transformation-products network.
    #' @template arg-ms-groups
    #' @param showMS2 Logical. When TRUE, includes MS2 spectra in node details.
    #' @param showIntensityProfile Logical. When TRUE, includes intensity profiles in node details.
    plot_transformation_products = function(groups = NULL, showMS2 = FALSE, showIntensityProfile = FALSE) {
      if (!requireNamespace("visNetwork", quietly = TRUE)) {
        stop("visNetwork package is required for this function.")
      }
      tps <- self$get_transformation_products(parents = NULL, groups = groups)
      if (nrow(tps) == 0) {
        message("\u2717 No transformation products to plot.")
        return(invisible(NULL))
      }

      ms2_lookup <- NULL
      intensity_profile_dt <- NULL
      replicate_order <- character(0)
      if (showMS2 || showIntensityProfile) {
        product_groups <- unique(tps$feature_group[!is.na(tps$feature_group) & tps$feature_group != ""])
        precursor_groups <- unique(tps$precursor_feature_group[!is.na(tps$precursor_feature_group) & tps$precursor_feature_group != ""])
        main_precursor_groups <- unique(tps$main_precursor_feature_group[!is.na(tps$main_precursor_feature_group) & tps$main_precursor_feature_group != ""])
        all_groups <- unique(c(product_groups, precursor_groups, main_precursor_groups))

        if (length(all_groups) > 0) {
          select_cols <- c("feature_group", "analysis")
          if (showIntensityProfile) {
            select_cols <- c(select_cols, "intensity")
          }
          if (showMS2) {
            select_cols <- c(select_cols, "ms2_mz", "ms2_intensity")
          }
          feature_dt <- self$get_features(groups = all_groups, filtered = FALSE)
          feature_dt <- data.table::as.data.table(feature_dt)[, intersect(unique(select_cols), colnames(feature_dt)), with = FALSE]

          if (showMS2) {
            ms2_data <- feature_dt[!is.na(ms2_mz) & ms2_mz != "", .(feature_group, analysis, ms2_mz, ms2_intensity)]
            if (nrow(ms2_data) > 0) {
              ms2_lookup <- split(ms2_data, ms2_data$feature_group)
            }
          }

          if (showIntensityProfile) {
            analyses_info <- data.table::as.data.table(self$list_analyses())
            keep_cols <- intersect(c("analysis", "replicate"), colnames(analyses_info))
            if (length(keep_cols) > 0) {
              analyses_info <- analyses_info[, ..keep_cols]
            }
            if (nrow(analyses_info) > 0) {
              analyses_info$analysis <- as.character(analyses_info$analysis)
              analyses_info$replicate <- as.character(analyses_info$replicate)
              analyses_info <- unique(analyses_info[, .(analysis, replicate)])
              info_order <- as.character(data.table::as.data.table(self$list_analyses())$analysis)
              analyses_info <- analyses_info[match(analyses_info$analysis, info_order), ]
              analyses_info <- analyses_info[!is.na(analysis) & analysis != "" & !is.na(replicate) & replicate != ""]
              rpls <- analyses_info$replicate
              names(rpls) <- analyses_info$analysis
              replicate_order <- unique(analyses_info$replicate)
              replicate_dt <- data.table::data.table(replicate = replicate_order, replicate_order = seq_along(replicate_order))
              ft_dt <- feature_dt[, .(feature_group, analysis, intensity)]

              if (nrow(ft_dt) > 0) {
                ft_dt$feature_group <- as.character(ft_dt$feature_group)
                ft_dt$analysis <- as.character(ft_dt$analysis)
                ft_dt$intensity <- suppressWarnings(as.numeric(ft_dt$intensity))
                ft_dt <- ft_dt[!is.na(feature_group) & feature_group != "" & !is.na(analysis) & analysis != ""]
                ft_dt$replicate <- unname(rpls[ft_dt$analysis])
                ft_dt <- ft_dt[!is.na(replicate) & replicate != ""]
                ft_dt <- ft_dt[, .(intensity = mean(intensity, na.rm = TRUE), replicate = replicate[1]), by = .(feature_group, analysis)]
                ft_dt[!is.finite(intensity), intensity := 0]
                intensity_profile_dt <- ft_dt[, .(
                  mean_intensity = mean(intensity, na.rm = TRUE),
                  sd_intensity = stats::sd(intensity, na.rm = TRUE)
                ), by = .(feature_group, replicate)]
                intensity_profile_dt[!is.finite(sd_intensity), sd_intensity := 0]
              } else {
                intensity_profile_dt <- data.table::data.table(feature_group = character(0), replicate = character(0), mean_intensity = numeric(0), sd_intensity = numeric(0))
              }

              rep_grid <- data.table::CJ(feature_group = unique(all_groups), replicate = replicate_order, sorted = FALSE, unique = TRUE)
              intensity_profile_dt <- merge(intensity_profile_dt, rep_grid, by = c("feature_group", "replicate"), all = TRUE, sort = FALSE)
              intensity_profile_dt[is.na(mean_intensity) | !is.finite(mean_intensity), mean_intensity := 0]
              intensity_profile_dt[is.na(sd_intensity) | !is.finite(sd_intensity), sd_intensity := 0]
              intensity_profile_dt <- merge(intensity_profile_dt, replicate_dt, by = "replicate", all.x = TRUE, sort = FALSE)
              data.table::setorder(intensity_profile_dt, feature_group, replicate_order)
              intensity_profile_dt[, max_mean_intensity := max(mean_intensity, na.rm = TRUE), by = feature_group]
              intensity_profile_dt[, mean_norm_intensity := ifelse(max_mean_intensity > 0, mean_intensity / max_mean_intensity, 0)]
              intensity_profile_dt[, sd_norm_intensity := ifelse(max_mean_intensity > 0, sd_intensity / max_mean_intensity, 0)]
              intensity_profile_dt[!is.finite(mean_norm_intensity), mean_norm_intensity := 0]
              intensity_profile_dt[!is.finite(sd_norm_intensity), sd_norm_intensity := 0]
              intensity_profile_dt[, max_mean_intensity := NULL]
            }
          }
        }
      }

      node_ids <- unique(c(tps$SMILES, tps$precursor_SMILES, tps$main_precursor_SMILES))
      node_ids <- node_ids[!is.na(node_ids) & node_ids != ""]
      if (length(node_ids) == 0) {
        message("\u2717 No nodes to plot.")
        return(invisible(NULL))
      }

      edges <- tps[!is.na(precursor_SMILES) & precursor_SMILES != "" & !is.na(SMILES) & SMILES != "", .(from = precursor_SMILES, to = SMILES, label = transformation)]
      edges$label <- gsub(" transformation", "", edges$label, fixed = TRUE)
      edges <- edges[, .(edge_label = paste(unique(label), collapse = "\n")), by = .(from, to)]
      edges$id <- seq_len(nrow(edges))
      edges$label <- ""
      edges$base_color <- "rgba(120,120,120,0.7)"
      edges$color <- edges$base_color

      prod_map <- tps[!is.na(SMILES) & SMILES != "", .(id = SMILES, label = name)]
      prec_map <- tps[!is.na(precursor_SMILES) & precursor_SMILES != "", .(id = precursor_SMILES, label = precursor_name)]
      main_map <- tps[!is.na(main_precursor_SMILES) & main_precursor_SMILES != "", .(id = main_precursor_SMILES, label = main_precursor_name)]
      name_map <- data.table::rbindlist(list(prod_map, prec_map, main_map), fill = TRUE)
      name_map <- name_map[!is.na(id) & id != ""]
      name_map <- name_map[!is.na(label) & label != "", .(label = label[1]), by = id]

      nodes <- data.table::data.table(id = node_ids)
      nodes$label <- name_map$label[match(nodes$id, name_map$id)]
      nodes$label[is.na(nodes$label) | nodes$label == ""] <- nodes$id
      fmt_vals <- function(x) {
        x <- as.character(x)
        x <- x[!is.na(x) & x != ""]
        if (length(x) == 0) return("NA")
        paste(unique(x), collapse = "; ")
      }

      create_structure_image <- function(smiles, width_px = 2400, height_px = 1600, dpi = 400) {
        if (is.null(smiles) || is.na(smiles) || !nzchar(smiles)) return("")
        if (!requireNamespace("rcdk", quietly = TRUE)) return("")
        if (!requireNamespace("rJava", quietly = TRUE)) return("")
        if (!requireNamespace("base64enc", quietly = TRUE)) return("")
        if (!requireNamespace("magick", quietly = TRUE)) return("")
        tryCatch({
          mol <- rcdk::parse.smiles(smiles)[[1]]
          depictor <- rcdk::get.depictor(width = as.integer(width_px), height = as.integer(height_px), fillToFit = TRUE)
          img <- rcdk::view.image.2d(mol, depictor = depictor)
          temp_file <- tempfile(fileext = ".png")
          grDevices::png(filename = temp_file, width = width_px, height = height_px, units = "px", res = dpi, bg = "transparent")
          graphics::par(mar = c(0, 0, 0, 0))
          graphics::plot.new()
          graphics::rasterImage(img, 0, 0, 1, 1, interpolate = FALSE)
          grDevices::dev.off()
          magick_img <- magick::image_read(temp_file)
          magick_img <- magick::image_transparent(magick_img, "white", fuzz = 1)
          magick_img <- magick::image_trim(magick_img, fuzz = 1)
          magick::image_write(magick_img, path = temp_file, format = "png")
          img_base64 <- base64enc::base64encode(temp_file)
          unlink(temp_file)
          paste0("data:image/png;base64,", img_base64)
        }, error = function(e) "")
      }

      message("\u2699 Pre-rendering ", length(node_ids), " unique structures...", appendLF = FALSE)
      structure_cache <- setNames(lapply(node_ids, function(smiles) create_structure_image(smiles)), node_ids)
      message(" Done.")

      create_ms2_mirror_plot <- function(precursor_spectra_list, product_spectra_list, width = 700, height = 400) {
        if (!requireNamespace("base64enc", quietly = TRUE)) return("")
        tryCatch({
          parse_values <- function(x) {
            if (is.null(x) || is.na(x) || !nzchar(as.character(x))) return(numeric(0))
            tryCatch({
              vals <- rcpp_streamcraft_decode_string(as.character(x))
              if (length(vals) == 0 || !is.numeric(vals)) return(numeric(0))
              vals[is.finite(vals)]
            }, error = function(e) numeric(0))
          }
          prec_spectra <- list()
          if (!is.null(precursor_spectra_list) && nrow(precursor_spectra_list) > 0) {
            for (i in seq_len(nrow(precursor_spectra_list))) {
              mz <- parse_values(precursor_spectra_list$ms2_mz[i])
              int <- parse_values(precursor_spectra_list$ms2_intensity[i])
              if (length(mz) > 0 && length(int) > 0 && length(mz) == length(int)) {
                valid <- is.finite(mz) & is.finite(int) & int > 0
                if (any(valid)) prec_spectra[[i]] <- list(mz = mz[valid], int = int[valid])
              }
            }
          }
          prod_spectra <- list()
          if (!is.null(product_spectra_list) && nrow(product_spectra_list) > 0) {
            for (i in seq_len(nrow(product_spectra_list))) {
              mz <- parse_values(product_spectra_list$ms2_mz[i])
              int <- parse_values(product_spectra_list$ms2_intensity[i])
              if (length(mz) > 0 && length(int) > 0 && length(mz) == length(int)) {
                valid <- is.finite(mz) & is.finite(int) & int > 0
                if (any(valid)) prod_spectra[[i]] <- list(mz = mz[valid], int = int[valid])
              }
            }
          }
          if (length(prec_spectra) == 0 && length(prod_spectra) == 0) return("")
          for (i in seq_along(prec_spectra)) if (max(prec_spectra[[i]]$int) > 0) prec_spectra[[i]]$int <- prec_spectra[[i]]$int / max(prec_spectra[[i]]$int)
          for (i in seq_along(prod_spectra)) if (max(prod_spectra[[i]]$int) > 0) prod_spectra[[i]]$int <- prod_spectra[[i]]$int / max(prod_spectra[[i]]$int)
          all_mz <- c(unlist(lapply(prec_spectra, function(s) s$mz)), unlist(lapply(prod_spectra, function(s) s$mz)))
          if (length(all_mz) == 0) return("")
          mz_range <- c(floor(min(all_mz)), ceiling(max(all_mz)))
          temp_file <- tempfile(fileext = ".png")
          grDevices::png(filename = temp_file, width = width, height = height, res = 150, bg = "transparent")
          graphics::par(mar = c(3.5, 3.5, 1, 1), mgp = c(2.1, 0.6, 0), family = "sans")
          graphics::plot(NULL, xlim = mz_range, ylim = c(-1, 1), xlab = "m/z", ylab = "Relative Intensity", las = 1, cex.lab = 1, cex.axis = 0.9, bty = "n")
          x_ticks <- pretty(mz_range, n = 8)
          y_ticks <- seq(-1, 1, by = 0.25)
          graphics::abline(v = x_ticks, col = grDevices::adjustcolor("#C8D4E3", alpha.f = 0.55), lty = 3, lwd = 0.8)
          graphics::abline(h = y_ticks, col = grDevices::adjustcolor("#C8D4E3", alpha.f = 0.55), lty = 3, lwd = 0.8)
          graphics::abline(h = 0, col = "#607D9C", lwd = 1.1)
          prec_colors <- grDevices::adjustcolor(c("#EF553B", "#C0392B", "#FF8A65", "#E57373"), alpha.f = 0.75)
          prod_colors <- grDevices::adjustcolor(c("#00CC96", "#2E8B57", "#66D19E", "#7BCFA8"), alpha.f = 0.75)
          for (i in seq_along(prec_spectra)) {
            col <- prec_colors[((i - 1) %% length(prec_colors)) + 1]
            for (j in seq_along(prec_spectra[[i]]$mz)) graphics::segments(prec_spectra[[i]]$mz[j], 0, prec_spectra[[i]]$mz[j], -prec_spectra[[i]]$int[j], col = col, lwd = 1.7)
          }
          for (i in seq_along(prod_spectra)) {
            col <- prod_colors[((i - 1) %% length(prod_colors)) + 1]
            for (j in seq_along(prod_spectra[[i]]$mz)) graphics::segments(prod_spectra[[i]]$mz[j], 0, prod_spectra[[i]]$mz[j], prod_spectra[[i]]$int[j], col = col, lwd = 1.7)
          }
          n_prod <- length(prod_spectra)
          n_prec <- length(prec_spectra)
          prod_label <- if (n_prod > 1) sprintf("Product (%d spectra)", n_prod) else "Product"
          prec_label <- if (n_prec > 1) sprintf("Precursor (%d spectra)", n_prec) else "Precursor"
          graphics::text(mz_range[1] + diff(mz_range) * 0.02, 0.9, prod_label, col = "#00A67A", adj = 0, cex = 0.88, font = 2)
          graphics::text(mz_range[1] + diff(mz_range) * 0.02, -0.9, prec_label, col = "#D6452F", adj = 0, cex = 0.88, font = 2)
          grDevices::dev.off()
          img_base64 <- base64enc::base64encode(temp_file)
          unlink(temp_file)
          paste0("data:image/png;base64,", img_base64)
        }, error = function(e) "")
      }

      create_intensity_profile_plot <- function(profile_dt, replicate_order, width = 700, height = 260) {
        if (!requireNamespace("base64enc", quietly = TRUE)) return("")
        if (!requireNamespace("ggplot2", quietly = TRUE)) return("")
        if (is.null(profile_dt) || nrow(profile_dt) == 0) return("")
        tryCatch({
          plt_dt <- data.table::copy(profile_dt)
          plt_dt$feature_group <- as.character(plt_dt$feature_group)
          plt_dt$replicate <- as.character(plt_dt$replicate)
          if (!is.null(replicate_order) && length(replicate_order) > 0) {
            ord <- replicate_order[replicate_order %in% plt_dt$replicate]
            if (length(ord) == 0) ord <- unique(plt_dt$replicate)
          } else {
            ord <- unique(plt_dt$replicate)
          }
          plt_dt$replicate <- factor(plt_dt$replicate, levels = ord)
          plt_dt <- plt_dt[order(replicate)]
          if (nrow(plt_dt) == 0) return("")
          cols <- .get_colors(unique(plt_dt$feature_group))
          plt <- ggplot2::ggplot(plt_dt, ggplot2::aes(x = replicate, y = mean_norm_intensity, color = feature_group, group = feature_group)) +
            ggplot2::geom_errorbar(ggplot2::aes(ymin = pmax(0, mean_norm_intensity - sd_norm_intensity), ymax = pmin(1, mean_norm_intensity + sd_norm_intensity)), width = 0.15, alpha = 0.65, linewidth = 0.45) +
            ggplot2::geom_line(linewidth = 0.6) +
            ggplot2::geom_point(size = 1.8) +
            ggplot2::scale_color_manual(values = cols) +
            ggplot2::coord_cartesian(ylim = c(0, 1)) +
            ggplot2::labs(x = "Replicate Group", y = "Normalized Intensity", color = "feature_group") +
            ggplot2::theme_minimal(base_size = 10) +
            ggplot2::theme(legend.position = "right", panel.grid.major = ggplot2::element_line(color = "#DCE3ED", linewidth = 0.35), panel.grid.minor = ggplot2::element_blank(), axis.text.x = ggplot2::element_text(angle = 35, hjust = 1))
          temp_file <- tempfile(fileext = ".png")
          ggplot2::ggsave(filename = temp_file, plot = plt, width = width / 150, height = height / 150, dpi = 150, bg = "transparent")
          img_base64 <- base64enc::base64encode(temp_file)
          unlink(temp_file)
          paste0("data:image/png;base64,", img_base64)
        }, error = function(e) "")
      }

      parse_ms_values <- function(x) {
        if (is.null(x) || is.na(x) || !nzchar(as.character(x))) return(numeric(0))
        vals <- tryCatch(rcpp_streamcraft_decode_string(as.character(x)), error = function(e) numeric(0))
        if (!is.numeric(vals) || length(vals) == 0) return(numeric(0))
        vals[is.finite(vals)]
      }

      build_plotly_spectra_payload <- function(as_product) {
        if (!showMS2 || is.null(ms2_lookup) || nrow(as_product) == 0) return("")
        product_fgs <- unique(as_product$feature_group)
        product_fgs <- product_fgs[!is.na(product_fgs) & product_fgs != ""]
        if (length(product_fgs) == 0) return("")
        fg_cols <- .get_colors(product_fgs)
        traces <- list()
        for (fg in product_fgs) {
          dt <- ms2_lookup[[fg]]
          if (is.null(dt) || nrow(dt) == 0) next
          x_seg <- numeric(0)
          y_seg <- numeric(0)
          for (i in seq_len(nrow(dt))) {
            mz <- parse_ms_values(dt$ms2_mz[i])
            int <- parse_ms_values(dt$ms2_intensity[i])
            if (length(mz) == 0 || length(int) == 0 || length(mz) != length(int)) next
            keep <- is.finite(mz) & is.finite(int) & int > 0
            if (!any(keep)) next
            mz <- mz[keep]
            int <- int[keep]
            max_int <- suppressWarnings(max(int, na.rm = TRUE))
            if (!is.finite(max_int) || max_int <= 0) next
            int <- int / max_int
            x_seg <- c(x_seg, as.vector(rbind(mz, mz, rep(NA_real_, length(mz)))))
            y_seg <- c(y_seg, as.vector(rbind(rep(0, length(int)), int, rep(NA_real_, length(int)))))
          }
          if (length(x_seg) == 0) next
          row_fg <- as_product[as_product$feature_group %in% fg, ]
          cs <- suppressWarnings(max(as.numeric(row_fg$cosine_similarity), na.rm = TRUE))
          rt <- suppressWarnings(max(as.numeric(row_fg$rt_plausibility), na.rm = TRUE))
          cs_lbl <- ifelse(is.finite(cs), sprintf("%.3f", cs), "-")
          rt_lbl <- ifelse(is.finite(rt), sprintf("%.2f", rt), "-")
          traces[[length(traces) + 1]] <- list(type = "scattergl", mode = "lines", x = as.numeric(x_seg), y = as.numeric(y_seg), name = paste0(fg, " | cos: ", cs_lbl, " | rt: ", rt_lbl), line = list(color = unname(fg_cols[[fg]]), width = 1.5), showlegend = TRUE, hovertemplate = "m/z: %{x:.4f}<br>rel.int: %{y:.3f}<extra></extra>")
        }
        precursor_fgs <- unique(as_product$precursor_feature_group)
        precursor_fgs <- precursor_fgs[!is.na(precursor_fgs) & precursor_fgs != ""]
        for (fg in precursor_fgs) {
          dt <- ms2_lookup[[fg]]
          if (is.null(dt) || nrow(dt) == 0) next
          x_seg <- numeric(0)
          y_seg <- numeric(0)
          for (i in seq_len(nrow(dt))) {
            mz <- parse_ms_values(dt$ms2_mz[i])
            int <- parse_ms_values(dt$ms2_intensity[i])
            if (length(mz) == 0 || length(int) == 0 || length(mz) != length(int)) next
            keep <- is.finite(mz) & is.finite(int) & int > 0
            if (!any(keep)) next
            mz <- mz[keep]
            int <- int[keep]
            max_int <- suppressWarnings(max(int, na.rm = TRUE))
            if (!is.finite(max_int) || max_int <= 0) next
            int <- int / max_int
            x_seg <- c(x_seg, as.vector(rbind(mz, mz, rep(NA_real_, length(mz)))))
            y_seg <- c(y_seg, as.vector(rbind(rep(0, length(int)), -int, rep(NA_real_, length(int)))))
          }
          if (length(x_seg) == 0) next
          traces[[length(traces) + 1]] <- list(type = "scattergl", mode = "lines", x = as.numeric(x_seg), y = as.numeric(y_seg), name = paste0("Precursor ", fg), line = list(color = "rgba(45,45,45,0.9)", width = 1.8, dash = "dot"), showlegend = FALSE, hovertemplate = "m/z: %{x:.4f}<br>rel.int: %{y:.3f}<extra></extra>")
        }
        if (length(traces) == 0) return("")
        jsonlite::toJSON(list(traces = traces, layout = list(template = "plotly_white", margin = list(l = 55, r = 20, t = 20, b = 45), xaxis = list(title = "m/z", zeroline = FALSE), yaxis = list(title = "Relative Intensity", range = list(-1, 1), zeroline = TRUE, zerolinecolor = "#607D9C"), legend = list(title = list(text = "Spectra Match"))), config = list(displayModeBar = TRUE, responsive = TRUE)), auto_unbox = TRUE, null = "null", digits = 8)
      }

      build_plotly_profile_payload <- function(as_product) {
        if (!showIntensityProfile || is.null(intensity_profile_dt) || nrow(as_product) == 0) return("")
        node_fgs <- unique(as_product$feature_group)
        node_fgs <- node_fgs[!is.na(node_fgs) & node_fgs != ""]
        if (length(node_fgs) == 0) return("")
        dt <- intensity_profile_dt[feature_group %in% node_fgs]
        if (nrow(dt) == 0) return("")
        dt <- data.table::copy(dt)
        dt$feature_group <- as.character(dt$feature_group)
        dt$replicate <- as.character(dt$replicate)
        ord <- replicate_order[replicate_order %in% dt$replicate]
        if (length(ord) == 0) ord <- unique(dt$replicate)
        dt$replicate <- factor(dt$replicate, levels = ord)
        data.table::setorder(dt, feature_group, replicate)
        cols <- .get_colors(unique(dt$feature_group))
        traces <- lapply(unique(dt$feature_group), function(fg) {
          dfg <- dt[feature_group %in% fg]
          list(type = "scatter", mode = "lines+markers", name = fg, x = as.character(dfg$replicate), y = as.numeric(dfg$mean_norm_intensity), line = list(color = unname(cols[[fg]]), width = 2), marker = list(color = unname(cols[[fg]]), size = 6), error_y = list(type = "data", array = as.numeric(dfg$sd_norm_intensity), visible = TRUE), hovertemplate = "replicate: %{x}<br>norm.int: %{y:.3f}<extra></extra>")
        })
        jsonlite::toJSON(list(traces = traces, layout = list(template = "plotly_white", margin = list(l = 55, r = 20, t = 20, b = 55), xaxis = list(title = "Replicate Group", tickangle = 35, type = "category", categoryorder = "array", categoryarray = as.list(ord)), yaxis = list(title = "Normalized Intensity", range = list(0, 1)), legend = list(title = list(text = "feature_group"))), config = list(displayModeBar = TRUE, responsive = TRUE)), auto_unbox = TRUE, null = "null", digits = 8)
      }

      node_modal_data <- function(node_id) {
        as_product <- tps[tps$SMILES == node_id, ]
        as_precursor <- tps[tps$precursor_SMILES == node_id, ]
        as_main_precursor <- tps[tps$main_precursor_SMILES == node_id, ]
        node_structure <- structure_cache[[node_id]]
        prec_smiles <- unique(as_product$precursor_SMILES)
        prec_smiles <- prec_smiles[!is.na(prec_smiles) & prec_smiles != ""][1]
        prec_structure <- if (!is.na(prec_smiles) && !is.null(prec_smiles)) structure_cache[[prec_smiles]] else ""
        structures_html <- ""
        if (nzchar(node_structure) || nzchar(prec_structure)) {
          structures_html <- paste0('<table style="width:100%;border-collapse:collapse;margin:0;padding:0;"><tr>','<td style="width:38%;vertical-align:middle;padding:4px 6px;text-align:center;">','<div style="font-size:0.75em;font-weight:bold;color:#888;margin-bottom:3px;">Precursor</div>',if (nzchar(prec_structure)) paste0('<img src="', prec_structure, '" style="width:100%;height:140px;object-fit:contain;"/>') else '<div style="color:#ccc;padding:14px;">No structure</div>','</td>','<td style="width:8%;vertical-align:middle;padding:0 4px;text-align:center;">','<div style="font-size:2.0em;font-weight:700;color:#5f6b7a;line-height:1;">&#8594;</div>','</td>','<td style="width:54%;vertical-align:middle;padding:4px 6px;text-align:center;">',if (nzchar(node_structure)) paste0('<img src="', node_structure, '" style="width:100%;height:220px;object-fit:contain;"/>') else '<div style="color:#ccc;padding:14px;">No structure</div>','</td>','</tr></table>')
        }
        node_name <- NA_character_
        node_formula <- NA_character_
        node_mass <- NA_real_
        node_inchikey <- NA_character_
        node_xlogp <- NA_real_
        if (nrow(as_product) > 0) {
          node_name <- fmt_vals(unique(as_product$name))
          node_formula <- fmt_vals(unique(as_product$formula))
          node_mass <- fmt_vals(unique(as_product$mass))
          node_inchikey <- fmt_vals(unique(as_product$InChIKey))
          node_xlogp <- fmt_vals(unique(as_product$xLogP))
        } else if (nrow(as_precursor) > 0) {
          node_name <- fmt_vals(unique(as_precursor$precursor_name))
          node_formula <- fmt_vals(unique(as_precursor$precursor_formula))
          node_mass <- fmt_vals(unique(as_precursor$precursor_mass))
          node_inchikey <- fmt_vals(unique(as_precursor$precursor_InChIKey))
          node_xlogp <- fmt_vals(unique(as_precursor$precursor_xLogP))
        } else if (nrow(as_main_precursor) > 0) {
          node_name <- fmt_vals(unique(as_main_precursor$main_precursor_name))
          node_formula <- fmt_vals(unique(as_main_precursor$main_precursor_formula))
          node_mass <- fmt_vals(unique(as_main_precursor$main_precursor_mass))
          node_inchikey <- fmt_vals(unique(as_main_precursor$main_precursor_InChIKey))
          node_xlogp <- fmt_vals(unique(as_main_precursor$main_precursor_xLogP))
        }
        metadata_lines <- c(paste0("<b>Name:</b> ", node_name), paste0("<b>Formula:</b> ", node_formula), paste0("<b>Mass:</b> ", node_mass), paste0("<b>SMILES:</b> ", fmt_vals(node_id)), paste0("<b>InChIKey:</b> ", node_inchikey), paste0("<b>xLogP:</b> ", node_xlogp))
        metadata_html <- paste0('<div style="font-size:0.75em;line-height:1.3;margin:8px 0;padding:5px;background:rgba(240,240,240,0.3);border-radius:3px;">', paste(metadata_lines, collapse = "<br/>"), '</div>')
        relationships_html <- ""
        if (nrow(as_product) > 0) {
          prod_valid <- as_product[!is.na(feature_group) & feature_group != ""]
          if (nrow(prod_valid) > 0) {
            prod_prec <- prod_valid[!is.na(precursor_feature_group) & precursor_feature_group != ""]
            if (nrow(prod_prec) > 0) {
              prod_prec <- unique(prod_prec, by = c("feature_group", "precursor_feature_group", "cosine_similarity", "rt_plausibility"))
              prec_lines <- vapply(seq_len(nrow(prod_prec)), function(i) {
                row <- prod_prec[i, ]
                paste0('<tr style="border-bottom:1px solid #eee;">','<td style="padding:2px 4px;">', row$feature_group, '</td>','<td style="padding:2px 4px;">', row$precursor_feature_group, '</td>','<td style="padding:2px 4px;">', ifelse(!is.na(row$cosine_similarity), sprintf("%.3f", row$cosine_similarity), "-"), '</td>','<td style="padding:2px 4px;">', ifelse(!is.na(row$rt_plausibility), sprintf("%.2f", row$rt_plausibility), "-"), '</td>','</tr>')
              }, character(1))
              relationships_html <- paste0(relationships_html, '<div style="margin-top:8px;border-top:1px solid #ddd;padding-top:4px;">','<div style="font-size:0.75em;font-weight:bold;color:#666;margin-bottom:3px;">Product → Precursor</div>','<table style="width:100%;font-size:0.7em;border-collapse:collapse;">','<tr style="background:#f5f5f5;font-weight:bold;">','<td style="padding:2px 4px;">FG</td>','<td style="padding:2px 4px;">Prec FG</td>','<td style="padding:2px 4px;">Cos</td>','<td style="padding:2px 4px;">RT</td>','</tr>', paste(prec_lines, collapse = ""), '</table>','</div>')
            }
            prod_main <- prod_valid[!is.na(main_precursor_feature_group) & main_precursor_feature_group != ""]
            if (nrow(prod_main) > 0) {
              prod_main <- unique(prod_main, by = c("feature_group", "main_precursor_feature_group", "main_precursor_cosine_similarity", "main_precursor_rt_plausibility"))
              main_lines <- vapply(seq_len(nrow(prod_main)), function(i) {
                row <- prod_main[i, ]
                paste0('<tr style="border-bottom:1px solid #eee;">','<td style="padding:2px 4px;">', row$feature_group, '</td>','<td style="padding:2px 4px;">', row$main_precursor_feature_group, '</td>','<td style="padding:2px 4px;">', ifelse(!is.na(row$main_precursor_cosine_similarity), sprintf("%.3f", row$main_precursor_cosine_similarity), "-"), '</td>','<td style="padding:2px 4px;">', ifelse(!is.na(row$main_precursor_rt_plausibility), sprintf("%.2f", row$main_precursor_rt_plausibility), "-"), '</td>','</tr>')
              }, character(1))
              relationships_html <- paste0(relationships_html, '<div style="margin-top:8px;border-top:1px solid #ddd;padding-top:4px;">','<div style="font-size:0.75em;font-weight:bold;color:#666;margin-bottom:3px;">Product → Main Precursor</div>','<table style="width:100%;font-size:0.7em;border-collapse:collapse;">','<tr style="background:#f5f5f5;font-weight:bold;">','<td style="padding:2px 4px;">FG</td>','<td style="padding:2px 4px;">Main FG</td>','<td style="padding:2px 4px;">Cos</td>','<td style="padding:2px 4px;">RT</td>','</tr>', paste(main_lines, collapse = ""), '</table>','</div>')
            }
          }
        }
        list(overview_html = paste0(structures_html, metadata_html, relationships_html), spectra_json = build_plotly_spectra_payload(as_product), profile_json = build_plotly_profile_payload(as_product))
      }

      modal_data <- lapply(nodes$id, node_modal_data)
      nodes$overview_html <- vapply(modal_data, function(z) z$overview_html, character(1))
      nodes$spectra_json <- vapply(modal_data, function(z) z$spectra_json, character(1))
      nodes$profile_json <- vapply(modal_data, function(z) z$profile_json, character(1))
      nodes$title <- "Double click node to open details"
      nodes$node_label <- nodes$label
      nodes$group <- "unassigned"

      target_groups <- character(0)
      if (!is.null(groups)) {
        groups_chr <- as.character(groups)
        groups_split <- unlist(strsplit(groups_chr, ";", fixed = TRUE), use.names = FALSE)
        groups_split <- trimws(groups_split)
        target_groups <- unique(groups_split[!is.na(groups_split) & groups_split != ""])
      }
      node_has_group <- unique(c(tps$SMILES[!is.na(tps$feature_group) & tps$feature_group != ""], tps$precursor_SMILES[!is.na(tps$precursor_feature_group) & tps$precursor_feature_group != ""], tps$main_precursor_SMILES[!is.na(tps$main_precursor_feature_group) & tps$main_precursor_feature_group != ""]))
      node_has_group <- node_has_group[!is.na(node_has_group) & node_has_group != ""]
      parent_nodes <- unique(c(tps$SMILES[tps$transformation %in% "main_precursor" & !is.na(tps$feature_group) & tps$feature_group != ""], tps$main_precursor_SMILES[!is.na(tps$main_precursor_feature_group) & tps$main_precursor_feature_group != ""]))
      parent_nodes <- parent_nodes[!is.na(parent_nodes) & parent_nodes != ""]
      nodes_in_target_groups <- character(0)
      if (length(target_groups) > 0) {
        nodes_in_target_groups <- unique(c(tps$SMILES[!is.na(tps$feature_group) & tps$feature_group %in% target_groups], tps$precursor_SMILES[!is.na(tps$precursor_feature_group) & tps$precursor_feature_group %in% target_groups], tps$main_precursor_SMILES[!is.na(tps$main_precursor_feature_group) & tps$main_precursor_feature_group %in% target_groups]))
        nodes_in_target_groups <- nodes_in_target_groups[!is.na(nodes_in_target_groups) & nodes_in_target_groups != ""]
      }

      nodes$group[nodes$id %in% node_has_group] <- "assigned"
      nodes$group[nodes$id %in% nodes_in_target_groups] <- "selected_group"
      nodes$group[nodes$id %in% parent_nodes] <- "parent"
      nodes$base_color <- "lightgray"
      nodes$base_color[nodes$group == "assigned"] <- "forestgreen"
      nodes$base_color[nodes$group == "selected_group"] <- "orange"
      nodes$base_color[nodes$group == "parent"] <- "darkred"
      nodes$color <- nodes$base_color

      p <- visNetwork::visNetwork(nodes, edges, height = "99vh", width = "100%") %>%
        visNetwork::visNodes(size = 12, font = list(size = 12, face = "Arial", strokeWidth = 0, strokeColor = "rgba(0,0,0,0)")) %>%
        visNetwork::visGroups(groupname = "parent", color = "darkred") %>%
        visNetwork::visGroups(groupname = "selected_group", color = "orange") %>%
        visNetwork::visGroups(groupname = "assigned", color = "forestgreen") %>%
        visNetwork::visGroups(groupname = "unassigned", color = "lightgray") %>%
        visNetwork::visEdges(arrows = "to", smooth = TRUE, font = list(size = 8, face = "Arial", strokeWidth = 0, strokeColor = "rgba(0,0,0,0)"), hoverWidth = 0, selectionWidth = 0) %>%
        visNetwork::visOptions(highlightNearest = FALSE, nodesIdSelection = list(enabled = TRUE)) %>%
        visNetwork::visInteraction(hover = TRUE, hoverConnectedEdges = TRUE, tooltipStyle = 'position: fixed; visibility: hidden; padding: 5px; font-family: verdana; font-size: 14px; background-color: rgb(245, 244, 237); border-radius: 3px; border: 1px solid rgb(128, 128, 116); box-shadow: rgba(0, 0, 0, 0.2) 3px 3px 10px; max-width: 1200px; word-break: break-word;') %>%
        visNetwork::visLayout(randomSeed = 123) %>%
        visNetwork::visEvents(
          selectNode = htmlwidgets::JS("function(params) { var selected = params.nodes[0]; if (!selected) return; var nearNodes = this.getConnectedNodes(selected); nearNodes.push(selected); var nearSet = {}; for (var n = 0; n < nearNodes.length; n++) nearSet[nearNodes[n]] = true; var connected = this.getConnectedEdges(selected); var keep = {}; for (var i = 0; i < connected.length; i++) keep[connected[i]] = true; var allNodes = this.body.data.nodes.getIds(); var nodeUpdates = []; for (var k = 0; k < allNodes.length; k++) { var nn = this.body.data.nodes.get(allNodes[k]); nodeUpdates.push({ id: allNodes[k], label: nearSet[allNodes[k]] ? nn.node_label : '', font: { color: nearSet[allNodes[k]] ? 'rgba(0,0,0,1)' : 'rgba(0,0,0,0)', face: 'Arial', bold: allNodes[k] === selected }, color: nearSet[allNodes[k]] ? nn.base_color : 'rgba(200,200,200,0.2)' }); } this.body.data.nodes.update(nodeUpdates); var allEdges = this.body.data.edges.getIds(); var updates = []; for (var j = 0; j < allEdges.length; j++) { var e = this.body.data.edges.get(allEdges[j]); updates.push({ id: allEdges[j], hidden: false, label: keep[allEdges[j]] ? e.edge_label : '', color: keep[allEdges[j]] ? e.base_color : 'rgba(200,200,200,0.2)', font: { color: keep[allEdges[j]] ? 'rgba(0,0,0,1)' : 'rgba(0,0,0,0)', face: 'Arial', strokeWidth: 0, strokeColor: 'rgba(0,0,0,0)' } }); } this.body.data.edges.update(updates); }") ,
          doubleClick = htmlwidgets::JS("function(params) { var selected = (params.nodes && params.nodes.length > 0) ? params.nodes[0] : null; if (!selected) return; if (window.streamfindOpenTPModal) { window.streamfindOpenTPModal(this, selected); } }") ,
          deselectNode = htmlwidgets::JS("function(params) { var allNodes = this.body.data.nodes.getIds(); var nodeUpdates = []; for (var k = 0; k < allNodes.length; k++) { var nn = this.body.data.nodes.get(allNodes[k]); nodeUpdates.push({ id: allNodes[k], label: nn.node_label, font: { color: 'rgba(0,0,0,1)', face: 'Arial', bold: false }, color: nn.base_color }); } this.body.data.nodes.update(nodeUpdates); var allEdges = this.body.data.edges.getIds(); var updates = []; for (var j = 0; j < allEdges.length; j++) { var e = this.body.data.edges.get(allEdges[j]); updates.push({ id: allEdges[j], hidden: false, label: '', color: e.base_color, font: { color: 'rgba(0,0,0,0)', face: 'Arial', strokeWidth: 0, strokeColor: 'rgba(0,0,0,0)' } }); } this.body.data.edges.update(updates); }") ,
          hoverEdge = htmlwidgets::JS("function(params) { if (params.edge) { var e = this.body.data.edges.get(params.edge); this.body.data.edges.update({ id: params.edge, label: e.edge_label, font: { color: 'rgba(0,0,0,1)', face: 'Arial', strokeWidth: 0, strokeColor: 'rgba(0,0,0,0)' } }); } }") ,
          blurEdge = htmlwidgets::JS("function(params) { if (params.edge) { this.body.data.edges.update({ id: params.edge, label: '', font: { color: 'rgba(0,0,0,0)', face: 'Arial', strokeWidth: 0, strokeColor: 'rgba(0,0,0,0)' } }); } }")
        )

      modal_markup <- htmltools::tagList(
        htmltools::tags$style(htmltools::HTML("#sf-tp-modal-overlay{display:none;position:fixed;inset:0;background:rgba(20,26,38,0.35);z-index:9998;align-items:center;justify-content:center;}#sf-tp-modal{width:96vw;height:94vh;background:#fff;border-radius:8px;box-shadow:0 20px 50px rgba(0,0,0,0.28);display:flex;flex-direction:column;overflow:hidden;}#sf-tp-modal-header{display:flex;align-items:center;justify-content:space-between;padding:10px 14px;border-bottom:1px solid #e3e3e3;background:#fafafa;}#sf-tp-modal-title{font-size:15px;font-weight:600;color:#1f2937;}#sf-tp-modal-close{border:none;background:transparent;font-size:22px;line-height:1;cursor:pointer;color:#666;}#sf-tp-modal-content{display:grid;grid-template-rows:2fr 1fr 1fr;flex:1 1 auto;min-height:0;height:calc(100% - 0px);}#sf-tp-overview-row{min-height:0;overflow:auto;padding:8px 12px;border-bottom:1px solid #ececec;}#sf-tp-overview-content{height:auto;min-height:100%;}#sf-tp-spectra-row,#sf-tp-profile-row{min-height:0;overflow:hidden;padding:0;margin:0;}#sf-tp-spectra-plot,#sf-tp-profile-plot{display:block;box-sizing:border-box;width:100%;height:100%;min-height:0;margin:0;padding:0;overflow:hidden;}#sf-tp-spectra-plot .js-plotly-plot,#sf-tp-profile-plot .js-plotly-plot{width:100% !important;height:100% !important;}#sf-tp-spectra-plot .plot-container,#sf-tp-profile-plot .plot-container{width:100% !important;height:100% !important;}#sf-tp-spectra-plot .svg-container,#sf-tp-profile-plot .svg-container{width:100% !important;height:100% !important;}")),
        htmltools::tags$div(id = "sf-tp-modal-overlay", htmltools::tags$div(id = "sf-tp-modal", htmltools::tags$div(id = "sf-tp-modal-header", htmltools::tags$div(id = "sf-tp-modal-title", "Node Details"), htmltools::tags$button(id = "sf-tp-modal-close", type = "button", "\u00d7")), htmltools::tags$div(id = "sf-tp-modal-content", htmltools::tags$div(id = "sf-tp-overview-row", htmltools::tags$div(id = "sf-tp-overview-content")), htmltools::tags$div(id = "sf-tp-spectra-row", htmltools::tags$div(id = "sf-tp-spectra-plot")), htmltools::tags$div(id = "sf-tp-profile-row", htmltools::tags$div(id = "sf-tp-profile-plot"))))),
        htmltools::tags$script(htmltools::HTML("(function(){function byId(id){ return document.getElementById(id); } var init = false; var resizeObserver = null; var sfRenderVersion = 0; function clearPlot(containerId){ var el = byId(containerId); if (!el) return; if (window.Plotly) { try { window.Plotly.purge(el); } catch(e){} } el.innerHTML = ''; } function resizePlots(){ if (!window.Plotly) return; var s = byId('sf-tp-spectra-plot'); var p = byId('sf-tp-profile-plot'); if (s) { try { window.Plotly.Plots.resize(s); } catch(e){} } if (p) { try { window.Plotly.Plots.resize(p); } catch(e){} } } function scheduleResize(){ if (!window.requestAnimationFrame) { setTimeout(resizePlots, 0); return; } window.requestAnimationFrame(function(){ resizePlots(); setTimeout(resizePlots, 40); }); } function setNoData(containerId, msg){ var el = byId(containerId); if (!el) return; if (window.Plotly) { try { window.Plotly.purge(el); } catch(e){} } el.innerHTML = '<div style=\"padding:14px;color:#666;font-size:13px;\">' + msg + '</div>'; } var sfPlotlyLoading = false; var sfPlotlyWaiters = []; function withPlotly(ready, fail){ if (window.Plotly) { ready(); return; } sfPlotlyWaiters.push({ready: ready, fail: fail}); if (sfPlotlyLoading) return; sfPlotlyLoading = true; var s = document.createElement('script'); s.src = 'https://cdn.plot.ly/plotly-2.35.2.min.js'; s.async = true; s.onload = function(){ sfPlotlyLoading = false; var q = sfPlotlyWaiters.slice(); sfPlotlyWaiters = []; for (var i = 0; i < q.length; i++) { try { q[i].ready(); } catch(e){} } }; s.onerror = function(){ sfPlotlyLoading = false; var q = sfPlotlyWaiters.slice(); sfPlotlyWaiters = []; for (var i = 0; i < q.length; i++) { if (q[i].fail) { try { q[i].fail(); } catch(e){} } } }; document.head.appendChild(s); } function renderPlot(containerId, payloadJson, noDataMsg, version){ var el = byId(containerId); if (!el) return; if (version !== sfRenderVersion) return; if (!payloadJson){ setNoData(containerId, noDataMsg); return; } var payload = null; try { payload = JSON.parse(payloadJson); } catch(e){ payload = null; } if (!payload || !payload.traces || !payload.traces.length){ setNoData(containerId, noDataMsg); return; } clearPlot(containerId); if (!window.Plotly){ setNoData(containerId, 'Loading interactive plot...'); } withPlotly(function(){ try { if (version !== sfRenderVersion) return; var target = byId(containerId); if (!target) return; var layout = Object.assign({}, payload.layout || {}, {autosize: true}); var config = Object.assign({responsive: true}, payload.config || {}); window.Plotly.react(target, payload.traces, layout, config).then(function(){ if (version !== sfRenderVersion) return; scheduleResize(); }); } catch(e){ if (version !== sfRenderVersion) return; setNoData(containerId, 'Could not render interactive plot.'); } }, function(){ if (version !== sfRenderVersion) return; setNoData(containerId, 'Plotly JS not available in this page.'); }); } function closeModal(){ var ov = byId('sf-tp-modal-overlay'); if (!ov) return; sfRenderVersion += 1; clearPlot('sf-tp-spectra-plot'); clearPlot('sf-tp-profile-plot'); ov.style.display = 'none'; } function ensureInit(){ if (init) return; init = true; var ov = byId('sf-tp-modal-overlay'); var close = byId('sf-tp-modal-close'); if (close) close.addEventListener('click', closeModal); if (ov) ov.addEventListener('click', function(e){ if (e.target === ov) closeModal(); }); document.addEventListener('keydown', function(e){ if (e.key === 'Escape') closeModal(); }); window.addEventListener('resize', scheduleResize); if (window.ResizeObserver){ resizeObserver = new window.ResizeObserver(function(){ scheduleResize(); }); var target = byId('sf-tp-modal-content'); if (target) resizeObserver.observe(target); } } window.streamfindOpenTPModal = function(network, nodeId){ ensureInit(); sfRenderVersion += 1; var renderVersion = sfRenderVersion; var node = null; try { node = network.body.data.nodes.get(nodeId); } catch(e){ node = null; } if (!node) return; var ov = byId('sf-tp-modal-overlay'); if (!ov) return; byId('sf-tp-modal-title').textContent = node.node_label || node.id || 'Node Details'; byId('sf-tp-overview-content').innerHTML = node.overview_html || '<div style=\"color:#666;\">No overview data.</div>'; renderPlot('sf-tp-spectra-plot', node.spectra_json, 'MS2 spectra not available for this node.', renderVersion); renderPlot('sf-tp-profile-plot', node.profile_json, 'Intensity profile not available for this node.', renderVersion); ov.style.display = 'flex'; scheduleResize(); }; })();"))
      )

      p <- htmlwidgets::prependContent(p, modal_markup)
      if (requireNamespace("plotly", quietly = TRUE)) {
        dep_src <- plotly::plotly_build(plotly::plot_ly(x = c(0, 1), y = c(0, 1), type = "scatter", mode = "lines"))
        dep_list <- htmltools::findDependencies(dep_src)
        if (length(dep_list) > 0) {
          p <- htmltools::attachDependencies(p, dep_list, append = TRUE)
        }
      }

      p
    },
    #' @description Print a short summary.
    #' @param ... Additional arguments ignored.
    print = function(...) {
      info <- try(self$info(), silent = TRUE)
      cat("\nProjectNonTargetAnalysis\n")
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
      if (!inherits(info, "try-error")) {
        cat("features: ", sum(info$features, na.rm = TRUE), "\n", sep = "")
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

#' @title ProjectNonTargetAnalysis S3 methods
#' @name ProjectNonTargetAnalysisS3
#' @rdname ProjectNonTargetAnalysisS3
#' @description S3 wrappers for the `ProjectNonTargetAnalysis` R6 methods.
#' @aliases
#'   info.ProjectNonTargetAnalysis
#'   get_features.ProjectNonTargetAnalysis
#'   get_features_count.ProjectNonTargetAnalysis
#'   get_features_profile.ProjectNonTargetAnalysis
#'   get_fold_change.ProjectNonTargetAnalysis
#'   get_suspects.ProjectNonTargetAnalysis
#'   get_internal_standards.ProjectNonTargetAnalysis
#'   get_transformation_products.ProjectNonTargetAnalysis
#'   plot_fold_change.ProjectNonTargetAnalysis
#'   plot_features_profile.ProjectNonTargetAnalysis
#'   plot_features.ProjectNonTargetAnalysis
#'   map_features.ProjectNonTargetAnalysis
#'   plot_features_ms1.ProjectNonTargetAnalysis
#'   plot_features_ms2.ProjectNonTargetAnalysis
#'   plot_suspects_ms2.ProjectNonTargetAnalysis
#'   plot_features_count.ProjectNonTargetAnalysis
#' @param x A `ProjectNonTargetAnalysis` object.
#' @export
info.ProjectNonTargetAnalysis <- function(x, ...) {
  checkmate::assert_class(x, "ProjectNonTargetAnalysis")
  x$info()
}

#' @rdname ProjectNonTargetAnalysisS3
#' @param x A `ProjectNonTargetAnalysis` object.
#' @template arg-analyses
#' @template arg-ms-features
#' @template arg-ms-groups
#' @template arg-ms-components
#' @template arg-ms-mass
#' @template arg-ms-mz
#' @template arg-ms-rt
#' @template arg-ms-mobility
#' @template arg-ms-ppm
#' @template arg-ms-sec
#' @template arg-ms-millisec
#' @template arg-ms-filtered
#' @export
get_features.ProjectNonTargetAnalysis <- function(
    x,
    analyses = NULL,
    features = NULL,
    groups = NULL,
    components = NULL,
    mass = NULL,
    mz = NULL,
    rt = NULL,
    mobility = NULL,
    ppm = 20,
    sec = 60,
    millisec = 5,
    filtered = FALSE,
    ...) {
  checkmate::assert_class(x, "ProjectNonTargetAnalysis")
  x$get_features(
    analyses = analyses,
    features = features,
    groups = groups,
    components = components,
    mass = mass,
    mz = mz,
    rt = rt,
    mobility = mobility,
    ppm = ppm,
    sec = sec,
    millisec = millisec,
    filtered = filtered
  )
}

#' @rdname ProjectNonTargetAnalysisS3
#' @param x A `ProjectNonTargetAnalysis` object.
#' @template arg-analyses
#' @template arg-ms-filtered
#' @export
get_features_count.ProjectNonTargetAnalysis <- function(x, analyses = NULL, filtered = FALSE) {
  checkmate::assert_class(x, "ProjectNonTargetAnalysis")
  x$get_features_count(analyses = analyses, filtered = filtered)
}

#' @rdname ProjectNonTargetAnalysisS3
#' @param x A `ProjectNonTargetAnalysis` object.
#' @template arg-analyses
#' @template arg-ms-groups
#' @template arg-ms-mass
#' @template arg-ms-mz
#' @template arg-ms-rt
#' @template arg-ms-mobility
#' @template arg-ms-ppm
#' @template arg-ms-sec
#' @template arg-ms-millisec
#' @template arg-ms-filtered
#' @export
get_features_profile.ProjectNonTargetAnalysis <- function(
    x,
    analyses = NULL,
    groups = NULL,
    mass = NULL,
    mz = NULL,
    rt = NULL,
    mobility = NULL,
    ppm = 20,
    sec = 60,
    millisec = 5,
    filtered = FALSE,
    ...) {
  checkmate::assert_class(x, "ProjectNonTargetAnalysis")
  x$get_features_profile(
    analyses = analyses,
    groups = groups,
    mass = mass,
    mz = mz,
    rt = rt,
    mobility = mobility,
    ppm = ppm,
    sec = sec,
    millisec = millisec,
    filtered = filtered
  )
}

#' @rdname ProjectNonTargetAnalysisS3
#' @param x A `ProjectNonTargetAnalysis` object.
#' @template arg-analyses
#' @template arg-ms-groups
#' @template arg-ms-mass
#' @template arg-ms-mz
#' @template arg-ms-rt
#' @template arg-ms-mobility
#' @template arg-ms-ppm
#' @template arg-ms-sec
#' @template arg-ms-millisec
#' @template arg-ms-filtered
#' @template arg-plot-groupBy
#' @template arg-normalized
#' @template arg-yLab
#' @template arg-title
#' @template arg-interactive
#' @template arg-showLegend
#' @export
plot_features_profile.ProjectNonTargetAnalysis <- function(
    x,
    analyses = NULL,
    groups = NULL,
    mass = NULL,
    mz = NULL,
    rt = NULL,
    mobility = NULL,
    ppm = 20,
    sec = 60,
    millisec = 5,
    filtered = FALSE,
    groupBy = "analysis",
    normalized = FALSE,
    yLab = NULL,
    title = NULL,
    interactive = TRUE,
    showLegend = TRUE,
    ...) {
  checkmate::assert_class(x, "ProjectNonTargetAnalysis")
  x$plot_features_profile(
    analyses = analyses,
    groups = groups,
    mass = mass,
    mz = mz,
    rt = rt,
    mobility = mobility,
    ppm = ppm,
    sec = sec,
    millisec = millisec,
    filtered = filtered,
    groupBy = groupBy,
    normalized = normalized,
    yLab = yLab,
    title = title,
    interactive = interactive,
    showLegend = showLegend
  )
}

#' @rdname ProjectNonTargetAnalysisS3
#' @param x A `ProjectNonTargetAnalysis` object.
#' @template arg-analyses
#' @template arg-ms-features
#' @template arg-ms-groups
#' @template arg-ms-components
#' @template arg-ms-mass
#' @template arg-ms-mz
#' @template arg-ms-rt
#' @template arg-ms-mobility
#' @template arg-ms-ppm
#' @template arg-ms-sec
#' @template arg-ms-millisec
#' @template arg-ms-filtered
#' @template arg-labs
#' @template arg-plot-groupBy
#' @template arg-interactive
#' @param showDetails Logical, show hover details in interactive plots.
#' @export
plot_features.ProjectNonTargetAnalysis <- function(
    x,
    analyses = NULL,
    features = NULL,
    groups = NULL,
    components = NULL,
    mass = NULL,
    mz = NULL,
    rt = NULL,
    mobility = NULL,
    ppm = 20,
    sec = 60,
    millisec = 5,
    filtered = FALSE,
    xLab = NULL,
    yLab = NULL,
    title = NULL,
    groupBy = "feature",
    interactive = TRUE,
    showDetails = FALSE,
    ...) {
  checkmate::assert_class(x, "ProjectNonTargetAnalysis")
  x$plot_features(
    analyses = analyses,
    features = features,
    groups = groups,
    components = components,
    mass = mass,
    mz = mz,
    rt = rt,
    mobility = mobility,
    ppm = ppm,
    sec = sec,
    millisec = millisec,
    filtered = filtered,
    xLab = xLab,
    yLab = yLab,
    title = title,
    groupBy = groupBy,
    interactive = interactive,
    showDetails = showDetails
  )
}

#' @rdname ProjectNonTargetAnalysisS3
#' @param x A `ProjectNonTargetAnalysis` object.
#' @template arg-analyses
#' @template arg-ms-features
#' @template arg-ms-groups
#' @template arg-ms-components
#' @template arg-ms-mass
#' @template arg-ms-mz
#' @template arg-ms-rt
#' @template arg-ms-mobility
#' @template arg-ms-ppm
#' @template arg-ms-sec
#' @template arg-ms-millisec
#' @template arg-ms-filtered
#' @template arg-labs
#' @template arg-plot-title
#' @template arg-plot-groupBy
#' @template arg-interactive
#' @param globalNormalization Logical, when TRUE normalize intensities globally across all selected features.
#' @param showDetails Logical, show hover details in interactive plots.
#' @export
map_features.ProjectNonTargetAnalysis <- function(
    x,
    analyses = NULL,
    features = NULL,
    groups = NULL,
    components = NULL,
    mass = NULL,
    mz = NULL,
    rt = NULL,
    mobility = NULL,
    ppm = 20,
    sec = 60,
    millisec = 5,
    filtered = FALSE,
    xLab = NULL,
    yLab = NULL,
    title = NULL,
    groupBy = "feature",
    globalNormalization = FALSE,
    interactive = TRUE,
    showDetails = FALSE,
    ...) {
  checkmate::assert_class(x, "ProjectNonTargetAnalysis")
  x$map_features(
    analyses = analyses,
    features = features,
    groups = groups,
    components = components,
    mass = mass,
    mz = mz,
    rt = rt,
    mobility = mobility,
    ppm = ppm,
    sec = sec,
    millisec = millisec,
    filtered = filtered,
    xLab = xLab,
    yLab = yLab,
    title = title,
    groupBy = groupBy,
    globalNormalization = globalNormalization,
    interactive = interactive,
    showDetails = showDetails
  )
}

#' @rdname ProjectNonTargetAnalysisS3
#' @param x A `ProjectNonTargetAnalysis` object.
#' @template arg-analyses
#' @template arg-ms-features
#' @template arg-ms-groups
#' @template arg-ms-components
#' @template arg-ms-mass
#' @template arg-ms-mz
#' @template arg-ms-rt
#' @template arg-ms-mobility
#' @template arg-ms-ppm
#' @template arg-ms-sec
#' @template arg-ms-millisec
#' @template arg-normalized
#' @template arg-ms-filtered
#' @template arg-plot-groupBy
#' @export
plot_features_ms1.ProjectNonTargetAnalysis <- function(
    x,
    analyses = NULL,
    features = NULL,
    groups = NULL,
    components = NULL,
    mass = NULL,
    mz = NULL,
    rt = NULL,
    mobility = NULL,
    ppm = 20,
    sec = 60,
    millisec = 5,
    normalized = FALSE,
    filtered = FALSE,
    xLab = NULL,
    yLab = NULL,
    title = NULL,
    groupBy = "feature",
    showText = TRUE,
    interactive = TRUE,
    ...) {
  checkmate::assert_class(x, "ProjectNonTargetAnalysis")
  x$plot_features_ms1(
    analyses = analyses,
    features = features,
    groups = groups,
    components = components,
    mass = mass,
    mz = mz,
    rt = rt,
    mobility = mobility,
    ppm = ppm,
    sec = sec,
    millisec = millisec,
    normalized = normalized,
    filtered = filtered,
    xLab = xLab,
    yLab = yLab,
    title = title,
    groupBy = groupBy,
    showText = showText,
    interactive = interactive
  )
}

#' @rdname ProjectNonTargetAnalysisS3
#' @param x A `ProjectNonTargetAnalysis` object.
#' @template arg-analyses
#' @template arg-ms-features
#' @template arg-ms-groups
#' @template arg-ms-components
#' @template arg-ms-mass
#' @template arg-ms-mz
#' @template arg-ms-rt
#' @template arg-ms-mobility
#' @template arg-ms-ppm
#' @template arg-ms-sec
#' @template arg-ms-millisec
#' @template arg-normalized
#' @template arg-ms-filtered
#' @template arg-plot-groupBy
#' @export
plot_features_ms2.ProjectNonTargetAnalysis <- function(
    x,
    analyses = NULL,
    features = NULL,
    groups = NULL,
    components = NULL,
    mass = NULL,
    mz = NULL,
    rt = NULL,
    mobility = NULL,
    ppm = 20,
    sec = 60,
    millisec = 5,
    normalized = TRUE,
    filtered = FALSE,
    xLab = NULL,
    yLab = NULL,
    title = NULL,
    groupBy = "feature",
    showText = TRUE,
    interactive = TRUE,
    ...) {
  checkmate::assert_class(x, "ProjectNonTargetAnalysis")
  x$plot_features_ms2(
    analyses = analyses,
    features = features,
    groups = groups,
    components = components,
    mass = mass,
    mz = mz,
    rt = rt,
    mobility = mobility,
    ppm = ppm,
    sec = sec,
    millisec = millisec,
    normalized = normalized,
    filtered = filtered,
    xLab = xLab,
    yLab = yLab,
    title = title,
    groupBy = groupBy,
    showText = showText,
    interactive = interactive
  )
}

#' @rdname ProjectNonTargetAnalysisS3
#' @param x A `ProjectNonTargetAnalysis` object.
#' @template arg-analyses
#' @template arg-ms-features
#' @template arg-ms-groups
#' @template arg-ms-mass
#' @template arg-ms-mz
#' @template arg-ms-rt
#' @template arg-ms-mobility
#' @template arg-ms-ppm
#' @template arg-ms-sec
#' @template arg-ms-millisec
#' @template arg-normalized
#' @template arg-ms-filtered
#' @template arg-plot-groupBy
#' @export
plot_suspects_ms2.ProjectNonTargetAnalysis <- function(
    x,
    analyses = NULL,
    features = NULL,
    groups = NULL,
    mass = NULL,
    mz = NULL,
    rt = NULL,
    mobility = NULL,
    ppm = 20,
    sec = 60,
    millisec = 5,
    normalized = TRUE,
    filtered = FALSE,
    xLab = NULL,
    yLab = NULL,
    title = NULL,
    groupBy = c("feature", "name"),
    showText = TRUE,
    interactive = TRUE,
    showLegend = TRUE,
    ...) {
  checkmate::assert_class(x, "ProjectNonTargetAnalysis")
  x$plot_suspects_ms2(
    analyses = analyses,
    features = features,
    groups = groups,
    mass = mass,
    mz = mz,
    rt = rt,
    mobility = mobility,
    ppm = ppm,
    sec = sec,
    millisec = millisec,
    normalized = normalized,
    filtered = filtered,
    xLab = xLab,
    yLab = yLab,
    title = title,
    groupBy = groupBy,
    showText = showText,
    interactive = interactive,
    showLegend = showLegend
  )
}

#' @rdname ProjectNonTargetAnalysisS3
#' @param x A `ProjectNonTargetAnalysis` object.
#' @param replicatesIn Character vector with replicate names used as denominator.
#' @param replicatesOut Character vector with replicate names used as numerator.
#' @template arg-ms-groups
#' @template arg-ms-mass
#' @template arg-ms-mz
#' @template arg-ms-rt
#' @template arg-ms-mobility
#' @template arg-ms-ppm
#' @template arg-ms-sec
#' @template arg-ms-millisec
#' @template arg-ms-filtered
#' @param constantThreshold Numeric threshold used to mark features as constant.
#' @param eliminationThreshold Numeric threshold used to mark features as eliminated.
#' @template arg-ms-correctIntensity
#' @param fillZerosWithLowerLimit Logical; replace zeros before fold-change calculation.
#' @param lowerLimit Optional lower limit used when filling zeros.
#' @export
get_fold_change.ProjectNonTargetAnalysis <- function(
    x,
    replicatesIn = NULL,
    replicatesOut = NULL,
    groups = NULL,
    mass = NULL,
    mz = NULL,
    rt = NULL,
    mobility = NULL,
    ppm = 4,
    sec = 10,
    millisec = 5,
    filtered = FALSE,
    constantThreshold = 0.5,
    eliminationThreshold = 0.2,
    correctIntensity = FALSE,
    fillZerosWithLowerLimit = FALSE,
    lowerLimit = NA_real_,
    ...) {
  checkmate::assert_class(x, "ProjectNonTargetAnalysis")
  x$get_fold_change(
    replicatesIn = replicatesIn,
    replicatesOut = replicatesOut,
    groups = groups,
    mass = mass,
    mz = mz,
    rt = rt,
    mobility = mobility,
    ppm = ppm,
    sec = sec,
    millisec = millisec,
    filtered = filtered,
    constantThreshold = constantThreshold,
    eliminationThreshold = eliminationThreshold,
    correctIntensity = correctIntensity,
    fillZerosWithLowerLimit = fillZerosWithLowerLimit,
    lowerLimit = lowerLimit
  )
}

#' @rdname ProjectNonTargetAnalysisS3
#' @param x A `ProjectNonTargetAnalysis` object.
#' @template arg-analyses
#' @template arg-ms-features
#' @template arg-ms-groups
#' @template arg-ms-mass
#' @template arg-ms-mz
#' @template arg-ms-rt
#' @template arg-ms-mobility
#' @template arg-ms-ppm
#' @template arg-ms-sec
#' @template arg-ms-millisec
#' @export
get_suspects.ProjectNonTargetAnalysis <- function(
    x,
    analyses = NULL,
    features = NULL,
    groups = NULL,
    mass = NULL,
    mz = NULL,
    rt = NULL,
    mobility = NULL,
    ppm = 20,
    sec = 60,
    millisec = 5,
    ...) {
  checkmate::assert_class(x, "ProjectNonTargetAnalysis")
  x$get_suspects(
    analyses = analyses,
    features = features,
    groups = groups,
    mass = mass,
    mz = mz,
    rt = rt,
    mobility = mobility,
    ppm = ppm,
    sec = sec,
    millisec = millisec
  )
}

#' @rdname ProjectNonTargetAnalysisS3
#' @param x A `ProjectNonTargetAnalysis` object.
#' @template arg-analyses
#' @template arg-ms-features
#' @template arg-ms-groups
#' @template arg-ms-mass
#' @template arg-ms-mz
#' @template arg-ms-rt
#' @template arg-ms-mobility
#' @template arg-ms-ppm
#' @template arg-ms-sec
#' @template arg-ms-millisec
#' @export
get_internal_standards.ProjectNonTargetAnalysis <- function(
    x,
    analyses = NULL,
    features = NULL,
    groups = NULL,
    mass = NULL,
    mz = NULL,
    rt = NULL,
    mobility = NULL,
    ppm = 20,
    sec = 60,
    millisec = 5,
    ...) {
  checkmate::assert_class(x, "ProjectNonTargetAnalysis")
  x$get_internal_standards(
    analyses = analyses,
    features = features,
    groups = groups,
    mass = mass,
    mz = mz,
    rt = rt,
    mobility = mobility,
    ppm = ppm,
    sec = sec,
    millisec = millisec
  )
}

#' @rdname ProjectNonTargetAnalysisS3
#' @param x A `ProjectNonTargetAnalysis` object.
#' @param parents Optional parent names to keep.
#' @template arg-ms-groups
#' @export
get_transformation_products.ProjectNonTargetAnalysis <- function(x, parents = NULL, groups = NULL, ...) {
  checkmate::assert_class(x, "ProjectNonTargetAnalysis")
  x$get_transformation_products(parents = parents, groups = groups)
}

#' @rdname ProjectNonTargetAnalysisS3
#' @param x A `ProjectNonTargetAnalysis` object.
#' @param replicatesIn Character vector with replicate names used as denominator.
#' @param replicatesOut Character vector with replicate names used as numerator.
#' @template arg-ms-groups
#' @template arg-ms-mass
#' @template arg-ms-mz
#' @template arg-ms-rt
#' @template arg-ms-mobility
#' @template arg-ms-ppm
#' @template arg-ms-sec
#' @template arg-ms-millisec
#' @template arg-ms-filtered
#' @param constantThreshold Numeric threshold used to mark features as constant.
#' @param eliminationThreshold Numeric threshold used to mark features as eliminated.
#' @template arg-ms-correctIntensity
#' @param fillZerosWithLowerLimit Logical; replace zeros before fold-change calculation.
#' @param lowerLimit Optional lower limit used when filling zeros.
#' @template arg-normalized
#' @template arg-yLab
#' @template arg-title
#' @template arg-interactive
#' @template arg-showLegend
#' @export
plot_fold_change.ProjectNonTargetAnalysis <- function(
    x,
    replicatesIn = NULL,
    replicatesOut = NULL,
    groups = NULL,
    mass = NULL,
    mz = NULL,
    rt = NULL,
    mobility = NULL,
    ppm = 4,
    sec = 10,
    millisec = 5,
    filtered = FALSE,
    constantThreshold = 0.5,
    eliminationThreshold = 0.2,
    correctIntensity = FALSE,
    fillZerosWithLowerLimit = FALSE,
    lowerLimit = NA_real_,
    normalized = TRUE,
    yLab = NULL,
    title = NULL,
    interactive = TRUE,
    showLegend = TRUE,
    ...) {
  checkmate::assert_class(x, "ProjectNonTargetAnalysis")
  x$plot_fold_change(
    replicatesIn = replicatesIn,
    replicatesOut = replicatesOut,
    groups = groups,
    mass = mass,
    mz = mz,
    rt = rt,
    mobility = mobility,
    ppm = ppm,
    sec = sec,
    millisec = millisec,
    filtered = filtered,
    constantThreshold = constantThreshold,
    eliminationThreshold = eliminationThreshold,
    correctIntensity = correctIntensity,
    fillZerosWithLowerLimit = fillZerosWithLowerLimit,
    lowerLimit = lowerLimit,
    normalized = normalized,
    yLab = yLab,
    title = title,
    interactive = interactive,
    showLegend = showLegend
  )
}

#' @rdname ProjectNonTargetAnalysisS3
#' @param x A `ProjectNonTargetAnalysis` object.
#' @template arg-ms-groups
#' @param modal Character vector of transformation-product modalities to keep.
#' @template arg-normalized
#' @template arg-labs
#' @template arg-title
#' @template arg-interactive
#' @template arg-showLegend
#' @export
plot_transformation_products.ProjectNonTargetAnalysis <- function(
    x,
    groups = NULL,
    modal = c("all", "dda", "dia", "ms1"),
    normalized = TRUE,
    xLab = NULL,
    yLab = NULL,
    title = NULL,
    interactive = TRUE,
    showLegend = TRUE,
    ...) {
  checkmate::assert_class(x, "ProjectNonTargetAnalysis")
  x$plot_transformation_products(
    groups = groups,
    modal = modal,
    normalized = normalized,
    xLab = xLab,
    yLab = yLab,
    title = title,
    interactive = interactive,
    showLegend = showLegend
  )
}

#' @rdname ProjectNonTargetAnalysisS3
#' @param x A `ProjectNonTargetAnalysis` object.
#' @template arg-analyses
#' @template arg-ms-filtered
#' @template arg-yLab
#' @template arg-title
#' @template arg-plot-groupBy
#' @template arg-showLegend
#' @template arg-showHoverText
#' @export
plot_features_count.ProjectNonTargetAnalysis <- function(
    x,
    analyses = NULL,
    filtered = FALSE,
    yLab = NULL,
    title = NULL,
    groupBy = "analysis",
    showLegend = TRUE,
    showHoverText = TRUE) {
  checkmate::assert_class(x, "ProjectNonTargetAnalysis")
  x$plot_features_count(
    analyses = analyses,
    filtered = filtered,
    yLab = yLab,
    title = title,
    groupBy = groupBy,
    showLegend = showLegend,
    showHoverText = showHoverText
  )
}
