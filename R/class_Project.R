#' @title Internal Project Base R6 Class
#' @description Internal DuckDB-backed StreamFind project runtime.
#' @template arg-db-path
#' @template arg-project-id
#' @template arg-value
#' @template arg-step
#' @template arg-workflow
#' @template arg-template
#' @template arg-output-file
#' @template arg-execute-dir
#' @template arg-cache-name
#' @template arg-ellipsis
#' @keywords internal
#'
Project <- R6::R6Class(
  classname = "Project",
  cloneable = FALSE,
  private = list(
    .ptr = NULL,
    .db = NULL,
    .project_id = NULL
  ),

  public = list(
    #' @description Create a new `Project` handle.
    initialize = function(db, project_id, ...) {
      dots <- list(...)
      ptr_res <- .pull_internal_init_arg(dots, ".ptr")
      .ptr <- ptr_res$value
      .assert_only_internal_init_args(ptr_res$dots, "Project$initialize()")
      if (!requireNamespace("duckdb", quietly = TRUE)) {
        stop("duckdb package is required for Project")
      }
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
      rcpp_project_validate(private$.ptr)
      invisible(self)
    },
    #' @description Get the project metadata.
    get_metadata = function() {
      value <- rcpp_project_get_metadata(private$.ptr)
      if (is.null(value) || identical(value, "") || identical(value, "null")) NULL else jsonlite::fromJSON(value)
    },
    #' @description Set the project metadata.
    set_metadata = function(value) {
      metadata_json <- if (is.null(value)) {
        "null"
      } else if (is.character(value) && length(value) == 1L) {
        value
      } else {
        as.character(.convert_to_json(value))
      }
      rcpp_project_set_metadata(private$.ptr, metadata_json)
      invisible(self)
    },
    #' @description Get the project domain.
    get_domain = function() {
      value <- rcpp_project_get_domain(private$.ptr)
      if (is.null(value) || identical(value, "")) NULL else value
    },
    #' @description Get the project workflow.
    get_workflow = function() {
      value <- rcpp_project_get_workflow(private$.ptr)
      if (is.null(value) || identical(value, "") || identical(value, "null")) NULL else jsonlite::fromJSON(value)
    },
    #' @description Set the project workflow.
    set_workflow = function(value) {
      workflow_json <- if (is.null(value)) {
        "null"
      } else if (is.character(value) && length(value) == 1L) {
        value
      } else {
        as.character(.convert_to_json(value))
      }
      rcpp_project_set_workflow(private$.ptr, workflow_json)
      invisible(self)
    },
    #' @description Return all audit entries.
    get_audit = function() {
      rcpp_project_get_audit(private$.ptr)
    },
    #' @description Return the number of cache rows.
    get_cache_size = function() {
      as.integer(rcpp_project_get_cache_size(private$.ptr))
    },
    #' @description Return cache rows for the active project.
    get_cache = function() {
      rcpp_project_get_cache(private$.ptr)
    },
    #' @description Delete cache rows, optionally filtered by cache name.
    delete_cache = function(name = NULL) {
      if (!is.null(name)) {
        checkmate::assert_character(name, len = 1, any.missing = FALSE)
      }
      rcpp_project_delete_cache(private$.ptr, name)
      invisible(self)
    },
    #' @description List tables in the project database.
    list_tables = function() {
      rcpp_project_list_tables(private$.ptr)
    },
    #' @description Return project-owned processing-step metadata.
    available_processing_methods = function() {
      list()
    },
    #' @description Run one workflow step via its owning project method.
    run_processing_step = function(step) {
      if (!inherits(step, "ProcessingStep")) {
        step <- as.ProcessingStep(step)
      }
      owner_class <- step$owner_class
      if (!is.na(owner_class) && nzchar(owner_class) && !owner_class %in% class(self)) {
        stop(sprintf(
          "Workflow step '%s' belongs to '%s' but active project is '%s'.",
          step$constructor_name,
          owner_class,
          class(self)[1]
        ))
      }
      method_name <- step$method
      if (is.na(method_name) || !nzchar(method_name)) {
        stop(sprintf(
          "Workflow step '%s' does not define a method dispatch target.",
          step$constructor_name
        ))
      }
      method_fun <- self[[method_name]]
      if (!is.function(method_fun)) {
        stop(sprintf(
          "Active project class '%s' does not implement workflow method '%s'.",
          class(self)[1],
          method_name
        ))
      }
      parameters <- step$parameters
      if (is.null(parameters)) {
        parameters <- list()
      }
      checkmate::assert_list(parameters)
      do.call(method_fun, parameters)
      invisible(self)
    },
    #' @description Run the active project workflow via project-owned methods.
    run_workflow = function(workflow = NULL) {
      if (is.null(workflow)) {
        workflow <- self$get_workflow()
      } else if (!inherits(workflow, "Workflow")) {
        workflow <- Workflow(workflow)
      }
      if (is.null(workflow) || length(workflow) == 0) {
        warning("There are no processing steps to run!")
        return(invisible(self))
      }
      self$set_workflow(workflow)
      for (i in seq_along(workflow)) {
        self$run_processing_step(workflow[[i]])
      }
      invisible(self)
    },
    #' @description Generate a Quarto report for the active project.
    report_quarto = function(template = NULL, output_file = NULL, execute_dir = getwd(), ...) {
      if (is.null(template) || !file.exists(template)) {
        warning("Template not found!")
        return(invisible(self))
      }
      if (!requireNamespace("quarto", quietly = TRUE)) {
        warning("quarto package not installed! Please install it with: install.packages('quarto')")
        return(invisible(self))
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
      execute_params$db <- normalizePath(private$.db, mustWork = TRUE)
      execute_params$project_id <- private$.project_id
      execute_params$project_class <- class(self)[1]

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

      invisible(self)
    },
    #' @description Run the StreamFind app using the active project as startup context.
    run_app = function() {
      run_app(
        db = private$.db,
        project_id = private$.project_id,
        project_class = class(self)[1]
      )
    },
    #' @description Copy this project to another database and/or project id.
    copy = function(db = private$.db, project_id = private$.project_id) {
      copied_ptr <- rcpp_project_copy(private$.ptr, db, project_id)
      Project$new(db, project_id, .ptr = copied_ptr)
    },
    #' @description Print a short summary.
    print = function(...) {
      cat("\nProject\n")
      cat("db: ", private$.db, "\n", sep = "")
      cat("project_id: ", private$.project_id, "\n", sep = "")
      domain <- try(self$get_domain(), silent = TRUE)
      if (!inherits(domain, "try-error") && !is.null(domain)) {
        cat("domain: ", domain, "\n", sep = "")
      }
      audit_info <- try(self$get_audit(), silent = TRUE)
      if (!inherits(audit_info, "try-error")) {
        cat("audit entries: ", nrow(audit_info), "\n", sep = "")
      }
      invisible(self)
    },
    #' @description Show a short summary.
    show = function(...) {
      self$print(...)
    }
  )
)


#' @name ProjectS3
#' @title Project S3 Methods
#' @description S3 wrappers for `Project` R6 methods providing a thin functional interface.
#' @param x A `Project` object.
#' @template arg-db-path
#' @template arg-project-id
#' @template arg-value
#' @template arg-step
#' @template arg-workflow
#' @template arg-template
#' @template arg-output-file
#' @template arg-execute-dir
#' @template arg-ellipsis
#' @template arg-cache-name
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
  x$validate()
}

#' @describeIn ProjectS3 Get the project metadata.
#' @method get_metadata Project
#' @export
get_metadata.Project <- function(x) {
  checkmate::assert_class(x, "Project")
  x$get_metadata()
}

#' @describeIn ProjectS3 Set the project metadata; `value` may be a list, JSON string, or NULL.
#' @method set_metadata Project
#' @export
set_metadata.Project <- function(x, value) {
  checkmate::assert_class(x, "Project")
  x$set_metadata(value)
}

#' @describeIn ProjectS3 Get the project domain.
#' @method get_domain Project
#' @export
get_domain.Project <- function(x) {
  checkmate::assert_class(x, "Project")
  x$get_domain()
}

#' @describeIn ProjectS3 Get the project workflow.
#' @method get_workflow Project
#' @export
get_workflow.Project <- function(x) {
  checkmate::assert_class(x, "Project")
  x$get_workflow()
}

#' @describeIn ProjectS3 Set the project workflow; `value` may be a Workflow-compatible list, JSON string, or NULL.
#' @method set_workflow Project
#' @export
set_workflow.Project <- function(x, value) {
  checkmate::assert_class(x, "Project")
  x$set_workflow(value)
}

#' @describeIn ProjectS3 Return all audit entries.
#' @method get_audit Project
#' @export
get_audit.Project <- function(x) {
  checkmate::assert_class(x, "Project")
  x$get_audit()
}

#' @describeIn ProjectS3 Return the number of cache rows.
#' @method get_cache_size Project
#' @export
get_cache_size.Project <- function(x) {
  checkmate::assert_class(x, "Project")
  x$get_cache_size()
}

#' @describeIn ProjectS3 Return cache rows for the active project.
#' @method get_cache Project
#' @export
get_cache.Project <- function(x) {
  checkmate::assert_class(x, "Project")
  x$get_cache()
}

#' @describeIn ProjectS3 Delete cache rows, optionally filtered by cache name.
#' @method delete_cache Project
#' @export
delete_cache.Project <- function(x, name = NULL) {
  checkmate::assert_class(x, "Project")
  x$delete_cache(name = name)
}

#' @describeIn ProjectS3 List tables in the project database.
#' @method list_tables Project
#' @export
list_tables.Project <- function(x) {
  checkmate::assert_class(x, "Project")
  x$list_tables()
}

#' @describeIn ProjectS3 Return project-owned processing-step metadata.
#' @method available_processing_methods Project
#' @export
available_processing_methods.Project <- function(x) {
  checkmate::assert_class(x, "Project")
  x$available_processing_methods()
}

#' @describeIn ProjectS3 Run one workflow step via its owning project method.
#' @method run_processing_step Project
#' @export
run_processing_step.Project <- function(x, step) {
  checkmate::assert_class(x, "Project")
  x$run_processing_step(step)
}

#' @describeIn ProjectS3 Run the active workflow or supplied `workflow`.
#' @method run_workflow Project
#' @export
run_workflow.Project <- function(x, workflow = NULL) {
  checkmate::assert_class(x, "Project")
  x$run_workflow(workflow = workflow)
}

#' @describeIn ProjectS3 Generate a Quarto report for the active project.
#' @method report_quarto Project
#' @export
report_quarto.Project <- function(x, template = NULL, output_file = NULL, execute_dir = getwd(), ...) {
  checkmate::assert_class(x, "Project")
  x$report_quarto(template = template, output_file = output_file, execute_dir = execute_dir, ...)
}

#' @describeIn ProjectS3 Run the StreamFind app using the active project as startup context.
#' @method run_app Project
#' @export
run_app.Project <- function(x) {
  checkmate::assert_class(x, "Project")
  x$run_app()
}

#' @describeIn ProjectS3 Copy this project to another database and/or project id, returning a new `Project` object.
#' @method copy Project
#' @export
copy.Project <- function(x, db = x$get_db(), project_id = x$get_project_id()) {
  checkmate::assert_class(x, "Project")
  x$copy(db = db, project_id = project_id)
}
