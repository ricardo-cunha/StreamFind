project_db <- file.path("dev", "dev_duckdb", "data_nta.duckdb")
project_id <- "demo_nta"

#if (file.exists(project_db)) file.remove(project_db)

internal_standards <- fread(file.path("dev", "dev_duckdb", "internal_standards.csv"))
internal_standards <- internal_standards[!is.na(rt), ]

suspects <- fread(file.path("dev", "dev_duckdb", "suspects_with_ms2_template.csv"))
transformation_products <- fread(file.path("dev", "dev_duckdb", "transformation_products_template.csv"))

ms_files <- StreamFindData::get_ms_file_paths()
ms_files <- ms_files[grepl("ww_", ms_files)]

# -----------------------------------------------------------------------------
# 2. Open the NTS project
# -----------------------------------------------------------------------------

nta <- open_ProjectNonTargetAnalysis(
  db = project_db,
  project_id = project_id,
  file_paths = ms_files
)

nta$set_replicate_names(c(
  rep("neg_blank", 3),
  rep("pos_blank", 3),
  rep("neg_influent", 3),
  rep("pos_influent", 3),
  rep("neg_effluent", 3),
  rep("pos_effluent", 3)
))

nta$set_blank_names(c(
  rep("neg_blank", 3),
  rep("pos_blank", 3),
  rep("neg_blank", 3),
  rep("pos_blank", 3),
  rep("neg_blank", 3),
  rep("pos_blank", 3)
))

print(nta)

nta$get_domain()
nta$list_tables()
info(nta)

# -----------------------------------------------------------------------------
# 4. Inspect the project-owned processing registry
# -----------------------------------------------------------------------------

registry <- nta$available_processing_methods()
names(registry)
projects_overview()$ProjectNonTargetAnalysis$processing_methods

# -----------------------------------------------------------------------------
# 5. Run methods
# -----------------------------------------------------------------------------

nta <- open_ProjectNonTargetAnalysis(
  db = project_db,
  project_id = project_id
)

ffm <- Method_NonTargetAnalysis_FindFeatures(
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

run_method(nta, ffm)

get_cache(nta)
print(nta)
nta$list_tables()

t(get_features(
  nta,
  analyses = 11,
  mass = internal_standards[4, ],
  ppm = 20,
  sec = 60
))

plot_features(
  nta,
  analyses = 11,
  mass = internal_standards[4:6, ],
  ppm = 20,
  sec = 60,
  interactive = TRUE,
  showDetails = TRUE
)










features <- nta$find_features(
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

nta$load_features_ms1(
  rtWindow = c(-1, 1),
  mzWindow = c(-1, 6),
  mzClust = 0.008,
  presence = 0.5,
  minIntensity = 250,
  filtered = FALSE
)

nta$load_features_ms2(
  isolationWindow = 1.3,
  mzClust = 0.008,
  presence = 0.5,
  minIntensity = 10,
  filtered = FALSE
)

nta$create_componenta(
  rtWindow = c(-5, 5),
  minCorrelation = 0.8,
  debugRT = 0,
  debugAnalysis = ""
)

nta$annotate_componenta(
  maxIsotopes = 8,
  maxCharge = 1,
  maxGaps = 1,
  ppm = 10,
  debugComponent = "",
  debugAnalysis = ""
)

nta$find_internal_standards(
  suspects = internal_standards,
  ppm = 10,
  sec = 15,
  ppmMS2 = 10,
  mzrMS2 = 0.008,
  minCosineSimilarity = 0.7,
  minSharedFragmenta = 3,
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
  configure_step(registry$CreateComponenta_native, list(
    analyses = character(),
    rtWindow = c(-5, 5),
    minCorrelation = 0.8,
    debugRT = 0,
    debugAnalysis = ""
  )),
  configure_step(registry$AnnotateComponenta_native, list(
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
    minSharedFragmenta = 3,
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
    metfrag_path = "C:\\Users\\cunha\\Documenta\\patRoon_deps\\MetFragCommandLine-2.5.0.jar",
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

nta$run_workflow(workflow)

# -----------------------------------------------------------------------------
# 7. Inspect downstream results using the project object
# -----------------------------------------------------------------------------

features_all <- get_features(nta)
features_subset <- get_features(
  nta,
  mass = suspects$mass[1],
  ppm = 20,
  filtered = FALSE
)

suspects_found <- get_suspects(nta)
internal_standards_found <- get_internal_standards(nta)
transformation_products_found <- get_transformation_products(nta)

head(features_all)
head(features_subset)
head(suspects_found)
head(internal_standards_found)
head(transformation_products_found)

# -----------------------------------------------------------------------------
# 8. Optional interactive/manual checks
# -----------------------------------------------------------------------------

# nta$run_app()
# plot_features_ms1(nta, interactive = TRUE)
# plot_suspects_ms2(nta, features = get_suspects(nta)[1, ], interactive = TRUE)
# plot_transformation_products(nta, groups = unique(transformation_products_found$feature_group)[1], showMS2 = TRUE)
