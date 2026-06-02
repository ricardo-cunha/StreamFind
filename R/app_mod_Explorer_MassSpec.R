##' @noRd
##' @export
.mod_Explorer_UI.ProjectMassSpec <- function(x, id, ns) {
  ns2 <- shiny::NS(id)
  summary_plot_id <- ns(ns2("summary_plotly"))
  summary_surface_id <- ns(ns2("summary_plot_surface"))
  chrom_plot_id <- ns(ns2("chrom_plotly"))
  chrom_surface_id <- ns(ns2("chrom_plot_surface"))

  htmltools::div(
    style = "height: calc(100vh - 35px); overflow: hidden;",
    htmltools::tags$script(htmltools::HTML(sprintf(
      "(function() {
          var bindSurface = function(outputId, surfaceId) {
            var output = document.getElementById(outputId);
            var surface = document.getElementById(surfaceId);
            if (!output || !surface) return false;

            var syncLoading = function() {
              surface.classList.toggle('loading', output.classList.contains('recalculating'));
            };

            syncLoading();

            if (!window.__sfExplorerLoadingObservers) {
              window.__sfExplorerLoadingObservers = {};
            }
            if (window.__sfExplorerLoadingObservers[outputId]) {
              try { window.__sfExplorerLoadingObservers[outputId].disconnect(); } catch (e) {}
            }

            var observer = new MutationObserver(syncLoading);
            observer.observe(output, { attributes: true, attributeFilter: ['class'] });
            window.__sfExplorerLoadingObservers[outputId] = observer;
            return true;
          };

          var bindWhenReady = function(outputId, surfaceId) {
            var attempts = 0;
            var timer = window.setInterval(function() {
              attempts += 1;
              if (bindSurface(outputId, surfaceId) || attempts >= 50) {
                window.clearInterval(timer);
              }
            }, 150);
          };

          bindWhenReady('%s', '%s');
          bindWhenReady('%s', '%s');
        })();",
      summary_plot_id, summary_surface_id, chrom_plot_id, chrom_surface_id
    ))),
    shiny::conditionalPanel(
      "input.sf_active_subtab === 'tic'",
      shiny::fluidRow(
        shiny::column(
          3,
          DT::dataTableOutput(
            ns(ns2("spectraAnalysesTable")),
            height = "calc(100vh - 45px)"
          )
        ),
        shiny::column(9,
          bslib::layout_sidebar(
            sidebar = bslib::sidebar(
              width = "200px",
              bg = NULL,
              resizable = FALSE,
              class = "sf-explorer-sidebar",
              shiny::uiOutput(ns(ns2("summary_plot_controls")))
            ),
            shiny::uiOutput(ns(ns2("summary_plot_ui")))
          ),
          height = "calc(100vh - 45px)"
        )
      )
    ),
    shiny::conditionalPanel(
      "input.sf_active_subtab === 'chromatograms'",
      shiny::fluidRow(
        shiny::column(
          3,
          DT::dataTableOutput(
            ns(ns2("chromAnalysesTable")),
            height = "calc(100vh - 45px)"
          )
        ),
        shiny::column(9,
          bslib::layout_sidebar(
            sidebar = bslib::sidebar(
              width = "200px",
              bg = NULL,
              resizable = FALSE,
              class = "sf-explorer-sidebar",
              shiny::uiOutput(ns(ns2("chrom_plot_controls")))
            ),
            shiny::uiOutput(ns(ns2("chrom_plot_ui")))
          ),
          height = "calc(100vh - 45px)"
        )
      )
    ),
    shiny::conditionalPanel(
      "input.sf_active_subtab === 'eic'",
      shiny::uiOutput(ns(ns2("eics_interface")))
    )
  )
}

##' @noRd
##' @export
.mod_Explorer_Server.ProjectMassSpec <- function(
    x,
    id,
    ns,
    reactive_analyses,
    reactive_volumes) {
  shiny::moduleServer(id, function(input, output, session) {
    ns2 <- shiny::NS(id)
    reactive_has_results_spectra <- shiny::reactiveVal(FALSE)
    reactive_has_results_chromatograms <- shiny::reactiveVal(FALSE)
    reactive_levels <- shiny::reactiveVal(1)
    reactive_rt_end <- shiny::reactiveVal(0)
    reactive_rt_start <- shiny::reactiveVal(0)
    reactive_number_analyses <- shiny::reactiveVal(0)

    update_reactive_vars <- function(
      reactive_analyses,
      reactive_has_results_spectra,
      reactive_has_results_chromatograms,
      reactive_levels,
      reactive_rt_end,
      reactive_rt_start,
      reactive_number_analyses
    ) {
      analyses_obj <- reactive_analyses()
      if (is.null(analyses_obj)) {
        reactive_number_analyses(0)
        reactive_has_results_spectra(FALSE)
        reactive_has_results_chromatograms(FALSE)
        reactive_levels(1)
        reactive_rt_end(0)
        reactive_rt_start(0)
        return(invisible(NULL))
      }

      analyses_info <- info.ProjectMassSpec(analyses_obj)
      reactive_number_analyses(nrow(analyses_info))
      hd <- get_spectra_headers(analyses_obj)
      chrom_hd <- get_chromatograms_headers(analyses_obj)
      reactive_has_results_spectra(nrow(hd) > 0)
      reactive_has_results_chromatograms(nrow(chrom_hd) > 0)
      if (nrow(hd) > 0) {
        reactive_levels(as.numeric(unique(hd$level)))
        reactive_rt_end(round(max(hd$rt), digits = 0))
        reactive_rt_start(round(min(hd$rt), digits = 0))
      } else {
        reactive_levels(1)
        reactive_rt_end(0)
        reactive_rt_start(0)
      }
    }

    update_reactive_vars(
      reactive_analyses,
      reactive_has_results_spectra,
      reactive_has_results_chromatograms,
      reactive_levels,
      reactive_rt_end,
      reactive_rt_start,
      reactive_number_analyses
    )

    shiny::observe({
      update_reactive_vars(
        reactive_analyses,
        reactive_has_results_spectra,
        reactive_has_results_chromatograms,
        reactive_levels,
        reactive_rt_end,
        reactive_rt_start,
        reactive_number_analyses
      )
    })

    shinyFiles::shinyFileSave(
      input,
      "summary_plot_save",
      roots = .app_util_get_volumes(),
      defaultRoot = "wd",
      session = session
    )

    shinyFiles::shinyFileSave(
      input,
      "chrom_plot_save",
      roots = .app_util_get_volumes(),
      defaultRoot = "wd",
      session = session
    )

    group_by_spectra <- c(
      "analysis",
      "replicate",
      "polarity",
      "analysis+polarity",
      "replicate+polarity"
    )

    group_by_chromatograms <- c(
      "id",
      "analysis",
      "replicate",
      "polarity",
      "id+polarity",
      "analysis+polarity",
      "replicate+polarity",
      "id+analysis",
      "id+replicate"
    )

    selected_analysis_names <- function(selected_rows) {
      analyses_obj <- reactive_analyses()
      if (is.null(analyses_obj) || length(selected_rows) == 0) {
        return(character())
      }
      analyses_info <- info.ProjectMassSpec(analyses_obj)
      selected_rows <- selected_rows[selected_rows >= 1 & selected_rows <= nrow(analyses_info)]
      if (length(selected_rows) == 0) {
        return(character())
      }
      analyses_info$analysis[selected_rows]
    }

    # out Analyses Table -----
    output$spectraAnalysesTable <- DT::renderDT({
      if (reactive_number_analyses() == 0) return()
      analyses_obj <- reactive_analyses()
      if (is.null(analyses_obj)) return()
      analyses_info <- info.ProjectMassSpec(analyses_obj)
      DT::datatable(
        analyses_info[, c("analysis", "replicate")],
        selection = list(mode = "multiple", selected = 1, target = "row"),
        options = list(
          dom = "ft",
          paging = FALSE,
          scrollY = "calc(100vh - 25px - 10px - 28px - 10px - 100px)",
          scrollCollapse = TRUE
        )
      )
    })

    # out Summary plot UI -----
    output$summary_plot_ui <- shiny::renderUI({
      if (reactive_number_analyses() == 0) {
        htmltools::div(
          style = "margin-top: 20px;",
          htmltools::h4("No analyses found!")
        )
      } else if (reactive_has_results_spectra()) {
        htmltools::div(
          id = ns(ns2("summary_plot_surface")),
          class = "sf-explorer-plot-surface",
          plotly::plotlyOutput(
            ns(ns2("summary_plotly")),
            height = "calc(100vh - 25px - 10px - 28px - 30px)"
          )
        )
      } else {
        htmltools::div(
          style = "margin-top: 20px;",
          htmltools::h4("No spectra found!")
        )
      }
    })

    # out Summary controls -----
    output$summary_plot_controls <- shiny::renderUI({
      if (reactive_number_analyses() == 0) return()
      if (reactive_has_results_spectra()) {
        plot_view <- if (!is.null(input$summary_plot_view)) input$summary_plot_view else "tic"
        htmltools::div(
          style = "display: flex; flex-direction: column; gap: 10px; padding: 10px;",
          htmltools::div(
            shinyFiles::shinySaveButton(
              ns(ns2("summary_plot_save")),
              "Export (.csv)",
              "Export (.csv)",
              filename = "spectra_summary_data",
              filetype = list(csv = "csv")
            )
          ),
          htmltools::div(
            shiny::selectInput(
              ns(ns2("summary_plot_view")),
              label = "Plot",
              choices = c("TIC" = "tic", "TIC 3D" = "tic_3d"),
              selected = plot_view,
              width = "100%"
            )
          ),
          htmltools::div(
            shiny::selectInput(
              ns(ns2("summary_plot_group_by")),
              label = "Group by",
              choices = group_by_spectra,
              selected = "analysis",
              width = "100%"
            )
          ),
          htmltools::div(
            shiny::selectInput(
              ns(ns2("summary_plot_level")),
              label = "MS levels",
              choices = reactive_levels(),
              selected = reactive_levels()[1],
              width = "100%"
            )
          ),
          htmltools::div(
            shiny::numericInput(
              ns(ns2("summary_plot_downsize")),
              label = if (identical(plot_view, "tic_3d")) "Reduction" else "Downsize",
              min = if (identical(plot_view, "tic_3d")) 0.01 else 1,
              max = if (identical(plot_view, "tic_3d")) 1 else 100,
              value = if (identical(plot_view, "tic_3d")) 0.1 else 1,
              step = if (identical(plot_view, "tic_3d")) 0.01 else 1,
              width = "100%"
            )
          ),
          htmltools::div(
            shiny::sliderInput(
              ns(ns2("summary_plot_rt")),
              label = "Retention Time",
              min = reactive_rt_start(),
              max = reactive_rt_end(),
              value = c(reactive_rt_start(), reactive_rt_end()),
              step = 1,
              width = "100%"
            )
          ),
          if (identical(plot_view, "tic_3d")) {
            htmltools::div(
              shiny::checkboxInput(
                ns(ns2("summary_plot_use_mobility")),
                label = "Use mobility axis",
                value = TRUE,
                width = "100%"
              )
            )
          }
        )
      }
    })

    # out Summary plotly -----
    output$summary_plotly <- plotly::renderPlotly({
      tryCatch({
        if (reactive_number_analyses() == 0) return()
        if (!is.null(input$summary_plot_view)) {
          selected <- selected_analysis_names(input$spectraAnalysesTable_rows_selected)
          if (length(selected) == 0) {
            return()
          }
          if (identical(input$summary_plot_view, "tic")) {
            p <- suppressWarnings(plot_spectra_tic(
              reactive_analyses(),
              analyses = selected,
              groupBy = strsplit(input$summary_plot_group_by, "\\+")[[1]],
              levels = input$summary_plot_level,
              rtmin = input$summary_plot_rt[1],
              rtmax = input$summary_plot_rt[2],
              downsize = input$summary_plot_downsize,
              interactive = TRUE
            ))
            return(plotly::layout(
              p,
              title = NULL,
              paper_bgcolor = "rgba(0,0,0,0)",
              plot_bgcolor = "rgba(0,0,0,0)"
            ))
          } else if (identical(input$summary_plot_view, "tic_3d")) {
            p <- suppressWarnings(plot_spectra_tic_3d(
              reactive_analyses(),
              analyses = selected,
              groupBy = strsplit(input$summary_plot_group_by, "\\+")[[1]],
              levels = input$summary_plot_level,
              rtmin = input$summary_plot_rt[1],
              rtmax = input$summary_plot_rt[2],
              reduction = input$summary_plot_downsize,
              useMobility = isTRUE(input$summary_plot_use_mobility)
            ))
            return(plotly::layout(
              p,
              title = NULL,
              paper_bgcolor = "rgba(0,0,0,0)",
              plot_bgcolor = "rgba(0,0,0,0)"
            ))
          }
        }
      }, error = function(e) {
        shiny::showNotification(
          paste("Unable to render TIC plot:", conditionMessage(e)),
          duration = 8,
          type = "warning"
        )
        return(NULL)
      })
    })

    # out Summary plot -----
    output$summary_plot <- shiny::renderPlot({
      tryCatch({
        if (reactive_number_analyses() == 0) return()
        if (
          !is.null(input$summary_plot_view) && !as.logical(input$summary_plot_interactive)
        ) {
          selected <- selected_analysis_names(input$spectraAnalysesTable_rows_selected)
          if (length(selected) == 0) {
            return()
          }
          if (identical(input$summary_plot_view, "tic")) {
            suppressWarnings(plot_spectra_tic(
              reactive_analyses(),
              analyses = selected,
              groupBy = strsplit(input$summary_plot_group_by, "\\+")[[1]],
              levels = input$summary_plot_level,
              rtmin = input$summary_plot_rt[1],
              rtmax = input$summary_plot_rt[2],
              downsize = input$summary_plot_downsize,
              interactive = as.logical(input$summary_plot_interactive)
            ))
          } else if (identical(input$summary_plot_view, "tic_3d")) {
            suppressWarnings(plot_spectra_tic_3d(
              reactive_analyses(),
              analyses = selected,
              groupBy = strsplit(input$summary_plot_group_by, "\\+")[[1]],
              levels = input$summary_plot_level,
              rtmin = input$summary_plot_rt[1],
              rtmax = input$summary_plot_rt[2],
              reduction = input$summary_plot_downsize,
              useMobility = isTRUE(input$summary_plot_use_mobility)
            ))
          }
        }
      }, error = function(e) {
        shiny::showNotification(
          paste("Unable to render TIC plot:", conditionMessage(e)),
          duration = 8,
          type = "warning"
        )
        return(invisible(NULL))
      })
    }, bg = "transparent")

    # event Summary plot export -----
    shiny::observeEvent(input$summary_plot_save, {
      if (reactive_number_analyses() == 0){
        msg <- "No analyses found!"
        shiny::showNotification(msg, duration = 5, type = "warning")
        return()
      }
      if (!is.null(input$summary_plot_view)) {
        selected <- selected_analysis_names(input$spectraAnalysesTable_rows_selected)
        if (length(selected) == 0) return()
        csv <- reactive_analyses()$get_spectra_tic(
          analyses = selected,
          levels = input$summary_plot_level
        )
        csv <- csv[, .(analysis, replicate, polarity, level, rt, tic)]
        fileinfo <- shinyFiles::parseSavePath(
          reactive_volumes(),
          input$summary_plot_save
        )
        if (nrow(fileinfo) > 0) {
          utils::write.csv(csv, fileinfo$datapath, row.names = FALSE)
          shiny::showNotification(
            "File saved successfully!",
            duration = 5,
            type = "message"
          )
        }
      }
    })

    # out Chromatograms Table -----
    output$chromAnalysesTable <- DT::renderDT({
      if (reactive_number_analyses() == 0) return()
      analyses_obj <- reactive_analyses()
      if (is.null(analyses_obj)) return()
      analyses_info <- info.ProjectMassSpec(analyses_obj)
      DT::datatable(
        analyses_info[, c("analysis", "replicate")],
        selection = list(mode = "multiple", selected = 1, target = "row"),
        options = list(
          dom = "ft",
          paging = FALSE,
          scrollY = "calc(100vh - 25px - 10px - 28px - 10px - 100px)",
          scrollCollapse = TRUE
        )
      )
    })

    # out Chromatograms plot UI -----
    output$chrom_plot_ui <- shiny::renderUI({
      if (reactive_number_analyses() == 0) {
        htmltools::div(
          style = "margin-top: 20px;",
          htmltools::h4("No analyses found!")
        )
      } else if (reactive_has_results_chromatograms()) {
        htmltools::div(
          id = ns(ns2("chrom_plot_surface")),
          class = "sf-explorer-plot-surface",
          plotly::plotlyOutput(
            ns(ns2("chrom_plotly")),
            height = "calc(100vh - 25px - 10px - 28px - 30px)"
          )
        )
      } else {
        htmltools::div(
          style = "margin-top: 20px;",
          htmltools::h4("No chromatograms found!")
        )
      }
    })

    # out Chromatograms controls -----
    output$chrom_plot_controls <- shiny::renderUI({
      if (reactive_number_analyses() == 0) return()
      if (reactive_has_results_chromatograms()) {
        htmltools::div(
          style = "display: flex; flex-direction: column; gap: 10px; padding: 10px;",
          htmltools::div(
            shinyFiles::shinySaveButton(
              ns(ns2("chrom_plot_save")),
              "Export (.csv)",
              "Export (.csv)",
              filename = "chrom_data",
              filetype = list(csv = "csv")
            )
          ),
          htmltools::div(
            shiny::selectInput(
              ns(ns2("summary_chrom_group_by")),
              label = "Group by",
              choices = group_by_chromatograms,
              selected = "analysis",
              width = "100%"
            )
          )
        )
      }
    })

    # out Chromatograms plotly -----
    output$chrom_plotly <- plotly::renderPlotly({
      if (reactive_number_analyses() == 0) return()
      selected <- selected_analysis_names(input$chromAnalysesTable_rows_selected)
      if (length(selected) == 0) return()
      if (!reactive_has_results_chromatograms()) return()
      p <- plot_raw_chromatograms(
        reactive_analyses(),
        analyses = selected,
        groupBy = strsplit(input$summary_chrom_group_by, "\\+")[[1]],
        interactive = TRUE
      )
      plotly::layout(
        p,
        title = NULL,
        paper_bgcolor = "rgba(0,0,0,0)",
        plot_bgcolor = "rgba(0,0,0,0)"
      )
    })

    # out Chromatograms plot -----
    output$chrom_plot <- shiny::renderPlot({
      if (reactive_number_analyses() == 0) return()
      selected <- selected_analysis_names(input$chromAnalysesTable_rows_selected)
      if (length(selected) == 0) return()
      if (!reactive_has_results_chromatograms()) return()
      plot_raw_chromatograms(
        reactive_analyses(),
        analyses = selected,
        groupBy = strsplit(input$summary_chrom_group_by, "\\+")[[1]],
        interactive = as.logical(input$summary_chrom_interactive)
      )
    }, bg = "transparent")

    # event Chromatograms plot export
    shiny::observeEvent(input$chrom_plot_save, {
      if (reactive_number_analyses() == 0) {
        msg <- "No analyses found!"
        shiny::showNotification(msg, duration = 5, type = "warning")
        return()
      }
      selected <- selected_analysis_names(input$chromAnalysesTable_rows_selected)
      if (length(selected) == 0) {
        return()
      }
      csv <- get_raw_chromatograms(reactive_analyses(), analyses = selected)
      fileinfo <- shinyFiles::parseSavePath(
        reactive_volumes(),
        input$chrom_plot_save
      )
      if (nrow(fileinfo) > 0) {
        utils::write.csv(csv, fileinfo$datapath, row.names = FALSE)
        shiny::showNotification(
          "File saved successfully!",
          duration = 5,
          type = "message"
        )
      }
    })

    targets <- shiny::reactiveVal(NULL)

    colorby_targets <- c(
      "targets",
      "analyses",
      "replicates",
      "polarities",
      "targets+analyses",
      "targets+replicates",
      "targets+polarities",
      "analyses+polarities",
      "replicates+polarities"
    )

    # # out EICs plot UI -----
    # output$eics_interface <- shiny::renderUI({
    #   if (length(reactive_analyses()) == 0) {
    #     htmltools::div(
    #       style = "margin-top: 20px;",
    #       htmltools::h4("No analyses found!")
    #     )
    #   } else if (has_results_spectra()) {
    #     htmltools::div(
    #       htmltools::div(
    #         style = "display: flex; align-items: center;",
    #         htmltools::div(
    #           style = "margin-left: 20px;",
    #           shiny::selectInput(
    #             ns(ns2("eics_analyses")),
    #             label = "Analyses",
    #             multiple = TRUE,
    #             choices = names(reactive_analyses()$analyses),
    #             width = 200
    #           )
    #         ),
    #         htmltools::div(
    #           style = "margin-left: 20px;",
    #           shiny::textInput(
    #             ns(ns2("eics_mass")),
    #             label = "Mass (Da)",
    #             value = 238.0547,
    #             width = 200
    #           )
    #         ),
    #         htmltools::div(
    #           style = "margin-left: 20px;",
    #           shiny::textInput(
    #             ns(ns2("eics_rt")),
    #             label = "Retention Time (Seconds)",
    #             value = 1157,
    #             width = 200
    #           )
    #         ),
    #         htmltools::div(
    #           style = "margin-left: 20px;",
    #           shiny::textInput(
    #             ns(ns2("eics_ppm")),
    #             label = "Mass Deviation (ppm)",
    #             value = 20,
    #             width = 200
    #           )
    #         ),
    #         htmltools::div(
    #           style = "margin-left: 20px;",
    #           shiny::textInput(
    #             ns(ns2("eics_sec")),
    #             label = "Time deviation (Seconds)",
    #             value = 60,
    #             width = 200
    #           )
    #         ),
    #         htmltools::div(
    #           style = "margin-left: 20px;",
    #           shiny::actionButton(
    #             ns(ns2("eics_extract")),
    #             label = "Extract EIC",
    #             width = 200
    #           )
    #         )
    #       ),
    #       htmltools::div(htmltools::br()),
    #       htmltools::div(
    #         style = "margin-left: 20px;",
    #         shiny::uiOutput(ns(ns2("eics_targets")))
    #       ),
    #       htmltools::div(htmltools::br()),
    #       shinycssloaders::withSpinner(
    #         plotly::plotlyOutput(ns(ns2("eics_plotly")), height = "500px"),
    #         color = "black"
    #       ),
    #       htmltools::div(htmltools::br()),
    #       shiny::column(12, shiny::uiOutput(ns(ns2("eics_plot_controls")))),
    #       htmltools::div(style = "margin-bottom: 20px;")
    #     )
    #   } else {
    #     htmltools::div(
    #       style = "margin-top: 20px;",
    #       htmltools::h4("No spectra found!")
    #     )
    #   }
    # })

    # # event EICs extract -----
    # shiny::observeEvent(input$eics_extract, {
    #   anas <- input$eics_analyses
    #   if (length(anas) == 0) {
    #     msg <- "No analyses selected!"
    #     shiny::showNotification(msg, duration = 5, type = "warning")
    #     return()
    #   }
    #   mass <- as.numeric(input$eics_mass)
    #   rt <- as.numeric(input$eics_rt)
    #   ppm <- as.numeric(input$eics_ppm)
    #   sec <- as.numeric(input$eics_sec)
    #   if (is.na(mass) || is.na(rt) || is.na(ppm) || is.na(sec)) {
    #     msg <- "Invalid input!"
    #     shiny::showNotification(msg, duration = 5, type = "warning")
    #     return()
    #   }
    #   pols <- vapply(reactive_analyses()$analyses[anas], function(a) {
    #     paste0(unique(a$spectra_headers$polarity), collapse = ", ")
    #   }, NA_character_)
    #   tar <- MassSpecTargets(
    #     mz = data.frame(mass = mass, rt = rt),
    #     mobility = 0,
    #     ppm = ppm,
    #     sec = sec,
    #     millisec = 0,
    #     analyses = anas,
    #     polarities = pols
    #   )
    #   if (is.null(targets())) {
    #     targets(tar)
    #   } else {
    #     unified <- targets()
    #     unified <- rbind(unified, tar)
    #     unified <- unique(unified)
    #     targets(unified)
    #   }
    # })

    # # out EICs targets -----
    # output$eics_targets <- shiny::renderUI({
    #   if (is.null(targets())) {
    #     return()
    #   }
    #   if (nrow(targets()) == 0) {
    #     return()
    #   }
    #   lapply(seq_len(nrow(targets())), function(i) {
    #     shiny::observeEvent(
    #       input[[paste0("eics_del_", i)]],
    #       {
    #         unified <- targets()
    #         unified <- unified[-i, ]
    #         targets(unified)
    #       },
    #       ignoreInit = TRUE
    #     )

    #     htmltools::div(
    #       shiny::actionButton(
    #         ns(ns2(paste0("eics_del_", i))),
    #         label = NULL,
    #         icon = shiny::icon("trash"),
    #         width = "40px"
    #       ),
    #       htmltools::tags$b("  Analysis/Mass/RT/Mobility: "),
    #       paste0(targets()[i, "analysis"], " ", targets()[i, "id"]),
    #       htmltools::br()
    #     )
    #   })
    # })

    # # out EICs controls -----
    # output$eics_plot_controls <- shiny::renderUI({
    #   if (is.null(targets())) {
    #     return()
    #   }
    #   if (nrow(targets()) == 0) {
    #     return()
    #   }
    #   htmltools::div(
    #     style = "display: flex; align-items: center;",
    #     htmltools::div(
    #       style = "margin-left: 20px;",
    #       shiny::selectInput(
    #         ns(ns2("eics_chrom_colorby")),
    #         label = "Color by",
    #         choices = colorby_targets,
    #         selected = "targets+analyses",
    #         width = 200
    #       )
    #     ),
    #     htmltools::div(
    #       style = "margin-left: 20px;",
    #       shiny::checkboxInput(
    #         ns(ns2("eics_chrom_interactive")),
    #         label = "Interactive",
    #         value = FALSE,
    #         width = 100
    #       )
    #     ),
    #     htmltools::div(
    #       style = "margin-left: 20px;",
    #       shinyFiles::shinySaveButton(
    #         ns(ns2("eics_plot_save")),
    #         "Save Plot Data (.csv)",
    #         "Save Plot Data (.csv)",
    #         filename = "eics_data",
    #         filetype = list(csv = "csv")
    #       )
    #     ),
    #     htmltools::div(style = "margin-bottom: 20px;")
    #   )
    # })

    # # out EICs plotly -----
    # output$eics_plotly <- plotly::renderPlotly({
    #   if (is.null(targets())) {
    #     return()
    #   }
    #   if (is.null(input$eics_chrom_colorby)) {
    #     return()
    #   }
    #   if (nrow(targets()) == 0) {
    #     return()
    #   }
    #   anas <- unique(targets()[["analysis"]])
    #   plot_spectra_eic(
    #     reactive_analyses(),
    #     mz = targets(),
    #     colorBy = input$eics_chrom_colorby,
    #     interactive = TRUE
    #   )
    # })

    # # out EICs plot -----
    # output$eics_plot <- plotly::renderPlotly({
    #   if (is.null(targets())) {
    #     return()
    #   }
    #   if (is.null(input$eics_chrom_colorby)) {
    #     return()
    #   }
    #   if (nrow(targets()) == 0) {
    #     return()
    #   }
    #   anas <- unique(targets()[["analysis"]])
    #   plot_spectra_eic(
    #     reactive_analyses(),
    #     mz = targets(),
    #     colorBy = input$eics_chrom_colorby,
    #     interactive = TRUE
    #   )
    # })
  })
}

##' @noRd
##' @export
.mod_Explorer_UI.ProjectNonTargetAnalysis <- .mod_Explorer_UI.ProjectMassSpec

##' @noRd
##' @export
.mod_Explorer_Server.ProjectNonTargetAnalysis <- .mod_Explorer_Server.ProjectMassSpec

##' @noRd
##' @export
.mod_Explorer_UI.ProjectMassSpecSpectra <- .mod_Explorer_UI.ProjectMassSpec

##' @noRd
##' @export
.mod_Explorer_Server.ProjectMassSpecSpectra <- .mod_Explorer_Server.ProjectMassSpec

##' @noRd
##' @export
.mod_Explorer_UI.ProjectMassSpecChromatograms <- .mod_Explorer_UI.ProjectMassSpec

##' @noRd
##' @export
.mod_Explorer_Server.ProjectMassSpecChromatograms <- .mod_Explorer_Server.ProjectMassSpec
