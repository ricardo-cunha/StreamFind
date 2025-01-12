
library(StreamFind)




# Create -----------------------------------------------------------------------

# Load file paths
all_files <- StreamFindData::get_ms_file_paths()
files <- all_files[grepl("blank|influent|o3sw", all_files)]
files

# Make project headers
headers <- ProjectHeaders(
  name = "Wastewater project",
  description = "Project example"
)

# Create the "Engine"
ms <- MassSpecData$new(files = files, headers = headers)

# Print method and access methods
ms

ms$plot_bpc(analyses = c(4, 10), levels = 1)






# Change -----------------------------------------------------------------------

# Replicate names
rpls <- c(
  rep("blank_neg", 3), rep("blank_pos", 3),
  rep("influent_neg", 3), rep("influent_pos", 3),
  rep("effluent_neg", 3), rep("effluent_pos", 3)
)

# Respective blank replicate names
blks <- c(
  rep("blank_neg", 3), rep("blank_pos", 3),
  rep("blank_neg", 3), rep("blank_pos", 3),
  rep("blank_neg", 3), rep("blank_pos", 3)
)

# Add names to the Engine
ms$add_replicate_names(rpls)$add_blank_names(blks)

# Print
ms






# Processing settings ----------------------------------------------------------

ffs <- Settings_find_features_openms()


# Settings documentation
?Settings_find_features_openms


# Saves an example of settings on disk
save_default_ProcessingSettings(
  call = "find_features",
  algorithm = "openms",
  format = "json",
  name = "ffs"
)


ms$import_settings("ffs.json")


# Print
ms


# Loads a database of chemicals
db <- StreamFindData::get_ms_tof_spiked_chemicals()
cols <- c("name", "formula", "mass", "rt", "tag")
db <- db[, cols, with = FALSE]
# Only spiked internal standards
dbis <- db[grepl("IS", db$tag), ]
dbis


# Add other module processing settings
ms$add_settings(
  list(
    Settings_annotate_features_StreamFind(),

    Settings_group_features_openms(),

    Settings_find_internal_standards_StreamFind(
      database = dbis,
      ppm = 8,
      sec = 10
    ),

    Settings_filter_features_StreamFind(
      minIntensity = 5000,
      maxGroupSd = 30,
      blank = 5,
      minGroupAbundance = 3,
      excludeIsotopes = TRUE
    ),

    Settings_load_features_eic_StreamFind(
      rtExpand = 60,
      mzExpand = 0.0005
    ),

    Settings_load_features_ms1_StreamFind(),

    Settings_load_features_ms2_StreamFind(),

    Settings_load_groups_ms1_StreamFind(),

    Settings_load_groups_ms2_StreamFind(),

    Settings_calculate_quality_StreamFind()
  )
)


# Print
ms








# Process data -----------------------------------------------------------------

# Process all modules in workflow
ms$run_workflow()


# Alternative to chaining the processing modules
# ms$find_features()$annotate_features()$group_features()$filter_features()


# Print
ms









# Access and plot data ---------------------------------------------------------

# Get help for methods
ms$help$get_groups()


# Getting feature groups from the database
ms$get_groups(mass = db, ppm = 8, sec = 10, average = TRUE)


# Plot overview of feature groups
ms$plot_groups_overview(
  mass = db,
  ppm = 8, sec = 10,
  legendNames = TRUE
)


# Change filtered to TRUE to show hidden data
ms$get_groups(mass = db, ppm = 8, sec = 10, filtered = TRUE, average = TRUE)


# Quality check for spiked internal standards
ms$plot_internal_standards_qc()


# Raw data for given targets
ms$plot_eic(
  mass = 233.1131, # Naproxen-d3
  rt = 1169,
  ppm = 10,
  sec = 30,
  colorBy = "analyses"
)


# Isotopic chains
ms$map_components(
  analyses = 10,
  mass = db,
  ppm = 8, sec = 10,
  legendNames = TRUE
)






# Audit trail ------------------------------------------------------------------

ms$get_history()







# Export -----------------------------------------------------------------------

# Saves processing settings
ms$save_settings(format = "json", name = "settings")


# Saves all project data
ms$save(format = "json", name = "MassSpecData_example")










file.remove("ffs.json")
file.remove("settings.json")
file.remove("MassSpecData_example.json")
