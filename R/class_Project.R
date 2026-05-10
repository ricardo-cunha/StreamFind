#' @title Internal Project Base R6 Class
#' @description Internal DuckDB-backed StreamFind project runtime.
#' @details Native bridge calls are inlined in the public methods for a single, flat interface.
#' This class underpins the public project wrappers but is not intended as a direct
#' user-facing entry point.
#' @param db Path to the project DuckDB file.
#' @param project_id Active project identifier.
#' @keywords internal
Project <- R6::R6Class(
  classname = "Project",
  cloneable = FALSE,
  private = list(
    .ptr = NULL,
    .db = NULL,
    .project_id = NULL
  ),
  active = list(
    #' @field db Project database path (read-only).
    db = function(value) {
      if (missing(value)) {
        return(private$.db)
      }
      stop("db is read-only")
    },
    #' @field project_id Active project identifier (read-only).
    project_id = function(value) {
      if (missing(value)) {
        return(private$.project_id)
      }
      stop("project_id is read-only")
    },
    #' @field metadata Project metadata JSON stored in DuckDB.
    metadata = function(value) {
      if (missing(value)) {
        return(self$get_metadata())
      }
      self$set_metadata(value)
      invisible(self)
    },
    #' @field domain Project domain stored in DuckDB.
    domain = function(value) {
      if (missing(value)) {
        return(self$get_domain())
      }
      stop("domain is read-only")
    },
    #' @field workflow Project workflow JSON stored in DuckDB.
    workflow = function(value) {
      if (missing(value)) {
        return(self$get_workflow())
      }
      self$set_workflow(value)
      invisible(self)
    }
  ),
  public = list(
    #' @description Create a new `Project` handle.
    #' @param db Path to the DuckDB project file.
    #' @param project_id Active project identifier.
    #' @param .ptr Existing native project pointer for internal use.
    initialize = function(db, project_id, .ptr = NULL) {
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
    #' @return External pointer to the C++ `project::Project` object.
    get_ptr = function() {
      private$.ptr
    },
    #' @description Validate the project schema and row state.
    #' @return The `Project` object invisibly.
    validate = function() {
      rcpp_project_validate(private$.ptr)
      invisible(self)
    },
    #' @description Get the project metadata.
    #' @return A list or `NULL`.
    get_metadata = function() {
      value <- rcpp_project_get_metadata(private$.ptr)
      if (is.null(value) || identical(value, "") || identical(value, "null")) NULL else jsonlite::fromJSON(value)
    },
    #' @description Set the project metadata.
    #' @param value A list, JSON string, or `NULL`.
    #' @return The `Project` object invisibly.
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
    #' @return A character scalar or `NULL`.
    get_domain = function() {
      value <- rcpp_project_get_domain(private$.ptr)
      if (is.null(value) || identical(value, "")) NULL else value
    },
    #' @description Get the project workflow.
    #' @return A list or `NULL`.
    get_workflow = function() {
      value <- rcpp_project_get_workflow(private$.ptr)
      if (is.null(value) || identical(value, "") || identical(value, "null")) NULL else jsonlite::fromJSON(value)
    },
    #' @description Set the project workflow.
    #' @param value A list, JSON string, or `NULL`.
    #' @return The `Project` object invisibly.
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
    #' @return A data.frame ordered by newest first.
    get_audit = function() {
      rcpp_project_get_audit(private$.ptr)
    },
    #' @description List tables in the project database.
    #' @return A character vector of table names.
    list_tables = function() {
      rcpp_project_list_tables(private$.ptr)
    },
    #' @description Return project-owned processing-step metadata.
    #' @return A named list of `ProcessingStep` metadata objects.
    available_processing_methods = function() {
      list()
    },
    #' @description Run one workflow step via its owning project method.
    #' @param step A `ProcessingStep` object or compatible list.
    #' @return The `Project` object invisibly.
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
    #' @param workflow Optional `Workflow` object or compatible list. Defaults to the stored project workflow.
    #' @return The `Project` object invisibly.
    run_workflow = function(workflow = self$workflow) {
      if (is.null(workflow)) {
        workflow <- Workflow()
      } else if (!inherits(workflow, "Workflow")) {
        workflow <- Workflow(workflow)
      }
      if (length(workflow) == 0) {
        warning("There are no processing steps to run!")
        return(invisible(self))
      }
      self$workflow <- workflow
      for (i in seq_along(workflow)) {
        self$run_processing_step(workflow[[i]])
      }
      invisible(self)
    },
    #' @description Generate a Quarto report for the active project.
    #' @param template Full path to the Quarto `.qmd` template.
    #' @param output_file Output file name or path without enforcing an extension.
    #' @param execute_dir Execution directory for Quarto.
    #' @param ... Additional arguments forwarded to `quarto::quarto_render()`.
    #' @return The `Project` object invisibly.
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
    #' @return Invisibly returns the launched app object.
    run_app = function() {
      run_app(
        db = private$.db,
        project_id = private$.project_id,
        project_class = class(self)[1]
      )
    },
    #' @description Copy this project to another database and/or project id.
    #' @param db Target DuckDB file path.
    #' @param project_id Target project identifier.
    #' @return A new `Project` object.
    copy = function(db = private$.db, project_id = private$.project_id) {
      copied_ptr <- rcpp_project_copy(private$.ptr, db, project_id)
      Project$new(db, project_id, .ptr = copied_ptr)
    },
    #' @description Print a short summary.
    #' @param ... Additional arguments ignored.
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
    #' @param ... Additional arguments ignored.
    show = function(...) {
      self$print(...)
    }
  )
)
