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
  reactive_project_entry <- shiny::reactiveVal(NULL)
  reactive_theme_mode <- shiny::reactiveVal("light")
  reactive_theme_palette <- shiny::reactiveVal("lagoon")
  reactive_create_class <- shiny::reactiveVal(NA_character_)
  reactive_create_db <- shiny::reactiveVal(NA_character_)
  reactive_open_db <- shiny::reactiveVal(NA_character_)
  reactive_open_resolution <- shiny::reactiveVal(NULL)
  reactive_open_project_id <- shiny::reactiveVal(NA_character_)
  reactive_skip_initial_project_load <- shiny::reactiveVal(FALSE)

  .init_project_db <- golem::get_golem_options("db")
  .init_project_id <- golem::get_golem_options("project_id")
  .init_project_class <- golem::get_golem_options("project_class")
  .init_project_object <- golem::get_golem_options("project_object")

  if (!is.null(.init_project_db) && !is.na(.init_project_db) && file.exists(.init_project_db)) {
    reactive_project_db(.init_project_db)
  }
  if (!is.null(.init_project_id) && !is.na(.init_project_id) && nzchar(.init_project_id)) {
    reactive_project_id(.init_project_id)
  }
  if (!is.null(.init_project_class) && !is.na(.init_project_class) && nzchar(.init_project_class)) {
    reactive_project_class(.init_project_class)
  } else if (!is.null(.init_project_db) && !is.na(.init_project_db) && file.exists(.init_project_db)) {
    try({
      init_resolution <- .app_util_resolve_project_db(.init_project_db)
      reactive_project_class(init_resolution$project_class)
      reactive_project_entry(projects_overview(init_resolution$project_class))
    }, silent = TRUE)
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

  if (inherits(.init_project_object, "Project")) {
    project_obj <- .init_project_object
    reactive_skip_initial_project_load(TRUE)
    reactive_project_db(project_obj$get_db())
    reactive_project_id(project_obj$get_project_id())
    reactive_project_class(class(project_obj)[1])
    reactive_project_entry(projects_overview(class(project_obj)[1]))
    reactive_metadata(project_obj$metadata)
    reactive_analyses(project_obj)
    reactive_workflow(get_workflow(project_obj))
    reactive_audit(project_obj$get_audit())
    reactive_results(.app_util_project_results(project_obj))
    reactive_app_mode("Project")

    session$onFlushed(function() {
      session$sendCustomMessage("setActiveTab", list(tab = "project"))
      session$sendCustomMessage("setBootOverlay", list(visible = FALSE))
    }, once = TRUE)
  }

  project_registry <- projects_overview()
  value_or <- function(x, default) if (is.null(x) || length(x) == 0) default else x

  make_subbar_button <- function(tab, key, label, active_key = NA_character_) {
    htmltools::tags$button(
      type = "button",
      class = paste(
        "sf-subbar-btn",
        if (!is.na(active_key) && identical(active_key, key)) "active" else ""
      ),
      `data-tab` = tab,
      `data-subtab` = key,
      title = label,
      label
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
    opener_name <- .project_open_function_name(project_class)
    opener <- get0(opener_name, envir = asNamespace("StreamFind"), mode = "function", inherits = FALSE)
    if (is.null(opener)) {
      stop("Project open function not found: ", opener_name)
    }
    suppressMessages(opener(db = db, project_id = project_id))
  }

  no_project_loaded_ui <- function() {
    htmltools::div(
      class = "sf-empty-state",
      htmltools::div(
        class = "sf-page-title-block",
        htmltools::tags$h3(class = "sf-page-title", "No project loaded"),
        htmltools::tags$p(
          class = "sf-page-subtitle",
          "No project is currently loaded. Use the Home tab to create or open a project."
        )
      )
    )
  }

  show_create_project_modal <- function(project_class) {
    details <- projects_overview(project_class)
    reactive_create_class(project_class)
    shiny::showModal(
      htmltools::tagAppendAttributes(
        shiny::modalDialog(
          title = paste("Create", details$label),
          easyClose = TRUE,
          footer = shiny::tagList(
            shiny::modalButton("Cancel"),
            shiny::actionButton("create_project_confirm", "Create / Open Project", class = "btn-primary")
          ),
          shiny::uiOutput("create_project_modal_ui")
        ),
        class = "sf-wizard-modal"
      )
    )
  }

  show_open_project_modal <- function() {
    shiny::showModal(
      htmltools::tagAppendAttributes(
        shiny::modalDialog(
          title = "Open Existing Project",
          easyClose = TRUE,
          footer = shiny::tagList(
            shiny::modalButton("Cancel"),
            shiny::actionButton("open_project_confirm", "Open Project", class = "btn-primary")
          ),
          shiny::uiOutput("open_project_modal_ui")
        ),
        class = "sf-wizard-modal"
      )
    )
  }

  shinyFiles::shinyFileChoose(
    input, "create_project_db",
    roots = reactive_volumes(),
    defaultRoot = "wd",
    session = session,
    filetypes = "duckdb"
  )
  shinyFiles::shinyFileChoose(
    input, "open_project_db",
    roots = reactive_volumes(),
    defaultRoot = "wd",
    session = session,
    filetypes = "duckdb"
  )

  output$app_mode_ui <- shiny::renderUI({
    shiny::tags$span("StreamFind")
  })

  output$home_ui <- shiny::renderUI({
    project_tiles <- lapply(names(project_registry), function(project_class) {
      entry <- project_registry[[project_class]]
      shiny::actionButton(
        inputId = paste0("home_create_", project_class),
        label = htmltools::tagList(
          htmltools::tags$span(class = "sf-home-tile-title", entry$label),
          htmltools::tags$span(class = "sf-home-tile-type", paste("Project Type:", project_class)),
          htmltools::tags$span(class = "sf-home-tile-copy", entry$description)
        ),
        class = "sf-home-tile"
      )
    })

    htmltools::div(
      class = "sf-page-shell sf-home-shell",
      htmltools::div(
        class = "sf-page-toolbar",
        htmltools::div(
          class = "sf-page-title-block",
          htmltools::tags$h3(class = "sf-page-title", "Home"),
          htmltools::tags$p(
            class = "sf-page-subtitle",
            "Start a new project from any available project class or open an existing StreamFind DuckDB file."
          )
        )
      ),
      htmltools::div(
        class = "sf-home-grid",
        project_tiles,
        shiny::actionButton(
          "home_open_project",
          label = htmltools::tagList(
            htmltools::tags$span(class = "sf-home-tile-title", "Open Existing Project"),
            htmltools::tags$span(class = "sf-home-tile-type", "DuckDB Resolver"),
            htmltools::tags$span(
              class = "sf-home-tile-copy",
              "Inspect an existing DuckDB file, resolve its project class dynamically, and choose the project ID to work on."
            )
          ),
          class = "sf-home-tile sf-home-tile-open"
        )
      )
    )
  })

  output$subtopbar_ui <- shiny::renderUI({
    active_tab <- value_or(input$sf_active_tab, "home")
    active_subtab <- value_or(input$sf_active_subtab, "")

    if (identical(active_tab, "explorer")) {
      buttons <- list(
        make_subbar_button("explorer", "spectra", "Spectra", active_subtab),
        make_subbar_button("explorer", "chromatograms", "Chromatograms", active_subtab),
        make_subbar_button("explorer", "eic", "EIC", active_subtab)
      )
      return(
        htmltools::div(
          id = "sf-subtopbar",
          htmltools::div(
            class = "sf-subtopbar-nav",
            do.call(htmltools::tagList, buttons)
          )
        )
      )
    }

    if (identical(active_tab, "results")) {
      project <- reactive_analyses()
      if (is.null(project)) {
        return(NULL)
      }
      pages <- .app_util_results_pages(class(project)[1])
      if (length(pages) == 0) {
        return(NULL)
      }
      buttons <- lapply(pages, function(page) {
        make_subbar_button("results", page$key, page$label, active_subtab)
      })
      return(
        htmltools::div(
          id = "sf-subtopbar",
          htmltools::div(
            class = "sf-subtopbar-nav",
            do.call(htmltools::tagList, buttons)
          )
        )
      )
    }

    NULL
  })

  shiny::observe({
    active_tab <- value_or(input$sf_active_tab, "home")
    active_subtab <- value_or(input$sf_active_subtab, "")

    if (identical(active_tab, "explorer")) {
      valid_subtabs <- c("spectra", "chromatograms", "eic")
      if (!active_subtab %in% valid_subtabs) {
        session$sendCustomMessage("setActiveTab", list(tab = "explorer", subtab = valid_subtabs[[1]]))
      }
      return(invisible(NULL))
    }

    if (identical(active_tab, "results")) {
      project <- reactive_analyses()
      if (is.null(project)) {
        return(invisible(NULL))
      }
      pages <- .app_util_results_pages(class(project)[1])
      if (length(pages) == 0) {
        return(invisible(NULL))
      }
      valid_subtabs <- vapply(pages, `[[`, character(1), "key")
      if (!active_subtab %in% valid_subtabs) {
        session$sendCustomMessage("setActiveTab", list(tab = "results", subtab = valid_subtabs[[1]]))
      }
    }
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
          class = "sf-topbar-dropdown sf-notif-dropdown",
          items
        )
      )
  })

  shiny::observe({
    session$sendCustomMessage("setAppTheme", list(
      mode = reactive_theme_mode(),
      palette = reactive_theme_palette()
    ))
  })

  shiny::observeEvent(input$settings_theme_mode, {
    shiny::req(is.character(input$settings_theme_mode), nzchar(input$settings_theme_mode))
    reactive_theme_mode(input$settings_theme_mode)
  }, ignoreInit = TRUE)

  shiny::observeEvent(input$settings_theme_palette, {
    shiny::req(is.character(input$settings_theme_palette), nzchar(input$settings_theme_palette))
    reactive_theme_palette(input$settings_theme_palette)
  })

  lapply(names(project_registry), function(project_class) {
    shiny::observeEvent(input[[paste0("home_create_", project_class)]], {
      reactive_create_db(NA_character_)
      show_create_project_modal(project_class)
    }, ignoreInit = TRUE)
  })

  shiny::observeEvent(input$home_open_project, {
    reactive_open_db(NA_character_)
    reactive_open_resolution(NULL)
    reactive_open_project_id(NA_character_)
    show_open_project_modal()
  }, ignoreInit = TRUE)

  shiny::observeEvent(list(reactive_project_class(), reactive_project_db(), reactive_project_id()), {
    project_class <- reactive_project_class()
    project_db <- reactive_project_db()
    project_id <- reactive_project_id()
    shiny::req(!is.na(project_class), !is.na(project_db), !is.na(project_id), file.exists(project_db), nzchar(project_id))

    if (isTRUE(reactive_skip_initial_project_load())) {
      reactive_skip_initial_project_load(FALSE)
      session$onFlushed(function() {
        session$sendCustomMessage("setBootOverlay", list(visible = FALSE))
      }, once = TRUE)
      return(invisible(NULL))
    }

    session$sendCustomMessage("setBootOverlay", list(visible = TRUE))

    tryCatch(
      {
        project_obj <<- load_project_object(project_class, project_db, project_id)
        reactive_project_entry(projects_overview(project_class))
        reactive_metadata(project_obj$metadata)
        reactive_analyses(project_obj)
        reactive_workflow(get_workflow(project_obj))
        reactive_audit(project_obj$get_audit())
        reactive_results(.app_util_project_results(project_obj))
        reactive_app_mode("Project")

        session$onFlushed(function() {
          session$sendCustomMessage("setActiveTab", list(tab = "project"))
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
      reactive_project_entry(projects_overview(class(project_obj)[1]))
      reactive_metadata(project_obj$metadata)
      reactive_analyses(project_obj)
      reactive_workflow(get_workflow(project_obj))
      reactive_audit(project_obj$get_audit())
      reactive_results(.app_util_project_results(project_obj))
    }
  })

  shiny::observeEvent(input$create_project_db, {
    fileinfo <- shinyFiles::parseFilePaths(reactive_volumes(), input$create_project_db)
    if (nrow(fileinfo) > 0) {
      reactive_create_db(fileinfo$datapath[1])
    }
  }, ignoreInit = TRUE)

  shiny::observeEvent(input$open_project_db, {
    fileinfo <- shinyFiles::parseFilePaths(reactive_volumes(), input$open_project_db)
    if (nrow(fileinfo) == 0) {
      return()
    }
    db_path <- fileinfo$datapath[1]
    reactive_open_db(db_path)
    resolution <- tryCatch(
      .app_util_resolve_project_db(db_path, registry = project_registry),
      error = function(e) structure(list(message = conditionMessage(e)), class = "app_project_resolution_error")
    )
    reactive_open_resolution(resolution)
    if (!inherits(resolution, "app_project_resolution_error") && !is.null(resolution) && nrow(resolution$rows) > 0) {
      reactive_open_project_id(resolution$rows$project_id[[1]])
    } else {
      reactive_open_project_id(NA_character_)
    }
  }, ignoreInit = TRUE)

  shiny::observeEvent(input$open_project_tile, {
    shiny::req(is.character(input$open_project_tile), nzchar(input$open_project_tile))
    reactive_open_project_id(input$open_project_tile)
  }, ignoreInit = TRUE)

  shiny::observeEvent(input$create_project_confirm, {
    project_class <- reactive_create_class()
    project_id <- input$create_project_id
    if (is.null(project_id)) project_id <- ""
    project_id <- trimws(project_id)
    db_path <- reactive_create_db()
    if (!is.character(project_class) || !nzchar(project_class)) {
      shiny::showNotification("Please choose a project type to create.", type = "warning", duration = 5)
      return()
    }
    if (!is.character(db_path) || !nzchar(db_path)) {
      shiny::showNotification("Please choose a DuckDB file for the new project.", type = "warning", duration = 5)
      return()
    }
    if (!nzchar(project_id)) {
      shiny::showNotification("Please enter a project ID.", type = "warning", duration = 5)
      return()
    }
    shiny::removeModal()
    reactive_project_class(project_class)
    reactive_project_db(db_path)
    reactive_project_id(project_id)
    session$sendCustomMessage("setActiveTab", list(tab = "project"))
  }, ignoreInit = TRUE)

  shiny::observeEvent(input$open_project_confirm, {
    resolution <- reactive_open_resolution()
    if (inherits(resolution, "app_project_resolution_error") || is.null(resolution)) {
      shiny::showNotification("Please select a valid StreamFind DuckDB file.", type = "warning", duration = 5)
      return()
    }
    selected_project_id <- reactive_open_project_id()
    if (is.null(selected_project_id)) selected_project_id <- ""
    selected_project_id <- trimws(selected_project_id)
    if (!nzchar(selected_project_id)) {
      shiny::showNotification("Please choose a project ID from the selected DuckDB file.", type = "warning", duration = 5)
      return()
    }
    if (!selected_project_id %in% resolution$rows$project_id) {
      shiny::showNotification("The selected project ID is not available in this DuckDB file.", type = "error", duration = 5)
      return()
    }
    shiny::removeModal()
    reactive_project_class(resolution$project_class)
    reactive_project_db(reactive_open_db())
    reactive_project_id(selected_project_id)
    session$sendCustomMessage("setActiveTab", list(tab = "project"))
  }, ignoreInit = TRUE)

  output$project_ui <- shiny::renderUI({
    project <- reactive_analyses()
    if (is.null(project)) {
      return(htmltools::div(class = "sf-page-shell", no_project_loaded_ui()))
    }
    htmltools::div(
      class = "sf-page-shell",
      htmltools::div(
        class = "sf-page-toolbar",
        shiny::uiOutput("project_control_ui")
      ),
      htmltools::div(
        class = "sf-page-body",
        shiny::uiOutput("metadata_ui")
      )
    )
  })

  output$create_project_modal_ui <- shiny::renderUI({
    project_class <- reactive_create_class()
    shiny::req(is.character(project_class), nzchar(project_class))
    details <- projects_overview(project_class)
    htmltools::div(
      class = "sf-stack",
      htmltools::div(
        class = "sf-info-banner",
        htmltools::tags$strong(details$label),
        htmltools::tags$p(class = "sf-panel-copy", details$description),
        htmltools::tags$div(
          class = "sf-inline-meta",
          htmltools::tags$span("Domain:"),
          htmltools::tags$span(details$domain),
          htmltools::tags$span("Formats:"),
          htmltools::tags$span(paste(details$formats, collapse = ", "))
        )
      ),
      shinyFiles::shinyFilesButton(
        "create_project_db",
        "Choose DuckDB File",
        "Select or create a DuckDB file for the project",
        multiple = FALSE,
        class = "btn btn-default"
      ),
      shiny::uiOutput("create_project_db_ui"),
      shiny::textInput("create_project_id", "Project ID", value = "default")
    )
  })

  output$open_project_modal_ui <- shiny::renderUI({
    htmltools::div(
      class = "sf-stack",
      shinyFiles::shinyFilesButton(
        "open_project_db",
        "Choose Existing DuckDB File",
        "Select a StreamFind DuckDB file",
        multiple = FALSE,
        class = "btn btn-default"
      ),
      shiny::uiOutput("open_project_resolution_ui")
    )
  })

  output$create_project_db_ui <- shiny::renderUI({
    db_path <- reactive_create_db()
    htmltools::div(
      class = "sf-path-preview",
      if (is.character(db_path) && nzchar(db_path)) db_path else "No DuckDB file selected."
    )
  })

  output$open_project_resolution_ui <- shiny::renderUI({
    resolution <- reactive_open_resolution()
    db_path <- reactive_open_db()
    if (!is.character(db_path) || !nzchar(db_path)) {
      return(htmltools::div(class = "sf-path-preview", "No DuckDB file selected."))
    }
    if (inherits(resolution, "app_project_resolution_error")) {
      return(
        htmltools::div(
          class = "sf-panel sf-panel-danger",
          htmltools::tags$strong("Invalid project file"),
          htmltools::tags$p(class = "sf-panel-copy", resolution$message)
        )
      )
    }
    shiny::req(!is.null(resolution))
    rows <- resolution$rows
    selected_project_id <- reactive_open_project_id()
    project_tiles <- lapply(rows$project_id, function(project_id) {
      htmltools::tags$button(
        type = "button",
        class = paste(
          "sf-home-tile sf-project-id-tile",
          if (!is.na(selected_project_id) && identical(selected_project_id, project_id)) "active" else ""
        ),
        onclick = sprintf(
          "Shiny.setInputValue('open_project_tile', '%s', {priority: 'event'})",
          gsub("'", "\\\\'", project_id, fixed = TRUE)
        ),
        htmltools::tags$span(class = "sf-home-tile-title", project_id),
        htmltools::tags$span(class = "sf-home-tile-type", "Project ID")
      )
    })
    htmltools::div(
      class = "sf-panel sf-panel-muted",
      htmltools::div(class = "sf-path-preview", db_path),
      htmltools::tags$p(
        class = "sf-panel-copy",
        paste0("Resolved project class: ", resolution$project_label, " (", resolution$project_class, ")")
      ),
      htmltools::div(class = "sf-project-id-grid", project_tiles)
    )
  })

  output$project_control_ui <- shiny::renderUI({
    project <- reactive_analyses()
    shiny::req(!is.null(project))
    project_db <- reactive_project_db()
    project_id <- reactive_project_id()
    htmltools::div(
      class = "sf-project-summary",
      htmltools::div(
        class = "sf-project-summary-lines",
        htmltools::tags$p(class = "sf-page-subtitle", "Project DB:"),
        htmltools::tags$p(class = "sf-page-title", project_db),
        htmltools::tags$p(class = "sf-page-subtitle", "Project ID:"),
        htmltools::tags$p(class = "sf-page-title", project_id)
      )
    )
  })

  metadata_dt <- shiny::reactiveVal()

  metadata_to_dt <- function(meta) {
    if (is.null(meta) || length(meta) == 0) {
      return(data.table::data.table(Name = character(), Value = character()))
    }
    if (inherits(meta, "data.frame")) {
      dt <- data.table::as.data.table(meta)
      if (ncol(dt) >= 2) {
        dt <- dt[, seq_len(2), with = FALSE]
        data.table::setnames(dt, c("Name", "Value"))
        dt[, Name := as.character(Name)]
        dt[, Value := as.character(Value)]
        return(dt)
      }
    }
    values <- unlist(meta, use.names = FALSE)
    names_vec <- names(meta)
    if (is.null(names_vec) || !length(names_vec)) {
      names_vec <- rep("", length(values))
    }
    data.table::data.table(
      Name = as.character(names_vec),
      Value = as.character(values)
    )
  }

  shiny::observe({
    tryCatch(
      {
        metadata_dt(metadata_to_dt(reactive_metadata()))
      },
      error = function(e) message("Error initializing metadata: ", e)
    )
  })

  output$update_metadata_ui <- shiny::renderUI({
    dt <- metadata_dt()
    if (!is.null(dt)) {
      htmltools::div(
        class = "sf-toolbar-inline",
        shiny::actionButton("update_metadata", "Update Metadata"),
        shiny::actionButton("discard_changes", "Discard Changes", class = "btn-danger")
      )
    }
  })

  output$metadata_ui <- shiny::renderUI({
    htmltools::div(
      class = "sf-stack sf-fill",
      htmltools::div(
        class = "sf-toolbar-inline",
        shiny::actionButton("add_row", "Add New Row", class = "btn-light"),
        shiny::uiOutput("update_metadata_ui")
      ),
      htmltools::div(
        class = "sf-info-text",
        shiny::HTML("<i class='fa fa-info-circle'></i> Double-click on any cell to edit its value")
      ),
      htmltools::div(
        class = "sf-fill",
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
    if (is.null(dt)) dt <- data.table::data.table(Name = character(), Value = character())
    place_holder_idx <- nrow(dt) + 1
    place_holder_name <- paste0("place_holder_", place_holder_idx)
    dt <- rbind(dt, data.table::data.table(Name = place_holder_name, Value = place_holder_name))
    dt <- dt[!duplicated(dt), ]
    metadata_dt(dt)
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
    metadata_dt(metadata_to_dt(reactive_metadata()))
  })

  output$analyses_ui <- shiny::renderUI({
    project <- reactive_analyses()
    if (is.null(project)) {
      return(no_project_loaded_ui())
    }
    module_fns <- .app_util_module_functions(class(project)[1], "analyses")
    if (!is.function(module_fns$ui) || !is.function(module_fns$server)) {
      return(htmltools::div(class = "sf-empty-state", "No analyses module available for this project class."))
    }
    module_fns$server(
      project, "analyses", session$ns,
      reactive_update_trigger, reactive_analyses,
      reactive_warnings, reactive_volumes
    )
    module_fns$ui(project, "analyses", session$ns)
  })

  output$explorer_ui <- shiny::renderUI({
    project <- reactive_analyses()
    if (is.null(project)) {
      return(no_project_loaded_ui())
    }
    tryCatch(
      {
        module_fns <- .app_util_module_functions(class(project)[1], "explorer")
        if (!is.function(module_fns$ui) || !is.function(module_fns$server)) {
          return(htmltools::div(class = "sf-empty-state", "No explorer module available for this project class."))
        }
        module_fns$server(project, "explorer", session$ns, reactive_analyses, reactive_volumes)
        module_fns$ui(project, "explorer", session$ns)
      },
      error = function(e) {
        msg <- paste("Explorer not rendering for class", class(project)[1], ":", conditionMessage(e))
        shiny::showNotification(msg, duration = 10, type = "error")
        shiny::div(class = "sf-panel sf-panel-danger", msg)
      }
    )
  })

  output$workflow_ui <- shiny::renderUI({
    project <- reactive_analyses()
    if (is.null(project)) return(no_project_loaded_ui())
    module_id <- make_module_id("workflow", reactive_project_class(), reactive_project_db(), reactive_project_id())
    .mod_Workflow_Server(
      project, module_id, session$ns,
      reactive_workflow, reactive_warnings,
      reactive_volumes, reactive_update_trigger
    )
    .mod_Workflow_UI(project, module_id, session$ns)
  })

  output$results_ui <- shiny::renderUI({
    project <- reactive_analyses()
    if (is.null(project)) return(no_project_loaded_ui())
    pages <- .app_util_results_pages(class(project)[1])
    if (length(pages) == 0) {
      return(htmltools::div(class = "sf-empty-state", htmltools::h4("No results found!")))
    }
    module_fns <- .app_util_module_functions(class(project)[1], "results")
    ui_fun <- module_fns$ui
    server_fun <- module_fns$server
    tab_id <- "results"
    if (is.function(server_fun)) {
      server_fun(project, tab_id, session$ns, reactive_analyses, reactive_volumes)
    }
    if (is.function(ui_fun)) ui_fun(project, tab_id, session$ns)
    else htmltools::div(class = "sf-empty-state", paste0("No results UI available for ", class(project)[1]))
  })

  output$audit_ui <- shiny::renderUI({
    project <- reactive_analyses()
    if (is.null(project)) return(no_project_loaded_ui())
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
    htmltools::tags$span(class = "sf-cache-label", paste0("Type: ", .app_util_project_label(project_class)))
  })

  output$settings_dropdown_ui <- shiny::renderUI({
    htmltools::div(
      class = "sf-settings-wrapper",
      htmltools::tags$button(
        class = "sf-topbar-btn",
        onclick = "var dd = document.getElementById('sf-settings-dropdown'); if(dd) dd.classList.toggle('open');",
        title = "Settings",
        shiny::icon("gear")
        ),
        htmltools::div(
          id = "sf-settings-dropdown",
          class = "sf-topbar-dropdown sf-settings-dropdown",
          htmltools::div(
            class = "sf-settings-section",
          htmltools::tags$h4(class = "sf-panel-title", "Mode"),
          shiny::radioButtons(
            "settings_theme_mode",
            label = NULL,
            choices = c("Light" = "light", "Dark" = "dark"),
            selected = reactive_theme_mode(),
            inline = FALSE
          )
        ),
        htmltools::div(
          class = "sf-settings-section",
          htmltools::tags$h4(class = "sf-panel-title", "Palette"),
          shiny::selectInput(
            "settings_theme_palette",
            label = NULL,
            choices = c(
              "Lagoon" = "lagoon",
              "Copper" = "copper",
              "Slate" = "slate",
              "StreamFind" = "streamfind"
            ),
            selected = reactive_theme_palette()
          )
        ),
        htmltools::div(
          class = "sf-settings-note",
          "Theme changes apply to the current app session only."
        )
      )
    )
  })

  output$report_ui <- shiny::renderUI({
    project <- reactive_analyses()
    if (is.null(project)) return(no_project_loaded_ui())
    .mod_Report_Server(project, "report", session$ns, reactive_volumes)
    .mod_Report_UI(project, "report", session$ns)
  })

}
