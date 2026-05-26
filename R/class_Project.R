#' @title Internal Project Base R6 Class
#' @description Internal DuckDB-backed StreamFind project runtime.
#' @template arg-Project-db
#' @template arg-Project-project-id
#' @template arg-Project-value
#' @template arg-Project-cache-name
#' @template arg-Project-step
#' @template arg-Project-workflow
#' @template arg-Project-template
#' @template arg-Project-output-file
#' @template arg-Project-execute-dir
#' @template arg-Project-ellipsis
#' @keywords internal
#'
Project <- R6::R6Class(
  classname = "Project",
  cloneable = FALSE,
  private = list(
    .ptr = NULL,
    .db = NULL,
    .project_id = NULL,
    finalize = function() {
      if (!is.null(private$.ptr)) {
        try(rcpp_project_close(private$.ptr), silent = TRUE)
      }
    }
  ),
  public = list(
    #' @description Create a new `Project` handle.
    initialize = function(db, project_id, ...) {
      dots <- list(...)
      ptr_res <- .pull_internal_init_arg(dots, ".ptr")
      .ptr <- ptr_res$value
      .assert_only_internal_init_args(ptr_res$dots, "Project$initialize()")
      checkmate::assert_character(db, len = 1)
      checkmate::assert_character(project_id, len = 1)
      private$.db <- db
      private$.project_id <- project_id
      private$.ptr <- if (is.null(.ptr)) rcpp_project_new(db, project_id) else .ptr
    },
    #' @description Return the native project pointer.
    get_ptr = function() {
      private$.ptr
    },
    #' @description Get the project database path.
    get_db = function() {
      private$.db
    },
    #' @description Get the active project identifier.
    get_project_id = function() {
      private$.project_id
    },
    #' @description Validate the project schema and row state.
    validate = function() {
      validate.Project(self)
    },
    #' @description Close the shared DuckDB handle for this project object.
    close = function() {
      close.Project(self)
    },
    #' @description Get the project metadata.
    get_metadata = function() {
      get_metadata.Project(self)
    },
    #' @description Set the project metadata.
    set_metadata = function(value) {
      set_metadata.Project(self, value)
    },
    #' @description Get the project domain.
    get_domain = function() {
      get_domain.Project(self)
    },
    #' @description Get the project workflow.
    get_workflow = function() {
      get_workflow.Project(self)
    },
    #' @description Set the project workflow.
    set_workflow = function(value) {
      set_workflow.Project(self, value)
    },
    #' @description Return all audit entries.
    get_audit = function() {
      get_audit.Project(self)
    },
    #' @description Return the number of cache rows.
    get_cache_size = function() {
      get_cache_size.Project(self)
    },
    #' @description Return cache rows for the active project.
    get_cache = function() {
      get_cache.Project(self)
    },
    #' @description Delete cache rows, optionally filtered by cache name.
    delete_cache = function(name = NULL) {
      delete_cache.Project(self, name = name)
    },
    #' @description List tables in the project database.
    list_tables = function() {
      list_tables.Project(self)
    },
    #' @description Return project-owned method metadata.
    available_processing_methods = function() {
      available_processing_methods.Project(self)
    },
    #' @description Run one workflow method via its owning project method.
    run_method = function(step) {
      run_method.Project(self, step)
    },
    #' @description Run the active project workflow via project-owned methods.
    run_workflow = function(workflow = NULL) {
      run_workflow.Project(self, workflow = workflow)
    },
    #' @description Generate a Quarto report for the active project.
    report_quarto = function(template = NULL, output_file = NULL, execute_dir = getwd(), ...) {
      report_quarto.Project(self, template = template, output_file = output_file, execute_dir = execute_dir, ...)
    },
    #' @description Run the StreamFind app using the active project as startup context.
    run_app = function() {
      run_app.Project(self)
    },
    #' @description Copy this project to another database and/or project id.
    copy = function(db = private$.db, project_id = private$.project_id) {
      copy.Project(self, db = db, project_id = project_id)
    },
    #' @description Print a short summary.
    print = function(...) {
      print.Project(self, ...)
    },
    #' @description Show a short summary.
    show = function(...) {
      show.Project(self, ...)
    }
  )
)

#' @noRd
.print_project_summary_base <- function(x, title = class(x)[1]) {
  cat("\n", title, "\n", sep = "")
  cat("db: ", x$get_db(), "\n", sep = "")
  cat("project_id: ", x$get_project_id(), "\n", sep = "")
  domain <- try(get_domain.Project(x), silent = TRUE)
  if (!inherits(domain, "try-error") && !is.null(domain)) {
    cat("domain: ", domain, "\n", sep = "")
  }
  audit_info <- try(get_audit.Project(x), silent = TRUE)
  if (!inherits(audit_info, "try-error")) {
    cat("audit entries: ", nrow(audit_info), "\n", sep = "")
  }
  invisible(x)
}


#' @name ProjectS3
#' @title Project S3 Methods
#' @description S3 wrappers for `Project` R6 methods providing a thin functional interface.
#' @param x A `Project` object.
#' @template args-Project
NULL

#' @describeIn ProjectS3 Return the native project pointer.
#' @export
get_ptr.Project <- function(x) {
  checkmate::assert_class(x, "Project")
  x$get_ptr()
}

#' @describeIn ProjectS3 Get the project database path.
#' @export
get_db.Project <- function(x) {
  checkmate::assert_class(x, "Project")
  x$get_db()
}

#' @describeIn ProjectS3 Get the active project identifier.
#' @export
get_project_id.Project <- function(x) {
  checkmate::assert_class(x, "Project")
  x$get_project_id()
}

#' @describeIn ProjectS3 Validate the project schema and row state.
#' @method validate Project
#' @export
validate.Project <- function(x) {
  checkmate::assert_class(x, "Project")
  rcpp_project_validate(x$get_ptr())
  invisible(x)
}

#' @describeIn ProjectS3 Close the shared DuckDB handle for this project object.
#' @method close Project
#' @export
close.Project <- function(con, ...) {
  checkmate::assert_class(con, "Project")
  rcpp_project_close(con$get_ptr())
  invisible(con)
}

#' @describeIn ProjectS3 Get the project metadata.
#' @method get_metadata Project
#' @export
get_metadata.Project <- function(x) {
  checkmate::assert_class(x, "Project")
  value <- rcpp_project_get_metadata(x$get_ptr())
  if (is.null(value) || identical(value, "") || identical(value, "null")) NULL else jsonlite::fromJSON(value)
}

#' @describeIn ProjectS3 Set the project metadata; `value` may be a list, JSON string, or NULL.
#' @method set_metadata Project
#' @export
set_metadata.Project <- function(x, value) {
  checkmate::assert_class(x, "Project")
  metadata_json <- if (is.null(value)) {
    "null"
  } else if (is.character(value) && length(value) == 1L) {
    value
  } else {
    as.character(.convert_to_json(value))
  }
  rcpp_project_set_metadata(x$get_ptr(), metadata_json)
  invisible(x)
}

#' @describeIn ProjectS3 Get the project domain.
#' @method get_domain Project
#' @export
get_domain.Project <- function(x) {
  checkmate::assert_class(x, "Project")
  value <- rcpp_project_get_domain(x$get_ptr())
  if (is.null(value) || identical(value, "")) NULL else value
}

#' @describeIn ProjectS3 Get the project workflow.
#' @method get_workflow Project
#' @export
get_workflow.Project <- function(x) {
  checkmate::assert_class(x, "Project")
  value <- rcpp_project_get_workflow(x$get_ptr())
  if (is.null(value) || identical(value, "") || identical(value, "null")) {
    return(NULL)
  }
  Workflow(jsonlite::fromJSON(
    value,
    simplifyVector = FALSE,
    simplifyDataFrame = FALSE,
    simplifyMatrix = FALSE
  ))
}

#' @describeIn ProjectS3 Set the project workflow; `value` may be a Workflow-compatible list, JSON string, or NULL.
#' @method set_workflow Project
#' @export
set_workflow.Project <- function(x, value) {
  checkmate::assert_class(x, "Project")
  workflow_json <- if (is.null(value)) {
    "null"
  } else if (is.character(value) && length(value) == 1L) {
    value
  } else {
    workflow <- if (inherits(value, "Workflow")) value else Workflow(value)
    payload <- unname(lapply(workflow, unclass))
    as.character(.convert_to_json(payload))
  }
  rcpp_project_set_workflow(x$get_ptr(), workflow_json)
  invisible(x)
}

#' @describeIn ProjectS3 Return all audit entries.
#' @method get_audit Project
#' @export
get_audit.Project <- function(x) {
  checkmate::assert_class(x, "Project")
  rcpp_project_get_audit(x$get_ptr())
}

#' @describeIn ProjectS3 Return the number of cache rows.
#' @method get_cache_size Project
#' @export
get_cache_size.Project <- function(x) {
  checkmate::assert_class(x, "Project")
  as.integer(rcpp_project_get_cache_size(x$get_ptr()))
}

#' @describeIn ProjectS3 Return cache rows for the active project.
#' @method get_cache Project
#' @export
get_cache.Project <- function(x) {
  checkmate::assert_class(x, "Project")
  rcpp_project_get_cache(x$get_ptr())
}

#' @describeIn ProjectS3 Delete cache rows, optionally filtered by cache name.
#' @method delete_cache Project
#' @export
delete_cache.Project <- function(x, name = NULL) {
  checkmate::assert_class(x, "Project")
  if (!is.null(name)) {
    checkmate::assert_character(name, len = 1, any.missing = FALSE)
  }
  rcpp_project_delete_cache(x$get_ptr(), name)
  invisible(x)
}

#' @describeIn ProjectS3 List tables in the project database.
#' @method list_tables Project
#' @export
list_tables.Project <- function(x) {
  checkmate::assert_class(x, "Project")
  rcpp_project_list_tables(x$get_ptr())
}

#' @describeIn ProjectS3 Return project-owned method metadata.
#' @method available_processing_methods Project
#' @export
available_processing_methods.Project <- function(x) {
  checkmate::assert_class(x, "Project")
  .discover_project_methods(class(x)[1])
}

#' @describeIn ProjectS3 Run one workflow method via its owning project method.
#' @method run_method Project
#' @export
run_method.Project <- function(x, step) {
  checkmate::assert_class(x, "Project")
  if (!inherits(step, "Method")) {
    step <- as.Method(step)
  }
  step_name <- step$method
  if (is.na(step_name) || !nzchar(step_name)) {
    step_name <- class(step)[1]
  }
  owner_class <- step$owner_class
  if (!is.na(owner_class) && nzchar(owner_class) && !owner_class %in% class(x)) {
    stop(sprintf(
      "Workflow method '%s' belongs to '%s' but active project is '%s'.",
      class(step)[1],
      owner_class,
      class(x)[1]
    ))
  }
  cat("\u2699 Running ", step_name, "\n", sep = "")
  flush.console()
  run_method <- NULL
  for (cls in class(step)) {
    run_method <- utils::getS3method("run", cls, optional = TRUE)
    if (!is.null(run_method)) {
      break
    }
  }
  if (!is.null(run_method)) {
    run(step, x)
    return(invisible(x))
  }
  method_name <- step$method
  if (is.na(method_name) || !nzchar(method_name)) {
    stop(sprintf(
      "Workflow method '%s' does not define a method dispatch target.",
      class(step)[1]
    ))
  }
  method_fun <- x[[method_name]]
  if (!is.function(method_fun)) {
    stop(sprintf(
      "Active project class '%s' does not implement workflow method '%s'.",
      class(x)[1],
      method_name
    ))
  }
  parameters <- step$parameters
  if (is.null(parameters)) {
    parameters <- list()
  }
  checkmate::assert_list(parameters)
  do.call(method_fun, parameters)
  invisible(x)
}

#' @describeIn ProjectS3 Run the active workflow or supplied `workflow`.
#' @method run_workflow Project
#' @export
run_workflow.Project <- function(x, workflow = NULL) {
  checkmate::assert_class(x, "Project")
  if (is.null(workflow)) {
    workflow <- get_workflow.Project(x)
  } else if (!inherits(workflow, "Workflow")) {
    workflow <- Workflow(workflow)
  }
  if (is.null(workflow) || length(workflow) == 0) {
    warning("There are no workflow methods to run!")
    return(invisible(x))
  }
  set_workflow.Project(x, workflow)
  for (i in seq_along(workflow)) {
    run_method.Project(x, workflow[[i]])
  }
  invisible(x)
}

#' @describeIn ProjectS3 Generate a Quarto report for the active project.
#' @method report_quarto Project
#' @export
report_quarto.Project <- function(x, template = NULL, output_file = NULL, execute_dir = getwd(), ...) {
  checkmate::assert_class(x, "Project")
  if (is.null(template) || !file.exists(template)) {
    warning("Template not found!")
    return(invisible(x))
  }
  if (!requireNamespace("quarto", quietly = TRUE)) {
    warning("quarto package not installed! Please install it with: install.packages('quarto')")
    return(invisible(x))
  }

  template <- normalizePath(template, mustWork = TRUE)

  if (is.null(execute_dir) || !nzchar(trimws(execute_dir))) {
    execute_dir <- getwd()
  } else {
    execute_dir <- trimws(execute_dir)
  }
  execute_dir <- normalizePath(execute_dir, mustWork = FALSE)

  if (is.null(output_file)) {
    output_file <- tools::file_path_sans_ext(basename(template))
  } else {
    checkmate::assert_character(output_file, len = 1)
    output_file <- trimws(output_file)
  }

  output_file_dir <- dirname(output_file)
  if (identical(output_file_dir, ".")) {
    output_dir <- execute_dir
    output_file <- basename(output_file)
  } else {
    if (grepl("^([A-Za-z]:|/|\\\\)", output_file)) {
      output_file_abs <- normalizePath(output_file, mustWork = FALSE)
    } else {
      output_file_abs <- normalizePath(file.path(execute_dir, output_file), mustWork = FALSE)
    }
    output_dir <- dirname(output_file_abs)
    output_file <- basename(output_file_abs)
  }

  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  dots <- list(...)
  if ("output_dir" %in% names(dots)) {
    warning("Argument output_dir is deprecated for Project$report_quarto() and will be ignored.")
    dots$output_dir <- NULL
  }
  execute_params <- dots$execute_params
  dots$execute_params <- NULL
  if (is.null(execute_params)) {
    execute_params <- list()
  }
  checkmate::assert_list(execute_params)
  execute_params$db <- normalizePath(x$get_db(), mustWork = TRUE)
  execute_params$project_id <- x$get_project_id()
  execute_params$project_class <- class(x)[1]

  quarto_args <- dots$quarto_args
  dots$quarto_args <- NULL
  if (is.null(quarto_args)) {
    quarto_args <- character()
  } else {
    checkmate::assert_character(quarto_args)
  }
  if (!"--output-dir" %in% quarto_args) {
    quarto_args <- c(quarto_args, "--output-dir", output_dir)
  }

  tryCatch(
    {
      do.call(
        quarto::quarto_render,
        c(
          list(
            input = template,
            output_file = output_file,
            execute_dir = execute_dir,
            execute_params = execute_params,
            quarto_args = quarto_args
          ),
          dots
        )
      )
      message("\U2713 Quarto report generated successfully!")
    },
    error = function(e) {
      warning("Error generating Quarto report: ", e$message)
    }
  )

  invisible(x)
}

#' @describeIn ProjectS3 Run the StreamFind app using the active project as startup context.
#' @method run_app Project
#' @export
run_app.Project <- function(x) {
  checkmate::assert_class(x, "Project")
  run_app(
    project_object = x,
    db = x$get_db(),
    project_id = x$get_project_id(),
    project_class = class(x)[1]
  )
}

#' @describeIn ProjectS3 Copy this project to another database and/or project id, returning a new `Project` object.
#' @method copy Project
#' @export
copy.Project <- function(x, db = x$get_db(), project_id = x$get_project_id()) {
  checkmate::assert_class(x, "Project")
  copied_ptr <- rcpp_project_copy(x$get_ptr(), db, project_id)
  Project$new(db, project_id, .ptr = copied_ptr)
}

#' @describeIn ProjectS3 Print a short summary.
#' @method print Project
#' @export
print.Project <- function(x, ...) {
  checkmate::assert_class(x, "Project")
  .print_project_summary_base(x, title = "Project")
}

#' @describeIn ProjectS3 Show a short summary.
#' @method show Project
#' @export
show.Project <- function(x, ...) {
  checkmate::assert_class(x, "Project")
  print.Project(x, ...)
}
