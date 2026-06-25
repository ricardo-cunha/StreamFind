#' The application server-side
#'
#' @param input,output,session Internal parameters for {shiny}.
#'
#' @noRd
app_server <- function(input, output, session) {
  volumes <- .app_util_get_volumes()
  project_obj <- NULL

  # Debug log — shows in the Terminal modal
  .debug_log <- shiny::reactiveVal(character())
  log_debug <- function(...) {
    msg <- paste0(...)
    timestamp <- format(Sys.time(), "%H:%M:%OS3")
    entry <- paste0("[", timestamp, "] ", msg)
    .debug_log(c(.debug_log(), entry))
    message(msg)
  }

  # Refresh volumes (re-reads host mounts for container environments)
  refresh_volumes <- function() {
    vols <- .app_util_get_volumes()
    reactive_volumes(vols)
    vols
  }

  reactive_project_class <- shiny::reactiveVal(NA_character_)
  reactive_project_db <- shiny::reactiveVal(NA_character_)
  reactive_project_id <- shiny::reactiveVal(NA_character_)
  reactive_project_entry <- shiny::reactiveVal(NULL)
  reactive_theme_mode <- shiny::reactiveVal("light")
  reactive_theme_palette <- shiny::reactiveVal("streamfind")
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

  sync_project_state <- function(project) {
    shiny::req(!is.null(project))
    reactive_metadata(get_metadata(project))
    reactive_analyses(project)
    reactive_workflow(get_workflow(project))
    reactive_audit(project$get_audit())
    reactive_results(.app_util_project_results(project))
  }

  if (inherits(.init_project_object, "Project")) {
    project_obj <- .init_project_object
    reactive_skip_initial_project_load(TRUE)
    reactive_project_db(project_obj$get_db())
    reactive_project_id(project_obj$get_project_id())
    reactive_project_class(class(project_obj)[1])
    reactive_project_entry(projects_overview(class(project_obj)[1]))
    sync_project_state(project_obj)
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
        "sf-subbar-btn sf-btn-transparent-hover",
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

  normalize_duckdb_path <- function(path) {
    if (!is.character(path) || length(path) == 0 || is.na(path)) {
      return(NA_character_)
    }
    path <- trimws(path[[1]])
    if (!nzchar(path)) {
      return(NA_character_)
    }
    ext <- tolower(tools::file_ext(path))
    if (!nzchar(ext)) {
      return(paste0(path, ".duckdb"))
    }
    if (!identical(ext, "duckdb")) {
      path <- paste0(tools::file_path_sans_ext(path), ".duckdb")
    }
    path
  }

  is_duckdb_path <- function(path) {
    is.character(path) &&
      length(path) > 0 &&
      !is.na(path[[1]]) &&
      identical(tolower(tools::file_ext(trimws(path[[1]]))), "duckdb")
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
    refresh_volumes()
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
    refresh_volumes()
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

  shinyFiles::shinyFileSave(
    input, "create_project_db",
    roots = volumes,
    defaultRoot = "wd",
    session = session,
    filetypes = list(duckdb = "duckdb")
  )
  shinyFiles::shinyFileChoose(
    input, "open_project_db",
    roots = volumes,
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
          htmltools::tags$span(class = "sf-home-tile-title", paste("New", entry$label)),
          htmltools::tags$span(class = "sf-home-tile-type", paste("Project Type:", project_class)),
          htmltools::tags$span(class = "sf-home-tile-copy", entry$description)
        ),
        class = "sf-home-tile"
      )
    })

    htmltools::div(
      class = "sf-page-shell sf-home-shell",
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
      project <- reactive_analyses()
      if (is.null(project)) {
        return(NULL)
      }
      pages <- .app_util_explorer_pages(class(project)[1])
      if (length(pages) == 0) {
        return(NULL)
      }
      buttons <- lapply(pages, function(page) {
        make_subbar_button("explorer", page$key, page$label, active_subtab)
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
      project <- reactive_analyses()
      if (is.null(project)) {
        return(invisible(NULL))
      }
      pages <- .app_util_explorer_pages(class(project)[1])
      if (length(pages) == 0) {
        return(invisible(NULL))
      }
      valid_subtabs <- vapply(pages, `[[`, character(1), "key")
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

  output$settings_palette_selector <- shiny::renderUI({
    mode <- reactive_theme_mode()
    is_dark <- identical(mode, "dark")

    palettes <- list(
      lagoon = list(
        name = "Lagoon",
        font = "\"Josefin Sans\", \"Segoe UI\", Helvetica, Arial, sans-serif",
        light = c("#ffffff", "#fbfdfc", "#050505", "#0b6f6b", "#0b6f6b"),
        dark  = c("#091211", "#0d1716", "#ffffff", "#46c1bb", "#46c1bb")
      ),
      copper = list(
        name = "Copper",
        font = "\"DM Sans\", \"Segoe UI\", Helvetica, Arial, sans-serif",
        light = c("#ffffff", "#fffaf5", "#2b1b12", "#a65a3a", "#a65a3a"),
        dark  = c("#150e0a", "#1c140f", "#fff7f2", "#d08a5f", "#d08a5f")
      ),
      slate = list(
        name = "Slate",
        font = "\"Inter\", \"Segoe UI\", Helvetica, Arial, sans-serif",
        light = c("#ffffff", "#fbfcfe", "#111827", "#334155", "#334155"),
        dark  = c("#0b1220", "#0f172a", "#f8fafc", "#94a3b8", "#94a3b8")
      ),
      streamfind = list(
        name = "StreamFind",
        font = "\"Space Grotesk\", \"Segoe UI\", Helvetica, Arial, sans-serif",
        light = c("#ffffff", "#f8fbf4", "#102a66", "#5a8d37", "#102a66"),
        dark  = c("#08101d", "#0d1425", "#f4f8ef", "#7fb24f", "#7fb24f")
      )
    )

    selected <- reactive_theme_palette()

    items <- lapply(names(palettes), function(key) {
      p <- palettes[[key]]
      cols <- if (is_dark) p$dark else p$light
      is_sel <- identical(key, selected)

      bar_divs <- lapply(cols, function(col) {
        htmltools::div(
          style = sprintf(
            "width: 14px; height: 14px; flex-shrink: 0; background: %s; border-radius: 1px; border: 1px solid rgba(0,0,0,0.12);",
            col
          )
        )
      })

      row_style <- sprintf(
        "display: flex; align-items: center; gap: 6px; padding: 5px 8px; cursor: pointer; font-size: 12px; border-radius: 2px; %s",
        if (is_sel) "background: var(--sf-nav-hover-bg); font-weight: 600;" else "background: transparent;"
      )

      htmltools::div(
        style = row_style,
        onclick = sprintf(
          "Shiny.setInputValue('settings_theme_palette', '%s', {priority: 'event'});",
          key
        ),
        htmltools::div(style = "display: flex; gap: 2px; align-items: center;", bar_divs),
        htmltools::span(style = sprintf("font-family: %s;", p$font), p$name)
      )
    })

    htmltools::div(style = "display: flex; flex-direction: column; gap: 2px;", items)
  })

  lapply(names(project_registry), function(project_class) {
    shiny::observeEvent(input[[paste0("home_create_", project_class)]], {
      reactive_create_db(NA_character_)
      show_create_project_modal(project_class)
    }, ignoreInit = TRUE)
  })

  shiny::observeEvent(input$open_terminal_modal, {
    log_lines <- .debug_log()
    if (length(log_lines) == 0) log_lines <- "No log entries yet."
    shiny::showModal(
      htmltools::tagAppendAttributes(
        shiny::modalDialog(
          title = htmltools::tagList(
            htmltools::tags$i(class = "fa-solid fa-terminal"),
            " Debug Terminal"
          ),
          easyClose = TRUE,
          fade = TRUE,
          size = "l",
          shiny::tags$pre(
            style = "background: #1e2129; color: #f0f0f0; padding: 12px; border-radius: 4px; font-size: 12px; line-height: 1.5; max-height: 70vh; overflow-y: auto; white-space: pre-wrap; word-break: break-all; margin: 0; font-family: 'Cascadia Code', 'Fira Code', 'JetBrains Mono', monospace;",
            paste(log_lines, collapse = "\n")
          ),
          footer = shiny::tagList(
            shiny::actionButton("clear_terminal_log", "Clear", class = "btn-danger"),
            shiny::modalButton("Close")
          )
        ),
        class = "sf-wizard-modal"
      )
    )
  }, ignoreInit = TRUE)

  shiny::observeEvent(input$clear_terminal_log, {
    .debug_log(character())
  }, ignoreInit = TRUE)

  shiny::observeEvent(input$home_open_project, {
    refresh_volumes()
    reactive_open_db(NA_character_)
    reactive_open_resolution(NULL)
    reactive_open_project_id(NA_character_)
    show_open_project_modal()
  }, ignoreInit = TRUE)

  shiny::observeEvent(list(reactive_project_class(), reactive_project_db(), reactive_project_id()), {
    project_class <- reactive_project_class()
    project_db <- reactive_project_db()
    project_id <- reactive_project_id()
    shiny::req(!is.na(project_class), !is.na(project_db), !is.na(project_id), nzchar(project_id))

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
        sync_project_state(project_obj)
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
      sync_project_state(project_obj)
    }
  })

  shiny::observeEvent(input$create_project_db, {
    fileinfo <- shinyFiles::parseSavePath(reactive_volumes(), input$create_project_db)
    if (nrow(fileinfo) > 0) {
      reactive_create_db(normalize_duckdb_path(fileinfo$datapath[1]))
    }
  }, ignoreInit = TRUE)

  shiny::observeEvent(input$open_project_db, {
    log_debug("shinyFiles: input$open_project_db triggered")
    volumes <- reactive_volumes()
    log_debug("shinyFiles: volumes = ", paste(names(volumes), volumes, sep = "=", collapse = "; "))
    raw_input <- input$open_project_db
    log_debug("shinyFiles: raw input class = ", paste(class(raw_input), collapse = ", "))
    log_debug("shinyFiles: raw input = ", paste(capture.output(str(raw_input, max.level = 2)), collapse = "\n"))
    fileinfo <- shinyFiles::parseFilePaths(volumes, raw_input)
    log_debug("shinyFiles: parseFilePaths output nrow = ", nrow(fileinfo))
    if (nrow(fileinfo) > 0) {
      log_debug("shinyFiles: datapath = ", fileinfo$datapath[1])
      log_debug("shinyFiles: name = ", fileinfo$name[1])
      log_debug("shinyFiles: filesystem path exists? ", file.exists(fileinfo$datapath[1]))
    }
    if (nrow(fileinfo) == 0) {
      log_debug("shinyFiles: no file selected, returning")
      return()
    }
    db_path <- fileinfo$datapath[1]
    if (!is_duckdb_path(db_path)) {
      log_debug("shinyFiles: not a duckdb path: ", db_path)
      reactive_open_db(NA_character_)
      reactive_open_resolution(structure(list(message = "Please select a file with the .duckdb extension."), class = "app_project_resolution_error"))
      reactive_open_project_id(NA_character_)
      return()
    }
    log_debug("shinyFiles: resolving project db: ", db_path)
    reactive_open_db(db_path)
    resolution <- tryCatch(
      .app_util_resolve_project_db(db_path, registry = project_registry),
      error = function(e) structure(list(message = conditionMessage(e)), class = "app_project_resolution_error")
    )
    log_debug("shinyFiles: resolution class = ", if (inherits(resolution, "app_project_resolution_error")) "ERROR" else "OK")
    if (!inherits(resolution, "app_project_resolution_error")) {
      log_debug("shinyFiles: rows found = ", nrow(resolution$rows))
    }
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
    db_path <- normalize_duckdb_path(db_path)
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
        style = "margin-bottom: 12px;",
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
      shinyFiles::shinySaveButton(
        "create_project_db",
        "Choose DuckDB File",
        "Select or create a DuckDB file for the project",
        filename = "project",
        filetype = list(duckdb = "duckdb"),
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
    if (!is.character(db_path) || length(db_path) == 0 || is.na(db_path) || !nzchar(trimws(db_path))) {
      return(NULL)
    }
    htmltools::div(
      class = "sf-path-preview",
      db_path
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
      htmltools::tags$br(),
      htmltools::div(class = "sf-path-preview", db_path),
      htmltools::tags$p(
        class = "sf-panel-copy",
        paste0("Project type: ", resolution$project_label)
      ),
      htmltools::tags$br(),
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

  DEFAULT_METADATA_JSON <- jsonlite::toJSON(
    list(key = "value", key2 = "value2"),
    pretty = TRUE,
    auto_unbox = TRUE
  )

  stored_metadata_json <- shiny::reactive({
    meta <- reactive_metadata()
    if (is.null(meta) || length(meta) == 0) return("null")
    .convert_to_json(meta)
  })

  project_json_string <- shiny::reactiveVal()

  project_json_valid <- shiny::reactive({
    txt <- project_json_string()
    if (is.null(txt) || !nzchar(trimws(txt))) return(FALSE)
    jsonlite::validate(txt)
  })

  .normalize_json <- function(x) {
    if (is.null(x) || identical(x, "null")) return("null")
    p <- tryCatch(jsonlite::fromJSON(x, simplifyVector = FALSE), error = function(e) NULL)
    if (is.null(p)) return(x)
    jsonlite::toJSON(p, pretty = TRUE, auto_unbox = TRUE)
  }

  project_json_dirty <- shiny::reactive({
    current <- .normalize_json(project_json_string())
    stored <- .normalize_json(stored_metadata_json())
    default <- .normalize_json(DEFAULT_METADATA_JSON)
    if (identical(current, stored)) return(FALSE)
    if (identical(current, default)) return(FALSE)
    TRUE
  })

  shiny::observe({
    stored <- stored_metadata_json()
    if (is.null(stored) || identical(stored, "null")) {
      project_json_string(DEFAULT_METADATA_JSON)
    } else {
      project_json_string(stored)
    }
  })

  if (requireNamespace("shinyAce", quietly = TRUE)) {
    shiny::observeEvent(input$project_json_editor, {
      txt <- input$project_json_editor
      if (is.null(txt)) return()
      project_json_string(txt)
    }, ignoreNULL = TRUE, ignoreInit = TRUE)
  } else {
    shiny::observeEvent(input$project_json_fallback, {
      txt <- input$project_json_fallback
      if (is.null(txt)) return()
      project_json_string(txt)
    }, ignoreNULL = TRUE, ignoreInit = TRUE)
  }

  reactive_metadata_list <- shiny::reactive({
    meta <- reactive_metadata()
    if (is.null(meta) || length(meta) == 0) {
      return(data.frame(Key = character(), Value = character(), stringsAsFactors = FALSE))
    }
    keys <- names(meta)
    vals <- as.character(unlist(meta, use.names = FALSE))
    if (is.null(keys) || length(keys) == 0) keys <- seq_along(vals)
    data.frame(Key = keys, Value = vals, stringsAsFactors = FALSE)
  })

  output$metadata_ui <- shiny::renderUI({
    df <- reactive_metadata_list()
    rows <- lapply(seq_len(nrow(df)), function(i) {
      htmltools::div(
        style = "display: flex; gap: 10px; padding: 3px 0; font-size: 13px;",
        htmltools::span(style = "font-weight: 600; color: var(--sf-accent); min-width: 200px;", df$Key[i]),
        htmltools::span(style = "color: var(--sf-text-primary); flex: 1; word-break: break-word;", df$Value[i])
      )
    })
    if (length(rows) == 0) {
      rows <- list(htmltools::div(style = "color: var(--sf-text-secondary); font-size: 13px;", "No metadata set."))
    }
    htmltools::div(
      class = "sf-stack sf-fill",
      htmltools::div(
        style = "display: flex; align-items: center; gap: 6px; flex-shrink: 0;",
        shiny::actionButton(
          "modify_metadata",
          label = "",
          icon = shiny::icon("pen-to-square", class = "fa-solid"),
          class = "sf-topbar-btn sf-btn-transparent-hover"
        ),
        htmltools::tags$p(class = "sf-page-subtitle", style = "margin: 0;", "Project Metadata:")
      ),
      htmltools::div(
        style = "flex: 1; overflow-y: auto; min-height: 0; padding: 5px;",
        rows
      )
    )
  })

  shiny::observeEvent(input$modify_metadata, {
    stored <- stored_metadata_json()
    if (is.null(stored) || identical(stored, "null")) {
      project_json_string(DEFAULT_METADATA_JSON)
    } else {
      project_json_string(stored)
    }
    is_dark <- identical(reactive_theme_mode(), "dark")
    has_ace <- requireNamespace("shinyAce", quietly = TRUE)
    editor_core <- if (has_ace) {
      shinyAce::aceEditor(
        "project_json_editor",
        mode = "json",
        theme = if (is_dark) "idle_fingers" else "textmate",
        height = "100%",
        fontSize = 12,
        tabSize = 2,
        useSoftTabs = TRUE,
        showPrintMargin = FALSE,
        showLineNumbers = TRUE,
        debounce = 500,
        autoComplete = "disabled",
        value = project_json_string()
      )
    } else {
      shiny::tags$textarea(
        id = "project_json_fallback",
        class = "form-control",
        style = "width: 100%; height: 100%; font-family: monospace; font-size: 12px; resize: none;",
        oninput = "Shiny.setInputValue('project_json_fallback', this.value, {priority: 'event'});",
        project_json_string()
      )
    }
    editor_ui <- htmltools::div(
      style = "flex: 1; min-height: 0; height: 100%; display: flex; flex-direction: column; overflow: hidden;",
      editor_core
    )
    shiny::showModal(shiny::modalDialog(
      title = "Edit Metadata JSON",
      editor_ui,
      footer = shiny::tagList(
        shiny::actionButton("save_project_json", "Save"),
        shiny::actionButton("discard_project_json", "Discard", class = "btn-danger")
      ),
      size = "l",
      easyClose = TRUE,
      fluid = FALSE
    ))
  })

  shiny::observeEvent(input$save_project_json, {
    txt <- project_json_string()
    if (!jsonlite::validate(txt)) {
      shiny::showNotification("Invalid JSON — cannot save.", type = "error")
      return()
    }
    project <- reactive_analyses()
    shiny::req(!is.null(project))
    parsed <- jsonlite::fromJSON(txt, simplifyVector = FALSE)
    pretty <- jsonlite::toJSON(parsed, pretty = TRUE, auto_unbox = TRUE)
    project$set_metadata(pretty)
    sync_project_state(project)
    project_json_string(pretty)
    if (requireNamespace("shinyAce", quietly = TRUE)) {
      shinyAce::updateAceEditor(session, "project_json_editor", value = pretty)
    }
    shiny::removeModal()
    shiny::showNotification("Metadata saved.", type = "message", duration = 3)
  })

  shiny::observeEvent(input$discard_project_json, {
    stored <- stored_metadata_json()
    if (is.null(stored) || identical(stored, "null")) {
      project_json_string(DEFAULT_METADATA_JSON)
    } else {
      project_json_string(stored)
    }
    if (requireNamespace("shinyAce", quietly = TRUE)) {
      new_val <- if (is.null(stored) || identical(stored, "null")) DEFAULT_METADATA_JSON else stored
      shinyAce::updateAceEditor(session, "project_json_editor", value = new_val)
    }
    shiny::removeModal()
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
        module_fns$server(project, "explorer", session$ns, reactive_analyses, reactive_volumes, reactive_theme_mode)
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
      server_fun(project, tab_id, session$ns, reactive_analyses, reactive_volumes, reactive_theme_mode)
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
        style = "padding: 0px; box-sizing: border-box; height: calc(100vh - var(--sf-topbar-height) - var(--sf-pad-10)); overflow-y: auto;",
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
        scrollY = "calc(100vh - var(--sf-topbar-height) - var(--sf-pad-10) - 10px - 170px)",
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
          style = "max-height: calc(100vh - 44px); overflow-y: auto; overflow-x: hidden; font-size: 12px;",
          htmltools::div(
            class = "sf-settings-section",
          htmltools::tags$h4(class = "sf-panel-title", style = "font-size: 14px;", "Mode"),
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
          htmltools::tags$h4(class = "sf-panel-title", style = "font-size: 14px;", "Style"),
          shiny::uiOutput("settings_palette_selector")
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

  shiny::outputOptions(output, "project_ui", suspendWhenHidden = FALSE)
  shiny::outputOptions(output, "analyses_ui", suspendWhenHidden = FALSE)
  shiny::outputOptions(output, "explorer_ui", suspendWhenHidden = FALSE)
  shiny::outputOptions(output, "workflow_ui", suspendWhenHidden = FALSE)
  shiny::outputOptions(output, "results_ui", suspendWhenHidden = FALSE)
  shiny::outputOptions(output, "report_ui", suspendWhenHidden = FALSE)
  shiny::outputOptions(output, "audit_ui", suspendWhenHidden = FALSE)
  shiny::outputOptions(output, "settings_palette_selector", suspendWhenHidden = FALSE)
}
