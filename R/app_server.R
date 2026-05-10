#' The application server-side
#'
#' @param input,output,session Internal parameters for {shiny}.
#'
#' @noRd
app_server <- function(input, output, session) {
  volumes <- .app_util_get_volumes()
  project_obj <- NULL

  reactive_project_class <- shiny::reactiveVal(NA_character_)
  reactive_project_db <- shiny::reactiveVal(NA_character_)
  reactive_project_id <- shiny::reactiveVal(NA_character_)
  reactive_show_init_modal <- shiny::reactiveVal(FALSE)

  .init_project_db <- golem::get_golem_options("db")
  .init_project_id <- golem::get_golem_options("project_id")
  .init_project_class <- golem::get_golem_options("project_class")
  if (!is.null(.init_project_db) && !is.na(.init_project_db) && file.exists(.init_project_db)) {
    reactive_project_db(.init_project_db)
  }
  if (!is.null(.init_project_id) && !is.na(.init_project_id) && nzchar(.init_project_id)) {
    reactive_project_id(.init_project_id)
  }
  if (!is.null(.init_project_class) && !is.na(.init_project_class) && nzchar(.init_project_class)) {
    reactive_project_class(.init_project_class)
  }

  reactive_warnings <- shiny::reactiveVal(list())
  reactive_volumes <- shiny::reactiveVal(volumes)
  reactive_metadata <- shiny::reactiveVal(NULL)
  reactive_analyses <- shiny::reactiveVal(NULL)
  reactive_workflow <- shiny::reactiveVal(NULL)
  reactive_results <- shiny::reactiveVal(NULL)
  reactive_audit <- shiny::reactiveVal(NULL)
  reactive_app_mode <- shiny::reactiveVal(NA_character_)
  reactive_update_trigger <- shiny::reactiveVal(0)

  public_project_label <- function(project_class) {
    switch(
      project_class,
      ProjectMassSpecSpectra = "Mass Spec Spectra",
      ProjectMassSpecChromatograms = "Mass Spec Chromatograms",
      ProjectNonTargetAnalysis = "Non-Target Analysis",
      project_class
    )
  }

  make_module_id <- function(prefix, project_class = NA_character_, project_db = NA_character_, project_id = NA_character_) {
    if (is.null(project_class) || is.na(project_class)) project_class <- ""
    if (is.null(project_db) || is.na(project_db)) project_db <- ""
    if (is.null(project_id) || is.na(project_id)) project_id <- ""
    key <- paste(prefix, project_class, project_db, project_id, sep = "_")
    key <- gsub("[^A-Za-z0-9_]+", "_", key)
    key <- gsub("_+", "_", key)
    key
  }

  load_project_object <- function(project_class, db, project_id) {
    ctor <- get0(project_class, envir = asNamespace("StreamFind"), inherits = FALSE)
    if (is.null(ctor) || !inherits(ctor, "R6ClassGenerator")) {
      stop("Project class not found: ", project_class)
    }
    suppressMessages(ctor$new(db = db, project_id = project_id))
  }

  get_project_results <- function(project) {
    if (inherits(project, "ProjectNonTargetAnalysis")) {
      return(list(ProjectNonTargetAnalysis = project))
    }
    list()
  }

  output$app_mode_ui <- shiny::renderUI({
    shiny::tags$span("StreamFind")
  })

  output$notifications_ui <- shiny::renderUI({
    warnings <- reactive_warnings()
    count <- length(warnings)
    bell_btn <- htmltools::tags$button(
      class = "sf-topbar-btn",
      onclick = "var dd = document.getElementById('sf-notif-dropdown'); if(dd) dd.classList.toggle('open');",
      title = "Notifications",
      shiny::icon("bell"),
      if (count > 0) htmltools::tags$span(class = "sf-notif-count visible", count)
    )
    items <- if (count == 0) {
      htmltools::div(class = "sf-notif-empty", "No notifications")
    } else {
      lapply(warnings, function(w) htmltools::div(class = "sf-notif-item", w))
    }
    htmltools::div(
      class = "sf-notif-wrapper",
      bell_btn,
      htmltools::div(
        id = "sf-notif-dropdown",
        class = "sf-notif-dropdown",
        items
      )
    )
  })

  shiny::observeEvent(input$theme_toggle, {
    session$sendCustomMessage("toggleTheme", list())
  })

  shiny::observeEvent(input$settings_button, {
    shiny::showModal(shiny::modalDialog(
      title = "Settings",
      easyClose = TRUE,
      footer = shiny::modalButton("Close"),
      htmltools::div(
        class = "sf-settings-modal",
        htmltools::tags$h4("Appearance"),
        shiny::actionButton(
          "theme_toggle",
          label = "Toggle Light / Dark Mode",
          icon = shiny::icon("circle-half-stroke"),
          class = "btn-primary"
        ),
        htmltools::tags$hr(),
        htmltools::tags$p(
          class = "sf-settings-note",
          "Additional configuration options can be added here later."
        )
      )
    ))
  })

  shiny::observeEvent(list(reactive_project_class(), reactive_project_db(), reactive_project_id()), {
    project_class <- reactive_project_class()
    project_db <- reactive_project_db()
    project_id <- reactive_project_id()
    shiny::req(!is.na(project_class), !is.na(project_db), !is.na(project_id), file.exists(project_db), nzchar(project_id))
    session$sendCustomMessage("setBootOverlay", list(visible = TRUE))

    tryCatch(
      {
        project_obj <<- load_project_object(project_class, project_db, project_id)
        reactive_metadata(project_obj$metadata)
        reactive_analyses(project_obj)
        reactive_workflow(Workflow(project_obj$workflow %||% list()))
        reactive_audit(project_obj$get_audit())
        reactive_results(get_project_results(project_obj))
        reactive_app_mode("Project")

        session$onFlushed(function() {
          session$sendCustomMessage("setBootOverlay", list(visible = FALSE))
        }, once = TRUE)
      },
      error = function(e) {
        session$sendCustomMessage("setBootOverlay", list(visible = FALSE))
        shiny::showNotification(
          paste("Error loading project:", conditionMessage(e)),
          duration = 10,
          type = "error"
        )
      }
    )
  }, ignoreInit = FALSE)

  shiny::observeEvent(reactive_update_trigger(), {
    if (!is.null(project_obj)) {
      reactive_metadata(project_obj$metadata)
      reactive_analyses(project_obj)
      reactive_workflow(Workflow(project_obj$workflow %||% list()))
      reactive_audit(project_obj$get_audit())
      reactive_results(get_project_results(project_obj))
    }
  })

  output$project_ui <- shiny::renderUI({
    htmltools::div(
      style = "height: calc(100vh - 35px); display: flex; flex-direction: column; overflow: hidden;",
      htmltools::div(
        style = "flex: 0 0 auto; padding: 8px 10px;",
        shiny::uiOutput("project_control_ui")
      ),
      htmltools::div(
        style = "flex: 1; overflow: hidden; padding: 0 10px 8px;",
        shiny::uiOutput("metadata_ui")
      )
    )
  })

  output$project_control_ui <- shiny::renderUI({
    project_db <- reactive_project_db()
    project_id <- reactive_project_id()
    project_class <- reactive_project_class()
    htmltools::div(
      htmltools::div(
        style = "display: flex; align-items: center; gap: 12px; font-size: 12px; flex-wrap: nowrap;",
        htmltools::div(
          style = "flex-shrink: 0;",
          htmltools::strong("Project DB: "),
          htmltools::span(project_db, style = "word-break: break-all;")
        ),
        htmltools::div(
          style = "flex-shrink: 0;",
          htmltools::strong("Project ID: "),
          htmltools::span(project_id)
        ),
        htmltools::div(
          style = "flex-shrink: 0; margin-left: auto;",
          htmltools::span(public_project_label(project_class), class = "sf-cache-label")
        )
      )
    )
  })

  metadata_dt <- shiny::reactiveVal()

  shiny::observe({
    tryCatch(
      {
        meta <- reactive_metadata()
        if (!is.null(meta)) {
          dt <- data.table::as.data.table(meta)
          data.table::setnames(dt, c("Name", "Value"))
          metadata_dt(dt)
        }
      },
      error = function(e) message("Error initializing metadata: ", e)
    )
  })

  output$update_metadata_ui <- shiny::renderUI({
    dt <- metadata_dt()
    if (!is.null(dt)) {
      htmltools::div(
        style = "display: flex; gap: 10px;",
        shiny::actionButton("update_metadata", "Update Metadata"),
        shiny::actionButton("discard_changes", "Discard Changes", class = "btn-danger")
      )
    }
  })

  output$metadata_ui <- shiny::renderUI({
    htmltools::div(
      style = "display: flex; flex-direction: column; height: 100%; overflow: hidden;",
      htmltools::div(
        style = "flex: 0 0 auto; display: flex; gap: 10px; align-items: center; padding: 0 0 4px 0;",
        shiny::actionButton("add_row", "Add New Row", class = "btn-light"),
        shiny::uiOutput("update_metadata_ui")
      ),
      htmltools::div(
        class = "sf-info-text",
        style = "flex: 0 0 auto; padding: 2px 0 4px 0;",
        shiny::HTML("<i class='fa fa-info-circle'></i> Double-click on any cell to edit its value")
      ),
      htmltools::div(
        style = "flex: 1; overflow: hidden;",
        DT::DTOutput("metadata_dt")
      )
    )
  })

  output$metadata_dt <- DT::renderDT({
    dt_display <- metadata_dt()
    if (!is.null(dt_display) && nrow(dt_display) > 0) {
      dt_display$Delete <- paste0(
        '<button class="btn btn-danger btn-sm delete-btn" data-row="',
        seq_len(nrow(dt_display)), '"><i class="fa fa-trash"></i></button>'
      )
    }
    DT::datatable(
      dt_display,
      rownames = FALSE,
      editable = list(target = "cell", disable = list(columns = c(2))),
      selection = "none",
      escape = FALSE,
      callback = DT::JS(paste0(
        "table.on('click', '.delete-btn', function() {",
        "var row = $(this).data('row');",
        "var timestamp = Date.now();",
        "Shiny.setInputValue('delete_row', row + '_' + timestamp, {priority: 'event'});",
        "});"
      )),
      options = list(
        searching = TRUE,
        processing = TRUE,
        paging = FALSE,
        dom = "ft",
        scrollY = "calc(100vh - 35px - 310px)",
        scrollCollapse = TRUE,
        columnDefs = list(
          list(orderable = FALSE, targets = 2),
          list(width = "60px", targets = 2)
        )
      ),
      class = "cell-border stripe"
    )
  }, server = TRUE)

  shiny::observeEvent(input$metadata_dt_cell_edit, {
    info <- input$metadata_dt_cell_edit
    dt <- metadata_dt()
    dt[info$row, (info$col + 1)] <- info$value
    metadata_dt(dt)
  })

  shiny::observeEvent(input$add_row, {
    dt <- metadata_dt()
    if (!is.null(dt)) {
      place_holder_idx <- nrow(dt) + 1
      place_holder_name <- paste0("place_holder_", place_holder_idx)
      dt <- rbind(dt, data.table::data.table(Name = place_holder_name, Value = place_holder_name))
      dt <- dt[!duplicated(dt), ]
      metadata_dt(dt)
    }
  })

  shiny::observeEvent(input$delete_row, {
    delete_info <- input$delete_row
    row_to_delete <- as.numeric(strsplit(delete_info, "_")[[1]][1])
    dt <- metadata_dt()
    if (!is.null(dt) && !is.na(row_to_delete) && row_to_delete > 0 && row_to_delete <= nrow(dt)) {
      dt <- dt[-row_to_delete, ]
      metadata_dt(dt)
    }
  }, ignoreInit = TRUE)

  shiny::observeEvent(input$update_metadata, {
    tryCatch(
      {
        dt <- metadata_dt()
        colnames(dt) <- c("name", "value")
        dt <- dt[!grepl("^place_holder_", dt$name), ]
        project_obj$metadata <- as.list(stats::setNames(dt$value, dt$name))
        reactive_metadata(project_obj$metadata)
      },
      error = function(e) message("Error updating metadata: ", e)
    )
  })

  shiny::observeEvent(input$discard_changes, {
    dt <- data.table::as.data.table(reactive_metadata())
    data.table::setnames(dt, c("Name", "Value"))
    metadata_dt(dt)
  })

  output$analyses_ui <- shiny::renderUI({
    project <- reactive_analyses()
    if (is.null(project)) {
      return(htmltools::div("No project loaded yet."))
    }
    .mod_Analyses_Server(
      project, "analyses", session$ns,
      reactive_update_trigger, reactive_analyses,
      reactive_warnings, reactive_volumes
    )
    .mod_Analyses_UI(project, "analyses", session$ns)
  })

  output$explorer_ui <- shiny::renderUI({
    project <- reactive_analyses()
    if (is.null(project)) {
      return(htmltools::div("No project loaded yet."))
    }
    tryCatch(
      {
        .mod_Explorer_Server(project, "explorer", session$ns, reactive_analyses, reactive_volumes)
        .mod_Explorer_UI(project, "explorer", session$ns)
      },
      error = function(e) {
        msg <- paste("Explorer not rendering for class", class(project)[1], ":", conditionMessage(e))
        shiny::showNotification(msg, duration = 10, type = "error")
        shiny::div(style = "color: red;", msg)
      }
    )
  })

  output$workflow_ui <- shiny::renderUI({
    if (is.null(project_obj)) return(htmltools::div("Project not initialized!"))
    module_id <- make_module_id("workflow", reactive_project_class(), reactive_project_db(), reactive_project_id())
    .mod_Workflow_Server(
      project_obj, module_id, session$ns,
      reactive_workflow, reactive_warnings,
      reactive_volumes, reactive_update_trigger
    )
    .mod_Workflow_UI(project_obj, module_id, session$ns)
  })

  output$results_sidebar_subnav <- shiny::renderUI({
    res <- reactive_results()
    if (length(res) == 0) return(NULL)
    session$sendCustomMessage("activateFirstSubtab", "results")
    sub_btns <- lapply(seq_along(res), function(i) {
      cls <- class(res[[i]])[1]
      tab_id <- paste0("tab_", names(res)[i])
      lbl <- switch(
        cls,
        ProjectNonTargetAnalysis = "Non-Target",
        gsub("_", " ", names(res)[i], fixed = TRUE)
      )
      htmltools::tags$button(
        class = if (i == 1) "sf-sub-btn active" else "sf-sub-btn",
        `data-tab` = "results",
        `data-subtab` = tab_id,
        title = lbl,
        lbl
      )
    })
    htmltools::div(class = "sf-sub-menu", sub_btns)
  })

  output$results_ui <- shiny::renderUI({
    res <- reactive_results()
    if (length(res) == 0) return(htmltools::div(htmltools::h4("No results found!")))
    panels <- lapply(seq_along(res), function(i) {
      res_obj <- res[[i]]
      cls <- class(res_obj)[1]
      tab_id <- paste0("tab_", names(res)[i])
      ui_fun <- get0(paste0(".mod_Result_UI.", cls), mode = "function")
      server_fun <- get0(paste0(".mod_Result_Server.", cls), mode = "function")
      if (is.function(server_fun)) {
        server_fun(res_obj, tab_id, session$ns, reactive_analyses, reactive_volumes)
      }
      shiny::conditionalPanel(
        paste0("input.sf_active_subtab === '", tab_id, "'"),
        if (is.function(ui_fun)) ui_fun(res_obj, tab_id, session$ns)
        else htmltools::div(paste0("No results UI available for ", cls))
      )
    })
    htmltools::div(panels)
  })

  output$audit_ui <- shiny::renderUI({
    htmltools::tagList(
      htmltools::tags$style(htmltools::HTML(
        ".audit-table .dataTables_wrapper { width: 100% !important; }
         .audit-table table.dataTable { width: 100% !important; }
         .audit-table table.dataTable th,
         .audit-table table.dataTable td { text-align: left !important; }"
      )),
      htmltools::div(
        class = "audit-table",
        style = "padding: 0px; box-sizing: border-box; height: calc(100vh - 35px); overflow-y: auto;",
        DT::DTOutput("audit_ui_dt", width = "100%")
      )
    )
  })

  output$audit_ui_dt <- DT::renderDT({
    audit_trail <- data.table::as.data.table(reactive_audit())
    DT::datatable(
      audit_trail,
      width = "100%",
      filter = "top",
      selection = list(mode = "single", selected = 1, target = "row"),
      options = list(
        dom = "ft",
        paging = FALSE,
        scrollX = TRUE,
        scrollY = "calc(100vh - 35px - 10px - 170px)",
        scrollCollapse = TRUE,
        autoWidth = TRUE,
        columnDefs = list(list(className = "dt-left", targets = "_all"))
      ),
      escape = FALSE
    )
  })

  output$project_data_type <- shiny::renderUI({
    project_class <- reactive_project_class()
    if (is.null(project_class) || is.na(project_class) || identical(project_class, "")) {
      return(NULL)
    }
    htmltools::tags$span(class = "sf-cache-label", paste0("Type: ", public_project_label(project_class)))
  })

  output$report_ui <- shiny::renderUI({
    if (is.null(project_obj)) return(htmltools::div("Project not initialized!"))
    .mod_Report_Server(project_obj, "report", session$ns, reactive_volumes)
    .mod_Report_UI(project_obj, "report", session$ns)
  })

  shiny::observe({
    if (reactive_show_init_modal()) {
      reactive_show_init_modal(FALSE)
      .app_util_use_initial_modal(
        reactive_app_mode,
        reactive_project_class,
        reactive_project_db,
        reactive_project_id,
        reactive_show_init_modal,
        .app_util_get_volumes(),
        input,
        output,
        session
      )
    }
  })

  shiny::observeEvent(input$restart_app, {
    time_var <- format(Sys.time(), "%Y%m%d%H%M%S")
    btn_id <- paste0("confirm_restart_", time_var)
    shiny::showModal(shiny::modalDialog(
      "Are you sure you want to restart StreamFind?",
      title = "Restart StreamFind",
      easyClose = TRUE,
      footer = shiny::tagList(
        shiny::modalButton("Cancel"),
        shiny::actionButton(btn_id, "Confirm", class = "btn-danger")
      )
    ))
    shiny::observeEvent(input[[btn_id]], {
      shiny::removeModal()
      session$sendCustomMessage("cleanupAllModals", list())
      session$sendCustomMessage("setBootOverlay", list(visible = FALSE))
      project_obj <<- NULL
      reactive_app_mode(NA_character_)
      reactive_project_class(NA_character_)
      reactive_project_db(NA_character_)
      reactive_project_id(NA_character_)
      reactive_metadata(NULL)
      reactive_analyses(NULL)
      reactive_workflow(NULL)
      reactive_results(NULL)
      reactive_audit(NULL)
      reactive_warnings(list())
    }, ignoreNULL = TRUE, once = TRUE)
  })

  shiny::observe({
    if (is.na(reactive_project_class()) && is.na(reactive_project_db()) && is.na(reactive_project_id())) {
      reactive_show_init_modal(TRUE)
    }
  })
}
