##' @noRd
##' @export
.mod_Analyses_UI.ProjectMassSpec <- function(x, id, ns) {
  ns2 <- shiny::NS(id)
  htmltools::div(
    style = "height: calc(100vh - var(--sf-topbar-height) - var(--sf-pad-10)); overflow: hidden;",
    shiny::column(12, shiny::uiOutput(ns(ns2("analyses_overview_buttons")))),
    shiny::column(12, shiny::uiOutput(ns(ns2("notes_analyses")))),
    shiny::column(12, DT::dataTableOutput(ns(ns2("AnalysesTable"))), height = "calc(100vh - var(--sf-topbar-height) - var(--sf-pad-10) - 38px - 69px)")
  )
}

##' @noRd
##' @export
.mod_Analyses_Server.ProjectMassSpec <- function(
    x,
    id,
    ns,
    reactive_update_cache_size,
    reactive_analyses,
    reactive_warnings,
    reactive_volumes) {
  shiny::moduleServer(id, function(input, output, session) {
    ns2 <- shiny::NS(id)

    analyses_obj <- shiny::isolate(reactive_analyses())
    reactive_analyses_info <- shiny::reactiveVal(info(analyses_obj))
    project_details <- projects_overview(class(analyses_obj)[1])

    # Register shinyFileChoose once (must be outside renderUI) -----
    vol_cfg <- .app_util_get_volumes()
    shinyFiles::shinyFileChoose(
      input,
      "add_analyses_button",
      roots = vol_cfg$volumes,
      defaultRoot = vol_cfg$default_root,
      session = session,
      filetypes = project_details$formats
    )
    shinyFiles::shinyFileChoose(
      input,
      "upload_analyses_info",
      roots = vol_cfg$volumes,
      defaultRoot = vol_cfg$default_root,
      session = session,
      filetypes = "csv"
    )

    # out Analyses Table -----
    output$AnalysesTable <- DT::renderDT(
      {
        analyses_info <- reactive_analyses_info()
        if (nrow(analyses_info) > 0) {
          analyses_info$Delete <- paste0('<button class="btn btn-danger btn-sm delete-btn" data-row="', seq_len(nrow(analyses_info)), '"><i class="fa fa-trash"></i></button>')
        } else {
          analyses_info$Delete <- character(0)
        }
        blocked_columns <- seq_len(ncol(analyses_info)) - 1
        blocked_columns <- blocked_columns[!colnames(analyses_info) %in% c("replicate", "blank", "concentration")]

        DT::datatable(
          analyses_info,
          rownames = FALSE,
          editable = list(
            target = "cell",
            disable = list(
              columns = blocked_columns
            )
          ),
          selection = "none",
          escape = FALSE, # Allow HTML in the Delete column
          callback = DT::JS(paste0("
            table.on('click', '.delete-btn', function() {
              var row = $(this).data('row');
              var timestamp = Date.now();
              Shiny.setInputValue('", session$ns("delete_row"), "', row + '_' + timestamp, {priority: 'event'});
            });
          ")),
          extensions = c("Buttons"),
          options = list(
            searching = TRUE,
            processing = TRUE,
            scrollY = "calc(100vh - var(--sf-topbar-height) - var(--sf-pad-10) - 38px - 69px - var(--sf-dt-chrome))",
            scrollX = TRUE,
            scrollCollapse = TRUE,
            paging = FALSE,
            dom = "Bfrt",
            buttons = c("copy", "csv", "pdf", "print"),
            orderable = FALSE,
            columnDefs = list(
              list(orderable = FALSE, targets = seq_len(ncol(analyses_info)) - 1), # Make Delete column non-sortable
              list(width = "60px", targets = ncol(analyses_info) - 1) # Set width for Delete column
            )
          ),
          class = "cell-border stripe"
        )
      },
      server = TRUE
    )

    # Delete row ----
    observeEvent(input$delete_row,
      {
        delete_info <- input$delete_row
        row_to_delete <- as.numeric(strsplit(delete_info, "_")[[1]][1])
        analyses <- reactive_analyses()
        analyses_info <- reactive_analyses_info()
        if (!is.na(row_to_delete) && row_to_delete > 0 && row_to_delete <= nrow(analyses_info)) {
          analyses_to_remove <- analyses_info$analysis[row_to_delete]
          analyses <- remove_analyses(analyses, analyses_to_remove)
          reactive_analyses_info(info(analyses))
          reactive_update_cache_size(reactive_update_cache_size() + 1)
        }
      },
      ignoreInit = TRUE
    )

    # event Analyses Table Editing -----
    shiny::observeEvent(input$AnalysesTable_cell_edit, {
      analyses <- reactive_analyses()
      analyses_info <- reactive_analyses_info()
      analyses_info <- DT::editData(
        analyses_info,
        input$AnalysesTable_cell_edit,
        rownames = FALSE
      )

      replicate_values <- as.character(analyses_info$replicate)
      replicate_values[is.na(replicate_values)] <- ""
      set_replicate_names(analyses, replicate_values)

      blank_values <- as.character(analyses_info$blank)
      blank_values[blank_values %in% ""] <- NA_character_

      # Handle concentration updates
      if ("concentration" %in% colnames(analyses_info)) {
        # Convert concentration to numeric, handling empty strings and invalid values
        analyses_info$concentration[analyses_info$concentration %in% ""] <- NA_character_
        concentration_numeric <- suppressWarnings(as.numeric(analyses_info$concentration))

        # Check for invalid numeric conversions
        if (any(is.na(concentration_numeric) & !is.na(analyses_info$concentration))) {
          reactive_warnings(
            .app_util_add_notifications(
              reactive_warnings(),
              "invalid_concentration_values",
              "Concentration values must be numeric!"
            )
          )
        } else {
          reactive_warnings(
            .app_util_remove_notifications(
              reactive_warnings(),
              "invalid_concentration_values"
            )
          )
          set_concentrations(analyses, concentration_numeric)
        }
      }

      if (any(!(blank_values %in% replicate_values) & !is.na(blank_values))) {
        reactive_warnings(
          .app_util_add_notifications(
            reactive_warnings(),
            "blank_names_not_in_replicate",
            "Blank names must be in the replicate column!"
          )
        )
      } else {
        reactive_warnings(
          .app_util_remove_notifications(
            reactive_warnings(),
            "blank_names_not_in_replicate"
          )
        )
        blank_values_setter <- blank_values
        blank_values_setter[is.na(blank_values_setter)] <- ""
        set_blank_names(analyses, blank_values_setter)
      }
      reactive_analyses_info(info(analyses))
      reactive_analyses(analyses)
    })

    # out Analyses Overview Buttons -----
    output$analyses_overview_buttons <- shiny::renderUI({
      if (length(reactive_analyses()) > 0) {
        htmltools::div(
          style = "margin-bottom: 5px;",
           shinyFiles::shinyFilesButton(
             ns(ns2("add_analyses_button")),
             "Add Analyses",
             paste0(
               "Select Analyses (",
               paste(project_details$formats, collapse = "|"),
               ")"
             ),
             multiple = TRUE,
             style = "width: 200px;"
           ),
           shiny::actionButton(
             ns(ns2("remove_all_analyses")),
             label = "Delete All Analyses",
             width = 200
           )
         )
       } else {
         htmltools::div(
           style = "margin-bottom: 5px;",
           shinyFiles::shinyFilesButton(
             ns(ns2("add_analyses_button")),
             "Add Analyses",
             paste0(
               "Select Analyses (",
               paste(project_details$formats, collapse = "|"),
               ")"
             ),
             multiple = TRUE,
             style = "width: 200px;"
           )
         )
      }
    })

    # event Add analyses -----
    shiny::observeEvent(input$add_analyses_button, {
      fileinfo <- shinyFiles::parseFilePaths(
        reactive_volumes(),
        input$add_analyses_button
      )
      if (nrow(fileinfo) > 0) {
        files <- fileinfo$datapath
        number_files <- length(files)
        if (number_files > 0) {
          if (
            all(
              tools::file_ext(files) %in% project_details$formats
            )
          ) {
            analyses <- reactive_analyses()

            output$loading_spinner <- shiny::renderUI({
              htmltools::div(style = "height: 100px; width: 100px;")
            })

            shiny::withProgress(message = "Loading files...", value = 0, {
              for (i in seq_len(number_files)) {
                tryCatch(
                  {
                    add_analyses(analyses, files[i])
                  },
                  error = function(e) {
                    msg <- paste(
                      "Error for",
                      files[i],
                      ":",
                      conditionMessage(e)
                    )
                    shiny::showNotification(msg, duration = 10, type = "error")
                  }
                )
                shiny::incProgress(i / number_files)
              }
            })

            output$loading_spinner <- shiny::renderUI({
              NULL
            })

            reactive_analyses_info(info(analyses))
            reactive_update_cache_size(reactive_update_cache_size() + 1)
          } else {
            shiny::showNotification(
              "Invalid file/s format/s!",
              duration = 10,
              type = "warning"
            )
          }
        }
      }
    })

    # event Remove all analyses -----
    shiny::observeEvent(input$remove_all_analyses, {
      analyses <- reactive_analyses()
      if (nrow(info(analyses)) == 0) {
        shiny::showNotification(
          "No analyses found!",
          duration = 10,
          type = "warning"
        )
        return()
      }
      analyses <- remove_analyses(analyses, seq_len(length(analyses)))
      reactive_analyses(analyses)
      reactive_analyses_info(info(analyses))
    })

    # out Notes Analyses -----
    output$notes_analyses <- shiny::renderUI({
      shiny::div(
        style = "margin-bottom: 5px; margin-top: 0px;",
        shiny::tags$ul(
          class = "sf-info-list",
          shiny::tags$li(
            class = "sf-info-text",
            shiny::tags$i(class = "fa fa-info-circle"),
            sprintf(
              "Analyses can be added in the following formats: %s.",
              paste(project_details$formats, collapse = ", ")
            )
          ),
          shiny::tags$li(
            class = "sf-info-text",
            shiny::tags$i(class = "fa fa-info-circle"),
            "Replicate and blank names can be edited in the table by double clicking the cell."
          ),
          shiny::tags$li(
            class = "sf-info-text",
            shiny::tags$i(class = "fa fa-info-circle"),
            "Note that blank names must be in the replicate column otherwise are not considered as blanks."
          )
        )
      )
    })
  })
}

##' @noRd
##' @export
.mod_Analyses_UI.ProjectNonTargetAnalysis <- .mod_Analyses_UI.ProjectMassSpec

##' @noRd
##' @export
.mod_Analyses_Server.ProjectNonTargetAnalysis <- .mod_Analyses_Server.ProjectMassSpec

##' @noRd
##' @export
.mod_Analyses_UI.ProjectMassSpecSpectra <- .mod_Analyses_UI.ProjectMassSpec

##' @noRd
##' @export
.mod_Analyses_Server.ProjectMassSpecSpectra <- .mod_Analyses_Server.ProjectMassSpec

##' @noRd
##' @export
.mod_Analyses_UI.ProjectMassSpecChromatograms <- .mod_Analyses_UI.ProjectMassSpec

##' @noRd
##' @export
.mod_Analyses_Server.ProjectMassSpecChromatograms <- .mod_Analyses_Server.ProjectMassSpec
