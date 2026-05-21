#' @title Method Metadata Object
#' @description Method metadata used by project-owned workflow registries and
#'   workflow execution.
#'   `Method` is the metadata container for project methods.
#' @param method Processing method name. This should match the owning project
#'   child-class method name.
#' @param required Character vector of required preceding methods.
#' @param owner_class Owning project class.
#' @param number_permitted Maximum permitted occurrences in one workflow.
#' @param developer Developer name.
#' @param contact Developer contact.
#' @param link Reference link.
#' @param doi Reference DOI.
#' @param parameters Named list of parameter default values.
#' @return A `Method` object.
#' @export
Method <- function(
  method = NA_character_,
  required = character(),
  owner_class = NA_character_,
  number_permitted = NA_real_,
  developer = NA_character_,
  contact = NA_character_,
  link = NA_character_,
  doi = NA_character_,
  parameters = list()
) {
  class_name <- if (!is.na(method) && nzchar(method) && !is.na(owner_class) && nzchar(owner_class)) {
    paste0(sub("^Project", "Method_", owner_class), "_", method)
  } else if (!is.na(method) && nzchar(method)) {
    method
  } else {
    "Method"
  }
  x <- structure(
    list(
      method = method,
      required = required,
      owner_class = owner_class,
      number_permitted = number_permitted,
      developer = developer,
      contact = contact,
      link = link,
      doi = doi,
      parameters = parameters
    ),
    class = unique(c(class_name, "Method"))
  )
  validate_object(x)
  x
}

#' @export
#' @noRd
validate_object.Method <- function(x, ...) {
  checkmate::assert_character(x$method, len = 1, any.missing = FALSE)
  checkmate::assert_character(x$required, any.missing = FALSE, null.ok = FALSE)
  checkmate::assert_character(x$owner_class, len = 1, any.missing = FALSE)
  checkmate::assert_number(x$number_permitted, lower = 1, finite = FALSE, na.ok = FALSE)
  checkmate::assert_character(x$developer, len = 1, null.ok = FALSE)
  checkmate::assert_character(x$contact, len = 1, null.ok = FALSE)
  checkmate::assert_character(x$link, len = 1, null.ok = FALSE)
  checkmate::assert_character(x$doi, len = 1, null.ok = FALSE)
  checkmate::assert_list(x$parameters, names = "named")
  invisible(NULL)
}

#' @description Convert a list to a `Method` object.
#' @rdname Method
#' @param value A list representation of a method metadata object.
#' @return A `Method` object.
#' @export
as.Method <- function(value) {
  if (length(value) == 1 && is.list(value)) {
    value <- value[[1]]
  }
  checkmate::assert_list(value)
  required_fields <- c("method", "parameters")
  if (!all(required_fields %in% names(value))) {
    stop("Method metadata is missing required fields.")
  }
  defaults <- list(
    required = character(),
    owner_class = NA_character_,
    number_permitted = Inf,
    developer = NA_character_,
    contact = NA_character_,
    link = NA_character_,
    doi = NA_character_,
    parameters = list()
  )
  for (nm in names(defaults)) {
    if (!nm %in% names(value) || is.null(value[[nm]])) {
      value[[nm]] <- defaults[[nm]]
    }
  }
  value$method <- as.character(unlist(value$method, use.names = FALSE))[1]
  value$required <- if (length(value$required) == 0) {
    character()
  } else {
    as.character(unlist(value$required, use.names = FALSE))
  }
  value$owner_class <- as.character(unlist(value$owner_class, use.names = FALSE))[1]
  value$number_permitted <- as.numeric(unlist(value$number_permitted, use.names = FALSE))[1]
  value$developer <- as.character(unlist(value$developer, use.names = FALSE))[1]
  value$contact <- as.character(unlist(value$contact, use.names = FALSE))[1]
  value$link <- as.character(unlist(value$link, use.names = FALSE))[1]
  value$doi <- if (length(value$doi) == 0) {
    NA_character_
  } else {
    as.character(unlist(value$doi, use.names = FALSE))[1]
  }
  if (!is.na(value$method) && nzchar(value$method) &&
    !is.na(value$owner_class) && nzchar(value$owner_class)) {
    constructor_name <- paste0(sub("^Project", "Method_", value$owner_class), "_", value$method)
    constructor_envs <- Filter(Negate(is.null), list(
      tryCatch(asNamespace("StreamFind"), error = function(...) NULL),
      .GlobalEnv
    ))
    constructor_exists <- any(vapply(
      constructor_envs,
      function(env) exists(constructor_name, mode = "function", envir = env, inherits = TRUE),
      logical(1)
    ))
    if (constructor_exists) {
      constructor <- get(
        constructor_name,
        mode = "function",
        envir = constructor_envs[[which(vapply(
          constructor_envs,
          function(env) exists(constructor_name, mode = "function", envir = env, inherits = TRUE),
          logical(1)
        ))[1]]],
        inherits = TRUE
      )
      return(do.call(constructor, value$parameters))
    }
  }
  do.call(Method, value)
}

#' @rdname Method
#' @export
#' @noRd
show.Method <- function(x, ...) {
  cat("\n", class(x)[1], "\n", sep = "")
  cat("owner_class: ", x$owner_class, "\n", sep = "")
  cat("method: ", x$method, "\n", sep = "")
  invisible(x)
}

#' @rdname Method
#' @export
#' @noRd
save.Method <- function(x, file = "settings.json", ...) {
  format <- tools::file_ext(file)
  if (identical(format, "json")) {
    write(as.character(.convert_to_json(unclass(x))), file)
  } else if (identical(format, "rds")) {
    saveRDS(x, file)
  } else {
    stop("Unsupported Method format.")
  }
  invisible(x)
}

#' @rdname Method
#' @export
#' @noRd
read.Method <- function(x, file, ...) {
  if (grepl("\\.json$", file, ignore.case = TRUE) && file.exists(file)) {
    return(as.Method(jsonlite::fromJSON(file)))
  }
  if (grepl("\\.rds$", file, ignore.case = TRUE) && file.exists(file)) {
    return(readRDS(file))
  }
  stop("Unsupported Method input file.")
}
