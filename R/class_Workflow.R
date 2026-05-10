#' @title Workflow Metadata Container
#' @description Ordered list of `ProcessingStep` metadata objects.
#' @param processing_steps A list of `ProcessingStep` objects or compatible lists.
#' @return A `Workflow` object.
#' @export
Workflow <- function(processing_steps = list()) {
  checkmate::assert_list(processing_steps)
  items <- unclass(processing_steps)
  attributes(items) <- NULL
  if (length(items) > 0) {
    items <- lapply(items, function(step) {
      if (inherits(step, "ProcessingStep")) {
        return(step)
      }
      as.ProcessingStep(step)
    })
    workflow_methods <- character(0)
    for (i in seq_along(items)) {
      req <- unique(stats::na.omit(items[[i]]$required))
      if (length(req) > 0 && !all(req %in% workflow_methods)) {
        stop("Required methods not present earlier in the workflow: ", paste(setdiff(req, workflow_methods), collapse = ", "))
      }
      workflow_methods <- c(workflow_methods, items[[i]]$method)
    }
    names(items) <- paste0(seq_along(items), "_", vapply(items, function(step) step$method, character(1)))
  }
  structure(items, class = "Workflow")
}

#' @export
#' @noRd
validate_object.Workflow <- function(x, ...) {
  checkmate::assert_list(x)
  if (length(x) == 0) {
    return(invisible(NULL))
  }
  step_types <- vapply(x, function(step) {
    checkmate::assert_true(inherits(step, "ProcessingStep"))
    validate_object(step)
    step$type
  }, character(1))
  if (length(unique(step_types)) > 1) {
    stop("All workflow steps must share the same type.")
  }
  methods <- vapply(x, function(step) step$method, character(1))
  permitted <- vapply(x, function(step) step$number_permitted, numeric(1))
  singleton_methods <- methods[is.finite(permitted) & permitted == 1]
  if (length(unique(singleton_methods)) != length(singleton_methods)) {
    stop("Workflow contains duplicate single-permitted methods.")
  }
  invisible(NULL)
}

#' @export
#' @noRd
get_methods.Workflow <- function(x, ...) {
  if (length(x) == 0) {
    return(character())
  }
  vapply(x, function(step) step$constructor_name, character(1))
}

#' @export
#' @noRd
info.Workflow <- function(x, ...) {
  if (length(x) == 0) {
    return(data.frame())
  }
  data.frame(
    index = seq_along(x),
    type = vapply(x, function(step) step$type, character(1)),
    owner_class = vapply(x, function(step) step$owner_class, character(1)),
    method = vapply(x, function(step) step$method, character(1)),
    algorithm = vapply(x, function(step) step$algorithm, character(1)),
    input_class = vapply(x, function(step) step$input_class, character(1)),
    output_class = vapply(x, function(step) step$output_class, character(1)),
    number_permitted = vapply(x, function(step) step$number_permitted, numeric(1)),
    version = vapply(x, function(step) step$version, character(1)),
    software = vapply(x, function(step) step$software, character(1)),
    developer = vapply(x, function(step) step$developer, character(1)),
    contact = vapply(x, function(step) step$contact, character(1)),
    link = vapply(x, function(step) step$link, character(1)),
    doi = vapply(x, function(step) step$doi, character(1)),
    stringsAsFactors = FALSE
  )
}

#' @export
#' @noRd
`[.Workflow` <- function(x, i) {
  NextMethod()
}

#' @export
#' @noRd
`[[.Workflow` <- function(x, i) {
  NextMethod()
}

#' @export
#' @noRd
`[<-.Workflow` <- function(x, i, value) {
  x <- NextMethod()
  Workflow(x)
}

#' @export
#' @noRd
`[[<-.Workflow` <- function(x, i, value) {
  validate_object(value)
  x <- NextMethod()
  Workflow(x)
}

#' @export
#' @noRd
save.Workflow <- function(x, file = "workflow.rds", ...) {
  format <- tools::file_ext(file)
  if (identical(format, "json")) {
    payload <- lapply(x, unclass)
    names(payload) <- names(x)
    write(as.character(.convert_to_json(payload)), file)
  } else if (identical(format, "rds")) {
    saveRDS(x, file)
  } else {
    stop("Unsupported Workflow format.")
  }
  invisible(x)
}

#' @export
#' @noRd
read.Workflow <- function(x, file, ...) {
  if (grepl("\\.json$", file, ignore.case = TRUE) && file.exists(file)) {
    return(Workflow(jsonlite::fromJSON(file, simplifyVector = FALSE)))
  }
  if (grepl("\\.rds$", file, ignore.case = TRUE) && file.exists(file)) {
    return(readRDS(file))
  }
  stop("Unsupported Workflow input file.")
}

#' @export
#' @noRd
show.Workflow <- function(x, ...) {
  cat("\nWorkflow\n")
  cat("steps: ", length(x), "\n", sep = "")
  invisible(x)
}
