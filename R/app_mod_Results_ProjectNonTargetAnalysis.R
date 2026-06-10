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
    .sf-nta-results-features .bslib-sidebar-layout,
    .sf-nta-results-internal-standards .bslib-sidebar-layout {
      flex: 1 1 auto;
      display: flex;
      min-height: 0;
      overflow: hidden;
    }
    .sf-nta-results-summary .bslib-sidebar-layout > .main,
    .sf-nta-results-features .bslib-sidebar-layout > .main,
    .sf-nta-results-internal-standards .bslib-sidebar-layout > .main {
      flex: 1 1 auto;
      display: flex;
      flex-direction: column;
      min-height: 0;
      overflow: hidden;
    }
    .sf-nta-results-summary .bslib-sidebar-layout > .sidebar,
    .sf-nta-results-features .bslib-sidebar-layout > .sidebar,
    .sf-nta-results-internal-standards .bslib-sidebar-layout > .sidebar {
      overflow: auto;
    }
    .sf-nta-results-root .bslib-gap-spacing,
    .sf-nta-results-root .html-fill-container {
      padding: 5px !important;
      box-sizing: border-box;
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
    .sf-nta-results-summary .bslib-sidebar-resize-handle .visually-hidden {
      display: none !important;
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
      width: 180px;
      height: 200px;
      display: block;
      border: none;
      background: transparent;
      object-fit: contain;
      object-position: center;
    }
    .suspect-spectra-img {
      width: 360px;
      height: 200px;
      display: block;
      border: none;
      background: transparent;
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
      padding: 5px;
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
    .sf-nta-results-features > .features-controls-bar,
    .sf-nta-results-internal-standards > .features-controls-bar {
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
      background-color: transparent;
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
    .sf-nta-network-panel {
      height: 100%;
      min-height: 0;
      display: flex;
      flex-direction: column;
      overflow: hidden;
    }
    .sf-nta-network-body {
      flex: 1 1 auto;
      min-height: 0;
      overflow: hidden;
    }
    .sf-nta-network-body .visNetwork,
    .sf-nta-network-body .html-widget,
    .sf-nta-network-body .vis-network {
      width: 100% !important;
      height: 100% !important;
    }
    .sf-nta-network-body .vis-tooltip {
      font-size: 12px !important;
      line-height: 1.35 !important;
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
      gap: 6px;
      padding: 0 0 5px 0;
      border-bottom: none;
    }
    .sf-nta-details-tabs > .tabbable > .nav-tabs > li {
      flex: 0 0 auto;
      margin: 0;
      border: none !important;
      box-shadow: none !important;
    }
    .sf-nta-details-tabs > .tabbable > .nav-tabs > li > a,
    .sf-nta-details-tabs > .tabbable > .nav-tabs > li > a.nav-link {
      display: flex;
      align-items: center;
      justify-content: center;
      min-height: 28px;
      padding: 4px 10px;
      margin: 0;
      background: transparent !important;
      border: none !important;
      border-radius: var(--sf-radius-sm);
      color: var(--sf-topbar-color) !important;
      font-size: 12px;
      font-weight: 600;
      letter-spacing: 0.01em;
      line-height: 1.2;
      box-shadow: none !important;
      outline: none !important;
      transition: background 0.15s, color 0.15s;
    }
    .sf-nta-details-tabs > .tabbable > .nav-tabs > li > a:hover,
    .sf-nta-details-tabs > .tabbable > .nav-tabs > li > a:focus,
    .sf-nta-details-tabs > .tabbable > .nav-tabs > li > a.nav-link:hover,
    .sf-nta-details-tabs > .tabbable > .nav-tabs > li > a.nav-link:focus {
      background: var(--sf-nav-hover-bg) !important;
      color: var(--sf-topbar-color) !important;
      border: none !important;
    }
    .sf-nta-details-tabs > .tabbable > .nav-tabs > li.active > a,
    .sf-nta-details-tabs > .tabbable > .nav-tabs > li.active > a:hover,
    .sf-nta-details-tabs > .tabbable > .nav-tabs > li.active > a:focus,
    .sf-nta-details-tabs > .tabbable > .nav-tabs > li > a.active,
    .sf-nta-details-tabs > .tabbable > .nav-tabs > li > a.nav-link.active {
      background: var(--sf-nav-active-bg) !important;
      color: var(--sf-nav-active-color) !important;
      border: none !important;
      border-color: transparent !important;
      box-shadow: none !important;
      outline: none !important;
      font-weight: 600;
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
    .sf-nta-plot-body {
      flex: 1 1 auto;
      min-height: 0;
      background: transparent;
      display: flex;
      overflow: hidden;
      position: relative;
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
      display: flex;
      flex-direction: column;
      overflow: hidden;
      padding: 12px;
      background: transparent;
    }
    .sf-nta-table-panel > .html-widget,
    .sf-nta-table-panel .datatables,
    .sf-nta-table-panel .dataTables_wrapper,
    .sf-nta-table-panel .dataTables_scroll {
      width: 100%;
      height: 100%;
      min-height: 0;
    }
    .sf-nta-table-panel .dataTables_scroll {
      display: flex;
      flex-direction: column;
      overflow: hidden;
    }
    .sf-nta-table-panel .dataTables_scrollHead,
    .sf-nta-table-panel .dataTables_scrollFoot {
      flex: 0 0 auto;
    }
    .sf-nta-table-panel .dataTables_scrollBody {
      flex: 1 1 auto;
      min-height: 0;
      height: auto !important;
      max-height: none !important;
      overflow: auto !important;
    }
    .sf-nta-table-panel .dataTables_scrollBody table {
      margin-top: 0 !important;
      margin-bottom: 0 !important;
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

          $(document).on('shown.bs.tab', '#%s li a[data-toggle=\"tab\"], #%s li a[data-toggle=\"tab\"]', function() {
            var ids = [
              '%s', '%s', '%s', '%s', '%s', '%s',
              '%s', '%s', '%s', '%s', '%s', '%s'
            ];
            setTimeout(function() {
              observeIds(ids);
              resizeIds(ids);
            }, 80);
          });

          var initLoadingSurfaces = function() {
            [
              ['%s', '%s'],
              ['%s', '%s'],
              ['%s', '%s'],
              ['%s', '%s'],
              ['%s', '%s'],
              ['%s', '%s'],
              ['%s', '%s'],
              ['%s', '%s'],
              ['%s', '%s'],
              ['%s', '%s'],
              ['%s', '%s'],
              ['%s', '%s'],
              ['%s', '%s']
            ].forEach(function(pair) {
              bindLoadingSurface(pair[0], pair[1]);
            });
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
        ns_full("istd_details_tabs"),
        ns_full("features_scatter_plot"),
        ns_full("feature_peaks_plot_scatter"),
        ns_full("feature_xic_plot_scatter"),
        ns_full("feature_profile_plot_scatter"),
        ns_full("feature_ms1_plot_scatter"),
        ns_full("feature_ms2_plot_scatter"),
        ns_full("internal_standards_scatter_plot"),
        ns_full("internal_standard_eic_plot"),
        ns_full("internal_standard_xic_plot"),
        ns_full("internal_standard_profile_plot"),
        ns_full("internal_standard_ms1_plot"),
        ns_full("internal_standard_ms2_plot"),
        ns_full("features_chart"),
        ns_full("features_chart_surface"),
        ns_full("features_scatter_plot"),
        ns_full("features_scatter_surface"),
        ns_full("feature_peaks_plot_scatter"),
        ns_full("feature_peaks_plot_scatter_surface"),
        ns_full("feature_xic_plot_scatter"),
        ns_full("feature_xic_plot_scatter_surface"),
        ns_full("feature_profile_plot_scatter"),
        ns_full("feature_profile_plot_scatter_surface"),
        ns_full("feature_ms1_plot_scatter"),
        ns_full("feature_ms1_plot_scatter_surface"),
        ns_full("feature_ms2_plot_scatter"),
        ns_full("feature_ms2_plot_scatter_surface"),
        ns_full("internal_standard_eic_plot"),
        ns_full("internal_standard_eic_plot_surface"),
        ns_full("internal_standard_xic_plot"),
        ns_full("internal_standard_xic_plot_surface"),
        ns_full("internal_standard_profile_plot"),
        ns_full("internal_standard_profile_plot_surface"),
        ns_full("internal_standard_ms1_plot"),
        ns_full("internal_standard_ms1_plot_surface"),
        ns_full("internal_standard_ms2_plot"),
        ns_full("internal_standard_ms2_plot_surface"),
        ns_full("internal_standard_metrics_plot"),
        ns_full("internal_standard_metrics_plot_surface")
      )
    )
  )

  shiny::tagList(
    custom_css,
    custom_js,
    shiny::conditionalPanel(
      "input.sf_active_subtab === 'summary'",
        shiny::div(
          class = "sf-nta-results-root sf-nta-results-summary tab-content",
          bslib::layout_sidebar(
            sidebar = bslib::sidebar(
              width = "250px",
              resizable = FALSE,
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
                      shiny::span("Group by:", style = "font-weight: 700;"),
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
                  plotly::plotlyOutput(ns_full("features_chart"), height = "100%")
                )
            )
          )
        )
    ),
    shiny::conditionalPanel(
      "input.sf_active_subtab === 'features'",
      shiny::uiOutput(ns_full("features_results_ui"))
    ),
    shiny::conditionalPanel(
      "input.sf_active_subtab === 'internal_standards'",
      shiny::uiOutput(ns_full("internal_standards_results_ui"))
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
    reactive_volumes,
    reactive_theme_mode = shiny::reactive("light")) {
  shiny::moduleServer(id, function(input, output, session) {
    ns_full <- session$ns
    dark_mode <- shiny::reactive(identical(reactive_theme_mode(), "dark"))

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
              shiny::span("Group by:", style = "font-weight: 700;"),
              shiny::div(
                style = "display: flex; align-items: center;",
                shiny::radioButtons(
                  ns_full("scatter_color_by"),
                  label = NULL,
                  choices = c("Analysis" = "analysis", "Replicate" = "replicate"),
                  selected = "replicate",
                  inline = TRUE
                )
              )
            ),
            shiny::div(
              style = "display: flex; align-items: center; gap: 8px; flex-wrap: wrap;",
              shiny::span("Select by:", style = "font-weight: 700;"),
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
            shiny::actionButton(ns_full("scatter_prop_50_50"), "50:50", class = "btn btn-outline-primary btn-sm active"),
            shiny::actionButton(ns_full("scatter_prop_60_40"), "60:40", class = "btn btn-outline-primary btn-sm"),
            shiny::actionButton(ns_full("scatter_prop_70_30"), "70:30", class = "btn btn-outline-primary btn-sm"),
            shiny::actionButton(ns_full("scatter_prop_80_20"), "80:20", class = "btn btn-outline-primary btn-sm")
          )
        ),
        shiny::div(
          id = ns_full("scatter_content_container"),
          class = "sf-nta-features-layout",
          shiny::div(
            id = ns_full("features_scatter_panel"),
            class = "sf-nta-features-plot-pane",
            style = "flex: 0 0 calc(50% - 10px); max-width: calc(50% - 10px);",
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
            style = "flex: 0 0 calc(50% - 10px); max-width: calc(50% - 10px);",
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
                    id = ns_full("feature_peaks_plot_scatter_surface"),
                    class = "sf-nta-plot-body sf-nta-loading-surface",
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
                    id = ns_full("feature_xic_plot_scatter_surface"),
                    class = "sf-nta-plot-body sf-nta-loading-surface",
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
                    id = ns_full("feature_profile_plot_scatter_surface"),
                    class = "sf-nta-plot-body sf-nta-loading-surface",
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
                    id = ns_full("feature_ms1_plot_scatter_surface"),
                    class = "sf-nta-plot-body sf-nta-loading-surface",
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
                    id = ns_full("feature_ms2_plot_scatter_surface"),
                    class = "sf-nta-plot-body sf-nta-loading-surface",
                    plotly::plotlyOutput(
                      ns_full("feature_ms2_plot_scatter"),
                      height = "100%"
                    )
                  )
                )
              ),
              shiny::tabPanel(
                title = "Network",
                height = "100%",
                shiny::div(
                  class = "sf-nta-network-panel",
                  shiny::div(
                    class = "sf-nta-network-body",
                    visNetwork::visNetworkOutput(
                      ns_full("feature_network_plot_scatter"),
                      height = "100%",
                      width = "100%"
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

    has_internal_standards <- shiny::reactive({
      nrow(internal_standards_data()) > 0
    })

    output$internal_standards_results_ui <- shiny::renderUI({
      if (!isTRUE(has_internal_standards())) {
        return(
          htmltools::div(
            class = "sf-empty-state",
            htmltools::div(
              class = "sf-page-title-block",
              htmltools::tags$h3(class = "sf-page-title", "No Internal Standards Available"),
              htmltools::tags$p(
                class = "sf-page-subtitle",
                "Run the Internal Standards workflow step to inspect assigned standards."
              )
            )
          )
        )
      }

      shiny::div(
        class = "sf-nta-results-root sf-nta-results-internal-standards tab-content",
        shiny::div(
          class = "features-controls-bar",
          style = "display: flex; align-items: center; justify-content: space-between;",
          shiny::div(
            style = "display: flex; align-items: center; gap: 10px; flex-wrap: wrap;",
            shiny::div(
              style = "display: flex; align-items: center; gap: 8px; flex-wrap: wrap;",
              shiny::span("Group by:", style = "font-weight: 700;"),
              shiny::div(
                style = "display: flex; align-items: center;",
                shiny::radioButtons(
                  ns_full("istd_color_by"),
                  label = NULL,
                  choices = c("Analysis" = "analysis", "Replicate" = "replicate"),
                  selected = "replicate",
                  inline = TRUE
                )
              )
            ),
            shiny::div(
              style = "display: flex; align-items: center; gap: 8px; flex-wrap: wrap;"
            )
          ),
          shiny::div(
            class = "btn-group btn-group-sm",
            shiny::actionButton(ns_full("istd_prop_20_80"), "20:80", class = "btn btn-outline-primary btn-sm"),
            shiny::actionButton(ns_full("istd_prop_30_70"), "30:70", class = "btn btn-outline-primary btn-sm"),
            shiny::actionButton(ns_full("istd_prop_40_60"), "40:60", class = "btn btn-outline-primary btn-sm"),
            shiny::actionButton(ns_full("istd_prop_50_50"), "50:50", class = "btn btn-outline-primary btn-sm active"),
            shiny::actionButton(ns_full("istd_prop_60_40"), "60:40", class = "btn btn-outline-primary btn-sm"),
            shiny::actionButton(ns_full("istd_prop_70_30"), "70:30", class = "btn btn-outline-primary btn-sm"),
            shiny::actionButton(ns_full("istd_prop_80_20"), "80:20", class = "btn btn-outline-primary btn-sm")
          )
        ),
        shiny::div(
          id = ns_full("istd_content_container"),
          class = "sf-nta-features-layout",
          shiny::div(
            id = ns_full("internal_standards_scatter_panel"),
            class = "sf-nta-features-plot-pane",
            style = "flex: 0 0 calc(50% - 10px); max-width: calc(50% - 10px);",
            shiny::div(
              class = "sf-nta-feature-plot-shell",
              shiny::div(
                id = ns_full("internal_standards_scatter_surface"),
                class = "sf-nta-feature-plot-holder sf-nta-loading-surface",
                plotly::plotlyOutput(
                  ns_full("internal_standards_scatter_plot"),
                  height = "100%",
                  width = "100%"
                )
              )
            )
          ),
          shiny::div(
            id = ns_full("internal_standards_details_panel"),
            class = "sf-nta-features-details-pane",
            style = "flex: 0 0 calc(50% - 10px); max-width: calc(50% - 10px);",
            shiny::div(
              class = "sf-nta-details-tabs",
              shiny::tabsetPanel(
                id = ns_full("istd_details_tabs"),
                type = "tabs",
                shiny::tabPanel(
                  title = "EIC",
                  height = "100%",
                  shiny::div(
                    class = "sf-nta-plot-panel",
                    shiny::div(
                      id = ns_full("internal_standard_eic_plot_surface"),
                      class = "sf-nta-plot-body sf-nta-loading-surface",
                      plotly::plotlyOutput(ns_full("internal_standard_eic_plot"), height = "100%")
                    )
                  )
                ),
                shiny::tabPanel(
                  title = "XIC",
                  height = "100%",
                  shiny::div(
                    class = "sf-nta-plot-panel",
                    shiny::div(
                      id = ns_full("internal_standard_xic_plot_surface"),
                      class = "sf-nta-plot-body sf-nta-loading-surface",
                      plotly::plotlyOutput(ns_full("internal_standard_xic_plot"), height = "100%")
                    )
                  )
                ),
                shiny::tabPanel(
                  title = "Profile",
                  height = "100%",
                  shiny::div(
                    class = "sf-nta-plot-panel",
                    shiny::div(
                      id = ns_full("internal_standard_profile_plot_surface"),
                      class = "sf-nta-plot-body sf-nta-loading-surface",
                      plotly::plotlyOutput(ns_full("internal_standard_profile_plot"), height = "100%")
                    )
                  )
                ),
                shiny::tabPanel(
                  title = "MS1",
                  height = "100%",
                  shiny::div(
                    class = "sf-nta-plot-panel",
                    shiny::div(
                      id = ns_full("internal_standard_ms1_plot_surface"),
                      class = "sf-nta-plot-body sf-nta-loading-surface",
                      plotly::plotlyOutput(ns_full("internal_standard_ms1_plot"), height = "100%")
                    )
                  )
                ),
                shiny::tabPanel(
                  title = "MS2",
                  height = "100%",
                  shiny::div(
                    class = "sf-nta-plot-panel",
                    shiny::div(
                      id = ns_full("internal_standard_ms2_plot_surface"),
                      class = "sf-nta-plot-body sf-nta-loading-surface",
                      plotly::plotlyOutput(ns_full("internal_standard_ms2_plot"), height = "100%")
                    )
                  )
                ),
                shiny::tabPanel(
                  title = "Network",
                  height = "100%",
                  shiny::div(
                    class = "sf-nta-network-panel",
                    shiny::div(
                      class = "sf-nta-network-body",
                      visNetwork::visNetworkOutput(
                        ns_full("internal_standard_network_plot"),
                        height = "100%",
                        width = "100%"
                      )
                    )
                  )
                ),
                shiny::tabPanel(
                  title = "Details",
                  shiny::div(class = "sf-nta-table-panel", DT::dataTableOutput(ns_full("internal_standard_details_table")))
                ),
                shiny::tabPanel(
                  title = "Compound",
                  shiny::div(class = "sf-nta-table-panel", DT::dataTableOutput(ns_full("internal_standard_identification_table")))
                ),
                shiny::tabPanel(
                  title = "Metrics",
                  shiny::div(
                    class = "sf-nta-plot-panel",
                    shiny::div(
                      id = ns_full("internal_standard_metrics_plot_surface"),
                      class = "sf-nta-plot-body sf-nta-loading-surface",
                      plotly::plotlyOutput(ns_full("internal_standard_metrics_plot"), height = "100%")
                    )
                  )
                )
              )
            )
          )
        )
      )
    })

    # MARK: internal_standards_data
    internal_standards_data <- shiny::reactive({
      nts <- nta_data()
      istd <- data.table::as.data.table(get_internal_standards(nts))
      if (nrow(istd) == 0) return(istd)
      istd <- data.table::copy(istd)
      digits_for_col <- function(col) {
        col_lower <- tolower(col)
        if (col_lower %in% c("candidate_rank", "polarity", "shared_fragments", "db_ms2_size", "exp_ms2_size")) return(0)
        if (grepl("mass|mz", col_lower)) return(4)
        if (grepl("^rt|_rt$", col_lower)) return(2)
        if (col_lower == "error_mass") return(1)
        if (col_lower %in% c("intensity", "area")) return(0)
        if (col_lower %in% c("score", "cosine_similarity", "xlogp")) return(3)
        2
      }
      num_cols <- names(istd)[sapply(istd, is.numeric)]
      for (col in num_cols) {
        istd[[col]] <- round(istd[[col]], digits_for_col(col))
      }
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
    normalize_inline_svg <- function(svg) {
      if (is.null(svg) || !nzchar(svg)) return("")
      svg <- sub("^\\s*<\\?xml[^>]*>\\s*", "", svg)
      svg <- sub("^\\s*<!DOCTYPE[^>]*>\\s*", "", svg, ignore.case = TRUE)
      svg
    }

    svg_data_uri <- function(svg) {
      if (is.null(svg) || !nzchar(svg)) return("")
      paste0(
        "data:image/svg+xml;base64,",
        base64enc::base64encode(charToRaw(enc2utf8(svg)))
      )
    }

    create_structure_image <- function(smiles, inchi = NULL, width = 180, height = 200, darkMode = FALSE) {
      if ((is.null(smiles) || is.na(smiles) || !nzchar(smiles)) &&
          (is.null(inchi) || is.na(inchi) || !nzchar(inchi))) return("")
      if (!requireNamespace("base64enc", quietly = TRUE)) return("")
      tryCatch(
        {
          svg <- rcpp_openbabel_structure_svg(
            SMILES = if (!is.null(smiles) && !is.na(smiles) && nzchar(smiles)) smiles else NULL,
            InChI = if (!is.null(inchi) && !is.na(inchi) && nzchar(inchi)) inchi else NULL,
            width = as.integer(width),
            height = as.integer(height),
            darkMode = isTRUE(darkMode)
          )
          if (is.null(svg) || !nzchar(svg)) return("")
          svg_data_uri(normalize_inline_svg(svg))
        },
        error = function(e) {
          ""
        }
      )
    }

    # MARK: create_spectra_image
    create_spectra_image <- function(nts, analysis, feature, width = 900, height = 450, darkMode = FALSE) {
      if (is.null(analysis) || is.null(feature)) return("")
      if (!requireNamespace("base64enc", quietly = TRUE)) return("")
      if (!requireNamespace("ggplot2", quietly = TRUE)) return("")
      if (!capabilities("cairo")) return("")
      tryCatch(
        {
          sel <- data.table::data.table(analysis = analysis, feature = feature)
          p <- plot_suspects_ms2(
            nts,
            features = sel,
            interactive = FALSE,
            showLegend = FALSE,
            showText = FALSE,
            darkMode = darkMode
          )
          if (is.null(p)) return("")
          temp_file <- tempfile(fileext = ".svg")
          grDevices::svg(filename = temp_file, width = width / 72, height = height / 72, bg = "transparent", onefile = TRUE)
          print(p)
          grDevices::dev.off()
          svg <- paste(readLines(temp_file, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
          unlink(temp_file)
          svg_data_uri(normalize_inline_svg(svg))
        },
        error = function(e) {
          ""
        }
      )
    }

    create_feature_spectra_image <- function(nts, analysis, feature, width = 900, height = 450, darkMode = FALSE) {
      if (is.null(analysis) || is.null(feature)) return("")
      if (!requireNamespace("base64enc", quietly = TRUE)) return("")
      if (!requireNamespace("ggplot2", quietly = TRUE)) return("")
      if (!capabilities("cairo")) return("")
      tryCatch(
        {
          sel <- data.table::data.table(analysis = analysis, feature = feature)
          p <- plot_features_ms2(
            nts,
            features = sel,
            interactive = FALSE,
            showLegend = FALSE,
            darkMode = darkMode
          )
          if (is.null(p)) return("")
          temp_file <- tempfile(fileext = ".svg")
          grDevices::svg(filename = temp_file, width = width / 72, height = height / 72, bg = "transparent", onefile = TRUE)
          print(p)
          grDevices::dev.off()
          svg <- paste(readLines(temp_file, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
          unlink(temp_file)
          svg_data_uri(normalize_inline_svg(svg))
        },
        error = function(e) {
          ""
        }
      )
    }

    analyses_info <- shiny::reactive({
      info(nta_data())
    })

    add_replicates <- function(dt, analyses_info_dt = analyses_info()) {
      dt <- data.table::copy(data.table::as.data.table(dt))
      if (!"analysis" %in% colnames(dt) || !"replicate" %in% colnames(analyses_info_dt)) return(dt)
      rep_map <- analyses_info_dt$replicate
      names(rep_map) <- analyses_info_dt$analysis
      dt$replicate <- rep_map[as.character(dt$analysis)]
      dt
    }

    build_identification_table <- function(
        dt,
        nts,
        darkMode = FALSE,
        spectra_mode = c("suspect", "feature")) {
      spectra_mode <- match.arg(spectra_mode)
      dt <- data.table::copy(data.table::as.data.table(dt))
      if (nrow(dt) == 0) return(dt)

      dt <- add_replicates(dt)

      smiles_vec <- if ("SMILES" %in% colnames(dt)) dt$SMILES else rep(NA_character_, nrow(dt))
      inchi_vec <- if ("InChI" %in% colnames(dt)) dt$InChI else rep(NA_character_, nrow(dt))
      dt$structure <- mapply(
        function(smiles, inchi) {
          img_uri <- create_structure_image(smiles, inchi, darkMode = darkMode)
          if (!nzchar(img_uri)) return("")
          sprintf("<img class='suspect-structure-img' src='%s' alt=''/>", img_uri)
        },
        smiles_vec,
        inchi_vec,
        SIMPLIFY = TRUE,
        USE.NAMES = FALSE
      )

      dt$spectra <- mapply(
        function(analysis, feature) {
          img_uri <- if (identical(spectra_mode, "suspect")) {
            create_spectra_image(nts, analysis, feature, darkMode = darkMode)
          } else {
            create_feature_spectra_image(nts, analysis, feature, darkMode = darkMode)
          }
          if (!nzchar(img_uri)) return("")
          sprintf("<img class='suspect-spectra-img' src='%s' alt=''/>", img_uri)
        },
        dt$analysis,
        dt$feature,
        SIMPLIFY = TRUE,
        USE.NAMES = FALSE
      )

      exclude_cols <- c(
        "db_ms2_mz",
        "db_ms2_intensity",
        "db_ms2_formula",
        "exp_ms2_mz",
        "exp_ms2_intensity",
        "created_at"
      )
      keep_cols <- setdiff(colnames(dt), exclude_cols)
      base_cols <- c(
        "structure", "name", "spectra", "analysis", "replicate",
        "feature", "feature_component", "feature_group", "candidate_rank",
        "id_level", "score", "shared_fragments", "cosine_similarity",
        "formula", "InChIKey", "xLogP", "error_mass", "error_rt",
        "db_ms2_size", "exp_ms2_size"
      )
      base_cols <- base_cols[base_cols %in% keep_cols]
      rest_cols <- setdiff(keep_cols, base_cols)
      dt[, c(base_cols, rest_cols), with = FALSE]
    }

    feature_network_key <- function(analysis, feature) {
      paste(as.character(analysis), as.character(feature), sep = "||")
    }

    feature_network_format_num <- function(x, digits = 3) {
      x <- suppressWarnings(as.numeric(x))
      ifelse(is.finite(x), formatC(x, format = "f", digits = digits), "")
    }

    feature_network_flag <- function(x) {
      !is.na(x) & as.logical(x)
    }

    feature_network_node_role <- function(annotation_category, adduct) {
      annotation_category <- if (length(annotation_category) == 0 || is.na(annotation_category)) "" else trimws(as.character(annotation_category))
      adduct <- if (length(adduct) == 0 || is.na(adduct)) "" else trimws(as.character(adduct))
      if (identical(annotation_category, "isotope")) return("isotope")
      if (identical(annotation_category, "adduct")) return("adduct")
      if (identical(annotation_category, "loss")) return("loss")
      if (adduct %in% c("[M+H]+", "[M-H]-")) return("precursor")
      "feature"
    }

    feature_network_node_text <- function(role, adduct = "", annotation_type = "", annotation_element = "") {
      role <- if (length(role) == 0 || is.na(role)) "" else trimws(as.character(role))
      adduct <- if (length(adduct) == 0 || is.na(adduct)) "" else trimws(as.character(adduct))
      annotation_type <- if (length(annotation_type) == 0 || is.na(annotation_type)) "" else trimws(as.character(annotation_type))
      annotation_element <- if (length(annotation_element) == 0 || is.na(annotation_element)) "" else trimws(as.character(annotation_element))

      if (identical(role, "isotope")) {
        if (nzchar(annotation_element)) return(annotation_element)
        if (nzchar(annotation_type)) return(annotation_type)
        return("i")
      }
      if (identical(role, "adduct")) {
        if (nzchar(annotation_type)) return(annotation_type)
        if (nzchar(adduct)) return(adduct)
        return("A")
      }
      if (identical(role, "loss")) {
        if (nzchar(annotation_element)) return(annotation_element)
        if (nzchar(annotation_type)) return(annotation_type)
        return("L")
      }
      if (nzchar(adduct)) return(adduct)
      "[M]"
    }

    feature_network_modal_table <- function(entries) {
      entries <- Filter(function(x) {
        val <- as.character(x$value)
        !is.na(val) && nzchar(val)
      }, entries)
      if (length(entries) == 0) {
        return("<div style='color:#666;'>No metadata available.</div>")
      }
      rows <- vapply(
        entries,
        function(item) {
          paste0(
            "<tr style='border-bottom:1px solid #ececec;'>",
            "<td style='padding:4px 8px;font-weight:600;vertical-align:top;white-space:nowrap;'>",
            htmltools::htmlEscape(item$label),
            "</td>",
            "<td style='padding:4px 8px;vertical-align:top;'>",
            htmltools::htmlEscape(item$value),
            "</td></tr>"
          )
        },
        character(1)
      )
      paste0(
        "<table style='width:100%;border-collapse:collapse;font-size:12px;'>",
        paste(rows, collapse = ""),
        "</table>"
      )
    }

    build_feature_network_widget <- function(nodes, edges, widget_id) {
      safe_id <- gsub("[^A-Za-z0-9_]+", "_", widget_id)

      widget <- visNetwork::visNetwork(nodes, edges, height = "100%", width = "100%") %>%
        visNetwork::visNodes(
          font = list(size = 13, color = "#ffffff", face = "Arial", strokeWidth = 0, strokeColor = "rgba(0,0,0,0)"),
          scaling = list(min = 10, max = 28),
          shapeProperties = list(borderRadius = 2),
          margin = 2,
          chosen = FALSE
        ) %>%
        visNetwork::visEdges(
          smooth = FALSE,
          selectionWidth = 0,
          hoverWidth = 0.6,
          font = list(size = 1, color = "rgba(0,0,0,0)", face = "Arial", strokeWidth = 0, strokeColor = "rgba(0,0,0,0)"),
          chosen = FALSE
        ) %>%
        visNetwork::visInteraction(hover = TRUE, hoverConnectedEdges = FALSE, navigationButtons = FALSE, tooltipDelay = 100) %>%
        visNetwork::visPhysics(
          enabled = TRUE,
          stabilization = list(enabled = TRUE, iterations = 200),
          solver = "forceAtlas2Based",
          forceAtlas2Based = list(gravitationalConstant = -55, centralGravity = 0.01, springLength = 120, springConstant = 0.045, damping = 0.8)
        ) %>%
        visNetwork::visLayout(randomSeed = 123) %>%
        visNetwork::visOptions(highlightNearest = list(enabled = TRUE, degree = 1, hover = TRUE))

      on_render_js <- paste0(
        "function(el, x) {
          var network = this;
          if (!el) return;
          el.style.position = 'relative';
          var styleId = 'sf-nta-net-style-%1$s';
          if (!document.getElementById(styleId)) {
            var style = document.createElement('style');
            style.id = styleId;
            style.textContent =
              '.sf-nta-net-modal-overlay-%1$s{display:none;position:fixed;inset:0;background:rgba(20,26,38,0.35);z-index:9998;align-items:center;justify-content:center;}' +
              '.sf-nta-net-modal-%1$s{width:88vw;height:82vh;background:#fff;border-radius:8px;box-shadow:0 20px 50px rgba(0,0,0,0.28);display:flex;flex-direction:column;overflow:hidden;}' +
              '.sf-nta-net-modal-header-%1$s{display:flex;align-items:center;justify-content:space-between;padding:10px 14px;border-bottom:1px solid #e3e3e3;background:#fafafa;}' +
              '.sf-nta-net-modal-title-%1$s{font-size:15px;font-weight:600;color:#1f2937;}' +
              '.sf-nta-net-modal-close-%1$s{border:none;background:transparent;font-size:22px;line-height:1;cursor:pointer;color:#666;}' +
              '.sf-nta-net-modal-content-%1$s{flex:1 1 auto;min-height:0;overflow:auto;padding:10px 14px;background:#fff;}' +
              '.sf-nta-net-legend-%1$s{position:absolute;right:8px;top:8px;z-index:20;background:transparent;border:none;border-radius:0;padding:0;font-size:11px;color:#1f2937;}' +
              '.sf-nta-net-legend-row-%1$s{display:flex;align-items:center;gap:6px;white-space:nowrap;}' +
              '.sf-nta-net-legend-row-%1$s + .sf-nta-net-legend-row-%1$s{margin-top:4px;}' +
              '.sf-nta-net-legend-box-%1$s{width:14px;height:14px;border-radius:2px;border:1px solid currentColor;display:inline-flex;align-items:center;justify-content:center;font-size:9px;font-weight:700;line-height:1;}';
            document.head.appendChild(style);
          }
          var overlayId = 'sf-nta-net-overlay-%1$s';
          var overlay = document.getElementById(overlayId);
          if (!overlay) {
            overlay = document.createElement('div');
            overlay.id = overlayId;
            overlay.className = 'sf-nta-net-modal-overlay-%1$s';
            overlay.innerHTML =
              '<div class=\"sf-nta-net-modal-%1$s\">' +
              '<div class=\"sf-nta-net-modal-header-%1$s\">' +
              '<div class=\"sf-nta-net-modal-title-%1$s\">Node Details</div>' +
              '<button type=\"button\" class=\"sf-nta-net-modal-close-%1$s\">×</button>' +
              '</div>' +
              '<div class=\"sf-nta-net-modal-content-%1$s\"></div>' +
              '</div>';
            document.body.appendChild(overlay);
            overlay.addEventListener('click', function(e){ if (e.target === overlay) overlay.style.display = 'none'; });
            overlay.querySelector('.sf-nta-net-modal-close-%1$s').addEventListener('click', function(){ overlay.style.display = 'none'; });
          }
          if (!el.querySelector('.sf-nta-net-legend-%1$s')) {
            var legend = document.createElement('div');
            legend.className = 'sf-nta-net-legend-%1$s';
            legend.innerHTML =
              '<div class=\"sf-nta-net-legend-row-%1$s\"><span class=\"sf-nta-net-legend-box-%1$s\" style=\"color:#166534;background:#166534;\">F</span><span>feature</span></div>' +
              '<div class=\"sf-nta-net-legend-row-%1$s\"><span class=\"sf-nta-net-legend-box-%1$s\" style=\"color:#6b7280;background:#6b7280;\"> i </span><span>isotope</span></div>' +
              '<div class=\"sf-nta-net-legend-row-%1$s\"><span class=\"sf-nta-net-legend-box-%1$s\" style=\"color:#1e3a8a;background:#1e3a8a;\">A</span><span>adduct</span></div>' +
              '<div class=\"sf-nta-net-legend-row-%1$s\"><span class=\"sf-nta-net-legend-box-%1$s\" style=\"color:#991b1b;background:#991b1b;\">L</span><span>loss</span></div>';
            el.appendChild(legend);
          }
          function shadeColor(hex, alpha) {
            return { background: hex, border: hex, highlight: { background: hex, border: hex }, hover: { background: hex, border: hex } };
          }
          function emphasizeNode(nodeId, scale) {
            if (!nodeId || !network.body || !network.body.data || !network.body.data.nodes) return;
            var node = null;
            try { node = network.body.data.nodes.get(nodeId); } catch(e) { node = null; }
            if (!node) return;
            var baseValue = (typeof node.base_value === 'number' && isFinite(node.base_value)) ? node.base_value : node.value;
            var baseColor = node.base_background || '#64748b';
            var baseBorder = node.base_border || baseColor;
            network.body.data.nodes.update({
              id: nodeId,
              value: baseValue * scale,
              color: {
                background: baseColor,
                border: baseBorder,
                highlight: { background: baseColor, border: baseBorder },
                hover: { background: baseColor, border: baseBorder }
              },
              shadow: { enabled: true, color: node.shadow_color || 'rgba(0,0,0,0.22)', size: 20, x: 0, y: 0 }
            });
          }
          function resetNode(nodeId) {
            if (!nodeId || !network.body || !network.body.data || !network.body.data.nodes) return;
            var node = null;
            try { node = network.body.data.nodes.get(nodeId); } catch(e) { node = null; }
            if (!node) return;
            var baseValue = (typeof node.base_value === 'number' && isFinite(node.base_value)) ? node.base_value : node.value;
            var baseColor = node.base_background || '#64748b';
            var baseBorder = node.base_border || baseColor;
            var seedShadow = !!node.is_seed;
            network.body.data.nodes.update({
              id: nodeId,
              value: baseValue,
              color: {
                background: baseColor,
                border: baseBorder,
                highlight: { background: baseColor, border: baseBorder },
                hover: { background: baseColor, border: baseBorder }
              },
              shadow: seedShadow ? { enabled: true, color: node.shadow_color || 'rgba(0,0,0,0.22)', size: 18, x: 0, y: 0 } : false
            });
          }
          function emphasizeEdge(edgeId, scale) {
            if (!edgeId || !network.body || !network.body.data || !network.body.data.edges) return;
            var edge = null;
            try { edge = network.body.data.edges.get(edgeId); } catch(e) { edge = null; }
            if (!edge) return;
            var baseWidth = (typeof edge.base_width === 'number' && isFinite(edge.base_width)) ? edge.base_width : edge.width;
            var baseColor = edge.base_color || '#64748b';
            network.body.data.edges.update({
              id: edgeId,
              width: baseWidth * scale,
              color: { color: baseColor, highlight: baseColor, hover: baseColor }
            });
          }
          function resetEdge(edgeId) {
            if (!edgeId || !network.body || !network.body.data || !network.body.data.edges) return;
            var edge = null;
            try { edge = network.body.data.edges.get(edgeId); } catch(e) { edge = null; }
            if (!edge) return;
            var baseWidth = (typeof edge.base_width === 'number' && isFinite(edge.base_width)) ? edge.base_width : edge.width;
            var baseColor = edge.base_color || '#64748b';
            network.body.data.edges.update({
              id: edgeId,
              width: baseWidth,
              color: { color: baseColor, highlight: baseColor, hover: baseColor }
            });
          }
          network.off && network.off('hoverNode');
          network.off && network.off('blurNode');
          network.on('hoverNode', function(params) {
            emphasizeNode(params.node, 1.18);
            var conn = network.getConnectedEdges(params.node) || [];
            for (var i = 0; i < conn.length; i++) emphasizeEdge(conn[i], 1.18);
          });
          network.on('blurNode', function(params) {
            resetNode(params.node);
            var conn = network.getConnectedEdges(params.node) || [];
            for (var i = 0; i < conn.length; i++) resetEdge(conn[i]);
          });
          network.off && network.off('hoverEdge');
          network.off && network.off('blurEdge');
          network.on('hoverEdge', function(params) { emphasizeEdge(params.edge, 1.18); });
          network.on('blurEdge', function(params) { resetEdge(params.edge); });
          network.off && network.off('selectNode');
          network.on('selectNode', function(params) {
            if (!params.nodes || !params.nodes.length) return;
            emphasizeNode(params.nodes[0], 1.22);
            var conn = network.getConnectedEdges(params.nodes[0]) || [];
            for (var i = 0; i < conn.length; i++) emphasizeEdge(conn[i], 1.22);
            var node = null;
            try { node = network.body.data.nodes.get(params.nodes[0]); } catch(e) { node = null; }
            if (!node) return;
            var titleEl = overlay.querySelector('.sf-nta-net-modal-title-%1$s');
            var contentEl = overlay.querySelector('.sf-nta-net-modal-content-%1$s');
            if (titleEl) titleEl.textContent = node.node_label || node.label || node.id || 'Node Details';
            if (contentEl) contentEl.innerHTML = node.overview_html || '<div style=\"color:#666;\">No metadata available.</div>';
            overlay.style.display = 'flex';
          });
          network.off && network.off('deselectNode');
          network.on('deselectNode', function(params) {
            var prev = (params.previousSelection && params.previousSelection.nodes) ? params.previousSelection.nodes : [];
            for (var i = 0; i < prev.length; i++) {
              resetNode(prev[i]);
              var conn = network.getConnectedEdges(prev[i]) || [];
              for (var j = 0; j < conn.length; j++) resetEdge(conn[j]);
            }
          });
        }"
      )
      on_render_js <- gsub("%1$s", safe_id, on_render_js, fixed = TRUE)
      widget <- htmlwidgets::onRender(widget, on_render_js)
      widget
    }

    build_feature_network_data <- function(feature_dt, selected_rows, selection_mode = "feature", internal_standard_dt = NULL) {
      fts <- data.table::copy(data.table::as.data.table(feature_dt))
      if (nrow(fts) == 0 || is.null(selected_rows) || nrow(selected_rows) == 0) {
        return(NULL)
      }
      if (!all(c("analysis", "feature") %in% colnames(fts))) {
        return(NULL)
      }

      fts$analysis <- as.character(fts$analysis)
      fts$feature <- as.character(fts$feature)
      if ("feature_component" %in% colnames(fts)) fts$feature_component <- as.character(fts$feature_component)
      if ("feature_group" %in% colnames(fts)) fts$feature_group <- as.character(fts$feature_group)
      fts$node_id <- feature_network_key(fts$analysis, fts$feature)

      seeds <- data.table::copy(data.table::as.data.table(selected_rows))
      if (!all(c("analysis", "feature") %in% colnames(seeds))) {
        return(NULL)
      }
      seeds$analysis <- as.character(seeds$analysis)
      seeds$feature <- as.character(seeds$feature)
      seeds$node_id <- feature_network_key(seeds$analysis, seeds$feature)
      seed_ids <- unique(seeds$node_id)
      seed_dt <- fts[node_id %in% seed_ids]
      if (nrow(seed_dt) == 0) {
        return(NULL)
      }

      display_dt <- switch(
        selection_mode,
        feature_component = {
          comps <- unique(seed_dt$feature_component)
          comps <- comps[!is.na(comps) & nzchar(comps)]
          if (length(comps) == 0) seed_dt else fts[feature_component %in% comps & analysis %in% unique(seed_dt$analysis)]
        },
        feature_group = {
          groups <- unique(seed_dt$feature_group)
          groups <- groups[!is.na(groups) & nzchar(groups)]
          group_members <- if (length(groups) == 0) seed_dt else fts[feature_group %in% groups]
          comps <- unique(group_members$feature_component)
          comps <- comps[!is.na(comps) & nzchar(comps)]
          component_neighbors <- if (length(comps) == 0) group_members else fts[feature_component %in% comps & analysis %in% unique(group_members$analysis)]
          unique(data.table::rbindlist(list(group_members, component_neighbors), fill = TRUE), by = "node_id")
        },
        {
          comps <- unique(seed_dt$feature_component)
          comps <- comps[!is.na(comps) & nzchar(comps)]
          if (length(comps) == 0) seed_dt else fts[feature_component %in% comps & analysis %in% unique(seed_dt$analysis)]
        }
      )

      if (nrow(display_dt) == 0) {
        return(NULL)
      }

      display_dt$is_seed <- identical(selection_mode, "feature") & (display_dt$node_id %in% seed_ids)
      display_dt$is_group_primary <- FALSE
      if (identical(selection_mode, "feature_group") && "feature_group" %in% colnames(display_dt) && "feature_group" %in% colnames(seed_dt)) {
        seed_groups <- unique(seed_dt$feature_group)
        seed_groups <- seed_groups[!is.na(seed_groups) & nzchar(seed_groups)]
        display_dt$is_group_primary <- display_dt$feature_group %in% seed_groups
      }

      if (!is.null(internal_standard_dt) && nrow(internal_standard_dt) > 0) {
        istd <- data.table::copy(data.table::as.data.table(internal_standard_dt))
        if (all(c("analysis", "feature") %in% colnames(istd))) {
          istd$analysis <- as.character(istd$analysis)
          istd$feature <- as.character(istd$feature)
          keep_cols <- intersect(
            c("analysis", "feature", "name", "formula", "SMILES", "InChIKey", "score", "candidate_rank", "id_level", "cosine_similarity", "shared_fragments", "error_mass", "error_rt"),
            colnames(istd)
          )
          if (length(keep_cols) > 2) {
            istd <- unique(istd[, ..keep_cols], by = c("analysis", "feature"))
            display_dt <- merge(display_dt, istd, by = c("analysis", "feature"), all.x = TRUE, suffixes = c("", "_istd"), sort = FALSE)
          }
        }
      }

      display_dt[, annotation_category_chr := if ("annotation_category" %in% colnames(display_dt)) as.character(annotation_category) else ""]
      display_dt[, annotation_parent_feature_chr := if ("annotation_parent_feature" %in% colnames(display_dt)) as.character(annotation_parent_feature) else ""]
      display_dt[, role := mapply(feature_network_node_role, annotation_category_chr, if ("adduct" %in% colnames(display_dt)) adduct else "", USE.NAMES = FALSE)]
      display_dt[, is_precursor_like := role %in% c("precursor", "feature")]
      display_dt[, is_main_ion := is_precursor_like & ("adduct" %in% colnames(display_dt)) & adduct %in% c("[M+H]+", "[M-H]-")]

      resolve_annotation_parent <- function(row) {
        parent_feature <- as.character(row$annotation_parent_feature_chr)
        if (!nzchar(parent_feature)) return(NULL)
        parent <- display_dt[analysis == row$analysis & feature == parent_feature]
        if (nrow(parent) == 0) return(NULL)
        parent[1]
      }

      edge_rows <- list()
      push_edge <- function(from_id, to_id, category, score, label) {
        if (!nzchar(from_id) || !nzchar(to_id) || identical(from_id, to_id)) return()
        edge_rows[[length(edge_rows) + 1]] <<- data.table::data.table(
          from = from_id,
          to = to_id,
          edge_category = category,
          score = score,
          edge_label = label
        )
      }

      for (i in seq_len(nrow(display_dt))) {
        child <- display_dt[i]
        child_cat <- as.character(child$annotation_category_chr)
        if (!child_cat %in% c("isotope", "adduct", "loss")) next
        parent <- resolve_annotation_parent(child)
        if (is.null(parent) || nrow(parent) == 0) next
        child_score <- if ("annotation_score" %in% colnames(display_dt)) suppressWarnings(as.numeric(child$annotation_score[[1]])) else NA_real_
        if (!is.finite(child_score)) child_score <- 0
        push_edge(
          as.character(parent$node_id),
          as.character(child$node_id),
          child_cat,
          child_score,
          paste0(child_cat, " ", as.character(child$annotation_type))
        )
      }

      if (identical(selection_mode, "feature_group") && "feature_group" %in% colnames(display_dt)) {
        valid_group_dt <- display_dt[!is.na(feature_group) & nzchar(feature_group) & is_main_ion %in% TRUE]
        group_groups <- split(valid_group_dt, valid_group_dt$feature_group)
        for (grp in group_groups) {
          if (nrow(grp) < 2) next
          idx <- utils::combn(seq_len(nrow(grp)), 2)
          for (j in seq_len(ncol(idx))) {
            a <- grp[idx[1, j]]
            b <- grp[idx[2, j]]
            push_edge(a$node_id, b$node_id, "group", 0.55, "same annotated group")
          }
        }
      }

      edges <- if (length(edge_rows) == 0) {
        data.table::data.table(from = character(0), to = character(0), edge_category = character(0), score = numeric(0), edge_label = character(0))
      } else {
        data.table::rbindlist(edge_rows, fill = TRUE)
      }

      if (nrow(edges) > 0) {
        pair_sep <- "<<<PAIR>>>"
        edges[, pair_id := ifelse(from < to, paste(from, to, sep = pair_sep), paste(to, from, sep = pair_sep))]
        edges <- edges[, .(
          categories = paste(unique(edge_category), collapse = "|"),
          score = max(score, na.rm = TRUE),
          edge_label = paste(unique(edge_label), collapse = " | ")
        ), by = pair_id]
        edges[!is.finite(score), score := 0]
        edges[, c("from", "to") := tstrsplit(pair_id, pair_sep, fixed = TRUE)]
        edges[, primary_category := fifelse(grepl("isotope", categories, fixed = TRUE), "isotope",
          fifelse(grepl("adduct", categories, fixed = TRUE), "adduct",
            fifelse(grepl("loss", categories, fixed = TRUE), "loss", "group")))]
        edges[, score_clamped := pmin(pmax(score, 0), 1)]
        edges[, length := fifelse(
          primary_category == "group",
          220,
          fifelse(
            primary_category == "isotope",
            70 + (1 - score_clamped) * 90,
            fifelse(
              primary_category == "adduct",
              85 + (1 - score_clamped) * 95,
              95 + (1 - score_clamped) * 105
            )
          )
        )]
        edges[, width := fifelse(primary_category == "isotope", 2.6,
          fifelse(primary_category == "adduct", 2.3,
            fifelse(primary_category == "loss", 2.1, 1.6)))]
        edges[, dashes := primary_category %in% c("group", "loss")]
        edges[, color := fifelse(primary_category == "isotope", "#6b7280",
          fifelse(primary_category == "adduct", "#1e3a8a",
            fifelse(primary_category == "loss", "#991b1b", "#64748b")))]
        edges[, title := paste0(edge_label, " | score=", feature_network_format_num(score, 3))]
        edges[, label := ""]
        edges[, base_width := width]
        edges[, base_color := color]
        edges <- edges[, .(from, to, label, title, width, length, dashes, base_width, base_color, color = lapply(color, function(x) list(color = x, highlight = x, hover = x))), ]
      }

      connected_ids <- if (nrow(edges) > 0) unique(c(edges$from, edges$to)) else character(0)
      display_dt[, has_graph_edge := node_id %in% connected_ids]

      display_dt[, node_group := fifelse(role == "isotope", "isotope",
        fifelse(role == "adduct", "adduct",
          fifelse(role == "loss", "loss", "feature")))]
      node_color <- c(
        feature = "#166534",
        isotope = "#6b7280",
        adduct = "#1e3a8a",
        loss = "#991b1b"
      )
      node_border <- c(
        feature = "#14532d",
        isotope = "#4b5563",
        adduct = "#1e40af",
        loss = "#7f1d1d"
      )
      display_dt[, label := mapply(
        feature_network_node_text,
        role,
        if ("adduct" %in% colnames(display_dt)) adduct else "",
        if ("annotation_type" %in% colnames(display_dt)) annotation_type else "",
        if ("annotation_element" %in% colnames(display_dt)) annotation_element else "",
        USE.NAMES = FALSE
      )]
      display_dt[, value := pmax(14, pmin(26, 12 + log10(pmax(1, as.numeric(intensity))) * 2.2))]
      display_dt[, title := paste0(
        "<b>", htmltools::htmlEscape(feature), "</b><br>",
        "analysis: ", htmltools::htmlEscape(analysis), "<br>",
        "role: ", htmltools::htmlEscape(role), "<br>",
        "component: ", htmltools::htmlEscape(if ("feature_component" %in% colnames(display_dt)) feature_component else ""), "<br>",
        "group: ", htmltools::htmlEscape(if ("feature_group" %in% colnames(display_dt)) feature_group else ""), "<br>",
        "mass: ", feature_network_format_num(mass, 4), "<br>",
        "rt: ", feature_network_format_num(rt, 2), "<br>",
        "intensity: ", feature_network_format_num(intensity, 0), "<br>",
        "adduct: ", htmltools::htmlEscape(if ("adduct" %in% colnames(display_dt)) adduct else ""), "<br>",
        "element: ", htmltools::htmlEscape(if ("annotation_element" %in% colnames(display_dt)) as.character(annotation_element) else ""), "<br>",
        "dev_ppm: ", feature_network_format_num(if ("annotation_mass_error_ppm" %in% colnames(display_dt)) annotation_mass_error_ppm else NA_real_, 3), "<br>",
        "dev_rt: ", feature_network_format_num(if ("annotation_rt_error" %in% colnames(display_dt)) annotation_rt_error else NA_real_, 3), "<br>",
        "connected: ", ifelse(has_graph_edge, "yes", "no")
      )]

      display_dt[, overview_html := mapply(
        function(feature, analysis, feature_component, feature_group, mass, rt, intensity, adduct,
                 annotation_category, annotation_type, annotation_parent_feature, annotation_element,
                 annotation_mass_error_ppm, annotation_rt_error, annotation_rel_intensity,
                 component_size, component_rt_center, component_rt_spread, component_density,
                 component_mean_correlation, component_best_partner, component_max_correlation,
                 component_mean_correlation_to_component, component_membership_score,
                 component_is_core, component_bridge_flag, name, formula, score, candidate_rank,
                 id_level, cosine_similarity, shared_fragments, error_mass, error_rt) {
          entries <- list(
            list(label = "Feature", value = as.character(feature)),
            list(label = "Analysis", value = as.character(analysis)),
            list(label = "Component", value = as.character(feature_component)),
            list(label = "Group", value = as.character(feature_group)),
            list(label = "Mass", value = feature_network_format_num(mass, 4)),
            list(label = "RT", value = feature_network_format_num(rt, 2)),
            list(label = "Intensity", value = feature_network_format_num(intensity, 0)),
            list(label = "Adduct", value = as.character(adduct)),
            list(label = "Annotation Category", value = as.character(annotation_category)),
            list(label = "Annotation Type", value = as.character(annotation_type)),
            list(label = "Annotation Parent", value = as.character(annotation_parent_feature)),
            list(label = "Element", value = as.character(annotation_element)),
            list(label = "dev_ppm", value = feature_network_format_num(annotation_mass_error_ppm, 3)),
            list(label = "dev_rt", value = feature_network_format_num(annotation_rt_error, 3)),
            list(label = "Annotation Rel Intensity", value = feature_network_format_num(annotation_rel_intensity, 3)),
            list(label = "Component Size", value = feature_network_format_num(component_size, 0)),
            list(label = "Component RT Center", value = feature_network_format_num(component_rt_center, 2)),
            list(label = "Component RT Spread", value = feature_network_format_num(component_rt_spread, 2)),
            list(label = "Component Density", value = feature_network_format_num(component_density, 3)),
            list(label = "Component Mean Corr", value = feature_network_format_num(component_mean_correlation, 3)),
            list(label = "Best Partner", value = as.character(component_best_partner)),
            list(label = "Max Corr", value = feature_network_format_num(component_max_correlation, 3)),
            list(label = "Mean Corr To Component", value = feature_network_format_num(component_mean_correlation_to_component, 3)),
            list(label = "Membership Score", value = feature_network_format_num(component_membership_score, 3)),
            list(label = "Core", value = ifelse(feature_network_flag(component_is_core), "TRUE", "")),
            list(label = "Bridge", value = ifelse(feature_network_flag(component_bridge_flag), "TRUE", "")),
            list(label = "Name", value = as.character(name)),
            list(label = "Formula", value = as.character(formula)),
            list(label = "Score", value = feature_network_format_num(score, 3)),
            list(label = "Candidate Rank", value = feature_network_format_num(candidate_rank, 0)),
            list(label = "ID Level", value = feature_network_format_num(id_level, 0)),
            list(label = "Cosine Similarity", value = feature_network_format_num(cosine_similarity, 3)),
            list(label = "Shared Fragments", value = feature_network_format_num(shared_fragments, 0)),
            list(label = "Mass Error", value = feature_network_format_num(error_mass, 3)),
            list(label = "RT Error", value = feature_network_format_num(error_rt, 3))
          )
          feature_network_modal_table(entries)
        },
        feature, analysis,
        if ("feature_component" %in% colnames(display_dt)) feature_component else "",
        if ("feature_group" %in% colnames(display_dt)) feature_group else "",
        if ("mass" %in% colnames(display_dt)) mass else NA_real_,
        if ("rt" %in% colnames(display_dt)) rt else NA_real_,
        if ("intensity" %in% colnames(display_dt)) intensity else NA_real_,
        if ("adduct" %in% colnames(display_dt)) adduct else "",
        if ("annotation_category" %in% colnames(display_dt)) annotation_category else "",
        if ("annotation_type" %in% colnames(display_dt)) annotation_type else "",
        if ("annotation_parent_feature" %in% colnames(display_dt)) annotation_parent_feature else "",
        if ("annotation_element" %in% colnames(display_dt)) annotation_element else "",
        if ("annotation_mass_error_ppm" %in% colnames(display_dt)) annotation_mass_error_ppm else NA_real_,
        if ("annotation_rt_error" %in% colnames(display_dt)) annotation_rt_error else NA_real_,
        if ("annotation_rel_intensity" %in% colnames(display_dt)) annotation_rel_intensity else NA_real_,
        if ("component_size" %in% colnames(display_dt)) component_size else NA_real_,
        if ("component_rt_center" %in% colnames(display_dt)) component_rt_center else NA_real_,
        if ("component_rt_spread" %in% colnames(display_dt)) component_rt_spread else NA_real_,
        if ("component_density" %in% colnames(display_dt)) component_density else NA_real_,
        if ("component_mean_correlation" %in% colnames(display_dt)) component_mean_correlation else NA_real_,
        if ("component_best_partner" %in% colnames(display_dt)) component_best_partner else "",
        if ("component_max_correlation" %in% colnames(display_dt)) component_max_correlation else NA_real_,
        if ("component_mean_correlation_to_component" %in% colnames(display_dt)) component_mean_correlation_to_component else NA_real_,
        if ("component_membership_score" %in% colnames(display_dt)) component_membership_score else NA_real_,
        if ("component_is_core" %in% colnames(display_dt)) component_is_core else FALSE,
        if ("component_bridge_flag" %in% colnames(display_dt)) component_bridge_flag else FALSE,
        if ("name" %in% colnames(display_dt)) name else "",
        if ("formula" %in% colnames(display_dt)) formula else "",
        if ("score" %in% colnames(display_dt)) score else NA_real_,
        if ("candidate_rank" %in% colnames(display_dt)) candidate_rank else NA_real_,
        if ("id_level" %in% colnames(display_dt)) id_level else NA_real_,
        if ("cosine_similarity" %in% colnames(display_dt)) cosine_similarity else NA_real_,
        if ("shared_fragments" %in% colnames(display_dt)) shared_fragments else NA_real_,
        if ("error_mass" %in% colnames(display_dt)) error_mass else NA_real_,
        if ("error_rt" %in% colnames(display_dt)) error_rt else NA_real_,
        SIMPLIFY = TRUE,
        USE.NAMES = FALSE
      )]

      nodes <- display_dt[, .(
        id = node_id,
        label,
        title,
        value,
        base_value = value,
        shape = "box",
        base_background = unname(node_color[node_group]),
        base_border = unname(node_border[node_group]),
        color = Map(function(bg, border) list(background = bg, border = border, highlight = list(background = bg, border = border), hover = list(background = bg, border = border)), node_color[node_group], node_border[node_group]),
        borderWidth = ifelse(is_seed, 4, 2),
        is_seed = is_seed,
        shadow_color = ifelse(is_seed, "rgba(217,119,6,0.28)", "rgba(15,23,42,0.22)"),
        shadow = Map(function(flag) if (isTRUE(flag)) list(enabled = TRUE, color = "rgba(217,119,6,0.28)", size = 18, x = 0, y = 0) else FALSE, is_seed),
        node_label = feature,
        overview_html
      )]

      list(nodes = nodes, edges = edges, selected_count = nrow(seed_dt))
    }

    metrics_summary_table <- function(dt) {
      dt <- data.table::copy(data.table::as.data.table(dt))
      if (nrow(dt) == 0) return(dt)
      dt <- add_replicates(dt)
      safe_mean <- function(x) if (sum(is.finite(x)) > 0) mean(x, na.rm = TRUE) else NA_real_
      safe_sd <- function(x) if (sum(is.finite(x)) > 1) stats::sd(x, na.rm = TRUE) else NA_real_
      safe_cv <- function(x) {
        mu <- safe_mean(x)
        sdv <- safe_sd(x)
        if (!is.finite(mu) || isTRUE(all.equal(mu, 0)) || !is.finite(sdv)) return(NA_real_)
        100 * sdv / abs(mu)
      }
      dt[, .(
        n_hits = .N,
        exp_rt_mean = safe_mean(exp_rt),
        exp_rt_sd = safe_sd(exp_rt),
        exp_rt_cv = safe_cv(exp_rt),
        exp_mass_mean = safe_mean(exp_mass),
        exp_mass_sd = safe_sd(exp_mass),
        exp_mass_cv = safe_cv(exp_mass),
        intensity_mean = safe_mean(intensity),
        intensity_sd = safe_sd(intensity),
        intensity_cv = safe_cv(intensity),
        area_mean = safe_mean(area),
        area_sd = safe_sd(area),
        area_cv = safe_cv(area),
        error_rt_mean = safe_mean(error_rt),
        error_rt_abs_mean = safe_mean(abs(error_rt)),
        error_mass_mean = safe_mean(error_mass),
        error_mass_abs_mean = safe_mean(abs(error_mass))
      ), by = .(name, replicate)][order(name, replicate)]
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
      p <- plot_features_count(nts, groupBy = group_by, showLegend = FALSE, darkMode = dark_mode())
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
    scatter_layout_proportions <- shiny::reactiveVal(c(50, 50))
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
            label = col,
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
        return("feature")
      }
      unique(c(scatter_color_cols(), scatter_selection_cols()))
    })

    features_scatter_events_ready <- shiny::reactiveVal(FALSE)

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

      pal <- .get_colors(unique(fts$color_var), darkMode = dark_mode())
      hide_legend <- length(unique(fts$color_var)) > 50

      sel_cols <- scatter_selection_cols()
      sel_cols <- sel_cols[sel_cols %in% colnames(fts)]
      if (length(sel_cols) == 0) sel_cols <- intersect(c("analysis", "feature"), colnames(fts))
      fts[, sel_cols] <- lapply(fts[, sel_cols, drop = FALSE], as.character)
      for (col in sel_cols) fts[[col]][is.na(fts[[col]])] <- ""
      fts$scatter_key <- do.call(paste, c(fts[, sel_cols, drop = FALSE], sep = "||"))

      # Ensure size is numeric vector to avoid ordering issues with formula notation
      # size_values <- as.numeric(fts$dot_size)

      fts_highlight <- plotly::highlight_key(fts, ~scatter_key)

      p <- plotly::plot_ly(
        data = fts_highlight,
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
          opacity = 0.95,
          line = list(width = 0)
        ),
        hoverinfo = "none"
      )

      p <- plotly::layout(
        p,
        title = NULL,
        margin = list(l = 60, r = 30, t = 30, b = 88),
        paper_bgcolor = "rgba(0,0,0,0)",
        plot_bgcolor = "rgba(0,0,0,0)",
        xaxis = .plotly_axis_spec(
          title = list(text = "Retention Time"),
          darkMode = dark_mode(),
          tickfont = list(size = 12, color = .get_plot_theme(dark_mode())$text)
        ),
        yaxis = .plotly_axis_spec(
          title = list(text = "<i>m/z</i>"),
          darkMode = dark_mode(),
          tickfont = list(size = 12, color = .get_plot_theme(dark_mode())$text)
        ),
        font = list(color = .get_plot_theme(dark_mode())$text),
        legend = list(
          title = list(text = paste(color_cols, collapse = ", ")),
          orientation = "h",
          x = 0,
          xanchor = "left",
          y = -0.16,
          yanchor = "top"
        ),
        dragmode = "zoom",
        showlegend = !hide_legend
      )

            p <- plotly::config(
              p,
              displayModeBar = TRUE,
              displaylogo = FALSE,
              responsive = FALSE,
              modeBarButtonsToRemove = c("select2d", "lasso2d")
            )

      p <- plotly::highlight(
        p,
        on = "plotly_click",
        off = "plotly_doubleclick",
        persistent = FALSE,
        dynamic = FALSE,
        opacityDim = 0.22,
        selected = plotly::attrs_selected(
          marker = list(
            opacity = 1
          )
        )
      )

      p <- plotly::event_register(p, "plotly_click")
      p <- plotly::event_register(p, "plotly_doubleclick")
      features_scatter_events_ready(TRUE)
      p
    })

    selected_features_scatter_keys <- shiny::reactiveVal(NULL)

    shiny::observeEvent({
      shiny::req(features_scatter_events_ready())
      plotly::event_data("plotly_click", source = "features_scatter")
    }, {
      evt <- plotly::event_data("plotly_click", source = "features_scatter")
      if (is.null(evt) || nrow(evt) == 0 || is.null(evt$key)) return()
      selected_features_scatter_keys(as.character(evt$key))
    }, ignoreNULL = TRUE)

    shiny::observeEvent({
      shiny::req(features_scatter_events_ready())
      plotly::event_data("plotly_doubleclick", source = "features_scatter")
    }, {
      selected_features_scatter_keys(NULL)
    }, ignoreInit = TRUE)

    # MARK: selected_features_scatter
    selected_features_scatter <- shiny::reactive({
      keys <- selected_features_scatter_keys()
      if (is.null(keys) || length(keys) == 0) return(NULL)

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
        showDetails = TRUE,
        darkMode = dark_mode()
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
        filtered = TRUE,
        darkMode = dark_mode()
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
        filtered = TRUE,
        darkMode = dark_mode()
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

    feature_network_graph_data <- shiny::reactive({
      sel <- selected_features_scatter()
      shiny::validate(shiny::need(!is.null(sel) && nrow(sel) > 0, "Select one or more points to view the network."))
      network_data <- build_feature_network_data(
        feature_dt = features_data(),
        selected_rows = sel,
        selection_mode = if (is.null(input$scatter_select_by) || !nzchar(input$scatter_select_by)) "feature" else input$scatter_select_by
      )
      shiny::validate(shiny::need(!is.null(network_data) && nrow(network_data$nodes) > 0, "No network data available for the current feature selection."))
      network_data
    })

    output$feature_network_plot_scatter <- visNetwork::renderVisNetwork({
      graph_data <- feature_network_graph_data()
      build_feature_network_widget(
        nodes = graph_data$nodes,
        edges = graph_data$edges,
        widget_id = ns_full("feature_network_plot_scatter")
      )
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
        showDetails = TRUE,
        darkMode = dark_mode()
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
        showLegend = FALSE,
        darkMode = dark_mode()
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
        "id",
        "created_at",
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
            scrollY = "100%",
            scrollCollapse = TRUE,
            fixedColumns = list(leftColumns = 1)
          ),
          callback = DT::JS(
            "table.on('init.dt', function() {",
            "$(table.table().header()).hide();",
            "$(table.table().container()).find('.dataTables_scrollHead').hide();",
            "});"
          ),
          selection = "single",
          extensions = "FixedColumns",
          style = "bootstrap",
          class = "table table-striped table-hover",
          width = "100%",
          rownames = FALSE
        )
      })

    # Internal Standards ------

    istd_layout_proportions <- shiny::reactiveVal(c(50, 50))
    shiny::observeEvent(input$istd_prop_20_80, { istd_layout_proportions(c(20, 80)) })
    shiny::observeEvent(input$istd_prop_30_70, { istd_layout_proportions(c(30, 70)) })
    shiny::observeEvent(input$istd_prop_40_60, { istd_layout_proportions(c(40, 60)) })
    shiny::observeEvent(input$istd_prop_50_50, { istd_layout_proportions(c(50, 50)) })
    shiny::observeEvent(input$istd_prop_60_40, { istd_layout_proportions(c(60, 40)) })
    shiny::observeEvent(input$istd_prop_70_30, { istd_layout_proportions(c(70, 30)) })
    shiny::observeEvent(input$istd_prop_80_20, { istd_layout_proportions(c(80, 20)) })

    resize_internal_standard_plots <- function() {
      session$sendCustomMessage("sf-plotly-resize", list(
        ids = unname(c(
          ns_full("internal_standards_scatter_plot"),
          ns_full("internal_standard_eic_plot"),
          ns_full("internal_standard_xic_plot"),
          ns_full("internal_standard_profile_plot"),
          ns_full("internal_standard_ms1_plot"),
          ns_full("internal_standard_ms2_plot")
        ))
      ))
    }
    schedule_internal_standard_plot_resize <- function() {
      session$onFlushed(function() {
        resize_internal_standard_plots()
      }, once = TRUE)
    }
    sync_internal_standard_layout <- function() {
      props <- istd_layout_proportions()
      active_prop <- paste0(props[1], "_", props[2])
      session$sendCustomMessage("sf-nta-feature-layout", list(
        left_id = ns_full("internal_standards_scatter_panel"),
        right_id = ns_full("internal_standards_details_panel"),
        left_basis = props[1],
        right_basis = props[2],
        filters_open = FALSE,
        prop_button_ids = unname(c(
          ns_full("istd_prop_20_80"),
          ns_full("istd_prop_30_70"),
          ns_full("istd_prop_40_60"),
          ns_full("istd_prop_50_50"),
          ns_full("istd_prop_60_40"),
          ns_full("istd_prop_70_30"),
          ns_full("istd_prop_80_20")
        )),
        active_prop_button_id = ns_full(paste0("istd_prop_", active_prop))
      ))
    }
    shiny::observeEvent(istd_layout_proportions(), {
      sync_internal_standard_layout()
      later::later(schedule_internal_standard_plot_resize, delay = 0.08)
    }, ignoreInit = FALSE)

    internal_standards_scatter_data <- shiny::reactive({
      istd <- data.table::copy(internal_standards_data())
      if (nrow(istd) == 0) return(istd)
      istd$analysis <- as.character(istd$analysis)
      istd$feature <- as.character(istd$feature)
      if ("feature_group" %in% colnames(istd)) istd$feature_group <- as.character(istd$feature_group)
      if ("name" %in% colnames(istd)) istd$name <- as.character(istd$name)
      istd$replicate <- as.character(istd$replicate)
      max_intensity_global <- if ("intensity" %in% colnames(istd)) max(istd$intensity, na.rm = TRUE) else NA_real_
      istd$rel_intensity <- if (is.finite(max_intensity_global) && max_intensity_global > 0) istd$intensity / max_intensity_global else 0
      istd$rel_intensity[!is.finite(istd$rel_intensity)] <- 0
      istd$dot_size <- 6 + 10 * istd$rel_intensity
      istd
    })

    istd_color_cols <- shiny::reactive({
      sel <- input$istd_color_by
      if (is.null(sel) || !nzchar(sel)) sel <- "analysis"
      sel
    })

    istd_selection_cols <- shiny::reactive({
      "name"
    })

    istd_details_group_by <- shiny::reactive({
      color_col <- istd_color_cols()
      if (!is.character(color_col) || length(color_col) != 1 || !nzchar(color_col)) {
        color_col <- "analysis"
      }
      unique(c(color_col, "feature"))
    })

    internal_standards_scatter_events_ready <- shiny::reactiveVal(FALSE)

    output$internal_standards_scatter_plot <- plotly::renderPlotly({
      istd <- data.table::copy(internal_standards_scatter_data())
      shiny::validate(shiny::need(nrow(istd) > 0, "No internal standards available to plot."))

      color_cols <- istd_color_cols()
      color_cols <- color_cols[color_cols %in% colnames(istd)]
      if (length(color_cols) == 0) color_cols <- "analysis"
      istd[, (color_cols) := lapply(.SD, as.character), .SDcols = color_cols]
      for (col in color_cols) istd[[col]][is.na(istd[[col]])] <- ""
      istd$color_var <- do.call(paste, c(istd[, ..color_cols], sep = "_"))

      sel_cols <- istd_selection_cols()
      sel_cols <- sel_cols[sel_cols %in% colnames(istd)]
      if (length(sel_cols) == 0) sel_cols <- intersect(c("analysis", "feature"), colnames(istd))
      istd[, (sel_cols) := lapply(.SD, as.character), .SDcols = sel_cols]
      for (col in sel_cols) istd[[col]][is.na(istd[[col]])] <- ""
      if ("feature_group" %in% sel_cols) {
        istd <- istd[!is.na(istd$feature_group) & nzchar(istd$feature_group), ]
      }
      if ("name" %in% sel_cols) {
        istd <- istd[!is.na(istd$name) & nzchar(istd$name), ]
      }
      shiny::validate(shiny::need(nrow(istd) > 0, "No internal standards available for the current selection mode."))
      istd$scatter_key <- do.call(paste, c(istd[, ..sel_cols], sep = "||"))

      pal <- .get_colors(unique(istd$color_var), darkMode = dark_mode())
      hide_legend <- length(unique(istd$color_var)) > 50

      istd_highlight <- plotly::highlight_key(istd, ~scatter_key)

      p <- plotly::plot_ly(
        data = istd_highlight,
        source = "internal_standards_scatter",
        x = ~exp_rt,
        y = ~exp_mass,
        type = "scattergl",
        mode = "markers",
        color = ~color_var,
        colors = pal,
        marker = list(
          sizemode = "diameter",
          size = ~dot_size,
          sizemin = 3,
          opacity = 0.95,
          line = list(width = 0)
        ),
        hoverinfo = "text",
        text = ~paste0(
          "<b>", name, "</b><br>",
          "Analysis: ", analysis, "<br>",
          "Feature: ", feature, "<br>",
          "RT: ", exp_rt, "<br>",
          "Mass: ", exp_mass
        )
      )

      p <- plotly::layout(
        p,
        title = NULL,
        margin = list(l = 60, r = 30, t = 30, b = 88),
        paper_bgcolor = "rgba(0,0,0,0)",
        plot_bgcolor = "rgba(0,0,0,0)",
        xaxis = .plotly_axis_spec(
          title = list(text = "Retention Time"),
          darkMode = dark_mode(),
          tickfont = list(size = 12, color = .get_plot_theme(dark_mode())$text)
        ),
        yaxis = .plotly_axis_spec(
          title = list(text = "Experimental Mass"),
          darkMode = dark_mode(),
          tickfont = list(size = 12, color = .get_plot_theme(dark_mode())$text)
        ),
        font = list(color = .get_plot_theme(dark_mode())$text),
        legend = list(
          title = list(text = paste(color_cols, collapse = ", ")),
          orientation = "h",
          x = 0,
          xanchor = "left",
          y = -0.16,
          yanchor = "top"
        ),
        dragmode = "zoom",
        showlegend = !hide_legend
      )

      p <- plotly::config(
        p,
        displayModeBar = TRUE,
        displaylogo = FALSE,
        responsive = FALSE,
        modeBarButtonsToRemove = c("select2d", "lasso2d")
      )

      p <- plotly::highlight(
        p,
        on = "plotly_click",
        off = "plotly_doubleclick",
        persistent = FALSE,
        dynamic = FALSE,
        opacityDim = 0.22,
        selected = plotly::attrs_selected(
          marker = list(
            opacity = 1
          )
        )
      )

      p <- plotly::event_register(p, "plotly_click")
      p <- plotly::event_register(p, "plotly_doubleclick")
      internal_standards_scatter_events_ready(TRUE)
      p
    })

    selected_internal_standards_keys <- shiny::reactiveVal(NULL)

    shiny::observeEvent({
      shiny::req(internal_standards_scatter_events_ready())
      plotly::event_data("plotly_click", source = "internal_standards_scatter")
    }, {
      evt <- plotly::event_data("plotly_click", source = "internal_standards_scatter")
      if (is.null(evt) || nrow(evt) == 0 || is.null(evt$key)) return()
      selected_internal_standards_keys(as.character(evt$key))
    }, ignoreNULL = TRUE)

    shiny::observeEvent({
      shiny::req(internal_standards_scatter_events_ready())
      plotly::event_data("plotly_doubleclick", source = "internal_standards_scatter")
    }, {
      selected_internal_standards_keys(NULL)
    }, ignoreInit = TRUE)

    selected_internal_standards_rows <- shiny::reactive({
      keys <- selected_internal_standards_keys()
      if (is.null(keys) || length(keys) == 0) return(NULL)

      istd <- data.table::copy(internal_standards_scatter_data())
      if (!nrow(istd)) return(NULL)

      sel_cols <- istd_selection_cols()
      sel_cols <- sel_cols[sel_cols %in% colnames(istd)]
      if (length(sel_cols) == 0) sel_cols <- intersect(c("analysis", "feature"), colnames(istd))
      if ("feature_group" %in% sel_cols) {
        istd <- istd[!is.na(feature_group) & nzchar(feature_group), ]
      }
      if ("name" %in% sel_cols) {
        istd <- istd[!is.na(name) & nzchar(name), ]
      }
      if (!nrow(istd)) return(NULL)

      istd$scatter_key <- do.call(paste, c(istd[, ..sel_cols], sep = "||"))
      selected_entities <- unique(istd[scatter_key %in% keys, ..sel_cols])
      if (nrow(selected_entities) == 0) return(NULL)
      istd[selected_entities, on = sel_cols, nomatch = 0]
    })

    selected_internal_standards_features <- shiny::reactive({
      sel <- selected_internal_standards_rows()
      if (is.null(sel) || nrow(sel) == 0) return(NULL)
      unique(sel[, c("analysis", "feature"), with = FALSE])
    })

    output$internal_standard_eic_plot <- plotly::renderPlotly({
      sel <- selected_internal_standards_features()
      shiny::validate(shiny::need(!is.null(sel) && nrow(sel) > 0, "Select one or more points to view EIC."))
      p <- plot_features(
        nta_data(),
        features = sel,
        groupBy = istd_details_group_by(),
        filtered = TRUE,
        showDetails = TRUE,
        darkMode = dark_mode()
      )
      shiny::validate(shiny::need(!is.null(p), "No EIC data for selected internal standards."))
      plotly::layout(p, title = NULL, margin = list(l = 50, r = 30, t = 30, b = 50), paper_bgcolor = "rgba(0,0,0,0)", plot_bgcolor = "rgba(0,0,0,0)") %>%
        plotly::config(displaylogo = FALSE, responsive = TRUE)
    })

    output$internal_standard_xic_plot <- plotly::renderPlotly({
      sel <- selected_internal_standards_features()
      shiny::validate(shiny::need(!is.null(sel) && nrow(sel) > 0, "Select one or more points to view XIC."))
      p <- map_features(
        nta_data(),
        features = sel,
        groupBy = istd_details_group_by(),
        filtered = TRUE,
        showDetails = TRUE,
        darkMode = dark_mode()
      )
      shiny::validate(shiny::need(!is.null(p), "No XIC data for selected internal standards."))
      plotly::layout(p, title = NULL, margin = list(l = 50, r = 30, t = 30, b = 50), paper_bgcolor = "rgba(0,0,0,0)", plot_bgcolor = "rgba(0,0,0,0)") %>%
        plotly::config(displaylogo = FALSE, responsive = TRUE)
    })

    output$internal_standard_profile_plot <- plotly::renderPlotly({
      sel <- selected_internal_standards_rows()
      shiny::validate(shiny::need(!is.null(sel) && nrow(sel) > 0, "Select one or more points to view profile."))
      names_sel <- unique(sel$name)
      names_sel <- names_sel[!is.na(names_sel) & nzchar(names_sel)]
      shiny::validate(shiny::need(length(names_sel) > 0, "No internal standard names available for selected rows."))
      p <- plot_internal_standards_profile(
        nta_data(),
        names = names_sel,
        groupBy = if (identical(input$istd_color_by, "replicate")) "replicate" else "analysis",
        showLegend = FALSE,
        darkMode = dark_mode()
      )
      shiny::validate(shiny::need(!is.null(p), "No profile data for selected internal standards."))
      plotly::layout(p, title = NULL, margin = list(l = 50, r = 30, t = 30, b = 50), paper_bgcolor = "rgba(0,0,0,0)", plot_bgcolor = "rgba(0,0,0,0)") %>%
        plotly::config(displaylogo = FALSE, responsive = TRUE)
    })

    output$internal_standard_ms1_plot <- plotly::renderPlotly({
      sel <- selected_internal_standards_features()
      shiny::validate(shiny::need(!is.null(sel) && nrow(sel) > 0, "Select one or more points to view MS1."))
      p <- plot_features_ms1(
        nta_data(),
        features = sel,
        groupBy = istd_details_group_by(),
        filtered = TRUE,
        darkMode = dark_mode()
      )
      shiny::validate(shiny::need(!is.null(p), "No MS1 data for selected internal standards."))
      plotly::layout(p, title = NULL, margin = list(l = 50, r = 30, t = 30, b = 50), paper_bgcolor = "rgba(0,0,0,0)", plot_bgcolor = "rgba(0,0,0,0)") %>%
        plotly::config(displaylogo = FALSE, responsive = TRUE)
    })

    output$internal_standard_ms2_plot <- plotly::renderPlotly({
      sel <- selected_internal_standards_features()
      shiny::validate(shiny::need(!is.null(sel) && nrow(sel) > 0, "Select one or more points to view MS2."))
      p <- plot_features_ms2(
        nta_data(),
        features = sel,
        groupBy = istd_details_group_by(),
        filtered = TRUE,
        darkMode = dark_mode()
      )
      shiny::validate(shiny::need(!is.null(p), "No MS2 data for selected internal standards."))
      plotly::layout(p, title = NULL, margin = list(l = 50, r = 30, t = 30, b = 50), paper_bgcolor = "rgba(0,0,0,0)", plot_bgcolor = "rgba(0,0,0,0)") %>%
        plotly::config(displaylogo = FALSE, responsive = TRUE)
    })

    internal_standard_network_graph_data <- shiny::reactive({
      sel_features <- selected_internal_standards_features()
      shiny::validate(shiny::need(!is.null(sel_features) && nrow(sel_features) > 0, "Select one or more points to view the network."))
      sel_rows <- selected_internal_standards_rows()
      network_data <- build_feature_network_data(
        feature_dt = features_data(),
        selected_rows = sel_features,
        selection_mode = "feature_group",
        internal_standard_dt = sel_rows
      )
      shiny::validate(shiny::need(!is.null(network_data) && nrow(network_data$nodes) > 0, "No network data available for the current internal standard selection."))
      network_data
    })

    output$internal_standard_network_plot <- visNetwork::renderVisNetwork({
      graph_data <- internal_standard_network_graph_data()
      build_feature_network_widget(
        nodes = graph_data$nodes,
        edges = graph_data$edges,
        widget_id = ns_full("internal_standard_network_plot")
      )
    })

    output$internal_standard_details_table <- DT::renderDT({
      rows <- selected_internal_standards_rows()
      shiny::validate(shiny::need(!is.null(rows) && nrow(rows) > 0, "Select one or more points to view details."))
      rows <- data.table::copy(rows)
      rows <- rows[, setdiff(colnames(rows), c("id", "created_at", "db_ms2_mz", "db_ms2_intensity", "db_ms2_formula", "exp_ms2_mz", "exp_ms2_intensity", "rel_intensity", "dot_size")), with = FALSE]
      n_sel <- nrow(rows)
      prop_names <- colnames(rows)
      details_rows <- lapply(prop_names, function(p) {
        vals <- as.character(rows[[p]])
        data.frame(
          Property = p,
          t(as.matrix(vals)),
          stringsAsFactors = FALSE
        )
      })
      details_dt <- data.table::rbindlist(details_rows, fill = TRUE)
      if (n_sel > 1) {
        data.table::setnames(details_dt, c("Property", paste0("Value ", seq_len(n_sel))))
      } else {
        data.table::setnames(details_dt, c("Property", "Value"))
      }
      DT::datatable(
        details_dt,
        options = list(
          dom = "tip",
          paging = FALSE,
          ordering = FALSE,
          autoWidth = FALSE,
          scrollX = TRUE,
          scrollY = "100%",
          scrollCollapse = TRUE,
          fixedColumns = list(leftColumns = 1)
        ),
        callback = DT::JS(
          "table.on('init.dt', function() {",
          "$(table.table().header()).hide();",
          "$(table.table().container()).find('.dataTables_scrollHead').hide();",
          "});"
        ),
        selection = "single",
        extensions = "FixedColumns",
        style = "bootstrap",
        class = "table table-striped table-hover",
        width = "100%",
        rownames = FALSE
      )
    })

    output$internal_standard_identification_table <- DT::renderDT({
      rows <- selected_internal_standards_rows()
      shiny::validate(shiny::need(!is.null(rows) && nrow(rows) > 0, "Select one or more points to view identification."))
      rows <- build_identification_table(rows, nta_data(), darkMode = dark_mode(), spectra_mode = "feature")
      DT::datatable(
        rows,
        options = list(dom = "t", paging = FALSE, autoWidth = TRUE, scrollX = TRUE, scrollY = "calc(100vh - 293px)"),
        escape = FALSE,
        style = "bootstrap",
        class = "table table-hover suspects-table",
        rownames = FALSE
      )
    })

    output$internal_standard_metrics_plot <- plotly::renderPlotly({
      rows <- selected_internal_standards_rows()
      if (is.null(rows) || nrow(rows) == 0) {
        rows <- internal_standards_data()
      }
      shiny::validate(shiny::need(nrow(rows) > 0, "No internal standards available for metrics."))
      rows <- add_replicates(rows)
      rows <- rows[!is.na(name) & nzchar(name)]
      shiny::validate(shiny::need(nrow(rows) > 0, "No named internal standards available for metrics."))

      metric_specs <- list(
        list(col = "exp_rt", label = "RT"),
        list(col = "exp_mass", label = "Mass"),
        list(col = "intensity", label = "Intensity"),
        list(col = "area", label = "Area"),
        list(col = "error_rt", label = "RT Error"),
        list(col = "error_mass", label = "Mass Error")
      )

      summarize_metric <- function(dt, value_col) {
        dt <- dt[is.finite(get(value_col))]
        if (nrow(dt) == 0) return(data.table::data.table())
        dt[, .(
          mean_value = mean(get(value_col), na.rm = TRUE),
          sd_value = if (.N > 1) stats::sd(get(value_col), na.rm = TRUE) else 0
        ), by = .(name, replicate)]
      }

      selected_names <- unique(as.character(rows$name))
      selected_names <- selected_names[!is.na(selected_names) & nzchar(selected_names)]
      shiny::validate(shiny::need(length(selected_names) > 0, "No internal standard names available for metrics."))
      rep_levels <- unique(as.character(rows$replicate))
      rep_levels <- rep_levels[!is.na(rep_levels) & nzchar(rep_levels)]
      if (length(rep_levels) == 0) {
        rep_levels <- unique(as.character(rows$analysis))
      }

      name_colors <- .get_colors(selected_names, darkMode = dark_mode())
      metric_plots <- lapply(metric_specs, function(spec) {
        metric_dt <- summarize_metric(rows, spec$col)
        shiny::validate(shiny::need(nrow(metric_dt) > 0, paste("No", spec$label, "data available for metrics.")))
        metric_dt$replicate <- as.character(metric_dt$replicate)
        metric_dt$replicate[is.na(metric_dt$replicate) | !nzchar(metric_dt$replicate)] <- "NA"
        rep_axis <- unique(c(rep_levels, metric_dt$replicate))
        metric_dt$replicate <- factor(metric_dt$replicate, levels = rep_axis)

        overall_vals <- rows[[spec$col]]
        overall_vals <- overall_vals[is.finite(overall_vals)]
        overall_mean <- if (length(overall_vals) > 0) mean(overall_vals, na.rm = TRUE) else NA_real_
        overall_sd <- if (length(overall_vals) > 1) stats::sd(overall_vals, na.rm = TRUE) else NA_real_

        p_metric <- plotly::plot_ly()
        if (is.finite(overall_mean) && is.finite(overall_sd) && overall_sd > 0) {
          band_df <- data.frame(
            replicate = factor(rep_axis, levels = rep_axis),
            lower = rep(overall_mean - overall_sd, length(rep_axis)),
            upper = rep(overall_mean + overall_sd, length(rep_axis))
          )
          p_metric <- plotly::add_trace(
            p_metric,
            data = band_df,
            x = ~replicate,
            y = ~lower,
            type = "scatter",
            mode = "lines",
            line = list(color = "rgba(0,0,0,0)", width = 0),
            hoverinfo = "skip",
            showlegend = FALSE,
            inherit = FALSE
          )
          p_metric <- plotly::add_trace(
            p_metric,
            data = band_df,
            x = ~replicate,
            y = ~upper,
            type = "scatter",
            mode = "lines",
            line = list(color = "rgba(0,0,0,0)", width = 0),
            fill = "tonexty",
            fillcolor = "rgba(34, 197, 94, 0.16)",
            hoverinfo = "skip",
            showlegend = FALSE,
            inherit = FALSE
          )
        }
        for (nm in selected_names) {
          seg <- metric_dt[name == nm]
          if (nrow(seg) == 0) next
          trace_color <- unname(name_colors[nm])
          p_metric <- plotly::add_trace(
            p_metric,
            data = seg,
            x = ~replicate,
            y = ~mean_value,
            type = "scatter",
            mode = "lines+markers",
            name = nm,
            legendgroup = nm,
            showlegend = identical(spec$col, metric_specs[[1]]$col),
            line = list(color = trace_color, width = 2),
            marker = list(color = trace_color, size = 8),
            error_y = list(type = "data", array = seg$sd_value, visible = TRUE, color = trace_color, thickness = 1.5, width = 4),
            hovertemplate = paste0(
              "name: ", nm,
              "<br>replicate: %{x}",
              "<br>mean: %{y}<extra></extra>"
            )
          )
        }
        plotly::layout(
          p_metric,
          title = .plotly_title_spec(spec$label, darkMode = dark_mode()),
          xaxis = .plotly_axis_spec(title = "Replicate", darkMode = dark_mode()),
          yaxis = .plotly_axis_spec(title = spec$label, darkMode = dark_mode()),
          paper_bgcolor = .get_plot_theme(dark_mode())$background,
          plot_bgcolor = .get_plot_theme(dark_mode())$background,
          font = list(color = .get_plot_theme(dark_mode())$text),
          margin = list(l = 60, r = 30, t = 46, b = 54)
        )
      })

      subplot <- plotly::subplot(
        metric_plots,
        nrows = ceiling(length(metric_plots) / 2),
        shareX = FALSE,
        shareY = FALSE,
        margin = 0.085,
        titleX = TRUE,
        titleY = TRUE
      )

      plotly::layout(
        subplot,
        showlegend = length(selected_names) > 0,
        legend = list(orientation = "h", x = 0, xanchor = "left", y = 1.08, yanchor = "bottom"),
        paper_bgcolor = .get_plot_theme(dark_mode())$background,
        plot_bgcolor = .get_plot_theme(dark_mode())$background,
        font = list(color = .get_plot_theme(dark_mode())$text)
      ) %>%
        plotly::config(displaylogo = FALSE, responsive = TRUE)
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

      suspects <- build_identification_table(suspects, nts, darkMode = dark_mode(), spectra_mode = "suspect")

      DT::datatable(
        suspects,
        options = list(
          dom = "t",
          paging = FALSE,
          autoWidth = TRUE,
          scrollX = TRUE,
          scrollY = "calc(100vh - 293px)"
        ),
        escape = FALSE,
        style = "bootstrap",
        class = "table table-hover suspects-table",
        rownames = FALSE
      )
    })
  })
}

