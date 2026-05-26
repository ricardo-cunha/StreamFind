#' The application User-Interface
#'
#' @param request Internal parameter for `{shiny}`.
#'
#' @noRd
app_ui <- function(request) {
  init_project_path <- golem::get_golem_options("projectPath")
  init_project_db <- golem::get_golem_options("db")
  init_project_id <- golem::get_golem_options("project_id")
  init_project_class <- golem::get_golem_options("project_class")
  init_project_object <- golem::get_golem_options("project_object")

  has_initial_project_context <- (
    inherits(init_project_object, "Project") ||
      (!is.null(init_project_db) && !is.na(init_project_db) && nzchar(init_project_db)) ||
      (!is.null(init_project_id) && !is.na(init_project_id) && nzchar(init_project_id)) ||
      (!is.null(init_project_class) && !is.na(init_project_class) && nzchar(init_project_class))
  )

  boot_loading <- (
    (!is.null(init_project_path) && !is.na(init_project_path) && dir.exists(init_project_path)) ||
      isTRUE(has_initial_project_context)
  )

  shiny::tagList(
    golem_add_external_resources(),
    htmltools::div(
      id = "sf-app", class = "sf-light",
      # ---- Top bar (logo + horizontal nav + right controls) ----
      htmltools::div(
        id = "sf-topbar",
        htmltools::div(
          id = "sf-logo",
          htmltools::tags$img(
            src = "www/logo_StreamFind.png"
          )
        ),
        # ---- Horizontal navigation (replaces sidebar) ----
        htmltools::div(
          id = "sf-nav",
          # Home
          htmltools::div(class = "sf-nav-group active", `data-tab` = "home",
            htmltools::tags$button(class = "sf-nav-btn active", `data-tab` = "home", title = "Home",
              shiny::icon("home"))
          ),
          # Project
          htmltools::div(class = "sf-nav-group", `data-tab` = "project",
            htmltools::tags$button(class = "sf-nav-btn", `data-tab` = "project", title = "Project",
              "Project")
          ),
          # Analyses
          htmltools::div(class = "sf-nav-group", `data-tab` = "analyses",
            htmltools::tags$button(class = "sf-nav-btn", `data-tab` = "analyses", title = "Analyses",
              "Analyses")
          ),
          # Explorer
          htmltools::div(class = "sf-nav-group", `data-tab` = "explorer",
            htmltools::tags$button(class = "sf-nav-btn", `data-tab` = "explorer", title = "Explorer",
              "Explorer")
          ),
          # Workflow
          htmltools::div(class = "sf-nav-group", `data-tab` = "workflow",
            htmltools::tags$button(class = "sf-nav-btn", `data-tab` = "workflow", title = "Workflow",
              "Workflow")
          ),
          # Results
          htmltools::div(class = "sf-nav-group", `data-tab` = "results",
            htmltools::tags$button(class = "sf-nav-btn", `data-tab` = "results", title = "Results",
              "Results")
          ),
          # Report
          htmltools::div(class = "sf-nav-group", `data-tab` = "report",
            htmltools::tags$button(class = "sf-nav-btn", `data-tab` = "report", title = "Report",
              "Report")
          ),
          # Audit Trail
          htmltools::div(class = "sf-nav-group", `data-tab` = "audit",
            htmltools::tags$button(class = "sf-nav-btn", `data-tab` = "audit", title = "Audit Trail",
              "Audit Trail")
          ),
          
        ),
        htmltools::div(
          id = "sf-topbar-right",
          shiny::uiOutput("project_data_type"),
          shiny::uiOutput("notifications_ui"),
          shiny::uiOutput("settings_dropdown_ui")
        )
      ),
      shiny::uiOutput("subtopbar_ui"),
      # ---- Body = full-width content (no sidebar) ----
      htmltools::div(
        id = "sf-body",
        # Content area: one .sf-page div per tab, shown via conditionalPanel
        htmltools::div(
          id = "sf-content",
          htmltools::div(
            id = "sf-boot-overlay",
            class = if (isTRUE(boot_loading)) "sf-boot-overlay visible" else "sf-boot-overlay",
            htmltools::div(
              class = "sf-boot-overlay-inner",
              htmltools::tags$img(
                src = "www/logo_StreamFind.png",
                alt = "StreamFind loading"
              )
            )
          ),
          shiny::conditionalPanel(
            "input.sf_active_tab === 'home' || !input.sf_active_tab",
            htmltools::div(class = "sf-page", shiny::uiOutput("home_ui"))
          ),
          shiny::conditionalPanel(
            "input.sf_active_tab === 'project'",
            htmltools::div(class = "sf-page", shiny::uiOutput("project_ui"))
          ),
          shiny::conditionalPanel(
            "input.sf_active_tab === 'analyses'",
            htmltools::div(class = "sf-page", shiny::uiOutput("analyses_ui"))
          ),
          shiny::conditionalPanel(
            "input.sf_active_tab === 'explorer'",
            htmltools::div(class = "sf-page", shiny::uiOutput("explorer_ui"))
          ),
          shiny::conditionalPanel(
            "input.sf_active_tab === 'workflow'",
            htmltools::div(class = "sf-page", shiny::uiOutput("workflow_ui"))
          ),
          shiny::conditionalPanel(
            "input.sf_active_tab === 'results'",
            htmltools::div(class = "sf-page", shiny::uiOutput("results_ui"))
          ),
          shiny::conditionalPanel(
            "input.sf_active_tab === 'report'",
            htmltools::div(class = "sf-page", shiny::uiOutput("report_ui"))
          ),
          shiny::conditionalPanel(
            "input.sf_active_tab === 'audit'",
            htmltools::div(class = "sf-page", shiny::uiOutput("audit_ui"))
          ),
          
        )
      )
    )
  )
}

#' Add external Resources to the Application
#'
#' This function is internally used to add external
#' resources inside the Shiny application.
#'
#' @noRd
golem_add_external_resources <- function() {
  golem::add_resource_path(
    "www",
    app_sys("app/www")
  )

  htmltools::tags$head(
    golem::favicon(ext = "png"),
    htmltools::tags$link(
      rel = "icon",
      type = "image/png",
      href = "favicon.png"
    ),
    # Bootstrap 3.4.1 CSS — required for shinyFiles, modal layout,
    # glyphicons, and Bootstrap grid/button styling when not using fluidPage().
    shiny::singleton(
      htmltools::tags$link(
        rel = "stylesheet",
        type = "text/css",
        href = "shared/bootstrap/css/bootstrap.min.css"
      )
    ),
    golem::bundle_resources(
      path = app_sys("app/www"),
      app_title = "StreamFind"
    ),
    # Bootstrap 3.4.1 JS (jQuery plugin) — Shiny ships Bootstrap 3 CSS but
    # doesn't auto-load its JS when the UI is built with raw htmltools::div().
    # shiny::showModal(), shinyFiles, and other components call $.fn.modal()
    # which comes from this JS.
    shiny::singleton(
      htmltools::tags$script(src = "shared/bootstrap/js/bootstrap.min.js")
    ),
    # Navigation + theme toggle JS
    shiny::tags$script(htmltools::HTML("
      // sfNavigate: activate a main tab
      function sfNavigate(tab, subtab) {
        Shiny.setInputValue('sf_active_tab', tab, {priority: 'event'});

        document.querySelectorAll('#sf-nav .sf-nav-group').forEach(function(grp) {
          grp.classList.toggle('active', grp.getAttribute('data-tab') === tab);
        });

        document.querySelectorAll('#sf-nav .sf-nav-btn').forEach(function(btn) {
          btn.classList.toggle('active', btn.getAttribute('data-tab') === tab);
        });

        if (typeof subtab === 'string') {
          sfSubNavigate(tab, subtab);
        }
      }

      // sfSubNavigate: switch sub-tab on the second topbar
      function sfSubNavigate(tab, subtab) {
        Shiny.setInputValue('sf_active_tab', tab, {priority: 'event'});
        Shiny.setInputValue('sf_active_subtab', subtab, {priority: 'event'});

        document.querySelectorAll('#sf-nav .sf-nav-group').forEach(function(grp) {
          grp.classList.toggle('active', grp.getAttribute('data-tab') === tab);
        });

        document.querySelectorAll('#sf-nav .sf-nav-btn').forEach(function(btn) {
          btn.classList.toggle('active', btn.getAttribute('data-tab') === tab);
        });

        document.querySelectorAll('#sf-subtopbar .sf-subbar-btn').forEach(function(btn) {
          btn.classList.toggle('active',
            btn.getAttribute('data-tab') === tab &&
            btn.getAttribute('data-subtab') === subtab);
        });
      }

      // Event delegation on nav bars
      document.addEventListener('DOMContentLoaded', function() {
        document.getElementById('sf-nav').addEventListener('click', function(e) {
          var mainBtn = e.target.closest('.sf-nav-btn');
          if (mainBtn) {
            var tab = mainBtn.getAttribute('data-tab');
            sfNavigate(tab);
          }
        });

        document.addEventListener('click', function(e) {
          var subBtn = e.target.closest('#sf-subtopbar .sf-subbar-btn');
          if (subBtn) {
            sfSubNavigate(subBtn.getAttribute('data-tab'), subBtn.getAttribute('data-subtab'));
          }
        });
      });

      // Apply mode/style to the app root and body so shared CSS and modals stay in sync.
      Shiny.addCustomMessageHandler('setAppTheme', function(msg) {
        var app = document.getElementById('sf-app');
        if (app) {
          var mode = (msg && msg.mode) ? msg.mode : 'light';
          var palette = (msg && msg.palette) ? msg.palette : 'lagoon';
          app.classList.remove('sf-light', 'sf-dark');
          app.classList.add(mode === 'dark' ? 'sf-dark' : 'sf-light');
          app.setAttribute('data-sf-palette', palette);
          document.body.setAttribute('data-sf-theme', mode);
          document.body.setAttribute('data-sf-palette', palette);
        }
      });

      Shiny.addCustomMessageHandler('setActiveTab', function(msg) {
        if (!msg || !msg.tab) return;
        sfNavigate(msg.tab, msg.subtab || null);
      });

      Shiny.addCustomMessageHandler('setBootOverlay', function(msg) {
        var overlay = document.getElementById('sf-boot-overlay');
        if (!overlay) return;
        if (msg && msg.visible) {
          overlay.classList.add('visible');
        } else {
          overlay.classList.remove('visible');
        }
      });

      function sfShowBootOverlay() {
        var overlay = document.getElementById('sf-boot-overlay');
        if (overlay) overlay.classList.add('visible');
      }

      function sfHideBootOverlay() {
        var overlay = document.getElementById('sf-boot-overlay');
        if (overlay) overlay.classList.remove('visible');
      }

      // Hard cleanup for restart flow: remove any residual modal/backdrop nodes
      // (including shinyFiles custom containers) and clear body modal flags.
      Shiny.addCustomMessageHandler('cleanupAllModals', function(msg) {
        document.querySelectorAll('.sF-modalContainer, .sF-modalBackdrop, .modal-backdrop').forEach(function(el) {
          if (el && el.parentNode) {
            el.parentNode.removeChild(el);
          }
        });

        var shinyModal = document.getElementById('shiny-modal');
        if (shinyModal) {
          shinyModal.classList.remove('in', 'show');
          shinyModal.style.display = 'none';
        }

        document.body.classList.remove('modal-open');
      });

      // Ensure Shiny's modal wrapper is always rendered as a floating overlay.
      // This guards against missing Bootstrap modal CSS in custom page layouts.
      function enforceShinyModalFloating() {
        var wrapper = document.getElementById('shiny-modal-wrapper');
        var modal = document.getElementById('shiny-modal');
        if (!wrapper || !modal) return;

        wrapper.style.position = 'fixed';
        wrapper.style.top = '0';
        wrapper.style.right = '0';
        wrapper.style.bottom = '0';
        wrapper.style.left = '0';
        wrapper.style.zIndex = '1060';

        modal.style.position = 'fixed';
        modal.style.top = '0';
        modal.style.right = '0';
        modal.style.bottom = '0';
        modal.style.left = '0';
        modal.style.zIndex = '1060';
        modal.style.display = 'flex';
        modal.style.alignItems = 'center';
        modal.style.justifyContent = 'center';
        modal.style.padding = '16px';
        modal.style.overflowX = 'hidden';
        modal.style.overflowY = 'auto';

        var dialog = modal.querySelector('.modal-dialog');
        if (dialog) {
          dialog.style.margin = '0';
          dialog.style.width = 'min(640px, calc(100vw - 32px))';
          dialog.style.maxWidth = '640px';
        }
      }

      document.addEventListener('DOMContentLoaded', function() {
        enforceShinyModalFloating();
        var obs = new MutationObserver(function() {
          enforceShinyModalFloating();
        });
        obs.observe(document.body, { childList: true, subtree: true });

        document.addEventListener('click', function(e) {
          var trigger = e.target.closest(
            '#create_project_confirm, #open_project_confirm'
          );
          if (trigger) {
            sfShowBootOverlay();
          }
        });
      });

      // Init body theme attribute on page load
      document.addEventListener('DOMContentLoaded', function() {
        var app = document.getElementById('sf-app');
        if (app) {
          document.body.setAttribute('data-sf-theme', app.classList.contains('sf-dark') ? 'dark' : 'light');
          document.body.setAttribute('data-sf-palette', app.getAttribute('data-sf-palette') || 'lagoon');
        }
      });

      // Notification bell: close dropdown when clicking outside
      document.addEventListener('click', function(e) {
        var wrapper = document.querySelector('.sf-notif-wrapper');
        if (wrapper && !wrapper.contains(e.target)) {
          var dd = document.getElementById('sf-notif-dropdown');
          if (dd) dd.classList.remove('open');
        }

        var settingsWrapper = document.querySelector('.sf-settings-wrapper');
        if (settingsWrapper && !settingsWrapper.contains(e.target)) {
          var settingsDd = document.getElementById('sf-settings-dropdown');
          if (settingsDd) settingsDd.classList.remove('open');
        }
      });
    "))
  )
}
