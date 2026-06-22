#' Predict CFM-ID fragmentation spectra for a SMILES
#'
#' Runs \code{cfm-predict} inside the Docker-based CFM-ID installation
#' (\code{\link{install_cfmid_docker}}) and returns both the predicted
#' spectra and the fragment structures (as SMILES).
#'
#' @param smiles A SMILES string for the molecule of interest.
#' @param adduct Adduct type.  Default \code{"[M+H]+"}.  Other common values:
#'   \code{"[M-H]-"}, \code{"[M+Na]+"}, \code{"[M+HCOO]-"}.
#' @param prob_threshold Probability threshold (default \code{0.001}).
#' @param param_file Path inside the Docker container to the trained model.
#'   Default looks in \code{/trained_models_cfmid4.0/<adduct>/param_output.log}.
#' @param output_dir Directory for output files.  Default is
#'   \code{log/cfm-predict/} in the working directory.
#' @param quiet Suppress sub-process output.
#'
#' @return A list with two elements:
#'   \describe{
#'     \item{\code{spectra}}{data.frame with columns \code{mz}, \code{intensity},
#'       \code{energy}, and \code{fragment_id}s.}
#'     \item{\code{fragments}}{data.frame with columns \code{id}, \code{mass},
#'       \code{smiles}.  Map \code{spectra$fragment_id} to
#'       \code{fragments$id} to look up the SMILES of each fragment.}
#'   }
#'   Returns \code{NULL} (invisibly) on failure.
#'
#' @examples
#' \dontrun{
#' res <- cfm_predict("CC(=O)OC1=CC=CC=C1C(=O)O")
#' head(res$spectra)
#' head(res$fragments)
#' }
#' @export
cfm_predict <- function(smiles,
                        adduct = "[M+H]+",
                        prob_threshold = 0.001,
                        param_file = NULL,
                        output_dir = file.path(getwd(), "log", "cfm-predict"),
                        quiet = TRUE) {

  tool <- get_cfm_id_tool("predict")
  if (is.na(tool)) {
    stop("CFM-ID (Docker) is not installed. Run install_external_tools('cfm_id_docker').",
         call. = FALSE)
  }

  docker <- get_docker_path()
  if (is.na(docker)) {
    stop("Docker CLI not found.", call. = FALSE)
  }
  daemon_ok <- suppressWarnings(system(paste(shQuote(docker), "info"),
                                       ignore.stdout = TRUE, ignore.stderr = TRUE))
  if (daemon_ok != 0L) {
    stop("Docker daemon is not running. Start Docker Desktop and try again.",
         call. = FALSE)
  }

  if (is.null(param_file)) {
    param_file <- file.path("/trained_models_cfmid4.0", adduct, "param_output.log")
  }
  config_file <- file.path("/trained_models_cfmid4.0", adduct, "param_config.txt")

  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
  out_file <- file.path(normalizePath(output_dir, winslash = "/"), "spectra.txt")

  docker_bin <- dirname(docker)
  old_path <- Sys.getenv("PATH")
  if (!grepl(docker_bin, old_path, fixed = TRUE)) {
    Sys.setenv(PATH = paste(docker_bin, old_path, sep = ";"))
  }

  # include_annotations = 1 so CFM-ID appends fragment id -> SMILES map
  cmd <- sprintf(
    "docker run --rm -v \"%s:/cfmid/public\" --workdir /cfmid/public wishartlab/cfmid:latest cfm-predict %s %s %s %s 1 spectra.txt 1",
    normalizePath(output_dir, winslash = "/"),
    shQuote(smiles),
    prob_threshold,
    shQuote(param_file),
    shQuote(config_file)
  )

  status <- system(cmd, ignore.stdout = quiet, ignore.stderr = quiet)
  if (status != 0L) {
    message("CFM-ID prediction failed (exit code ", status, ").")
    return(invisible(NULL))
  }
  if (!file.exists(out_file)) {
    message("CFM-ID ran but produced no output file.")
    return(invisible(NULL))
  }

  raw <- readLines(out_file, warn = FALSE)
  if (length(raw) == 0L) {
    message("Output file is empty.")
    return(invisible(NULL))
  }

  # ── Parse spectra ───────────────────────────────────────────────────────
  # energy0
  # mz intensity id1 id2 ... (probs ...)
  #
  # ── Parse fragments ─────────────────────────────────────────────────────
  #   id mass SMILES

  in_fragments <- FALSE
  spectra_list <- list()
  fragments_list <- list()
  current_energy <- NA_integer_

  for (line in raw) {
    if (grepl("^#", line)) next
    if (grepl("^energy(\\d+)$", line, perl = TRUE)) {
      current_energy <- as.integer(sub("^energy(\\d+)$", "\\1", line, perl = TRUE))
      in_fragments <- FALSE
      next
    }
    # Blank line separates spectra from fragment annotations
    if (nzchar(line) && grepl("^\\s*$", line)) {
      in_fragments <- TRUE
      next
    }
    # Detect fragment annotation line: starts with a digit (id)
    if (in_fragments || grepl("^\\d+\\s+", line)) {
      parts <- strsplit(trimws(line), "\\s+")[[1]]
      if (length(parts) >= 3L) {
        fid <- as.integer(parts[1L])
        fmass <- as.numeric(parts[2L])
        fsmiles <- parts[3L]
        if (!is.na(fid) && !is.na(fmass)) {
          fragments_list[[length(fragments_list) + 1L]] <- data.frame(
            id = fid, mass = fmass, smiles = fsmiles,
            stringsAsFactors = FALSE
          )
        }
      }
      next
    }
    # Otherwise it is a spectra data line
    parts <- strsplit(trimws(line), "\\s+")[[1]]
    if (length(parts) >= 2L) {
      mz <- as.numeric(parts[1L])
      intensity <- as.numeric(parts[2L])
      if (!is.na(mz) && !is.na(intensity)) {
        # Remaining tokens before '(' are fragment IDs
        frag_ids <- integer(0)
        if (length(parts) >= 3L) {
          for (tok in parts[3L:length(parts)]) {
            if (grepl("^\\d+$", tok)) {
              frag_ids <- c(frag_ids, as.integer(tok))
            } else break
          }
        }
        spectra_list[[length(spectra_list) + 1L]] <- data.frame(
          mz = mz,
          intensity = intensity,
          energy = current_energy,
          fragment_ids = I(list(frag_ids)),
          stringsAsFactors = FALSE
        )
      }
    }
  }

  if (length(spectra_list) == 0L) {
    message("No spectral data found in output.")
    return(invisible(NULL))
  }

  spectra <- do.call(rbind, spectra_list)
  rownames(spectra) <- NULL

  fragments <- if (length(fragments_list) > 0L) {
    tbl <- do.call(rbind, fragments_list)
    rownames(tbl) <- NULL
    tbl
  } else NULL

  invisible(list(spectra = spectra, fragments = fragments))
}