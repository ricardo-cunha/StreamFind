#' Locate the Docker CLI
#'
#' Checks PATH first, then common install locations (\code{C:/Program Files/Docker/...}).
#' @return Path to \code{docker} (or \code{docker.exe}), or \code{NA}.
#' @export
get_docker_path <- function() {
  docker <- Sys.which("docker")
  if (nzchar(docker)) return(normalizePath(docker, winslash = "\\"))
  for (d in c(
    "C:/Program Files/Docker/Docker/resources/bin/docker.exe",
    "C:/Program Files/Docker/Docker/resources/bin/docker",
    "C:/ProgramData/chocolatey/bin/docker.exe"
  )) {
    if (file.exists(d)) return(normalizePath(d, winslash = "\\"))
  }
  NA_character_
}

#' Coalesce: return first non-NULL / non-missing value.
`%||%` <- function(a, b) {
  if (!is.null(a) && !is.na(a) && (is.logical(a) || length(a) == 1L || nzchar(a))) return(a)
  # fall back to b for NA/NULL / empty cases
  if (!is.null(b)) return(b)
  a
}

#' Predict CFM-ID fragmentation spectra for SMILES strings.
#'
#' Returns a named list of results --- one element per input SMILES. Each element
#' contains the parent molecule metadata and is produced by running the
#' \code{wishartlab/cfmid:latest} Dockerised `cfm-predict` binary. Each result is a
#' \code{list(spectra, fragments, parent_smiles, adduct)}.
#'
#' @param smiles character vector of SMILES strings.
#' @param adduct Adduct type (e.g. `"[M+H]+"`, `"[M-H]-"`).
#' @param prob_threshold Probability threshold (default \code{0.001}).
#' @param param_file Path to trained model (\code{param_output.log}) relative to the Docker working directory.
#' @param output_dir Directory for output files (created if needed).
#' @param verbose Run `docker run` with \code{quiet = FALSE} so you see Docker / cfm-predict logs in R.
#' @return A named list of lists. Each element has: \\describe{
#'   \item{spectra}{data.frame or data.table (mz, intensity, energy, fragment_ids)}
#'   \item{fragments}{data.frame or data.table (id, mass, smiles)}
#'   \item{parent_smiles}{character(1) the input SMILES}
#'   \item{adduct}{character(1) the adduct string used for prediction}
#' }
cfmpred <- function(smiles,
                    adduct        = "[M+H]+",
                    prob_threshold = 0.001,
                    param_file   = NULL,
                    output_dir   = file.path(getwd(), "log", "cfm-predict"),
                    verbose      = FALSE) {

  docker <- get_docker_path()
  if (is.na(docker)) stop("Docker CLI not found. Start Docker Desktop first.", call. = FALSE)

  daemon_ok <- suppressWarnings(system(paste(shQuote(docker), "info"), ignore.stdout = TRUE, ignore.stderr = TRUE))
  if (daemon_ok != 0L) stop("Docker daemon not reachable.", call. = FALSE)

  output_dir <- file.path(getwd(), "log", "cfm-predict")
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  out_dir <- normalizePath(output_dir, winslash = "/")

  # names(smiles) <- if (!is.null(names(smiles)) && nzchar(names(smiles))) names(smiles) else seq_along(smiles)
  if (isFALSE(is.null(names(smiles)))) {
    nm <- trimws(names(smiles))
    any_nm <- any(nzchar(nm))
    if (any_nm) {
      # If all are empty, use seq_along instead
      valid_idx <- which(nzchar(nm))
      smiles[names(smiles)] <- ifelse(nzchar(nm), names(smiles), seq_along(smiles))
      # Set any still-empty names to their index
      empty_idx <- which(!nzchar(smiles))
      smiles[empty_idx] <- as.character(seq_len(length(smiles))[empty_idx])
    } else {
      names(smiles) <- as.character(seq_along(smiles))
    }
  } else {
    names(smiles) <- as.character(seq_along(smiles))
  }
  result <- lapply(seq_along(smiles), function(idx) {
    smiles_i <- smiles[idx]
    idx_dir <- file.path(out_dir, paste0("smiles_", idx))
    dir.create(idx_dir, recursive = TRUE, showWarnings = FALSE)
    idx_out_file <- file.path(idx_dir, "spectra.txt")

    pfile <- param_file %||% file.path("/trained_models_cfmid4.0", adduct, "param_output.log")
    cfile <- file.path("/trained_models_cfmid4.0", adduct, "param_config.txt")

    tryCatch({
      suppressWarnings(system2("docker", c("pull", "wishartlab/cfmid:latest"), stdout = FALSE, stderr = FALSE))
    }, error = function(e) invisible(NULL))

    cmd <- sprintf(
      "docker run --rm -v \"%s:/cfmid/public\" --workdir /cfmid/public wishartlab/cfmid:latest cfm-predict %s %s %s %s 1 spectra.txt 1",
      idx_dir,
      shQuote(smiles_i),
      prob_threshold,
      shQuote(pfile),
      shQuote(cfile)
    )

    status <- system(cmd, ignore.stdout = verbose, ignore.stderr = verbose)
    if (status != 0L || !file.exists(idx_out_file)) {
      return(invisible(list(spectra = data.frame(), fragments = data.frame(), parent_smiles = smiles_i, adduct = adduct)))
    }

    raw_lines <- readLines(idx_out_file, warn = FALSE)
    if (length(raw_lines) == 0L) return(invisible(list(spectra = data.frame(), fragments = data.frame(), parent_smiles = smiles_i, adduct = adduct)))

    spectrum_rows   <- list()
    fragment_rows   <- list()
    cur_energy      <- NA_integer_
    past_blank      <- FALSE

    for (ln in raw_lines) {
      if (grepl("^energy(\\d+)$", ln, perl = TRUE)) {
        cur_energy <- as.integer(sub("^energy(\\d+)$", "\\1", ln, perl = TRUE))
        next
      }
      if (grepl("^\\s*$", ln)) {
        past_blank <- TRUE
        next
      }
      parts <- strsplit(trimws(ln), "\\s+")[[1]]
      if (length(parts) < 2L) next
      mz   <- as.numeric(parts[1L])
      intensity <- as.numeric(parts[2L])
      if (is.na(mz) || is.na(intensity)) next

      if (past_blank || grepl("^fragment", parts[1L], ignore.case = TRUE)) {
        if (length(parts) >= 3L && !is.na(as.integer(parts[1L]))) {
          fragment_rows[[length(fragment_rows) + 1L]] <- data.frame(
            id   = as.integer(parts[1L]),
            mass = as.numeric(parts[2L]),
            smiles = paste(parts[-(1:2)], collapse = " "),
            stringsAsFactors = FALSE
          )
        }
      } else {
        frag_ids <- integer(0)
        if (length(parts) >= 3L) {
          for (tok in parts[-(1:2)]) {
            cleaned <- sub("^\\s*(\\d+)\\s*.*$", "\\1", tok, perl = TRUE)
            if (grepl("^\\d+$", cleaned)) frag_ids <- c(frag_ids, as.integer(cleaned)) else break
          }
        }
        spectrum_rows[[length(spectrum_rows) + 1L]] <- data.frame(
          mz   = mz,
          intensity  = intensity,
          energy   = cur_energy,
          fragment_ids = I(list(frag_ids)),
          stringsAsFactors = FALSE
        )
      }
    }

    spectra <- if (length(spectrum_rows)) do.call(rbind, spectrum_rows) else data.frame()
    fragments <- if (length(fragment_rows)) do.call(rbind, fragment_rows) else data.frame()

    invisible(list(
      spectra       = as.data.table(spectra),
      fragments     = as.data.table(fragments),
      adduct        = adduct,
      parent_smiles = smiles_i
    ))
  })

  names(result) <- smiles
  invisible(result)
}

#' Flatten cfmpred results into unique fragment rows matching the suspect_screening CSV template.
#'
#' Takes the list output of [cfmpred()] and extracts every unique fragment SMILES across all
#' molecules, enriches each with parent molecule metadata and OpenBabel-derived properties,
#' and returns a data.table matching the columns: `name`, `formula`, `mass`, `rt`,
#' `SMILES`, `InChI`, `InChIKey`, `xLogP`, `ms2_positive`, `ms2_negative`.
#'
#' @param res list of cfmpred results --- one element per input SMILES. Each element
#'   is a list(spectra, fragments, parent_smiles, adduct).
#' @return data.table with columns matching the suspect_screening CSV template:
#'   \describe{
#'   \item{name}{fragment identifier (parent\@SMILES_hash)}
#'   \item{formula}{molecular formula of the fragment}
#'   \item{mass}{fragment monoisotopic mass}
#'   \item{rt}{retention time (NA --- derived from CFM-ID)}
#'   \item{SMILES}{canonical fragment SMILES}
#'   \item{InChI}{fragment InChI}
#'   \item{InChIKey}{fragment InChIKey}
#'   \item{xLogP}{fragment xLogP}
#'   \item{ms2_positive}{MS2 spectrum as semicolon-separated "mz intensity" pairs for [M+H]+}
#'   \item{ms2_negative}{MS2 spectrum as semicolon-separated "mz intensity" pairs for [M-H]-}
#'   \item{parent_smiles}{the original parent molecule SMILES}
#'   \item{adduct}{the adduct used for prediction}
#' }
flatten_cfmpred <- function(res) {

  if (is.null(res) || length(res) == 0L || !is.list(res)) return(data.table())

  # Collect all unique fragment SMILES & their parent metadata
  all_fragments <- list()   # named by canonical SMILES
  smi_to_parent <- character()   # maps SMILES -> parent info

  for (i in seq_along(res)) {
    r <- res[[i]]
    if (is.null(r) || is.null(r$fragments) || nrow(r$fragments) == 0L) next

    ps <- if (!is.null(r$parent_smiles) && !is.na(r$parent_smiles)) as.character(r$parent_smiles) else NA_character_
    adduct_val <- if (!is.null(r$adduct)) as.character(r$adduct) else NA_character_

    for (k in seq_len(nrow(r$fragments))) {
      f_smi <- r$fragments$smiles[k]

      # Compute canonical SMILES via OpenBabel
      if (!is.na(f_smi) && nzchar(trimws(f_smi))) {
        f_smi_canon <- trimws(f_smi)
      } else {
        next  # skip invalid/empty SMILES
      }

       if (!(f_smi_canon %in% names(all_fragments))) {
         all_fragments[[f_smi_canon]] <- list(
           parent_smiles = ps,
           adduct = adduct_val,
           fragment_id = r$fragments$id[k],
           mass = r$fragments$mass[k],
           energy_levels = integer(0),
           mz_intensity_pairs = list()  # list of character vectors "mz;int" per adduct type
         )
       } else {
        # Update parent info if missing and now available
        cur <- all_fragments[[f_smi_canon]]
        if (is.na(cur$parent_smiles) && !is.na(ps)) {
          cur$parent_smiles <- ps
          cur$adduct <- adduct_val
        }
      }
    }
  }

  n_f <- length(all_fragments)
  if (n_f == 0L) return(data.table())

   unique_smis <- names(all_fragments)

   # Filter to only valid SMILES - reject any containing bare T or other invalid characters
   is_valid_smiles <- vapply(unique_smis, function(s) {
     if (!nzchar(s)) return(FALSE)
     s <- trimws(as.character(s))
     # Reject if contains bare uppercase T alone (not in square brackets like [T])
     has_bare_t <- grepl('(?<![\\[])T', s, perl = TRUE) 
     has_other_bad <- nchar(s) > 256L | !grepl('^[B-CO-PN0-9]|[BCNOPFSIclbrnihose]', s, perl = TRUE)
     if (has_bare_t || has_other_bad) return(FALSE)
     TRUE
   }, logical(1L))

   if (!any(is_valid_smiles)) return(data.table())

   unique_smis <- names(all_fragments)[is_valid_smiles]
   

  # Batch compute properties for all unique fragment SMILES via OpenBabel backend
  props_df <- tryCatch({
    streamfind::rcpp_get_suspects_screening_csv(
      data.frame(SMILES = unique_smis, name = seq_len(n_f), stringsAsFactors = FALSE)
    )
  }, error = function(e) data.frame())

  # Also batch-fetch properties for all unique parent SMILES
  all_parent_smis <- unique(unlist(lapply(all_fragments, function(f) { if (!is.na(f$parent_smiles) && nzchar(trimws(as.character(f$parent_smiles)))) f$parent_smiles else character(0) })))
  
  parent_mass_map <- setNames(nm = all_parent_smis)
  if (length(all_parent_smis) > 0L && nzchar(all_parent_smis)[1]) {
    parent_props <- tryCatch({
      streamfind::rcpp_get_suspects_screening_csv(
        data.frame(SMILES = all_parent_smis, name = paste0("parent_", seq_along(all_parent_smis)), stringsAsFactors = FALSE)
      )
    }, error = function(e) data.frame())
    
    for (i in seq_len(nrow(parent_props))) {
      if (!is.na(parent_props$SMILES[i]) && nzchar(parent_props$SMILES[i]) && !is.na(parent_props$mass[i])) {
        parent_mass_map[as.character(parent_props$SMILES[i])] <- as.double(parent_props$mass[i])
      }
    }
  }

  # Helper to safely extract from props_df by index
  safe_formula <- function(idx) {
    if (is.null(props_df) || is.na(idx) || idx < 1L || idx > nrow(props_df)) return(NA_character_)
    val <- props_df$formula[idx]
    if (is.character(val) && nzchar(val)) val else NA_character_
  }

  safe_mass <- function(idx) {
    if (is.null(props_df) || is.na(idx) || idx < 1L || idx > nrow(props_df)) return(NA_real_)
    val <- props_df$mass[idx]
    if (!is.na(val)) as.numeric(val) else NA_real_
  }

  safe_xlogp <- function(idx) {
    if (is.null(props_df) || is.na(idx) || idx < 1L || idx > nrow(props_df)) return(NA_real_)
    val <- props_df$xLogP[idx]
    if (!is.na(val)) as.numeric(val) else NA_real_
  }

  safe_smiles <- function(idx, default) {
    if (is.null(props_df) || is.na(idx) || idx < 1L || idx > nrow(props_df)) return(default)
    val <- props_df$SMILES[idx]
    if (is.character(val) && nzchar(val)) val else default
  }

  safe_inchi <- function(idx, default = NA_character_) {
    if (is.null(props_df) || is.na(idx) || idx < 1L || idx > nrow(props_df)) return(default)
    val <- props_df$InChI[idx]
    if (is.character(val) && nzchar(val)) val else default
  }

  safe_inchikey <- function(idx, default = NA_character_) {
    if (is.null(props_df) || is.na(idx) || idx < 1L || idx > nrow(props_df)) return(default)
    val <- props_df$InChIKey[idx]
    if (is.character(val) && nzchar(val)) val else default
  }
  mhp_key <- "M+H]+"
  mhn_key <- "M-H]-"

  # Build result rows matching suspect_screening_csv template + CFM-ID metadata
  result_rows <- vector("list", n_f)
  for (idx in seq_len(n_f)) {
    smi <- unique_smis[idx]
    frag <- all_fragments[[smi]]

    frag_id   <- if (!is.na(frag$fragment_id)) as.integer(frag$fragment_id) else NA_integer_
    frag_mass <- if (!is.null(frag$mass) && is.finite(frag$mass)) round(frag$mass) else NA_real_
    
    parent_smiles_val <- frag$parent_smiles
    
    parent_mass <- if (!is.na(parent_smiles_val) && nzchar(parent_smiles_val)) {
      pm <- parent_mass_map[as.character(parent_smiles_val)]
      if (!is.na(pm)) as.double(pm) else NA_real_
    } else NA_real_
    
    result_rows[[idx]] <- data.frame(
      name = paste0(frag_id, "_", frag_mass, "_", frag$adduct, "_", round(parent_mass)),
      formula = safe_formula(idx),
      mass = safe_mass(idx),
      rt = NA_character_,
      SMILES = safe_smiles(idx, smi),
      InChI = safe_inchi(idx),
      InChIKey = safe_inchikey(idx),
      xLogP = safe_xlogp(idx),
      ms2_positive = paste(frag$mz_intensity_pairs[[mhp_key]], collapse = "; "),
      ms2_negative = paste(frag$mz_intensity_pairs[[mhn_key]], collapse = "; "),
      parent_smiles = frag$parent_smiles,
      adduct = frag$adduct,
      stringsAsFactors = FALSE
    )
  }

  as.data.table(rbindlist(result_rows, fill = TRUE))
}
