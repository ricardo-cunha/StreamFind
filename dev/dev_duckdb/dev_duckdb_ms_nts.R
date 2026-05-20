standards <- StreamFindData::get_ms_tof_spiked_chemicals()
standards <- standards[grepl("S", standards$tag), ]
cols <- c("name", "formula", "mass", "rt", "tag")
internal_standards <- standards[standards$tag %in% "IS", ]
internal_standards <- internal_standards[, cols, with = FALSE]
internal_standards <- internal_standards[!internal_standards$name %in% c("Ibuprofen-d3", "Naproxen-d3"), ]
standards <- standards[standards$tag %in% "S", ]
standards <- standards[, cols, with = FALSE]
db_with_ms2 <- StreamFindData::get_ms_tof_spiked_chemicals_with_ms2()
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












project_db <- file.path("dev", "dev_duckdb", "data_nts.duckdb")
project_id <- "demo_nts"

internal_standards <- fread(file.path("dev", "dev_duckdb", "internal_standards.csv"))
internal_standards <- internal_standards[!is.na(rt), ]

suspects <- fread(file.path("dev", "dev_duckdb", "suspects_with_ms2_template.csv"))
transformation_products <- fread(file.path("dev", "dev_duckdb", "transformation_products_template.csv"))

ms_files <- StreamFindData::get_ms_file_paths()
ms_files <- ms_files[grepl("ww_", ms_files)]

# -----------------------------------------------------------------------------
# 1. Overview of the public project classes
# -----------------------------------------------------------------------------

project_classes <- ProjectClasses()
str(project_classes, max.level = 1)
ProjectClasses("ProjectNonTargetAnalysis")

# -----------------------------------------------------------------------------
# 2. Open the NTS project
# -----------------------------------------------------------------------------

nts <- ProjectNonTargetAnalysis$new(
  db = project_db,
  project_id = project_id
)

nts

nts$get_domain()

nts$list_tables()

# -----------------------------------------------------------------------------
# 3. Import files into the shared project DB
#    Run this section only when the project is still empty or you want to add
#    more analyses.
# -----------------------------------------------------------------------------

if (length(nts$get_analysis_names()) == 0) {
  nts$import_files(file_paths = ms_files)

  nts$set_replicate_names(c(
    rep("neg_blank", 3),
    rep("pos_blank", 3),
    rep("neg_influent", 3),
    rep("pos_influent", 3),
    rep("neg_effluent", 3),
    rep("pos_effluent", 3)
  ))

  nts$set_blank_names(c(
    rep("neg_blank", 3),
    rep("pos_blank", 3),
    rep("neg_blank", 3),
    rep("pos_blank", 3),
    rep("neg_blank", 3),
    rep("pos_blank", 3)
  ))
}

info(nts)

# -----------------------------------------------------------------------------
# 4. Inspect the project-owned processing registry
# -----------------------------------------------------------------------------

registry <- nts$available_processing_methods()
names(registry)
ProjectClasses("ProjectNonTargetAnalysis")$processing_methods

registry$FindFeatures_native
registry$SuspectScreening_metfrag

# -----------------------------------------------------------------------------
# 5. Run methods directly on the project object
#    These calls are the primary API for testing implementations in
#    ProjectNonTargetAnalysis.
# -----------------------------------------------------------------------------

features <- nts$find_features(
  rtWindows = data.frame(rtmin = numeric(), rtmax = numeric()),
  ppmThreshold = 10,
  noiseThreshold = 250,
  minSNR = 3,
  minTraces = 3,
  baselineWindow = 200,
  maxWidth = 250,
  baseQuantile = 0.99,
  debugAnalysis = "",
  debugMZ = 0,
  debugSpecIdx = -1L
)

head(features)

nts$load_features_ms1(
  rtWindow = c(-1, 1),
  mzWindow = c(-1, 6),
  mzClust = 0.008,
  presence = 0.5,
  minIntensity = 250,
  filtered = FALSE
)

nts$load_features_ms2(
  isolationWindow = 1.3,
  mzClust = 0.008,
  presence = 0.5,
  minIntensity = 10,
  filtered = FALSE
)

nts$create_components(
  rtWindow = c(-5, 5),
  minCorrelation = 0.8,
  debugRT = 0,
  debugAnalysis = ""
)

nts$annotate_components(
  maxIsotopes = 8,
  maxCharge = 1,
  maxGaps = 1,
  ppm = 10,
  debugComponent = "",
  debugAnalysis = ""
)

nts$find_internal_standards(
  suspects = internal_standards,
  ppm = 10,
  sec = 15,
  ppmMS2 = 10,
  mzrMS2 = 0.008,
  minCosineSimilarity = 0.7,
  minSharedFragments = 3,
  filtered = TRUE
)

# -----------------------------------------------------------------------------
# 6. Build and run a workflow from the registry metadata
#    This tests the project-owned workflow dispatcher.
# -----------------------------------------------------------------------------

configure_step <- function(step, parameters) {
  step$parameters <- parameters
  step
}

workflow <- Workflow(list(
  configure_step(registry$FindFeatures_native, list(
    analyses = character(),
    rtWindows = data.frame(rtmin = numeric(), rtmax = numeric()),
    ppmThreshold = 10,
    noiseThreshold = 250,
    minSNR = 3,
    minTraces = 3,
    baselineWindow = 200,
    maxWidth = 250,
    baseQuantile = 0.99,
    debugAnalysis = "",
    debugMZ = 0,
    debugSpecIdx = -1L
  )),
  configure_step(registry$LoadFeaturesMS1_native, list(
    analyses = character(),
    rtWindow = c(-1, 1),
    mzWindow = c(-1, 6),
    mzClust = 0.008,
    presence = 0.5,
    minIntensity = 250,
    filtered = FALSE
  )),
  configure_step(registry$LoadFeaturesMS2_native, list(
    analyses = character(),
    isolationWindow = 1.3,
    mzClust = 0.008,
    presence = 0.5,
    minIntensity = 10,
    filtered = FALSE
  )),
  configure_step(registry$CreateComponents_native, list(
    analyses = character(),
    rtWindow = c(-5, 5),
    minCorrelation = 0.8,
    debugRT = 0,
    debugAnalysis = ""
  )),
  configure_step(registry$AnnotateComponents_native, list(
    analyses = character(),
    maxIsotopes = 8,
    maxCharge = 1,
    maxGaps = 1,
    ppm = 10,
    debugComponent = "",
    debugAnalysis = ""
  )),
  configure_step(registry$FindInternalStandard_native, list(
    analyses = character(),
    suspects = internal_standards,
    ppm = 10,
    sec = 15,
    ppmMS2 = 10,
    mzrMS2 = 0.008,
    minCosineSimilarity = 0.7,
    minSharedFragments = 3,
    filtered = TRUE
  )),
  configure_step(registry$FilterInternalStandards_native, list(
    analyses = character(),
    idLevels = c(1, 3)
  )),
  configure_step(registry$GroupFeatures_native, list(
    analyses = character(),
    method = "internal_standards",
    rtDeviation = 5,
    ppm = 10,
    minSamples = 1,
    binSize = 5,
    filtered = FALSE,
    debug = FALSE,
    debugRT = 0
  )),
  configure_step(registry$FeatureBlankSubtraction_native, list(
    analyses = character(),
    blankThreshold = 5,
    rtExpand = 10,
    mzExpand = 0.005
  )),
  configure_step(registry$FilterFeatures_native, list(
    analyses = character(),
    minIntensity = 10000,
    removeIsotopes = TRUE,
    removeAdducts = TRUE,
    removeLosses = TRUE
  )),
  configure_step(registry$SuspectScreening_metfrag, list(
    analyses = character(),
    metfrag_path = "C:\\Users\\cunha\\Documents\\patRoon_deps\\MetFragCommandLine-2.5.0.jar",
    database_type = "LocalCSV",
    database_path = file.path("dev", "dev_duckdb", "transformation_products_template.csv"),
    ppm = 10,
    sec = 15,
    ppmMS2 = 10,
    mzrMS2 = 0.008,
    top_n = 5,
    filtered = FALSE,
    n_cores = 10,
    java_path = "java",
    metfrag_args = NULL,
    extra_params = list(),
    show_progress = TRUE,
    quiet = FALSE,
    debug = TRUE
  )),
  configure_step(registry$AssignTransformationProducts_native, list(
    analyses = character(),
    transformation_products = transformation_products,
    chromatographic_phase = "reverse_phase",
    mzrMS2 = 0.008
  ))
))

nts$run_workflow(workflow)

# -----------------------------------------------------------------------------
# 7. Inspect downstream results using the project object
# -----------------------------------------------------------------------------

features_all <- get_features(nts)
features_subset <- get_features(
  nts,
  mass = suspects$mass[1],
  ppm = 20,
  filtered = FALSE
)

suspects_found <- get_suspects(nts)
internal_standards_found <- get_internal_standards(nts)
transformation_products_found <- get_transformation_products(nts)

head(features_all)
head(features_subset)
head(suspects_found)
head(internal_standards_found)
head(transformation_products_found)

# -----------------------------------------------------------------------------
# 8. Optional interactive/manual checks
# -----------------------------------------------------------------------------

# nts$run_app()
# plot_features_ms1(nts, interactive = TRUE)
# plot_suspects_ms2(nts, features = get_suspects(nts)[1, ], interactive = TRUE)
# plot_transformation_products(nts, groups = unique(transformation_products_found$feature_group)[1], showMS2 = TRUE)
