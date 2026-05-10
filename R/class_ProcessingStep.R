#' @title ProcessingStep Metadata Object
#' @description Processing-step metadata used by project-owned workflow registries.
#'   The object preserves the legacy `ProcessingStep` shape used by the workflow UI
#'   while allowing project classes to provide richer documentation metadata.
#' @param type Processing type, for example `"MassSpec"`.
#' @param method Processing method name. This should match the owning project
#'   child-class method name.
#' @param required Character vector of required preceding methods.
#' @param algorithm Optional algorithm label retained for compatibility.
#' @param owner_class Owning project class.
#' @param input_class Input class metadata.
#' @param output_class Output class metadata.
#' @param number_permitted Maximum permitted occurrences in one workflow.
#' @param version Method version string.
#' @param software Software name.
#' @param developer Developer name.
#' @param contact Developer contact.
#' @param link Reference link.
#' @param doi Reference DOI.
#' @param parameters Named list of parameter default values.
#' @param title Optional display title.
#' @param description Optional short description.
#' @param details Optional long-form details.
#' @param parameter_docs Optional named list with per-parameter metadata.
#' @param constructor_name Optional legacy constructor-style name.
#' @return A `ProcessingStep` object.
#' @export
ProcessingStep <- function(
    type = NA_character_,
    method = NA_character_,
    required = character(),
    algorithm = NA_character_,
    owner_class = NA_character_,
    input_class = NA_character_,
    output_class = NA_character_,
    number_permitted = NA_real_,
    version = NA_character_,
    software = NA_character_,
    developer = NA_character_,
    contact = NA_character_,
    link = NA_character_,
    doi = NA_character_,
    parameters = list(),
    title = NA_character_,
    description = NA_character_,
    details = NA_character_,
    parameter_docs = list(),
    constructor_name = NA_character_) {
  class_name <- constructor_name
  if (is.na(class_name) || !nzchar(class_name)) {
    if (!is.na(method) && nzchar(method) && !is.na(type) && nzchar(type)) {
      if (!is.na(algorithm) && nzchar(algorithm)) {
        class_name <- paste0(type, "Method_", method, "_", algorithm)
      } else {
        class_name <- paste0(type, "Method_", method)
      }
    } else if (!is.na(method) && nzchar(method)) {
      class_name <- method
    } else {
      class_name <- "ProcessingStep"
    }
  }
  x <- structure(
    list(
      type = type,
      method = method,
      required = required,
      algorithm = algorithm,
      owner_class = owner_class,
      input_class = input_class,
      output_class = output_class,
      number_permitted = number_permitted,
      version = version,
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
      constructor_name = class_name
    ),
    class = unique(c(class_name, "ProcessingStep"))
  )
  validate_object(x)
  x
}

#' @export
#' @noRd
validate_object.ProcessingStep <- function(x, ...) {
  checkmate::assert_character(x$type, len = 1, any.missing = FALSE)
  checkmate::assert_character(x$method, len = 1, any.missing = FALSE)
  checkmate::assert_character(x$required, any.missing = FALSE, null.ok = FALSE)
  checkmate::assert_character(x$algorithm, len = 1, null.ok = FALSE)
  checkmate::assert_character(x$owner_class, len = 1, any.missing = FALSE)
  checkmate::assert_character(x$input_class, len = 1, any.missing = FALSE)
  checkmate::assert_character(x$output_class, len = 1, any.missing = FALSE)
  checkmate::assert_number(x$number_permitted, lower = 1, finite = FALSE, na.ok = FALSE)
  checkmate::assert_character(x$version, len = 1, null.ok = FALSE)
  checkmate::assert_character(x$software, len = 1, null.ok = FALSE)
  checkmate::assert_character(x$developer, len = 1, null.ok = FALSE)
  checkmate::assert_character(x$contact, len = 1, null.ok = FALSE)
  checkmate::assert_character(x$link, len = 1, null.ok = FALSE)
  checkmate::assert_character(x$doi, len = 1, null.ok = FALSE)
  checkmate::assert_list(x$parameters, names = "named")
  checkmate::assert_character(x$title, len = 1, null.ok = FALSE)
  checkmate::assert_character(x$description, len = 1, null.ok = FALSE)
  checkmate::assert_character(x$details, len = 1, null.ok = FALSE)
  checkmate::assert_list(x$parameter_docs)
  checkmate::assert_character(x$constructor_name, len = 1, null.ok = FALSE)
  invisible(NULL)
}

#' @description Convert a list to a `ProcessingStep` object.
#' @rdname ProcessingStep
#' @param value A list representation of a processing-step metadata object.
#' @return A `ProcessingStep` object.
#' @export
as.ProcessingStep <- function(value) {
  if (length(value) == 1 && is.list(value)) {
    value <- value[[1]]
  }
  checkmate::assert_list(value)
  required_fields <- c("type", "method", "parameters")
  if (!all(required_fields %in% names(value))) {
    stop("ProcessingStep metadata is missing required fields.")
  }
  defaults <- list(
    required = character(),
    owner_class = .infer_processing_owner_class(
      value$type,
      if ("input_class" %in% names(value)) value$input_class else NA_character_,
      if ("output_class" %in% names(value)) value$output_class else NA_character_
    ),
    input_class = NA_character_,
    output_class = NA_character_,
    number_permitted = Inf,
    version = as.character(packageVersion("StreamFind")),
    software = "StreamFind",
    developer = NA_character_,
    contact = NA_character_,
    link = NA_character_,
    doi = NA_character_,
    title = NA_character_,
    description = NA_character_,
    details = NA_character_,
    parameter_docs = list(),
    constructor_name = NA_character_,
    algorithm = NA_character_
  )
  for (nm in names(defaults)) {
    if (!nm %in% names(value) || is.null(value[[nm]])) {
      value[[nm]] <- defaults[[nm]]
    }
  }
  do.call(ProcessingStep, value)
}

#' @rdname ProcessingStep
#' @export
#' @noRd
show.ProcessingStep <- function(x, ...) {
  cat("\n", x$constructor_name, "\n", sep = "")
  cat("title: ", x$title, "\n", sep = "")
  cat("owner_class: ", x$owner_class, "\n", sep = "")
  cat("method: ", x$method, "\n", sep = "")
  invisible(x)
}

#' @rdname ProcessingStep
#' @export
#' @noRd
save.ProcessingStep <- function(x, file = "settings.json", ...) {
  format <- tools::file_ext(file)
  if (identical(format, "json")) {
    write(as.character(.convert_to_json(unclass(x))), file)
  } else if (identical(format, "rds")) {
    saveRDS(x, file)
  } else {
    stop("Unsupported ProcessingStep format.")
  }
  invisible(x)
}

#' @rdname ProcessingStep
#' @export
#' @noRd
read.ProcessingStep <- function(x, file, ...) {
  if (grepl("\\.json$", file, ignore.case = TRUE) && file.exists(file)) {
    return(as.ProcessingStep(jsonlite::fromJSON(file, simplifyVector = FALSE)))
  }
  if (grepl("\\.rds$", file, ignore.case = TRUE) && file.exists(file)) {
    return(readRDS(file))
  }
  stop("Unsupported ProcessingStep input file.")
}
