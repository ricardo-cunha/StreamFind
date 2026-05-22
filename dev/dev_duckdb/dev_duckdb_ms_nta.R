project_db <- file.path("dev", "dev_duckdb", "data_nta.duckdb")
project_id <- "demo_nta"

# if (file.exists(project_db)) file.remove(project_db)

internal_standards <- fread(file.path("dev", "dev_duckdb", "internal_standards.csv"))
internal_standards <- internal_standards[!is.na(rt), ]

suspects <- fread(file.path("dev", "dev_duckdb", "suspects_with_ms2_template.csv"))
transformation_products <- fread(file.path("dev", "dev_duckdb", "transformation_products_template.csv"))

ms_files <- StreamFindData::get_ms_file_paths()
ms_files <- ms_files[grepl("ww_", ms_files)]

# -----------------------------------------------------------------------------
# 1. Open the NTA project
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
# 2. Inspect the project-owned method registry
# -----------------------------------------------------------------------------

registry <- nta$available_processing_methods()
names(registry)

projects_overview()$ProjectNonTargetAnalysis$processing_methods

# -----------------------------------------------------------------------------
# 3. Build and run a workflow using the new Method child classes
# -----------------------------------------------------------------------------

workflow <- Workflow(list(
  Method_NonTargetAnalysis_FindFeatures(
    rtWindows = data.frame(rtmin = numeric(), rtmax = numeric()),
    ppmThreshold = 10,
    noiseThreshold = 250,
    minSNR = 3,
    minTraces = 3L,
    baselineWindow = 200,
    maxWidth = 250,
    baseQuantile = 0.99,
    debugAnalysis = "",
    debugMZ = 0,
    debugSpecIdx = -1L
  ),
  Method_NonTargetAnalysis_LoadFeaturesMS1(
    filtered = FALSE,
    rtWindow = c(-1, 1),
    mzWindow = c(-1, 6),
    minTracesIntensity = 250,
    mzClust = 0.008,
    presence = 0.5
  ),
  Method_NonTargetAnalysis_LoadFeaturesMS2(
    filtered = FALSE,
    minTracesIntensity = 10,
    isolationWindow = 1.3,
    mzClust = 0.008,
    presence = 0.5
  ),
  Method_NonTargetAnalysis_CreateComponents(
    rtWindow = c(-5, 5),
    minCorrelation = 0.8,
    debugRT = 0,
    debugAnalysis = ""
  ),
  Method_NonTargetAnalysis_AnnotateComponents(
    maxIsotopes = 8L,
    maxCharge = 1L,
    maxGaps = 1L,
    ppm = 10,
    debugComponent = "",
    debugAnalysis = ""
  ),
  Method_NonTargetAnalysis_SuspectScreening(
    suspects = internal_standards,
    ppm = 10,
    sec = 15,
    ppmMS2 = 10,
    mzrMS2 = 0.008,
    minCosineSimilarity = 0.7,
    minSharedFragments = 3L,
    filtered = TRUE
  ),
  Method_NonTargetAnalysis_FilterInternalStandards(
    idLevels = c(1L, 3L)
  ),
  Method_NonTargetAnalysis_GroupFeatures(
    method = "internal_standards",
    rtDeviation = 5,
    ppm = 10,
    minSamples = 1L,
    binSize = 5,
    debug = FALSE,
    debugRT = 0
  ),
  Method_NonTargetAnalysis_BlankSubtraction(
    blankThreshold = 5,
    rtExpand = 10,
    mzExpand = 0.005
  ),
  Method_NonTargetAnalysis_FilterFeatures(
    minIntensity = 10000,
    removeIsotopes = TRUE,
    removeAdducts = TRUE,
    removeLosses = TRUE
  ),
  Method_NonTargetAnalysis_MetFragScreening(
    metfrag_path = "C:\\Users\\cunha\\Documents\\patRoon_deps\\MetFragCommandLine-2.5.0.jar",
    database_type = "LocalCSV",
    database_path = file.path("dev", "dev_duckdb", "transformation_products_template.csv"),
    ppm = 10,
    sec = 15,
    ppmMS2 = 10,
    mzrMS2 = 0.008,
    top_n = 5L,
    filtered = FALSE,
    java_path = "java",
    run_dir = "",
    debug = TRUE,
    extra_params = list()
  ),
  Method_NonTargetAnalysis_AssignTransformationProducts(
    transformation_products = transformation_products,
    chromatographic_phase = "reverse_phase",
    mzrMS2 = 0.008
  )
))

set_workflow(nta, workflow[1:3])

nta$run_workflow()



show(nta$get_workflow())

class(nta$get_workflow())

nta$list_tables()


nta <- open_ProjectNonTargetAnalysis(
  db = project_db,
  project_id = project_id
)

nta$run_app()




# -----------------------------------------------------------------------------
# 4. Inspect the results
# -----------------------------------------------------------------------------

get_cache(nta)

delete_cache(nta, name = "NTA_FEATURES_CACHE")

print(nta)


features_all <- get_features(nta)

features_subset <- get_features(
  nta,
  analyses = 11,
  mass = internal_standards[4:6, ],
  ppm = 20,
  sec = 60,
  filtered = FALSE
)

plot_features_ms2(
  nta,
  analyses = 11,
  mass = internal_standards[4:6, ],
  ppm = 20,
  sec = 60,
  filtered = FALSE
)

plot_features_ms1(
  nta,
  analyses = 11,
  mass = internal_standards[4:6, ],
  ppm = 20,
  sec = 60,
  filtered = FALSE
)

get_features_ms2(
  nta,
  analyses = 11,
  mass = internal_standards[4:6, ],
  ppm = 20,
  sec = 60,
  filtered = FALSE
)

get_raw_spectra_ms2(
  nta,
  analyses = 11,
  mass = internal_standards[4:6, ],
  ppm = 20,
  sec = 60
)


suspects_found <- get_suspects(nta)
internal_standards_found <- get_internal_standards(nta)
transformation_products_found <- get_transformation_products(nta)

head(features_all)
head(features_subset)
head(suspects_found)
head(internal_standards_found)
head(transformation_products_found)

t(features_subset)

plot_features(
  nta,
  analyses = 11,
  mass = internal_standards[4:6, ],
  ppm = 20,
  sec = 60,
  interactive = TRUE,
  showDetails = TRUE
)

# -----------------------------------------------------------------------------
# 5. Optional interactive/manual checks
# -----------------------------------------------------------------------------

# nta$run_app()
# plot_features_ms1(nta, interactive = TRUE)
# plot_suspects_ms2(nta, features = get_suspects(nta)[1, ], interactive = TRUE)
# plot_transformation_products(
#   nta,
#   groups = unique(transformation_products_found$feature_group)[1],
#   showMS2 = TRUE
# )
