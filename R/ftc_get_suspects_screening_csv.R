#' @title Create a suspect screening CSV from SMILES
#' @description Normalizes SMILES to canonical form and derives required columns
#' for suspect screening. Writes a CSV with the same columns as
#' \code{get_template_suspect_screening_csv()}.
#' @param suspects data.table or data.frame with required column: \code{name}.
#' One of \code{SMILES}, \code{InChI}, or \code{mol} is required. \code{mol} is a
#' file path to a \code{.mol} file per row. When provided, the \code{.mol} file is
#' used to derive canonical SMILES and properties. \code{rt} can be provided to
#' populate the \code{rt} column in the output.
#' @param file Character (length 1). Output CSV file path.
#' @return Invisibly returns the file path.
#' @export
get_suspects_screening_csv <- function(suspects, file) {
  if (!requireNamespace("checkmate", quietly = TRUE)) {
    stop("checkmate is required for input validation.")
  }
  checkmate::assert_data_frame(suspects)
  checkmate::assert_character(file, len = 1)

  suspects <- data.table::as.data.table(suspects)
  checkmate::assert_names(names(suspects), must.include = c("name"))
  has_smiles <- "SMILES" %in% names(suspects)
  has_inchi <- "InChI" %in% names(suspects)
  has_mol <- "mol" %in% names(suspects)
  if (!has_smiles && !has_inchi && !has_mol) {
    stop("suspects must include either 'SMILES', 'InChI', or 'mol' column.")
  }

  if (!requireNamespace("rcdk", quietly = TRUE)) {
    stop("rcdk is required to normalize SMILES and compute properties.")
  }

  has_rjava <- requireNamespace("rJava", quietly = TRUE)

  has_isotope_smiles <- function(smiles) {
    is.character(smiles) &&
      length(smiles) > 0 &&
      !is.na(smiles[1]) &&
      grepl("\\[[0-9]+[A-Z][a-z]?", smiles[1], perl = TRUE)
  }

  format_formula_count <- function(n) {
    if (isTRUE(n == 1L)) "" else as.character(n)
  }

  increment_named_count <- function(x, key, value = 1L) {
    current <- if (key %in% names(x)) unname(x[[key]]) else 0L
    x[key] <- as.integer(current) + as.integer(value)
    x
  }

  hill_order_symbols <- function(symbols) {
    base <- unique(as.character(symbols))
    base <- base[!is.na(base) & nzchar(base)]
    ordered <- character()
    if ("C" %in% base) ordered <- c(ordered, "C")
    if ("H" %in% base) ordered <- c(ordered, "H")
    others <- sort(setdiff(base, c("C", "H")))
    c(ordered, others)
  }

  calc_isotope_formula_from_mol <- function(mol, charge = 0L) {
    atom_count <- tryCatch(as.integer(mol$getAtomCount()), error = function(e) NA_integer_)
    if (is.na(atom_count) || atom_count <= 0) return(NA_character_)

    base_counts <- integer()
    isotope_counts <- integer()

    for (idx in seq_len(atom_count) - 1L) {
      atom <- tryCatch(mol$getAtom(as.integer(idx)), error = function(e) NULL)
      if (is.null(atom)) next

      symbol <- tryCatch(as.character(atom$getSymbol()), error = function(e) NA_character_)
      if (is.na(symbol) || !nzchar(symbol)) next

      mass_number <- tryCatch(atom$getMassNumber(), error = function(e) NULL)
      if (is.null(mass_number)) {
        base_counts <- increment_named_count(base_counts, symbol, 1L)
      } else {
        iso_key <- paste0("[", as.integer(mass_number), symbol, "]")
        isotope_counts <- increment_named_count(isotope_counts, iso_key, 1L)
      }

      implicit_h <- tryCatch(atom$getImplicitHydrogenCount(), error = function(e) NULL)
      if (!is.null(implicit_h) && !is.na(implicit_h)) {
        base_counts <- increment_named_count(base_counts, "H", as.integer(implicit_h))
      }
    }

    if (length(base_counts) == 0L && length(isotope_counts) == 0L) return(NA_character_)

    pieces <- character()
    ordered_symbols <- hill_order_symbols(names(base_counts))
    for (symbol in ordered_symbols) {
      n_base <- unname(base_counts[[symbol]])
      if (!is.na(n_base) && n_base > 0L) {
        pieces <- c(pieces, paste0(symbol, format_formula_count(n_base)))
      }

      symbol_pattern <- paste0("^\\[[0-9]+", gsub("([][{}()+*^$.|\\\\?])", "\\\\\\1", symbol), "\\]$")
      iso_names <- names(isotope_counts)[grepl(symbol_pattern, names(isotope_counts), perl = TRUE)]
      if (length(iso_names) > 0L) {
        iso_names <- iso_names[order(as.integer(sub("^\\[([0-9]+).*$", "\\1", iso_names)))]
        pieces <- c(
          pieces,
          vapply(iso_names, function(iso_name) {
            paste0(iso_name, format_formula_count(unname(isotope_counts[[iso_name]])))
          }, character(1))
        )
      }
    }

    orphan_isotopes <- setdiff(names(isotope_counts), unlist(lapply(ordered_symbols, function(symbol) {
      names(isotope_counts)[grepl(
        paste0("^\\[[0-9]+", gsub("([][{}()+*^$.|\\\\?])", "\\\\\\1", symbol), "\\]$"),
        names(isotope_counts),
        perl = TRUE
      )]
    })))
    if (length(orphan_isotopes) > 0L) {
      orphan_isotopes <- orphan_isotopes[order(orphan_isotopes)]
      pieces <- c(
        pieces,
        vapply(orphan_isotopes, function(iso_name) {
          paste0(iso_name, format_formula_count(unname(isotope_counts[[iso_name]])))
        }, character(1))
      )
    }

    if (!is.null(charge) && !is.na(charge) && charge != 0L) {
      sign <- if (charge > 0L) "+" else "-"
      magnitude <- abs(as.integer(charge))
      pieces <- c(pieces, paste0(if (magnitude == 1L) "" else magnitude, sign))
    }

    paste0(pieces, collapse = "")
  }

  calc_props_from_smiles <- function(smiles) {
    if (is.null(smiles) || length(smiles) == 0) {
      return(list(
        smiles = NA_character_,
        formula = NA_character_,
        mass = NA_real_,
        inchi = NA_character_,
        inchikey = NA_character_,
        logp = NA_real_
      ))
    }
    smiles <- as.character(smiles[1])
    smiles <- trimws(smiles)
    if (is.na(smiles) || !nzchar(smiles)) {
      return(list(
        smiles = NA_character_,
        formula = NA_character_,
        mass = NA_real_,
        inchi = NA_character_,
        inchikey = NA_character_,
        logp = NA_real_
      ))
    }

    mol <- tryCatch(rcdk::parse.smiles(smiles)[[1]], error = function(e) NULL)
    if (is.null(mol)) {
      return(list(
        smiles = smiles,
        formula = NA_character_,
        mass = NA_real_,
        inchi = NA_character_,
        inchikey = NA_character_,
        logp = NA_real_
      ))
    }

    canonical_smiles <- tryCatch(
      rcdk::get.smiles(mol, smilesFlavor = "Canonical"),
      error = function(e) tryCatch(rcdk::get.smiles(mol), error = function(e2) smiles)
    )
    smiles_out <- if (has_isotope_smiles(smiles) && !has_isotope_smiles(canonical_smiles)) smiles else canonical_smiles
    mass <- tryCatch(as.numeric(rcdk::get.exact.mass(mol)), error = function(e) NA_real_)
    logp <- tryCatch(as.numeric(rcdk::get.xlogp(mol)), error = function(e) NA_real_)
    formula <- tryCatch(calc_isotope_formula_from_mol(mol, charge = 0L), error = function(e) NA_character_)
    if (is.na(formula) || !nzchar(formula)) {
      formula <- tryCatch(rcdk::get.mol2formula(mol, charge = 0)@string, error = function(e) NA_character_)
    }

    inchi <- NA_character_
    inchikey <- NA_character_
    if (has_rjava) {
      inchi <- tryCatch(rJava::.jcall("org/guha/rcdk/util/Misc", "S", "getInChi", mol, check = FALSE), error = function(e) NA_character_)
      inchikey <- tryCatch(rJava::.jcall("org/guha/rcdk/util/Misc", "S", "getInChiKey", mol, check = FALSE), error = function(e) NA_character_)
    }

    conv_fn <- tryCatch(getFromNamespace("convert.implicit.to.explicit", "rcdk"), error = function(e) NULL)
    if (is.function(conv_fn)) {
      tryCatch(conv_fn(mol), error = function(e) NULL)
    }

    list(
      smiles = smiles_out,
      formula = formula,
      mass = mass,
      inchi = inchi,
      inchikey = inchikey,
      logp = logp
    )
  }

  calc_props_from_inchi <- function(inchi) {
    if (is.null(inchi) || length(inchi) == 0) {
      return(list(
        smiles = NA_character_,
        formula = NA_character_,
        mass = NA_real_,
        inchi = NA_character_,
        inchikey = NA_character_,
        logp = NA_real_
      ))
    }
    inchi <- as.character(inchi[1])
    inchi <- trimws(inchi)
    if (is.na(inchi) || !nzchar(inchi)) {
      return(list(
        smiles = NA_character_,
        formula = NA_character_,
        mass = NA_real_,
        inchi = NA_character_,
        inchikey = NA_character_,
        logp = NA_real_
      ))
    }
    if (!has_rjava) {
      return(list(
        smiles = NA_character_,
        formula = NA_character_,
        mass = NA_real_,
        inchi = inchi,
        inchikey = NA_character_,
        logp = NA_real_
      ))
    }

    mol <- tryCatch({
      fac <- rJava::.jcall(
        "org/openscience/cdk/inchi/InChIGeneratorFactory",
        "Lorg/openscience/cdk/inchi/InChIGeneratorFactory;",
        "getInstance"
      )
      builder <- rJava::.jcall(
        "org/openscience/cdk/silent/SilentChemObjectBuilder",
        "Lorg/openscience/cdk/interfaces/IChemObjectBuilder;",
        "getInstance"
      )
      inchi_struct <- rJava::.jcall(
        fac,
        "Lorg/openscience/cdk/inchi/InChIToStructure;",
        "getInChIToStructure",
        inchi,
        builder
      )
      rJava::.jcall(
        inchi_struct,
        "Lorg/openscience/cdk/interfaces/IAtomContainer;",
        "getAtomContainer"
      )
    }, error = function(e) NULL)

    if (is.null(mol)) {
      return(list(
        smiles = NA_character_,
        formula = NA_character_,
        mass = NA_real_,
        inchi = inchi,
        inchikey = NA_character_,
        logp = NA_real_
      ))
    }

    smiles_out <- tryCatch(rcdk::get.smiles(mol), error = function(e) NA_character_)
    mass <- tryCatch(as.numeric(rcdk::get.exact.mass(mol)), error = function(e) NA_real_)
    logp <- tryCatch(as.numeric(rcdk::get.xlogp(mol)), error = function(e) NA_real_)
    formula <- tryCatch(calc_isotope_formula_from_mol(mol, charge = 0L), error = function(e) NA_character_)
    if (is.na(formula) || !nzchar(formula)) {
      formula <- tryCatch(rcdk::get.mol2formula(mol, charge = 0)@string, error = function(e) NA_character_)
    }

    inchikey <- tryCatch(
      rJava::.jcall("org/guha/rcdk/util/Misc", "S", "getInChiKey", mol, check = FALSE),
      error = function(e) NA_character_
    )

    list(
      smiles = smiles_out,
      formula = formula,
      mass = mass,
      inchi = inchi,
      inchikey = inchikey,
      logp = logp
    )
  }

  calc_props_from_mol <- function(mol_path) {
    if (is.null(mol_path) || length(mol_path) == 0) {
      return(list(
        smiles = NA_character_,
        formula = NA_character_,
        mass = NA_real_,
        inchi = NA_character_,
        inchikey = NA_character_,
        logp = NA_real_
      ))
    }
    mol_path <- as.character(mol_path[1])
    mol_path <- trimws(mol_path)
    if (is.na(mol_path) || !nzchar(mol_path) || !file.exists(mol_path)) {
      return(list(
        smiles = NA_character_,
        formula = NA_character_,
        mass = NA_real_,
        inchi = NA_character_,
        inchikey = NA_character_,
        logp = NA_real_
      ))
    }

    mol <- tryCatch(rcdk::load.molecules(mol_path), error = function(e) NULL)
    if (is.null(mol) || length(mol) == 0 || is.null(mol[[1]])) {
      return(list(
        smiles = NA_character_,
        formula = NA_character_,
        mass = NA_real_,
        inchi = NA_character_,
        inchikey = NA_character_,
        logp = NA_real_
      ))
    }
    mol <- mol[[1]]

    canonical_smiles <- tryCatch(
      rcdk::get.smiles(mol, smilesFlavor = "Canonical"),
      error = function(e) tryCatch(rcdk::get.smiles(mol), error = function(e2) NA_character_)
    )
    mass <- tryCatch(as.numeric(rcdk::get.exact.mass(mol)), error = function(e) NA_real_)
    logp <- tryCatch(as.numeric(rcdk::get.xlogp(mol)), error = function(e) NA_real_)
    formula <- tryCatch(calc_isotope_formula_from_mol(mol, charge = 0L), error = function(e) NA_character_)
    if (is.na(formula) || !nzchar(formula)) {
      formula <- tryCatch(rcdk::get.mol2formula(mol, charge = 0)@string, error = function(e) NA_character_)
    }

    inchi <- NA_character_
    inchikey <- NA_character_
    if (has_rjava) {
      inchi <- tryCatch(rJava::.jcall("org/guha/rcdk/util/Misc", "S", "getInChi", mol, check = FALSE), error = function(e) NA_character_)
      inchikey <- tryCatch(rJava::.jcall("org/guha/rcdk/util/Misc", "S", "getInChiKey", mol, check = FALSE), error = function(e) NA_character_)
    }

    conv_fn <- tryCatch(getFromNamespace("convert.implicit.to.explicit", "rcdk"), error = function(e) NULL)
    if (is.function(conv_fn)) {
      tryCatch(conv_fn(mol), error = function(e) NULL)
    }

    list(
      smiles = canonical_smiles,
      formula = formula,
      mass = mass,
      inchi = inchi,
      inchikey = inchikey,
      logp = logp
    )
  }

  props <- lapply(seq_len(nrow(suspects)), function(i) {
    mol_path <- if (has_mol) suspects$mol[i] else NA_character_
    mol_props <- calc_props_from_mol(mol_path)
    if (!is.na(mol_props$smiles) && nzchar(mol_props$smiles)) {
      return(mol_props)
    }
    if (has_smiles) {
      return(calc_props_from_smiles(suspects$SMILES[i]))
    }
    if (has_inchi) {
      return(calc_props_from_inchi(suspects$InChI[i]))
    }
    list(
      smiles = NA_character_,
      formula = NA_character_,
      mass = NA_real_,
      inchi = NA_character_,
      inchikey = NA_character_,
      logp = NA_real_
    )
  })
  props <- data.table::rbindlist(lapply(props, as.data.table), fill = TRUE)

  rt_val <- if ("rt" %in% names(suspects)) as.numeric(suspects$rt) else rep(NA_real_, nrow(suspects))

  out <- data.table::data.table(
    name = as.character(suspects$name),
    formula = props$formula,
    mass = props$mass,
    rt = rt_val,
    SMILES = props$smiles,
    InChI = props$inchi,
    InChIKey = props$inchikey,
    xLogP = props$logp,
    ms2_positive = "",
    ms2_negative = ""
  )

  cols <- c(
    "name", "formula", "mass", "rt", "SMILES", "InChI", "InChIKey", "xLogP",
    "ms2_positive", "ms2_negative"
  )
  out <- out[, ..cols]

  data.table::fwrite(out, file)
  invisible(file)
}

