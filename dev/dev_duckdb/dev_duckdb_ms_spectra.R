# MARK: Project Mass Spec shared DuckDB test

standards <- streamfindData::get_ms_tof_spiked_chemicals()
standards <- standards[grepl("S", standards$tag), ]
cols <- c("name", "formula", "mass", "rt", "tag")
internal_standards <- standards[standards$tag %in% "IS", ]
internal_standards <- internal_standards[, cols, with = FALSE]
internal_standards <- internal_standards[!internal_standards$name %in% c("Ibuprofen-d3", "Naproxen-d3"), ]
standards <- standards[standards$tag %in% "S", ]
standards <- standards[, cols, with = FALSE]
db_with_ms2 <- streamfindData::get_ms_tof_spiked_chemicals_with_ms2()
db_with_ms2 <- db_with_ms2[db_with_ms2$tag %in% "S", ]
db_with_ms2 <- db_with_ms2[, c("name", "formula", "mass", "SMILES", "rt", "polarity", "fragments"), with = FALSE]
db_with_ms2$polarity[db_with_ms2$polarity == 1] <- "positive"
db_with_ms2$polarity[is.na(db_with_ms2$polarity)] <- "positive"
db_with_ms2$polarity[db_with_ms2$polarity == -1] <- "negative"

db <- file.path("dev", "dev_duckdb", "data", "ms_project_test.duckdb")
if (file.exists(db)) file.remove(db)

#main_drive <- "D:"
main_drive <- "E:"

ms_files <- c(
  file.path(main_drive, "example_files", "ms_basic", "00_hrms_mix1_pos_cent-r001.mzML"),
  file.path(main_drive, "example_files", "ms_basic", "00_hrms_mix1_pos_cent-r002.mzML"),
  file.path(main_drive, "example_files", "ms_basic", "00_hrms_mix1_pos_cent-r003.mzML")
)

ms_files_mzxml <- c(
  file.path(main_drive, "example_files", "ms_basic_mzxml", "00_hrms_mix1_pos_mzxml_cent-r001.mzXML"),
  file.path(main_drive, "example_files", "ms_basic_mzxml", "00_hrms_mix1_pos_mzxml_cent-r002.mzXML"),
  file.path(main_drive, "example_files", "ms_basic_mzxml", "00_hrms_mix1_pos_mzxml_cent-r003.mzXML")
)

proj <- OpenProjectMassSpecSpectra(
  db = db,
  project_id = "ms-demo",
  file_paths = ms_files
)

proj <- OpenProjectMassSpecSpectra(
  db = db,
  project_id = "ms-demo"
)

proj$get_cache()
proj$get_project_id()
proj$get_domain()
proj$set_metadata(
  list(
    name = "Mass Spec shared DB demo",
    description = "Shared DuckDB project with MS domain tables"
  )
)
proj$get_metadata()
proj$list_tables()
proj$get_analyses()
proj$get_spectra_headers()
proj$get_spectra_tic()
proj$plot_spectra_tic(interactive = FALSE, levels = 1)
proj$plot_spectra_bpc(interactive = FALSE, levels = 1)

devtools::load_all()
db <- file.path("dev", "dev_duckdb", "data", "ms_project_test.duckdb")


proj <- OpenProjectMassSpecSpectra(
  db = db,
  project_id = "ms-demo"
)

proj

spec <- proj$get_raw_spectra(
  analyses = character(),
  levels = 1,
  mass = internal_standards[4, ],
  mz = numeric(),
  rt = numeric(),
  mobility = numeric(),
  ppm = 20,
  sec = 60,
  millisec = 5,
  id = character(),
  allTraces = TRUE,
  isolationWindow = 1.3,
  minIntensityMS1 = 0,
  minIntensityMS2 = 0
)

plot(spec$rt, spec$intensity, type = "l")

plot_raw_spectra_eic(
  proj,
  mass = internal_standards[4:5, ],
  interactive = FALSE
)

plot_raw_spectra_ms2(
  proj,
  mass = internal_standards[4:5, ],
  presence = 0.5
)

plot_raw_spectra_ms1(
  proj,
  mass = internal_standards[4:5, ],
  presence = 0.5
)

get_chromatograms_headers(proj)

plot_raw_chromatograms(
  proj,
  analyses = 1,
  chromatograms = "TIC",
  interactive = FALSE
)

htmlwidgets::saveWidget()

proj$import_files(ms_files)

proj$list_tables()
proj$list_analyses()



head(proj$get_spectra_headers())
head(proj$get_chromatograms_headers())





plot_spectra_bpc(proj)


