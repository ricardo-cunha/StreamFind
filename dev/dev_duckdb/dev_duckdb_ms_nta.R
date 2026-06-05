library(StreamFind)
library(data.table)

project_db <- file.path("dev", "dev_duckdb", "data_nta.duckdb")
project_id <- "demo_nta"

# if (file.exists(project_db)) file.remove(project_db)

internal_standards <- fread(file.path("dev", "dev_duckdb", "internal_standards_v3.csv"))
internal_standards <- internal_standards[!is.na(rt), ]
internal_standards <- internal_standards[, c("name", "InChI", "rt", "ms2_positive")]

suspects <- fread(file.path("dev", "dev_duckdb", "suspects_with_ms2_template.csv"))
suspects <- suspects[, c("name", "InChI", "rt", "ms2_positive")]

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
  Method_NonTargetAnalysis_FindInternalStandards(
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
    idLevels = c(1L, 2L, 3L)
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
  Method_NonTargetAnalysis_FillFeatures(
    withinReplicate = FALSE,
    filtered = FALSE,
    rtExpand = 10,
    mzExpand = 0.01,
    maxPeakWidth = 30,
    minTracesIntensity = 1000,
    minNumberTraces = 5L,
    minIntensity = 5000,
    rtApexDeviation = 5,
    minSignalToNoiseRatio = 3,
    minGaussianFit = 0.2,
    debugFG = ""
  ),
  # Method_NonTargetAnalysis_CorrectMatrixSuppression(
  #   refBlankReplicate = NA_character_,
  #   mpRtWindow = 10
  # ),
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
  # Method_NonTargetAnalysis_SuspectScreening(
  #   suspects = suspects,
  #   ppm = 5,
  #   sec = 10,
  #   ppmMS2 = 10,
  #   mzrMS2 = 0.008,
  #   minCosineSimilarity = 0.7,
  #   minSharedFragments = 3L,
  #   filtered = TRUE
  # ),
  Method_NonTargetAnalysis_MetFragScreening(
    metfrag_path = "C:\\Users\\cunha\\Documents\\patRoon_deps\\MetFragCommandLine-2.5.0.jar",
    database_type = "LocalCSV",
    database_path = file.path("dev", "dev_duckdb", "suspects_template_V2.csv"),
    ppm = 10,
    sec = 15,
    ppmMS2 = 10,
    mzrMS2 = 0.008,
    top_n = 5L,
    score_types = "FragmenterScore",
    score_weights = 1,
    pre_processing_candidate_filter = c("UnconnectedCompoundFilter", "IsotopeFilter"),
    post_processing_candidate_filter = "InChIKeyFilter",
    maximum_tree_depth = 2L,
    number_threads = 1L,
    use_smiles = TRUE,
    filtered = FALSE,
    java_path = "java",
    run_dir = "",
    debug = TRUE,
    extra_params = list()
  )
  # Method_NonTargetAnalysis_AssignTransformationProducts(
  #   transformation_products = transformation_products,
  #   chromatographic_phase = "reverse_phase",
  #   mzrMS2 = 0.008
  # )
))

set_workflow(nta, workflow)

show(nta$get_workflow())




# get_suspects_screening_csv(
#   suspects = data.table::fread(
#     file.path(
#       getwd(),
#       "dev",
#       "dev_duckdb",
#       "internal_standards_fants.csv"
#     )
#   ),
#   file = file.path(
#     getwd(),
#     "dev",
#     "dev_duckdb",
#     "internal_standards_fants_V2.csv"
#   )
# )



nta$run_workflow()



run(suspect_screening_method, nta)

head(get_suspects(nta)[id_level == 2, ])


nrow(get_internal_standards(nta))

head(get_internal_standards(nta))

class(nta$get_workflow())

nta$list_tables()


rm(nta)
gc()
devtools::load_all()

nta <- open_ProjectNonTargetAnalysis(
  db = project_db,
  project_id = project_id
)

#nta$run_workflow()

nta$run_app()


run_app()


comp <- "FC38_RT1007_POS"
fts <- get_features(nta, filtered = TRUE)
fts_comp <- fts[feature_component == comp, ]

fts_comp[, .(feature, mass, adduct)]

# -----------------------------------------------------------------------------
# 4. Inspect the results
# -----------------------------------------------------------------------------

get_cache(nta)

delete_cache(nta, name = "NTA_FEATURES_CACHE")
delete_cache(nta, name = "NTA_INTERNAL_STANDARDS_CACHE")
delete_cache(nta, name = "NTA_SUSPECTS_CACHE")

print(nta)


features_all <- get_features(nta)

features_subset <- get_features(
  nta,
  #analyses = 11,
  mass = internal_standards[4, ],
  ppm = 20,
  sec = 60,
  filtered = TRUE
)[, 1:35]


tic_plot <- plot_spectra_tic(
  nta,
  downsize = 1,
  levels = 1,
  groupBy = "replicate"
)

matrix_suppression_plot <- plot_matrix_suppression(
  nta,
  colorBy = "replicates"
)

tic_matrix_subplot <- plotly::subplot(
  tic_plot,
  matrix_suppression_plot,
  nrows = 2,
  shareX = TRUE,
  titleY = TRUE
)

htmlwidgets::saveWidget(
  tic_matrix_subplot,
  file = file.path("dev", "dev_duckdb", "tic_matrix_suppression_subplot.html"),
  selfcontained = TRUE
)

tic_matrix_subplot

plot_features(
  nta,
  mass = internal_standards[4, ],
  ppm = 20,
  sec = 60,
  filtered = TRUE
)

plot_features_profile(
  nta,
  #analyses = 11,
  mass = internal_standards[4, ],
  ppm = 20,
  sec = 60,
  corrected = TRUE,
  filtered = TRUE
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


# Toxicity via SMILES

suspects <- data.table::fread(
  file.path("dev", "dev_duckdb", "suspects_with_ms2_template.csv")
)
sus_smiles <- suspects[, c("name", "SMILES", "mass")]
colnames(sus_smiles) <- c("name", "SMILES", "exactMass")

library(rcdk)
mol <- parse.smiles(sus_smiles$SMILES[11])[[1]]

# perceive chemistry (recommended)
# do.typing(mol)
set.atom.types(mol)
do.aromaticity(mol)
do.isotopes(mol)

# compute fingerprint (types: "standard","extended","maccs","pubchem","morgan", etc.)
fp <- get.fingerprint(mol, type = "extended")

# inspect / print
print(fp)


if (!require("BiocManager", quietly = TRUE)) install.packages("BiocManager")
BiocManager::install("Rdisop")
remotes::install_github("kruvelab/MS2Tox", INSTALL_opts="--no-multiarch", force = TRUE)

library(MS2Tox)
lc50 <- LC50fromSMILES(compoundslistwithSMILES = sus_smiles[11, ])

# Addition to SIRIUS fingerprints it is also possible to calculate LC50 values using SMILES as an input. For that use function LC50fromSMILES(compoundslistwithSMILES). PS! Input needs to be a table containing columns named "SMILES" and "exactMass". Use exactly this format for naming.


pred_log <- lc50$LC50_predicted           # predicted log10(LC50 [mmol/L])
mmol_per_L <- 10^pred_log       # mmol/L
mol_per_L  <- mmol_per_L / 1000 # mol/L

molar_mass <- sus_smiles$exactMass[11]            # Diuron molar mass (g/mol)
mg_per_L <- mmol_per_L * molar_mass  # mg/L  (since mmol/L * g/mol = mg/L)

cat(mg_per_L, " mg/L\n")








#Before installing MS2Tox package Rdisop is needed to be installed. To install this package, start R (version "4.1") and enter:





