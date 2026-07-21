library(streamfind)
library(streamfindData)

# resources --------------------------------------------------------------------
## files -------------------------------------------------------x----------------
all_ms_files <- streamfindData::get_ms_file_paths()
mrm_files <- all_ms_files[grepl("mrm", all_ms_files)]
ms_files <- all_ms_files[grepl("influent|blank", all_ms_files)]
raman_files <- streamfindData::get_raman_file_paths()
dev_file_path <- "C:/Users/apoli/Documents/example_files"
dev_files <- list.files(dev_file_path, pattern = "mzML", full.names = TRUE)[1:3]
## settings -------------------------------------------------------------------
workflow <- streamfind::Workflow(
  list(
    MassSpecMethod_FindFeatures_openms(),
    MassSpecMethod_AnnotateFeatures_streamfind(),
    MassSpecMethod_GroupFeatures_openms(),
    MassSpecMethod_FilterFeatures_streamfind(excludeIsotopes = TRUE),
    MassSpecMethod_FilterFeatures_patRoon(
      absMinIntensity = 5000,
      maxReplicateIntRSD = 30,
      blankThreshold = 10,
      absMinReplicateAbundance = 3
    ),
    MassSpecMethod_LoadFeaturesEIC_streamfind(rtExpand = 60, mzExpand = 0.0005),
    MassSpecMethod_CalculateFeaturesQuality_streamfind(),
    MassSpecMethod_FilterFeatures_streamfind(minSnRatio = 5),
    MassSpecMethod_LoadFeaturesMS1_streamfind(),
    MassSpecMethod_LoadFeaturesMS2_streamfind()
    # MassSpecMethod_LoadMSPeakLists_streamfind(),
    # MassSpecMethod_GenerateFormulas_genform(),
    # MassSpecMethod_GenerateCompounds_metfrag()
  )
)

# save(workflow, format = "rds", name = "workflow")

## databases -------------------------------------------------------------------
db <- streamfindData::get_ms_tof_spiked_chemicals()

## run_app() function ---------------------------------------------------------

# run_app()

# CoreEngine -------------------------------------------------------------------
# core <- CoreEngine$new()
# core$save(paste0(getwd(), "/core.rds"))
# core$run_app()

# MassSpecEngine ---------------------------------------------------------------
ms <- MassSpecEngine$new(analyses = dev_files, workflow = workflow)
ms$save(paste0(getwd(), "/ms.rds"))
ms$run_app()

# RamanEngine ------------------------------------------------------------------
raman <- RamanEngine$new(analyses = raman_files)
raman$Analyses$replicates <- c(rep("BVCZ", 11), rep("Blank", 11))
raman$Analyses$blanks <- rep("Blank", 22)
raman_workflow <- streamfind::Workflow(
  list(
    RamanMethod_AverageSpectra_native(),
    RamanMethod_SubtractBlankSpectra_streamfind(),
    RamanMethod_CorrectSpectraBaseline_baseline_als()
  )
)
raman$Workflow <- raman_workflow
#raman$run_workflow()
raman$save("raman.rds")
raman$run_app()
