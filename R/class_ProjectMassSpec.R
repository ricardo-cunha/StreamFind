#' @title Internal Project Mass Spec Base R6 Class
#' @description Internal R6 child of `Project` exposing shared Mass Spec tables and native helpers.
#' @template arg-db-path
#' @template arg-project-id
#' @template arg-analyses
#' @template arg-chromatograms
#' @template arg-ms-levels
#' @template arg-ms-rt
#' @template arg-ms-rtmin
#' @template arg-ms-rtmax
#' @template arg-ms-mass
#' @template arg-ms-mz
#' @template arg-ms-mobility
#' @template arg-ms-ppm
#' @template arg-ms-sec
#' @template arg-ms-millisec
#' @template arg-ms-id
#' @template arg-ms-allTraces
#' @template arg-ms-isolationWindow
#' @template arg-ms-minIntensityMS1
#' @template arg-ms-minIntensityMS2
#' @template arg-plot-downsize
#' @template arg-plot-xLab
#' @template arg-plot-yLab
#' @template arg-plot-title
#' @template arg-plot-groupBy
#' @template arg-plot-interactive
#' @template arg-plot-colorPalette
#' @template arg-normalized
#' @template arg-showText
#' @template arg-ms-mzClust
#' @template arg-ms-presence
#' @template arg-ms-minIntensity
#' @template arg-ms-isolationWindow
#' @template arg-ellipsis
#' @template arg-import-file
#' @template arg-file-paths
#' @template arg-replicates
#' @template arg-blanks
#' @template arg-analysis
#' @template arg-value
#' @keywords internal
#'
ProjectMassSpec <- R6::R6Class(
  classname = "ProjectMassSpec",
  inherit = Project,
  cloneable = FALSE,
  private = list(
    .mass_spec_ptr = NULL
  ),
  public = list(
    #' @description Create a Mass Spec domain wrapper for a shared `Project`.
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
      .assert_only_internal_init_args(mass_spec_ptr_res$dots, "ProjectMassSpec$initialize()")
      super$initialize(db = db, project_id = project_id, .ptr = .ptr)
      private$.mass_spec_ptr <- if (is.null(.mass_spec_ptr)) {
        rcpp_project_mass_spec_new(self$get_ptr(), file_paths, replicates, blanks)
      } else {
        .mass_spec_ptr
      }
      if (!is.null(.mass_spec_ptr) && length(file_paths) > 0) {
        self$add_analyses(file_paths = file_paths, replicates = replicates, blanks = blanks)
      }
    },
    #' @description Return the native Mass Spec pointer.
    get_mass_spec_ptr = function() {
      private$.mass_spec_ptr
    },
    #' @description Add multiple Mass Spec files into the shared DB as analyses.
    add_analyses = function(file_paths, replicates = character(), blanks = character()) {
      checkmate::assert_character(file_paths, min.len = 1, any.missing = FALSE)
      checkmate::assert_character(replicates, any.missing = FALSE, null.ok = FALSE)
      checkmate::assert_character(blanks, any.missing = FALSE, null.ok = FALSE)
      if (length(replicates) > 0 && length(replicates) != length(file_paths)) {
        stop("`replicates` must have length 0 or match `file_paths`.")
      }
      if (length(blanks) > 0 && length(blanks) != length(file_paths)) {
        stop("`blanks` must have length 0 or match `file_paths`.")
      }
      rcpp_project_mass_spec_import_files(private$.mass_spec_ptr, file_paths, replicates, blanks)
      invisible(self)
    },
    #' @description Remove analyses from the shared DB.
    remove_analyses = function(analyses) {
      checkmate::assert_character(analyses, min.len = 1, any.missing = FALSE)
      for (analysis in analyses) {
        rcpp_project_mass_spec_remove_analysis(private$.mass_spec_ptr, analysis)
      }
      invisible(self)
    },
    #' @description Return imported analyses.
    get_analyses = function() {
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
    set_concentrations = function(value) {
      if (!is.numeric(value)) stop("value must be numeric.")
      rcpp_project_mass_spec_set_concentrations(private$.mass_spec_ptr, value)
      invisible(self)
    },
    #' @description Return spectra headers for selected analyses.
    get_spectra_headers = function(analyses = NULL) {
      if (is.null(analyses)) {
        analyses <- character()
      }
      analyses_info <- data.table::as.data.table(self$get_analyses())
      hd <- data.table::as.data.table(rcpp_project_mass_spec_get_spectra_headers(private$.mass_spec_ptr, analyses))
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
    get_spectra_tic = function(analyses = NULL, levels = NULL, rt = NULL) {
      if (is.null(analyses)) {
        analyses <- character()
      }
      if (is.null(levels)) {
        levels <- integer()
      }
      if (is.null(rt)) {
        rt <- numeric()
      }
      data.table::as.data.table(rcpp_project_mass_spec_get_spectra_tic(
        private$.mass_spec_ptr,
        analyses,
        as.integer(levels),
        as.numeric(rt)
      ))
    },
    #' @description Return chromatogram headers for selected analyses.
    get_chromatograms_headers = function(analyses = NULL) {
      if (is.null(analyses)) {
        analyses <- character()
      }
      analyses_info <- data.table::as.data.table(self$get_analyses())
      hd <- data.table::as.data.table(rcpp_project_mass_spec_get_chromatograms_headers(private$.mass_spec_ptr, analyses))
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
    #' @description Get raw chromatograms for selected analyses.
    get_raw_chromatograms = function(analyses = NULL,
                                     chromatograms = NULL,
                                     rtmin = 0,
                                     rtmax = 0,
                                     minIntensity = NULL) {
      chrom_hd <- self$get_chromatograms_headers(analyses)
      if (nrow(chrom_hd) == 0) {
        message("\U2717 No chromatograms found for the analyses!")
        return(data.table::data.table())
      }
      if (is.numeric(chromatograms)) {
        chrom_hd <- chrom_hd[as.integer(chrom_hd$index) == as.integer(chromatograms), ]
      } else if (is.character(chromatograms)) {
        chrom_hd <- chrom_hd[chrom_hd$id %in% chromatograms, ]
      }
      if (nrow(chrom_hd) == 0) {
        message("\U2717 No chromatograms found for the specified IDs/indices!")
        return(data.table::data.table())
      }
      sel_analyses <- unique(chrom_hd$analysis)
      chrom_hd_list <- split(chrom_hd, chrom_hd$analysis)
      chrom_list <- lapply(sel_analyses, function(aname) {
        chrom_hd_a <- chrom_hd_list[[aname]]
        data.table::as.data.table(rcpp_project_mass_spec_get_raw_chromatograms(
          private$.mass_spec_ptr,
          aname,
          as.integer(chrom_hd_a$index)
        ))
      })
      chrom_dt <- data.table::rbindlist(chrom_list, fill = TRUE)
      if (nrow(chrom_dt) == 0) {
        message("\U2717 No chromatogram data found for the specified analyses!")
        return(data.table::data.table())
      }
      if (is.numeric(minIntensity)) {
        chrom_dt <- chrom_dt[chrom_dt$intensity > minIntensity, ]
      }
      if (is.numeric(rtmin) && is.numeric(rtmax) && rtmax > 0) {
        chrom_dt <- chrom_dt[chrom_dt$rt >= rtmin & chrom_dt$rt <= rtmax]
      }
      data.table::setcolorder(chrom_dt, c("analysis", "replicate"))
      chrom_dt
    },
    #' @description Plot raw chromatograms for selected analyses.
    plot_raw_chromatograms = function(analyses = NULL,
                                      chromatograms = NULL,
                                      rtmin = 0,
                                      rtmax = 0,
                                      minIntensity = NULL,
                                      downsize = NULL,
                                      xLab = NULL,
                                      yLab = NULL,
                                      title = NULL,
                                      groupBy = "analysis",
                                      interactive = TRUE,
                                      colorPalette = NULL) {
      chrom <- self$get_raw_chromatograms(analyses, chromatograms, rtmin, rtmax, minIntensity)
      if (nrow(chrom) == 0) {
        message("\U2717 No chromatogram data found for plotting!")
        return(NULL)
      }
      if (!is.null(downsize) && downsize > 0 && nrow(chrom) > downsize) {
        chrom <- data.table::as.data.table(chrom)
        chrom$rt <- floor(chrom$rt / downsize) * downsize
        chrom <- chrom[, lapply(.SD, function(col) {
          if (is.numeric(col)) {
            mean(col, na.rm = TRUE)
          } else if (is.character(col)) {
            col[1]
          } else {
            col[1]
          }
        }), by = .(rt, analysis, id)]
      }
      if (is.null(xLab)) xLab <- "Retention time / seconds"
      if (is.null(yLab)) yLab <- "Intensity / counts"
      .plot_lines_tabular_data(
        data = chrom,
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
    #' @description Get raw spectra data for selected analyses.
    get_raw_spectra = function(analyses = character(),
                               levels = integer(),
                               mass = numeric(),
                               mz = numeric(),
                               rt = numeric(),
                               mobility = numeric(),
                               ppm = 20,
                               sec = 60,
                               millisec = 5,
                               id = character(),
                               allTraces = TRUE,
                               isolationWindow = 1.3,
                               minIntensityMS1 = 0,
                               minIntensityMS2 = 0) {
      if (is.null(analyses)) {
        analyses <- character()
      }
      if (is.null(mass)) {
        mass <- numeric()
      }
      if (is.null(mz)) {
        mz <- numeric()
      }
      if (is.null(rt)) {
        rt <- numeric()
      }
      if (is.null(mobility)) {
        mobility <- numeric()
      }
      if (is.null(id)) {
        id <- character()
      }
      if (is.null(levels)) {
        levels <- integer()
      }
      if (!(checkmate::test_character(analyses, any.missing = FALSE) || checkmate::test_integerish(analyses, any.missing = FALSE, lower = 1))) {
        stop("`analyses` must be a character vector of names or a numeric vector of 1-based indices.")
      }
      checkmate::assert_integerish(levels, any.missing = FALSE, lower = 1)
      if (!(checkmate::test_numeric(mass, any.missing = FALSE) || checkmate::test_data_frame(mass))) {
        stop("`mass` must be a numeric vector or a data.frame.")
      }
      if (!(checkmate::test_numeric(mz, any.missing = FALSE) || checkmate::test_data_frame(mz))) {
        stop("`mz` must be a numeric vector or a data.frame.")
      }
      if (!(checkmate::test_numeric(rt, any.missing = FALSE) || checkmate::test_data_frame(rt))) {
        stop("`rt` must be a numeric vector or a data.frame.")
      }
      if (!(checkmate::test_numeric(mobility, any.missing = FALSE) || checkmate::test_data_frame(mobility))) {
        stop("`mobility` must be a numeric vector or a data.frame.")
      }
      checkmate::assert_character(id, any.missing = FALSE)
      checkmate::assert_number(ppm, lower = 0, finite = TRUE)
      checkmate::assert_number(sec, lower = 0, finite = TRUE)
      checkmate::assert_number(millisec, lower = 0, finite = TRUE)
      checkmate::assert_flag(allTraces)
      checkmate::assert_number(isolationWindow, lower = 0, finite = TRUE)
      checkmate::assert_number(minIntensityMS1, lower = 0, finite = TRUE)
      checkmate::assert_number(minIntensityMS2, lower = 0, finite = TRUE)
      spec <- data.table::as.data.table(rcpp_project_mass_spec_get_raw_spectra(
        private$.mass_spec_ptr,
        analyses,
        as.integer(levels),
        mass,
        mz,
        rt,
        mobility,
        as.character(id),
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
        data.table::setcolorder(spec, c("analysis", "replicate"))
      }
      spec
    },
    #' @description Plot total ion current traces for selected analyses.
    plot_spectra_tic = function(analyses = NULL,
                                levels = c(1, 2),
                                rt = NULL,
                                downsize = NULL,
                                xLab = NULL,
                                yLab = NULL,
                                title = NULL,
                                groupBy = "analysis",
                                interactive = TRUE,
                                colorPalette = NULL) {
      tic <- data.table::as.data.table(self$get_spectra_tic(analyses, levels, rt))
      if (nrow(tic) == 0) {
        message("\U2717 TIC not found for the analyses!")
        return(NULL)
      }
      tic <- tic[, .(analysis, replicate, polarity, level, rt, tic)]
      if (!is.null(downsize) && downsize > 0 && nrow(tic) > downsize) {
        tic[, rt := floor(rt / downsize) * downsize]
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
    plot_spectra_bpc = function(analyses = NULL,
                                levels = c(1, 2),
                                rt = NULL,
                                downsize = NULL,
                                xLab = NULL,
                                yLab = NULL,
                                title = NULL,
                                groupBy = "analysis",
                                interactive = TRUE,
                                colorPalette = NULL) {
      bpc <- data.table::as.data.table(self$get_spectra_tic(analyses, levels, rt))
      if (nrow(bpc) == 0) {
        message("\U2717 BPC not found for the analyses!")
        return(NULL)
      }
      bpc <- bpc[, .(analysis, replicate, polarity, level, rt, bpmz, bpint)]
      if (!is.null(downsize) && downsize > 0 && nrow(bpc) > downsize) {
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
    get_raw_spectra_eic = function(analyses = NULL,
                                   mass = NULL,
                                   mz = NULL,
                                   rt = NULL,
                                   mobility = NULL,
                                   ppm = 20,
                                   sec = 60,
                                   millisec = 5,
                                   id = NULL) {
      data.table::as.data.table(rcpp_project_mass_spec_get_raw_spectra_eic(
        private$.mass_spec_ptr,
        analyses,
        mass,
        mz,
        rt,
        mobility,
        as.character(id),
        ppm,
        sec,
        millisec
      ))
    },
    #' @description Plot extracted ion chromatograms for selected analyses.
    plot_raw_spectra_eic = function(analyses = NULL,
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
    get_raw_spectra_ms1 = function(analyses = NULL,
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
      data.table::as.data.table(rcpp_project_mass_spec_get_raw_spectra_ms1(
        private$.mass_spec_ptr,
        analyses,
        mass,
        mz,
        rt,
        mobility,
        as.character(id),
        ppm,
        sec,
        millisec,
        as.numeric(mzClust),
        as.numeric(presence),
        as.numeric(minIntensity)
      ))
    },
    #' @description Get clustered MS2 spectra for selected analyses.
    get_raw_spectra_ms2 = function(analyses = NULL,
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
                                   presence = 0,
                                   minIntensity = 0) {
      data.table::as.data.table(rcpp_project_mass_spec_get_raw_spectra_ms2(
        private$.mass_spec_ptr,
        analyses,
        mass,
        mz,
        rt,
        mobility,
        as.character(id),
        ppm,
        sec,
        millisec,
        as.numeric(isolationWindow),
        as.numeric(mzClust),
        as.numeric(presence),
        as.numeric(minIntensity)
      ))
    },
    #' @description Plot clustered MS1 spectra for selected analyses.
    plot_raw_spectra_ms1 = function(analyses = NULL,
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
                                    minIntensity = 1000,
                                    normalized = FALSE,
                                    xLab = NULL,
                                    yLab = NULL,
                                    title = NULL,
                                    groupBy = "id",
                                    showText = TRUE,
                                    interactive = TRUE) {
      ms1 <- self$get_raw_spectra_ms1(
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
      if (nrow(ms1) == 0) {
        message("\U2717 MS1 traces not found for the targets!")
        return(NULL)
      }
      .plot_raw_spectra_tabular_data(
        data = ms1,
        groupBy = groupBy,
        normalized = normalized,
        interactive = interactive,
        title = title,
        xLab = xLab,
        yLab = yLab,
        showText = showText
      )
    },
    #' @description Plot clustered MS2 spectra for selected analyses.
    plot_raw_spectra_ms2 = function(analyses = NULL,
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
                                    presence = 0,
                                    minIntensity = 0,
                                    normalized = TRUE,
                                    xLab = NULL,
                                    yLab = NULL,
                                    title = NULL,
                                    groupBy = "id",
                                    showText = TRUE,
                                    interactive = TRUE) {
      ms2 <- self$get_raw_spectra_ms2(
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
      if (nrow(ms2) == 0) {
        message("\U2717 MS2 traces not found for the targets!")
        return(NULL)
      }
      .plot_raw_spectra_tabular_data(
        data = ms2,
        groupBy = groupBy,
        normalized = normalized,
        interactive = interactive,
        title = title,
        xLab = xLab,
        yLab = yLab,
        showText = showText,
        precursorTol = mzClust
      )
    },
    #' @description Print a short summary.
    print = function(...) {
      cat("\nProjectMassSpec\n")
      cat("db: ", self$get_db(), "\n", sep = "")
      cat("project_id: ", self$get_project_id(), "\n", sep = "")
      domain <- try(self$get_domain(), silent = TRUE)
      if (!inherits(domain, "try-error") && !is.null(domain)) {
        cat("domain: ", domain, "\n", sep = "")
      }
      analyses <- try(self$get_analyses(), silent = TRUE)
      if (!inherits(analyses, "try-error")) {
        cat("analyses: ", nrow(analyses), "\n", sep = "")
      }
      invisible(self)
    },
    #' @description Show a short summary.
    show = function(...) {
      self$print(...)
    }
  )
)

#' @name ProjectMassSpecS3
#' @title ProjectMassSpec S3 Methods
#' @description S3 interface methods for `ProjectMassSpec`.
#' @param x A `ProjectMassSpec` object.
#' @template arg-analyses
#' @template arg-chromatograms
#' @template arg-ms-levels
#' @template arg-ms-rt
#' @template arg-ms-rtmin
#' @template arg-ms-rtmax
#' @template arg-ms-mass
#' @template arg-ms-mz
#' @template arg-ms-mobility
#' @template arg-ms-ppm
#' @template arg-ms-sec
#' @template arg-ms-millisec
#' @template arg-ms-id
#' @template arg-ms-allTraces
#' @template arg-ms-isolationWindow
#' @template arg-ms-minIntensityMS1
#' @template arg-ms-minIntensityMS2
#' @template arg-plot-downsize
#' @template arg-plot-xLab
#' @template arg-plot-yLab
#' @template arg-plot-title
#' @template arg-plot-groupBy
#' @template arg-plot-interactive
#' @template arg-plot-colorPalette
#' @template arg-normalized
#' @template arg-showText
NULL

#' @describeIn ProjectMassSpecS3 Return chromatogram headers for selected analyses.
#' @method get_chromatograms_headers ProjectMassSpec
#' @export
get_chromatograms_headers.ProjectMassSpec <- function(x, analyses = NULL) {
  checkmate::assert_class(x, "ProjectMassSpec")
  x$get_chromatograms_headers(analyses = analyses)
}

#' @describeIn ProjectMassSpecS3 Get raw chromatograms for selected analyses.
#' @method get_raw_chromatograms ProjectMassSpec
#' @export
get_raw_chromatograms.ProjectMassSpec <- function(
  x,
  analyses = NULL,
  chromatograms = NULL,
  rtmin = 0,
  rtmax = 0,
  minIntensity = NULL
) {
  checkmate::assert_class(x, "ProjectMassSpec")
  x$get_raw_chromatograms(
    analyses = analyses,
    chromatograms = chromatograms,
    rtmin = rtmin,
    rtmax = rtmax,
    minIntensity = minIntensity
  )
}

#' @describeIn ProjectMassSpecS3 Plot raw chromatograms for selected analyses.
#' @method plot_raw_chromatograms ProjectMassSpec
#' @export
plot_raw_chromatograms.ProjectMassSpec <- function(
  x,
  analyses = NULL,
  chromatograms = NULL,
  rtmin = 0,
  rtmax = 0,
  minIntensity = NULL,
  downsize = NULL,
  xLab = NULL,
  yLab = NULL,
  title = NULL,
  groupBy = "analysis",
  interactive = TRUE,
  colorPalette = NULL
) {
  checkmate::assert_class(x, "ProjectMassSpec")
  x$plot_raw_chromatograms(
    analyses = analyses,
    chromatograms = chromatograms,
    rtmin = rtmin,
    rtmax = rtmax,
    minIntensity = minIntensity,
    downsize = downsize,
    xLab = xLab,
    yLab = yLab,
    title = title,
    groupBy = groupBy,
    interactive = interactive,
    colorPalette = colorPalette
  )
}

#' @describeIn ProjectMassSpecS3 Return imported analyses.
#' @method get_analyses ProjectMassSpec
#' @export
get_analyses.ProjectMassSpec <- function(x) {
  checkmate::assert_class(x, "ProjectMassSpec")
  x$get_analyses()
}

#' @describeIn ProjectMassSpecS3 Plot total ion current (TIC) spectra for specified analyses.
#' @method plot_spectra_tic ProjectMassSpec
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
  colorPalette = NULL
) {
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

#' @describeIn ProjectMassSpecS3 Plot base peak chromatogram (BPC) spectra for specified analyses.
#' @method plot_spectra_bpc ProjectMassSpec
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
  colorPalette = NULL
) {
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

#' @describeIn ProjectMassSpecS3 Fetch spectra headers for specified analyses.
#' @method get_spectra_headers ProjectMassSpec
#' @export
get_spectra_headers.ProjectMassSpec <- function(x, analyses = NULL) {
  checkmate::assert_class(x, "ProjectMassSpec")
  x$get_spectra_headers(analyses = analyses)
}

#' @describeIn ProjectMassSpecS3 Print a short information table for the project analyses.
#' @method info ProjectMassSpec
#' @export
info.ProjectMassSpec <- function(x, ...) {
  checkmate::assert_class(x, "ProjectMassSpec")
  analyses_info <- data.table::as.data.table(x$get_analyses())
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

#' @describeIn ProjectMassSpecS3 Import one or more data files into the project as analyses.
#' @method add_analyses ProjectMassSpec
#' @export
add_analyses.ProjectMassSpec <- function(x, ...) {
  checkmate::assert_class(x, "ProjectMassSpec")
  dots <- list(...)
  file_paths <- unlist(dots, use.names = FALSE)
  checkmate::assert_character(file_paths, min.len = 1, any.missing = FALSE)
  x$add_analyses(file_paths = file_paths)
  invisible(x)
}

#' @describeIn ProjectMassSpecS3 Remove analyses from the project by name or index.
#' @method remove_analyses ProjectMassSpec
#' @export
remove_analyses.ProjectMassSpec <- function(x, ...) {
  checkmate::assert_class(x, "ProjectMassSpec")
  dots <- list(...)
  value <- if (length(dots) > 0) dots[[1]] else NULL
  analyses_info <- data.table::as.data.table(x$get_analyses())
  sel_names <- .resolve_analyses_selection(value, analyses_info$analysis)
  x$remove_analyses(sel_names)
  invisible(x)
}

#' @describeIn ProjectMassSpecS3 Return analysis names for the project.
#' @method get_analysis_names ProjectMassSpec
#' @export
get_analysis_names.ProjectMassSpec <- function(x) {
  checkmate::assert_class(x, "ProjectMassSpec")
  x$get_analysis_names()
}

#' @describeIn ProjectMassSpecS3 Return replicate names for the project.
#' @method get_replicate_names ProjectMassSpec
#' @export
get_replicate_names.ProjectMassSpec <- function(x) {
  checkmate::assert_class(x, "ProjectMassSpec")
  x$get_replicate_names()
}

#' @describeIn ProjectMassSpecS3 Set replicate names for the project analyses.
#' @method set_replicate_names ProjectMassSpec
#' @export
set_replicate_names.ProjectMassSpec <- function(x, value) {
  checkmate::assert_class(x, "ProjectMassSpec")
  x$set_replicate_names(value)
}

#' @describeIn ProjectMassSpecS3 Return blank names for the project.
#' @method get_blank_names ProjectMassSpec
#' @export
get_blank_names.ProjectMassSpec <- function(x) {
  checkmate::assert_class(x, "ProjectMassSpec")
  x$get_blank_names()
}

#' @describeIn ProjectMassSpecS3 Set blank names for the project analyses.
#' @method set_blank_names ProjectMassSpec
#' @export
set_blank_names.ProjectMassSpec <- function(x, value) {
  checkmate::assert_class(x, "ProjectMassSpec")
  x$set_blank_names(value)
}

#' @describeIn ProjectMassSpecS3 Return concentrations vector for the project.
#' @method get_concentrations ProjectMassSpec
#' @export
get_concentrations.ProjectMassSpec <- function(x) {
  checkmate::assert_class(x, "ProjectMassSpec")
  x$get_concentrations()
}

#' @describeIn ProjectMassSpecS3 Set concentrations for the project analyses.
#' @method set_concentrations ProjectMassSpec
#' @export
set_concentrations.ProjectMassSpec <- function(x, value) {
  checkmate::assert_class(x, "ProjectMassSpec")
  x$set_concentrations(value)
}

#' @describeIn ProjectMassSpecS3 Get raw spectra data for specified analyses; returns a data.table with spectra rows.
#' @method get_raw_spectra ProjectMassSpec
#' @export
get_raw_spectra.ProjectMassSpec <- function(
  x,
  analyses = character(),
  levels = integer(),
  mass = numeric(),
  mz = numeric(),
  rt = numeric(),
  mobility = numeric(),
  ppm = 20,
  sec = 60,
  millisec = 5,
  id = character(),
  allTraces = TRUE,
  isolationWindow = 1.3,
  minIntensityMS1 = 0,
  minIntensityMS2 = 0
) {
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

#' @describeIn ProjectMassSpecS3 Get extracted ion chromatograms (EIC) for specified analyses.
#' @method get_raw_spectra_eic ProjectMassSpec
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
  id = NULL
) {
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

#' @describeIn ProjectMassSpecS3 Plot extracted ion chromatograms (EIC) for specified analyses and targets.
#' @method plot_raw_spectra_eic ProjectMassSpec
#' @export
plot_raw_spectra_eic.ProjectMassSpec <- function(
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
  colorPalette = NULL
) {
  checkmate::assert_class(x, "ProjectMassSpec")
  x$plot_raw_spectra_eic(
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

#' @describeIn ProjectMassSpecS3 Plot clustered MS1 spectra for specified analyses and targets.
#' @method plot_raw_spectra_ms1 ProjectMassSpec
#' @export
plot_raw_spectra_ms1.ProjectMassSpec <- function(
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
  minIntensity = 1000,
  normalized = FALSE,
  xLab = NULL,
  yLab = NULL,
  title = NULL,
  groupBy = "id",
  showText = TRUE,
  interactive = TRUE
) {
  checkmate::assert_class(x, "ProjectMassSpec")
  x$plot_raw_spectra_ms1(
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
    minIntensity = minIntensity,
    normalized = normalized,
    xLab = xLab,
    yLab = yLab,
    title = title,
    groupBy = groupBy,
    showText = showText,
    interactive = interactive
  )
}

#' @describeIn ProjectMassSpecS3 Plot clustered MS2 spectra for specified analyses and targets.
#' @method plot_raw_spectra_ms2 ProjectMassSpec
#' @export
plot_raw_spectra_ms2.ProjectMassSpec <- function(
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
  presence = 0,
  minIntensity = 0,
  normalized = TRUE,
  xLab = NULL,
  yLab = NULL,
  title = NULL,
  groupBy = "id",
  showText = TRUE,
  interactive = TRUE
) {
  checkmate::assert_class(x, "ProjectMassSpec")
  x$plot_raw_spectra_ms2(
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
    minIntensity = minIntensity,
    normalized = normalized,
    xLab = xLab,
    yLab = yLab,
    title = title,
    groupBy = groupBy,
    showText = showText,
    interactive = interactive
  )
}

#' @describeIn ProjectMassSpecS3 Get clustered MS1 spectra for specified analyses and targets.
#' @method get_raw_spectra_ms1 ProjectMassSpec
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
  minIntensity = 1000
) {
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

#' @describeIn ProjectMassSpecS3 Get clustered MS2 spectra for specified analyses and targets.
#' @method get_raw_spectra_ms2 ProjectMassSpec
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
  presence = 0,
  minIntensity = 0
) {
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
