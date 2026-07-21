#!/usr/bin/env Rscript
devtools::load_all(".")
library(data.table)

# Mock rcpp_get_suspects_screening_csv that never crashes
mock_rcpp <- function(df) {
  cat("MOCK rcpp called with", nrow(df), "SMILES\n")
  data.frame(
    SMILES = paste("CC", df$SMILES, sep="_"),
    InChI = paste("INCHI_", df$SMILES, sep=""),
    InChIKey = paste("KEY_", df$SMILES, sep=""),
    formula = paste("FML_", df$SMILES, sep=""),
    mass = 100 + seq_len(nrow(df)),
    xLogP = 1.5 * seq_len(nrow(df)),
    stringsAsFactors = FALSE
  )
}

# Create a simple mock cfmpred result
mock_res <- list(
  `SMILES_1` = list(
    spectra = data.table(
      mz = c(100, 200), 
      intensity = c(950, 300), 
      energy = c(10L, 10L),
      fragment_ids = I(list(c(1L, 2L), c(1L)))
    ),
    fragments = data.table(
      id = c(1L, 2L), 
      mass = c(50.0, 75.0), 
      smiles = c("C", "CC"), 
      stringsAsFactors = FALSE
    ),
    parent_smiles = "CCO",
    adduct = "[M+H]+"
  )
)

cat("=== Manual flatten implementation ===\n")

# Step 1: Collect unique SMILES + per-SMILES metadata  
all_rows <- list()
for (i in seq_along(mock_res)) {
  r <- mock_res[[i]]
  
  # Get the parent info (first/smallest fragment per molecule)
  first_smi <- if (!is.null(r$fragments) && nrow(r$fragments) > 0L && !is.na(r$fragments$smiles[1])) r$fragments$smiles[1] else NA_character_
  
  # Track which fragments we've already seen
  seen <- character(0)
  
  if (!is.null(r$fragments)) {
    for (k in seq_len(nrow(r$fragments))) {
      f_smi <- r$fragments$smiles[k]
      
      if (is.na(f_smi) || !nzchar(trimws(f_smi))) next
      
      f_smi_canon <- trimws(f_smi)
      
      # Only add each unique SMILES once (first occurrence wins for metadata)
      if (!(f_smi_canon %in% seen)) {
        all_rows[[length(all_rows) + 1L]] <<- c(
          parent_smiles = r$parent_smiles,
          adduct = r$adduct,
          fragment_id = as.character(r$fragments$id[k]),
          smi = f_smi_canon
        )
        seen[length(seen) + 1L] <<- f_smi_canon
      }
    }
    
    # Also collect MS2 spectral data per parent_molecule
    if (!is.null(r$spectra) && nrow(r$spectra) > 0L) {
      for (j in seq_len(nrow(r$spectra))) {
        mz_val <- r$spectra$mz[j]
        int_val <- r$spectra$intensity[j]
        if (!is.na(mz_val) && !is.na(int_val)) {
          all_rows[[length(all_rows)]][["ms2"]] <<- paste0(
            all_rows[[length(all_rows)]][["ms2"]], 
            mz_val, " ", int_val, "; "
          )
        }
      }
    }
  }
}

cat("Step 1 done. Collected", length(all_rows), "unique fragments\n")
print(as.data.frame(do.call(rbind, all_rows)))

# Step 2: Batch get properties via rcpp_get_suspects_screening_csv  
unique_smis <- sapply(all_rows, "[[", "smi")
cat("\nStep 2: Fetching properties for unique SMILES\n")

# Replace with real call once we verify structure:
# props_df <- streamfind::rcpp_get_suspects_screening_csv(data.frame(SMILES = unique_smis))
props_df <- mock_rcpp(data.frame(SMILES = unique_smis))
cat("Step 2 done. Got", nrow(props_df), "properties\n")
print(props_df)

# Step 3: Match properties back to each SMILES row and build result
result_rows <- vector("list", length(all_rows))
for (idx in seq_along(all_rows)) {
  smi_val <- all_rows[[idx]][["smi"]]
  
  # Find matching property by exact SMILES match
  prop_idx <- which(props_df$SMILES == smi_val)
  
  formula_val <- if (length(prop_idx) > 0L && !is.na(props_df$formula[prop_idx])) props_df$formula[prop_idx] else NA_character_
  mass_val    <- if (length(prop_idx) > 0L && !is.na(props_df$mass[prop_idx])) props_df$mass[prop_idx] else NA_real_
  xlogp_val   <- if (length(prop_idx) > 0L && !is.na(props_df$xLogP[prop_idx])) props_df$xLogP[prop_idx] else NA_real_
  smiles_val  <- if (length(prop_idx) > 0L && nzchar(props_df$SMILES[prop_idx])) props_df$SMILES[prop_idx] else smi_val
  inchi_val   <- if (length(prop_idx) > 0L && !is.na(props_df$InChI[prop_idx])) props_df$InChI[prop_idx] else NA_character_
  inchikey_val <- if (length(prop_idx) > 0L && !is.na(props_df$InChIKey[prop_idx])) props_df$InChIKey[prop_idx] else NA_character_
  
  result_rows[[idx]] <<- data.frame(
    name      = paste0(substring(parent_smiles, 1, min(40, nchar(parent_smiles))), "@", substring(smi_val, max(1, nchar(smi_val)-7))),
    formula   = formula_val,
    mass      = mass_val,
    rt        = NA_character_,
    SMILES    = smiles_val,
    InChI     = inchi_val,
    InChIKey  = inchikey_val,
    xLogP     = xlogp_val,
    parent_smiles = as.character(parent_smiles),
    adduct      = as.character(adduct),
    fragment_id = as.character(fragment_id),
    ms2       = all_rows[[idx]][["ms2"]],
    stringsAsFactors = FALSE
  )
}

result_dt <- as.data.table(rbindlist(result_rows, fill = TRUE))

cat("\n=== SUCCESS! ===\n")
print(result_dt)
