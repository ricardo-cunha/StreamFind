# MARK: General utility functions
# General utility functions -----

# MARK: .resolve_analyses_selection
#' @title .resolve_analyses_selection
#' @description Utility to resolve analyses selection by name or index, returning only valid matches.
#' If analyses is NULL, returns all_analyses. If numeric, returns valid indices only. If character, returns valid names only.
#' Returns character() if no valid matches.
#' @param analyses Analyses selection (NULL, integer, or character).
#' @param all_analyses Character vector of all available analyses.
#' @return Character vector of valid selected analyses (may be character(0)).
#' @noRd
.resolve_analyses_selection <- function(analyses, all_analyses) {
  if (is.null(analyses)) {
    return(all_analyses)
  }
  if (is.numeric(analyses)) {
    all_analyses <- sort(all_analyses)
    valid_idx <- analyses[analyses >= 1 & analyses <= length(all_analyses)]
    if (length(valid_idx) == 0) return(character())
    return(all_analyses[valid_idx])
  }
  if (is.character(analyses)) {
    valid_names <- intersect(analyses, all_analyses)
    return(valid_names)
  }
  character()
}

#' @noRd
.pull_internal_init_arg <- function(dots, name) {
  if (!name %in% names(dots)) {
    return(list(value = NULL, dots = dots))
  }
  value <- dots[[name]]
  dots[[name]] <- NULL
  list(value = value, dots = dots)
}

#' @noRd
.assert_only_internal_init_args <- function(dots, context = "initialize") {
  if (length(dots) == 0) {
    return(invisible(NULL))
  }
  dot_names <- names(dots)
  if (is.null(dot_names)) {
    dot_names <- rep("", length(dots))
  }
  unexpected <- ifelse(nzchar(dot_names), dot_names, "<unnamed>")
  stop(
    sprintf(
      "Unused arguments in %s: %s",
      context,
      paste(unexpected, collapse = ", ")
    ),
    call. = FALSE
  )
}

# MARK: .infer_processing_owner_class
#' @noRd
.infer_processing_owner_class <- function(type = NA_character_, input_class = NA_character_, output_class = NA_character_) {
  classes <- unique(stats::na.omit(c(input_class, output_class)))
  if (length(classes) > 0) {
    if (any(grepl("NonTargetAnalysis", classes, fixed = TRUE))) {
      return("ProjectNonTargetAnalysis")
    }
    if (any(grepl("Chromatograms", classes, fixed = TRUE))) {
      return("ProjectMassSpecChromatograms")
    }
    if (any(grepl("Spectra", classes, fixed = TRUE))) {
      return("ProjectMassSpecSpectra")
    }
    if (any(grepl("MassSpec", classes, fixed = TRUE))) {
      return("ProjectMassSpec")
    }
  }
  if (identical(type, "MassSpec")) {
    return("ProjectMassSpec")
  }
  NA_character_
}

# MARK: .make_processing_parameter_doc
#' @noRd
.make_processing_parameter_doc <- function(description, type = NA_character_, required = FALSE) {
  list(
    description = as.character(description),
    type = as.character(type),
    required = as.logical(required)
  )
}

# MARK: .make_project_processing_step
#' @noRd
.make_project_processing_step <- function(
    method,
    parameters,
    parameter_docs,
    title,
    description,
    details,
    required = NA_character_,
    owner_class,
    algorithm = NA_character_,
    type = "MassSpec",
    input_class = owner_class,
    output_class = owner_class,
    number_permitted = 1,
    software = "StreamFind",
    developer = "Ricardo Cunha",
    contact = "cunha@iuta.de",
    link = "https://odea-project.github.io/StreamFind",
    doi = NA_character_) {
  if (length(required) == 1 && is.na(required)) {
    required <- character()
  }
  ProcessingStep(
    type = type,
    method = method,
    required = required,
    algorithm = algorithm,
    owner_class = owner_class,
    input_class = input_class,
    output_class = output_class,
    number_permitted = number_permitted,
    version = as.character(packageVersion("StreamFind")),
    software = software,
    developer = developer,
    contact = contact,
    link = link,
    doi = doi,
    parameters = parameters,
    title = title,
    description = description,
    details = details,
    parameter_docs = parameter_docs,
    constructor_name = if (!is.na(algorithm) && nzchar(algorithm)) paste0(type, "Method_", method, "_", algorithm) else paste0(type, "Method_", method)
  )
}

#' @title .convert_to_json
#'
#' @description Converts an object to JSON format.
#'
#' @noRd
.convert_to_json <- function(x) {
  jsonlite::toJSON(
    x,
    dataframe = "columns",
    Date = "ISO8601",
    POSIXt = "string",
    factor = "string",
    complex = "string",
    null = "null",
    na = "null",
    digits = 6,
    pretty = TRUE,
    force = TRUE
  )
}

#' @noRd
.get_colors <- function(obj) {
  colors <- c(
    brewer.pal(8, "Greys")[6],
    brewer.pal(8, "Greens")[6],
    brewer.pal(8, "Blues")[6],
    brewer.pal(8, "Oranges")[6],
    brewer.pal(8, "Purples")[6],
    brewer.pal(8, "PuRd")[6],
    brewer.pal(8, "YlOrRd")[6],
    brewer.pal(8, "PuBuGn")[6],
    brewer.pal(8, "GnBu")[6],
    brewer.pal(8, "BuPu")[6],
    brewer.pal(8, "Dark2")
  )

  Ncol <- length(unique(obj))

  if (Ncol > 18) {
    colors <- colorRampPalette(colors)(Ncol)
  }

  if (length(unique(obj)) < length(obj)) {
    Vcol <- colors[seq_len(Ncol)]
    Ncol <- length(obj)
    char <- NULL
    df <- data.frame(n = seq_len(Ncol), char = obj)
    count <- table(df$char)
    count <- as.data.frame(count)
    Vcol <- rep(Vcol, times = count[, "Freq"])
    names(Vcol) <- obj
  } else {
    Vcol <- colors[seq_len(Ncol)]
    names(Vcol) <- obj
  }

  Vcol
}

# MARK: DB Utilitiy Functions

# MARK: .query_db
#' @title .query_db
#' @description Execute a SQL query on a database-backed object.
#' @param conn Database connection object.
#' @param query SQL query string.
#' @template arg-sql-params
#' @return Data frame with query results.
#' @noRd
#'
.query_db <- function(conn, query, params = list()) {
  if (is.null(params)) {
    res <- DBI::dbGetQuery(conn, query)
  } else {
    res <- DBI::dbGetQuery(conn, query, params)
  }
  res
}

# MARK: .list_db_tables
#' @title .list_db_tables
#' @description List all tables in a database-backed object.
#' @param conn Database connection object.
#' @return Character vector with table names.
#' @noRd
#'
.list_db_tables <- function(conn) {
  tables <- DBI::dbListTables(conn)
  tables
}

# MARK: .get_db_table_info
#' @title .get_db_table_info
#' @description Get information about a specific table in a database-backed object.
#' @param conn Database connection object.
#' @param table_name Name of the table to get information about.
#' @return Data frame with table information.
#' @noRd
#'
.get_db_table_info <- function(conn, table_name) {
  res <- NULL
  tryCatch({
    # Get row count
    count_result <- DBI::dbGetQuery(conn,
      paste("SELECT COUNT(*) as row_count FROM", table_name))
    # Get column info
    columns <- DBI::dbGetQuery(conn,
      paste("PRAGMA table_info(", table_name, ")"))
    res <- list(
      table_name = table_name,
      row_count = count_result$row_count[1],
      columns = columns
    )
  }, error = function(e) {
    warning("Error getting table info for ", table_name, ": ", e$message)
  })
  res
}
