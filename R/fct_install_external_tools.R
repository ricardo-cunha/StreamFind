# ── streamfind External Tools ─────────────────────────────────────────────────
# Helper functions and user-facing API for managing external software (Java,
# Boost, RDKit, LPSolve, MetFrag, CFM-ID, vcpkg) in ~/.streamfind/external/

# ── path helpers ──────────────────────────────────────────────────────────────

.streamfind_home <- function() {
  if (.Platform$OS.type == "windows") {
    file.path(Sys.getenv("USERPROFILE"), ".streamfind")
  } else {
    path.expand("~/.streamfind")
  }
}

.ext_dir <- function() {
  file.path(.streamfind_home(), "external")
}

.ensure_dir <- function(d) {
  if (!dir.exists(d)) dir.create(d, recursive = TRUE, showWarnings = FALSE)
  invisible(d)
}

.detect_platform <- function() {
  os <- .Platform$OS.type
  if (os == "windows") {
    list(os = "windows", arch = "x64", ext = ".zip", untar = FALSE)
  } else {
    sys <- Sys.info()["sysname"]
    if (sys == "Darwin") {
      list(os = "mac", arch = "x64", ext = ".tar.gz", untar = TRUE)
    } else {
      list(os = "linux", arch = "x64", ext = ".tar.gz", untar = TRUE)
    }
  }
}

.download <- function(url, destfile, quiet = TRUE) {
  old_timeout <- getOption("timeout")
  on.exit(options(timeout = old_timeout))
  options(timeout = 600)
  methods <- c("libcurl", "auto")
  for (m in methods) {
    status <- tryCatch(
      utils::download.file(url, destfile, mode = "wb", quiet = quiet, method = m),
      error = function(e) NULL
    )
    if (!is.null(status) && status == 0L) {
      if (file.exists(destfile) && file.info(destfile)$size > 0) return(TRUE)
    }
  }
  FALSE
}

.msg <- function(...) {
  message("[streamfind External Tools]  ", ...)
}

# ── exported getters ─────────────────────────────────────────────────────────

#' Path to the streamfind home directory
#'
#' Returns (and creates if needed) \code{~/.streamfind/}.
#' @return The normalized path to \code{~/.streamfind/}.
#' @export
get_streamfind_dir <- function() {
  dir <- .streamfind_home()
  if (!dir.exists(dir)) dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  invisible(dir)
}

#' Path to the external tools directory
#'
#' Returns (and creates if needed) \code{~/.streamfind/external/}.
#' @return The normalized path to \code{~/.streamfind/external/}.
#' @export
get_external_dir <- function() {
  dir <- .ext_dir()
  if (!dir.exists(dir)) dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  invisible(dir)
}

#' Locate the Java executable
#'
#' Checks PATH first, then scans \code{~/.streamfind/external/java/}.
#' @return Path to \code{java} (or \code{java.exe}), or \code{NA} if not found.
#' @export
get_java_path <- function() {
  if (nzchar(Sys.which("java"))) return("java")
  java_home <- list.files(file.path(.ext_dir(), "java"), pattern = "^jdk", full.names = TRUE)
  if (length(java_home) > 0) {
    exe <- if (.Platform$OS.type == "windows") "java.exe" else "java"
    path <- file.path(java_home[1], "bin", exe)
    if (file.exists(path)) return(path)
  }
  NA_character_
}

#' Locate the Boost installation directory
#'
#' Checks source-built (\code{boost/1.71.0/install}) and vcpkg
#' (\code{vcpkg/installed/x64-windows}) locations.
#' @return Path to Boost root, or \code{NA} if not found.
#' @export
get_boost_dir <- function() {
  # Source-built Boost
  dir <- file.path(.ext_dir(), "boost", "1.71.0", "install")
  if (dir.exists(file.path(dir, "include", "boost", "version.hpp"))) return(dir)
  # vcpkg-installed Boost (MSVC path)
  vcpkg_dir <- get_vcpkg_dir()
  if (!is.na(vcpkg_dir)) {
    vcpkg_boost <- file.path(vcpkg_dir, "installed", "x64-windows")
    if (file.exists(file.path(vcpkg_boost, "include", "boost", "version.hpp"))) return(vcpkg_boost)
  }
  NA_character_
}

#' Locate the RDKit installation directory
#'
#' Checks source-built (\code{rdkit/2017_09_3}) and conda
#' (\code{conda/Library}) locations.
#' @return Path to RDKit root, or \code{NA} if not found.
#' @export
get_rdkit_dir <- function() {
  # Check the original source build location first
  src_dir <- file.path(.ext_dir(), "rdkit", "2017_09_3")
  if (dir.exists(file.path(src_dir, "lib"))) return(src_dir)
  # Check conda installation
  conda_dir <- get_conda_dir()
  if (!is.na(conda_dir)) {
    if (.Platform$OS.type == "windows") {
      conda_rdkit <- file.path(conda_dir, "Library")
      if (dir.exists(file.path(conda_rdkit, "include", "rdkit"))) return(conda_rdkit)
    } else {
      conda_rdkit <- file.path(conda_dir, "include", "rdkit")
      if (dir.exists(conda_rdkit)) return(file.path(conda_dir))
    }
  }
  NA_character_
}

#' Locate the LPSolve installation directory
#'
#' Checks \code{~/.streamfind/external/lpsolve/5.5.2.11/}.
#' @return Path to LPSolve directory, or \code{NA} if not found.
#' @export
get_lpsolve_dir <- function() {
  dir <- file.path(.ext_dir(), "lpsolve", "5.5.2.11")
  if (file.exists(file.path(dir, "lp_lib.h"))) dir else NA_character_
}

#' Locate MSVC Build Tools installation
#'
#' Searches standard Visual Studio installation paths for \code{cl.exe}.
#' @return Path to VS BuildTools root, or \code{NA} if not found.
#' @export
get_msvc_dir <- function() {
  # Find MSVC by looking for cl.exe (the actual compiler)
  find_cl <- function(root) {
    tools <- file.path(root, "VC", "Tools", "MSVC")
    if (!dir.exists(tools)) return(NULL)
    vers <- list.files(tools)
    for (ver in rev(vers)) {  # newest first
      cl <- file.path(tools, ver, "bin", "Hostx64", "x64", "cl.exe")
      if (file.exists(cl)) return(root)
    }
    NULL
  }
  # Check standard VS installation paths
  # Check both year-named dirs (2022, 2026, etc.) and numeric version dirs (17, 18, etc.)
  for (year in c("2026", "2025", "2024", "2023", "2022", "2019", "2017", "18", "17", "16", "15")) {
    for (edition in c("Community", "Professional", "Enterprise", "BuildTools")) {
      d <- file.path("C:/Program Files", "Microsoft Visual Studio", year, edition)
      r <- find_cl(d); if (!is.null(r)) return(r)
      d <- file.path("C:/Program Files (x86)", "Microsoft Visual Studio", year, edition)
      r <- find_cl(d); if (!is.null(r)) return(r)
    }
  }
  NA_character_
}

# Find cmake from VS installation (preferred over Rtools cmake for MSVC builds)
.find_msvc_cmake <- function() {
  msvc_dir <- get_msvc_dir()
  if (is.na(msvc_dir)) return(Sys.which("cmake"))
  candidates <- c(
    file.path(msvc_dir, "Common7", "IDE", "CommonExtensions", "Microsoft", "CMake", "CMake", "bin", "cmake.exe"),
    file.path(msvc_dir, "Common7", "IDE", "CommonExtensions", "Microsoft", "CMake", "CMake", "bin", "cmake")
  )
  for (c in candidates) if (file.exists(c)) return(normalizePath(c, winslash = "\\"))
  Sys.which("cmake")
}

.ext_conda_dir <- function() {
  file.path(.ext_dir(), "conda")
}

#' Locate the Miniforge / Conda installation
#'
#' Checks \code{~/.streamfind/external/conda/}.
#' @return Path to conda root, or \code{NA} if not found.
#' @export
get_conda_dir <- function() {
  dir <- .ext_conda_dir()
  exe <- if (.Platform$OS.type == "windows") file.path(dir, "Scripts", "conda.exe") else file.path(dir, "bin", "conda")
  if (file.exists(exe)) dir else NA_character_
}

#' Locate the vcpkg installation directory
#'
#' Checks \code{~/.streamfind/external/vcpkg/}.
#' @return Path to vcpkg root, or \code{NA} if not found.
#' @export
get_vcpkg_dir <- function() {
  exe <- if (.Platform$OS.type == "windows") "vcpkg.exe" else "vcpkg"
  dir <- file.path(.ext_dir(), "vcpkg")
  if (file.exists(file.path(dir, exe))) dir else NA_character_
}

#' Locate the MetFrag CL JAR
#'
#' Checks \code{~/.streamfind/external/metfrag/MetFragCL.jar}.
#' @return Path to the JAR file, or \code{NA} if not found.
#' @export
get_metfrag_path <- function() {
  path <- file.path(.ext_dir(), "metfrag", "MetFragCL.jar")
  if (file.exists(path)) path else NA_character_
}

#' Locate a CFM-ID tool binary or wrapper
#'
#' Checks \code{~/.streamfind/external/cfm-id/bin/} for native binaries
#' (from source build) or \code{.bat} wrappers (from Docker install).
#' @param tool One of \code{"predict"}, \code{"annotate"}, \code{"id"},
#'   \code{"fraggraph_gen"}.
#' @return Full path to the tool, or \code{NA} if not found.
#' @export
get_cfm_id_tool <- function(tool = c("predict", "annotate", "id", "fraggraph_gen")) {
  tool <- match.arg(tool)
  bin_dir <- file.path(.ext_dir(), "cfm-id", "bin")
  if (dir.exists(bin_dir)) {
    exe <- paste0("cfm_", tool)
    if (.Platform$OS.type == "windows") {
      # Check both .exe and .bat wrappers
      exe_exe <- paste0(exe, ".exe"); exe_bat <- paste0(exe, ".bat")
      if (file.exists(file.path(bin_dir, exe_exe))) return(file.path(bin_dir, exe_exe))
      if (file.exists(file.path(bin_dir, exe_bat))) return(file.path(bin_dir, exe_bat))
    } else {
      if (file.exists(file.path(bin_dir, exe))) return(file.path(bin_dir, exe))
    }
  }
  # Check for docker wrappers
  if (.Platform$OS.type == "windows") {
    wrapper <- file.path(bin_dir, paste0("cfm_", tool, ".bat"))
    if (file.exists(wrapper)) return(wrapper)
  } else {
    wrapper <- file.path(bin_dir, paste0("cfm_", tool))
    if (file.exists(wrapper)) return(wrapper)
  }
  NA_character_
}

# ── check_external_tools ─────────────────────────────────────────────────────

#' Check status of all external tools
#'
#' Scans \code{~/.streamfind/external/} and the system PATH to report which
#' external tools are installed and where.  Tools are checked in dependency
#' order (build tools before package managers before libraries before
#' applications) so that missing prerequisites are evident.
#'
#' @param verbose If \code{TRUE} (default), print status messages.
#' @return A named logical vector with \code{TRUE} / \code{FALSE} / \code{NA}
#'   for each tool.
#' @export
check_external_tools <- function(verbose = TRUE) {
  result <- c(java = NA, msvc = NA, vcpkg = NA, conda = NA, boost = NA,
              rdkit = NA, lpsolve = NA, metfrag = NA, docker = NA,
              cfm_predict = NA, cfm_annotate = NA, cfm_id = NA,
              cfm_fraggraph_gen = NA)

  check1 <- function(name, label, condition, found_at) {
    ok <- isTRUE(condition)
    result[name] <<- ok
    if (verbose) {
      if (ok) message("[streamfind External Tools]  ", label, " found at: ", found_at)
      else message("[streamfind External Tools]  ", label, " not found.")
    }
  }

  # 1. Runtime environments (no dependencies)
  jp <- get_java_path()
  check1("java", "Java", !is.na(jp), jp)

  # 2. Build tools (needed by vcpkg, Boost, RDKit)
  md <- get_msvc_dir()
  check1("msvc", "MSVC Build Tools", !is.na(md),
         if (!is.na(md)) md else "")

  # 3. Package managers (needed by libraries)
  vd <- get_vcpkg_dir()
  check1("vcpkg", "vcpkg", !is.na(vd),
         if (!is.na(vd)) vd else "")

  cd <- get_conda_dir()
  check1("conda", "Miniforge/Conda", !is.na(cd),
         if (!is.na(cd)) cd else "")

  # 4. Libraries (needed by CFM-ID)
  bd <- get_boost_dir()
  check1("boost", "Boost", !is.na(bd),
         if (!is.na(bd)) bd else "")

  rd <- get_rdkit_dir()
  check1("rdkit", "RDKit 2017_09_3", !is.na(rd),
         if (!is.na(rd)) rd else "")

  ld <- get_lpsolve_dir()
  check1("lpsolve", "LPSolve 5.5.2.11", !is.na(ld),
         if (!is.na(ld)) ld else "")

  # 5. Applications
  mp <- get_metfrag_path()
  check1("metfrag", "MetFrag CL", !is.na(mp),
         if (!is.na(mp)) mp else "")

  # 6. Docker (independent until CFM-ID)
  dk <- get_docker_path()
  check1("docker", "Docker", !is.na(dk),
         if (!is.na(dk)) dk else "")

  for (tool in c("predict", "annotate", "id", "fraggraph_gen")) {
    tp <- get_cfm_id_tool(tool)
    check1(paste0("cfm_", tool), paste0("CFM-ID ", tool), !is.na(tp),
           if (!is.na(tp)) tp else "")
  }

  invisible(result)
}

# ── installers ───────────────────────────────────────────────────────────────

install_java <- function(quiet = TRUE) {
  if (nzchar(Sys.which("java"))) {
    .msg("Java found on PATH (", Sys.which("java"), "). Done!")
    return(invisible(TRUE))
  }
  java_root <- file.path(.ext_dir(), "java")
  existing <- list.files(java_root, pattern = "^jdk", full.names = TRUE)
  if (length(existing) > 0) {
    java_exe <- file.path(existing[1], "bin",
      if (.Platform$OS.type == "windows") "java.exe" else "java")
    if (file.exists(java_exe)) {
      .msg("Java already installed at ", existing[1], ". Done!")
      return(invisible(TRUE))
    }
  }
  .msg("Downloading Adoptium Temurin JDK 21 (~200 MB) ...")
  .ensure_dir(java_root)
  for (d in list.files(java_root, pattern = "^jdk", full.names = TRUE)) unlink(d, recursive = TRUE)
  plat <- .detect_platform()
  url <- sprintf("https://api.adoptium.net/v3/binary/latest/21/ga/%s/%s/jdk/hotspot/normal/eclipse",
                 plat$os, plat$arch)
  tmp <- file.path(tempdir(), paste0("temurin-jdk", plat$ext))
  unlink(tmp)
  ok <- .download(url, tmp, quiet = quiet)
  if (!ok) { unlink(tmp); .msg("Failed to download Java."); return(invisible(FALSE)) }
  .msg("Extracting JDK ...")
  if (plat$untar) utils::untar(tmp, exdir = java_root) else utils::unzip(tmp, exdir = java_root)
  unlink(tmp)
  extracted <- list.files(java_root, pattern = "^jdk", full.names = TRUE)
  if (length(extracted) == 0) { .msg("Extraction produced no jdk-* directory."); return(invisible(FALSE)) }
  java_home <- extracted[1]
  java_exe <- file.path(java_home, "bin", if (.Platform$OS.type == "windows") "java.exe" else "java")
  if (!file.exists(java_exe)) { .msg("java binary not found at ", java_exe); return(invisible(FALSE)) }
  .msg("Java installed at ", java_home, " Done!")
  invisible(TRUE)
}

install_vcpkg <- function(quiet = TRUE) {
  vcpkg_dir <- file.path(.ext_dir(), "vcpkg")
  vcpkg_exe <- file.path(vcpkg_dir, if (.Platform$OS.type == "windows") "vcpkg.exe" else "vcpkg")
  if (file.exists(vcpkg_exe)) { .msg("vcpkg already installed. Done!"); return(invisible(TRUE)) }
  git <- Sys.which("git")
  if (!nzchar(git)) { .msg("git not found. Cannot install vcpkg."); return(invisible(FALSE)) }
  .ensure_dir(dirname(vcpkg_dir))
  .msg("Cloning vcpkg ...")
  status <- system(sprintf('"%s" clone --depth 1 https://github.com/microsoft/vcpkg.git "%s"', git, vcpkg_dir),
                   ignore.stdout = quiet, ignore.stderr = quiet)
  if (status != 0L) { .msg("Failed to clone vcpkg."); return(invisible(FALSE)) }
  .msg("Bootstrapping vcpkg ...")
  if (.Platform$OS.type == "windows") {
    status <- system(sprintf('"%s\\bootstrap-vcpkg.bat"', vcpkg_dir),
                     ignore.stdout = quiet, ignore.stderr = quiet)
  } else {
    status <- system(sprintf('"%s/bootstrap-vcpkg.sh"', vcpkg_dir),
                     ignore.stdout = quiet, ignore.stderr = quiet)
  }
  if (status != 0L || !file.exists(vcpkg_exe)) { .msg("vcpkg bootstrap failed."); return(invisible(FALSE)) }
  .msg("vcpkg installed at ", vcpkg_dir, " Done!")
  invisible(TRUE)
}

install_msvc_buildtools <- function(quiet = TRUE) {
  if (!is.na(get_msvc_dir())) { .msg("MSVC Build Tools already installed. Done!"); return(invisible(TRUE)) }
  url <- "https://aka.ms/vs/17/release/vs_BuildTools.exe"
  tmp <- file.path(tempdir(), "vs_BuildTools.exe"); unlink(tmp)
  .msg("Downloading Visual Studio Build Tools bootstrapper ...")
  ok <- .download(url, tmp, quiet = quiet)
  if (!ok) { unlink(tmp); .msg("Failed to download VS Build Tools."); return(invisible(FALSE)) }
  .msg("Installing MSVC toolchain (10-30 min, ~1-3 GB)...")
  status <- system(
    sprintf('"%s" --quiet --wait --norestart --nocache --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended', tmp),
    ignore.stdout = quiet, ignore.stderr = quiet
  )
  unlink(tmp)
  if (status != 0L || is.na(get_msvc_dir())) { .msg("MSVC Build Tools install may have failed."); return(invisible(FALSE)) }
  .msg("MSVC Build Tools installed. Done!")
  invisible(TRUE)
}

install_boost <- function(quiet = TRUE) {
  if (.Platform$OS.type == "windows" && !is.na(get_msvc_dir())) {
    # MSVC available: use vcpkg for pre-built Windows Boost
    vd <- get_vcpkg_dir()
    if (is.na(vd)) {
      .msg("Installing vcpkg first ...")
      if (!isTRUE(install_vcpkg(quiet = quiet))) return(invisible(FALSE))
      vd <- get_vcpkg_dir()
    }
    .msg("Installing Boost via vcpkg (MSVC) ...")
    status <- system(sprintf('"%s" install boost:x64-windows',
                             file.path(vd, "vcpkg.exe")), ignore.stdout = quiet, ignore.stderr = quiet)
    if (status != 0L) { .msg("vcpkg Boost install failed."); return(invisible(FALSE)) }
    .msg("Boost installed via vcpkg at ", file.path(vd, "installed", "x64-windows"), " Done!")
    invisible(TRUE)
  } else {
    # Unix: build from source
    boost_dir <- file.path(.ext_dir(), "boost", "1.71.0")
    boost_install <- file.path(boost_dir, "install")
    boost_headers <- file.path(boost_install, "include", "boost", "version.hpp")
    if (file.exists(boost_headers)) { .msg("Boost 1.71.0 already installed. Done!"); return(invisible(TRUE)) }
    .ensure_dir(boost_dir)
    plat <- .detect_platform()
    url <- "https://archives.boost.io/release/1.71.0/source/boost_1_71_0"
    tmp <- file.path(tempdir(), paste0("boost_1_71_0", plat$ext))
    unlink(tmp)
    .msg("Downloading Boost 1.71.0 ...")
    ok <- .download(paste0(url, plat$ext), tmp, quiet = quiet)
    if (!ok) { unlink(tmp); .msg("Failed to download Boost."); return(invisible(FALSE)) }
    .msg("Extracting Boost ...")
    src_dir <- file.path(tempdir(), "boost_1_71_0")
    unlink(src_dir, recursive = TRUE)
    if (plat$untar) utils::untar(tmp, exdir = tempdir()) else utils::unzip(tmp, exdir = tempdir())
    unlink(tmp)
    if (!dir.exists(src_dir)) { .msg("Boost extraction failed."); return(invisible(FALSE)) }
    .msg("Building Boost libraries ...")
    old_dir <- getwd()
    on.exit(setwd(old_dir), add = TRUE)
    setwd(src_dir)
    bootstrap_ok <- FALSE
    if (.Platform$OS.type == "windows") {
      status <- system("bootstrap.bat mingw", ignore.stdout = quiet, ignore.stderr = quiet)
      bootstrap_ok <- (status == 0L && file.exists("b2.exe"))
    } else {
      status <- system("./bootstrap.sh --with-libraries=filesystem,system,serialization,program_options,thread",
                       ignore.stdout = quiet, ignore.stderr = quiet)
      bootstrap_ok <- (status == 0L && file.exists("b2"))
    }
    if (!bootstrap_ok) {
      setwd(old_dir)
      .msg("Boost bootstrap failed. Ensure a C++ compiler is available.")
      return(invisible(FALSE))
    }
    b2_cmd <- if (.Platform$OS.type == "windows") "b2.exe" else "./b2"
    ts_arg <- if (.Platform$OS.type == "windows") "toolset=gcc" else ""
    status <- system(sprintf("%s %s --prefix=\"%s\" --layout=system variant=release address-model=64 --with-filesystem --with-system --with-serialization --with-program_options --with-thread --with-regex install",
                             b2_cmd, ts_arg, boost_install),
                     ignore.stdout = quiet, ignore.stderr = quiet)
    setwd(old_dir)
    if (status != 0L) { .msg("Boost build failed."); return(invisible(FALSE)) }
    if (!file.exists(boost_headers)) { .msg("Boost install incomplete."); return(invisible(FALSE)) }
    .msg("Boost 1.71.0 installed at ", boost_dir, " Done!")
    invisible(TRUE)
  }
}

install_lpsolve <- function(quiet = TRUE) {
  lpsolve_dir <- file.path(.ext_dir(), "lpsolve", "5.5.2.11")
  if (file.exists(file.path(lpsolve_dir, "lp_lib.h"))) { .msg("LPSolve already installed. Done!"); return(invisible(TRUE)) }
  .ensure_dir(lpsolve_dir)
  plat <- .detect_platform()
  base_url <- "https://sourceforge.net/projects/lpsolve/files/lpsolve/5.5.2.11"
  url <- if (plat$os == "windows") {
    paste0(base_url, "/lp_solve_5.5.2.11_dev_win64.zip/download")
  } else {
    paste0(base_url, "/lp_solve_5.5.2.11_dev_ux64.tar.gz/download")
  }
  ext <- if (plat$untar) ".tar.gz" else ".zip"
  tmp <- file.path(tempdir(), paste0("lpsolve", ext))
  unlink(tmp)
  .msg("Downloading LPSolve ...")
  ok <- .download(url, tmp, quiet = quiet)
  if (!ok) { unlink(tmp); .msg("Failed to download LPSolve."); return(invisible(FALSE)) }
  .msg("Extracting LPSolve ...")
  extract_dir <- file.path(tempdir(), "lpsolve_extract")
  unlink(extract_dir, recursive = TRUE); dir.create(extract_dir, showWarnings = FALSE)
  if (plat$untar) utils::untar(tmp, exdir = extract_dir) else utils::unzip(tmp, exdir = extract_dir)
  unlink(tmp)
  for (h in c("lp_lib.h", "lp_types.h", "lp_utils.h", "lp_Hash.h", "lp_SOS.h", "lp_matrix.h", "lp_mipbb.h")) {
    f <- list.files(extract_dir, pattern = h, recursive = TRUE, full.names = TRUE)
    if (length(f) > 0) file.copy(f[1], file.path(lpsolve_dir, h), overwrite = TRUE)
  }
    lib_ext <- if (plat$os == "windows") "\\.(dll|lib)$" else "\\.(so|a)$"
  for (lf in list.files(extract_dir, pattern = lib_ext, recursive = TRUE, full.names = TRUE))
    file.copy(lf, file.path(lpsolve_dir, basename(lf)), overwrite = TRUE)
  unlink(extract_dir, recursive = TRUE)
  if (!file.exists(file.path(lpsolve_dir, "lp_lib.h"))) { .msg("LPSolve extraction incomplete."); return(invisible(FALSE)) }
  .msg("LPSolve 5.5.2.11 installed at ", lpsolve_dir, " Done!")
  invisible(TRUE)
}

install_metfrag <- function(quiet = TRUE) {
  metfrag_dir <- file.path(.ext_dir(), "metfrag")
  jar_path <- file.path(metfrag_dir, "MetFragCL.jar")
  if (file.exists(jar_path)) { .msg("MetFrag CL already installed. Done!"); return(invisible(TRUE)) }
  .ensure_dir(metfrag_dir)
  .msg("Looking up latest MetFrag CL release ...")
  tmp_json <- file.path(tempdir(), "metfrag_release.json"); unlink(tmp_json)
  jar_url <- NULL; jar_name <- NULL
  ok <- .download("https://api.github.com/repos/ipb-halle/MetFragRelaunched/releases/latest", tmp_json, quiet = quiet)
  if (ok && requireNamespace("jsonlite", quietly = TRUE)) {
    release <- jsonlite::fromJSON(tmp_json, simplifyVector = FALSE); unlink(tmp_json)
    for (a in release$assets) {
      if (grepl("\\.jar$", a$name) && grepl("CommandLine", a$name)) { jar_url <- a$browser_download_url; jar_name <- a$name; break }
    }
  } else { unlink(tmp_json) }
  if (is.null(jar_url)) {
    jar_url <- "https://github.com/ipb-halle/MetFragRelaunched/releases/download/v2.6.11/MetFragCommandLine-2.6.11.jar"
    jar_name <- "MetFragCommandLine-2.6.11.jar"
    .msg("Using MetFrag CL v2.6.11.")
  }
  .msg("Downloading MetFrag CL ...")
  tmp_jar <- file.path(tempdir(), jar_name); unlink(tmp_jar)
  ok <- .download(jar_url, tmp_jar, quiet = quiet)
  if (!ok) { unlink(tmp_jar); .msg("Failed to download MetFrag CL."); return(invisible(FALSE)) }
  file.copy(tmp_jar, jar_path, overwrite = TRUE); unlink(tmp_jar)
  if (!file.exists(jar_path)) { .msg("Failed to copy MetFrag CL JAR."); return(invisible(FALSE)) }
  .msg("MetFrag CL installed at ", jar_path, " Done!")
  invisible(TRUE)
}

#' Locate the Docker CLI
#'
#' Checks PATH first, then common install locations
#' (\code{C:/Program Files/Docker/Docker/resources/bin/}).
#' @return Path to \code{docker} (or \code{docker.exe}), or \code{NA}.
#' @export
get_docker_path <- function() {
  # Check if docker is on PATH
  docker <- Sys.which("docker")
  if (nzchar(docker)) return(normalizePath(docker, winslash = "\\"))
  # Check common install locations
  for (d in c("C:/Program Files/Docker/Docker/resources/bin/docker.exe",
              "C:/Program Files/Docker/Docker/resources/bin/docker",
              "C:/ProgramData/chocolatey/bin/docker.exe")) {
    if (file.exists(d)) return(normalizePath(d, winslash = "\\"))
  }
  NA_character_
}

check_wsl2 <- function() {
  if (.Platform$OS.type != "windows") return(TRUE)
  wsl <- Sys.which("wsl")
  if (!nzchar(wsl)) return(FALSE)
  # Use exit code: wsl --version returns 0 when WSL works
  status <- suppressWarnings(system(paste(shQuote(wsl), "--version"), ignore.stdout = TRUE, ignore.stderr = TRUE))
  if (status == 0L) return(TRUE)
  # Fallback: check for WSL install directories
  if (dir.exists(file.path(Sys.getenv("LOCALAPPDATA", ""), "Microsoft", "WSL"))) return(TRUE)
  if (dir.exists(file.path(Sys.getenv("SYSTEMROOT", "C:/Windows"), "System32", "lxss"))) return(TRUE)
  FALSE
}

check_virtualization <- function() {
  if (.Platform$OS.type != "windows") return(TRUE)

  # Check 1: Does the CPU support hardware virtualization?
  ps <- Sys.which("powershell")
  cpu_ok <- NA
  if (nzchar(ps)) {
    out <- suppressWarnings(system2(ps, c("-NoProfile", "-Command",
      "(Get-CimInstance Win32_ComputerSystem).HypervisorPresent"), stdout = TRUE))
    if (length(out) > 0L && !is.na(out[1]) && nzchar(out[1])) {
      cpu_ok <- grepl("^true", out[1], ignore.case = TRUE)
    }
  }

  # Check 2: Is the Virtual Machine Platform feature installed?
  # vmcompute.exe is the Hyper-V VM Compute binary, only present when
  # VirtualMachinePlatform optional feature is enabled.
  feature_ok <- file.exists(file.path(Sys.getenv("SYSTEMROOT", "C:/Windows"),
                                       "System32", "vmcompute.exe"))

  if (isTRUE(feature_ok) && isTRUE(cpu_ok)) return(TRUE)
  # VM Platform not installed — give actionable guidance
  if (!feature_ok) return(FALSE)
  # VM Platform is installed but CPU support couldn't be confirmed
  NA
}

install_wsl2 <- function(quiet = TRUE) {
  if (check_wsl2()) { .msg("WSL2 already installed. Done!"); return(invisible(TRUE)) }
  if (.Platform$OS.type != "windows") { .msg("WSL2 is Windows-only."); return(invisible(FALSE)) }

  # Modern Windows: wsl --install does everything in one command
  wsl <- Sys.which("wsl")
  if (nzchar(wsl)) {
    .msg("Running 'wsl --install' (installs WSL2 + Ubuntu Linux distro) ...")
    status <- system(paste(shQuote(wsl), "--install"), ignore.stdout = quiet, ignore.stderr = quiet)
    if (status == 0L) {
      .msg("WSL2 installed. REBOOT your system before using it. Done!")
      return(invisible(TRUE))
    }
  }

  # Fallback: manual steps
  .msg("WSL2 installation requires admin rights.",
       "\n  Open PowerShell as Administrator and run:",
       "\n    wsl --install",
       "\n  Then reboot your system.")
  invisible(FALSE)
}

install_docker <- function(quiet = TRUE) {
  if (.Platform$OS.type != "windows") {
    .msg("Docker not found. Install Docker from https://docs.docker.com/engine/install/")
    return(invisible(FALSE))
  }

  # Check hardware virtualization + VM Platform (required for WSL2/Docker)
  virt <- check_virtualization()
  if (isFALSE(virt)) {
    .msg("Hardware virtualization is not enabled.",
         "\n  WSL2 and Docker Desktop require:",
         "\n    1. Enable Virtual Machine Platform (Admin PowerShell):",
         "\n       Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform",
         "\n    2. Enable hardware virtualization in BIOS/UEFI firmware:",
         "\n       Look for 'Intel VT-x', 'AMD-V', or 'SVM Mode' in BIOS settings",
         "\n    3. Reboot after making these changes")
    return(invisible(FALSE))
  }

  # Ensure WSL2 is available first (required for Docker Desktop on Windows)
  if (!check_wsl2()) {
    .msg("WSL2 not found. Installing WSL2 first (requires admin rights) ...")
    install_wsl2(quiet = quiet)
  }

  # Check if Docker CLI is already available
  if (!is.na(get_docker_path())) {
    .msg("Docker CLI found at ", get_docker_path(), ". Done!")
    if (!check_wsl2()) {
      .msg("  But WSL2 is required. Run 'wsl --install' as admin and reboot.")
      return(invisible(FALSE))
    }
    # Ensure Docker bin dir is on PATH for credential helper
    docker_bin <- dirname(get_docker_path())
    curr_path <- Sys.getenv("PATH")
    if (!grepl(docker_bin, curr_path, fixed = TRUE)) {
      Sys.setenv(PATH = paste(docker_bin, curr_path, sep = ";"))
      # Persist for future sessions (user-level PATH)
      system(sprintf('setx PATH "%s;%%PATH%%"', docker_bin), ignore.stdout = TRUE, ignore.stderr = TRUE)
    }
    .msg("Docker appears ready. Done!")
    return(invisible(TRUE))
  }

  # Try winget first (built-in Windows package manager)
  winget <- Sys.which("winget")
  if (nzchar(winget)) {
    .msg("Installing Docker Desktop via winget ...")
    status <- system(sprintf('"%s" install -e --id Docker.DockerDesktop --accept-source-agreements --accept-package-agreements', winget),
                     ignore.stdout = quiet, ignore.stderr = quiet)
    if (status == 0L && !is.na(get_docker_path())) {
      .msg("Docker Desktop installed via winget. REBOOT before use. Done!")
      return(invisible(TRUE))
    }
  }

  .msg("Docker Desktop not installed.",
       "\n  Install it manually:",
       "\n    1. Enable WSL2 (requires admin): wsl --install",
       "\n    2. Download from https://www.docker.com/products/docker-desktop/",
       "\n    3. Run the installer",
       "\n  Or via winget: winget install -e --id Docker.DockerDesktop")
  return(invisible(FALSE))
}

install_cfmid_docker <- function(quiet = TRUE) {
  docker <- get_docker_path()
  if (is.na(docker)) {
    .msg("Docker not found. Installing Docker first ...")
    if (!isTRUE(install_docker(quiet = quiet))) {
      .msg("Docker required for Docker-based CFM-ID.")
      return(invisible(FALSE))
    }
    docker <- get_docker_path()
    if (is.na(docker)) { .msg("Docker still not found after install."); return(invisible(FALSE)) }
  }

  # Docker's credential helper needs its bin dir on PATH
  docker_bin <- dirname(docker)
  old_path <- Sys.getenv("PATH")
  if (!grepl(docker_bin, old_path, fixed = TRUE)) {
    Sys.setenv(PATH = paste(docker_bin, old_path, sep = ";"))
  }

  cfm_bin <- file.path(.ext_dir(), "cfm-id", "bin")
  .ensure_dir(cfm_bin)

  # Check Docker daemon connectivity
  daemon_ok <- suppressWarnings(system(paste(shQuote(docker), "info"),
                                        ignore.stdout = TRUE, ignore.stderr = TRUE))
  if (daemon_ok != 0L) {
    .msg("Docker CLI found but daemon is not running.")
    virt <- check_virtualization()
    if (isFALSE(virt)) {
      .msg("  Likely cause: Hardware virtualization is not enabled.",
           "\n    Enable Virtual Machine Platform (Admin PowerShell):",
           "\n      Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform",
           "\n    Enable virtualization in BIOS/UEFI firmware and reboot.")
    } else {
      .msg("  Start Docker Desktop and try again.")
    }
    return(invisible(FALSE))
  }

  .msg("Pulling wishartlab/cfmid Docker image (~200 MB) ...")
  status <- system(paste(shQuote(docker), "pull wishartlab/cfmid:latest"),
                   ignore.stdout = quiet, ignore.stderr = quiet)
  if (status != 0L) { .msg("Failed to pull CFM-ID Docker image."); return(invisible(FALSE)) }

  # Create wrapper batch scripts — add Docker bin dir to PATH so credential helper works
  tools <- list(
    cfm_predict = "cfm-predict",
    cfm_id = "cfm-id",
    cfm_annotate = "cfm-annotate",
    fraggraph_gen = "fraggraph-gen"
  )

  for (r_name in names(tools)) {
    cmd_name <- tools[[r_name]]
    if (.Platform$OS.type == "windows") {
      bat <- file.path(cfm_bin, paste0(r_name, ".bat"))
      writeLines(c(
        '@echo off',
        sprintf('set PATH=%s;%%PATH%%', docker_bin),
        sprintf('docker run --rm -v "%%CD%%:/cfmid/public" --workdir /cfmid/public wishartlab/cfmid:latest %s %%*', cmd_name)
      ), bat)
    } else {
      sh <- file.path(cfm_bin, r_name)
      writeLines(c(
        '#!/bin/sh',
        sprintf('PATH="%s:$PATH"', docker_bin),
        sprintf('docker run --rm -v "$(pwd):/cfmid/public" --workdir /cfmid/public wishartlab/cfmid:latest %s "$@"', cmd_name)
      ), sh)
      Sys.chmod(sh, "0755")
    }
  }

  .msg("CFM-ID Docker wrappers created in ", cfm_bin, " Done!")
  .msg("Usage: cfm_predict 'SMILES' 0.001 /trained_models_cfmid4.0/[M+H]+/param_output.log ...")
  .msg("  or: cfm_id <spectrum_file> <id> <candidates> ...")
  invisible(TRUE)
}

install_miniforge <- function(quiet = TRUE) {
  conda_dir <- .ext_conda_dir()
  conda_exe <- if (.Platform$OS.type == "windows") {
    file.path(conda_dir, "Scripts", "conda.exe")
  } else {
    file.path(conda_dir, "bin", "conda")
  }
  if (file.exists(conda_exe)) { .msg("Miniforge already installed. Done!"); return(invisible(TRUE)) }

  .ensure_dir(dirname(conda_dir))
  plat <- .detect_platform()

  if (plat$os == "windows") {
    url <- "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Windows-x86_64.exe"
    tmp <- file.path(tempdir(), "Miniforge3.exe"); unlink(tmp)
    .msg("Downloading Miniforge (~75 MB) ...")
    ok <- .download(url, tmp, quiet = quiet)
    if (!ok) { unlink(tmp); .msg("Failed to download Miniforge."); return(invisible(FALSE)) }
    .msg("Installing Miniforge to default location (will move to streamfind dir) ...")
    # Install to default location since NSIS /D= has inconsistent support
    status <- system(sprintf('"%s" /S /InstallationType=JustMe /RegisterPython=0', tmp),
                     ignore.stdout = quiet, ignore.stderr = quiet)
    unlink(tmp)
    if (status != 0L) { .msg("Miniforge install failed."); return(invisible(FALSE)) }
    # Miniforge installs to USERPROFILE\miniforge3 by default
    default_install <- file.path(Sys.getenv("USERPROFILE"), "miniforge3")
    if (dir.exists(default_install)) {
      file.rename(default_install, conda_dir)
    }
    if (!file.exists(conda_exe)) { .msg("Could not find conda.exe after install."); return(invisible(FALSE)) }
  } else if (plat$os == "mac") {
    url <- "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-MacOSX-x86_64.sh"
    tmp <- file.path(tempdir(), "Miniforge3.sh"); unlink(tmp)
    .msg("Downloading Miniforge ...")
    ok <- .download(url, tmp, quiet = quiet)
    if (!ok) { unlink(tmp); .msg("Failed to download Miniforge."); return(invisible(FALSE)) }
    .msg("Installing Miniforge ...")
    status <- system(sprintf('bash "%s" -b -p "%s"', tmp, conda_dir),
                     ignore.stdout = quiet, ignore.stderr = quiet)
    unlink(tmp)
    if (status != 0L || !file.exists(conda_exe)) { .msg("Miniforge install failed."); return(invisible(FALSE)) }
  } else {
    url <- "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh"
    tmp <- file.path(tempdir(), "Miniforge3.sh"); unlink(tmp)
    .msg("Downloading Miniforge ...")
    ok <- .download(url, tmp, quiet = quiet)
    if (!ok) { unlink(tmp); .msg("Failed to download Miniforge."); return(invisible(FALSE)) }
    .msg("Installing Miniforge ...")
    status <- system(sprintf('bash "%s" -b -p "%s"', tmp, conda_dir),
                     ignore.stdout = quiet, ignore.stderr = quiet)
    unlink(tmp)
    if (status != 0L || !file.exists(conda_exe)) { .msg("Miniforge install failed."); return(invisible(FALSE)) }
  }

  # Configure conda to not activate base by default
  system(sprintf('"%s" config --set auto_activate_base false', conda_exe),
         ignore.stdout = quiet, ignore.stderr = quiet)

  .msg("Miniforge installed at ", conda_dir, " Done!")
  invisible(TRUE)
}

install_rdkit_conda <- function(quiet = TRUE) {
  conda_dir <- .ext_conda_dir()
  conda_exe <- if (.Platform$OS.type == "windows") {
    file.path(conda_dir, "Scripts", "conda.exe")
  } else {
    file.path(conda_dir, "bin", "conda")
  }
  if (!file.exists(conda_exe)) {
    .msg("Installing Miniforge first ...")
    if (!isTRUE(install_miniforge(quiet = quiet))) return(invisible(FALSE))
  }

  # Check if rdkit is already installed in base env
  rdkit_check <- system(sprintf('"%s" list rdkit', conda_exe), intern = TRUE)
  if (any(grepl("rdkit", rdkit_check))) {
    .msg("RDKit already installed via conda. Done!")
    return(invisible(TRUE))
  }

  .msg("Installing RDKit via conda-forge (pre-compiled, ~30 sec) ...")
  status <- system(
    sprintf('"%s" install -c conda-forge librdkit-dev rdkit-dev -y -q', conda_exe),
    ignore.stdout = quiet, ignore.stderr = quiet
  )
  if (status != 0L) { .msg("Conda RDKit install failed."); return(invisible(FALSE)) }

  # Show what was installed
  installed <- system(sprintf('"%s" list rdkit', conda_exe), intern = TRUE)
  .msg("RDKit installed via conda-forge. Verifying libraries ...")

  if (.Platform$OS.type == "windows") {
    lib_dir <- file.path(conda_dir, "Library", "lib")
    inc_dir <- file.path(conda_dir, "Library", "include", "rdkit")
    if (dir.exists(lib_dir) && length(list.files(lib_dir, pattern = "RDKit.*\\.lib$")) > 0 &&
        dir.exists(inc_dir)) {
      .msg("RDKit C++ libraries found at ", lib_dir, " Done!")
      invisible(TRUE)
    } else {
      .msg("RDKit installed but C++ libraries not found.")
      return(invisible(FALSE))
    }
  } else {
    invisible(TRUE)
  }
}





# ── install_external_tools ───────────────────────────────────────────────────

#' Install external tools in dependency order
#'
#' Installs each requested tool by calling its \code{install_*} function.
#' Tools are installed in dependency order (e.g. MSVC before vcpkg, vcpkg
#' before Boost, conda before RDKit) so that prerequisites are satisfied.
#'
#' @param tools Character vector of tool names to install.  Default installs
#'   the core set (Java, MSVC, vcpkg, Boost, LPSolve, MetFrag, Docker,
#'   CFM-ID/Docker).  Other valid names: \code{"miniforge"},
#'   \code{"rdkit_conda"}.
#' @param quiet If \code{TRUE} (default), suppress sub-process output.
#' @return \code{TRUE} if all requested tools succeeded, \code{FALSE}
#'   otherwise (invisibly).
#' @export
install_external_tools <- function(
  tools = c("java", "msvc", "vcpkg", "boost", "lpsolve", "metfrag", "docker", "cfm_id_docker"),
  quiet = TRUE
) {
  ok <- TRUE
  # Runtime
  if ("java" %in% tools)          ok <- ok && isTRUE(install_java(quiet = quiet))
  # Build tools
  if ("msvc" %in% tools)          ok <- ok && isTRUE(install_msvc_buildtools(quiet = quiet))
  # Package managers
  if ("vcpkg" %in% tools)         ok <- ok && isTRUE(install_vcpkg(quiet = quiet))
  if ("miniforge" %in% tools)     ok <- ok && isTRUE(install_miniforge(quiet = quiet))
  # Libraries (Boost before RDKit, LPSolve independent)
  if ("boost" %in% tools)         ok <- ok && isTRUE(install_boost(quiet = quiet))
  if ("rdkit_conda" %in% tools)   ok <- ok && isTRUE(install_rdkit_conda(quiet = quiet))
  if ("lpsolve" %in% tools)       ok <- ok && isTRUE(install_lpsolve(quiet = quiet))
  # Applications
  if ("metfrag" %in% tools)       ok <- ok && isTRUE(install_metfrag(quiet = quiet))
  if ("docker" %in% tools)        ok <- ok && isTRUE(install_docker(quiet = quiet))
  if ("cfm_id_docker" %in% tools) ok <- ok && isTRUE(install_cfmid_docker(quiet = quiet))
  invisible(ok)
}
