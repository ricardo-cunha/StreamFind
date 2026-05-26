## MARK: .mod_Result_UI.ProjectNonTargetAnalysis
##' @export
##' @noRd
.mod_Result_UI.ProjectNonTargetAnalysis <- function(x, id, ns) {
  ns2 <- shiny::NS(id)
  ns_full <- function(name) ns(ns2(name))

  # MARK: Custom CSS
  custom_css <- shiny::tags$style(
    shiny::HTML(
      "
    .status-panel {
      background: transparent;
      border: none;
      border-radius: 0;
      box-shadow: none;
      padding: 8px 12px;
      height: 100%;
    }
    .status-item {
      display: flex;
      justify-content: space-between;
      padding: 6px 0;
      border-bottom: 1px solid rgba(0,0,0,0.05);
    }
    .status-item:last-child {
      border-bottom: none;
    }
    .status-label {
      font-weight: 400;
    }
    .status-value {
      font-weight: 600;
    }
    .status-yes {
      color: #28a745;
    }
    .status-no {
      color: #dc3545;
    }
    .tab-content {
      padding: 0;
    }
    .sf-nta-results-root {
      height: calc(100dvh - var(--sf-topbar-height, 36px) - var(--sf-subtopbar-height, 36px) - 10px);
      min-height: 0;
      display: flex;
      flex-direction: column;
      overflow: hidden;
      background: transparent;
    }
    .sf-nta-results-root > .tab-content {
      height: 100%;
      min-height: 0;
      display: flex;
      flex-direction: column;
      overflow: hidden;
      background: transparent;
    }
    .sf-nta-results-root .bslib-sidebar-layout,
    .sf-nta-results-root .bslib-sidebar-layout > .main,
    .sf-nta-results-root .bslib-sidebar-layout > .sidebar {
      min-height: 0;
      height: 100% !important;
      background: transparent !important;
      box-shadow: none !important;
      border: none !important;
    }
    .sf-nta-results-summary .bslib-sidebar-layout,
    .sf-nta-results-features .bslib-sidebar-layout {
      flex: 1 1 auto;
      display: flex;
      min-height: 0;
      overflow: hidden;
    }
    .sf-nta-results-summary .bslib-sidebar-layout > .main,
    .sf-nta-results-features .bslib-sidebar-layout > .main {
      flex: 1 1 auto;
      display: flex;
      flex-direction: column;
      min-height: 0;
      overflow: hidden;
    }
    .sf-nta-results-summary .bslib-sidebar-layout > .sidebar,
    .sf-nta-results-features .bslib-sidebar-layout > .sidebar {
      overflow: auto;
    }
    .sf-nta-summary-main {
      flex: 1 1 auto;
      height: 100%;
      min-height: 0;
      display: flex;
      flex-direction: column;
      background: transparent;
    }
    .sf-nta-summary-main > .features-controls-bar {
      flex: 0 0 60px;
    }
    .sf-nta-summary-plot {
      flex: 1 1 auto;
      min-height: 0;
      background: transparent;
      padding: 5px;
      display: flex;
      flex-direction: column;
      overflow: hidden;
      position: relative;
    }
    .sf-nta-summary-plot .shiny-plot-output,
    .sf-nta-summary-plot .plotly,
    .sf-nta-summary-plot .js-plotly-plot,
    .sf-nta-summary-plot .html-widget {
      flex: 1 1 auto;
      min-height: 0;
      height: 100% !important;
    }
    .nav-tabs {
      border-bottom: 2px solid #e3e6f0;
    }
    .nav-tabs .nav-link.active {
      border-color: transparent;
      border-bottom: 3px solid #222d32;
      font-weight: 600;
    }
    .nav-tabs .nav-link {
      border: none;
      color: #5a5c69;
      padding: 2px 8px;
    }
    .nav-tabs .nav-link:hover {
      border-color: transparent;
      border-bottom: 3px solid #555;
    }
    .suspects-table td {
      vertical-align: top;
      padding-top: 12px !important;
      padding-bottom: 12px !important;
    }
    .suspects-table tbody tr,
    .suspects-table tbody tr td,
    table.dataTable.display tbody tr,
    table.dataTable.display tbody tr td,
    table.dataTable.stripe tbody tr.odd,
    table.dataTable.stripe tbody tr.even,
    table.dataTable.stripe tbody tr.odd td,
    table.dataTable.stripe tbody tr.even td {
      background-color: var(--sf-content-bg, #ffffff) !important;
      color: var(--sf-content-color, #333333) !important;
    }
    .suspects-table tbody tr.selected,
    .suspects-table tbody tr.selected td {
      color: #000000 !important;
    }
    .suspect-structure-img {
      width: 140px;
      height: 120px;
      object-fit: contain;
      display: block;
    }
    .suspect-spectra-img {
      width: 360px;
      height: 200px;
      object-fit: contain;
      display: block;
    }
    .plot-container {
      border-radius: 0;
      background: transparent;
      padding: 0;
      box-shadow: none;
    }
    .nav-tabs-custom {
      margin-bottom: 0px;
    }
    .features-controls-bar {
      background: transparent;
      border: none;
      box-shadow: none;
      padding: 10px 15px;
      height: 60px;
      display: flex;
      align-items: center;
      justify-content: space-between;
    }
    .features-controls-bar .shiny-input-container {
      margin-bottom: 0;
      display: flex;
      align-items: center;
    }
    .features-controls-bar .checkbox {
      margin: 0;
      display: flex;
      align-items: center;
    }
    .features-controls-bar .checkbox input {
      margin-right: 4px;
    }
    .sf-nta-features-layout {
      display: flex;
      flex: 1 1 auto;
      min-height: 0;
      overflow: hidden;
      gap: 0;
    }
    .sf-nta-results-features > .features-controls-bar {
      flex: 0 0 60px;
    }
    .sf-nta-features-plot-pane {
      min-width: 0;
      flex: 1 1 auto;
      padding: 10px;
      min-height: 0;
      overflow: hidden;
      display: flex;
      flex-direction: column;
      background: transparent;
    }
    .sf-nta-features-details-pane {
      min-width: 340px;
      padding: 10px;
      min-height: 0;
      overflow: hidden;
      background: transparent;
    }
    .sf-nta-feature-pane-shell {
      display: flex;
      flex: 1 1 auto;
      min-height: 0;
      min-width: 0;
      overflow: hidden;
      gap: 10px;
    }
    .sf-nta-feature-filter-sidebar {
      flex: 0 0 0;
      width: 0;
      min-width: 0;
      padding: 0;
      overflow: hidden;
      opacity: 0;
      transition: width 0.16s ease, opacity 0.16s ease, padding 0.16s ease;
      background: transparent;
    }
    .sf-nta-feature-filter-sidebar.open {
      flex-basis: 320px;
      width: 320px;
      min-width: 320px;
      padding: 5px;
      opacity: 1;
      overflow: auto;
    }
    .sf-nta-feature-filter-sidebar .form-group,
    .sf-nta-feature-filter-sidebar .shiny-input-container {
      margin-bottom: 10px;
    }
    .sf-nta-feature-plot-shell {
      flex: 1 1 auto;
      min-width: 0;
      min-height: 0;
      display: flex;
      flex-direction: column;
      overflow: hidden;
      background: transparent;
    }
    .sf-nta-feature-plot-holder {
      flex: 1 1 auto;
      min-width: 0;
      min-height: 0;
      display: flex;
      overflow: hidden;
      background: transparent;
      position: relative;
    }
    .sf-nta-loading-surface.loading::after {
      content: '';
      position: absolute;
      inset: 0;
      z-index: 8100;
      pointer-events: none;
      background-color: rgba(255, 255, 255, 0.96);
      background-image: url('/www/logo_StreamFind.png');
      background-repeat: no-repeat;
      background-position: center center;
      background-size: auto 70%;
      animation: sf-logo-pulse 1.2s ease-in-out infinite;
    }
    .sf-nta-feature-plot-holder .plotly,
    .sf-nta-feature-plot-holder .js-plotly-plot,
    .sf-nta-feature-plot-holder .html-widget,
    .sf-nta-feature-plot-holder .shiny-plot-output {
      flex: 1 1 auto;
      min-width: 0;
      min-height: 0;
      height: 100% !important;
      width: 100% !important;
    }
    .sf-nta-details-tabs {
      height: 100%;
      min-height: 0;
    }
    .sf-nta-details-tabs > .tabbable {
      height: 100%;
      min-height: 0;
      display: flex;
      flex-direction: column;
    }
    .sf-nta-details-tabs > .tabbable > .nav,
    .sf-nta-details-tabs > .tabbable > .nav-tabs {
      flex: 0 0 auto;
      display: flex;
      flex-wrap: nowrap;
      overflow-x: auto;
      overflow-y: hidden;
      white-space: nowrap;
    }
    .sf-nta-details-tabs > .tabbable > .nav-tabs > li {
      flex: 0 0 auto;
    }
    .sf-nta-details-tabs > .tabbable > .tab-content {
      flex: 1 1 auto;
      min-height: 0;
      overflow: hidden;
    }
    .sf-nta-details-tabs > .tabbable > .tab-content > .tab-pane,
    .sf-nta-details-tabs > .tabbable > .tab-content > .tab-pane.active {
      height: 100%;
      min-height: 0;
      overflow: hidden;
      padding: 0;
    }
    .sf-nta-plot-panel {
      height: 100%;
      min-height: 0;
      display: flex;
      flex-direction: column;
      background: transparent;
    }
    .sf-nta-plot-toolbar {
      flex: 0 0 30px;
      height: 30px;
      position: relative;
    }
    .sf-nta-plot-body {
      flex: 1 1 auto;
      min-height: 0;
      background: transparent;
      display: flex;
      overflow: hidden;
    }
    .sf-nta-plot-body .shiny-plot-output,
    .sf-nta-plot-body .plotly,
    .sf-nta-plot-body .js-plotly-plot,
    .sf-nta-plot-body .html-widget {
      flex: 1 1 auto;
      min-height: 0;
      height: 100% !important;
    }
    .sf-nta-table-panel {
      height: 100%;
      min-height: 0;
      overflow: auto;
      padding: 12px;
      background: transparent;
    }
    "
    )
  )

  custom_js <- shiny::tags$script(
    shiny::HTML(
      sprintf(
        "
        (function() {
          if (window.__sfNtaResultsResizeRegistered) return;
          window.__sfNtaResultsResizeRegistered = true;
          window.__sfNtaPlotlyObservers = window.__sfNtaPlotlyObservers || {};
          window.__sfNtaLoadingObservers = window.__sfNtaLoadingObservers || {};

          var resolvePlotEl = function(id) {
            var root = document.getElementById(id);
            if (!root) return null;
            return root.querySelector('.js-plotly-plot') || root;
          };

          var resizeIds = function(ids) {
            if (!Array.isArray(ids)) return;
            ids.forEach(function(id) {
              var el = resolvePlotEl(id);
              if (el && window.Plotly && window.Plotly.Plots) {
                try { window.Plotly.relayout(el, {autosize: true}); } catch (e) {}
                try { window.Plotly.Plots.resize(el); } catch (e) {}
              }
            });
          };

          var observeIds = function(ids) {
            if (!window.ResizeObserver || !Array.isArray(ids)) return;
            ids.forEach(function(id) {
              var root = document.getElementById(id);
              if (!root) return;
              if (window.__sfNtaPlotlyObservers[id]) {
                try { window.__sfNtaPlotlyObservers[id].disconnect(); } catch (e) {}
              }
              var observer = new ResizeObserver(function() {
                window.requestAnimationFrame(function() {
                  resizeIds([id]);
                  setTimeout(function() { resizeIds([id]); }, 80);
                });
              });
              observer.observe(root);
              window.__sfNtaPlotlyObservers[id] = observer;
            });
          };

          var bindLoadingSurface = function(outputId, surfaceId) {
            var output = document.getElementById(outputId);
            var surface = document.getElementById(surfaceId);
            if (!output || !surface) return;

            var syncLoading = function() {
              surface.classList.toggle('loading', output.classList.contains('recalculating'));
            };

            syncLoading();

            if (window.__sfNtaLoadingObservers[outputId]) {
              try { window.__sfNtaLoadingObservers[outputId].disconnect(); } catch (e) {}
            }

            var observer = new MutationObserver(function() {
              syncLoading();
            });
            observer.observe(output, { attributes: true, attributeFilter: ['class'] });
            window.__sfNtaLoadingObservers[outputId] = observer;
          };

          Shiny.addCustomMessageHandler('sf-plotly-resize', function(message) {
            if (!message || !Array.isArray(message.ids)) return;
            var ids = message.ids;
            window.requestAnimationFrame(function() {
              observeIds(ids);
              resizeIds(ids);
              setTimeout(function() { resizeIds(ids); }, 120);
              setTimeout(function() { resizeIds(ids); }, 320);
            });
          });

          Shiny.addCustomMessageHandler('sf-nta-feature-layout', function(message) {
            if (!message) return;
            var left = document.getElementById(message.left_id || '');
            var right = document.getElementById(message.right_id || '');
            var sidebar = document.getElementById(message.sidebar_id || '');
            var toggleBtn = document.getElementById(message.toggle_id || '');
            if (left && typeof message.left_basis === 'number') {
              left.style.flex = '0 0 calc(' + message.left_basis + '%% - 10px)';
              left.style.maxWidth = 'calc(' + message.left_basis + '%% - 10px)';
            }
            if (right && typeof message.right_basis === 'number') {
              right.style.flex = '0 0 calc(' + message.right_basis + '%% - 10px)';
              right.style.maxWidth = 'calc(' + message.right_basis + '%% - 10px)';
            }
            if (sidebar) {
              if (message.filters_open) sidebar.classList.add('open');
              else sidebar.classList.remove('open');
            }
            if (toggleBtn && typeof message.toggle_label === 'string') {
              var labelNode = toggleBtn.querySelector('.sf-nta-toggle-label');
              if (labelNode) labelNode.textContent = message.toggle_label;
            }
            if (Array.isArray(message.prop_button_ids)) {
              message.prop_button_ids.forEach(function(id) {
                var btn = document.getElementById(id);
                if (!btn) return;
                if (id === message.active_prop_button_id) btn.classList.add('active');
                else btn.classList.remove('active');
              });
            }
          });

          $(document).on('shown.bs.tab', '#%s li a[data-toggle=\"tab\"]', function() {
            var ids = [
              '%s', '%s', '%s', '%s', '%s', '%s'
            ];
            setTimeout(function() {
              observeIds(ids);
              resizeIds(ids);
            }, 80);
          });

          var initLoadingSurfaces = function() {
            bindLoadingSurface('%s', '%s');
            bindLoadingSurface('%s', '%s');
          };

          document.addEventListener('DOMContentLoaded', function() {
            setTimeout(initLoadingSurfaces, 0);
            setTimeout(initLoadingSurfaces, 250);
          });

          setTimeout(initLoadingSurfaces, 0);
          setTimeout(initLoadingSurfaces, 250);
        })();
        ",
        ns_full("feature_scatter_details_tabs"),
        ns_full("features_scatter_plot"),
        ns_full("feature_peaks_plot_scatter"),
        ns_full("feature_xic_plot_scatter"),
        ns_full("feature_profile_plot_scatter"),
        ns_full("feature_ms1_plot_scatter"),
        ns_full("feature_ms2_plot_scatter"),
        ns_full("features_chart"),
        ns_full("features_chart_surface"),
        ns_full("features_scatter_plot"),
        ns_full("features_scatter_surface")
      )
    )
  )

  shiny::tagList(
    custom_css,
    custom_js,
    .app_util_plot_maximize_js(),
    .app_util_create_plot_modal(ns_full),
    shiny::conditionalPanel(
      "input.sf_active_subtab === 'summary'",
        shiny::div(
          class = "sf-nta-results-root sf-nta-results-summary tab-content",
          bslib::layout_sidebar(
            sidebar = bslib::sidebar(
              shiny::div(
                class = "status-panel",
                shiny::div(
                  class = "status-item",
                  shiny::span(
                    class = "status-label",
                    shiny::icon("chart-line", class = "mr-2"),
                    "Total Analyses"
                  ),
                  shiny::span(
                    class = "status-value",
                    shiny::textOutput(ns_full("total_analyses"), inline = TRUE)
                  )
                ),
                shiny::div(
                  class = "status-item",
                  shiny::span(
                    class = "status-label",
                    shiny::icon("gears", class = "mr-2"),
                    "Total Features"
                  ),
                  shiny::span(
                    class = "status-value",
                    shiny::textOutput(ns_full("total_features"), inline = TRUE)
                  )
                ),
                shiny::div(
                  class = "status-item",
                  shiny::span(
                    class = "status-label",
                    shiny::icon("filter", class = "mr-2"),
                    "Filtered Features"
                  ),
                  shiny::span(
                    class = "status-value",
                    shiny::textOutput(ns_full("filtered_features_count"), inline = TRUE)
                  )
                ),
                shiny::div(
                  class = "status-item",
                  shiny::span(
                    class = "status-label",
                    shiny::icon("network-wired", class = "mr-2"),
                    "Total Groups"
                  ),
                  shiny::span(
                    class = "status-value",
                    shiny::textOutput(ns_full("total_groups"), inline = TRUE)
                  )
                ),
                shiny::div(
                  class = "status-item",
                  shiny::span(
                    class = "status-label",
                    shiny::icon("wave-square", class = "mr-2"),
                    "Has EIC?"
                  ),
                  shiny::span(
                    class = "status-value",
                    shiny::uiOutput(ns_full("has_features_eic_ui"), inline = TRUE)
                  )
                ),
                shiny::div(
                  class = "status-item",
                  shiny::span(
                    class = "status-label",
                    shiny::icon("chart-bar", class = "mr-2"),
                    "Has MS1?"
                  ),
                  shiny::span(
                    class = "status-value",
                    shiny::uiOutput(ns_full("has_features_ms1_ui"), inline = TRUE)
                  )
                ),
                shiny::div(
                  class = "status-item",
                  shiny::span(
                    class = "status-label",
                    shiny::icon("chart-area", class = "mr-2"),
                    "Has MS2?"
                  ),
                  shiny::span(
                    class = "status-value",
                    shiny::uiOutput(ns_full("has_features_ms2_ui"), inline = TRUE)
                  )
                ),
                shiny::div(
                  class = "status-item",
                  shiny::span(
                    class = "status-label",
                    shiny::icon("list-check", class = "mr-2"),
                    "Suspects"
                  ),
                  shiny::span(
                    class = "status-value",
                    shiny::uiOutput(ns_full("has_features_suspects_ui"), inline = TRUE)
                  )
                ),
                shiny::div(
                  class = "status-item",
                  shiny::span(
                    class = "status-label",
                    shiny::icon("vial", class = "mr-2"),
                    "Internal Standards"
                  ),
                  shiny::span(
                    class = "status-value",
                    shiny::uiOutput(ns_full("internal_standards_assigned_ui"), inline = TRUE)
                  )
                )
              )
            ),
              shiny::div(
                class = "sf-nta-summary-main",
                shiny::div(
                  class = "features-controls-bar",
                  style = "display: flex; align-items: center; justify-content: space-between;",
                  shiny::div(
                    style = "display: flex; align-items: center; gap: 10px; flex-wrap: wrap;",
                    shiny::div(
                      style = "display: flex; align-items: center; gap: 8px; flex-wrap: wrap;",
                      shiny::span("Group by:", style = "font-weight: 500;"),
                      shiny::div(
                        style = "display: flex; align-items: center;",
                        shiny::radioButtons(
                          ns_full("chart_color_by"),
                          label = NULL,
                          choices = c("Analysis" = "analysis", "Replicate" = "replicate"),
                          selected = "analysis",
                          inline = TRUE
                        )
                      )
                    )
                  )
                ),
                shiny::div(
                  id = ns_full("features_chart_surface"),
                  class = "position-relative sf-nta-summary-plot sf-nta-loading-surface",
                  .app_util_create_maximize_button("features_chart", ns_full),
                  plotly::plotlyOutput(ns_full("features_chart"), height = "100%")
                )
            )
          )
        )
    ),
    shiny::conditionalPanel(
      "input.sf_active_subtab === 'features'",
      shiny::uiOutput(ns_full("features_results_ui"))
    )
  )
}

# MARK: .mod_Result_Server.ProjectNonTargetAnalysis
##' @export
##' @noRd
.mod_Result_Server.ProjectNonTargetAnalysis <- function(
    x,
    id,
    ns,
    reactive_analyses,
    reactive_volumes) {
  shiny::moduleServer(id, function(input, output, session) {
    ns_full <- session$ns

    # Helpers and Data Reactives ------

    # MARK: Helpers
    status_tag <- function(value) {
      shiny::tags$span(
        class = ifelse(value, "status-yes", "status-no"),
        ifelse(value, "YES", "NO")
      )
    }

    # MARK: nta_data
    nta_data <- shiny::reactiveVal()

    shiny::observe({
      shiny::validate(shiny::need(!is.null(x), "NTA data is not available"))
      nta_data(x)
    })

    # MARK: features_data
    features_data <- shiny::reactive({
      nts <- nta_data()
      fts <- data.table::as.data.table(get_features(nts, filtered = TRUE))
      if (nrow(fts) == 0) return(fts)
      digits_for_col <- function(col) {
        col_lower <- tolower(col)
        digits <- 4
        if (col_lower %in% c("ppm", "sn")) digits <- 1
        if (col_lower %in% c("gaussian_sigma")) digits <- 1
        if (col_lower %in% c("gaussian_mu", "gaussian_a")) digits <- 0
        if (col_lower == "fwhm_mz") digits <- 4
        mz_in_col <- grepl("^mz", col_lower) || grepl("mzmin|mzmax|mass", col_lower)
        if (mz_in_col) digits <- 4
        no_decimals <- grepl("intensity|area|size|noise|plates", col_lower)
        no_decimals <- no_decimals || grepl("^rt", col_lower)
        no_decimals <- no_decimals || (grepl("width|fwhm", col_lower) && col_lower != "fwhm_mz")
        if (no_decimals) digits <- 0
        if (grepl("gaussian_r2|correction|jaggedness|sharpness|asymmetry", col_lower)) digits <- 2
        digits
      }
      num_cols <- names(fts)[sapply(fts, is.numeric)]
      for (col in num_cols) {
        d <- digits_for_col(col)
        fts[[col]] <- round(fts[[col]], d)
      }
      fts
    })

    has_features <- shiny::reactive({
      nrow(features_data()) > 0
    })

    output$features_results_ui <- shiny::renderUI({
      if (!isTRUE(has_features())) {
        return(
          htmltools::div(
            class = "sf-empty-state",
            htmltools::div(
              class = "sf-page-title-block",
              htmltools::tags$h3(class = "sf-page-title", "No Features Available"),
              htmltools::tags$p(
                class = "sf-page-subtitle",
                "Run the FindFeatures method in the Workflow tab."
              )
            )
          )
        )
      }

      shiny::div(
        class = "sf-nta-results-root sf-nta-results-features tab-content",
        shiny::div(
          class = "features-controls-bar",
          style = "display: flex; align-items: center; justify-content: space-between;",
          shiny::div(
            style = "display: flex; align-items: center; gap: 10px; flex-wrap: wrap;",
            shiny::actionButton(
              ns_full("toggle_scatter_filters"),
              label = shiny::tagList(
                shiny::icon("sliders"),
                shiny::tags$span(class = "sf-nta-toggle-label", "Show Filters")
              ),
              class = "btn btn-outline-primary btn-sm"
            ),
            shiny::div(
              style = "display: flex; align-items: center; gap: 8px; flex-wrap: wrap;",
              shiny::span("Group by:", style = "font-weight: 500;"),
              shiny::div(
                style = "display: flex; align-items: center;",
                shiny::radioButtons(
                  ns_full("scatter_color_by"),
                  label = NULL,
                  choices = c("Analysis" = "analysis", "Replicate" = "replicate"),
                  selected = "analysis",
                  inline = TRUE
                )
              )
            ),
            shiny::div(
              style = "display: flex; align-items: center; gap: 8px; flex-wrap: wrap;",
              shiny::span("Select by:", style = "font-weight: 500;"),
              shiny::radioButtons(
                ns_full("scatter_select_by"),
                label = NULL,
                choices = c("Feature" = "feature", "Component" = "feature_component", "Group" = "feature_group"),
                selected = "feature",
                inline = TRUE
              )
            )
          ),
          shiny::div(
            class = "btn-group btn-group-sm",
            shiny::actionButton(ns_full("scatter_prop_20_80"), "20:80", class = "btn btn-outline-primary btn-sm"),
            shiny::actionButton(ns_full("scatter_prop_30_70"), "30:70", class = "btn btn-outline-primary btn-sm"),
            shiny::actionButton(ns_full("scatter_prop_40_60"), "40:60", class = "btn btn-outline-primary btn-sm"),
            shiny::actionButton(ns_full("scatter_prop_50_50"), "50:50", class = "btn btn-outline-primary btn-sm"),
            shiny::actionButton(ns_full("scatter_prop_60_40"), "60:40", class = "btn btn-outline-primary btn-sm"),
            shiny::actionButton(ns_full("scatter_prop_70_30"), "70:30", class = "btn btn-outline-primary btn-sm"),
            shiny::actionButton(ns_full("scatter_prop_80_20"), "80:20", class = "btn btn-outline-primary btn-sm active")
          )
        ),
        shiny::div(
          id = ns_full("scatter_content_container"),
          class = "sf-nta-features-layout",
          shiny::div(
            id = ns_full("features_scatter_panel"),
            class = "sf-nta-features-plot-pane",
            style = "flex: 0 0 calc(80% - 10px); max-width: calc(80% - 10px);",
            shiny::div(
              class = "sf-nta-feature-pane-shell",
              shiny::div(
                id = ns_full("scatter_filter_sidebar"),
                class = "sf-nta-feature-filter-sidebar",
                shiny::textInput(
                  ns_full("scatter_search"),
                  "Search (regex)",
                  value = "",
                  placeholder = "Filter features (regex)..."
                ),
                shiny::uiOutput(ns_full("scatter_numeric_filters"))
              ),
              shiny::div(
                class = "sf-nta-feature-plot-shell",
                shiny::div(
                  class = "sf-nta-plot-toolbar",
                  .app_util_create_maximize_button("features_scatter_plot", ns_full)
                ),
                shiny::div(
                  id = ns_full("features_scatter_surface"),
                  class = "sf-nta-feature-plot-holder sf-nta-loading-surface",
                  plotly::plotlyOutput(
                    ns_full("features_scatter_plot"),
                    height = "100%",
                    width = "100%"
                  )
                )
              )
            )
          ),
          shiny::div(
            id = ns_full("features_scatter_details_panel"),
            class = "sf-nta-features-details-pane",
            style = "flex: 0 0 calc(20% - 10px); max-width: calc(20% - 10px);",
            shiny::div(
              class = "sf-nta-details-tabs",
              shiny::tabsetPanel(
              id = ns_full("feature_scatter_details_tabs"),
              type = "tabs",
              shiny::tabPanel(
                title = "EIC",
                height = "100%",
                shiny::div(
                  class = "sf-nta-plot-panel",
                  shiny::div(
                    class = "sf-nta-plot-toolbar",
                    .app_util_create_maximize_button("feature_peaks_plot_scatter", ns_full)
                  ),
                  shiny::div(
                    class = "sf-nta-plot-body",
                    plotly::plotlyOutput(
                      ns_full("feature_peaks_plot_scatter"),
                      height = "100%"
                    )
                  )
                )
              ),
              shiny::tabPanel(
                title = "XIC",
                height = "100%",
                shiny::div(
                  class = "sf-nta-plot-panel",
                  shiny::div(
                    class = "sf-nta-plot-toolbar",
                    .app_util_create_maximize_button("feature_xic_plot_scatter", ns_full)
                  ),
                  shiny::div(
                    class = "sf-nta-plot-body",
                    plotly::plotlyOutput(
                      ns_full("feature_xic_plot_scatter"),
                      height = "100%"
                    )
                  )
                )
              ),
              shiny::tabPanel(
                title = "Profile",
                height = "100%",
                shiny::div(
                  class = "sf-nta-plot-panel",
                  shiny::div(
                    class = "sf-nta-plot-toolbar",
                    .app_util_create_maximize_button("feature_profile_plot_scatter", ns_full)
                  ),
                  shiny::div(
                    class = "sf-nta-plot-body",
                    plotly::plotlyOutput(
                      ns_full("feature_profile_plot_scatter"),
                      height = "100%"
                    )
                  )
                )
              ),
              shiny::tabPanel(
                title = "MS1",
                height = "100%",
                shiny::div(
                  class = "sf-nta-plot-panel",
                  shiny::div(
                    class = "sf-nta-plot-toolbar",
                    .app_util_create_maximize_button("feature_ms1_plot_scatter", ns_full)
                  ),
                  shiny::div(
                    class = "sf-nta-plot-body",
                    plotly::plotlyOutput(
                      ns_full("feature_ms1_plot_scatter"),
                      height = "100%"
                    )
                  )
                )
              ),
              shiny::tabPanel(
                title = "MS2",
                height = "100%",
                shiny::div(
                  class = "sf-nta-plot-panel",
                  shiny::div(
                    class = "sf-nta-plot-toolbar",
                    .app_util_create_maximize_button("feature_ms2_plot_scatter", ns_full)
                  ),
                  shiny::div(
                    class = "sf-nta-plot-body",
                    plotly::plotlyOutput(
                      ns_full("feature_ms2_plot_scatter"),
                      height = "100%"
                    )
                  )
                )
              ),
              shiny::tabPanel(
                title = "Details",
                shiny::div(
                  class = "sf-nta-table-panel",
                  DT::dataTableOutput(ns_full("feature_details_table_scatter"))
                )
              ),
              shiny::tabPanel(
                title = "Suspects",
                shiny::div(
                  class = "sf-nta-table-panel",
                  DT::dataTableOutput(ns_full("suspects_table_scatter"))
                )
              )
            ))
          )
        )
      )
    })

    # MARK: internal_standards_data
    internal_standards_data <- shiny::reactive({
      nts <- nta_data()
      istd <- get_internal_standards(nts)
      istd
    })

    # MARK: suspects_data
    suspects_data <- shiny::reactive({
      nts <- nta_data()
      sps <- data.table::as.data.table(get_suspects(nts))
      if (nrow(sps) == 0) return(sps)
      sps <- data.table::copy(sps)
      digits_for_col <- function(col) {
        col_lower <- tolower(col)
        if (col_lower %in% c("candidate_rank", "polarity", "shared_fragments", "db_ms2_size", "exp_ms2_size")) return(0)
        if (grepl("mass|mz", col_lower)) return(4)
        if (grepl("^rt|_rt$", col_lower)) return(2)
        if (col_lower == "error_mass") return(1)
        if (col_lower %in% c("intensity", "area")) return(0)
        if (col_lower == "score") return(3)
        if (col_lower == "cosine_similarity") return(3)
        2
      }
      num_cols <- names(sps)[sapply(sps, is.numeric)]
      for (col in num_cols) {
        sps[[col]] <- round(sps[[col]], digits_for_col(col))
      }
      sps
    })

    # MARK: create_structure_image
    create_structure_image <- function(smiles, width = 140, height = 120) {
      if (is.null(smiles) || is.na(smiles) || !nzchar(smiles)) return("")
      if (!requireNamespace("rcdk", quietly = TRUE)) return("")
      if (!requireNamespace("rJava", quietly = TRUE)) return("")
      if (!requireNamespace("base64enc", quietly = TRUE)) return("")
      if (!requireNamespace("magick", quietly = TRUE)) return("")
      tryCatch(
        {
          mol <- rcdk::parse.smiles(smiles)[[1]]
          img <- rcdk::view.image.2d(mol)
          temp_file <- tempfile(fileext = ".png")
          grDevices::png(filename = temp_file, width = width, height = height, res = 120, bg = "transparent")
          graphics::par(mar = c(0, 0, 0, 0))
          graphics::plot.new()
          graphics::rasterImage(img, 0, 0, 1, 1)
          grDevices::dev.off()
          magick_img <- magick::image_read(temp_file)
          magick_img <- magick::image_transparent(magick_img, "white", fuzz = 5)
          magick::image_write(magick_img, path = temp_file, format = "png")
          img_base64 <- base64enc::base64encode(temp_file)
          unlink(temp_file)
          paste0("data:image/png;base64,", img_base64)
        },
        error = function(e) {
          ""
        }
      )
    }

    # MARK: create_spectra_image
    create_spectra_image <- function(nts, analysis, feature, width = 900, height = 450) {
      if (is.null(analysis) || is.null(feature)) return("")
      if (!requireNamespace("base64enc", quietly = TRUE)) return("")
      if (!requireNamespace("ggplot2", quietly = TRUE)) return("")
      tryCatch(
        {
          sel <- data.table::data.table(analysis = analysis, feature = feature)
          p <- plot_suspects_ms2(nts, features = sel, interactive = FALSE, showLegend = FALSE, showText = FALSE)
          p <- p + ggplot2::theme(
            panel.background = ggplot2::element_rect(fill = "transparent", colour = NA),
            plot.background = ggplot2::element_rect(fill = "transparent", colour = NA)
          )
          if (is.null(p)) return("")
          temp_file <- tempfile(fileext = ".png")
          grDevices::png(filename = temp_file, width = width, height = height, res = 120, bg = "transparent")
          print(p)
          grDevices::dev.off()
          img_base64 <- base64enc::base64encode(temp_file)
          unlink(temp_file)
          paste0("data:image/png;base64,", img_base64)
        },
        error = function(e) {
          ""
        }
      )
    }

    # MARK: Summary Tab
    # Summary Tab ------

    # MARK: chart_color_by
    chart_color_by <- shiny::reactiveVal("analysis")

    shiny::observeEvent(input$chart_color_by, {
      chart_color_by(input$chart_color_by)
    })

    # MARK: summary_data
    summary_data <- shiny::reactive({
      nts <- nta_data()
      info_analyses <- info(nts)
      all_fts <- features_data()
      if (nrow(all_fts) == 0) {
        counts <- data.frame(
          analysis = info_analyses$analysis,
          total = 0,
          filtered = 0,
          not_filtered = 0,
          replicate = info_analyses$replicate
        )
        return(list(
          info = info_analyses,
          counts = counts,
          total_analyses = nrow(info_analyses),
          total_features = 0,
          filtered_features = 0,
          total_groups = 0,
          has_eic = FALSE,
          has_ms1 = FALSE,
          has_ms2 = FALSE
        ))
      }
      counts <- all_fts[, .(total = .N, filtered = sum(filtered, na.rm = TRUE)), by = analysis]
      counts$not_filtered <- counts$total - counts$filtered
      counts$replicate <- info_analyses$replicate[match(counts$analysis, info_analyses$analysis)]
      non_filtered_fts <- all_fts[!all_fts$filtered, ]
      total_groups <- 0
      if (nrow(non_filtered_fts) > 0 && "feature_group" %in% colnames(non_filtered_fts)) {
        total_groups <- data.table::uniqueN(non_filtered_fts[feature_group != "" & !is.na(feature_group)]$feature_group)
      }
      has_eic <- FALSE
      has_ms1 <- FALSE
      has_ms2 <- FALSE
      if ("eic_size" %in% colnames(all_fts)) {
        has_eic <- any(all_fts$eic_size > 0, na.rm = TRUE)
      }
      if ("ms1_size" %in% colnames(all_fts)) {
        has_ms1 <- any(all_fts$ms1_size > 0, na.rm = TRUE)
      }
      if ("ms2_size" %in% colnames(all_fts)) {
        has_ms2 <- any(all_fts$ms2_size > 0, na.rm = TRUE)
      }
      list(
        info = info_analyses,
        counts = counts,
        total_analyses = nrow(info_analyses),
        total_features = sum(counts$total, na.rm = TRUE),
        filtered_features = sum(counts$filtered, na.rm = TRUE),
        total_groups = total_groups,
        has_eic = has_eic,
        has_ms1 = has_ms1,
        has_ms2 = has_ms2
      )
    })

    # MARK: summary outputs
    output$total_analyses <- shiny::renderText({
      as.character(summary_data()$total_analyses)
    })
    output$total_features <- shiny::renderText({
      as.character(summary_data()$total_features)
    })
    output$filtered_features_count <- shiny::renderText({
      as.character(summary_data()$filtered_features)
    })
    output$total_groups <- shiny::renderText({
      as.character(summary_data()$total_groups)
    })
    output$has_features_eic_ui <- shiny::renderUI({
      status_tag(summary_data()$has_eic)
    })
    output$has_features_ms1_ui <- shiny::renderUI({
      status_tag(summary_data()$has_ms1)
    })
    output$has_features_ms2_ui <- shiny::renderUI({
      status_tag(summary_data()$has_ms2)
    })
    output$has_features_suspects_ui <- shiny::renderUI({
      n_suspects <- nrow(suspects_data())
      if (is.null(n_suspects)) n_suspects <- 0
      shiny::tags$span(
        class = ifelse(n_suspects > 0, "status-yes", "status-no"),
        as.character(n_suspects)
      )
    })
    output$internal_standards_assigned_ui <- shiny::renderUI({
      n_istd <- nrow(internal_standards_data())
      if (is.null(n_istd)) n_istd <- 0
      shiny::tags$span(
        class = ifelse(n_istd > 0, "status-yes", "status-no"),
        as.character(n_istd)
      )
    })

    # MARK: summary_chart
    output$features_chart <- plotly::renderPlotly({
      nts <- nta_data()
      shiny::validate(shiny::need(!is.null(nts), "NTA data is not available"))
      group_by <- if (identical(chart_color_by(), "replicate")) "replicate" else "analysis"
      p <- plot_features_count(nts, groupBy = group_by, showLegend = FALSE)
      shiny::validate(shiny::need(!is.null(p), "No features available to plot."))
      p %>%
        plotly::layout(
          title = NULL,
          margin = list(l = 60, r = 40, t = 40, b = 40),
          paper_bgcolor = "rgba(0,0,0,0)",
          plot_bgcolor = "rgba(0,0,0,0)"
        ) %>%
        plotly::config(
          displayModeBar = TRUE,
          displaylogo = FALSE,
          responsive = TRUE
        )
    })

    # MARK: Features Tab
    # Features Tab ------

    # MARK: Layout proportions
    scatter_layout_proportions <- shiny::reactiveVal(c(80, 20))
    scatter_filters_open <- shiny::reactiveVal(FALSE)
    scatter_numeric_cols <- shiny::reactive({
      fts <- data.table::as.data.table(features_data())
      names(fts)[sapply(fts, is.numeric)]
    })
    shiny::observeEvent(input$scatter_prop_20_80, {
      scatter_layout_proportions(c(20, 80))
    })
    shiny::observeEvent(input$scatter_prop_30_70, {
      scatter_layout_proportions(c(30, 70))
    })
    shiny::observeEvent(input$scatter_prop_40_60, {
      scatter_layout_proportions(c(40, 60))
    })
    shiny::observeEvent(input$scatter_prop_50_50, {
      scatter_layout_proportions(c(50, 50))
    })
    shiny::observeEvent(input$scatter_prop_60_40, {
      scatter_layout_proportions(c(60, 40))
    })
    shiny::observeEvent(input$scatter_prop_70_30, {
      scatter_layout_proportions(c(70, 30))
    })
    shiny::observeEvent(input$scatter_prop_80_20, {
      scatter_layout_proportions(c(80, 20))
    })
    shiny::observeEvent(input$toggle_scatter_filters, {
      scatter_filters_open(!isTRUE(scatter_filters_open()))
    })
    resize_feature_plots <- function() {
      session$sendCustomMessage("sf-plotly-resize", list(
        ids = unname(c(
          ns_full("features_scatter_plot"),
          ns_full("feature_peaks_plot_scatter"),
          ns_full("feature_xic_plot_scatter"),
          ns_full("feature_profile_plot_scatter"),
          ns_full("feature_ms1_plot_scatter"),
          ns_full("feature_ms2_plot_scatter")
        ))
      ))
    }
    schedule_feature_plot_resize <- function() {
      session$onFlushed(function() {
        resize_feature_plots()
      }, once = TRUE)
    }
    sync_feature_layout <- function() {
      props <- scatter_layout_proportions()
      filters_open <- isTRUE(scatter_filters_open())
      active_prop <- paste0(props[1], "_", props[2])
      session$sendCustomMessage("sf-nta-feature-layout", list(
        left_id = ns_full("features_scatter_panel"),
        right_id = ns_full("features_scatter_details_panel"),
        sidebar_id = ns_full("scatter_filter_sidebar"),
        toggle_id = ns_full("toggle_scatter_filters"),
        left_basis = props[1],
        right_basis = props[2],
        filters_open = filters_open,
        toggle_label = if (filters_open) "Hide Filters" else "Show Filters",
        prop_button_ids = unname(c(
          ns_full("scatter_prop_20_80"),
          ns_full("scatter_prop_30_70"),
          ns_full("scatter_prop_40_60"),
          ns_full("scatter_prop_50_50"),
          ns_full("scatter_prop_60_40"),
          ns_full("scatter_prop_70_30"),
          ns_full("scatter_prop_80_20")
        )),
        active_prop_button_id = ns_full(paste0("scatter_prop_", active_prop))
      ))
    }
    shiny::observeEvent(scatter_layout_proportions(), {
      sync_feature_layout()
      later::later(schedule_feature_plot_resize, delay = 0.08)
    }, ignoreInit = FALSE)
    shiny::observeEvent(scatter_filters_open(), {
      sync_feature_layout()
      later::later(schedule_feature_plot_resize, delay = 0.08)
    }, ignoreInit = FALSE)

    # MARK: scatter_numeric_filters
    output$scatter_numeric_filters <- shiny::renderUI({
      fts <- data.table::as.data.table(features_data())
      if (nrow(fts) == 0) return(NULL)
      num_cols <- names(fts)[sapply(fts, is.numeric)]
      log_cols <- names(fts)[sapply(fts, is.logical)]

      slider_specs <- function(col, rng) {
        digits <- 3
        col_lower <- tolower(col)
        if (col_lower == "fwhm_mz") {
          digits <- 4
        } else if (col_lower == "gaussian_sigma") {
          digits <- 1
        } else if (col_lower %in% c("gaussian_mu", "gaussian_a")) {
          digits <- 0
        }
        four_decimals <- grepl("^mz", col, ignore.case = TRUE)
        four_decimals <- four_decimals || grepl("mzmin|mzmax|mass", col_lower)
        if (four_decimals) {
          digits <- 4
        }
        if (col_lower == "ppm") {
          digits <- 1
        }
        if (col_lower == "sn") {
          digits <- 1
        }
        zero_decimals <- grepl("intensity|area|size|noise|plates", col_lower)
        zero_decimals <- zero_decimals || grepl("^rt", col_lower)
        zero_decimals <- zero_decimals || (grepl("width|fwhm", col_lower) && col_lower != "fwhm_mz")
        if (zero_decimals) {
          digits <- 0
        }
        if (grepl("gaussian_r2|correction|jaggedness|sharpness|asymmetry", col_lower)) {
          digits <- 2
        }
        step <- if (digits == 0) 1 else 10^-digits
        list(
          min = rng[1],
          max = rng[2],
          value = rng,
          step = step
        )
      }

      slider_list <- NULL
      if (length(num_cols) > 0) {
        slider_list <- lapply(num_cols, function(col) {
          vals <- fts[[col]]
          vals <- vals[is.finite(vals)]
          if (length(vals) == 0) return(NULL)
          rng <- range(vals, na.rm = TRUE)
          specs <- slider_specs(col, rng)
          shiny::sliderInput(
            ns_full(paste0("scatter_filter_", col)),
            label = col,
            min = specs$min,
            max = specs$max,
            value = specs$value,
            step = specs$step
          )
        })
        slider_list <- slider_list[!vapply(slider_list, is.null, logical(1))]
      }

      logi_list <- NULL
      if (length(log_cols) > 0) {
        logi_list <- lapply(log_cols, function(col) {
          col_lower <- tolower(col)
          default_sel <- if (col_lower == "filtered") "FALSE" else c("TRUE", "FALSE")
          shiny::checkboxGroupInput(
            ns_full(paste0("scatter_filter_", col)),
            label = paste0(col, " (TRUE/FALSE)"),
            choices = c("TRUE", "FALSE"),
            selected = default_sel,
            inline = TRUE
          )
        })
      }

      suspects_toggle <- shiny::checkboxInput(
        ns_full("scatter_filter_suspects"),
        "Suspects",
        value = FALSE
      )

      ui_elems <- c(list(suspects_toggle), logi_list, slider_list)
      if (length(ui_elems) == 0) return(NULL)
      shiny::tagList(ui_elems)
    })



    # MARK: features_scatter_data
    features_scatter_data <- shiny::reactive({
      fts <- data.table::as.data.table(features_data())
      if (nrow(fts) == 0) return(fts)

      # Make explicit copy to avoid shallow copy warning with :=
      fts <- data.table::copy(fts)
      fts$analysis <- as.character(fts$analysis)
      fts$feature <- as.character(fts$feature)
      fts$replicate <- as.character(fts$replicate)

      # Apply text search (regex) across all columns
      search_term <- input$scatter_search
      if (!is.null(search_term) && nzchar(search_term)) {
        row_txt <- apply(fts, 1, function(r) paste(r, collapse = " "))
        keep_idx <- grepl(search_term, row_txt, perl = TRUE, ignore.case = TRUE)
        fts <- fts[keep_idx]
      }

      # Apply numeric filters
      num_cols <- names(fts)[sapply(fts, is.numeric)]
      for (col in num_cols) {
        rng <- input[[paste0("scatter_filter_", col)]]
        if (!is.null(rng) && length(rng) == 2 && all(is.finite(rng))) {
          fts <- fts[fts[[col]] >= rng[1] & fts[[col]] <= rng[2]]
        }
      }

      # Apply logical filters
      log_cols <- names(fts)[sapply(fts, is.logical)]
      for (col in log_cols) {
        sel <- input[[paste0("scatter_filter_", col)]]
        if (!is.null(sel) && length(sel) > 0) {
          keep_vals <- as.logical(sel)
          fts <- fts[fts[[col]] %in% keep_vals]
        }
      }

      # Apply suspects filter
      if (isTRUE(input$scatter_filter_suspects)) {
        sps <- data.table::as.data.table(suspects_data())
        if (nrow(sps) == 0) return(fts[0])
        if (all(c("analysis", "feature") %in% colnames(sps))) {
          sps <- unique(sps[, .(analysis = as.character(analysis), feature = as.character(feature))])
          fts <- fts[sps, on = .(analysis, feature), nomatch = 0]
        }
      }

      if (nrow(fts) == 0) return(fts)

      fts$rel_intensity <- NA_real_
      if ("intensity" %in% colnames(fts) && "analysis" %in% colnames(fts)) {
        max_intensity_global <- max(fts$intensity, na.rm = TRUE)
        fts$rel_intensity <- fts$intensity / max_intensity_global
        fts$rel_intensity[is.infinite(fts$rel_intensity) | is.na(fts$rel_intensity)] <- 0
      } else {
        fts$rel_intensity <- 0
      }
      fts$dot_size <- 6 + 10 * fts$rel_intensity
      fts
    })

    # MARK: scatter_color_cols & scatter_selection_cols
    scatter_color_cols <- shiny::reactive({
      sel <- input$scatter_color_by
      if (is.null(sel) || !nzchar(sel)) sel <- "analysis"
      sel
    })
    scatter_selection_cols <- shiny::reactive({
      sel <- input$scatter_select_by
      if (is.null(sel) || !nzchar(sel)) sel <- "feature"
      cols <- sel
      if (sel %in% c("feature", "feature_component")) {
        cols <- c("analysis", cols)
      }
      cols
    })

    scatter_details_group_by <- shiny::reactive({
      sel <- input$scatter_select_by
      if (identical(sel, "feature_component")) {
        return(c("analysis", "feature"))
      }
      unique(c(scatter_color_cols(), scatter_selection_cols()))
    })

    # MARK: features_scatter_plot
    output$features_scatter_plot <- plotly::renderPlotly({
      fts <- as.data.frame(features_scatter_data())
      shiny::validate(shiny::need(nrow(fts) > 0, "No features available to plot."))

      color_cols <- scatter_color_cols()
      color_cols <- color_cols[color_cols %in% colnames(fts)]
      if (length(color_cols) == 0) color_cols <- "analysis"

      fts[, color_cols] <- lapply(fts[, color_cols, drop = FALSE], as.character)
      for (col in color_cols) fts[[col]][is.na(fts[[col]])] <- ""
      fts$color_var <- do.call(paste, c(fts[, color_cols, drop = FALSE], sep = "_"))

      pal <- .get_colors(unique(fts$color_var))
      hide_legend <- length(unique(fts$color_var)) > 50

      sel_cols <- scatter_selection_cols()
      sel_cols <- sel_cols[sel_cols %in% colnames(fts)]
      if (length(sel_cols) == 0) sel_cols <- intersect(c("analysis", "feature"), colnames(fts))
      fts[, sel_cols] <- lapply(fts[, sel_cols, drop = FALSE], as.character)
      for (col in sel_cols) fts[[col]][is.na(fts[[col]])] <- ""
      fts$scatter_key <- do.call(paste, c(fts[, sel_cols, drop = FALSE], sep = "||"))

      # Ensure size is numeric vector to avoid ordering issues with formula notation
      # size_values <- as.numeric(fts$dot_size)

      p <- plotly::plot_ly(
        data = fts,
        source = "features_scatter",
        x = ~rt,
        y = ~mz,
        type = "scattergl",
        mode = "markers",
        color = ~color_var,
        colors = pal,
        marker = list(
          sizemode = "diameter",
          size = ~dot_size,
          sizemin = 3,
          line = list(width = 0)
        ),
        key = ~scatter_key,
        hoverinfo = "none"
      )

      p <- plotly::layout(
        p,
        title = NULL,
        margin = list(l = 60, r = 30, t = 30, b = 88),
        paper_bgcolor = "rgba(0,0,0,0)",
        plot_bgcolor = "rgba(0,0,0,0)",
        xaxis = list(
          title = list(text = "Retention Time"),
          tickfont = list(size = 12),
          gridcolor = "#eee"
        ),
        yaxis = list(
          title = list(text = "<i>m/z</i>"),
          tickfont = list(size = 12),
          gridcolor = "#eee"
        ),
        legend = list(
          title = list(text = paste(color_cols, collapse = ", ")),
          orientation = "h",
          x = 0,
          xanchor = "left",
          y = -0.16,
          yanchor = "top"
        ),
        showlegend = !hide_legend
      )

            p <- plotly::config(
              p,
              displayModeBar = TRUE,
              displaylogo = FALSE,
              responsive = FALSE
            )

      p <- plotly::event_register(p, "plotly_selected")
      p <- plotly::event_register(p, "plotly_click")
      p
    })

    # MARK: selected_features_scatter
    selected_features_scatter <- shiny::reactive({
      evt <- plotly::event_data("plotly_selected", source = "features_scatter")
      if (is.null(evt) || nrow(evt) == 0) {
        evt <- plotly::event_data("plotly_click", source = "features_scatter")
      }
      if (is.null(evt) || nrow(evt) == 0) return(NULL)
      keys <- evt$key
      if (is.null(keys)) return(NULL)
      keys <- as.character(keys)

      fts <- data.table::copy(features_scatter_data())
      if (!nrow(fts)) return(NULL)

      sel_cols <- scatter_selection_cols()
      sel_cols <- sel_cols[sel_cols %in% colnames(fts)]
      if (length(sel_cols) == 0) sel_cols <- intersect(c("analysis", "feature"), colnames(fts))
      if ("feature_component" %in% sel_cols && "feature_component" %in% colnames(fts)) {
        fts <- fts[fts$feature_component != "", ]
        fts <- fts[!is.na(fts$feature_component), ]
      }
      if ("feature_group" %in% sel_cols && "feature_group" %in% colnames(fts)) {
        fts <- fts[fts$feature_group != "", ]
        fts <- fts[!is.na(fts$feature_group), ]
      }
      if (!nrow(fts)) return(NULL)

      key_parts <- strsplit(keys, "||", fixed = TRUE)
      key_parts <- unique(key_parts[[1]])

      sel <- rep(TRUE, nrow(fts))
      lapply(seq_along(sel_cols), function(i) {
        sel <<- sel & (fts[[sel_cols[i]]] %in% key_parts[i])
        invisible(NULL)
      })

      fts[sel, c("analysis", "feature"), with = FALSE]
    })

    # MARK: feature_peaks_plot_scatter
    output$feature_peaks_plot_scatter <- plotly::renderPlotly({
      shiny::validate(
        shiny::need(
          nrow(selected_features_scatter()) > 0,
          "Select one or more points to view EIC."
        )
      )
      nts <- nta_data()
      p <- plot_features(
        nts,
        features = selected_features_scatter(),
        groupBy = scatter_details_group_by(),
        filtered = TRUE,
        showDetails = TRUE
      )
      shiny::validate(shiny::need(!is.null(p), "No EIC data for selected features."))
      plotly::layout(
        p,
        title = NULL,
        margin = list(l = 50, r = 30, t = 30, b = 50),
        paper_bgcolor = "rgba(0,0,0,0)",
        plot_bgcolor = "rgba(0,0,0,0)"
      ) %>%
        plotly::config(displaylogo = FALSE, responsive = TRUE)
    })

    # MARK: feature_ms1_plot_scatter
    output$feature_ms1_plot_scatter <- plotly::renderPlotly({
      shiny::validate(
        shiny::need(
          nrow(selected_features_scatter()) > 0,
          "Select one or more points to view MS1."
        )
      )
      nts <- nta_data()
      p <- plot_features_ms1(
        nts,
        features = selected_features_scatter(),
        groupBy = scatter_details_group_by(),
        filtered = TRUE
      )
      shiny::validate(shiny::need(!is.null(p), "No MS1 data for selected features."))
      plotly::layout(
        p,
        title = NULL,
        margin = list(l = 50, r = 30, t = 30, b = 50),
        paper_bgcolor = "rgba(0,0,0,0)",
        plot_bgcolor = "rgba(0,0,0,0)"
      ) %>%
        plotly::config(displaylogo = FALSE, responsive = TRUE)
    })

    # MARK: feature_ms2_plot_scatter
    output$feature_ms2_plot_scatter <- plotly::renderPlotly({
      shiny::validate(
        shiny::need(
          nrow(selected_features_scatter()) > 0,
          "Select one or more points to view MS2."
        )
      )
      nts <- nta_data()
      p <- plot_features_ms2(
        nts,
        features = selected_features_scatter(),
        groupBy = scatter_details_group_by(),
        filtered = TRUE
      )
      shiny::validate(shiny::need(!is.null(p), "No MS2 data for selected features."))
      plotly::layout(
        p,
        title = NULL,
        margin = list(l = 50, r = 30, t = 30, b = 50),
        paper_bgcolor = "rgba(0,0,0,0)",
        plot_bgcolor = "rgba(0,0,0,0)"
      ) %>%
        plotly::config(displaylogo = FALSE, responsive = TRUE)
    })

    output$feature_xic_plot_scatter <- plotly::renderPlotly({
      shiny::validate(
        shiny::need(
          nrow(selected_features_scatter()) > 0,
          "Select one or more points to view XIC."
        )
      )
      nts <- nta_data()
      p <- map_features(
        nts,
        features = selected_features_scatter(),
        groupBy = scatter_details_group_by(),
        filtered = TRUE,
        showDetails = TRUE
      )
      shiny::validate(shiny::need(!is.null(p), "No XIC data for selected features."))
      plotly::layout(
        p,
        title = NULL,
        margin = list(l = 50, r = 30, t = 30, b = 50),
        paper_bgcolor = "rgba(0,0,0,0)",
        plot_bgcolor = "rgba(0,0,0,0)"
      ) %>%
        plotly::config(displaylogo = FALSE, responsive = TRUE)
    })

    output$feature_profile_plot_scatter <- plotly::renderPlotly({
      shiny::validate(
        shiny::need(
          nrow(selected_features_scatter()) > 0,
          "Select one or more points to view profile."
        )
      )
      nts <- nta_data()
      sel <- selected_features_scatter()
      fts <- get_features(nts, features = sel, filtered = TRUE)
      if (nrow(fts) == 0 || !"feature_group" %in% colnames(fts)) {
        shiny::validate(shiny::need(FALSE, "No feature groups available for selected features."))
      }
      groups <- unique(fts$feature_group)
      groups <- groups[!is.na(groups) & groups != ""]
      shiny::validate(
        shiny::need(length(groups) > 0, "No feature groups available for selected features.")
      )
      p <- plot_features_profile(
        nts,
        groups = groups,
        groupBy = if (identical(input$scatter_color_by, "replicate")) "replicate" else "analysis",
        showLegend = FALSE
      )
      shiny::validate(shiny::need(!is.null(p), "No profile data for selected features."))
      plotly::layout(
        p,
        title = NULL,
        margin = list(l = 50, r = 30, t = 30, b = 50),
        paper_bgcolor = "rgba(0,0,0,0)",
        plot_bgcolor = "rgba(0,0,0,0)"
      ) %>%
        plotly::config(displaylogo = FALSE, responsive = TRUE)
    })

    # MARK: feature_details_table_scatter
    output$feature_details_table_scatter <- DT::renderDT({
      sel <- selected_features_scatter()
      shiny::validate(shiny::need(nrow(sel) > 0, "Select one or more points to view details."))

      fts <- data.table::copy(features_data()[analysis %in% sel$analysis & feature %in% sel$feature, ])

      if (nrow(fts) == 0) {
        return(DT::datatable(
          data.frame(Message = "No details available for selected features."),
          options = list(dom = "t", paging = FALSE, ordering = FALSE),
          style = "bootstrap",
          class = "table table-striped table-hover",
          rownames = FALSE
        ))
      }

      keep_cols <- colnames(fts)
      keep_cols <- !keep_cols %in% c(
        "eic_rt",
        "eic_mz",
        "eic_intensity",
        "eic_baseline",
        "eic_smoothed",
        "ms1_mz",
        "ms1_intensity",
        "ms2_mz",
        "ms2_intensity",
        "rel_intensity"
      )
      fts <- fts[, keep_cols, with = FALSE]
      n_sel <- nrow(fts)
      prop_names <- colnames(fts)
      rows <- lapply(prop_names, function(p) {
        vals <- as.character(fts[[p]])
        data.frame(
          Property = p,
          t(as.matrix(vals)),
          stringsAsFactors = FALSE
        )
      })
      details_dt <- data.table::rbindlist(rows, fill = TRUE)
      if (n_sel > 1) {
        setnames(details_dt, c("Property", paste0("Value ", seq_len(n_sel))))
      } else {
        setnames(details_dt, c("Property", "Value"))
      }
        DT::datatable(
          details_dt,
          options = list(
            dom = "tip",
            paging = FALSE,
            ordering = FALSE,
            autoWidth = FALSE,
            scrollX = TRUE,
            scrollCollapse = TRUE,
            fixedColumns = list(leftColumns = 1)
          ),
          selection = "single",
          extensions = "FixedColumns",
          style = "bootstrap",
          class = "table table-striped table-hover",
          width = "100%",
          rownames = FALSE
        )
      })

    # Suspects ------

    # MARK: suspects_table_scatter
    output$suspects_table_scatter <- DT::renderDT({
      nts <- nta_data()
      suspects <- data.table::copy(suspects_data())
      sel <- selected_features_scatter()
      shiny::validate(shiny::need(!is.null(sel) && nrow(sel) > 0, "Select one or more points to view suspects."))
      if (nrow(suspects) == 0) {
        shiny::validate(shiny::need(FALSE, "No suspects available."))
      }
      suspects <- suspects[analysis %in% sel$analysis & feature %in% sel$feature, ]
      shiny::validate(shiny::need(nrow(suspects) > 0, "No suspects available for selected features."))

      analyses_info <- info(nts)
      rep_map <- analyses_info$replicate
      names(rep_map) <- analyses_info$analysis
      suspects$replicate <- rep_map[suspects$analysis]

      smiles_vec <- if ("SMILES" %in% colnames(suspects)) {
        suspects$SMILES
      } else {
        rep(NA_character_, nrow(suspects))
      }
      suspects$structure <- vapply(
        smiles_vec,
        function(smiles) {
          img_uri <- create_structure_image(smiles)
          if (!nzchar(img_uri)) return("")
          sprintf("<img src='%s' class='suspect-structure-img'/>", img_uri)
        },
        character(1)
      )

      suspects$spectra <- mapply(
        function(analysis, feature) {
          img_uri <- create_spectra_image(nts, analysis, feature)
          if (!nzchar(img_uri)) return("")
          sprintf("<img src='%s' class='suspect-spectra-img'/>", img_uri)
        },
        suspects$analysis,
        suspects$feature,
        SIMPLIFY = TRUE,
        USE.NAMES = FALSE
      )

      exclude_cols <- c(
        "db_ms2_mz",
        "db_ms2_intensity",
        "db_ms2_formula",
        "exp_ms2_mz",
        "exp_ms2_intensity"
      )
      keep_cols <- setdiff(colnames(suspects), exclude_cols)
      base_cols <- c(
        "structure", "name", "spectra", "analysis", "replicate",
        "feature", "feature_component", "feature_group"
      )
      base_cols <- base_cols[base_cols %in% keep_cols]
      rest_cols <- setdiff(keep_cols, base_cols)
      suspects <- suspects[, c(base_cols, rest_cols), with = FALSE]

      DT::datatable(
        suspects,
        options = list(
          dom = "t",
          paging = FALSE,
          autoWidth = TRUE,
          scrollX = TRUE,
          scrollY = "calc(100vh - 293px)",
          rowCallback = DT::JS(
            "function(row, data, num, index){",
            "  $(row).css('background-color', '#ffffff');",
            "  $('td', row).css('background-color', '#ffffff');",
            "}"
          )
        ),
        escape = FALSE,
        style = "bootstrap",
        class = "table table-hover suspects-table",
        rownames = FALSE
      )
    })
  })
}

