##' @noRd
##' @export
.mod_Workflow_UI.Project <- function(x, id, ns) {
  ns2 <- shiny::NS(id)
  htmltools::div(
    style = "height: calc(100vh - var(--sf-topbar-height) - var(--sf-pad-10)); overflow: hidden; padding: 0px; min-height: 0;",
    htmltools::div(
      style = "display: flex; flex-direction: row; height: 100%; overflow: hidden; gap: 5px; min-height: 0;",
      htmltools::div(
        class = "workflow-column",
        style = "flex: 0 0 50%; width: 50%; min-width: 0; min-height: 0; overflow-x: hidden; overflow-y: auto;",
        shiny::uiOutput(ns(ns2("workflow_settings")))
      ),
      htmltools::div(
        class = "method-column",
        style = "flex: 0 0 50%; width: 50%; min-width: 0; min-height: 0; overflow-x: hidden; overflow-y: auto;",
        shiny::uiOutput(ns(ns2("selected_method_details")))
      )
    ),
    htmltools::tags$style(htmltools::HTML(
      "
      .workflow-column {
        padding-right: 0px;
        margin-right: 0px;
        min-height: 0;
      }
      .method-column {
        padding-left: 0px;
        margin-left: 0px;
        min-height: 0;
      }
      .custom-button {
        background-color: #1e2129;
        color: #ffffff;
        border: none;
        padding: 5px 10px;
        margin: 5px;
        cursor: pointer;
      }
      .custom-buttonred {
        background-color: #c0392b;
        color: #ffffff;
        border: none;
        padding: 2px 6px;
        margin: 5px;
        cursor: pointer;
        font-size: 12px;
      }
      .custom-button:hover {
        background-color: #2a2f3a;
      }
      .custom-buttonred:hover {
        background-color: #a93226;
      }
      .workflow-item {
        display: flex;
        align-items: center;
        margin-bottom: 5px;
      }
      .workflow-item span {
        flex-grow: 1;
      }
      .workflow-item button {
        margin-left: auto;
      }
      .workflow-box {
        background-color: var(--sf-content-bg, #ffffff);
        color: var(--sf-content-color, #333333);
        border-radius: 4px;
        padding: 5px;
        margin-bottom: 0px;
        border: none;
        box-shadow: none;
      }
      .box.workflow-box {
        border: none !important;
        box-shadow: none !important;
      }
      .box.workflow-box > .box-body {
        border: none !important;
        box-shadow: none !important;
      }
      .method-details dt {
        font-weight: bold;
        float: left;
        clear: left;
        width: 30%;
        padding-bottom: 1px;
        padding-top: 1px;
        margin-bottom: 0px;
        margin-top: 0px;
      }
      .method-details dd {
        width: 70%;
        padding-bottom: 1px;
        padding-top: 12px;
        margin-bottom: 0px;
        margin-top: 0px;
      }
      .parameters-section {
        margin-top: 2px;
        border-top: 1px solid #ccc;
        padding-top: 2px;
      }
      .modal-dialog {
        position: relative;
        width: auto;
        max-width: 80%;
        min-width: 500px;
      }
      .workflow-actions {
        display: flex;
        align-items: center;
        gap: 10px;
        flex-wrap: wrap;
        align-content: flex-start;
      }
      .workflow-actions > div {
        flex: 0 0 auto;
        display: flex;
      }
      .workflow-actions .btn,
      .workflow-actions .shinyFiles,
      .workflow-actions .shinySave {
        min-width: 150px;
        width: 150px !important;
      }
      .workflow-list-shell {
        flex: 1 1 auto;
        min-height: 0;
        overflow: hidden;
        display: flex;
        flex-direction: column;
      }
      .workflow-list-scroll {
        flex: 1 1 auto;
        min-height: 0;
        overflow-y: auto;
        overflow-x: hidden;
        padding: 0 10px 0 0;
        margin: 0;
      }
      .workflow-list-scroll .rank-list-container {
        border: none !important;
        padding: 0 !important;
        margin: 0 !important;
        background: transparent !important;
        box-shadow: none !important;
      }
      .workflow-list-scroll .rank-list-title {
        margin: 0 0 5px 0 !important;
      }
      .workflow-method-row {
        display: flex;
        align-items: center;
        gap: 10px;
        width: 100%;
        padding-right: 10px;
        box-sizing: border-box;
      }
      .workflow-method-add {
        flex: 0 0 auto;
        display: flex;
        align-items: center;
      }
      .workflow-method-select {
        flex: 1 1 auto;
        min-width: 0;
        display: flex;
        align-items: center;
      }
      .workflow-method-select .shiny-input-container {
        width: 100%;
        margin-bottom: 0;
      }
    "
    ))
  )
}

##' @noRd
##' @export
.mod_Workflow_Server.Project <- function(
    x,
    id,
    ns,
    reactive_workflow,
    reactive_warnings,
    reactive_volumes,
    reactive_update_trigger) {
  shiny::moduleServer(id, function(input, output, session) {
    ns2 <- shiny::NS(id)
    project <- x
    project_type <- class(project)[1]
    param_edit_state <- shiny::reactiveValues()

    get_object_workflow <- function(obj) {
      if (is.null(obj$workflow)) {
        stop(sprintf("Object of class '%s' does not expose project workflow storage.", class(obj)[1]))
      }
      wf <- obj$workflow
      if (is.null(wf)) Workflow() else Workflow(wf)
    }

    set_object_workflow <- function(obj, workflow) {
      workflow <- if (inherits(workflow, "Workflow")) workflow else Workflow(workflow)
      if (is.null(obj$workflow)) {
        stop(sprintf("Object of class '%s' does not expose project workflow storage.", class(obj)[1]))
      }
      obj$workflow <- workflow
      invisible(obj)
    }

    processing_registry <- NULL
    if (!is.null(project$available_processing_methods) && is.function(project$available_processing_methods)) {
      processing_registry <- project$available_processing_methods()
    }

    if (length(processing_registry) == 0) {
      shiny::showNotification(
        paste("No processing methods found for project class", project_type, "!"),
        duration = 5,
        type = "warning"
      )
      processing_methods_short <- NULL
    } else {
      processing_methods_short <- names(processing_registry)
    }

    reactive_selected_method <- shiny::reactiveVal(NULL)
    reactive_workflow_file <- shiny::reactiveVal(NULL)
    reactive_saved_workflow <- shiny::reactiveVal(shiny::isolate(reactive_workflow()))

    output$load_workflow_ui <- shiny::renderUI({
      shinyFiles::shinyFilesButton(
        ns(ns2("load_workflow")),
        "Load Workflow",
        "Select a JSON or RDS file with workflow processing settings",
        multiple = FALSE,
        style = "width: 150px;"
      )
    })

    output$clear_workflow_ui <- shiny::renderUI({
      rw <- reactive_workflow()
      if (length(rw) > 0) {
        shiny::actionButton(
          ns(ns2("clear_workflow")),
          "Clear Workflow",
          width = 150
        )
      }
    })

    output$save_workflow_ui <- shiny::renderUI({
      rw <- reactive_workflow()
      rw_file <- reactive_workflow_file()

      if (length(rw) > 0) {
        shinyFiles::shinyFileSave(
          input,
          "save_workflow",
          roots = reactive_volumes(),
          defaultRoot = "wd",
          session = session
        )

        if (is.null(rw_file)) {
          rw_file <- "workflow.rds"
        }

        if (grepl(".json", rw_file)) {
          extensions <- list(json = "json", rds = "rds")
        } else {
          extensions <- list(rds = "rds", json = "json")
        }

        shinyFiles::shinySaveButton(
          ns(ns2("save_workflow")),
          label = "Save Workflow",
          title = "Save the workflow as .json or .rds",
          filename = gsub(".sqlite|.rds", "", basename(rw_file)),
          filetype = extensions,
          style = "width: 150px;"
        )
      }
    })

    output$persist_workflow_ui <- shiny::renderUI({
      rw <- reactive_workflow()
      saved_rw <- reactive_saved_workflow()
      if (!identical(rw, saved_rw)) {
        shiny::actionButton(
          ns(ns2("persist_workflow")),
          "Save to DB",
          width = 150
        )
      }
    })

    output$discard_changes_ui <- shiny::renderUI({
      rw <- reactive_workflow()
      saved_rw <- reactive_saved_workflow()
      if (!identical(rw, saved_rw)) {
        shiny::actionButton(
          ns(ns2("discard_changes")),
          "Discard Changes",
          class = "btn-danger",
          width = 150
        )
      }
    })

    output$run_workflow_ui <- shiny::renderUI({
      rw <- reactive_workflow()
      saved_rw <- reactive_saved_workflow()
      if (length(rw) > 0 && identical(rw, saved_rw)) {
        shiny::actionButton(
          ns(ns2("run_workflow")),
          "Run Workflow",
          width = 150
        )
      }
    })

    output$workflow_settings <- shiny::renderUI({
      rw <- reactive_workflow()
      labels <- lapply(names(rw), function(i) {
        htmltools::tagList(
          htmltools::div(
            class = "workflow-item",
            shiny::actionButton(
              ns(ns2(paste0("workflow_del_", i))),
              label = shiny::icon("trash"),
              class = "btn btn-danger btn-sm",
              style = "margin-right: 10px;"
            ),
            shiny::span(i),
            shiny::actionButton(
              ns(ns2(paste0("workflow_edit_", i))),
              "Details"
            )
          )
        )
      })

      lapply(names(rw), function(i) {
        shiny::observeEvent(
          input[[paste0("workflow_edit_", i)]],
          {
            reactive_selected_method(i)
          },
          ignoreInit = TRUE
        )
      })

      lapply(names(rw), function(i) {
        shiny::observeEvent(
          input[[paste0("workflow_del_", i)]],
          {
            rw <- reactive_workflow()
            rw <- rw[names(rw) != i]
            rw <- Workflow(rw)
            reactive_workflow(rw)
          },
          ignoreInit = TRUE
        )
      })

      htmltools::div(
        style = "height: calc(100vh - var(--sf-topbar-height) - var(--sf-pad-10) - 10px); overflow: hidden;",
        class = "workflow-box",
      htmltools::div(
        style = "display: flex; flex-direction: column; height: 100%; gap: 5px; min-height: 0;",
        shiny::column(
          width = 12,
          htmltools::div(
            class = "workflow-actions",
            shiny::uiOutput(ns(ns2("load_workflow_ui"))),
            shiny::uiOutput(ns(ns2("save_workflow_ui"))),
            shiny::uiOutput(ns(ns2("clear_workflow_ui"))),
            shiny::uiOutput(ns(ns2("persist_workflow_ui"))),
            shiny::uiOutput(ns(ns2("discard_changes_ui"))),
            shiny::uiOutput(ns(ns2("run_workflow_ui")))
          )
          ),
          shiny::column(
            width = 12,
            htmltools::p(
              "Select Processing Method",
              style = "margin-bottom: 5px; margin-top: 5px;"
            )
          ),
          shiny::column(
            width = 12,
            style = "margin-bottom: 0px;",
            htmltools::div(
              class = "workflow-method-row",
              htmltools::div(
                class = "workflow-method-select",
                shiny::selectInput(
                  ns(ns2("settings_selector")),
                  label = NULL,
                  choices = processing_methods_short,
                  multiple = FALSE,
                  width = "100%"
                )
              ),
              htmltools::div(
                class = "workflow-method-add",
                shiny::actionButton(
                  ns(ns2("add_workflow_step")),
                  "Add Method"
                )
              )
            )
          ),
          shiny::column(
            width = 12,
            class = "workflow-list-shell",
            htmltools::div(
              class = "workflow-list-scroll",
              sortable::rank_list(
                text = "Drag to order",
                labels = labels,
                input_id = ns(ns2("rank_workflow_names"))
              )
            )
          )
        )
      )
    })

    output$selected_method_details <- shiny::renderUI({
      selected_method <- reactive_selected_method()
      rw <- reactive_workflow()
      if (is.null(selected_method)) {
        return(htmltools::div("Please select a method to view details!"))
      }

      shiny::req(selected_method %in% names(rw))
      short_selected_method <- gsub("^\\d+_", "", selected_method)
      idx_selected_method <- gsub("^(\\d+)_.*", "\\1", selected_method)
      settings <- rw[[selected_method]]
      registry_entry <- processing_registry[[short_selected_method]]
      if (is.null(registry_entry)) {
        registry_entry <- settings
      }
      help_url <- NA_character_
      if (!is.null(registry_entry$link) && nzchar(registry_entry$link) && !is.na(registry_entry$link)) {
        help_url <- registry_entry$link
      }
      method_editor_title <- paste0(
        idx_selected_method,
        ": ",
        short_selected_method
      )
      create_parameter_ui <- function(ns2, param_name, param_value) {
        # Coerce list-like tables back to data.frames for CSV params
        if (is.list(param_value) && !is.data.frame(param_value)) {
          possible_df <- tryCatch(
            as.data.frame(param_value, stringsAsFactors = FALSE),
            error = function(...) NULL
          )
          if (!is.null(possible_df) && nrow(possible_df) > 0) {
            param_value <- possible_df
          }
        }

        input_element <- NULL
        if (is.null(param_value)) {
          input_element <- shiny::textInput(
            ns(ns2(param_name)),
            label = NULL,
            value = "",
            width = "100%"
          )
        } else if (is.logical(param_value)) {
          checkbox_value <- if (is.na(param_value)) FALSE else param_value
          input_element <- shiny::checkboxInput(
            ns(ns2(param_name)),
            label = NULL,
            value = checkbox_value
          )
        } else if (is.numeric(param_value)) {
          display_value <- if (length(param_value) > 1) {
            paste(param_value, collapse = " ")
          } else {
            as.character(param_value)
          }
          input_element <- shiny::textInput(
            ns(ns2(param_name)),
            label = NULL,
            value = display_value,
            width = "100%",
            placeholder = "If applicable, enter numbers separated by spaces"
          )
        } else if (is.character(param_value)) {
          input_element <- shiny::textInput(
            ns(ns2(param_name)),
            label = NULL,
            value = param_value,
            width = "100%"
          )
        } else if (is.data.frame(param_value)) {
          pram_load_name <- paste0(selected_method, "_load_", param_name)
          pram_save_name <- paste0(selected_method, "_save_", param_name)
          pram_edit_name <- paste0(selected_method, "_edit_", param_name)
          pram_table_id <- paste0(pram_edit_name, "_table")
          pram_save_edit <- paste0(pram_edit_name, "_save")
          pram_add_row <- paste0(pram_edit_name, "_add_row")
          pram_types <- paste0(pram_edit_name, "_types")

          custom_datatable_str_out <- function(dt, n = 5) {
            output <- paste0(
              "Data Table with ",
              nrow(dt),
              " observations of ",
              ncol(dt),
              " variables:<br>"
            )
            for (col_name in names(dt)) {
              col_type <- class(dt[[col_name]])
              output <- paste0(output, "$ ", col_name, " : ", col_type, "<br>")
            }
            shiny::tags$span(shiny::HTML(output))
          }

          shinyFiles::shinyFileChoose(
            input,
            pram_load_name,
            roots = reactive_volumes(),
            defaultRoot = "wd",
            session = session,
            filetypes = list(csv = "csv")
          )

          shinyFiles::shinyFileSave(
            input,
            pram_save_name,
            roots = reactive_volumes(),
            defaultRoot = "wd",
            session = session
          )

          input_element <- shiny::tags$div(
            shinyFiles::shinyFilesButton(
              ns(ns2(pram_load_name)),
              "Load (.csv)",
              paste0("Select a CSV file for parameter ", param_name),
              multiple = FALSE,
              style = "width: 150px;margin-bottom: 12px;"
            ),
            shinyFiles::shinySaveButton(
              ns(ns2(pram_save_name)),
              label = "Save (.csv)",
              title = paste0("Save as CSV the parameter ", param_name),
              filename = param_name,
              filetype = list(csv = "csv"),
              style = "width: 150px;margin-bottom: 12px;"
            ),
            shiny::actionButton(
              ns(ns2(pram_edit_name)),
              "Edit",
              style = "margin-bottom: 12px; margin-left: 5px;"
            ),
            shiny::tags$br(),
            custom_datatable_str_out(param_value, 5)
          )

          shiny::observeEvent(input[[pram_load_name]], {
            fileinfo <- shinyFiles::parseFilePaths(
              roots = reactive_volumes(),
              input[[pram_load_name]]
            )
            if (nrow(fileinfo) > 0) {
              file <- fileinfo$datapath
              if (length(file) == 1) {
                if (file.exists(file)) {
                  tryCatch(
                    {
                      param_value <- data.table::fread(file)
                      settings$parameters[[param_name]] <- param_value
                      rw[[selected_method]] <- settings
                      reactive_workflow(rw)
                    },
                    error = function(e) {
                      shiny::showNotification(
                        paste("Error loading csv file:", e$message),
                        duration = 5,
                        type = "error"
                      )
                    },
                    warning = function(w) {
                      shiny::showNotification(
                        paste("Warning loading csv file:", w$message),
                        duration = 5,
                        type = "warning"
                      )
                    }
                  )
                } else {
                  shiny::showNotification(
                    "CSV file does not exist!",
                    duration = 5,
                    type = "warning"
                  )
                }
              }
            }
          })

          shiny::observeEvent(input[[pram_save_name]], {
            shiny::req(input[[pram_save_name]])
            file_info <- shinyFiles::parseSavePath(
              roots = reactive_volumes(),
              input[[pram_save_name]]
            )
            if (nrow(file_info) > 0) {
              file_path <- file_info$datapath
              tryCatch(
                {
                  write.csv(param_value, file_path, row.names = FALSE)
                  shiny::showNotification(
                    paste("Parameter saved successfully as ", file_path),
                    duration = 5,
                    type = "message"
                  )
                },
                error = function(e) {
                  shiny::showNotification(
                    paste("Error saving csv:", e$message),
                    duration = 5,
                    type = "error"
                  )
                },
                warning = function(w) {
                  shiny::showNotification(
                    paste("Warning saving csv:", w$message),
                    duration = 5,
                    type = "warning"
                  )
                }
              )
            }
          })

          shiny::observeEvent(input[[pram_edit_name]], {
            param_edit_state[[pram_edit_name]] <- param_value
            param_edit_state[[pram_types]] <- vapply(
              param_value,
              function(col) class(col)[1],
              character(1)
            )
            local_table_id <- pram_table_id
            local_save_id <- pram_save_edit
            local_add_row <- pram_add_row
            local_types_id <- pram_types

            output[[local_table_id]] <- DT::renderDT(
              param_edit_state[[pram_edit_name]],
              editable = TRUE,
              rownames = FALSE,
              options = list(dom = "t", paging = FALSE)
            )

            shiny::observeEvent(input[[paste0(local_table_id, "_cell_edit")]], {
              info <- input[[paste0(local_table_id, "_cell_edit")]]
              df <- param_edit_state[[pram_edit_name]]
              df[info$row, info$col + 1] <- info$value
              param_edit_state[[pram_edit_name]] <- df
            }, ignoreInit = TRUE)

            shiny::showModal(
              shiny::modalDialog(
                title = paste("Edit", param_name),
                DT::dataTableOutput(ns(ns2(local_table_id))),
                footer = shiny::tagList(
                  shiny::actionButton(
                    ns(ns2(local_save_id)),
                    "Save changes"
                  ),
                  shiny::actionButton(
                    ns(ns2(local_add_row)),
                    "Add row"
                  ),
                  shiny::modalButton("Cancel")
                ),
                size = "l",
                easyClose = FALSE
              )
            )
          }, ignoreInit = TRUE)

          shiny::observeEvent(input[[pram_add_row]], {
            df <- param_edit_state[[pram_edit_name]]
            if (is.null(df)) {
              return()
            }
            df[nrow(df) + 1, names(df)] <- NA
            param_edit_state[[pram_edit_name]] <- df
          }, ignoreInit = TRUE)

          shiny::observeEvent(input[[pram_save_edit]], {
            df <- param_edit_state[[pram_edit_name]]
            col_types <- param_edit_state[[pram_types]]
            if (!is.null(col_types)) {
              for (col_name in names(df)) {
                target_type <- col_types[[col_name]]
                if (is.null(target_type)) next
                df[[col_name]] <- switch(target_type,
                  integer = suppressWarnings(as.integer(df[[col_name]])),
                  numeric = suppressWarnings(as.numeric(df[[col_name]])),
                  double = suppressWarnings(as.numeric(df[[col_name]])),
                  logical = suppressWarnings(as.logical(df[[col_name]])),
                  character = as.character(df[[col_name]]),
                  factor = {
                    lvls <- levels(param_value[[col_name]])
                    factor(as.character(df[[col_name]]), levels = lvls)
                  },
                  ordered = {
                    lvls <- levels(param_value[[col_name]])
                    factor(as.character(df[[col_name]]), levels = lvls, ordered = TRUE)
                  },
                  df[[col_name]]
                )
              }
            }
            settings$parameters[[param_name]] <- df
            validation_issue <- tryCatch(
              {
                validate_object(settings)
                NULL
              },
              error = function(e) e,
              warning = function(w) w
            )
            if (inherits(validation_issue, "condition")) {
              shiny::showNotification(
                paste("Validation failed:", validation_issue$message),
                duration = 5,
                type = "error"
              )
              return()
            }
            rw[[selected_method]] <- settings
            reactive_workflow(rw)
            shiny::removeModal()
            shiny::showNotification("Parameter updated.", type = "message")
          }, ignoreInit = TRUE)
        } else {
          input_element <- shiny::tags$p(paste(
            "Unsupported parameter type: ",
            class(param_value)
          ))
        }

        shiny::div(
          style = "display: flex; align-items: center;border-bottom: 1px solid #ccc;",
          shiny::tags$dt(shiny::tags$strong(param_name)),
          shiny::tags$dd(input_element)
        )
      }

      param_names <- names(settings$parameters)

      htmltools::div(
        style = "height: calc(100vh - var(--sf-topbar-height) - var(--sf-pad-10) - 10px); overflow: hidden;",
        class = "method-box",
        htmltools::div(
          style = "height: calc(100vh - var(--sf-topbar-height) - var(--sf-pad-10) - 20px); overflow-y: auto; padding: 5px; width: calc(100% - 5px);",
          shiny::tags$div(
            class = "method-details",
            shiny::h3(method_editor_title, style = "margin-top: 0px; margin-bottom: 10px;"),
            shiny::tags$div(
              shiny::tags$b("Owner Class: "),
              shiny::tags$span(settings$owner_class),
              shiny::tags$br(),
              shiny::tags$b("Developer: "),
              shiny::tags$span(settings$developer),
              shiny::tags$br(),
              shiny::tags$b("Contact: "),
              shiny::tags$span(settings$contact),
              shiny::tags$br(),
              shiny::tags$b("Link: "),
              shiny::tags$span(settings$link),
              shiny::tags$br(),
              shiny::tags$b("DOI: "),
              shiny::tags$span(settings$doi)
            ),
            if (!is.na(help_url)) {
              shiny::tags$div(
                style = "margin-top: 5px;margin-bottom: 5px;",
                shiny::tags$a(
                  href = help_url,
                  target = "_blank",
                  "View Online Reference Page",
                  style = "color: #3498DB; text-decoration: underline; cursor: pointer; font-size: 14px;"
                )
              )
            } else {
              shiny::tags$div(
                style = "margin-top: 5px;margin-bottom: 5px;",
                "No help documentation available."
              )
            },
            shiny::actionButton(
              ns(ns2("open_help_modal")),
              "Help",
              style = "margin-top: 10px; margin-bottom: 10px"
            ),
            shiny::actionButton(
              ns(ns2("update_method")),
              "Update Parameters",
              style = "margin-top: 10px; margin-bottom: 10px"
            ),
            shiny::actionButton(
              ns(ns2("reset_method")),
              "Reset Parameters",
              style = "margin-top: 10px; margin-bottom: 10px"
            ),
            shiny::tags$div(
              class = "parameters-section",
              shiny::tags$dl(
                lapply(param_names, function(param) {
                  create_parameter_ui(ns2, param, settings$parameters[[param]])
                })
              )
            )
          )
        )
      )
    })

    shiny::observe({
      rw <- reactive_workflow()
      if (length(rw) == 0) {
        reactive_selected_method(NULL)
      } else if (is.null(reactive_selected_method()) || !reactive_selected_method() %in% names(rw)) {
        reactive_selected_method(names(rw)[1])
      }
    })

    shiny::observeEvent(input$rank_workflow_names, {
      rw <- reactive_workflow()
      new_order <- input$rank_workflow_names
      new_order <- unname(vapply(
        new_order,
        function(z) {
          res <- tryCatch({
            parts <- as.character(z)
            parts <- unlist(strsplit(parts, "\n"))
            parts <- parts[nzchar(parts)] # drop empty lines to avoid zero-length
            if (length(parts) >= 2) {
              parts[2]
            } else if (length(parts) >= 1) {
              parts[1]
            } else {
              NA_character_
            }
          }, error = function(...) NA_character_)
          if (length(res) == 0) NA_character_ else res[[1]]
        },
        character(1),
        USE.NAMES = FALSE
      ))
      new_order <- new_order[!is.na(new_order) & nzchar(new_order)]
      new_order <- new_order[new_order %in% names(rw)]
      if (length(new_order) == 0) {
        return()
      }

      withCallingHandlers(
        {
          rw[seq_along(new_order)] <- rw[new_order]
          reactive_workflow(rw)
        },
        error = function(e) {
          shiny::showNotification(
            paste("Error ranking workflow:", e$message),
            duration = 5,
            type = "error"
          )
        },
        warning = function(w) {
          shiny::showNotification(
            paste("Warning ranking workflow:", w$message),
            duration = 5,
            type = "warning"
          )
        }
      )
    })

    shinyFiles::shinyFileChoose(
      input,
      "load_workflow",
      roots = .app_util_get_volumes(),
      defaultRoot = "wd",
      session = session,
      filetypes = list(json = "json", rds = "rds")
    )
    shiny::observeEvent(input$load_workflow, {
      rw <- reactive_workflow()
      fileinfo <- shinyFiles::parseFilePaths(
        roots = reactive_volumes(),
        input$load_workflow
      )
      if (nrow(fileinfo) > 0) {
        file <- fileinfo$datapath
        if (length(file) == 1) {
          if (file.exists(file)) {
            tryCatch(
              {
                rw <- read(rw, file)
                reactive_workflow(rw)
              },
              error = function(e) {
                shiny::showNotification(
                  paste("Error loading workflow:", e$message),
                  duration = 5,
                  type = "error"
                )
              },
              warning = function(w) {
                shiny::showNotification(
                  paste("Warning loading workflow:", w$message),
                  duration = 5,
                  type = "warning"
                )
              }
            )
          } else {
            shiny::showNotification(
              "File does not exist!",
              duration = 5,
              type = "warning"
            )
          }
        }
      }
    })

    shiny::observeEvent(input$clear_workflow, {
      reactive_workflow(Workflow())
      reactive_selected_method(NULL)
    })

    shiny::observeEvent(input$save_workflow, {
      shiny::req(input$save_workflow)
      file_info <- shinyFiles::parseSavePath(
        roots = reactive_volumes(),
        input$save_workflow
      )
      if (nrow(file_info) > 0) {
        file_path <- file_info$datapath
        tryCatch(
          {
            rw <- reactive_workflow()
            save(rw, file_path)
            reactive_workflow_file(file_path)
            shiny::showNotification(
              paste("Workflow saved successfully as ", file_path),
              duration = 5,
              type = "message"
            )
          },
          error = function(e) {
            shiny::showNotification(
              paste("Error saving workflow:", e$message),
              duration = 5,
              type = "error"
            )
          },
          warning = function(w) {
            shiny::showNotification(
              paste("Warning saving workflow:", w$message),
              duration = 5,
              type = "warning"
            )
          }
        )
      }
    })

    shiny::observeEvent(input$persist_workflow, {
      rw <- reactive_workflow()
      tryCatch(
        {
          set_object_workflow(project, rw)
          saved_workflow <- get_object_workflow(project)
          reactive_workflow(saved_workflow)
          reactive_saved_workflow(saved_workflow)
          reactive_update_trigger(reactive_update_trigger() + 1)
          shiny::showNotification("Workflow saved to database.", type = "message")
        },
        error = function(e) {
          shiny::showNotification(
            paste("Error saving workflow to database:", e$message),
            duration = 5,
            type = "error"
          )
        },
        warning = function(w) {
          shiny::showNotification(
            paste("Warning saving workflow to database:", w$message),
            duration = 5,
            type = "warning"
          )
        }
      )
    })

    shiny::observeEvent(input$discard_changes, {
      shiny::req(input$discard_changes)
      reactive_workflow(reactive_saved_workflow())
    })

    shiny::observeEvent(input$run_workflow, {
      shiny::req(input$run_workflow)
      shiny::showModal(shiny::modalDialog(
        title = "Processing",
        "The workflow is running. Please wait...",
        footer = NULL
      ))
      tryCatch(
        {
          set_object_workflow(project, reactive_workflow())
          if (!is.null(project$run_workflow) && is.function(project$run_workflow)) {
            project$run_workflow()
          } else {
            stop(sprintf("Object of class '%s' does not implement run_workflow().", class(project)[1]))
          }
          saved_workflow <- get_object_workflow(project)
          reactive_workflow(saved_workflow)
          reactive_saved_workflow(saved_workflow)
          reactive_update_trigger(reactive_update_trigger() + 1)
          shiny::removeModal()
        },
        error = function(e) {
          shiny::showNotification(
            paste("Error running workflow:", e$message),
            duration = 5,
            type = "error"
          )
          shiny::removeModal()
        }
      )
    })

    shiny::observeEvent(input$add_workflow_step, {
      rw <- reactive_workflow()
        settings_name <- input$settings_selector
      if (length(settings_name) > 0) {
        settings <- processing_registry[[settings_name]]
        tryCatch(
          {
            rw[[length(rw) + 1]] <- settings
            names(rw)[length(rw)] <- paste0(length(rw), "_", settings$method)
            rw <- Workflow(rw)
            reactive_workflow(rw)
          },
          error = function(e) {
            shiny::showNotification(
              paste("Error adding workflow step:", e$message),
              duration = 5,
              type = "error"
            )
          },
          warning = function(w) {
            shiny::showNotification(
              paste("Warning adding workflow step:", w$message),
              duration = 5,
              type = "warning"
            )
          }
        )
      }
    })

    shiny::observeEvent(input$open_help_modal, {
      shiny::req(reactive_selected_method())
      rw <- reactive_workflow()
      selected_method <- reactive_selected_method()
      shiny::req(selected_method %in% names(rw))
      settings <- rw[[selected_method]]
      tryCatch(
        {
          parameter_items <- lapply(names(settings$parameters), function(param_name) {
            value <- settings$parameters[[param_name]]
            value_type <- class(value)[1]
            shiny::tags$li(
              shiny::tags$b(param_name),
              paste0(" (", value_type, ")")
            )
          })

          help_page <- htmltools::tagList(
            htmltools::h3(settings$method),
            htmltools::tags$div(
              htmltools::tags$b("Project Method: "),
              htmltools::tags$code(settings$method)
            ),
            htmltools::tags$div(
              htmltools::tags$b("Owner Class: "),
              htmltools::tags$code(settings$owner_class)
            ),
            htmltools::tags$div(
              style = "margin-top: 10px;",
              htmltools::tags$b("Parameters"),
              htmltools::tags$ul(parameter_items)
            )
          )

          shiny::showModal(
            shiny::modalDialog(
              title = NULL,
              size = "l",
              help_page,
              easyClose = TRUE,
              footer = NULL
            )
          )
        },
        error = function(e) {
            shiny::showNotification(
              paste("Error getting method metadata:", e$message),
              duration = 5,
              type = "error"
            )
          return()
        },
        warning = function(w) {
            shiny::showNotification(
              paste("Warning getting method metadata:", w$message),
              duration = 5,
              type = "warning"
            )
          return()
        }
      )
    })

    shiny::observeEvent(input$update_method, {
      shiny::req(input$update_method)
      rw <- reactive_workflow()
      selected_method <- reactive_selected_method()
      shiny::req(selected_method %in% names(rw))
      settings <- rw[[selected_method]]

      tryCatch(
        {
          param_names <- names(settings$parameters)
          for (param_name in param_names) {
            tryCatch(
              {
                param_class <- class(settings$parameters[[param_name]])
                if ("logical" %in% param_class) {
                  value <- as.logical(input[[param_name]])
                  if (length(value) == 0) {
                    value <- as.logical(NA)
                  }
                  settings$parameters[[param_name]] <- as.logical(value)
                } else if ("numeric" %in% param_class) {
                  input_value <- input[[param_name]]
                  if (is.null(input_value) || input_value == "") {
                    value <- as.numeric(NA_real_)
                  } else {
                    value_parts <- trimws(strsplit(input_value, "\\s+")[[1]])
                    value_parts <- value_parts[value_parts != ""]
                    if (length(value_parts) == 0) {
                      value <- as.numeric(NA_real_)
                    } else {
                      value <- as.numeric(value_parts)
                    }
                  }
                  settings$parameters[[param_name]] <- value
                } else if ("character" %in% param_class) {
                  value <- as.character(input[[param_name]])
                  if (length(value) == 0) {
                    value <- as.character(NA_character_)
                  }
                  settings$parameters[[param_name]] <- as.character(value)
                } else if ("integer" %in% param_class) {
                  value <- as.integer(input[[param_name]])
                  if (length(value) == 0) {
                    value <- as.integer(NA_integer_)
                  }
                  settings$parameters[[param_name]] <- as.integer(value)
                } else if ("data.frame" %in% param_class) {
                  next
                } else if (param_class == "NULL") {
                  shiny::showNotification(
                    paste("Parameter ", param_name, " is NULL"),
                    duration = 5,
                    type = "warning"
                  )
                } else {
                  shiny::showNotification(
                    paste("Unsupported parameter type for ", param_name),
                    duration = 5,
                    type = "warning"
                  )
                }
              },
              error = function(e) {
                shiny::showNotification(
                  paste(
                    "Error getting parameter ",
                    param_name,
                    " value:",
                    e$message
                  ),
                  duration = 5,
                  type = "error"
                )
              },
              warning = function(w) {
                shiny::showNotification(
                  paste(
                    "Warning getting parameter ",
                    param_name,
                    " value:",
                    w$message
                  ),
                  duration = 5,
                  type = "warning"
                )
              }
            )
          }

          # Validate settings before updating
          validation_issue <- validate_object(settings)
          if (!is.null(validation_issue)) {
            stop(validation_issue)
          }

          rw[[selected_method]] <- settings
          reactive_workflow(rw)
          shiny::showNotification(
            "Settings updated successfully!",
            type = "message"
          )
        },
        error = function(e) {
          shiny::showNotification(
            paste("Validation failed:", e$message),
            duration = 10,
            type = "error"
          )
        },
        warning = function(w) {
          shiny::showNotification(
            paste("Warning:", w$message),
            duration = 10,
            type = "warning"
          )
        }
      )
    })

    shiny::observeEvent(input$reset_method, {
      rw <- reactive_workflow()
      selected_method <- reactive_selected_method()
      shiny::req(selected_method %in% names(rw))
      short_selected_method <- gsub("^\\d+_", "", selected_method)
      settings <- processing_registry[[short_selected_method]]
      rw[[selected_method]] <- settings
      reactive_workflow(rw)
      shiny::showNotification("Settings reset successfully!", type = "message")
    })
  })
}
