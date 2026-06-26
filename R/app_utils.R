# MARK: Notifications
#' @noRd
.app_util_add_notifications <- function(warnings, name_msg, msg) {
  shiny::showNotification(msg, duration = 5, type = "warning")
  warnings[[name_msg]] <- msg
  warnings
}

#' @noRd
.app_util_remove_notifications <- function(warnings, name_msgs) {
  warnings[name_msgs] <- NULL
  warnings
}

# MARK: Volumes for shinyFiles
#' @noRd
.app_util_get_volumes <- function() {
  home_dir <- Sys.getenv("USERPROFILE", unset = Sys.getenv("HOME", unset = "~"))
  volumes <- c(
    "wd" = normalizePath(getwd(), winslash = "/", mustWork = FALSE),
    "Home" = normalizePath(home_dir, winslash = "/", mustWork = FALSE)
  )

  # Standard mount root for Docker host bind mounts
  standard_host_root <- "/mnt/streamfind-host"
  if (dir.exists(standard_host_root)) {
    mounted <- list.files(standard_host_root, full.names = TRUE, recursive = FALSE, no.. = TRUE)
    mounted <- mounted[dir.exists(mounted)]
    if (length(mounted) > 0) {
      names(mounted) <- paste("Host", basename(mounted))
      mounted <- normalizePath(mounted, winslash = "/", mustWork = FALSE)
      volumes <- c(volumes, mounted)
    }
  }

  # Legacy /host_* mounts (Docker Desktop for Windows)
  legacy_host_dirs <- list.files("/", pattern = "^host_", full.names = TRUE)
  legacy_host_dirs <- legacy_host_dirs[dir.exists(legacy_host_dirs)]
  if (length(legacy_host_dirs) > 0) {
    names(legacy_host_dirs) <- basename(legacy_host_dirs)
    legacy_host_dirs <- gsub("^/{2,}", "/", legacy_host_dirs)
    volumes <- c(volumes, legacy_host_dirs)
  }

  # Windows drive letters
  os_type <- Sys.info()["sysname"]
  if (os_type == "Windows") {
    drives <- system(
      'powershell -NoProfile -Command "Get-PSDrive -PSProvider FileSystem | Select-Object -ExpandProperty Name"',
      intern = TRUE
    )
    drives <- paste0(drives, ":")
    names(drives) <- drives
    volumes <- c(volumes, drives)
  } else if (length(volumes) == 1) {
    # Fallback for Linux without any host mounts
    media_dirs <- list.files("/media", full.names = TRUE)
    names(media_dirs) <- basename(media_dirs)
    if (length(media_dirs) == 0) {
      media_dirs <- list.files("/mnt", full.names = TRUE)
      names(media_dirs) <- basename(media_dirs)
    }
    volumes <- c(volumes, media_dirs)
  }

  # Sanitize: remove any NA paths and normalize double slashes
  volumes <- volumes[!is.na(volumes) & nzchar(volumes)]
  volumes <- gsub("^/{2,}", "/", volumes)
  # Add "wd" alias pointing to first volume for backward compatibility
  if (length(volumes) > 0 && !"wd" %in% names(volumes)) {
    volumes <- c("wd" = unname(volumes[1]), volumes)
  }
  volumes
}

#' @noRd
.app_util_project_label <- function(project_class) {
  details <- tryCatch(projects_overview(project_class), error = function(...) NULL)
  if (!is.null(details) && !is.null(details$label)) {
    return(details$label)
  }
  project_class
}

#' @noRd
.app_util_result_label <- function(result_class) {
  switch(
    result_class,
    ProjectMassSpecChromatograms = "Chromatograms",
    ProjectNonTargetAnalysis = "Non-Target Analysis",
    result_class
  )
}

#' @noRd
.app_util_result_key <- function(result_class) {
  sub("^Project", "", result_class)
}

#' @noRd
.app_util_module_owner <- function(project_class, module_type) {
  module_type <- match.arg(module_type, c("analyses", "explorer", "results"))
  details <- projects_overview(project_class)
  owner <- switch(
    module_type,
    analyses = details$analyses_owner,
    explorer = details$explorer_owner,
    results = project_class
  )
  if (is.null(owner) || is.na(owner) || !nzchar(owner)) {
    owner <- project_class
  }
  owner
}

#' @noRd
.app_util_module_functions <- function(project_class, module_type, envir = parent.frame()) {
  module_type <- match.arg(module_type, c("analyses", "explorer", "results"))
  owner <- .app_util_module_owner(project_class, module_type)
  prefix <- switch(
    module_type,
    analyses = ".mod_Analyses",
    explorer = ".mod_Explorer",
    results = ".mod_Result"
  )
  namespace_env <- tryCatch(asNamespace("StreamFind"), error = function(...) envir)
  list(
    ui = get0(paste0(prefix, "_UI.", owner), mode = "function", envir = namespace_env, inherits = TRUE),
    server = get0(paste0(prefix, "_Server.", owner), mode = "function", envir = namespace_env, inherits = TRUE)
  )
}

#' @noRd
.app_util_project_results <- function(project) {
  if (is.null(project)) {
    return(list())
  }
  project_class <- class(project)[1]
  details <- projects_overview(project_class)
  result_classes <- details$result_classes
  if (is.null(result_classes)) {
    result_classes <- character()
  }
  if (length(result_classes) == 0) {
    return(list())
  }
  names(result_classes) <- vapply(result_classes, .app_util_result_key, character(1))
  lapply(result_classes, function(result_class) {
    list(
      key = .app_util_result_key(result_class),
      label = .app_util_result_label(result_class),
      class = result_class,
      object = project
    )
  })
}

#' @noRd
.app_util_results_pages <- function(project_class) {
  owner <- .app_util_module_owner(project_class, "results")
  switch(
    owner,
    ProjectNonTargetAnalysis = list(
      list(key = "summary", label = "Summary"),
      list(key = "features", label = "Features"),
      list(key = "internal_standards", label = "Internal Standards")
    ),
    ProjectMassSpecChromatograms = list(
      list(key = "chromatograms", label = "Chromatograms"),
      list(key = "peaks", label = "Peaks"),
      list(key = "summary", label = "Summary")
    ),
    list(
      list(key = "summary", label = "Summary")
    )
  )
}

#' @noRd
.app_util_explorer_pages <- function(project_class) {
  module_fns <- .app_util_module_functions(project_class, "explorer")
  if (!is.function(module_fns$ui) || !is.function(module_fns$server)) {
    return(list())
  }

  owner <- .app_util_module_owner(project_class, "explorer")
  switch(
    owner,
    ProjectMassSpec = list(
      list(key = "tic", label = "TIC"),
      list(key = "chromatograms", label = "Chromatograms"),
      list(key = "eic", label = "EIC")
    ),
    list()
  )
}

#' @noRd
.app_util_read_project_rows <- function(db) {
  checkmate::assert_file_exists(db)
  conn <- DBI::dbConnect(duckdb::duckdb(), dbdir = db, read_only = TRUE)
  on.exit(DBI::dbDisconnect(conn, shutdown = TRUE), add = TRUE)

  if (!DBI::dbExistsTable(conn, "PROJECT")) {
    stop("The selected DuckDB file does not contain a PROJECT table.", call. = FALSE)
  }

  rows <- DBI::dbGetQuery(
    conn,
    "SELECT project_id, domain, created_at FROM PROJECT ORDER BY project_id"
  )
  data.table::as.data.table(rows)
}

#' @noRd
.app_util_resolve_project_db <- function(db, registry = projects_overview()) {
  rows <- .app_util_read_project_rows(db)
  if (nrow(rows) == 0) {
    stop("The selected DuckDB file does not contain any StreamFind project rows.", call. = FALSE)
  }
  rows[, domain := trimws(as.character(domain))]
  rows <- rows[!is.na(project_id) & nzchar(trimws(project_id))]
  if (nrow(rows) == 0) {
    stop("The selected DuckDB file does not contain any valid project_id values.", call. = FALSE)
  }
  rows[, project_id := trimws(as.character(project_id))]
  rows[, project_class := vapply(domain, .project_class_from_domain, character(1), registry = registry)]

  if (anyNA(rows$project_class) || any(!nzchar(rows$project_class))) {
    bad_domains <- unique(rows$domain[is.na(rows$project_class) | !nzchar(rows$project_class)])
    stop(
      "Unable to map project domain(s) to a StreamFind project class: ",
      paste(bad_domains, collapse = ", "),
      ".",
      call. = FALSE
    )
  }

  unique_classes <- unique(rows$project_class)
  if (length(unique_classes) != 1) {
    stop(
      "The selected DuckDB file contains multiple incompatible project classes: ",
      paste(unique_classes, collapse = ", "),
      ".",
      call. = FALSE
    )
  }

  project_class <- unique_classes[[1]]
  rows[, project_label := .app_util_project_label(project_class)]
  list(
    project_class = project_class,
    project_label = .app_util_project_label(project_class),
    rows = rows
  )
}

# MARK: Initial Modal
#' @noRd
.app_util_use_initial_modal <- function(reactive_app_mode,
                                        reactive_project_class,
                                        reactive_project_db,
                                        reactive_project_id,
                                        reactive_show_init_modal,
                                        volumes,
                                        input, output, session) {

  project_registry <- projects_overview()
  available_projects <- names(project_registry)

  time_var <- format(Sys.time(), "%Y%m%d%H%M%S")

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

  model_elements <- list()

  model_elements[[1]] <- shiny::img(
    src = "www/logo_StreamFind.png",
    width = 250,
    style = "display: block; margin-left: auto; margin-right: auto; margin-bottom: 30px;"
  )

  # Color palette for tiles based on StreamFind logo (green and blue theme)
  tile_colors <- c(
    "#1e7e34", "#0066cc", "#2d9f4f", "#0052a3",
    "#27ae60", "#2874a6", "#229954", "#1f618d",
    "#16a085", "#004d99", "#0d7c2b", "#00ff99"
  )

  # Create tile container with grid layout
  tiles_content <- lapply(seq_along(available_projects), function(i) {
    obj <- available_projects[i]
    project_meta <- project_registry[[obj]]
    color <- tile_colors[(i - 1) %% length(tile_colors) + 1]
    btn_label <- project_meta$label
    shiny::column(
      4,
      shiny::div(
        shiny::actionButton(
          inputId = paste0(time_var, "_select_", obj),
          label = btn_label,
          style = paste0(
            "width: 100%; height: 120px; ",
            "background-color: ", color, "; ",
            "border: none; color: white; font-weight: bold; ",
            "font-size: 14px; border-radius: 8px; ",
            "display: flex; align-items: center; justify-content: center; ",
            "text-align: center; padding: 10px; ",
            "transition: all 0.3s ease; ",
            "box-shadow: 0 2px 4px rgba(0,0,0,0.2);"
          ),
          onmouseover = paste0(
            "this.style.boxShadow='0 4px 8px rgba(0,0,0,0.3)'; ",
            "this.style.transform='translateY(-2px)';"
          ),
          onmouseout = paste0(
            "this.style.boxShadow='0 2px 4px rgba(0,0,0,0.2)'; ",
            "this.style.transform='translateY(0)';"
          )
        ),
        shiny::p(
          project_meta$description,
          style = "margin: 10px 0 0 0; text-align: center; min-height: 40px; color: #555; font-size: 12px;"
        ),
        style = "margin-bottom: 15px;"
      )
    )
  })

  model_elements[[2]] <- shiny::fluidRow(
    do.call(shiny::tagList, tiles_content),
    style = "margin-top: 20px;"
  )

  shiny::showModal(shiny::modalDialog(
    title = " ",
    easyClose = TRUE,
    footer = shiny::tagList(shiny::modalButton("Cancel")),
    do.call(shiny::tagList, model_elements)
  ))

  lapply(available_projects, function(obj) {

    shiny::observeEvent(input[[paste0(time_var, "_select_", obj)]], {
      reactive_project_class(obj)
      shiny::removeModal()
      reactive_show_init_modal(FALSE)
      project_db_var <- paste0(time_var, "_select_ProjectDB")
      project_id_var <- paste0(time_var, "_project_id")
      shinyFiles::shinyFileSave(
        input,
        project_db_var,
        roots = volumes,
        defaultRoot = "wd",
        session = session,
        filetypes = list(duckdb = "duckdb")
      )
      shiny::showModal(shiny::modalDialog(
        title = "Open Project",
        shiny::p("Select a StreamFind DuckDB file and enter the project ID."),
        shiny::div(
          shinyFiles::shinySaveButton(
            project_db_var,
            "Choose DuckDB File",
            "Select or create a StreamFind .duckdb file",
            filename = "project",
            filetype = list(duckdb = "duckdb"),
            multiple = FALSE,
            class = "btn btn-primary"
          ),
          style = "text-align: center; margin: 32px 0 20px 0;"
        ),
        shiny::div(id = paste0(project_db_var, "_display")),
        shiny::div(
          style = "margin-top: 15px;",
          shiny::textInput(project_id_var, "Project ID", value = "default")
        ),
        footer = shiny::tagList(
          shiny::actionButton(
            paste0(project_db_var, "_confirm"),
            "Confirm",
            class = "btn btn-success"
          ),
          shiny::modalButton("Cancel")
        ),
        easyClose = FALSE
      ))
      shiny::observeEvent(input[[project_db_var]], {
        shiny::req(input[[project_db_var]])
        fileinfo <- shinyFiles::parseSavePath(volumes, input[[project_db_var]])
        if (nrow(fileinfo) > 0) {
          project_db <- normalize_duckdb_path(fileinfo$datapath[1])
          shiny::removeUI(selector = paste0("#", project_db_var, "_display > *"))
          shiny::insertUI(
            selector = paste0("#", project_db_var, "_display"),
            where = "afterBegin",
            htmltools::div(
              class = "sf-path-preview",
              project_db
            )
          )
        }
      })
      shiny::observeEvent(input[[paste0(project_db_var, "_confirm")]], {
        fileinfo <- shinyFiles::parseSavePath(volumes, input[[project_db_var]])
        project_id <- input[[project_id_var]]
        if (nrow(fileinfo) > 0 && is.character(project_id) && nzchar(trimws(project_id))) {
          reactive_project_db(normalize_duckdb_path(fileinfo$datapath[1]))
          reactive_project_id(trimws(project_id))
          reactive_app_mode("WADB")
          shiny::removeModal()
        } else {
          shiny::showNotification(
            "Please select a valid database file and project ID",
            duration = 5,
            type = "warning"
          )
        }
      })
    })
  })
}

#' Maximize button for plot
#'
#' @param plot_id ID of plot output to maximize
#' @param ns_full Namespace function for the Shiny module
#' @return A shiny tag containing the maximize button
#' @noRd
.app_util_create_maximize_button <- function(plot_id, ns_full) {
  button_id <- paste0(plot_id, "_maximize")

  shiny::tags$button(
    id = ns_full(button_id),
    class = "btn btn-sm btn-light plot-maximize-btn",
    title = "Maximize plot",
    style = "
      position: absolute;
      top: 0;
      left: 0;
      width: 25px;
      height: 25px;
      padding: 2.5px;
      display: flex;
      align-items: center;
      justify-content: center;
      z-index: 10;
    ",
    onclick = paste0("maximizePlot('", ns_full(plot_id), "', '", ns_full(button_id), "');"),
    shiny::icon("expand")
  )
}

#' Modal container for plots
#'
#' @param ns_full Namespace function for the Shiny module
#' @return A shiny tag containing the modal container
#' @noRd
.app_util_create_plot_modal <- function(ns_full) {
  shiny::tags$div(
    id = ns_full("plot_modal_container"),
    class = "modal fade plot-modal",
    tabindex = "-1",
    role = "dialog",
    'aria-hidden' = "true",

    shiny::tags$div(
      class = "modal-dialog modal-lg modal-dialog-centered",
      style = "max-width: 90%; width: 90%;",

      shiny::tags$div(
        class = "modal-content",

        shiny::tags$div(
          class = "modal-header",
          shiny::tags$h5(class = "modal-title", id = ns_full("plot_modal_title"), "Plot"),
          shiny::tags$button(
            type = "button",
            class = "close",
            'data-dismiss' = "modal",
            'aria-label' = "Close",
            shiny::tags$span('aria-hidden' = "true", HTML("×"))
          )
        ),

        shiny::tags$div(
          class = "modal-body p-0",
          id = ns_full("plot_modal_body")
        )
      )
    )
  )
}

#' JavaScript functions for plot maximization
#'
#' @return A shiny tag containing the JavaScript code
#' @noRd
.app_util_plot_maximize_js <- function() {
  shiny::tags$script(HTML("
    // Function to maximize a plot in a modal
    function maximizePlot(plotId, buttonId) {
      // Get the original plot div
      var originalPlot = document.getElementById(plotId);

      // If not found, try with the plotly class
      if (!originalPlot) {
        originalPlot = document.querySelector('.js-plotly-plot[id^=\"' + plotId + '\"]');
      }

      if (!originalPlot) {
        console.error('Plot not found:', plotId);
        return;
      }

      // Get the button element to extract plot title
      var button = document.getElementById(buttonId);
      var plotTitle = '';

      // Find the closest card header or section title
      var header = button.closest('.card-header');
      if (header) {
        plotTitle = header.textContent.trim();
      } else {
        var section = button.closest('div').querySelector('.section-title');
        if (section) {
          plotTitle = section.textContent.trim();
        } else {
          // Default title
          plotTitle = 'Plot View';
        }
      }

      // Set the modal title
      document.getElementById(plotId.replace(/[^-]*$/, 'plot_modal_title')).textContent = plotTitle;

      // Get the modal body
      var modalBody = document.getElementById(plotId.replace(/[^-]*$/, 'plot_modal_body'));

      // Clear previous content
      modalBody.innerHTML = '';

      // If it's a plotly plot
      if (originalPlot.classList.contains('js-plotly-plot')) {
        // Create a new container for the plot
        var newPlotContainer = document.createElement('div');
        newPlotContainer.id = 'modal-' + plotId;
        newPlotContainer.style.width = '100%';
        newPlotContainer.style.height = '100%';
        modalBody.appendChild(newPlotContainer);

        // Clone the plot to the modal with updated layout
        var newLayout = JSON.parse(JSON.stringify(originalPlot.layout));
        newLayout.width = null;
        newLayout.height = 800;
        newLayout.autosize = true;

        // Ensure margins allow full width usage
        newLayout.margin = {
          l: 50,
          r: 30,
          t: 30,
          b: 50
        };

        // Calculate 90% of viewport height
        var plotHeight = Math.floor(window.innerHeight * 0.9);
        newLayout.height = plotHeight;

        Plotly.newPlot(
          newPlotContainer.id,
          JSON.parse(JSON.stringify(originalPlot.data)),
          newLayout,
          {responsive: true}
        );

        // Trigger resize after modal is shown with a slight delay
        $('#' + plotId.replace(/[^-]*$/, 'plot_modal_container')).on('shown.bs.modal', function() {
          setTimeout(function() {
            Plotly.Plots.resize(newPlotContainer.id);
          }, 100);
        });
      } else {
        // For other types of plots or content
        var clone = originalPlot.cloneNode(true);
        clone.style.width = '100%';
        clone.style.height = Math.floor(window.innerHeight * 0.9) + 'px';
        modalBody.appendChild(clone);
      }

      // Show the modal
      $('#' + plotId.replace(/[^-]*$/, 'plot_modal_container')).modal('show');
    }

    // Custom CSS for the maximize button and plot modal body
    document.head.insertAdjacentHTML('beforeend', `
      <style>
        .plot-maximize-btn {
          position: absolute;
          top: 10px;
          right: 10px;
          z-index: 100;
          opacity: 0.6;
          font-size: 0.8rem;
          padding: 3px 6px;
        }
        .plot-maximize-btn:hover {
          opacity: 1;
        }
        .plot-container {
          position: relative;
        }
        /* Only apply to plot modals, not all modals */
        .plot-modal .modal-body {
          height: 90vh;
          padding: 0 !important;
        }
        .plot-modal .modal-body > div {
          width: 100% !important;
          height: 100% !important;
        }
        /* Ensure shinyFiles modals keep their default styling */
        .shinyFiles .modal-dialog {
          max-width: 900px !important;
          width: auto !important;
        }
        .shinyFiles .modal-body {
          height: auto !important;
          max-height: 70vh !important;
          overflow-y: auto !important;
          padding: 15px !important;
        }
        .shinyFiles .modal-body > div {
          width: auto !important;
          height: auto !important;
        }
        .shinyFiles {
          z-index: 1060 !important;
        }
      </style>
    `);
  "))
}
