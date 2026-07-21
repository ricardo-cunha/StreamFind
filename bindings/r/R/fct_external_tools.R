# ── streamfind External Tools ─────────────────────────────────────────────────
# Java and MetFrag are the only external tools managed here.

.streamfind_home <- function() {
  if (.Platform$OS.type == "windows") {
    file.path(Sys.getenv("USERPROFILE"), ".streamfind")
  } else {
    path.expand("~/.streamfind")
  }
}

.ext_dir <- function() {
  file.path(.streamfind_home(), "tools")
}

.ensure_dir <- function(d) {
  if (!dir.exists(d)) dir.create(d, recursive = TRUE, showWarnings = FALSE)
  invisible(d)
}

.detect_platform <- function() {
  if (.Platform$OS.type == "windows") {
    list(os = "windows", arch = "x64", ext = ".zip", untar = FALSE)
  } else if (identical(Sys.info()[["sysname"]], "Darwin")) {
    list(os = "mac", arch = "x64", ext = ".tar.gz", untar = TRUE)
  } else {
    list(os = "linux", arch = "x64", ext = ".tar.gz", untar = TRUE)
  }
}

.download <- function(url, destfile, quiet = TRUE) {
  old_timeout <- getOption("timeout")
  on.exit(options(timeout = old_timeout), add = TRUE)
  options(timeout = 600)

  for (method in c("libcurl", "auto")) {
    status <- tryCatch(
      utils::download.file(url, destfile, mode = "wb", quiet = quiet, method = method),
      error = function(e) NULL
    )
    if (!is.null(status) && status == 0L && file.exists(destfile) && file.info(destfile)$size > 0) {
      return(TRUE)
    }
  }

  FALSE
}

.msg <- function(...) {
  message("[streamfind External Tools]  ", ...)
}

.sf_configure_native_runtime <- function() {
  java_path <- get_java_path()
  if (!is.na(java_path)) {
    java_home <- dirname(dirname(java_path))
    Sys.setenv(JAVA_HOME = java_home)
    .path_prepend(file.path(java_home, "bin"))
  }

  metfrag_jar <- get_metfrag_path()
  if (!is.na(metfrag_jar)) {
    options(streamfind.metfrag_path = metfrag_jar)
  }

  invisible(list(
    java = java_path,
    metfrag = metfrag_jar
  ))
}

#' Path to the streamfind home directory
#'
#' Returns (and creates if needed) `~/.streamfind/`.
#' @return The normalized path to `~/.streamfind/`.
#' @export
get_streamfind_dir <- function() {
  dir <- .streamfind_home()
  if (!dir.exists(dir)) dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  invisible(dir)
}

#' Path to the external tools directory
#'
#' Returns (and creates if needed) `~/.streamfind/tools/`.
#' @return The normalized path to `~/.streamfind/tools/`.
#' @export
get_external_dir <- function() {
  dir <- .ext_dir()
  if (!dir.exists(dir)) dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  invisible(dir)
}

#' Locate the Java executable
#'
#' Checks PATH first, then scans `~/.streamfind/tools/java/`.
#' @return Path to `java` (or `java.exe`), or `NA` if not found.
#' @export
get_java_path <- function() {
  java_path <- Sys.which("java")
  if (nzchar(java_path)) {
    return(normalizePath(java_path, winslash = if (.Platform$OS.type == "windows") "\\" else "/"))
  }

  java_home <- list.files(file.path(.ext_dir(), "java"), pattern = "^jdk", full.names = TRUE)
  if (length(java_home) > 0) {
    exe <- if (.Platform$OS.type == "windows") "java.exe" else "java"
    path <- file.path(java_home[1], "bin", exe)
    if (file.exists(path)) return(path)
  }

  NA_character_
}

#' Locate the MetFrag CL JAR
#'
#' Checks `~/.streamfind/tools/metfrag/MetFragCL.jar`.
#' @return Path to the JAR file, or `NA` if not found.
#' @export
get_metfrag_path <- function() {
  path <- file.path(.ext_dir(), "metfrag", "MetFragCL.jar")
  if (file.exists(path)) path else NA_character_
}

#' Report external tool paths
#'
#' @return A named list with the streamfind home/tools paths and the resolved
#'   Java/MetFrag locations when available.
#' @export
get_external_paths <- function() {
  list(
    home = get_streamfind_dir(),
    tools = get_external_dir(),
    java = get_java_path(),
    metfrag = get_metfrag_path()
  )
}

#' Check status of external tools
#'
#' @param verbose If `TRUE`, print a short status summary.
#' @return A named logical vector for Java and MetFrag.
#' @export
check_external_tools <- function(verbose = TRUE) {
  result <- c(java = NA, metfrag = NA)

  jp <- get_java_path()
  result["java"] <- !is.na(jp)
  if (verbose) {
    message("[streamfind External Tools]  Java ", if (result[["java"]]) paste0("found at: ", jp) else "not found.")
  }

  mp <- get_metfrag_path()
  result["metfrag"] <- !is.na(mp)
  if (verbose) {
    message("[streamfind External Tools]  MetFrag CL ", if (result[["metfrag"]]) paste0("found at: ", mp) else "not found.")
  }

  invisible(result)
}

#' Install Java
#'
#' Installs Temurin JDK 21 into `~/.streamfind/tools/java/` when Java is not
#' already available on PATH.
#' @param quiet If `TRUE` (default), suppress download output.
#' @return `TRUE` on success, `FALSE` otherwise (invisibly).
#' @export
install_java <- function(quiet = TRUE) {
  java_path <- get_java_path()
  if (!is.na(java_path)) {
    .msg("Java found at ", java_path, ". Done!")
    return(invisible(TRUE))
  }

  java_root <- file.path(.ext_dir(), "java")
  existing <- list.files(java_root, pattern = "^jdk", full.names = TRUE)
  if (length(existing) > 0) {
    exe <- file.path(existing[1], "bin", if (.Platform$OS.type == "windows") "java.exe" else "java")
    if (file.exists(exe)) {
      .msg("Java already installed at ", existing[1], ". Done!")
      return(invisible(TRUE))
    }
  }

  .ensure_dir(java_root)
  for (d in list.files(java_root, pattern = "^jdk", full.names = TRUE)) {
    unlink(d, recursive = TRUE)
  }

  plat <- .detect_platform()
  url <- sprintf(
    "https://api.adoptium.net/v3/binary/latest/21/ga/%s/%s/jdk/hotspot/normal/eclipse",
    plat$os,
    plat$arch
  )
  tmp <- file.path(tempdir(), paste0("temurin-jdk", plat$ext))
  unlink(tmp)

  .msg("Downloading Adoptium Temurin JDK 21 ...")
  if (!.download(url, tmp, quiet = quiet)) {
    unlink(tmp)
    .msg("Failed to download Java.")
    return(invisible(FALSE))
  }

  .msg("Extracting JDK ...")
  if (plat$untar) {
    utils::untar(tmp, exdir = java_root)
  } else {
    utils::unzip(tmp, exdir = java_root)
  }
  unlink(tmp)

  extracted <- list.files(java_root, pattern = "^jdk", full.names = TRUE)
  if (length(extracted) == 0) {
    .msg("Extraction produced no jdk-* directory.")
    return(invisible(FALSE))
  }

  java_home <- extracted[1]
  java_exe <- file.path(java_home, "bin", if (.Platform$OS.type == "windows") "java.exe" else "java")
  if (!file.exists(java_exe)) {
    .msg("java binary not found at ", java_exe)
    return(invisible(FALSE))
  }

  .msg("Java installed at ", java_home, ". Done!")
  invisible(TRUE)
}

#' Install MetFrag CL
#'
#' Ensures Java is available, then installs MetFrag CL as
#' `~/.streamfind/tools/metfrag/MetFragCL.jar`.
#' @param quiet If `TRUE` (default), suppress download output.
#' @return `TRUE` on success, `FALSE` otherwise (invisibly).
#' @export
install_metfrag <- function(quiet = TRUE) {
  if (is.na(get_java_path())) {
    .msg("Java not found. Installing Java runtime first ...")
    if (!isTRUE(install_java(quiet = quiet))) {
      .msg("Java installation failed. Cannot install MetFrag CL.")
      return(invisible(FALSE))
    }
  }

  metfrag_dir <- file.path(.ext_dir(), "metfrag")
  jar_path <- file.path(metfrag_dir, "MetFragCL.jar")
  if (file.exists(jar_path)) {
    .msg("MetFrag CL already installed. Done!")
    return(invisible(TRUE))
  }

  .ensure_dir(metfrag_dir)
  jar_url <- "https://github.com/ipb-halle/MetFragRelaunched/releases/download/v2.6.11/MetFragCommandLine-2.6.11.jar"
  jar_name <- "MetFragCommandLine-2.6.11.jar"
  tmp_jar <- file.path(tempdir(), jar_name)
  unlink(tmp_jar)

  .msg("Downloading MetFrag CL v2.6.11 ...")
  if (!.download(jar_url, tmp_jar, quiet = quiet)) {
    unlink(tmp_jar)
    .msg("Failed to download MetFrag CL.")
    return(invisible(FALSE))
  }

  file.copy(tmp_jar, jar_path, overwrite = TRUE)
  unlink(tmp_jar)
  if (!file.exists(jar_path)) {
    .msg("Failed to copy MetFrag CL JAR.")
    return(invisible(FALSE))
  }

  .msg("MetFrag CL installed at ", jar_path, ". Done!")
  invisible(TRUE)
}

#' Install external tools
#'
#' Installs Java and MetFrag CL.
#' @param tools Character vector of tool names to install.
#' @param quiet If `TRUE` (default), suppress download output.
#' @return `TRUE` if all requested tools succeeded, `FALSE` otherwise
#'   (invisibly).
#' @export
install_external_tools <- function(tools = c("java", "metfrag"), quiet = TRUE) {
  ok <- TRUE
  if ("java" %in% tools) ok <- ok && isTRUE(install_java(quiet = quiet))
  if ("metfrag" %in% tools) ok <- ok && isTRUE(install_metfrag(quiet = quiet))
  invisible(ok)
}

#' Prepend a directory to PATH
#' @noRd
.path_prepend <- function(dir) {
  curr <- strsplit(Sys.getenv("PATH"), .Platform$path.sep, fixed = TRUE)[[1]]
  curr <- setdiff(curr, dir)
  Sys.setenv(PATH = paste(c(dir, curr), collapse = .Platform$path.sep))
}
