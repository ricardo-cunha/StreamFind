#' @title Project Non-Target Analysis R6 Class
#' @description R6 child of `ProjectMassSpec` exposing the non-target analysis-focused NTS interface.
#' @template arg-Project-db
#' @template arg-Project-project-id
#' @template arg-ProjectNonTargetAnalysis-ptr
#' @template arg-ProjectNonTargetAnalysis-mass-spec-ptr
#' @template arg-ProjectMassSpec-analyses
#' @template arg-ProjectNonTargetAnalysis-features
#' @template arg-ProjectNonTargetAnalysis-groups
#' @template arg-ProjectNonTargetAnalysis-names
#' @template arg-ProjectNonTargetAnalysis-components
#' @template arg-ProjectMassSpec-mass
#' @template arg-ProjectMassSpec-mz
#' @template arg-ProjectMassSpec-rt
#' @template arg-ProjectMassSpec-mobility
#' @template arg-ProjectMassSpec-ppm
#' @template arg-ProjectMassSpec-sec
#' @template arg-ProjectMassSpec-millisec
#' @template arg-ProjectNonTargetAnalysis-parents
#' @template arg-ProjectNonTargetAnalysis-filtered
#' @template arg-ProjectNonTargetAnalysis-corrected
#' @template arg-ProjectMassSpec-plot-groupBy
#' @template arg-ProjectMassSpec-normalized
#' @template arg-ms-rtWindowVal
#' @template arg-ProjectNonTargetAnalysis-refBlankReplicate
#' @template arg-ProjectNonTargetAnalysis-yLab
#' @template arg-ProjectNonTargetAnalysis-title
#' @template arg-ProjectNonTargetAnalysis-interactive
#' @template arg-ProjectNonTargetAnalysis-darkMode
#' @template arg-ProjectNonTargetAnalysis-showLegend
#' @template arg-ProjectNonTargetAnalysis-labs
#' @template arg-ms-colorBy
#' @template arg-legendNames
#' @template arg-ms-downsize
#' @template arg-ProjectNonTargetAnalysis-showHoverText
#' @template arg-ProjectNonTargetAnalysis-showDetails
#' @template arg-ProjectNonTargetAnalysis-showText
#' @template arg-ProjectNonTargetAnalysis-globalNormalization
#' @template arg-ProjectNonTargetAnalysis-correctIntensity
#' @template arg-ProjectNonTargetAnalysis-showMS2
#' @template arg-ProjectNonTargetAnalysis-showIntensityProfile
#' @template arg-ProjectNonTargetAnalysis-replicatesIn
#' @template arg-ProjectNonTargetAnalysis-replicatesOut
#' @template arg-ProjectNonTargetAnalysis-constantThreshold
#' @template arg-ProjectNonTargetAnalysis-eliminationThreshold
#' @template arg-ProjectNonTargetAnalysis-fillZerosWithLowerLimit
#' @template arg-ProjectNonTargetAnalysis-lowerLimit
#' @template arg-renderEngine
#' @template arg-Project-ellipsis
#' @template arg-ProjectMassSpec-file-paths
#' @template arg-ProjectMassSpec-replicates
#' @template arg-ProjectMassSpec-blanks
#' @keywords internal
#' @export

.format_nta_adduct_hover <- function(adduct, label = "adduct") {
  adduct_chr <- as.character(adduct)
  adduct_chr[is.na(adduct_chr)] <- ""
  vapply(adduct_chr, function(x) {
    if (!nzchar(x)) {
      return(paste0(label, ": "))
    }
    if (!startsWith(x, "cat=")) {
      return(paste0(label, ": ", x))
    }
    parts <- strsplit(x, " \\| ", fixed = FALSE)[[1]]
    parts <- paste0("&nbsp;&nbsp;", parts)
    paste0(label, ":<br>", paste(parts, collapse = "<br>"))
  }, character(1))
}

.format_nta_hover_field <- function(field, value) {
  value_chr <- as.character(value)
  value_chr[is.na(value_chr)] <- ""
  if (identical(field, "adduct")) {
    return(.format_nta_adduct_hover(value_chr))
  }
  paste0(field, ": ", value_chr)
}

ProjectNonTargetAnalysis <- R6::R6Class(
  classname = "ProjectNonTargetAnalysis",
  inherit = ProjectMassSpec,
  cloneable = FALSE,
  private = list(
    .nta_ptr = NULL
  ),
  public = list(
    #' @description Create an NTS domain wrapper on top of a shared Mass Spec project.
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
      nta_ptr_res <- .pull_internal_init_arg(mass_spec_ptr_res$dots, ".nta_ptr")
      .nta_ptr <- nta_ptr_res$value
      .assert_only_internal_init_args(nta_ptr_res$dots, "ProjectNonTargetAnalysis$initialize()")
      super$initialize(db = db, project_id = project_id, .ptr = .ptr, .mass_spec_ptr = .mass_spec_ptr, file_paths = file_paths, replicates = replicates, blanks = blanks)
      private$.nta_ptr <- if (is.null(.nta_ptr)) {
        rcpp_project_non_target_analysis_new(self$get_ptr())
      } else {
        .nta_ptr
      }
      if (!is.null(.nta_ptr) && length(file_paths) > 0) {
        self$add_analyses(file_paths = file_paths, replicates = replicates, blanks = blanks)
      }
    },
    #' @description Return the native NTS pointer.
    get_nts_ptr = function() {
      private$.nta_ptr
    },
    #' @description Return project-owned NTS method metadata.
    #' @return A named list of `Method` metadata objects.
    available_processing_methods = function() {
      available_processing_methods.Project(self)
    },
    #' @description Return a compact per-analysis feature summary.
    info = function() {
      info.ProjectNonTargetAnalysis(self)
    },
    #' @description Return shared `NTS_FEATURES` rows for selected analyses.
    get_features = function(analyses = NULL,
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
      get_features.ProjectNonTargetAnalysis(self, analyses = analyses, features = features, groups = groups, components = components, mass = mass, mz = mz, rt = rt, mobility = mobility, ppm = ppm, sec = sec, millisec = millisec, filtered = filtered)
    },
    #' @description Return MS1 feature spectra for selected analyses.
    get_features_ms1 = function(analyses = NULL,
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
                                filtered = FALSE) {
      get_features_ms1.ProjectNonTargetAnalysis(self, analyses = analyses, features = features, groups = groups, components = components, mass = mass, mz = mz, rt = rt, mobility = mobility, ppm = ppm, sec = sec, millisec = millisec, normalized = normalized, filtered = filtered)
    },
    #' @description Return MS2 feature spectra for selected analyses.
    get_features_ms2 = function(analyses = NULL,
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
                                filtered = FALSE) {
      get_features_ms2.ProjectNonTargetAnalysis(self, analyses = analyses, features = features, groups = groups, components = components, mass = mass, mz = mz, rt = rt, mobility = mobility, ppm = ppm, sec = sec, millisec = millisec, normalized = normalized, filtered = filtered)
    },
    #' @description Return a per-analysis summary of shared `NTS_FEATURES` rows.
    get_features_count = function(analyses = NULL, filtered = FALSE) {
      get_features_count.ProjectNonTargetAnalysis(self, analyses = analyses, filtered = filtered)
    },
    #' @description Return TIC-based matrix-suppression profiles for selected analyses.
    get_matrix_suppression = function(analyses = NULL,
                                      rtWindowVal = 10,
                                      refBlankReplicate = NA_character_) {
      get_matrix_suppression.ProjectNonTargetAnalysis(
        self,
        analyses = analyses,
        rtWindowVal = rtWindowVal,
        refBlankReplicate = refBlankReplicate
      )
    },
    #' @description Plot TIC-based matrix-suppression profiles for selected analyses.
    plot_matrix_suppression = function(analyses = NULL,
                                       rtWindowVal = 10,
                                       refBlankReplicate = NA_character_,
                                       xLab = NULL,
                                       yLab = NULL,
                                       title = NULL,
                                       colorBy = "analyses",
                                       legendNames = NULL,
                                       downsize = 1,
                                       interactive = TRUE,
                                       showLegend = TRUE,
                                       renderEngine = "webgl",
                                       darkMode = FALSE) {
      plot_matrix_suppression.ProjectNonTargetAnalysis(
        self,
        analyses = analyses,
        rtWindowVal = rtWindowVal,
        refBlankReplicate = refBlankReplicate,
        xLab = xLab,
        yLab = yLab,
        title = title,
        colorBy = colorBy,
        legendNames = legendNames,
        downsize = downsize,
        interactive = interactive,
        showLegend = showLegend,
        renderEngine = renderEngine,
        darkMode = darkMode
      )
    },
    #' @description Plot the number of features for selected analyses.
    plot_features_count = function(analyses = NULL,
                                   filtered = FALSE,
                                   yLab = NULL,
                                   title = NULL,
                                   groupBy = "analysis",
                                   showLegend = TRUE,
                                   showHoverText = TRUE,
                                   darkMode = FALSE) {
      plot_features_count.ProjectNonTargetAnalysis(self, analyses = analyses, filtered = filtered, yLab = yLab, title = title, groupBy = groupBy, showLegend = showLegend, showHoverText = showHoverText, darkMode = darkMode)
    },
    #' @description Return feature-group profiles across analyses.
    get_features_profile = function(analyses = NULL,
                                    groups = NULL,
                                    mass = NULL,
                                    mz = NULL,
                                    rt = NULL,
                                    mobility = NULL,
                                    ppm = 20,
                                    sec = 60,
                                    millisec = 5,
                                    filtered = FALSE,
                                    corrected = FALSE) {
      get_features_profile.ProjectNonTargetAnalysis(self, analyses = analyses, groups = groups, mass = mass, mz = mz, rt = rt, mobility = mobility, ppm = ppm, sec = sec, millisec = millisec, filtered = filtered, corrected = corrected)
    },
    #' @description Plot feature-group profiles across analyses or replicates.
    plot_features_profile = function(analyses = NULL,
                                     groups = NULL,
                                     mass = NULL,
                                     mz = NULL,
                                     rt = NULL,
                                     mobility = NULL,
                                     ppm = 20,
                                     sec = 60,
                                     millisec = 5,
                                     filtered = FALSE,
                                     corrected = FALSE,
                                     groupBy = "analysis",
                                     normalized = FALSE,
                                     yLab = NULL,
                                     title = NULL,
                                     interactive = TRUE,
                                     showLegend = TRUE,
                                     darkMode = FALSE) {
      plot_features_profile.ProjectNonTargetAnalysis(self, analyses = analyses, groups = groups, mass = mass, mz = mz, rt = rt, mobility = mobility, ppm = ppm, sec = sec, millisec = millisec, filtered = filtered, corrected = corrected, groupBy = groupBy, normalized = normalized, yLab = yLab, title = title, interactive = interactive, showLegend = showLegend, darkMode = darkMode)
    },
    #' @description Plot EIC traces for selected features.
    plot_features = function(analyses = NULL,
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
                             darkMode = FALSE) {
      plot_features.ProjectNonTargetAnalysis(self, analyses = analyses, features = features, groups = groups, components = components, mass = mass, mz = mz, rt = rt, mobility = mobility, ppm = ppm, sec = sec, millisec = millisec, filtered = filtered, xLab = xLab, yLab = yLab, title = title, groupBy = groupBy, interactive = interactive, showDetails = showDetails, darkMode = darkMode)
    },
    #' @description Plot RT versus m/z traces for selected features.
    map_features = function(analyses = NULL,
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
                            darkMode = FALSE) {
      map_features.ProjectNonTargetAnalysis(self, analyses = analyses, features = features, groups = groups, components = components, mass = mass, mz = mz, rt = rt, mobility = mobility, ppm = ppm, sec = sec, millisec = millisec, filtered = filtered, xLab = xLab, yLab = yLab, title = title, groupBy = groupBy, globalNormalization = globalNormalization, interactive = interactive, showDetails = showDetails, darkMode = darkMode)
    },
    #' @description Plot MS1 spectra for selected features.
    plot_features_ms1 = function(analyses = NULL,
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
                                 darkMode = FALSE) {
      plot_features_ms1.ProjectNonTargetAnalysis(self, analyses = analyses, features = features, groups = groups, components = components, mass = mass, mz = mz, rt = rt, mobility = mobility, ppm = ppm, sec = sec, millisec = millisec, normalized = normalized, filtered = filtered, xLab = xLab, yLab = yLab, title = title, groupBy = groupBy, showText = showText, interactive = interactive, darkMode = darkMode)
    },
    #' @description Plot MS2 spectra for selected features.
    plot_features_ms2 = function(analyses = NULL,
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
                                 darkMode = FALSE) {
      plot_features_ms2.ProjectNonTargetAnalysis(self, analyses = analyses, features = features, groups = groups, components = components, mass = mass, mz = mz, rt = rt, mobility = mobility, ppm = ppm, sec = sec, millisec = millisec, normalized = normalized, filtered = filtered, xLab = xLab, yLab = yLab, title = title, groupBy = groupBy, showText = showText, interactive = interactive, darkMode = darkMode)
    },
    #' @description Return shared `NTS_INTERNAL_STANDARDS` rows for selected analyses.
    get_internal_standards = function(analyses = NULL,
                                      features = NULL,
                                      groups = NULL,
                                      mass = NULL,
                                      mz = NULL,
                                      rt = NULL,
                                      mobility = NULL,
                                      ppm = 20,
                                      sec = 60,
                                      millisec = 5) {
      get_internal_standards.ProjectNonTargetAnalysis(self, analyses = analyses, features = features, groups = groups, mass = mass, mz = mz, rt = rt, mobility = mobility, ppm = ppm, sec = sec, millisec = millisec)
    },
    #' @description Return internal-standard intensity profiles across analyses.
    get_internal_standards_profile = function(analyses = NULL,
                                              features = NULL,
                                              names = NULL,
                                              mass = NULL,
                                              mz = NULL,
                                              rt = NULL,
                                              mobility = NULL,
                                              ppm = 20,
                                              sec = 60,
                                              millisec = 5,
                                              normalized = FALSE) {
      get_internal_standards_profile.ProjectNonTargetAnalysis(self, analyses = analyses, features = features, names = names, mass = mass, mz = mz, rt = rt, mobility = mobility, ppm = ppm, sec = sec, millisec = millisec, normalized = normalized)
    },
    #' @description Plot internal-standard intensity profiles across analyses or replicates.
    plot_internal_standards_profile = function(analyses = NULL,
                                               features = NULL,
                                               names = NULL,
                                               mass = NULL,
                                               mz = NULL,
                                               rt = NULL,
                                               mobility = NULL,
                                               ppm = 20,
                                               sec = 60,
                                               millisec = 5,
                                               groupBy = "analysis",
                                               normalized = FALSE,
                                               yLab = NULL,
                                               title = NULL,
                                               interactive = TRUE,
                                               showLegend = TRUE,
                                               darkMode = FALSE) {
      plot_internal_standards_profile.ProjectNonTargetAnalysis(self, analyses = analyses, features = features, names = names, mass = mass, mz = mz, rt = rt, mobility = mobility, ppm = ppm, sec = sec, millisec = millisec, groupBy = groupBy, normalized = normalized, yLab = yLab, title = title, interactive = interactive, showLegend = showLegend, darkMode = darkMode)
    },
    #' @description Return shared `NTS_SUSPECTS` rows for selected analyses.
    get_suspects = function(analyses = NULL,
                            features = NULL,
                            groups = NULL,
                            mass = NULL,
                            mz = NULL,
                            rt = NULL,
                            mobility = NULL,
                            ppm = 20,
                            sec = 60,
                            millisec = 5) {
      get_suspects.ProjectNonTargetAnalysis(self, analyses = analyses, features = features, groups = groups, mass = mass, mz = mz, rt = rt, mobility = mobility, ppm = ppm, sec = sec, millisec = millisec)
    },
    #' @description Plot suspect MS2 spectra for selected features.
    plot_suspects_ms2 = function(analyses = NULL,
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
                                 darkMode = FALSE) {
      plot_suspects_ms2.ProjectNonTargetAnalysis(self, analyses = analyses, features = features, groups = groups, mass = mass, mz = mz, rt = rt, mobility = mobility, ppm = ppm, sec = sec, millisec = millisec, normalized = normalized, filtered = filtered, xLab = xLab, yLab = yLab, title = title, groupBy = groupBy, showText = showText, interactive = interactive, showLegend = showLegend, darkMode = darkMode)
    },
    #' @description Return fold-change categories between replicate groups.
    get_fold_change = function(replicatesIn = NULL,
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
      get_fold_change.ProjectNonTargetAnalysis(self, replicatesIn = replicatesIn, replicatesOut = replicatesOut, groups = groups, mass = mass, mz = mz, rt = rt, mobility = mobility, ppm = ppm, sec = sec, millisec = millisec, filtered = filtered, constantThreshold = constantThreshold, eliminationThreshold = eliminationThreshold, correctIntensity = correctIntensity, fillZerosWithLowerLimit = fillZerosWithLowerLimit, lowerLimit = lowerLimit)
    },
    #' @description Plot fold-change categories between replicate groups.
    plot_fold_change = function(replicatesIn = NULL,
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
      plot_fold_change.ProjectNonTargetAnalysis(self, replicatesIn = replicatesIn, replicatesOut = replicatesOut, groups = groups, mass = mass, mz = mz, rt = rt, mobility = mobility, ppm = ppm, sec = sec, millisec = millisec, filtered = filtered, constantThreshold = constantThreshold, eliminationThreshold = eliminationThreshold, correctIntensity = correctIntensity, fillZerosWithLowerLimit = fillZerosWithLowerLimit, lowerLimit = lowerLimit, normalized = normalized, yLab = yLab, title = title, interactive = interactive, showLegend = showLegend)
    },
    #' @description Return shared `NTS_TRANSFORMATION_PRODUCTS` rows.
    get_transformation_products = function(parents = NULL, groups = NULL) {
      get_transformation_products.ProjectNonTargetAnalysis(self, parents = parents, groups = groups)
    },
    #' @description Plot a transformation-products network.
    plot_transformation_products = function(groups = NULL, showMS2 = FALSE, showIntensityProfile = FALSE) {
      plot_transformation_products.ProjectNonTargetAnalysis(self, groups = groups, showMS2 = showMS2, showIntensityProfile = showIntensityProfile)
    },
    #' @description Print a short summary.
    print = function(...) {
      print.ProjectNonTargetAnalysis(self, ...)
    },
    #' @description Show a short summary.
    show = function(...) {
      show.ProjectNonTargetAnalysis(self, ...)
    }
  )
)

#' @name ProjectNonTargetAnalysisS3
#' @title ProjectNonTargetAnalysis S3 Methods
#' @description S3 interface methods for `ProjectNonTargetAnalysis`.
#' @param x A `ProjectNonTargetAnalysis` object.
#' @template arg-Project-db
#' @template arg-Project-project-id
#' @template arg-ProjectNonTargetAnalysis-ptr
#' @template arg-ProjectNonTargetAnalysis-mass-spec-ptr
#' @template arg-ProjectMassSpec-analyses
#' @template arg-ProjectNonTargetAnalysis-features
#' @template arg-ProjectNonTargetAnalysis-groups
#' @template arg-ProjectNonTargetAnalysis-names
#' @template arg-ProjectNonTargetAnalysis-components
#' @template arg-ProjectMassSpec-mass
#' @template arg-ProjectMassSpec-mz
#' @template arg-ProjectMassSpec-rt
#' @template arg-ProjectMassSpec-mobility
#' @template arg-ProjectMassSpec-ppm
#' @template arg-ProjectMassSpec-sec
#' @template arg-ProjectMassSpec-millisec
#' @template arg-ProjectNonTargetAnalysis-filtered
#' @template arg-ProjectNonTargetAnalysis-corrected
#' @template arg-ProjectMassSpec-plot-groupBy
#' @template arg-ProjectMassSpec-normalized
#' @template arg-ms-rtWindowVal
#' @template arg-ProjectNonTargetAnalysis-refBlankReplicate
#' @template arg-ProjectNonTargetAnalysis-yLab
#' @template arg-ProjectNonTargetAnalysis-title
#' @template arg-ProjectNonTargetAnalysis-interactive
#' @template arg-ProjectNonTargetAnalysis-darkMode
#' @template arg-ProjectNonTargetAnalysis-showLegend
#' @template arg-ProjectNonTargetAnalysis-labs
#' @template arg-ms-colorBy
#' @template arg-legendNames
#' @template arg-ms-downsize
#' @template arg-ProjectNonTargetAnalysis-correctIntensity
#' @template arg-ProjectNonTargetAnalysis-showDetails
#' @template arg-ProjectNonTargetAnalysis-showText
#' @template arg-ProjectNonTargetAnalysis-globalNormalization
#' @template arg-ProjectNonTargetAnalysis-showMS2
#' @template arg-ProjectNonTargetAnalysis-showIntensityProfile
#' @template arg-ProjectNonTargetAnalysis-replicatesIn
#' @template arg-ProjectNonTargetAnalysis-replicatesOut
#' @template arg-ProjectNonTargetAnalysis-constantThreshold
#' @template arg-ProjectNonTargetAnalysis-eliminationThreshold
#' @template arg-ProjectNonTargetAnalysis-fillZerosWithLowerLimit
#' @template arg-ProjectNonTargetAnalysis-lowerLimit
#' @template arg-ProjectNonTargetAnalysis-parents
#' @template arg-ProjectNonTargetAnalysis-modal
#' @template arg-renderEngine
#' @template arg-Project-ellipsis
NULL

#' @describeIn ProjectNonTargetAnalysisS3 Return project information summary.
#' @method info ProjectNonTargetAnalysis
#' @export
info.ProjectNonTargetAnalysis <- function(x, ...) {
  checkmate::assert_class(x, "ProjectNonTargetAnalysis")
  analyses_info <- data.table::as.data.table(x$get_analyses())
  if (nrow(analyses_info) == 0) {
    return(data.table::data.table())
  }
  counts <- get_features_count(x, filtered = FALSE)
  data.table::data.table(
    analysis = analyses_info$analysis,
    replicate = analyses_info$replicate,
    blank = analyses_info$blank,
    polarity = analyses_info$polarity,
    features = counts$features[match(analyses_info$analysis, counts$analysis)],
    filtered = counts$filtered[match(analyses_info$analysis, counts$analysis)],
    feature_groups = counts$groups[match(analyses_info$analysis, counts$analysis)]
  )
}

#' @describeIn ProjectNonTargetAnalysisS3 Print a short summary.
#' @export
print.ProjectNonTargetAnalysis <- function(x, ...) {
  checkmate::assert_class(x, "ProjectNonTargetAnalysis")
  .print_project_mass_spec_summary(x, title = "ProjectNonTargetAnalysis")
  info <- try(info.ProjectNonTargetAnalysis(x), silent = TRUE)
  if (!inherits(info, "try-error") && nrow(info) > 0) {
    cat("features: ", sum(info$features, na.rm = TRUE), "\n", sep = "")
    cat("feature groups: ", sum(info$feature_groups, na.rm = TRUE), "\n", sep = "")
  }
  invisible(x)
}

#' @describeIn ProjectNonTargetAnalysisS3 Show a short summary.
#' @export
show.ProjectNonTargetAnalysis <- function(x, ...) {
  checkmate::assert_class(x, "ProjectNonTargetAnalysis")
  print.ProjectNonTargetAnalysis(x, ...)
}

.decode_project_nts_feature_spectra <- function(fts, spectrum = c("ms1", "ms2"), normalized = FALSE) {
  spectrum <- match.arg(spectrum)
  if (!data.table::is.data.table(fts)) {
    fts <- data.table::as.data.table(fts)
  }
  if (nrow(fts) == 0) {
    return(data.table::data.table())
  }

  mz_col <- paste0(spectrum, "_mz")
  intensity_col <- paste0(spectrum, "_intensity")

  spectra_list <- lapply(seq_len(nrow(fts)), function(i) {
    ft <- fts[i, ]
    has_spectrum <- !is.na(ft[[mz_col]]) &&
      nchar(ft[[mz_col]]) > 0 &&
      !is.na(ft[[intensity_col]]) &&
      nchar(ft[[intensity_col]]) > 0
    if (!has_spectrum) {
      return(data.table::data.table())
    }

    mz_dec <- rcpp_decode_string(ft[[mz_col]])
    int_dec <- rcpp_decode_string(ft[[intensity_col]])
    if (length(mz_dec) == 0 || length(mz_dec) != length(int_dec)) {
      return(data.table::data.table())
    }

    feature_group <- NA
    if ("feature_group" %in% colnames(ft)) {
      feature_group <- ft$feature_group
    } else if ("group" %in% colnames(ft)) {
      feature_group <- ft$group
    }

    feature_component <- NA
    if ("feature_component" %in% colnames(ft)) {
      feature_component <- ft$feature_component
    } else if ("component" %in% colnames(ft)) {
      feature_component <- ft$component
    }

    data.table::data.table(
      analysis = ft$analysis,
      replicate = if ("replicate" %in% colnames(ft)) ft$replicate else NA_character_,
      feature = ft$feature,
      feature_group = feature_group,
      feature_component = feature_component,
      name = if ("name" %in% colnames(ft)) ft$name else NA_character_,
      polarity = if ("polarity" %in% colnames(ft)) ft$polarity else NA_real_,
      feature_mz = if ("mz" %in% colnames(ft)) ft$mz else NA_real_,
      feature_rt = if ("rt" %in% colnames(ft)) ft$rt else NA_real_,
      pre_mz = if (identical(spectrum, "ms2") && "mz" %in% colnames(ft)) ft$mz else NA_real_,
      mz = mz_dec,
      intensity = int_dec
    )
  })

  spectra <- data.table::rbindlist(spectra_list, fill = TRUE)
  if (nrow(spectra) == 0) {
    return(data.table::data.table())
  }

  if (normalized) {
    spectra[, intensity := {
      max_intensity <- max(intensity, na.rm = TRUE)
      if (!is.finite(max_intensity) || max_intensity <= 0) {
        intensity
      } else {
        intensity / max_intensity
      }
    }, by = .(analysis, feature)]
  }

  desired_order <- c(
    "analysis",
    "replicate",
    "feature",
    "feature_group",
    "feature_component",
    "name",
    "polarity",
    "feature_mz",
    "feature_rt",
    "pre_mz",
    "mz",
    "intensity"
  )
  data.table::setcolorder(spectra, c(intersect(desired_order, colnames(spectra)), setdiff(colnames(spectra), desired_order)))
  spectra[]
}

#' @describeIn ProjectNonTargetAnalysisS3 Return shared NTS_FEATURES rows for selected analyses.
#' @method get_features ProjectNonTargetAnalysis
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
  ...
) {
  checkmate::assert_class(x, "ProjectNonTargetAnalysis")
  analyses_info <- data.table::as.data.table(x$get_analyses())
  sel_names <- .resolve_analyses_selection(analyses, analyses_info$analysis)
  if (length(sel_names) == 0) {
    return(data.table::data.table())
  }
  fts <- data.table::as.data.table(
    rcpp_project_non_target_analysis_get_features(
      x$get_nts_ptr(),
      sel_names,
      features,
      groups,
      components,
      mass,
      mz,
      rt,
      mobility,
      ppm,
      sec,
      millisec,
      filtered
    )
  )
  if (nrow(fts) == 0) {
    return(data.table::data.table())
  }
  if ("project_id" %in% colnames(fts)) {
    fts[, project_id := NULL]
  }
  rep_map <- analyses_info[, .(analysis, replicate)]
  fts <- merge(fts, rep_map, by = "analysis", all.x = TRUE)
  desired_order <- c("analysis", "replicate", "feature", "id")
  data.table::setcolorder(fts, c(intersect(desired_order, colnames(fts)), setdiff(colnames(fts), desired_order)))
  fts
}

#' @describeIn ProjectNonTargetAnalysisS3 Return decoded MS1 feature spectra for selected analyses.
#' @method get_features_ms1 ProjectNonTargetAnalysis
#' @export
get_features_ms1.ProjectNonTargetAnalysis <- function(
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
  ...
) {
  checkmate::assert_class(x, "ProjectNonTargetAnalysis")
  fts <- get_features(
    x,
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
  .decode_project_nts_feature_spectra(fts, spectrum = "ms1", normalized = normalized)
}

#' @describeIn ProjectNonTargetAnalysisS3 Return decoded MS2 feature spectra for selected analyses.
#' @method get_features_ms2 ProjectNonTargetAnalysis
#' @export
get_features_ms2.ProjectNonTargetAnalysis <- function(
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
  ...
) {
  checkmate::assert_class(x, "ProjectNonTargetAnalysis")
  fts <- get_features(
    x,
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
  .decode_project_nts_feature_spectra(fts, spectrum = "ms2", normalized = normalized)
}

#' @describeIn ProjectNonTargetAnalysisS3 Return feature counts for selected analyses.
#' @method get_features_count ProjectNonTargetAnalysis
#' @export
get_features_count.ProjectNonTargetAnalysis <- function(x, analyses = NULL, filtered = FALSE) {
  checkmate::assert_class(x, "ProjectNonTargetAnalysis")
  analyses_info <- data.table::as.data.table(x$get_analyses())
  all_names <- analyses_info$analysis
  sel_names <- .resolve_analyses_selection(analyses, all_names)
  if (length(sel_names) == 0) {
    return(data.table::data.table())
  }
  counts <- data.table::as.data.table(
    rcpp_project_non_target_analysis_get_features_count(x$get_nts_ptr(), sel_names, filtered)
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
}

#' @describeIn ProjectNonTargetAnalysisS3 Return TIC-based matrix-suppression rows for selected analyses.
#' @method get_matrix_suppression ProjectNonTargetAnalysis
#' @export
get_matrix_suppression.ProjectNonTargetAnalysis <- function(
  x,
  analyses = NULL,
  rtWindowVal = 10,
  refBlankReplicate = NA_character_,
  ...
) {
  checkmate::assert_class(x, "ProjectNonTargetAnalysis")
  analyses_info <- data.table::as.data.table(x$get_analyses())
  sel_names <- .resolve_analyses_selection(analyses, analyses_info$analysis)
  if (length(sel_names) == 0) {
    return(data.table::data.table())
  }
  ref_blank <- if (length(refBlankReplicate) == 0 || is.na(refBlankReplicate)) NULL else as.character(refBlankReplicate)
  mp <- data.table::as.data.table(
    rcpp_project_nta_get_matrix_suppression(
      x$get_nts_ptr(),
      sel_names,
      as.numeric(rtWindowVal),
      ref_blank
    )
  )
  if (nrow(mp) == 0) {
    return(data.table::data.table())
  }
  desired_order <- c("analysis", "replicate", "polarity", "level", "rt", "intensity", "mp")
  data.table::setcolorder(mp, c(intersect(desired_order, colnames(mp)), setdiff(colnames(mp), desired_order)))
  mp[]
}

#' @describeIn ProjectNonTargetAnalysisS3 Plot TIC-based matrix suppression for selected analyses.
#' @method plot_matrix_suppression ProjectNonTargetAnalysis
#' @export
plot_matrix_suppression.ProjectNonTargetAnalysis <- function(
  x,
  analyses = NULL,
  rtWindowVal = 10,
  refBlankReplicate = NA_character_,
  xLab = NULL,
  yLab = NULL,
  title = NULL,
  colorBy = "analyses",
  legendNames = NULL,
  downsize = 1,
  interactive = TRUE,
  showLegend = TRUE,
  renderEngine = "webgl",
  darkMode = FALSE,
  ...
) {
  checkmate::assert_class(x, "ProjectNonTargetAnalysis")
  mp <- get_matrix_suppression(
    x,
    analyses = analyses,
    rtWindowVal = rtWindowVal,
    refBlankReplicate = refBlankReplicate
  )
  if (nrow(mp) == 0) {
    message("\U2717 TIC matrix suppression not found for the analyses!")
    return(NULL)
  }
  if (!"id" %in% colnames(mp)) {
    mp[, id := analysis]
  }
  mp[, intensity := mp]

  if (is.numeric(downsize) && length(downsize) == 1 && is.finite(downsize) && downsize > 1) {
    mp[, rt := floor(rt / downsize) * downsize]
    mp <- mp[, .(intensity = mean(intensity, na.rm = TRUE)), by = c("analysis", "replicate", "polarity", "level", "id", "rt")]
  }

  if (is.null(yLab)) {
    yLab <- "Supression Factor"
  }
  if (is.null(xLab)) {
    xLab <- "Retention time / seconds"
  }

  color_col <- switch(
    as.character(colorBy),
    analyses = "analysis",
    analysis = "analysis",
    replicates = "replicate",
    replicate = "replicate",
    polarity = "polarity",
    level = "level",
    stop("colorBy must be one of: analyses, analysis, replicates, replicate, polarity, level")
  )

  mp[, var := as.character(get(color_col))]
  if (is.character(legendNames) && length(legendNames) == length(unique(mp$var))) {
    mapped <- setNames(legendNames, unique(mp$var))
    mp[, var := unname(mapped[var])]
  }
  mp[, loop := paste0(analysis, replicate, id, var)]
  cl <- .get_colors(unique(mp$var), darkMode = darkMode)

  if (!interactive) {
    return(
      ggplot2::ggplot(mp, ggplot2::aes(x = rt, y = intensity, group = loop)) +
        ggplot2::geom_line(ggplot2::aes(color = var)) +
        ggplot2::scale_color_manual(values = cl) +
        ggplot2::theme_classic() +
        ggplot2::labs(x = xLab, y = yLab, title = title, color = colorBy)
    )
  }

  title_spec <- .plotly_title_spec(title, darkMode = darkMode)
  xaxis <- .plotly_axis_spec(title = xLab, darkMode = darkMode)
  yaxis <- .plotly_axis_spec(title = yLab, darkMode = darkMode)

  loop <- NULL
  plot <- mp %>%
    dplyr::group_by(loop) %>%
    plotly::plot_ly(
      x = ~rt,
      y = ~intensity,
      type = "scatter",
      color = ~var,
      colors = cl,
      mode = "lines",
      line = list(width = 2),
      text = ~paste(
        "<br>analysis: ", analysis,
        "<br>replicate: ", replicate,
        "<br>id: ", id,
        "<br>polarity: ", polarity,
        "<br>level: ", level,
        "<br>rt: ", rt,
        "<br>suppression: ", intensity
      ),
      hoverinfo = "text",
      showlegend = showLegend
    ) %>%
    plotly::layout(
      xaxis = xaxis,
      yaxis = yaxis,
      title = title_spec,
      paper_bgcolor = .get_plot_theme(darkMode)$background,
      plot_bgcolor = .get_plot_theme(darkMode)$background,
      font = list(color = .get_plot_theme(darkMode)$text)
    )

  if (identical(renderEngine, "webgl")) {
    plot <- plot %>% plotly::toWebGL()
  }

  plot
}

#' @describeIn ProjectNonTargetAnalysisS3 Plot features count across analyses.
#' @method plot_features_count ProjectNonTargetAnalysis
#' @export
plot_features_count.ProjectNonTargetAnalysis <- function(
  x,
  analyses = NULL,
  filtered = FALSE,
  yLab = NULL,
  title = NULL,
  groupBy = "analysis",
  showLegend = TRUE,
  showHoverText = TRUE,
  darkMode = FALSE
) {
  checkmate::assert_class(x, "ProjectNonTargetAnalysis")
  info <- get_features_count(x, analyses = analyses, filtered = filtered)
  if (nrow(info) == 0) {
    return(NULL)
  }
  allowed_group_by <- c("analysis", "replicate")
  if (!is.character(groupBy) || length(groupBy) != 1 || !(groupBy %in% allowed_group_by)) {
    stop("groupBy must be one of: ", paste(allowed_group_by, collapse = ", "))
  }
  analyses_info <- data.table::as.data.table(get_analyses(x))
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
  colors_tag <- .get_colors(info$analysis, darkMode = darkMode)
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
      title = .plotly_title_spec(title, darkMode = darkMode),
      xaxis = .plotly_axis_spec(
        title = NULL,
        darkMode = darkMode,
        tickfont = list(size = 14, color = .get_plot_theme(darkMode)$text)
      ),
      yaxis = list(
        title = yLab,
        tickfont = list(size = 14, color = .get_plot_theme(darkMode)$text),
        titlefont = list(size = 18, color = .get_plot_theme(darkMode)$text),
        linecolor = .get_plot_theme(darkMode)$axis,
        tickcolor = .get_plot_theme(darkMode)$axis,
        gridcolor = .get_plot_theme(darkMode)$grid,
        zeroline = FALSE
      ),
      paper_bgcolor = .get_plot_theme(darkMode)$background,
      plot_bgcolor = .get_plot_theme(darkMode)$background,
      font = list(color = .get_plot_theme(darkMode)$text)
    )
}

#' @describeIn ProjectNonTargetAnalysisS3 Return feature profiles across analyses.
#' @method get_features_profile ProjectNonTargetAnalysis
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
  corrected = FALSE,
  ...
) {
  checkmate::assert_class(x, "ProjectNonTargetAnalysis")
  fts <- get_features(
    x,
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
  if (corrected && "correction" %in% colnames(fts)) {
    fts$intensity <- fts$intensity * fts$correction
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
}

#' @describeIn ProjectNonTargetAnalysisS3 Plot feature profiles for selected analyses.
#' @method plot_features_profile ProjectNonTargetAnalysis
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
  corrected = FALSE,
  groupBy = "analysis",
  normalized = FALSE,
  yLab = NULL,
  title = NULL,
  interactive = TRUE,
  showLegend = TRUE,
  darkMode = FALSE,
  ...
) {
  checkmate::assert_class(x, "ProjectNonTargetAnalysis")
  prof <- get_features_profile(
    x,
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
    corrected = corrected
  )

  if (nrow(prof) == 0) {
    return(NULL)
  }

  allowed_group_by <- c("analysis", "replicate")
  if (!is.character(groupBy) || length(groupBy) != 1 || !(groupBy %in% allowed_group_by)) {
    stop("groupBy must be one of: ", paste(allowed_group_by, collapse = ", "))
  }

  analyses_info <- data.table::as.data.table(get_analyses(x))
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

  colors_tag <- .get_colors(unique(prof$feature_group), darkMode = darkMode)
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
      title = .plotly_title_spec(title, darkMode = darkMode),
      xaxis = .plotly_axis_spec(
        title = NULL,
        darkMode = darkMode,
        tickfont = list(size = 12, color = .get_plot_theme(darkMode)$text),
        type = "category",
        categoryorder = "array",
        categoryarray = as.list(ord)
      ),
      yaxis = .plotly_axis_spec(
        title = yLab,
        darkMode = darkMode,
        tickfont = list(size = 12, color = .get_plot_theme(darkMode)$text)
      ),
      legend = list(title = list(text = "feature_group")),
      paper_bgcolor = .get_plot_theme(darkMode)$background,
      plot_bgcolor = .get_plot_theme(darkMode)$background,
      font = list(color = .get_plot_theme(darkMode)$text)
    )
}

#' @describeIn ProjectNonTargetAnalysisS3 Plot selected features for analyses.
#' @method plot_features ProjectNonTargetAnalysis
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
  darkMode = FALSE,
  ...
) {
  checkmate::assert_class(x, "ProjectNonTargetAnalysis")
  fts <- get_features(
    x,
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
      rt_decoded <- rcpp_decode_string(ft$eic_rt)
      intensity_decoded <- rcpp_decode_string(ft$eic_intensity)
      baseline_decoded <- NULL
      if (!is.na(ft$eic_baseline) && nchar(ft$eic_baseline) > 0) {
        baseline_decoded <- rcpp_decode_string(ft$eic_baseline)
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
  cl <- .get_colors(var_levels, darkMode = darkMode)
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

  title <- .plotly_title_spec(title, darkMode = darkMode)
  xaxis <- .plotly_axis_spec(title = xLab, darkMode = darkMode)
  yaxis <- .plotly_axis_spec(title = yLab, darkMode = darkMode)
  make_hover_text <- function(pk_row) {
    fmt_num <- function(x, digits = 2) {
      if (is.null(x)) {
        return(NA_real_)
      }
      ifelse(is.na(x), NA, round(as.numeric(x), digits))
    }
    base_lines <- c(
      paste0("analysis: ", pk_row$analysis),
      paste0("feature: ", pk_row$feature),
      paste0("feature_component: ", pk_row$feature_component),
      paste0("feature_group: ", pk_row$feature_group),
      .format_nta_adduct_hover(pk_row$adduct),
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
  plot %>% plotly::layout(
    xaxis = xaxis,
    yaxis = yaxis,
    title = title,
    paper_bgcolor = .get_plot_theme(darkMode)$background,
    plot_bgcolor = .get_plot_theme(darkMode)$background,
    font = list(color = .get_plot_theme(darkMode)$text)
  )
}

#' @describeIn ProjectNonTargetAnalysisS3 Map features across analyses (visualization).
#' @method map_features ProjectNonTargetAnalysis
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
  darkMode = FALSE,
  ...
) {
  checkmate::assert_class(x, "ProjectNonTargetAnalysis")
  fts <- get_features(
    x,
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
  cl <- .get_colors(var_levels, darkMode = darkMode)

  pt_list <- list()
  for (i in seq_len(nrow(fts))) {
    ft <- fts[i, ]
    has_eic <- !is.na(ft$eic_rt) && !is.na(ft$eic_mz) && !is.na(ft$eic_intensity)
    has_eic <- has_eic && nchar(ft$eic_rt) > 0 && nchar(ft$eic_mz) > 0 && nchar(ft$eic_intensity) > 0
    if (!has_eic) next
    rt_dec <- rcpp_decode_string(ft$eic_rt)
    mz_dec <- rcpp_decode_string(ft$eic_mz)
    int_dec <- rcpp_decode_string(ft$eic_intensity)
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

  title <- .plotly_title_spec(title, darkMode = darkMode)
  xaxis <- .plotly_axis_spec(title = xLab, darkMode = darkMode)
  yaxis <- .plotly_axis_spec(title = yLab, darkMode = darkMode)
  hover_vals <- if (showDetails) {
    paste0(
      "analysis: ", pts$analysis,
      "<br>replicate: ", pts$replicate,
      "<br>feature: ", pts$feature,
      "<br>component: ", pts$feature_component,
      "<br>group: ", pts$feature_group,
      "<br>", .format_nta_adduct_hover(pts$adduct),
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
    plotly::layout(
      title = title,
      xaxis = xaxis,
      yaxis = yaxis,
      legend = list(title = list(text = groupBy)),
      paper_bgcolor = .get_plot_theme(darkMode)$background,
      plot_bgcolor = .get_plot_theme(darkMode)$background,
      font = list(color = .get_plot_theme(darkMode)$text)
    )
}

#' @describeIn ProjectNonTargetAnalysisS3 Plot MS1 features for selected analyses.
#' @method plot_features_ms1 ProjectNonTargetAnalysis
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
  darkMode = FALSE,
  ...
) {
  checkmate::assert_class(x, "ProjectNonTargetAnalysis")
  ms1 <- get_features_ms1(
    x,
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
    filtered = filtered
  )

  if (nrow(ms1) == 0) {
    message("\u2717 MS1 traces not found for the targets!")
    return(NULL)
  }

  if (!(is.character(groupBy) && length(groupBy) >= 1 && all(groupBy %in% colnames(ms1)))) {
    warning("groupBy columns not found in MS1 data")
    return(NULL)
  }
  vals <- lapply(groupBy, function(col) as.character(ms1[[col]]))
  ms1$var <- do.call(paste, c(vals, sep = " - "))
  ms1$loop <- paste0(ms1$analysis, ms1$replicate, ms1$feature, ms1$var)
  cl <- .get_colors(unique(ms1$var), darkMode = darkMode)
  ms1$text_string <- if (showText) paste0(round(ms1$mz, 4)) else ""

  if (!interactive) {
    if (is.null(xLab)) xLab <- expression(italic("m/z ") / " Da")
    if (is.null(yLab)) yLab <- "Intensity / counts"
    return(
      ggplot2::ggplot(ms1, ggplot2::aes(x = mz, y = intensity, group = loop)) +
        ggplot2::geom_segment(ggplot2::aes(xend = mz, yend = 0, color = var), linewidth = 1) +
        {
          if (showText) ggplot2::geom_text(ggplot2::aes(label = text_string), vjust = 0.2, hjust = -0.2, angle = 90, size = 2, show.legend = FALSE)
        } +
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
  title <- .plotly_title_spec(title, darkMode = darkMode)
  xaxis <- .plotly_axis_spec(title = xLab, darkMode = darkMode, range = c(ticksMin, ticksMax), dtick = round((max(ms1$mz) / 10), -1), ticks = "outside")
  yaxis <- .plotly_axis_spec(title = yLab, darkMode = darkMode, range = c(0, max(ms1$intensity) * 1.5))
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
  plot %>% plotly::layout(
    title = title,
    xaxis = xaxis,
    yaxis = yaxis,
    paper_bgcolor = .get_plot_theme(darkMode)$background,
    plot_bgcolor = .get_plot_theme(darkMode)$background,
    font = list(color = .get_plot_theme(darkMode)$text),
    uniformtext = list(minsize = 6, mode = "show")
  )
}

#' @describeIn ProjectNonTargetAnalysisS3 Plot MS2 features for selected analyses.
#' @method plot_features_ms2 ProjectNonTargetAnalysis
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
  darkMode = FALSE,
  ...
) {
  checkmate::assert_class(x, "ProjectNonTargetAnalysis")
  ms2 <- get_features_ms2(
    x,
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
    filtered = filtered
  )

  if (nrow(ms2) == 0) {
    message("\u2717 MS2 traces not found for the targets!")
    return(NULL)
  }
  ms2[, is_pre := FALSE]

  if (!(is.character(groupBy) && length(groupBy) >= 1 && all(groupBy %in% colnames(ms2)))) {
    warning("groupBy columns not found in MS2 data")
    return(NULL)
  }
  vals <- lapply(groupBy, function(col) as.character(ms2[[col]]))
  ms2$var <- do.call(paste, c(vals, sep = " - "))
  ms2$text_string <- if (showText) paste0(round(ms2$mz, 4)) else ""
  ms2$text_string[ms2$is_pre] <- paste0("Pre ", ms2$text_string[ms2$is_pre])
  ms2$loop <- paste0(ms2$analysis, ms2$replicate, ms2$feature, ms2$var)
  cl <- .get_colors(unique(ms2$var), darkMode = darkMode)

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
  title <- .plotly_title_spec(title, darkMode = darkMode)
  xaxis <- .plotly_axis_spec(title = xLab, darkMode = darkMode, range = c(ticksMin, ticksMax), dtick = round((max(ms2$mz) / 10), -1), ticks = "outside")
  yaxis <- .plotly_axis_spec(title = yLab, darkMode = darkMode, range = c(0, max(ms2$intensity) * 1.5))
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
  plot %>% plotly::layout(
    title = title,
    xaxis = xaxis,
    yaxis = yaxis,
    paper_bgcolor = .get_plot_theme(darkMode)$background,
    plot_bgcolor = .get_plot_theme(darkMode)$background,
    font = list(color = .get_plot_theme(darkMode)$text),
    uniformtext = list(minsize = 6, mode = "show")
  )
}

#' @describeIn ProjectNonTargetAnalysisS3 Return internal standards for selected analyses.
#' @method get_internal_standards ProjectNonTargetAnalysis
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
  ...
) {
  checkmate::assert_class(x, "ProjectNonTargetAnalysis")
  analyses_info <- data.table::as.data.table(x$get_analyses())
  sel_names <- .resolve_analyses_selection(analyses, analyses_info$analysis)
  if (length(sel_names) == 0) {
    return(data.table::data.table())
  }
  internal_standards <- data.table::as.data.table(
    rcpp_project_non_target_analysis_get_internal_standards(
      x$get_nts_ptr(),
      sel_names,
      features,
      groups,
      mass,
      mz,
      rt,
      mobility,
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
  col_order <- c("analysis", "replicate", "feature", "feature_group", "feature_component", "adduct", "polarity")
  data.table::setcolorder(internal_standards, c(intersect(col_order, colnames(internal_standards)), setdiff(colnames(internal_standards), col_order)))
  internal_standards
}

#' @describeIn ProjectNonTargetAnalysisS3 Return internal-standard profiles across analyses.
#' @method get_internal_standards_profile ProjectNonTargetAnalysis
#' @export
get_internal_standards_profile.ProjectNonTargetAnalysis <- function(
  x,
  analyses = NULL,
  features = NULL,
  names = NULL,
  mass = NULL,
  mz = NULL,
  rt = NULL,
  mobility = NULL,
  ppm = 20,
  sec = 60,
  millisec = 5,
  normalized = FALSE,
  ...
) {
  checkmate::assert_class(x, "ProjectNonTargetAnalysis")
  istd <- get_internal_standards(
    x,
    analyses = analyses,
    features = features,
    mass = mass,
    mz = mz,
    rt = rt,
    mobility = mobility,
    ppm = ppm,
    sec = sec,
    millisec = millisec
  )
  if (nrow(istd) == 0) {
    return(data.table::data.table())
  }

  if (!is.null(names)) {
    name_values <- if (is.data.frame(names)) {
      col_name <- intersect(c("name", "names"), colnames(names))[1]
      if (is.na(col_name)) stop("Selection for 'names' must include a 'name' column")
      names[[col_name]]
    } else {
      names
    }
    istd <- istd[name %in% name_values]
  }
  if (nrow(istd) == 0) {
    return(data.table::data.table())
  }
  if (!"name" %in% colnames(istd)) {
    warning("Internal standard names not found!")
    return(data.table::data.table())
  }
  istd <- istd[!is.na(name) & name != ""]
  if (nrow(istd) == 0) {
    return(data.table::data.table())
  }

  prof <- istd[, .(intensity = max(intensity, na.rm = TRUE)), by = c("name", "analysis")]
  prof$intensity[is.na(prof$intensity) | is.infinite(prof$intensity)] <- 0
  if ("replicate" %in% colnames(istd)) {
    rep_map <- unique(istd[, .(analysis, replicate)])
    prof <- merge(prof, rep_map, by = "analysis", all.x = TRUE)
  }
  if (normalized) {
    prof[, intensity := {
      max_int <- max(intensity, na.rm = TRUE)
      if (!is.finite(max_int) || max_int == 0) 0 else intensity / max_int
    }, by = name]
  }
  desired_order <- c("analysis", "replicate", "name", "intensity")
  desired_order <- desired_order[desired_order %in% colnames(prof)]
  data.table::setcolorder(prof, c(intersect(desired_order, colnames(prof)), setdiff(colnames(prof), desired_order)))
  prof
}

#' @describeIn ProjectNonTargetAnalysisS3 Plot internal-standard profiles for selected analyses.
#' @method plot_internal_standards_profile ProjectNonTargetAnalysis
#' @export
plot_internal_standards_profile.ProjectNonTargetAnalysis <- function(
  x,
  analyses = NULL,
  features = NULL,
  names = NULL,
  mass = NULL,
  mz = NULL,
  rt = NULL,
  mobility = NULL,
  ppm = 20,
  sec = 60,
  millisec = 5,
  groupBy = "analysis",
  normalized = FALSE,
  yLab = NULL,
  title = NULL,
  interactive = TRUE,
  showLegend = TRUE,
  darkMode = FALSE,
  ...
) {
  checkmate::assert_class(x, "ProjectNonTargetAnalysis")
  prof <- get_internal_standards_profile(
    x,
    analyses = analyses,
    features = features,
    names = names,
    mass = mass,
    mz = mz,
    rt = rt,
    mobility = mobility,
    ppm = ppm,
    sec = sec,
    millisec = millisec,
    normalized = normalized
  )

  if (nrow(prof) == 0) {
    return(NULL)
  }

  allowed_group_by <- c("analysis", "replicate")
  if (!is.character(groupBy) || length(groupBy) != 1 || !(groupBy %in% allowed_group_by)) {
    stop("groupBy must be one of: ", paste(allowed_group_by, collapse = ", "))
  }

  analyses_info <- data.table::as.data.table(get_analyses(x))
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

  if (groupBy == "replicate") {
    if (!"replicate" %in% colnames(prof)) {
      warning("Replicate information not available for internal standard profiles.")
      return(NULL)
    }
    prof <- prof[, .(
      intensity = mean(intensity, na.rm = TRUE),
      analysis_sd = stats::sd(intensity, na.rm = TRUE)
    ), by = c("name", "replicate")]
    prof$analysis_sd[is.na(prof$analysis_sd)] <- 0
  }

  x_col <- if (groupBy == "replicate") "replicate" else "analysis"
  prof$name <- as.character(prof$name)

  if (groupBy == "replicate") {
    ord <- replicate_order[replicate_order %in% as.character(prof$replicate)]
    if (length(ord) == 0) ord <- unique(as.character(prof$replicate))
    prof$replicate <- factor(as.character(prof$replicate), levels = ord)
  } else {
    ord <- analysis_order[analysis_order %in% as.character(prof$analysis)]
    if (length(ord) == 0) ord <- unique(as.character(prof$analysis))
    prof$analysis <- factor(as.character(prof$analysis), levels = ord)
  }
  data.table::setorderv(prof, c("name", x_col))

  if (is.null(yLab)) {
    yLab <- if (normalized) "Relative intensity" else "Intensity"
  }
  xLab <- if (groupBy == "replicate") "Replicate" else "Analysis"

  if (!interactive) {
    plot <- ggplot2::ggplot(
      prof,
      ggplot2::aes(x = .data[[x_col]], y = intensity, group = name, color = name)
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
      .ggplot_plot_theme(darkMode = darkMode) +
      ggplot2::labs(x = xLab, y = yLab, title = title, color = "name")
    return(plot)
  }

  colors_tag <- .get_colors(unique(prof$name), darkMode = darkMode)
  hover_text <- paste0(
    "name: ", prof$name,
    "<br>", xLab, ": ", as.character(prof[[x_col]]),
    "<br>intensity: ", round(prof$intensity, 3)
  )

  error_y <- NULL
  if (groupBy == "replicate") {
    error_y <- list(type = "data", array = prof$analysis_sd, visible = TRUE)
  }

  plotly::plot_ly(
    data = prof,
    x = stats::as.formula(paste0("~", x_col)),
    y = ~intensity,
    type = "scatter",
    mode = "lines+markers",
    color = ~name,
    colors = colors_tag,
    text = hover_text,
    hoverinfo = "text",
    error_y = error_y,
    showlegend = showLegend
  ) %>%
    plotly::layout(
      title = .plotly_title_spec(title, darkMode = darkMode),
      xaxis = .plotly_axis_spec(title = xLab, darkMode = darkMode),
      yaxis = .plotly_axis_spec(title = yLab, darkMode = darkMode),
      paper_bgcolor = .get_plot_theme(darkMode)$background,
      plot_bgcolor = .get_plot_theme(darkMode)$background,
      font = list(color = .get_plot_theme(darkMode)$text)
    )
}

#' @describeIn ProjectNonTargetAnalysisS3 Return suspects for selected analyses.
#' @method get_suspects ProjectNonTargetAnalysis
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
  ...
) {
  checkmate::assert_class(x, "ProjectNonTargetAnalysis")
  analyses_info <- data.table::as.data.table(x$get_analyses())
  sel_names <- .resolve_analyses_selection(analyses, analyses_info$analysis)
  if (length(sel_names) == 0) {
    return(data.table::data.table())
  }
  suspects <- data.table::as.data.table(
    rcpp_project_non_target_analysis_get_suspects(
      x$get_nts_ptr(),
      sel_names,
      features,
      groups,
      mass,
      mz,
      rt,
      mobility,
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
  desired_order <- c("analysis", "replicate", "feature", "feature_group")
  data.table::setcolorder(suspects, c(intersect(desired_order, colnames(suspects)), setdiff(colnames(suspects), desired_order)))
  suspects
}

#' @describeIn ProjectNonTargetAnalysisS3 Plot suspects MS2 for selected analyses.
#' @method plot_suspects_ms2 ProjectNonTargetAnalysis
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
  darkMode = FALSE,
  ...
) {
  checkmate::assert_class(x, "ProjectNonTargetAnalysis")
  suspects <- get_suspects(
    x,
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
      mz_dec <- rcpp_decode_string(sp$exp_ms2_mz)
      int_dec <- rcpp_decode_string(sp$exp_ms2_intensity)
      if (length(mz_dec) > 0 && length(mz_dec) == length(int_dec)) {
        out[[1]] <- data.table::data.table(mz = mz_dec, intensity = int_dec, analysis = sp$analysis, feature = sp$feature, name = sp$name, formula_fragment = NA_character_, source = "exp")
      }
    }
    if (!is.na(sp$db_ms2_mz) && nzchar(sp$db_ms2_mz) && !is.na(sp$db_ms2_intensity) && nzchar(sp$db_ms2_intensity)) {
      mz_dec <- rcpp_decode_string(sp$db_ms2_mz)
      int_dec <- rcpp_decode_string(sp$db_ms2_intensity)
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
  cl <- .get_colors(unique(suspects_ms2$var), darkMode = darkMode)
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
    theme <- .get_plot_theme(darkMode = darkMode)
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
        ggplot2::annotate("segment", x = min_mz, xend = max_mz, y = 0, yend = 0, color = theme$axis, linewidth = 0.3) +
        ggplot2::geom_segment(data = data.table::data.table(x = x_breaks), ggplot2::aes(x = x, xend = x, y = 0, yend = -max_abs_int * 0.04), inherit.aes = FALSE, color = theme$axis, linewidth = 0.3) +
        ggplot2::geom_text(data = data.table::data.table(x = x_breaks), ggplot2::aes(x = x, y = -max_abs_int * 0.09, label = round(x, 2)), inherit.aes = FALSE, size = 3, color = theme$text) +
        ggplot2::scale_color_manual(values = cl, name = paste(groupBy, collapse = " - ")) +
        ggplot2::labs(x = xLab, y = yLab, title = title) +
        .ggplot_plot_theme(darkMode = darkMode) +
        ggplot2::theme(
          panel.background = ggplot2::element_rect(fill = "transparent", colour = NA),
          plot.background = ggplot2::element_rect(fill = "transparent", colour = NA),
          axis.line.x = ggplot2::element_blank(),
          axis.ticks.x = ggplot2::element_blank(),
          axis.text.x = ggplot2::element_blank(),
          axis.title.x = ggplot2::element_blank(),
          legend.text = ggplot2::element_text(color = theme$text),
          legend.title = ggplot2::element_text(color = theme$text),
          legend.position = if (isTRUE(showLegend)) "right" else "none"
        )
    )
  }

  if (is.null(xLab)) xLab <- "<i>m/z</i> / Da"
  if (is.null(yLab)) yLab <- "Intensity / counts"
  ticksMin <- plyr::round_any(min(suspects_ms2$mz, na.rm = TRUE) * 0.9, 10)
  ticksMax <- plyr::round_any(max(suspects_ms2$mz, na.rm = TRUE) * 1.1, 10)
  title <- .plotly_title_spec(title, darkMode = darkMode)
  xaxis <- .plotly_axis_spec(title = xLab, darkMode = darkMode, range = c(ticksMin, ticksMax), dtick = round((max(suspects_ms2$mz) / 10), -1), ticks = "outside")
  yaxis <- .plotly_axis_spec(title = yLab, darkMode = darkMode, range = c(-max_abs_int * 1.2, max_abs_int * 1.2))
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
        detail_info <- paste(vapply(seq_along(hover_fields), function(j) {
          .format_nta_hover_field(hover_fields[j], row_vals[j])
        }, character(1)), collapse = "<br>")
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
  plot %>% plotly::layout(
    title = title,
    xaxis = xaxis,
    yaxis = yaxis,
    paper_bgcolor = .get_plot_theme(darkMode)$background,
    plot_bgcolor = .get_plot_theme(darkMode)$background,
    font = list(color = .get_plot_theme(darkMode)$text),
    uniformtext = list(minsize = 6, mode = "show"),
    showlegend = showLegend,
    hoverlabel = list(align = "left")
  )
}

#' @describeIn ProjectNonTargetAnalysisS3 Compute fold change between replicate sets.
#' @method get_fold_change ProjectNonTargetAnalysis
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
  ...
) {
  checkmate::assert_class(x, "ProjectNonTargetAnalysis")
  info_analyses <- data.table::as.data.table(get_analyses(x))
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

  fts <- get_features.ProjectNonTargetAnalysis(
    x,
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
}

#' @describeIn ProjectNonTargetAnalysisS3 Plot fold change between replicate sets.
#' @method plot_fold_change ProjectNonTargetAnalysis
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
  ...
) {
  checkmate::assert_class(x, "ProjectNonTargetAnalysis")
  fc <- get_fold_change(
    x,
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

  info_analyses <- data.table::as.data.table(get_analyses.ProjectMassSpec(x))
  fts_all <- get_features.ProjectNonTargetAnalysis(x, analyses = NULL, filtered = filtered)
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
}

#' @describeIn ProjectNonTargetAnalysisS3 Return transformation products for groups/parents.
#' @method get_transformation_products ProjectNonTargetAnalysis
#' @export
get_transformation_products.ProjectNonTargetAnalysis <- function(x, parents = NULL, groups = NULL, ...) {
  checkmate::assert_class(x, "ProjectNonTargetAnalysis")
  tps <- data.table::as.data.table(
    rcpp_project_non_target_analysis_get_transformation_products(x$get_nts_ptr())
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
        if (is.na(x) || !nzchar(x)) {
          return(FALSE)
        }
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
}

#' @describeIn ProjectNonTargetAnalysisS3 Plot transformation products for groups.
#' @method plot_transformation_products ProjectNonTargetAnalysis
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
  showMS2 = FALSE,
  showIntensityProfile = FALSE,
  ...
) {
  checkmate::assert_class(x, "ProjectNonTargetAnalysis")
  if (!requireNamespace("visNetwork", quietly = TRUE)) {
    stop("visNetwork package is required for this function.")
  }
  tps <- get_transformation_products(x, parents = NULL, groups = groups)
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
      feature_dt <- get_features(x, groups = all_groups, filtered = FALSE)
      feature_dt <- data.table::as.data.table(feature_dt)[, intersect(unique(select_cols), colnames(feature_dt)), with = FALSE]

      if (showMS2) {
        ms2_data <- feature_dt[!is.na(ms2_mz) & ms2_mz != "", .(feature_group, analysis, ms2_mz, ms2_intensity)]
        if (nrow(ms2_data) > 0) {
          ms2_lookup <- split(ms2_data, ms2_data$feature_group)
        }
      }

      if (showIntensityProfile) {
        analyses_info <- data.table::as.data.table(get_analyses(x))
        keep_cols <- intersect(c("analysis", "replicate"), colnames(analyses_info))
        if (length(keep_cols) > 0) {
          analyses_info <- analyses_info[, ..keep_cols]
        }
        if (nrow(analyses_info) > 0) {
          analyses_info$analysis <- as.character(analyses_info$analysis)
          analyses_info$replicate <- as.character(analyses_info$replicate)
          analyses_info <- unique(analyses_info[, .(analysis, replicate)])
          info_order <- as.character(data.table::as.data.table(get_analyses(x))$analysis)
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
    if (length(x) == 0) {
      return("NA")
    }
    paste(unique(x), collapse = "; ")
  }

  create_structure_image <- function(smiles, width_px = 2400, height_px = 1600, dpi = 400) {
    if (is.null(smiles) || is.na(smiles) || !nzchar(smiles)) {
      return("")
    }
    if (!requireNamespace("rcdk", quietly = TRUE)) {
      return("")
    }
    if (!requireNamespace("rJava", quietly = TRUE)) {
      return("")
    }
    if (!requireNamespace("base64enc", quietly = TRUE)) {
      return("")
    }
    if (!requireNamespace("magick", quietly = TRUE)) {
      return("")
    }
    tryCatch(
      {
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
      },
      error = function(e) ""
    )
  }

  message("\u2699 Pre-rendering ", length(node_ids), " unique structures...", appendLF = FALSE)
  structure_cache <- setNames(lapply(node_ids, function(smiles) create_structure_image(smiles)), node_ids)
  message(" Done.")

  create_ms2_mirror_plot <- function(precursor_spectra_list, product_spectra_list, width = 700, height = 400) {
    if (!requireNamespace("base64enc", quietly = TRUE)) {
      return("")
    }
    tryCatch(
      {
        parse_values <- function(x) {
          if (is.null(x) || is.na(x) || !nzchar(as.character(x))) {
            return(numeric(0))
          }
          tryCatch(
            {
              vals <- rcpp_decode_string(as.character(x))
              if (length(vals) == 0 || !is.numeric(vals)) {
                return(numeric(0))
              }
              vals[is.finite(vals)]
            },
            error = function(e) numeric(0)
          )
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
        if (length(prec_spectra) == 0 && length(prod_spectra) == 0) {
          return("")
        }
        for (i in seq_along(prec_spectra)) if (max(prec_spectra[[i]]$int) > 0) prec_spectra[[i]]$int <- prec_spectra[[i]]$int / max(prec_spectra[[i]]$int)
        for (i in seq_along(prod_spectra)) if (max(prod_spectra[[i]]$int) > 0) prod_spectra[[i]]$int <- prod_spectra[[i]]$int / max(prod_spectra[[i]]$int)
        all_mz <- c(unlist(lapply(prec_spectra, function(s) s$mz)), unlist(lapply(prod_spectra, function(s) s$mz)))
        if (length(all_mz) == 0) {
          return("")
        }
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
      },
      error = function(e) ""
    )
  }

  create_intensity_profile_plot <- function(profile_dt, replicate_order, width = 700, height = 260) {
    if (!requireNamespace("base64enc", quietly = TRUE)) {
      return("")
    }
    if (!requireNamespace("ggplot2", quietly = TRUE)) {
      return("")
    }
    if (is.null(profile_dt) || nrow(profile_dt) == 0) {
      return("")
    }
    tryCatch(
      {
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
        if (nrow(plt_dt) == 0) {
          return("")
        }
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
      },
      error = function(e) ""
    )
  }

  parse_ms_values <- function(x) {
    if (is.null(x) || is.na(x) || !nzchar(as.character(x))) {
      return(numeric(0))
    }
    vals <- tryCatch(rcpp_decode_string(as.character(x)), error = function(e) numeric(0))
    if (!is.numeric(vals) || length(vals) == 0) {
      return(numeric(0))
    }
    vals[is.finite(vals)]
  }

  build_plotly_spectra_payload <- function(as_product) {
    if (!showMS2 || is.null(ms2_lookup) || nrow(as_product) == 0) {
      return("")
    }
    product_fgs <- unique(as_product$feature_group)
    product_fgs <- product_fgs[!is.na(product_fgs) & product_fgs != ""]
    if (length(product_fgs) == 0) {
      return("")
    }
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
    if (length(traces) == 0) {
      return("")
    }
    jsonlite::toJSON(list(traces = traces, layout = list(template = "plotly_white", margin = list(l = 55, r = 20, t = 20, b = 45), xaxis = list(title = "m/z", zeroline = FALSE), yaxis = list(title = "Relative Intensity", range = list(-1, 1), zeroline = TRUE, zerolinecolor = "#607D9C"), legend = list(title = list(text = "Spectra Match"))), config = list(displayModeBar = TRUE, responsive = TRUE)), auto_unbox = TRUE, null = "null", digits = 8)
  }

  build_plotly_profile_payload <- function(as_product) {
    if (!showIntensityProfile || is.null(intensity_profile_dt) || nrow(as_product) == 0) {
      return("")
    }
    node_fgs <- unique(as_product$feature_group)
    node_fgs <- node_fgs[!is.na(node_fgs) & node_fgs != ""]
    if (length(node_fgs) == 0) {
      return("")
    }
    dt <- intensity_profile_dt[feature_group %in% node_fgs]
    if (nrow(dt) == 0) {
      return("")
    }
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
      structures_html <- paste0('<table style="width:100%;border-collapse:collapse;margin:0;padding:0;"><tr>', '<td style="width:38%;vertical-align:middle;padding:4px 6px;text-align:center;">', '<div style="font-size:0.75em;font-weight:bold;color:#888;margin-bottom:3px;">Precursor</div>', if (nzchar(prec_structure)) paste0('<img src="', prec_structure, '" style="width:100%;height:140px;object-fit:contain;"/>') else '<div style="color:#ccc;padding:14px;">No structure</div>', "</td>", '<td style="width:8%;vertical-align:middle;padding:0 4px;text-align:center;">', '<div style="font-size:2.0em;font-weight:700;color:#5f6b7a;line-height:1;">&#8594;</div>', "</td>", '<td style="width:54%;vertical-align:middle;padding:4px 6px;text-align:center;">', if (nzchar(node_structure)) paste0('<img src="', node_structure, '" style="width:100%;height:220px;object-fit:contain;"/>') else '<div style="color:#ccc;padding:14px;">No structure</div>', "</td>", "</tr></table>")
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
    metadata_html <- paste0('<div style="font-size:0.75em;line-height:1.3;margin:8px 0;padding:5px;background:rgba(240,240,240,0.3);border-radius:3px;">', paste(metadata_lines, collapse = "<br/>"), "</div>")
    relationships_html <- ""
    if (nrow(as_product) > 0) {
      prod_valid <- as_product[!is.na(feature_group) & feature_group != ""]
      if (nrow(prod_valid) > 0) {
        prod_prec <- prod_valid[!is.na(precursor_feature_group) & precursor_feature_group != ""]
        if (nrow(prod_prec) > 0) {
          prod_prec <- unique(prod_prec, by = c("feature_group", "precursor_feature_group", "cosine_similarity", "rt_plausibility"))
          prec_lines <- vapply(seq_len(nrow(prod_prec)), function(i) {
            row <- prod_prec[i, ]
            paste0('<tr style="border-bottom:1px solid #eee;">', '<td style="padding:2px 4px;">', row$feature_group, "</td>", '<td style="padding:2px 4px;">', row$precursor_feature_group, "</td>", '<td style="padding:2px 4px;">', ifelse(!is.na(row$cosine_similarity), sprintf("%.3f", row$cosine_similarity), "-"), "</td>", '<td style="padding:2px 4px;">', ifelse(!is.na(row$rt_plausibility), sprintf("%.2f", row$rt_plausibility), "-"), "</td>", "</tr>")
          }, character(1))
          relationships_html <- paste0(relationships_html, '<div style="margin-top:8px;border-top:1px solid #ddd;padding-top:4px;">', '<div style="font-size:0.75em;font-weight:bold;color:#666;margin-bottom:3px;">Product → Precursor</div>', '<table style="width:100%;font-size:0.7em;border-collapse:collapse;">', '<tr style="background:#f5f5f5;font-weight:bold;">', '<td style="padding:2px 4px;">FG</td>', '<td style="padding:2px 4px;">Prec FG</td>', '<td style="padding:2px 4px;">Cos</td>', '<td style="padding:2px 4px;">RT</td>', "</tr>", paste(prec_lines, collapse = ""), "</table>", "</div>")
        }
        prod_main <- prod_valid[!is.na(main_precursor_feature_group) & main_precursor_feature_group != ""]
        if (nrow(prod_main) > 0) {
          prod_main <- unique(prod_main, by = c("feature_group", "main_precursor_feature_group", "main_precursor_cosine_similarity", "main_precursor_rt_plausibility"))
          main_lines <- vapply(seq_len(nrow(prod_main)), function(i) {
            row <- prod_main[i, ]
            paste0('<tr style="border-bottom:1px solid #eee;">', '<td style="padding:2px 4px;">', row$feature_group, "</td>", '<td style="padding:2px 4px;">', row$main_precursor_feature_group, "</td>", '<td style="padding:2px 4px;">', ifelse(!is.na(row$main_precursor_cosine_similarity), sprintf("%.3f", row$main_precursor_cosine_similarity), "-"), "</td>", '<td style="padding:2px 4px;">', ifelse(!is.na(row$main_precursor_rt_plausibility), sprintf("%.2f", row$main_precursor_rt_plausibility), "-"), "</td>", "</tr>")
          }, character(1))
          relationships_html <- paste0(relationships_html, '<div style="margin-top:8px;border-top:1px solid #ddd;padding-top:4px;">', '<div style="font-size:0.75em;font-weight:bold;color:#666;margin-bottom:3px;">Product → Main Precursor</div>', '<table style="width:100%;font-size:0.7em;border-collapse:collapse;">', '<tr style="background:#f5f5f5;font-weight:bold;">', '<td style="padding:2px 4px;">FG</td>', '<td style="padding:2px 4px;">Main FG</td>', '<td style="padding:2px 4px;">Cos</td>', '<td style="padding:2px 4px;">RT</td>', "</tr>", paste(main_lines, collapse = ""), "</table>", "</div>")
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

  tooltip_style <- paste(
    "position: fixed;",
    "visibility: hidden;",
    "padding: 5px;",
    "font-family: verdana;",
    "font-size: 14px;",
    "background-color: rgb(245, 244, 237);",
    "border-radius: 3px;",
    "border: 1px solid rgb(128, 128, 116);",
    "box-shadow: rgba(0, 0, 0, 0.2) 3px 3px 10px;",
    "max-width: 1200px;",
    "word-break: break-word;"
  )
  select_node_js <- paste(
    "function(params) {",
    "  var selected = params.nodes[0];",
    "  if (!selected) return;",
    "  var nearNodes = this.getConnectedNodes(selected);",
    "  nearNodes.push(selected);",
    "  var nearSet = {};",
    "  for (var n = 0; n < nearNodes.length; n++) nearSet[nearNodes[n]] = true;",
    "  var connected = this.getConnectedEdges(selected);",
    "  var keep = {};",
    "  for (var i = 0; i < connected.length; i++) keep[connected[i]] = true;",
    "  var allNodes = this.body.data.nodes.getIds();",
    "  var nodeUpdates = [];",
    "  for (var k = 0; k < allNodes.length; k++) {",
    "    var nn = this.body.data.nodes.get(allNodes[k]);",
    "    nodeUpdates.push({",
    "      id: allNodes[k],",
    "      label: nearSet[allNodes[k]] ? nn.node_label : '',",
    "      font: {",
    "        color: nearSet[allNodes[k]] ? 'rgba(0,0,0,1)' : 'rgba(0,0,0,0)',",
    "        face: 'Arial',",
    "        bold: allNodes[k] === selected",
    "      },",
    "      color: nearSet[allNodes[k]] ? nn.base_color : 'rgba(200,200,200,0.2)'",
    "    });",
    "  }",
    "  this.body.data.nodes.update(nodeUpdates);",
    "  var allEdges = this.body.data.edges.getIds();",
    "  var updates = [];",
    "  for (var j = 0; j < allEdges.length; j++) {",
    "    var e = this.body.data.edges.get(allEdges[j]);",
    "    updates.push({",
    "      id: allEdges[j],",
    "      hidden: false,",
    "      label: keep[allEdges[j]] ? e.edge_label : '',",
    "      color: keep[allEdges[j]] ? e.base_color : 'rgba(200,200,200,0.2)',",
    "      font: {",
    "        color: keep[allEdges[j]] ? 'rgba(0,0,0,1)' : 'rgba(0,0,0,0)',",
    "        face: 'Arial',",
    "        strokeWidth: 0,",
    "        strokeColor: 'rgba(0,0,0,0)'",
    "      }",
    "    });",
    "  }",
    "  this.body.data.edges.update(updates);",
    "}"
  )
  double_click_js <- paste(
    "function(params) {",
    "  var selected = (params.nodes && params.nodes.length > 0) ? params.nodes[0] : null;",
    "  if (!selected) return;",
    "  if (window.streamfindOpenTPModal) {",
    "    window.streamfindOpenTPModal(this, selected);",
    "  }",
    "}"
  )
  deselect_node_js <- paste(
    "function(params) {",
    "  var allNodes = this.body.data.nodes.getIds();",
    "  var nodeUpdates = [];",
    "  for (var k = 0; k < allNodes.length; k++) {",
    "    var nn = this.body.data.nodes.get(allNodes[k]);",
    "    nodeUpdates.push({",
    "      id: allNodes[k],",
    "      label: nn.node_label,",
    "      font: { color: 'rgba(0,0,0,1)', face: 'Arial', bold: false },",
    "      color: nn.base_color",
    "    });",
    "  }",
    "  this.body.data.nodes.update(nodeUpdates);",
    "  var allEdges = this.body.data.edges.getIds();",
    "  var updates = [];",
    "  for (var j = 0; j < allEdges.length; j++) {",
    "    var e = this.body.data.edges.get(allEdges[j]);",
    "    updates.push({",
    "      id: allEdges[j],",
    "      hidden: false,",
    "      label: '',",
    "      color: e.base_color,",
    "      font: {",
    "        color: 'rgba(0,0,0,0)',",
    "        face: 'Arial',",
    "        strokeWidth: 0,",
    "        strokeColor: 'rgba(0,0,0,0)'",
    "      }",
    "    });",
    "  }",
    "  this.body.data.edges.update(updates);",
    "}"
  )
  hover_edge_js <- paste(
    "function(params) {",
    "  if (params.edge) {",
    "    var e = this.body.data.edges.get(params.edge);",
    "    this.body.data.edges.update({",
    "      id: params.edge,",
    "      label: e.edge_label,",
    "      font: {",
    "        color: 'rgba(0,0,0,1)',",
    "        face: 'Arial',",
    "        strokeWidth: 0,",
    "        strokeColor: 'rgba(0,0,0,0)'",
    "      }",
    "    });",
    "  }",
    "}"
  )
  blur_edge_js <- paste(
    "function(params) {",
    "  if (params.edge) {",
    "    this.body.data.edges.update({",
    "      id: params.edge,",
    "      label: '',",
    "      font: {",
    "        color: 'rgba(0,0,0,0)',",
    "        face: 'Arial',",
    "        strokeWidth: 0,",
    "        strokeColor: 'rgba(0,0,0,0)'",
    "      }",
    "    });",
    "  }",
    "}"
  )

  p <- visNetwork::visNetwork(nodes, edges, height = "99vh", width = "100%") %>%
    visNetwork::visNodes(size = 12, font = list(size = 12, face = "Arial", strokeWidth = 0, strokeColor = "rgba(0,0,0,0)")) %>%
    visNetwork::visGroups(groupname = "parent", color = "darkred") %>%
    visNetwork::visGroups(groupname = "selected_group", color = "orange") %>%
    visNetwork::visGroups(groupname = "assigned", color = "forestgreen") %>%
    visNetwork::visGroups(groupname = "unassigned", color = "lightgray") %>%
    visNetwork::visEdges(arrows = "to", smooth = TRUE, font = list(size = 8, face = "Arial", strokeWidth = 0, strokeColor = "rgba(0,0,0,0)"), hoverWidth = 0, selectionWidth = 0) %>%
    visNetwork::visOptions(highlightNearest = FALSE, nodesIdSelection = list(enabled = TRUE)) %>%
    visNetwork::visInteraction(hover = TRUE, hoverConnectedEdges = TRUE, tooltipStyle = tooltip_style) %>%
    visNetwork::visLayout(randomSeed = 123) %>%
    visNetwork::visEvents(
      selectNode = htmlwidgets::JS(select_node_js),
      doubleClick = htmlwidgets::JS(double_click_js),
      deselectNode = htmlwidgets::JS(deselect_node_js),
      hoverEdge = htmlwidgets::JS(hover_edge_js),
      blurEdge = htmlwidgets::JS(blur_edge_js)
    )

  modal_css <- paste(
    c(
      "#sf-tp-modal-overlay{display:none;position:fixed;inset:0;background:rgba(20,26,38,0.35);z-index:9998;align-items:center;justify-content:center;}",
      "#sf-tp-modal{width:96vw;height:94vh;background:#fff;border-radius:8px;box-shadow:0 20px 50px rgba(0,0,0,0.28);display:flex;flex-direction:column;overflow:hidden;}",
      "#sf-tp-modal-header{display:flex;align-items:center;justify-content:space-between;padding:10px 14px;border-bottom:1px solid #e3e3e3;background:#fafafa;}",
      "#sf-tp-modal-title{font-size:15px;font-weight:600;color:#1f2937;}",
      "#sf-tp-modal-close{border:none;background:transparent;font-size:22px;line-height:1;cursor:pointer;color:#666;}",
      "#sf-tp-modal-content{display:grid;grid-template-rows:2fr 1fr 1fr;flex:1 1 auto;min-height:0;height:calc(100% - 0px);}",
      "#sf-tp-overview-row{min-height:0;overflow:auto;padding:8px 12px;border-bottom:1px solid #ececec;}",
      "#sf-tp-overview-content{height:auto;min-height:100%;}",
      "#sf-tp-spectra-row,#sf-tp-profile-row{min-height:0;overflow:hidden;padding:0;margin:0;}",
      "#sf-tp-spectra-plot,#sf-tp-profile-plot{display:block;box-sizing:border-box;width:100%;height:100%;min-height:0;margin:0;padding:0;overflow:hidden;}",
      "#sf-tp-spectra-plot .js-plotly-plot,#sf-tp-profile-plot .js-plotly-plot{width:100% !important;height:100% !important;}",
      "#sf-tp-spectra-plot .plot-container,#sf-tp-profile-plot .plot-container{width:100% !important;height:100% !important;}",
      "#sf-tp-spectra-plot .svg-container,#sf-tp-profile-plot .svg-container{width:100% !important;height:100% !important;}"
    ),
    collapse = "\n"
  )
  modal_script <- paste(
    c(
      "(function(){",
      "function byId(id){ return document.getElementById(id); }",
      "var init = false;",
      "var resizeObserver = null;",
      "var sfRenderVersion = 0;",
      "function clearPlot(containerId){",
      "  var el = byId(containerId);",
      "  if (!el) return;",
      "  if (window.Plotly) { try { window.Plotly.purge(el); } catch(e){} }",
      "  el.innerHTML = '';",
      "}",
      "function resizePlots(){",
      "  if (!window.Plotly) return;",
      "  var s = byId('sf-tp-spectra-plot');",
      "  var p = byId('sf-tp-profile-plot');",
      "  if (s) { try { window.Plotly.Plots.resize(s); } catch(e){} }",
      "  if (p) { try { window.Plotly.Plots.resize(p); } catch(e){} }",
      "}",
      "function scheduleResize(){",
      "  if (!window.requestAnimationFrame) { setTimeout(resizePlots, 0); return; }",
      "  window.requestAnimationFrame(function(){ resizePlots(); setTimeout(resizePlots, 40); });",
      "}",
      "function setNoData(containerId, msg){",
      "  var el = byId(containerId);",
      "  if (!el) return;",
      "  if (window.Plotly) { try { window.Plotly.purge(el); } catch(e){} }",
      "  el.innerHTML = '<div style=\"padding:14px;color:#666;font-size:13px;\">' + msg + '</div>';",
      "}",
      "var sfPlotlyLoading = false;",
      "var sfPlotlyWaiters = [];",
      "function withPlotly(ready, fail){",
      "  if (window.Plotly) { ready(); return; }",
      "  sfPlotlyWaiters.push({ready: ready, fail: fail});",
      "  if (sfPlotlyLoading) return;",
      "  sfPlotlyLoading = true;",
      "  var s = document.createElement('script');",
      "  s.src = 'https://cdn.plot.ly/plotly-2.35.2.min.js';",
      "  s.async = true;",
      "  s.onload = function(){",
      "    sfPlotlyLoading = false;",
      "    var q = sfPlotlyWaiters.slice();",
      "    sfPlotlyWaiters = [];",
      "    for (var i = 0; i < q.length; i++) { try { q[i].ready(); } catch(e){} }",
      "  };",
      "  s.onerror = function(){",
      "    sfPlotlyLoading = false;",
      "    var q = sfPlotlyWaiters.slice();",
      "    sfPlotlyWaiters = [];",
      "    for (var i = 0; i < q.length; i++) { if (q[i].fail) { try { q[i].fail(); } catch(e){} } }",
      "  };",
      "  document.head.appendChild(s);",
      "}",
      "function renderPlot(containerId, payloadJson, noDataMsg, version){",
      "  var el = byId(containerId);",
      "  if (!el) return;",
      "  if (version !== sfRenderVersion) return;",
      "  if (!payloadJson){ setNoData(containerId, noDataMsg); return; }",
      "  var payload = null;",
      "  try { payload = JSON.parse(payloadJson); } catch(e){ payload = null; }",
      "  if (!payload || !payload.traces || !payload.traces.length){ setNoData(containerId, noDataMsg); return; }",
      "  clearPlot(containerId);",
      "  if (!window.Plotly){ setNoData(containerId, 'Loading interactive plot...'); }",
      "  withPlotly(function(){",
      "    try {",
      "      if (version !== sfRenderVersion) return;",
      "      var target = byId(containerId);",
      "      if (!target) return;",
      "      var layout = Object.assign({}, payload.layout || {}, {autosize: true});",
      "      var config = Object.assign({responsive: true}, payload.config || {});",
      "      window.Plotly.react(target, payload.traces, layout, config).then(function(){",
      "        if (version !== sfRenderVersion) return;",
      "        scheduleResize();",
      "      });",
      "    } catch(e){",
      "      if (version !== sfRenderVersion) return;",
      "      setNoData(containerId, 'Could not render interactive plot.');",
      "    }",
      "  }, function(){",
      "    if (version !== sfRenderVersion) return;",
      "    setNoData(containerId, 'Plotly JS not available in this page.');",
      "  });",
      "}",
      "function closeModal(){",
      "  var ov = byId('sf-tp-modal-overlay');",
      "  if (!ov) return;",
      "  sfRenderVersion += 1;",
      "  clearPlot('sf-tp-spectra-plot');",
      "  clearPlot('sf-tp-profile-plot');",
      "  ov.style.display = 'none';",
      "}",
      "function ensureInit(){",
      "  if (init) return;",
      "  init = true;",
      "  var ov = byId('sf-tp-modal-overlay');",
      "  var close = byId('sf-tp-modal-close');",
      "  if (close) close.addEventListener('click', closeModal);",
      "  if (ov) ov.addEventListener('click', function(e){ if (e.target === ov) closeModal(); });",
      "  document.addEventListener('keydown', function(e){ if (e.key === 'Escape') closeModal(); });",
      "  window.addEventListener('resize', scheduleResize);",
      "  if (window.ResizeObserver){",
      "    resizeObserver = new window.ResizeObserver(function(){ scheduleResize(); });",
      "    var target = byId('sf-tp-modal-content');",
      "    if (target) resizeObserver.observe(target);",
      "  }",
      "}",
      "window.streamfindOpenTPModal = function(network, nodeId){",
      "  ensureInit();",
      "  sfRenderVersion += 1;",
      "  var renderVersion = sfRenderVersion;",
      "  var node = null;",
      "  try { node = network.body.data.nodes.get(nodeId); } catch(e){ node = null; }",
      "  if (!node) return;",
      "  var ov = byId('sf-tp-modal-overlay');",
      "  if (!ov) return;",
      "  byId('sf-tp-modal-title').textContent = node.node_label || node.id || 'Node Details';",
      "  byId('sf-tp-overview-content').innerHTML = node.overview_html || '<div style=\"color:#666;\">No overview data.</div>';",
      "  renderPlot('sf-tp-spectra-plot', node.spectra_json, 'MS2 spectra not available for this node.', renderVersion);",
      "  renderPlot('sf-tp-profile-plot', node.profile_json, 'Intensity profile not available for this node.', renderVersion);",
      "  ov.style.display = 'flex';",
      "  scheduleResize();",
      "};",
      "})();"
    ),
    collapse = "\n"
  )
  modal_markup <- htmltools::tagList(
    htmltools::tags$style(htmltools::HTML(modal_css)),
    htmltools::tags$div(
      id = "sf-tp-modal-overlay",
      htmltools::tags$div(
        id = "sf-tp-modal",
        htmltools::tags$div(
          id = "sf-tp-modal-header",
          htmltools::tags$div(id = "sf-tp-modal-title", "Node Details"),
          htmltools::tags$button(id = "sf-tp-modal-close", type = "button", "\u00d7")
        ),
        htmltools::tags$div(
          id = "sf-tp-modal-content",
          htmltools::tags$div(
            id = "sf-tp-overview-row",
            htmltools::tags$div(id = "sf-tp-overview-content")
          ),
          htmltools::tags$div(
            id = "sf-tp-spectra-row",
            htmltools::tags$div(id = "sf-tp-spectra-plot")
          ),
          htmltools::tags$div(
            id = "sf-tp-profile-row",
            htmltools::tags$div(id = "sf-tp-profile-plot")
          )
        )
      )
    ),
    htmltools::tags$script(htmltools::HTML(modal_script))
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
}
