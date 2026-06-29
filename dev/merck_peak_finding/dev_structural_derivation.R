library(knitr)
library(kableExtra)
library(data.table)
library(DT)
library(magrittr)
library(ggplot2)
library(plotly)
library(streamfind)

# devtools::load_all()

resources_file <- file.path(
  getwd(),
  "dev",
  "merck_peak_finding",
  "dev_resources.R"
)

if (!file.exists(resources_file)) {
  resources_file <- file.path(getwd(), "dev_resources.R")
}

project_dir <- file.path(dirname(resources_file), "data")
dir.create(project_dir, recursive = TRUE, showWarnings = FALSE)

source(resources_file)

example_key <- "ACC1_28203"
project_id <- paste0("merck_peak_finding_", example_key)
project_db <- file.path(project_dir, paste0(project_id, ".duckdb"))

ex_targets <- merck2_db_ex[example %in% example_key]
ex_files <- merck2_files_ex$file_path[grepl(example_key, merck2_files_ex$example)]




# Open the project

nta <- open_ProjectNonTargetAnalysis(
  db = project_db,
  project_id = project_id
)

#nta$run_app()


# rcpp_get_suspect_screening_csv_from_mol_files(
#   files = mol_merck_2[grepl(example_key, mol_merck_2)],
#   file = file.path("dev", "merck_peak_finding", "data", "ACC1_28203_suspects.csv")
# )

# rcpp_formula_from_mass(
#   180.0634,
#   tolerance_ppm = 5,
#   elements = c("C:1-80", "N:0-10", "O:0-20", "S:0-4", "Cl:0-6", "Br:0-4")
# )

# rcpp_formula_from_mass(
#   863.449100,
#   tolerance_ppm = 5,
#   elements = c("C:1-100", "N:0-10", "O:0-10")
# )

suspects <- data.table::fread(file.path("dev", "merck_peak_finding", "data", "ACC1_28203_suspects.csv"))
source("dev/merck_peak_finding/generate_spectra_cfm_id.R")
res <- cfm_predict(smiles = suspects$SMILES)

str(res)

res[[1]][1:2, ]

res$fragments[res$fragments$id %in% res$spectra$fragment_ids[[1]], ]

# Open the project and set up the workflow

nta <- open_ProjectNonTargetAnalysis(
  db = project_db,
  project_id = project_id,
  file_paths = ex_files
)

nta$set_replicate_names(c("blank", "sample"))
nta$set_blank_names(c("blank", "blank"))

workflow <- Workflow(list(
  Method_NonTargetAnalysis_FindFeatures(
    rtWindows = data.frame(rtmin = 300, rtmax = 3400),
    ppmThreshold = 15,
    noiseThreshold = 15,
    minSNR = 3,
    minTraces = 3L,
    baselineWindow = 200,
    maxWidth = 250,
    baseQuantile = 0.99,
    debugAnalysis = "",
    debugMZ = 0,
    debugSpecIdx = -1L
  ),
  Method_NonTargetAnalysis_CreateComponents(
    rtWindow = c(-5, 5),
    minCorrelation = 0.5,
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
  Method_NonTargetAnalysis_BlankSubtraction(
    blankThreshold = 5,
    rtExpand = 20,
    mzExpand = 0.005
  ),
  Method_NonTargetAnalysis_FilterFeatures(
    removeIsotopes = TRUE,
    removeAdducts = TRUE,
    removeLosses = TRUE
  ),
  Method_NonTargetAnalysis_LoadFeaturesMS1(
    rtWindow = c(-1, 1),
    mzWindow = c(-1, 6),
    mzClust = 0.008,
    presence = 0.5,
    minTracesIntensity = 50,
    filtered = FALSE
  ),
  Method_NonTargetAnalysis_LoadFeaturesMS2(
    isolationWindow = 1.3,
    mzClust = 0.008,
    presence = 0.5,
    minTracesIntensity = 10,
    filtered = FALSE
  )
))

set_workflow(nta, workflow)
run_workflow(nta)


