#' @title Internal Project Mass Spec Base R6 Class
#' @description Internal R6 child of `Project` exposing shared Mass Spec tables and native
#'   helpers in the shared DuckDB project. `ProjectMassSpecSpectra` and
#'   `ProjectMassSpecChromatograms` provide the dedicated public sub-domain
#'   interfaces on top of this base.
#' @details This shared base is used by the public Mass Spec project wrappers and
#' is not intended to be opened directly by end users.
#' @param db Path to the project DuckDB file.
#' @param project_id Active project identifier.
#' @keywords internal
ProjectMassSpec <- R6::R6Class(
  classname = "ProjectMassSpec",
  inherit = Project,
  cloneable = FALSE,
  private = list(
    .mass_spec_ptr = NULL
  ),
  public = list(
    #' @description Create a Mass Spec domain wrapper for a shared `Project`.
    #' @param db Path to the DuckDB project file.
    #' @param project_id Active project identifier.
    #' @param .ptr Existing native project pointer for internal use.
    #' @param .mass_spec_ptr Existing native Mass Spec pointer for internal use.
    initialize = function(db, project_id, .ptr = NULL, .mass_spec_ptr = NULL) {
      super$initialize(db = db, project_id = project_id, .ptr = .ptr)
      private$.mass_spec_ptr <- if (is.null(.mass_spec_ptr)) {
        rcpp_project_mass_spec_new(self$get_ptr())
      } else {
        .mass_spec_ptr
      }
    },
    #' @description Return the native Mass Spec pointer.
    get_mass_spec_ptr = function() {
      private$.mass_spec_ptr
    },
    #' @description Import multiple Mass Spec files into the shared DB.
    #' @param file_paths Character vector with Mass Spec file paths.
    #' @param analyses Optional character vector with analysis names.
    #' @param replicates Optional character vector with replicate names.
    #' @param blanks Optional character vector with blank names.
    import_files = function(file_paths, analyses = character(), replicates = character(), blanks = character()) {
      checkmate::assert_character(file_paths, min.len = 1, any.missing = FALSE)
      checkmate::assert_character(analyses, any.missing = FALSE, null.ok = FALSE)
      checkmate::assert_character(replicates, any.missing = FALSE, null.ok = FALSE)
      checkmate::assert_character(blanks, any.missing = FALSE, null.ok = FALSE)
      if (length(analyses) > 0 && length(analyses) != length(file_paths)) {
        stop("`analyses` must have length 0 or match `file_paths`.")
      }
      if (length(replicates) > 0 && length(replicates) != length(file_paths)) {
        stop("`replicates` must have length 0 or match `file_paths`.")
      }
      if (length(blanks) > 0 && length(blanks) != length(file_paths)) {
        stop("`blanks` must have length 0 or match `file_paths`.")
      }
      rcpp_project_mass_spec_import_files(private$.mass_spec_ptr, file_paths, analyses, replicates, blanks)
      invisible(self)
    },
    #' @description Remove one analysis from the shared DB.
    #' @param analysis Character scalar with the analysis name.
    remove_analysis = function(analysis) {
      checkmate::assert_character(analysis, len = 1, any.missing = FALSE)
      rcpp_project_mass_spec_remove_analysis(private$.mass_spec_ptr, analysis)
      invisible(self)
    },
    #' @description List imported analyses.
    list_analyses = function() {
      rcpp_project_mass_spec_list_analyses(private$.mass_spec_ptr)
    },
    #' @description Get analysis names.
    get_analysis_names = function() {
      rcpp_project_mass_spec_get_analysis_names(private$.mass_spec_ptr)
    },
    #' @description Get replicate names named by analysis.
    get_replicate_names = function() {
      rcpp_project_mass_spec_get_replicate_names(private$.mass_spec_ptr)
    },
    #' @description Set replicate names by analysis order.
    #' @param value Character vector of replicate names matching the number of analyses.
    set_replicate_names = function(value) {
      checkmate::assert_character(value, any.missing = FALSE)
      rcpp_project_mass_spec_set_replicate_names(private$.mass_spec_ptr, value)
      invisible(self)
    },
    #' @description Get blank names named by analysis.
    get_blank_names = function() {
      rcpp_project_mass_spec_get_blank_names(private$.mass_spec_ptr)
    },
    #' @description Set blank names by analysis order.
    #' @param value Character vector of blank names matching the number of analyses.
    set_blank_names = function(value) {
      checkmate::assert_character(value, any.missing = FALSE)
      rcpp_project_mass_spec_set_blank_names(private$.mass_spec_ptr, value)
      invisible(self)
    },
    #' @description Get concentrations named by analysis.
    get_concentrations = function() {
      rcpp_project_mass_spec_get_concentrations(private$.mass_spec_ptr)
    },
    #' @description Set concentrations by analysis order.
    #' @param value Numeric vector of concentrations matching the number of analyses.
    set_concentrations = function(value) {
      if (!is.numeric(value)) stop("value must be numeric.")
      rcpp_project_mass_spec_set_concentrations(private$.mass_spec_ptr, value)
      invisible(self)
    },
    #' @description Return spectra headers for selected analyses.
    #' @template arg-analyses
    get_spectra_headers = function(analyses = NULL) {
      analyses_info <- data.table::as.data.table(self$list_analyses())
      all_names <- analyses_info$analysis
      sel_names <- .resolve_analyses_selection(analyses, all_names)
      if (length(sel_names) == 0) {
        return(data.table::data.table())
      }
      hd <- data.table::as.data.table(rcpp_project_mass_spec_get_spectra_headers(private$.mass_spec_ptr, sel_names))
      if (nrow(hd) == 0) {
        return(data.table::data.table())
      }
      replicates <- analyses_info$replicate
      names(replicates) <- analyses_info$analysis
      if ("project_id" %in% colnames(hd)) {
        hd[, project_id := NULL]
      }
      hd$replicate <- replicates[hd$analysis]
      data.table::setcolorder(hd, c("analysis", "replicate"))
      hd
    },
    #' @description Return spectra TIC rows for selected analyses.
    #' @template arg-analyses
    #' @template arg-ms-levels
    #' @template arg-ms-rt
    get_spectra_tic = function(analyses = NULL, levels = NULL, rt = NULL) {
      analyses_info <- data.table::as.data.table(self$list_analyses())
      all_names <- analyses_info$analysis
      sel_names <- .resolve_analyses_selection(analyses, all_names)
      if (length(sel_names) == 0) {
        return(data.table::data.table())
      }
      if (is.null(levels)) {
        levels <- integer()
      }
      if (is.null(rt)) {
        rt <- numeric()
      }
      data.table::as.data.table(rcpp_project_mass_spec_get_spectra_tic(
        private$.mass_spec_ptr,
        sel_names,
        as.integer(levels),
        as.numeric(rt)
      ))
    },
    #' @description Get raw spectra data for selected analyses.
    #' @template arg-analyses
    #' @template arg-ms-levels
    #' @template arg-ms-mass
    #' @template arg-ms-mz
    #' @template arg-ms-rt
    #' @template arg-ms-mobility
    #' @template arg-ms-ppm
    #' @template arg-ms-sec
    #' @template arg-ms-millisec
    #' @template arg-ms-id
    #' @template arg-ms-allTraces
    #' @template arg-ms-isolationWindow
    #' @template arg-ms-minIntensityMS1
    #' @template arg-ms-minIntensityMS2
    get_raw_spectra = function(
        analyses = NULL,
        levels = NULL,
        mass = NULL,
        mz = NULL,
        rt = NULL,
        mobility = NULL,
        ppm = 20,
        sec = 60,
        millisec = 5,
        id = NULL,
        allTraces = TRUE,
        isolationWindow = 1.3,
        minIntensityMS1 = 0,
        minIntensityMS2 = 0) {
      analyses_info <- data.table::as.data.table(self$list_analyses())
      all_names <- analyses_info$analysis
      if (!any(is.numeric(minIntensityMS1) | is.integer(minIntensityMS1))) minIntensityMS1 <- 0
      if (!any(is.numeric(minIntensityMS2) | is.integer(minIntensityMS2))) minIntensityMS2 <- 0
      if (is.data.frame(mz) && "analysis" %in% colnames(mz)) analyses <- mz$analysis
      if (is.data.frame(mass) && "analysis" %in% colnames(mass)) analyses <- mass$analysis
      sel_names <- .resolve_analyses_selection(analyses, all_names)
      if (length(sel_names) == 0) {
        return(data.table::data.table())
      }
      hd <- self$get_spectra_headers(sel_names)
      if (nrow(hd) == 0) {
        return(data.table::data.table())
      }
      if (is.null(levels)) levels <- unique(hd$level)
      if (!2 %in% levels) allTraces <- TRUE
      if (!is.logical(allTraces)) allTraces <- TRUE
      if (!any(is.numeric(isolationWindow) | is.integer(isolationWindow))) {
        isolationWindow <- 0
      }
      spec <- data.table::as.data.table(rcpp_project_mass_spec_get_raw_spectra(
        private$.mass_spec_ptr,
        sel_names,
        as.integer(levels),
        mass,
        mz,
        rt,
        mobility,
        if (is.null(id)) character() else as.character(id),
        ppm,
        sec,
        millisec,
        allTraces,
        isolationWindow,
        minIntensityMS1,
        minIntensityMS2
      ))
      if (nrow(spec) > 0) {
        if (!any(spec$mobility > 0)) spec$mobility <- NULL
        if ("id" %in% colnames(spec)) {
          data.table::setorder(spec, analysis, id, rt, mz)
        } else {
          data.table::setorder(spec, analysis, rt, mz)
        }
        data.table::setcolorder(spec, c("analysis", "replicate"))
      }
      spec
    },
    #' @description Get total ion current traces for selected analyses.
    #' @template arg-analyses
    #' @template arg-ms-levels
    #' @template arg-ms-rt
    get_raw_spectra_tic = function(analyses = NULL, levels = c(1, 2), rt = NULL) {
      traces <- self$get_spectra_tic(analyses, levels, rt)
      if (nrow(traces) == 0) {
        return(data.table::data.table())
      }
      traces <- traces[, .(analysis, replicate, polarity, level, rt, tic)]
      traces
    },
    #' @description Get base peak chromatogram traces for selected analyses.
    #' @template arg-analyses
    #' @template arg-ms-levels
    #' @template arg-ms-rt
    get_raw_spectra_bpc = function(analyses = NULL, levels = c(1, 2), rt = NULL) {
      traces <- self$get_spectra_tic(analyses, levels, rt)
      if (nrow(traces) == 0) {
        return(data.table::data.table())
      }
      traces <- traces[, .(analysis, replicate, polarity, level, rt, bpmz, bpint)]
      traces
    },
    #' @description Plot total ion current traces for selected analyses.
    #' @template arg-analyses
    #' @template arg-ms-levels
    #' @template arg-ms-rt
    #' @template arg-plot-downsize
    #' @template arg-plot-xLab
    #' @template arg-plot-yLab
    #' @template arg-plot-title
    #' @template arg-plot-groupBy
    #' @template arg-plot-interactive
    #' @template arg-plot-colorPalette
    plot_spectra_tic = function(
        analyses = NULL,
        levels = c(1, 2),
        rt = NULL,
        downsize = NULL,
        xLab = NULL,
        yLab = NULL,
        title = NULL,
        groupBy = "analysis",
        interactive = TRUE,
        colorPalette = NULL) {
      tic <- self$get_raw_spectra_tic(analyses, levels, rt)
      if (nrow(tic) == 0) {
        message("\U2717 TIC not found for the analyses!")
        return(NULL)
      }
      if (!is.null(downsize) && downsize > 0 && nrow(tic) > downsize) {
        tic <- data.table::as.data.table(tic)
        tic$rt <- floor(tic$rt / downsize) * downsize
        tic <- tic[, lapply(.SD, function(col) {
          if (is.numeric(col)) {
            mean(col, na.rm = TRUE)
          } else if (is.character(col)) {
            col[1]
          } else {
            col[1]
          }
        }), by = .(rt, analysis)]
      }
      if (is.null(xLab)) xLab <- "Retention time / seconds"
      if (is.null(yLab)) yLab <- "Intensity / counts"
      .plot_lines_tabular_data(
        data = tic,
        xvar = "rt",
        yvar = "tic",
        groupBy = groupBy,
        basicGroupBy = "analysis",
        interactive = interactive,
        title = title,
        xLab = xLab,
        yLab = yLab,
        colorPalette = colorPalette
      )
    },
    #' @description Plot base peak chromatogram traces for selected analyses.
    #' @template arg-analyses
    #' @template arg-ms-levels
    #' @template arg-ms-rt
    #' @template arg-plot-downsize
    #' @template arg-plot-xLab
    #' @template arg-plot-yLab
    #' @template arg-plot-title
    #' @template arg-plot-groupBy
    #' @template arg-plot-interactive
    #' @template arg-plot-colorPalette
    plot_spectra_bpc = function(
        analyses = NULL,
        levels = c(1, 2),
        rt = NULL,
        downsize = NULL,
        xLab = NULL,
        yLab = NULL,
        title = NULL,
        groupBy = "analysis",
        interactive = TRUE,
        colorPalette = NULL) {
      bpc <- self$get_raw_spectra_bpc(analyses, levels, rt)
      if (nrow(bpc) == 0) {
        message("\U2717 BPC not found for the analyses!")
        return(NULL)
      }
      if (!is.null(downsize) && downsize > 0 && nrow(bpc) > downsize) {
        bpc <- data.table::as.data.table(bpc)
        bpc[, rt := floor(rt / downsize) * downsize]
        bpc <- bpc[, lapply(.SD, function(col) {
          if (is.numeric(col)) {
            mean(col, na.rm = TRUE)
          } else if (is.character(col)) {
            col[1]
          } else {
            col[1]
          }
        }), by = .(rt, analysis)]
      }
      if (is.null(xLab)) xLab <- "Retention time / seconds"
      if (is.null(yLab)) yLab <- "Intensity / counts"
      .plot_lines_tabular_data(
        data = bpc,
        xvar = "rt",
        yvar = "bpint",
        groupBy = groupBy,
        basicGroupBy = "analysis",
        interactive = interactive,
        title = title,
        xLab = xLab,
        yLab = yLab,
        colorPalette = colorPalette
      )
    },
    #' @description Get extracted ion chromatograms for selected analyses.
    #' @template arg-analyses
    #' @template arg-ms-mass
    #' @template arg-ms-mz
    #' @template arg-ms-rt
    #' @template arg-ms-mobility
    #' @template arg-ms-ppm
    #' @template arg-ms-sec
    #' @template arg-ms-millisec
    #' @template arg-ms-id
    get_raw_spectra_eic = function(
        analyses = NULL,
        mass = NULL,
        mz = NULL,
        rt = NULL,
        mobility = NULL,
        ppm = 20,
        sec = 60,
        millisec = 5,
        id = NULL) {
      eic <- self$get_raw_spectra(
        analyses = analyses,
        levels = 1,
        mass = mass,
        mz = mz,
        rt = rt,
        mobility = mobility,
        ppm = ppm,
        sec = sec,
        millisec = millisec,
        id = id,
        allTraces = TRUE,
        isolationWindow = 1.3,
        minIntensityMS1 = 0,
        minIntensityMS2 = 0
      )
      if (nrow(eic) > 0) {
        intensity <- NULL
        eic <- data.table::as.data.table(eic)
        if (!"id" %in% colnames(eic)) {
          eic$id <- NA_character_
        }
        if (!"polarity" %in% colnames(eic)) {
          eic$polarity <- 0
        }
        cols_summary <- c("analysis", "replicate", "polarity", "id", "rt")
        mz <- NULL
        eic <- eic[, .(intensity = max(intensity), mz = mean(mz)), by = cols_summary]
        sel_cols <- c("analysis", "replicate", "id", "polarity", "rt", "mz", "intensity")
        eic <- eic[, sel_cols, with = FALSE]
        eic <- unique(eic)
      }
      eic
    },
    #' @description Plot extracted ion chromatograms for selected analyses.
    #' @template arg-analyses
    #' @template arg-ms-mass
    #' @template arg-ms-mz
    #' @template arg-ms-rt
    #' @template arg-ms-mobility
    #' @template arg-ms-ppm
    #' @template arg-ms-sec
    #' @template arg-ms-millisec
    #' @template arg-ms-id
    #' @template arg-plot-downsize
    #' @template arg-plot-xLab
    #' @template arg-plot-yLab
    #' @template arg-plot-title
    #' @template arg-plot-groupBy
    #' @template arg-plot-interactive
    #' @template arg-plot-colorPalette
    plot_spectra_eic = function(
        analyses = NULL,
        mass = NULL,
        mz = NULL,
        rt = NULL,
        mobility = NULL,
        ppm = 20,
        sec = 60,
        millisec = 5,
        id = NULL,
        downsize = NULL,
        xLab = NULL,
        yLab = NULL,
        title = NULL,
        groupBy = c("analysis", "id"),
        interactive = TRUE,
        colorPalette = NULL) {
      eic <- self$get_raw_spectra_eic(analyses, mass, mz, rt, mobility, ppm, sec, millisec, id)
      if (nrow(eic) == 0) {
        message("\U2717 EIC not found for the analyses!")
        return(NULL)
      }
      if (!is.null(downsize) && downsize > 0 && nrow(eic) > downsize) {
        eic <- data.table::as.data.table(eic)
        eic$rt <- floor(eic$rt / downsize) * downsize
        group_cols <- c("rt", "analysis", "id")
        eic <- eic[, lapply(.SD, function(col) {
          if (is.numeric(col)) {
            mean(col, na.rm = TRUE)
          } else if (is.character(col)) {
            col[1]
          } else {
            col[1]
          }
        }), by = group_cols]
      }
      if (is.null(xLab)) xLab <- "Retention time / seconds"
      if (is.null(yLab)) yLab <- "Intensity / counts"
      .plot_lines_tabular_data(
        data = eic,
        xvar = "rt",
        yvar = "intensity",
        groupBy = groupBy,
        basicGroupBy = c("analysis", "id"),
        interactive = interactive,
        title = title,
        xLab = xLab,
        yLab = yLab,
        colorPalette = colorPalette
      )
    },
    #' @description Get clustered MS1 spectra for selected analyses.
    #' @template arg-analyses
    #' @template arg-ms-mass
    #' @template arg-ms-mz
    #' @template arg-ms-rt
    #' @template arg-ms-mobility
    #' @template arg-ms-ppm
    #' @template arg-ms-sec
    #' @template arg-ms-millisec
    #' @template arg-ms-id
    #' @template arg-ms-mzClust
    #' @template arg-ms-presence
    #' @template arg-ms-minIntensity
    get_raw_spectra_ms1 = function(
        analyses = NULL,
        mass = NULL,
        mz = NULL,
        rt = NULL,
        mobility = NULL,
        ppm = 20,
        sec = 60,
        millisec = 5,
        id = NULL,
        mzClust = 0.003,
        presence = 0.8,
        minIntensity = 1000) {
      ms1 <- self$get_raw_spectra(
        analyses = analyses,
        levels = 1,
        mass = mass,
        mz = mz,
        rt = rt,
        mobility = mobility,
        ppm = ppm,
        sec = sec,
        millisec = millisec,
        id = id,
        allTraces = TRUE,
        minIntensityMS1 = minIntensity,
        minIntensityMS2 = 0
      )
      if (nrow(ms1) == 0) {
        return(ms1)
      }
      if (!"id" %in% colnames(ms1)) {
        hd <- self$get_spectra_headers(analyses)
        has_ion_mobility <- any(hd$mobility > 0)
        if (has_ion_mobility) {
          ms1$id <- paste(
            round(min(ms1$mz), 4), "-",
            round(max(ms1$mz), 4), "/",
            round(max(ms1$rt), 0), "-",
            round(min(ms1$rt), 0), "/",
            round(max(ms1$mobility), 0), "-",
            round(min(ms1$mobility), 0),
            sep = ""
          )
        } else {
          ms1$id <- paste(
            round(min(ms1$mz), 4), "-",
            round(max(ms1$mz), 4), "/",
            round(max(ms1$rt), 0), "-",
            round(min(ms1$rt), 0),
            sep = ""
          )
        }
      }
      if (!is.numeric(mzClust)) {
        mzClust <- 0.01
      }
      ms1$unique_id <- paste0(ms1$analysis, "_", ms1$id, "_", ms1$polarity)
      ms1_list <- rcpp_ms_cluster_spectra(ms1, mzClust, presence, FALSE)
      ms1_df <- data.table::rbindlist(ms1_list, fill = TRUE)
      ms1_df <- ms1_df[order(ms1_df$mz), ]
      ms1_df <- ms1_df[order(ms1_df$id), ]
      ms1_df <- ms1_df[order(ms1_df$analysis), ]
      analyses_info <- data.table::as.data.table(self$list_analyses())
      rpls <- analyses_info$replicate
      names(rpls) <- analyses_info$analysis
      ms1_df$replicate <- rpls[ms1_df$analysis]
      data.table::setcolorder(ms1_df, c("analysis", "replicate"))
      ms1_df
    },
    #' @description Get clustered MS2 spectra for selected analyses.
    #' @template arg-analyses
    #' @template arg-ms-mass
    #' @template arg-ms-mz
    #' @template arg-ms-rt
    #' @template arg-ms-mobility
    #' @template arg-ms-ppm
    #' @template arg-ms-sec
    #' @template arg-ms-millisec
    #' @template arg-ms-id
    #' @template arg-ms-isolationWindow
    #' @template arg-ms-mzClust
    #' @template arg-ms-presence
    #' @template arg-ms-minIntensity
    get_raw_spectra_ms2 = function(
        analyses = NULL,
        mass = NULL,
        mz = NULL,
        rt = NULL,
        mobility = NULL,
        ppm = 20,
        sec = 60,
        millisec = 5,
        id = NULL,
        isolationWindow = 1.3,
        mzClust = 0.005,
        presence = 0.8,
        minIntensity = 0) {
      ms2 <- self$get_raw_spectra(
        analyses = analyses,
        levels = 2,
        mass = mass,
        mz = mz,
        rt = rt,
        mobility = mobility,
        ppm = ppm,
        sec = sec,
        millisec = millisec,
        id = id,
        isolationWindow = isolationWindow,
        allTraces = FALSE,
        minIntensityMS1 = 0,
        minIntensityMS2 = minIntensity
      )
      if (nrow(ms2) == 0) {
        return(ms2)
      }
      if (!"id" %in% colnames(ms2)) {
        hd <- self$get_spectra_headers(analyses)
        has_ion_mobility <- any(hd$mobility > 0)
        if (has_ion_mobility) {
          ms2$id <- paste(
            round(min(ms2$mz), 4), "-",
            round(max(ms2$mz), 4), "/",
            round(max(ms2$rt), 0), "-",
            round(min(ms2$rt), 0), "/",
            round(max(ms2$mobility), 0), "-",
            round(min(ms2$mobility), 0),
            sep = ""
          )
        } else {
          ms2$id <- paste(
            round(min(ms2$mz), 4), "-",
            round(max(ms2$mz), 4), "/",
            round(max(ms2$rt), 0), "-",
            round(min(ms2$rt), 0),
            sep = ""
          )
        }
      }
      if (!is.numeric(mzClust)) {
        mzClust <- 0.01
      }
      ms2$unique_id <- paste0(ms2$analysis, "_", ms2$id, "_", ms2$polarity)
      ms2_list <- rcpp_ms_cluster_spectra(ms2, mzClust, presence, FALSE)
      ms2_df <- data.table::rbindlist(ms2_list, fill = TRUE)
      ms2_df <- ms2_df[order(ms2_df$mz), ]
      ms2_df <- ms2_df[order(ms2_df$id), ]
      ms2_df <- ms2_df[order(ms2_df$analysis), ]
      analyses_info <- data.table::as.data.table(self$list_analyses())
      rpls <- analyses_info$replicate
      names(rpls) <- analyses_info$analysis
      ms2_df$replicate <- rpls[ms2_df$analysis]
      data.table::setcolorder(ms2_df, c("analysis", "replicate"))
      ms2_df
    },
    #' @description Print a short summary.
    #' @param ... Additional arguments ignored.
    print = function(...) {
      cat("\nProjectMassSpec\n")
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

#' @name ProjectMassSpecS3
#' @title ProjectMassSpec S3 Methods
#' @description S3 interface methods for `ProjectMassSpec`.
#' These methods are thin wrappers over the `ProjectMassSpec` R6 methods and expose
#' the shared-project Mass Spec API through the package generics.
#' @details
#' Available methods are:
#'
#' Metadata methods:
#' - `get_analysis_names()`: Get analysis names.
#' - `get_replicate_names()`: Get replicate names.
#' - `set_replicate_names()`: Set replicate names.
#' - `get_blank_names()`: Get blank names.
#' - `set_blank_names()`: Set blank names.
#' - `get_concentrations()`: Get concentrations.
#' - `set_concentrations()`: Set concentrations.
#'
#' Header methods:
#' - `get_spectra_headers()`: Fetch spectra headers for the specified analyses.
#' - `get_spectra_tic()`: Fetch spectra TIC rows for the specified analyses.
#'
#' Spectra trace methods:
#' - `get_raw_spectra_tic()`: Get the total ion current (TIC) spectra for the specified analyses.
#' - `get_raw_spectra_bpc()`: Get the base peak chromatograms (BPC) spectra for the specified analyses.
#' - `plot_spectra_tic()`: Plot total ion current (TIC) spectra for the specified analyses.
#' - `plot_spectra_bpc()`: Plot base peak chromatogram (BPC) spectra for the specified analyses.
#'
#' Spectra extraction methods:
#' - `get_raw_spectra()`: Get raw spectra data from specified analyses, returning a `data.table` with the spectra data.
#' - `get_raw_spectra_eic()`: Get extracted ion chromatograms (EIC) for the specified analyses and targets.
#' - `plot_spectra_eic()`: Plot extracted ion chromatograms (EIC) for the specified analyses and targets.
#' - `get_raw_spectra_ms1()`: Get MS1 spectra for the specified analyses and targets.
#' - `get_raw_spectra_ms2()`: Get MS2 spectra for the specified analyses and targets.
#' @aliases get_raw_spectra_tic.ProjectMassSpec
#'   get_raw_spectra_bpc.ProjectMassSpec
#'   plot_spectra_tic.ProjectMassSpec
#'   plot_spectra_bpc.ProjectMassSpec
#'   get_spectra_headers.ProjectMassSpec
#'   get_analysis_names.ProjectMassSpec
#'   get_replicate_names.ProjectMassSpec
#'   set_replicate_names.ProjectMassSpec
#'   get_blank_names.ProjectMassSpec
#'   set_blank_names.ProjectMassSpec
#'   get_concentrations.ProjectMassSpec
#'   set_concentrations.ProjectMassSpec
#'   get_raw_spectra.ProjectMassSpec
#'   get_raw_spectra_eic.ProjectMassSpec
#'   plot_spectra_eic.ProjectMassSpec
#'   get_raw_spectra_ms1.ProjectMassSpec
#'   get_raw_spectra_ms2.ProjectMassSpec
#' @param x A `ProjectMassSpec` object.
#' @rdname ProjectMassSpecS3
#' @template arg-analyses
#' @template arg-ms-levels
#' @template arg-ms-rt
#' @export
get_raw_spectra_tic.ProjectMassSpec <- function(
    x,
    analyses = NULL,
    levels = c(1, 2),
    rt = NULL) {
  checkmate::assert_class(x, "ProjectMassSpec")
  x$get_raw_spectra_tic(analyses = analyses, levels = levels, rt = rt)
}

#' @rdname ProjectMassSpecS3
#' @param x A `ProjectMassSpec` object.
#' @template arg-analyses
#' @template arg-ms-levels
#' @template arg-ms-rt
#' @export
get_raw_spectra_bpc.ProjectMassSpec <- function(
    x,
    analyses = NULL,
    levels = c(1, 2),
    rt = NULL) {
  checkmate::assert_class(x, "ProjectMassSpec")
  x$get_raw_spectra_bpc(analyses = analyses, levels = levels, rt = rt)
}

#' @rdname ProjectMassSpecS3
#' @param x A `ProjectMassSpec` object.
#' @template arg-analyses
#' @template arg-ms-levels
#' @template arg-ms-rt
#' @template arg-plot-downsize
#' @template arg-plot-xLab
#' @template arg-plot-yLab
#' @template arg-plot-title
#' @template arg-plot-groupBy
#' @template arg-plot-interactive
#' @template arg-plot-colorPalette
#' @export
plot_spectra_tic.ProjectMassSpec <- function(
    x,
    analyses = NULL,
    levels = c(1, 2),
    rt = NULL,
    downsize = NULL,
    xLab = NULL,
    yLab = NULL,
    title = NULL,
    groupBy = "analysis",
    interactive = TRUE,
    colorPalette = NULL) {
  checkmate::assert_class(x, "ProjectMassSpec")
  x$plot_spectra_tic(
    analyses = analyses,
    levels = levels,
    rt = rt,
    downsize = downsize,
    xLab = xLab,
    yLab = yLab,
    title = title,
    groupBy = groupBy,
    interactive = interactive,
    colorPalette = colorPalette
  )
}

#' @rdname ProjectMassSpecS3
#' @param x A `ProjectMassSpec` object.
#' @template arg-analyses
#' @template arg-ms-levels
#' @template arg-ms-rt
#' @template arg-plot-downsize
#' @template arg-plot-xLab
#' @template arg-plot-yLab
#' @template arg-plot-title
#' @template arg-plot-groupBy
#' @template arg-plot-interactive
#' @template arg-plot-colorPalette
#' @export
plot_spectra_bpc.ProjectMassSpec <- function(
    x,
    analyses = NULL,
    levels = c(1, 2),
    rt = NULL,
    downsize = NULL,
    xLab = NULL,
    yLab = NULL,
    title = NULL,
    groupBy = "analysis",
    interactive = TRUE,
    colorPalette = NULL) {
  checkmate::assert_class(x, "ProjectMassSpec")
  x$plot_spectra_bpc(
    analyses = analyses,
    levels = levels,
    rt = rt,
    downsize = downsize,
    xLab = xLab,
    yLab = yLab,
    title = title,
    groupBy = groupBy,
    interactive = interactive,
    colorPalette = colorPalette
  )
}

#' @rdname ProjectMassSpecS3
#' @param x A `ProjectMassSpec` object.
#' @template arg-analyses
#' @export
get_spectra_headers.ProjectMassSpec <- function(x, analyses = NULL) {
  checkmate::assert_class(x, "ProjectMassSpec")
  x$get_spectra_headers(analyses = analyses)
}

#' @rdname ProjectMassSpecS3
#' @param x A `ProjectMassSpec` object.
#' @export
info.ProjectMassSpec <- function(x, ...) {
  checkmate::assert_class(x, "ProjectMassSpec")
  analyses_info <- data.table::as.data.table(x$list_analyses())
  if (nrow(analyses_info) == 0) {
    return(data.table::data.table())
  }
  if ("project_id" %in% colnames(analyses_info)) {
    analyses_info[, project_id := NULL]
  }
  if ("number_spectra" %in% colnames(analyses_info)) {
    analyses_info[, spectra := number_spectra]
  }
  if ("number_chromatograms" %in% colnames(analyses_info)) {
    analyses_info[, chromatograms := number_chromatograms]
  }
  analyses_info
}

#' @rdname ProjectMassSpecS3
#' @param x A `ProjectMassSpec` object.
#' @param ... One or more file paths to import.
#' @export
add_analyses.ProjectMassSpec <- function(x, ...) {
  checkmate::assert_class(x, "ProjectMassSpec")
  dots <- list(...)
  file_paths <- unlist(dots, use.names = FALSE)
  checkmate::assert_character(file_paths, min.len = 1, any.missing = FALSE)
  x$import_files(file_paths = file_paths)
  invisible(x)
}

#' @rdname ProjectMassSpecS3
#' @param x A `ProjectMassSpec` object.
#' @param ... Character or integer analysis selection.
#' @export
remove_analyses.ProjectMassSpec <- function(x, ...) {
  checkmate::assert_class(x, "ProjectMassSpec")
  dots <- list(...)
  value <- if (length(dots) > 0) dots[[1]] else NULL
  analyses_info <- data.table::as.data.table(x$list_analyses())
  sel_names <- .resolve_analyses_selection(value, analyses_info$analysis)
  for (analysis in sel_names) {
    x$remove_analysis(analysis)
  }
  invisible(x)
}

#' @rdname ProjectMassSpecS3
#' @param x A `ProjectMassSpec` object.
#' @export
get_analysis_names.ProjectMassSpec <- function(x) {
  checkmate::assert_class(x, "ProjectMassSpec")
  x$get_analysis_names()
}

#' @rdname ProjectMassSpecS3
#' @param x A `ProjectMassSpec` object.
#' @export
get_replicate_names.ProjectMassSpec <- function(x) {
  checkmate::assert_class(x, "ProjectMassSpec")
  x$get_replicate_names()
}

#' @rdname ProjectMassSpecS3
#' @param x A `ProjectMassSpec` object.
#' @param value Character vector of replicate names matching the number of analyses.
#' @export
set_replicate_names.ProjectMassSpec <- function(x, value) {
  checkmate::assert_class(x, "ProjectMassSpec")
  x$set_replicate_names(value)
}

#' @rdname ProjectMassSpecS3
#' @param x A `ProjectMassSpec` object.
#' @export
get_blank_names.ProjectMassSpec <- function(x) {
  checkmate::assert_class(x, "ProjectMassSpec")
  x$get_blank_names()
}

#' @rdname ProjectMassSpecS3
#' @param x A `ProjectMassSpec` object.
#' @param value Character vector of blank names matching the number of analyses.
#' @export
set_blank_names.ProjectMassSpec <- function(x, value) {
  checkmate::assert_class(x, "ProjectMassSpec")
  x$set_blank_names(value)
}

#' @rdname ProjectMassSpecS3
#' @param x A `ProjectMassSpec` object.
#' @export
get_concentrations.ProjectMassSpec <- function(x) {
  checkmate::assert_class(x, "ProjectMassSpec")
  x$get_concentrations()
}

#' @rdname ProjectMassSpecS3
#' @param x A `ProjectMassSpec` object.
#' @param value Numeric vector of concentrations matching the number of analyses.
#' @export
set_concentrations.ProjectMassSpec <- function(x, value) {
  checkmate::assert_class(x, "ProjectMassSpec")
  x$set_concentrations(value)
}

#' @rdname ProjectMassSpecS3
#' @param x A `ProjectMassSpec` object.
#' @template arg-analyses
#' @template arg-ms-levels
#' @template arg-ms-mass
#' @template arg-ms-mz
#' @template arg-ms-rt
#' @template arg-ms-mobility
#' @template arg-ms-ppm
#' @template arg-ms-sec
#' @template arg-ms-millisec
#' @template arg-ms-id
#' @template arg-ms-allTraces
#' @template arg-ms-isolationWindow
#' @template arg-ms-minIntensityMS1
#' @template arg-ms-minIntensityMS2
#' @export
get_raw_spectra.ProjectMassSpec <- function(
    x,
    analyses = NULL,
    levels = NULL,
    mass = NULL,
    mz = NULL,
    rt = NULL,
    mobility = NULL,
    ppm = 20,
    sec = 60,
    millisec = 5,
    id = NULL,
    allTraces = TRUE,
    isolationWindow = 1.3,
    minIntensityMS1 = 0,
    minIntensityMS2 = 0) {
  checkmate::assert_class(x, "ProjectMassSpec")
  x$get_raw_spectra(
    analyses = analyses,
    levels = levels,
    mass = mass,
    mz = mz,
    rt = rt,
    mobility = mobility,
    ppm = ppm,
    sec = sec,
    millisec = millisec,
    id = id,
    allTraces = allTraces,
    isolationWindow = isolationWindow,
    minIntensityMS1 = minIntensityMS1,
    minIntensityMS2 = minIntensityMS2
  )
}

#' @rdname ProjectMassSpecS3
#' @param x A `ProjectMassSpec` object.
#' @template arg-analyses
#' @template arg-ms-mass
#' @template arg-ms-mz
#' @template arg-ms-rt
#' @template arg-ms-mobility
#' @template arg-ms-ppm
#' @template arg-ms-sec
#' @template arg-ms-millisec
#' @template arg-ms-id
#' @export
get_raw_spectra_eic.ProjectMassSpec <- function(
    x,
    analyses = NULL,
    mass = NULL,
    mz = NULL,
    rt = NULL,
    mobility = NULL,
    ppm = 20,
    sec = 60,
    millisec = 5,
    id = NULL) {
  checkmate::assert_class(x, "ProjectMassSpec")
  x$get_raw_spectra_eic(
    analyses = analyses,
    mass = mass,
    mz = mz,
    rt = rt,
    mobility = mobility,
    ppm = ppm,
    sec = sec,
    millisec = millisec,
    id = id
  )
}

#' @rdname ProjectMassSpecS3
#' @param x A `ProjectMassSpec` object.
#' @template arg-analyses
#' @template arg-ms-mass
#' @template arg-ms-mz
#' @template arg-ms-rt
#' @template arg-ms-mobility
#' @template arg-ms-ppm
#' @template arg-ms-sec
#' @template arg-ms-millisec
#' @template arg-ms-id
#' @template arg-plot-downsize
#' @template arg-plot-xLab
#' @template arg-plot-yLab
#' @template arg-plot-title
#' @template arg-plot-groupBy
#' @template arg-plot-interactive
#' @template arg-plot-colorPalette
#' @export
plot_spectra_eic.ProjectMassSpec <- function(
    x,
    analyses = NULL,
    mass = NULL,
    mz = NULL,
    rt = NULL,
    mobility = NULL,
    ppm = 20,
    sec = 60,
    millisec = 5,
    id = NULL,
    downsize = NULL,
    xLab = NULL,
    yLab = NULL,
    title = NULL,
    groupBy = c("analysis", "id"),
    interactive = TRUE,
    colorPalette = NULL) {
  checkmate::assert_class(x, "ProjectMassSpec")
  x$plot_spectra_eic(
    analyses = analyses,
    mass = mass,
    mz = mz,
    rt = rt,
    mobility = mobility,
    ppm = ppm,
    sec = sec,
    millisec = millisec,
    id = id,
    downsize = downsize,
    xLab = xLab,
    yLab = yLab,
    title = title,
    groupBy = groupBy,
    interactive = interactive,
    colorPalette = colorPalette
  )
}

#' @rdname ProjectMassSpecS3
#' @param x A `ProjectMassSpec` object.
#' @template arg-analyses
#' @template arg-ms-mass
#' @template arg-ms-mz
#' @template arg-ms-rt
#' @template arg-ms-mobility
#' @template arg-ms-ppm
#' @template arg-ms-sec
#' @template arg-ms-millisec
#' @template arg-ms-id
#' @template arg-ms-mzClust
#' @template arg-ms-presence
#' @template arg-ms-minIntensity
#' @export
get_raw_spectra_ms1.ProjectMassSpec <- function(
    x,
    analyses = NULL,
    mass = NULL,
    mz = NULL,
    rt = NULL,
    mobility = NULL,
    ppm = 20,
    sec = 60,
    millisec = 5,
    id = NULL,
    mzClust = 0.003,
    presence = 0.8,
    minIntensity = 1000) {
  checkmate::assert_class(x, "ProjectMassSpec")
  x$get_raw_spectra_ms1(
    analyses = analyses,
    mass = mass,
    mz = mz,
    rt = rt,
    mobility = mobility,
    ppm = ppm,
    sec = sec,
    millisec = millisec,
    id = id,
    mzClust = mzClust,
    presence = presence,
    minIntensity = minIntensity
  )
}

#' @rdname ProjectMassSpecS3
#' @param x A `ProjectMassSpec` object.
#' @template arg-analyses
#' @template arg-ms-mass
#' @template arg-ms-mz
#' @template arg-ms-rt
#' @template arg-ms-mobility
#' @template arg-ms-ppm
#' @template arg-ms-sec
#' @template arg-ms-millisec
#' @template arg-ms-id
#' @template arg-ms-isolationWindow
#' @template arg-ms-mzClust
#' @template arg-ms-presence
#' @template arg-ms-minIntensity
#' @export
get_raw_spectra_ms2.ProjectMassSpec <- function(
    x,
    analyses = NULL,
    mass = NULL,
    mz = NULL,
    rt = NULL,
    mobility = NULL,
    ppm = 20,
    sec = 60,
    millisec = 5,
    id = NULL,
    isolationWindow = 1.3,
    mzClust = 0.005,
    presence = 0.8,
    minIntensity = 0) {
  checkmate::assert_class(x, "ProjectMassSpec")
  x$get_raw_spectra_ms2(
    analyses = analyses,
    mass = mass,
    mz = mz,
    rt = rt,
    mobility = mobility,
    ppm = ppm,
    sec = sec,
    millisec = millisec,
    id = id,
    isolationWindow = isolationWindow,
    mzClust = mzClust,
    presence = presence,
    minIntensity = minIntensity
  )
}
