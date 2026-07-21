.onLoad <- function(libname, pkgname) {
  ext_dir <- .streamfind_ext_dir()
  found_any <- FALSE
  .sf_configure_native_runtime()

  # Java — prepend ~/.streamfind/tools/java/jdk-*/bin/ to PATH
  java_dirs <- list.files(file.path(ext_dir, "java"), pattern = "^jdk", full.names = TRUE)
  if (length(java_dirs) > 0) {
    java_bin <- file.path(java_dirs[1], "bin")
    if (dir.exists(java_bin)) {
      Sys.setenv(JAVA_HOME = java_dirs[1])
      .path_prepend(java_bin)
      found_any <- TRUE
    }
  }

  # Boost — add lib dir to PATH (Windows) or LD_LIBRARY_PATH (Unix)
  boost_lib <- file.path(ext_dir, "boost", "1.71.0", "install", "lib")
  if (dir.exists(boost_lib)) {
    if (.Platform$OS.type == "windows") {
      .path_prepend(boost_lib)
    } else {
      .libpath_prepend(boost_lib)
    }
    found_any <- TRUE
  }

  # RDKit — add lib dir to PATH (Windows) or LD_LIBRARY_PATH (Unix)
  rdkit_lib <- file.path(ext_dir, "rdkit", "2017_09_3", "lib")
  if (dir.exists(rdkit_lib)) {
    if (.Platform$OS.type == "windows") {
      .path_prepend(rdkit_lib)
    } else {
      .libpath_prepend(rdkit_lib)
    }
    found_any <- TRUE
  }

  # CFM-ID — prepend ~/.streamfind/tools/cfm-id/bin/ to PATH
  cfm_bin <- file.path(ext_dir, "cfm-id", "bin")
  if (dir.exists(cfm_bin)) {
    .path_prepend(cfm_bin)
    found_any <- TRUE
  }

  # vcpkg — add to PATH
  vcpkg_exe <- if (.Platform$OS.type == "windows") "vcpkg.exe" else "vcpkg"
  vcpkg_dir <- file.path(ext_dir, "vcpkg")
  if (file.exists(file.path(vcpkg_dir, vcpkg_exe))) {
    .path_prepend(vcpkg_dir)
    found_any <- TRUE
  }

  # MetFrag — set default path option
  metfrag_jar <- file.path(ext_dir, "metfrag", "MetFragCL.jar")
  if (file.exists(metfrag_jar)) {
    options(streamfind.metfrag_path = metfrag_jar)
    found_any <- TRUE
  }

  # Warn if no external tools found — e.g. when loaded via devtools::load_all()
  if (!found_any && interactive() && !dir.exists(ext_dir)) {
    packageStartupMessage(
      "streamfind external tools not found. ",
      "Run install_external_tools() to download and set up Java and MetFrag."
    )
  }
}

.libpath_prepend <- function(dir) {
  var <- if (.Platform$OS.type == "windows") "PATH" else "LD_LIBRARY_PATH"
  curr <- strsplit(Sys.getenv(var), .Platform$path.sep)[[1]]
  curr <- setdiff(curr, dir)
  Sys.setenv(var = paste(c(dir, curr), collapse = .Platform$path.sep))
}

.streamfind_ext_dir <- function() {
  if (.Platform$OS.type == "windows") {
    file.path(Sys.getenv("USERPROFILE"), ".streamfind", "tools")
  } else {
    path.expand("~/.streamfind/tools")
  }
}

.path_prepend <- function(dir) {
  curr <- strsplit(Sys.getenv("PATH"), .Platform$path.sep)[[1]]
  curr <- setdiff(curr, dir)
  Sys.setenv(PATH = paste(c(dir, curr), collapse = .Platform$path.sep))
}
