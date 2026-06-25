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
    .bslib-sidebar-resize-handle {
      display: none !important;
    }
    .bslib-sidebar-toggle {
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
    .features-controls-bar .shiny-input-container[style*='width: 200px'],
    .features-controls-bar .shiny-input-container[style*='width:200px'] {
      width: 200px !important;
      min-width: 200px !important;
      max-width: 200px !important;
    }
    .features-controls-bar .shiny-input-container > select.form-control {
      width: 200px !important;
      min-width: 200px !important;
      max-width: 200px !important;
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
    .sf-nta-loading-surface {
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
      background-size: auto 80px;
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
      position: relative;
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
      position: relative;
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
              var isLoading =
                output.classList.contains('recalculating') ||
                !!output.querySelector('.recalculating') ||
                !!output.querySelector('.shiny-busy') ||
                !!output.querySelector('.plotly.recalculating') ||
                !!output.querySelector('.html-widget.recalculating');
              surface.classList.toggle('loading', isLoading);
            };

            syncLoading();

            if (window.__sfNtaLoadingObservers[outputId]) {
              try { window.__sfNtaLoadingObservers[outputId].disconnect(); } catch (e) {}
            }

            var observer = new MutationObserver(function() {
              syncLoading();
            });
            observer.observe(output, { attributes: true, attributeFilter: ['class'], childList: true, subtree: true });
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
              initLoadingSurfaces();
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
        ns_full("feature_network_plot_scatter"),
        ns_full("feature_network_plot_scatter_surface"),
        ns_full("feature_details_table_scatter"),
        ns_full("feature_details_table_scatter_surface"),
        ns_full("suspects_table_scatter"),
        ns_full("suspects_table_scatter_surface"),
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
        ns_full("internal_standard_network_plot"),
        ns_full("internal_standard_network_plot_surface"),
        ns_full("internal_standard_details_table"),
        ns_full("internal_standard_details_table_surface"),
        ns_full("internal_standard_identification_table"),
        ns_full("internal_standard_identification_table_surface"),
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
                        shiny::selectInput(
                          ns_full("chart_color_by"),
                          label = NULL,
                          choices = c("Analysis" = "analysis", "Replicate" = "replicate"),
                          selected = "analysis",
                          width = "200px",
                          selectize = FALSE
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
    render_cache <- new.env(parent = emptyenv())

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

    shiny::observeEvent(nta_data(), {
      rm(list = ls(envir = render_cache, all.names = TRUE), envir = render_cache)
    }, ignoreInit = TRUE)

    # MARK: features_data
    features_data <- shiny::reactive({
      nts <- nta_data()
      fts <- data.table::as.data.table(get_features(nts, filtered = FALSE))
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
                shiny::selectInput(
                  ns_full("scatter_color_by"),
                  label = NULL,
                  choices = c("Analysis" = "analysis", "Replicate" = "replicate"),
                  selected = "replicate",
                  width = "200px",
                  selectize = FALSE
                )
              )
            ),
            shiny::div(
              style = "display: flex; align-items: center; gap: 8px; flex-wrap: wrap;",
              shiny::span("Select by:", style = "font-weight: 700;"),
                shiny::selectInput(
                  ns_full("scatter_select_by"),
                  label = NULL,
                  choices = c(
                    "Feature" = "feature",
                  "Component" = "feature_component",
                  "Group" = "feature_group",
                  "Group + Component" = "feature_group_component"
                  ),
                  selected = "feature",
                  width = "200px",
                  selectize = FALSE
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
                    id = ns_full("feature_network_plot_scatter_surface"),
                    class = "sf-nta-network-body sf-nta-loading-surface",
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
                  id = ns_full("feature_details_table_scatter_surface"),
                  class = "sf-nta-table-panel sf-nta-loading-surface",
                  DT::dataTableOutput(ns_full("feature_details_table_scatter"))
                )
              ),
              shiny::tabPanel(
                title = "Suspects",
                shiny::div(
                  id = ns_full("suspects_table_scatter_surface"),
                  class = "sf-nta-table-panel sf-nta-loading-surface",
                  DT::dataTableOutput(ns_full("suspects_table_scatter"))
                )
              ),
              shiny::tabPanel(
                title = "Transformations",
                height = "100%",
                shiny::div(
                  class = "sf-nta-network-panel",
                  shiny::div(
                    id = ns_full("tp_network_plot_scatter_surface"),
                    class = "sf-nta-network-body sf-nta-loading-surface",
                    visNetwork::visNetworkOutput(
                      ns_full("tp_network_plot_scatter"),
                      height = "100%",
                      width = "100%"
                    )
                  )
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
                shiny::selectInput(
                  ns_full("istd_color_by"),
                  label = NULL,
                  choices = c("Analysis" = "analysis", "Replicate" = "replicate"),
                  selected = "replicate",
                  width = "200px",
                  selectize = FALSE
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
                      id = ns_full("internal_standard_network_plot_surface"),
                      class = "sf-nta-network-body sf-nta-loading-surface",
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
                  shiny::div(
                    id = ns_full("internal_standard_details_table_surface"),
                    class = "sf-nta-table-panel sf-nta-loading-surface",
                    DT::dataTableOutput(ns_full("internal_standard_details_table"))
                  )
                ),
                shiny::tabPanel(
                  title = "Compound",
                  shiny::div(
                    id = ns_full("internal_standard_identification_table_surface"),
                    class = "sf-nta-table-panel sf-nta-loading-surface",
                    DT::dataTableOutput(ns_full("internal_standard_identification_table"))
                  )
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

    cache_get_or_set <- function(key, expr) {
      if (exists(key, envir = render_cache, inherits = FALSE)) {
        return(get(key, envir = render_cache, inherits = FALSE))
      }
      value <- force(expr)
      assign(key, value, envir = render_cache)
      value
    }

    cache_key_part <- function(x) {
      if (is.null(x)) return("NULL")
      if (is.data.frame(x)) {
        if (nrow(x) == 0) return("DT[0]")
        cols <- colnames(x)
        rows <- apply(as.data.frame(lapply(x, as.character), stringsAsFactors = FALSE), 1, paste, collapse = "\r")
        return(paste0("DT[", paste(cols, collapse = ","), "]=", paste(rows, collapse = "\n")))
      }
      paste(as.character(unlist(x, use.names = FALSE)), collapse = "\n")
    }

    identification_table_cache_key <- function(dt, spectra_mode, darkMode) {
      dt <- data.table::as.data.table(dt)
      key_cols <- intersect(
        c("analysis", "feature", "name", "candidate_rank", "SMILES", "InChI", "InChIKey"),
        colnames(dt)
      )
      if (length(key_cols) == 0) {
        key_cols <- colnames(dt)
      }
      key_dt <- dt[, ..key_cols]
      paste(
        "identification",
        spectra_mode,
        isTRUE(darkMode),
        cache_key_part(key_dt),
        sep = "||"
      )
    }

    map_components_widget_cached <- function(nts, args, darkMode = FALSE, showLegend = TRUE, showDetails = TRUE) {
      cache_key <- paste(
        "map_components_widget",
        isTRUE(darkMode),
        isTRUE(showLegend),
        isTRUE(showDetails),
        paste(
          vapply(names(args), function(nm) {
            paste0(nm, "=", cache_key_part(args[[nm]]))
          }, character(1)),
          collapse = "||"
        ),
        sep = "||"
      )
      cache_get_or_set(
        cache_key,
        do.call(
          map_components,
          c(
            list(
              x = nts,
              showLegend = showLegend,
              showDetails = showDetails,
              interactive = TRUE,
              darkMode = darkMode
            ),
            args
          )
        )
      )
    }

    create_structure_image <- function(smiles, inchi = NULL, width = 180, height = 200, darkMode = FALSE) {
      if ((is.null(smiles) || is.na(smiles) || !nzchar(smiles)) &&
          (is.null(inchi) || is.na(inchi) || !nzchar(inchi))) return("")
      if (!requireNamespace("base64enc", quietly = TRUE)) return("")
      smiles_key <- if (!is.null(smiles) && !is.na(smiles) && nzchar(smiles)) smiles else ""
      inchi_key <- if (!is.null(inchi) && !is.na(inchi) && nzchar(inchi)) inchi else ""
      cache_key <- paste("structure", smiles_key, inchi_key, width, height, isTRUE(darkMode), sep = "||")
      cache_get_or_set(cache_key, tryCatch(
        {
          svg <- rcpp_openbabel_structure_svg(
            SMILES = if (nzchar(smiles_key)) smiles_key else NULL,
            InChI = if (nzchar(inchi_key)) inchi_key else NULL,
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
      ))
    }

    # MARK: create_spectra_image
    create_spectra_image <- function(nts, analysis, feature, width = 900, height = 450, darkMode = FALSE) {
      if (is.null(analysis) || is.null(feature)) return("")
      if (!requireNamespace("base64enc", quietly = TRUE)) return("")
      if (!requireNamespace("ggplot2", quietly = TRUE)) return("")
      if (!capabilities("cairo")) return("")
      cache_key <- paste("suspect_spectra", analysis, feature, width, height, isTRUE(darkMode), sep = "||")
      cache_get_or_set(cache_key, tryCatch(
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
          on.exit({
            try(grDevices::dev.off(), silent = TRUE)
            unlink(temp_file)
          }, add = TRUE)
          print(p)
          grDevices::dev.off()
          svg <- paste(readLines(temp_file, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
          svg_data_uri(normalize_inline_svg(svg))
        },
        error = function(e) {
          ""
        }
      ))
    }

    create_feature_spectra_image <- function(nts, analysis, feature, width = 900, height = 450, darkMode = FALSE) {
      if (is.null(analysis) || is.null(feature)) return("")
      if (!requireNamespace("base64enc", quietly = TRUE)) return("")
      if (!requireNamespace("ggplot2", quietly = TRUE)) return("")
      if (!capabilities("cairo")) return("")
      cache_key <- paste("feature_spectra", analysis, feature, width, height, isTRUE(darkMode), sep = "||")
      cache_get_or_set(cache_key, tryCatch(
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
          on.exit({
            try(grDevices::dev.off(), silent = TRUE)
            unlink(temp_file)
          }, add = TRUE)
          print(p)
          grDevices::dev.off()
          svg <- paste(readLines(temp_file, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
          svg_data_uri(normalize_inline_svg(svg))
        },
        error = function(e) {
          ""
        }
      ))
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
      cache_key <- identification_table_cache_key(dt, spectra_mode = spectra_mode, darkMode = darkMode)
      result <- cache_get_or_set(cache_key, {
        dt <- add_replicates(dt)

        smiles_vec <- if ("SMILES" %in% colnames(dt)) as.character(dt$SMILES) else rep("", nrow(dt))
        inchi_vec <- if ("InChI" %in% colnames(dt)) as.character(dt$InChI) else rep("", nrow(dt))
        structure_lookup <- unique(data.table::data.table(
          SMILES = smiles_vec,
          InChI = inchi_vec
        ))
        structure_lookup[, structure := vapply(seq_len(.N), function(i) {
          img_uri <- create_structure_image(SMILES[i], InChI[i], darkMode = darkMode)
          if (!nzchar(img_uri)) return("")
          sprintf("<img class='suspect-structure-img' src='%s' alt=''/>", img_uri)
        }, character(1))]
        dt[, c("SMILES", "InChI") := .(smiles_vec, inchi_vec)]
        dt <- structure_lookup[dt, on = .(SMILES, InChI)]

        spectra_lookup <- unique(dt[, .(
          analysis = as.character(analysis),
          feature = as.character(feature)
        )])
        spectra_lookup[, spectra := vapply(seq_len(.N), function(i) {
          img_uri <- if (identical(spectra_mode, "suspect")) {
            create_spectra_image(nts, analysis[i], feature[i], darkMode = darkMode)
          } else {
            create_feature_spectra_image(nts, analysis[i], feature[i], darkMode = darkMode)
          }
          if (!nzchar(img_uri)) return("")
          sprintf("<img class='suspect-spectra-img' src='%s' alt=''/>", img_uri)
        }, character(1))]
        dt <- spectra_lookup[dt, on = .(analysis, feature)]

        exclude_cols <- c(
          "db_ms2_mz",
          "db_ms2_intensity",
          "db_ms2_formula",
          "db_ms2_smiles",
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
      })
      data.table::copy(result)
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

      log_cols_controls <- setdiff(log_cols, c("component_is_core", "component_bridge_flag"))
      logi_list <- NULL
      if (length(log_cols_controls) > 0) {
        logi_list <- lapply(log_cols_controls, function(col) {
          col_lower <- tolower(col)
          default_value <- if (col_lower == "filled") TRUE else FALSE
          shiny::checkboxInput(
            ns_full(paste0("scatter_filter_", col)),
            label = col,
            value = default_value
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
        if (identical(col, "filled")) next
        sel <- input[[paste0("scatter_filter_", col)]]
        if (identical(col, "filtered")) {
          if (isTRUE(sel)) {
            fts <- fts[!is.na(fts[[col]]) & fts[[col]], ]
          }
        } else {
          if (!is.null(sel) && !isTRUE(sel)) {
            fts <- fts[is.na(fts[[col]]) | !fts[[col]], ]
          }
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
      if ("intensity" %in% colnames(fts)) {
        max_int <- max(fts$intensity, na.rm = TRUE)
        fts$rel_intensity <- if (is.finite(max_int) && max_int > 0) fts$intensity / max_int else 0
        fts$rel_intensity[!is.finite(fts$rel_intensity)] <- 0
      } else {
        fts$rel_intensity <- 0
      }
      fts$dot_size <- 5 + sqrt(fts$rel_intensity) * 20
      fts
    })

    # MARK: scatter_color_cols & scatter_selection_cols
    scatter_color_cols <- shiny::reactive({
      sel <- input$scatter_color_by
      if (is.null(sel) || !nzchar(sel)) sel <- "analysis"
      sel
    })
    scatter_selection_mode <- shiny::reactive({
      sel <- input$scatter_select_by
      if (is.null(sel) || !nzchar(sel)) sel <- "feature"
      sel
    })
    scatter_selection_cols <- shiny::reactive({
      sel <- scatter_selection_mode()
      if (identical(sel, "feature")) {
        return(c("analysis", "feature"))
      }
      if (identical(sel, "feature_component")) {
        return(c("analysis", "feature_component"))
      }
      "feature_group"
    })

    scatter_details_group_by <- shiny::reactive({
      sel <- scatter_selection_mode()
      if (sel %in% c("feature_component", "feature_group", "feature_group_component")) {
        return(unique(c(scatter_color_cols(), "feature")))
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
      fts <- fts[order(fts$color_var), ]

      pal <- .get_colors(unique(fts$color_var), darkMode = dark_mode())
      hide_legend <- length(unique(fts$color_var)) > 50

      sel_cols <- scatter_selection_cols()
      sel_cols <- sel_cols[sel_cols %in% colnames(fts)]
      if (length(sel_cols) == 0) sel_cols <- intersect(c("analysis", "feature"), colnames(fts))
      fts[, sel_cols] <- lapply(fts[, sel_cols, drop = FALSE], as.character)
      for (col in sel_cols) fts[[col]][is.na(fts[[col]])] <- ""
      fts$scatter_key <- do.call(paste, c(fts[, sel_cols, drop = FALSE], sep = "||"))

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
          sizeref = 1,
          sizemin = 3,
          opacity = 0.22,
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

    selected_features_scatter_rows <- shiny::reactive({
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

      fts[sel]
    })

    selected_features_scatter_targets <- shiny::reactive({
      rows <- selected_features_scatter_rows()
      if (is.null(rows) || nrow(rows) == 0) return(NULL)

      fts <- data.table::copy(features_data())
      if (!nrow(fts)) return(NULL)

      fts$analysis <- as.character(fts$analysis)
      if ("feature" %in% colnames(fts)) fts$feature <- as.character(fts$feature)
      if ("feature_component" %in% colnames(fts)) fts$feature_component <- as.character(fts$feature_component)
      if ("feature_group" %in% colnames(fts)) fts$feature_group <- as.character(fts$feature_group)

      select_by <- scatter_selection_mode()
      if (identical(select_by, "feature")) {
        keys <- unique(rows[, c("analysis", "feature"), with = FALSE])
        target <- fts[keys, on = .(analysis, feature), nomatch = 0]
      } else if (identical(select_by, "feature_component")) {
        comps <- unique(rows[, c("analysis", "feature_component"), with = FALSE])
        comps <- comps[!is.na(feature_component) & nzchar(feature_component)]
        if (nrow(comps) == 0) return(NULL)
        target <- fts[comps, on = .(analysis, feature_component), nomatch = 0]
      } else if (identical(select_by, "feature_group_component")) {
        group_members <- fts[feature_group %in% unique(rows$feature_group) & !is.na(feature_group) & nzchar(feature_group)]
        comps <- unique(group_members[, c("analysis", "feature_component"), with = FALSE])
        comps <- comps[!is.na(feature_component) & nzchar(feature_component)]
        if (nrow(comps) == 0) return(NULL)
        target <- fts[comps, on = .(analysis, feature_component), nomatch = 0]
      } else {
        groups <- unique(rows[, c("analysis", "feature_group"), with = FALSE])
        groups <- groups[!is.na(feature_group) & nzchar(feature_group)]
        if (nrow(groups) == 0) return(NULL)
        target <- fts[groups, on = .(analysis, feature_group), nomatch = 0]
      }

      if (!nrow(target)) return(NULL)
      target
    })

    scatter_details_filtered <- shiny::reactive({
      mode <- scatter_selection_mode()
      isTRUE(input$scatter_filter_filtered) || mode %in% c("feature_component", "feature_group_component")
    })

    selected_features_scatter_detail_rows <- shiny::reactive({
      target <- selected_features_scatter_targets()
      if (is.null(target) || nrow(target) == 0) return(NULL)

      all_fts <- data.table::copy(data.table::as.data.table(features_data()))
      if (!nrow(all_fts)) return(NULL)

      keys <- unique(target[, c("analysis", "feature"), with = FALSE])
      keys <- keys[!is.na(analysis) & nzchar(analysis) & !is.na(feature) & nzchar(feature)]
      if (!nrow(keys)) return(NULL)

      details <- all_fts[keys, on = .(analysis, feature), nomatch = 0]
      if (!nrow(details)) return(NULL)
      details
    })

    # MARK: selected_features_scatter
    selected_features_scatter <- shiny::reactive({
      target <- selected_features_scatter_targets()
      if (is.null(target) || nrow(target) == 0) return(NULL)
      unique(target[, c("analysis", "feature"), with = FALSE])
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
        filtered = scatter_details_filtered(),
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
        filtered = scatter_details_filtered(),
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
        filtered = scatter_details_filtered(),
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

    map_components_scatter_args <- function(rows, select_by, filtered_value = FALSE) {
      rows <- data.table::copy(data.table::as.data.table(rows))
      if (nrow(rows) == 0) return(NULL)
      rows$analysis <- as.character(rows$analysis)
      rows$feature <- as.character(rows$feature)
      if ("feature_component" %in% colnames(rows)) rows$feature_component <- as.character(rows$feature_component)
      if ("feature_group" %in% colnames(rows)) rows$feature_group <- as.character(rows$feature_group)

      analyses <- unique(rows$analysis)
      analyses <- analyses[!is.na(analyses) & nzchar(analyses)]
      select_by <- if (is.null(select_by) || !nzchar(select_by)) "feature" else select_by

      if (identical(select_by, "feature_component")) {
        comps <- unique(rows$feature_component)
        comps <- comps[!is.na(comps) & nzchar(comps)]
        return(list(analyses = analyses, components = comps, filtered = filtered_value))
      }
      if (identical(select_by, "feature_group")) {
        grps <- unique(rows$feature_group)
        grps <- grps[!is.na(grps) & nzchar(grps)]
        return(list(analyses = analyses, groups = grps, filtered = filtered_value))
      }
      feats <- unique(rows$feature)
      feats <- feats[!is.na(feats) & nzchar(feats)]
      list(analyses = analyses, features = feats, filtered = filtered_value)
    }

    feature_network_args <- shiny::reactive({
      rows <- selected_features_scatter_rows()
      shiny::validate(shiny::need(!is.null(rows) && nrow(rows) > 0, "Select one or more points to view the network."))
      mode <- scatter_selection_mode()

      rows <- data.table::copy(data.table::as.data.table(rows))
      rows$analysis <- as.character(rows$analysis)
      if ("feature" %in% colnames(rows)) rows$feature <- as.character(rows$feature)
      if ("feature_component" %in% colnames(rows)) rows$feature_component <- as.character(rows$feature_component)
      if ("feature_group" %in% colnames(rows)) rows$feature_group <- as.character(rows$feature_group)

      analyses <- unique(rows$analysis)
      analyses <- analyses[!is.na(analyses) & nzchar(analyses)]

      if (identical(mode, "feature")) {
        feats <- unique(rows[, c("analysis", "feature"), with = FALSE])
        args <- list(
          analyses = analyses,
          features = feats,
          filtered = FALSE
        )
      } else if (identical(mode, "feature_component")) {
        feats <- unique(rows[, c("analysis", "feature"), with = FALSE])
        args <- list(
          analyses = analyses,
          features = feats,
          filtered = TRUE
        )
      } else if (identical(mode, "feature_group")) {
        grps <- unique(rows$feature_group)
        grps <- grps[!is.na(grps) & nzchar(grps)]
        args <- list(
          analyses = analyses,
          groups = grps,
          filtered = FALSE
        )
      } else {
        grps <- unique(rows$feature_group)
        grps <- grps[!is.na(grps) & nzchar(grps)]
        args <- list(
          analyses = analyses,
          groups = grps,
          filtered = TRUE
        )
      }
      shiny::validate(shiny::need(!is.null(args), "No network data available for the current feature selection."))
      args
    })

    output$feature_network_plot_scatter <- visNetwork::renderVisNetwork({
      args <- feature_network_args()
      map_components_widget_cached(
        nts = nta_data(),
        args = args,
        darkMode = dark_mode(),
        showLegend = TRUE,
        showDetails = TRUE
      )
    })

    # MARK: tp_network_args
    tp_network_args <- shiny::reactive({
      rows <- selected_features_scatter_rows()
      shiny::validate(shiny::need(!is.null(rows) && nrow(rows) > 0, "Select one or more points to view TPs."))
      rows <- data.table::copy(data.table::as.data.table(rows))
      groups <- unique(rows$feature_group)
      groups <- groups[!is.na(groups) & nzchar(groups)]
      shiny::validate(shiny::need(length(groups) > 0, "No feature groups found for the current selection."))
      groups
    })

    output$tp_network_plot_scatter <- visNetwork::renderVisNetwork({
      groups <- tp_network_args()
      nts <- nta_data()
      plot_transformation_products(
        nts,
        groups = groups,
        showMS2 = TRUE,
        showIntensityProfile = TRUE,
        darkMode = dark_mode()
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
        filtered = scatter_details_filtered(),
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
      sel <- selected_features_scatter_targets()
      shiny::validate(shiny::need(!is.null(sel) && nrow(sel) > 0, "Select one or more points to view profile."))
      fts <- data.table::copy(sel)
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
        analyses = unique(fts$analysis),
        groups = groups,
        groupBy = if (identical(input$scatter_color_by, "replicate")) "replicate" else "analysis",
        filtered = scatter_details_filtered(),
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
      fts <- selected_features_scatter_detail_rows()
      shiny::validate(shiny::need(!is.null(fts) && nrow(fts) > 0, "Select one or more points to view details."))
      fts <- data.table::copy(fts)

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
      if ("intensity" %in% colnames(istd)) {
        max_int <- max(istd$intensity, na.rm = TRUE)
        istd$rel_intensity <- if (is.finite(max_int) && max_int > 0) istd$intensity / max_int else 0
      } else {
        istd$rel_intensity <- 0
      }
      istd$rel_intensity[!is.finite(istd$rel_intensity)] <- 0
      istd$dot_size <- 5 + sqrt(istd$rel_intensity) * 20
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
      istd <- istd[order(istd$color_var), ]

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
          sizeref = 1,
          sizemin = 3,
          opacity = 0.22,
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

    internal_standard_network_args <- shiny::reactive({
      sel_rows <- selected_internal_standards_rows()
      shiny::validate(shiny::need(!is.null(sel_rows) && nrow(sel_rows) > 0, "Select one or more points to view the network."))
      sel_rows <- data.table::copy(data.table::as.data.table(sel_rows))
      if ("feature_group" %in% colnames(sel_rows)) {
        sel_rows <- sel_rows[!is.na(feature_group) & nzchar(feature_group), ]
      }
      shiny::validate(shiny::need(nrow(sel_rows) > 0, "No internal standard feature groups available for the current selection."))
      map_components_scatter_args(
        rows = sel_rows,
        select_by = "feature_group",
        filtered_value = TRUE
      )
    })

    output$internal_standard_network_plot <- visNetwork::renderVisNetwork({
      args <- internal_standard_network_args()
      map_components_widget_cached(
        nts = nta_data(),
        args = args,
        darkMode = dark_mode(),
        showLegend = TRUE,
        showDetails = TRUE
      )
    })

    output$internal_standard_details_table <- DT::renderDT({
      rows <- selected_internal_standards_rows()
      shiny::validate(shiny::need(!is.null(rows) && nrow(rows) > 0, "Select one or more points to view details."))
      rows <- data.table::copy(rows)
      rows <- rows[, setdiff(colnames(rows), c("id", "created_at", "db_ms2_mz", "db_ms2_intensity", "db_ms2_formula", "db_ms2_smiles", "exp_ms2_mz", "exp_ms2_intensity", "rel_intensity", "dot_size")), with = FALSE]
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
            internal_standards_table_row_data(data.table::copy(rows))
            rows <- build_identification_table(rows, nta_data(), darkMode = dark_mode(), spectra_mode = "feature")
            internal_standards_table_data(rows)
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
      sel <- unique(data.table::as.data.table(sel)[, .(
        analysis = as.character(analysis),
        feature = as.character(feature)
      )])
      suspects[, analysis := as.character(analysis)]
      suspects[, feature := as.character(feature)]
      suspects <- suspects[sel, on = .(analysis, feature), nomatch = 0]
      shiny::validate(shiny::need(nrow(suspects) > 0, "No suspects available for selected features."))

      suspects_table_row_data(data.table::copy(suspects))
      suspects <- build_identification_table(suspects, nts, darkMode = dark_mode(), spectra_mode = "suspect")
      suspects_table_data(suspects)

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

        suspects_table_data <- shiny::reactiveVal(data.table::data.table())
        suspects_table_row_data <- shiny::reactiveVal(data.table::data.table())
        internal_standards_table_data <- shiny::reactiveVal(data.table::data.table())
        internal_standards_table_row_data <- shiny::reactiveVal(data.table::data.table())

    build_modal_ms2_plotly <- function(row) {
      dm <- dark_mode()
      build_peak_dt <- function(mz_str, int_str, src, pos = TRUE) {
        if (is.null(mz_str) || is.na(mz_str) || !nzchar(mz_str) ||
            is.null(int_str) || is.na(int_str) || !nzchar(int_str)) {
          return(data.table::data.table(mz = numeric(), intensity = numeric(),
                                        source = character(), label_text = character(),
                                        hover_text = character()))
        }
        mz_v <- tryCatch(rcpp_decode_string(mz_str), error = function(e) numeric())
        int_v <- tryCatch(rcpp_decode_string(int_str), error = function(e) numeric())
        n <- min(length(mz_v), length(int_v))
        if (n == 0) return(data.table::data.table(mz = numeric(), intensity = numeric(),
                                                   source = character(), label_text = character(),
                                                   hover_text = character()))
        dt <- data.table::data.table(
          mz = mz_v[seq_len(n)],
          intensity = if (pos) int_v[seq_len(n)] else -abs(int_v[seq_len(n)]),
          source = src
        )
        dt <- dt[is.finite(mz) & is.finite(intensity)]
        if (nrow(dt) == 0) return(dt[, `:=`(label_text = character(), hover_text = character())])
        dt[, label_text := sprintf("%.4f", mz)]
        dt[, hover_text := paste0(
          "<b>", src, "</b>\nm/z: ", sprintf("%.4f", mz),
          "\nintensity: ", sprintf("%.4f", abs(intensity)))]
        dt
      }

      exp_dt <- build_peak_dt(row$exp_ms2_mz, row$exp_ms2_intensity, "exp", TRUE)
      db_dt <- build_peak_dt(row$db_ms2_mz, row$db_ms2_intensity, "db", FALSE)

      if (nrow(db_dt) > 0) {
        has_smi <- !is.na(row$db_ms2_smiles) && nzchar(row$db_ms2_smiles)
        has_form <- !is.na(row$db_ms2_formula) && nzchar(row$db_ms2_formula)
        form_vec <- if (has_form) trimws(strsplit(row$db_ms2_formula, ";", fixed = TRUE)[[1]]) else character()
        smi_vec <- if (has_smi) trimws(strsplit(row$db_ms2_smiles, ";", fixed = TRUE)[[1]]) else character()
        for (i in seq_len(nrow(db_dt))) {
          parts <- paste0("db<br>m/z: ", sprintf("%.4f", db_dt$mz[i]),
                          "<br>intensity: ", sprintf("%.4f", abs(db_dt$intensity[i])))
          if (has_form && i <= length(form_vec) && !is.na(form_vec[i]) && nzchar(form_vec[i]))
            parts <- paste0(parts, "<br>formula: ", form_vec[i])
          if (has_smi && i <= length(smi_vec) && !is.na(smi_vec[i]) && nzchar(smi_vec[i])) {
            svg <- tryCatch(rcpp_openbabel_structure_svg(SMILES = smi_vec[i], width = 180L, height = 130L, darkMode = dm),
                            error = function(e) "")
            if (nzchar(svg)) {
              uri <- svg_data_uri(normalize_inline_svg(svg))
              parts <- paste0(parts, "<br><img src='", uri, "' style='width:180px;height:130px;display:block;margin:2px auto;'>")
            }
          }
          db_dt$hover_text[i] <- parts
        }
      }

      # Normalize exp and db separately so each group max = 1
      if (nrow(exp_dt) > 0) {
        em <- max(exp_dt$intensity, na.rm = TRUE)
        if (is.finite(em) && em > 0) exp_dt[, intensity := intensity / em]
      }
      if (nrow(db_dt) > 0) {
        dmx <- max(abs(db_dt$intensity), na.rm = TRUE)
        if (is.finite(dmx) && dmx > 0) db_dt[, intensity := intensity / dmx]
      }

      plot_dt <- rbind(exp_dt, db_dt, fill = TRUE)
      if (nrow(plot_dt) == 0)
        return(plotly::plot_ly(type = "scatter", mode = "markers") |> plotly::layout(xaxis = list(title = "m/z"), yaxis = list(title = "Intensity")))

      theme <- .get_plot_theme(dm)

      p <- plotly::plot_ly()
      for (src_name in c("exp", "db")) {
        seg <- plot_dt[source == src_name]
        if (nrow(seg) == 0) next
        clr <- if (src_name == "exp") "#1f77b4" else "#d62728"
        x_seg <- as.numeric(rbind(seg$mz, seg$mz, rep(NA, nrow(seg))))
        y_seg <- as.numeric(rbind(rep(0, nrow(seg)), seg$intensity, rep(NA, nrow(seg))))
        cdata <- as.vector(rbind(seg$hover_text, seg$hover_text, rep(NA_character_, nrow(seg))))
        p <- p |> plotly::add_trace(
          x = x_seg, y = y_seg,
          type = "scattergl", mode = "lines",
          line = list(color = clr, width = 2),
          name = src_name, legendgroup = src_name, showlegend = TRUE,
          hoverinfo = "skip", meta = cdata
        )
        label_offset <- 0.025
        label_y <- if (src_name == "db") seg$intensity - label_offset else seg$intensity + label_offset
        p <- p |> plotly::add_trace(
          x = seg$mz, y = label_y,
          type = "scattergl", mode = "text",
          text = seg$label_text,
          textposition = if (src_name == "db") "bottom center" else "top center",
          textfont = list(size = 9, color = clr),
          meta = seg$hover_text,
          hoverinfo = "skip", name = src_name, legendgroup = src_name, showlegend = FALSE
        )
      }

      y_range <- c(-1.3, 1.3)

      ax_spec <- .plotly_axis_spec(title = list(text = "<i>m/z</i> / Da"), darkMode = dm)
      ay_spec <- .plotly_axis_spec(title = list(text = "Intensity"), darkMode = dm)
      ay_spec$range <- y_range
      ay_spec$tickvals <- c(-1, -0.5, 0, 0.5, 1)
      ay_spec$ticktext <- c("1.0", "0.5", "0", "0.5", "1.0")

      p <- p |>
        plotly::layout(
          title = NULL,
          margin = list(l = 55, r = 35, t = 35, b = 80),
          xaxis = ax_spec,
          yaxis = ay_spec,
          paper_bgcolor = .get_plot_theme(dm)$background,
          plot_bgcolor = .get_plot_theme(dm)$background,
          font = list(color = .get_plot_theme(dm)$text)
        ) |>
        plotly::config(displaylogo = FALSE, responsive = TRUE,
                       displayModeBar = TRUE,
                       modeBarButtonsToRemove = c("select2d", "lasso2d"))

      tip_id <- paste0("tip_", gsub("[^a-zA-Z0-9]", "_", row$feature))
      tip_bg <- if (dm) "#222" else "#fff"
      tip_fg <- if (dm) "#fff" else "#000"
      p <- htmlwidgets::onRender(p, sprintf("
        function(el) {
          var tip = document.getElementById('%s');
          if (!tip) {
            tip = document.createElement('div');
            tip.id = '%s';
            document.body.appendChild(tip);
          }
          tip.style.cssText = 'position:fixed;display:none;z-index:99999;background:%s;border:1px solid #888;border-radius:6px;padding:8px 10px;box-shadow:0 4px 12px rgba(0,0,0,0.2);pointer-events:none;max-width:360px;font-size:12px;color:%s;line-height:1.4;font-family:inherit;';
          el.on('plotly_hover', function(data) {
            var pt = data.points[0];
            if (!pt) return;
            var idx = pt.pointIndex;
            if (idx == null) idx = pt.pointNumber;
            var md = pt.data.meta;
            var html = '';
            if (md && Array.isArray(md)) {
              html = md[idx] || md[Math.floor(idx / 3)] || '';
            }
            if (!html || html === 'NA') { tip.style.display = 'none'; return; }
            tip.innerHTML = html;
            tip.style.display = 'block';
            var ex = data.event.clientX || 0;
            var ey = data.event.clientY || 0;
            var tx = ex + 18;
            var ty = ey - 12;
            if (tx + 360 > window.innerWidth) tx = ex - 370;
            if (ty < 5) ty = ey + 18;
            if (ty + 300 > window.innerHeight) ty = window.innerHeight - 310;
            tip.style.left = tx + 'px';
            tip.style.top = ty + 'px';
          });
          el.on('plotly_unhover', function() { tip.style.display = 'none'; });
        }
      ", tip_id, tip_id, tip_bg, tip_fg))
      p
    }

    open_details_modal <- function(row, title = "Details") {
      dm_open <- dark_mode()
      is_suspect <- "feature_group" %in% names(row) && !"feature_component" %in% names(row)

      fc_val <- NA_character_
      adduct_val <- NA_character_
      if (!is_suspect) {
        fc <- row$feature_component
        ad <- row$adduct
        fc_val <- if (is.null(fc) || is.na(fc) || !nzchar(as.character(fc))) NA_character_ else as.character(fc)
        adduct_val <- if (is.null(ad) || is.na(ad) || !nzchar(as.character(ad))) NA_character_ else as.character(ad)
      }

      fmt <- function(x, fmt_str) {
        if (is.null(x) || length(x) == 0 || is.na(x) || !is.finite(x)) NA_character_
        else sprintf(fmt_str, x)
      }
      db_mass_fmt <- if (!is.na(row$db_mass) && is.finite(row$db_mass)) sprintf("%.4f", row$db_mass) else "-"
      detail_fields <- list(
        "Name" = row$name,
        "Formula" = row$formula,
        "Mass" = db_mass_fmt,
        "SMILES" = row$SMILES,
        "InChIKey" = row$InChIKey,
        "Score" = fmt(row$score, "%.4f"),
        "Identification Level" = row$id_level,
        "Mass Error (ppm)" = fmt(row$error_mass, "%.1f"),
        "RT Error (s)" = fmt(row$error_rt, "%.1f"),
        "Shared Fragments" = row$shared_fragments,
        "Cosine Similarity" = fmt(row$cosine_similarity, "%.4f"),
        "xLogP" = fmt(row$xLogP, "%.4f"),
        "Analysis" = row$analysis,
        "Replicate" = row$replicate,
        "Feature" = row$feature,
        "Feature Group" = row$feature_group
      )
      if (!is_suspect) {
        detail_fields[["Feature Component"]] <- if (is.na(fc_val) || !nzchar(fc_val)) "-" else fc_val
        detail_fields[["Adduct"]] <- if (is.na(adduct_val) || !nzchar(adduct_val)) "-" else adduct_val
      }

      detail_html <- tags$table(
        class = "modal-detail-table",
        lapply(seq_along(detail_fields), function(i) {
          nm <- names(detail_fields)[i]
          val <- detail_fields[[i]]
          if (is.null(val) || is.na(val) || !nzchar(val)) val <- "-"
          tags$tr(
            tags$td(nm),
            tags$td(val)
          )
        })
      )

      struct_img <- ""
      if (!is.na(row$SMILES) && nzchar(row$SMILES)) {
        svg <- tryCatch(
          rcpp_openbabel_structure_svg(SMILES = row$SMILES, width = 320L, height = 320L, darkMode = dm_open),
          error = function(e) ""
        )
        if (nzchar(svg)) {
          svg <- gsub("^<\\?xml[^>]*\\?>", "", svg)
          svg_b64 <- base64enc::base64encode(charToRaw(enc2utf8(svg)))
          struct_img <- sprintf("<img src='data:image/svg+xml;base64,%s' style='width:320px;height:320px;object-fit:contain;'/>", svg_b64)
        }
      }

      ms2_id <- paste0("modal_ms2_", gsub("[^a-zA-Z0-9]", "_", row$feature))

      output[[ms2_id]] <- plotly::renderPlotly({
        build_modal_ms2_plotly(row)
      })

      shiny::showModal(
        shiny::modalDialog(
          easyClose = TRUE,
          fade = TRUE,
          tags$style(HTML("
.modal-dialog { width: 90vw !important; max-width: 90vw !important; }
.modal-content { height: 90vh; overflow: hidden; }
.modal-body { padding: 0 !important; }
.modal-detail-table td { vertical-align: top; }
.modal-detail-table { width: 100%; border-collapse: collapse; font-size: 12px; }
.modal-detail-table tr:nth-child(odd) { background: var(--sf-surface); }
.modal-detail-table tr:nth-child(even) { background: var(--sf-surface-alt); }
.modal-detail-table td { padding: 3px 8px; border-bottom: 1px solid var(--sf-input-border); color: var(--sf-text-primary); }
.modal-detail-table td:first-child { font-weight: 600; width: 40%; }
")),
          tags$div(
            style = "display:grid; grid-template-columns: 30fr 70fr; gap: 12px; height: calc(90vh - 60px); overflow: hidden;",
            tags$div(
              style = "overflow-y:auto; padding-right:8px;",
              tags$div(style = "text-align:center; margin-bottom:12px;", HTML(struct_img)),
              detail_html
            ),
            tags$div(
              style = "overflow:hidden; height:100%; width:100%;",
              plotly::plotlyOutput(session$ns(ms2_id), height = "100%", width = "100%")
            )
          ),
          footer = NULL,
          title = tags$span(
            style = "font-weight:600; font-size:16px;",
            if (!is.null(title) && !is.na(title) && nzchar(title)) title else
              if (!is.na(row$name) && nzchar(row$name)) row$name else "Details"
          )
        )
      )
    }

    observeEvent(input$suspects_table_scatter_cell_clicked, {
      click <- input$suspects_table_scatter_cell_clicked
      if (is.null(click) || is.null(click$row)) return()
      display_rows <- suspects_table_data()
      data_rows <- suspects_table_row_data()
      if (is.null(display_rows) || nrow(display_rows) < click$row) return()
      if (is.null(data_rows) || nrow(data_rows) < click$row) return()
      merged <- data.table::copy(display_rows[click$row, ])
      for (col in intersect(c("db_ms2_mz","db_ms2_intensity","db_ms2_formula","db_ms2_smiles",
                              "exp_ms2_mz","exp_ms2_intensity","exp_ms2_size","db_ms2_size"),
                            colnames(data_rows))) {
        merged[[col]] <- data_rows[[col]][click$row]
      }
      open_details_modal(merged, title = "Suspect Details")
    })

    observeEvent(input$internal_standard_identification_table_cell_clicked, {
      click <- input$internal_standard_identification_table_cell_clicked
      if (is.null(click) || is.null(click$row)) return()
      display_rows <- internal_standards_table_data()
      data_rows <- internal_standards_table_row_data()
      if (is.null(display_rows) || nrow(display_rows) < click$row) return()
      if (is.null(data_rows) || nrow(data_rows) < click$row) return()
      merged <- data.table::copy(display_rows[click$row, ])
      for (col in intersect(c("db_ms2_mz","db_ms2_intensity","db_ms2_formula","db_ms2_smiles",
                              "exp_ms2_mz","exp_ms2_intensity","exp_ms2_size","db_ms2_size"),
                            colnames(data_rows))) {
        merged[[col]] <- data_rows[[col]][click$row]
      }
      open_details_modal(merged, title = "Internal Standard Details")
    })
  })
}

