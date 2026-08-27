//! User-scoped external tool provisioning, mirroring the R package's
//! `~/.streamfind` layout (`bindings/r/R/fct_external_tools.R`):
//!
//! - home: `%USERPROFILE%\.streamfind` (Windows) or `~/.streamfind` (POSIX);
//!   `STREAMFIND_HOME` overrides for tests and custom setups.
//! - tools: `<home>/tools/`
//! - Java (Temurin JDK 21): `<tools>/java/jdk-*/bin/java(.exe)`,
//!   discovered PATH-first, then `JAVA_HOME`, then that directory.
//! - MetFrag CL: `<tools>/metfrag/MetFragCL.jar` (MetFragCommandLine 2.6.11).
//!
//! Installers download with `curl` and extract with `tar` (Windows 10+ ships
//! bsdtar, which handles both `.zip` and `.tar.gz`); no HTTP library needed.

use std::env;
use std::path::PathBuf;
use std::process::Command;

/// Temurin JDK 21 "latest" binary from the Adoptium API (same source/version
/// as the R package installer).
pub const JAVA_JDK_URL_TEMPLATE: &str =
    "https://api.adoptium.net/v3/binary/latest/21/ga/{os}/{arch}/jdk/hotspot/normal/eclipse";
/// Pinned MetFragCommandLine release used by `bindings/r`.
pub const METFRAG_JAR_URL: &str = "https://github.com/ipb-halle/MetFragRelaunched/releases/download/v2.6.11/MetFragCommandLine-2.6.11.jar";
pub const METFRAG_JAR_NAME: &str = "MetFragCL.jar";

/// `STREAMFIND_HOME` override, else `%USERPROFILE%\.streamfind` / `~/.streamfind`.
pub fn streamfind_home() -> PathBuf {
    if let Some(home) = env::var_os("STREAMFIND_HOME") {
        return PathBuf::from(home);
    }
    let base = env::var_os("USERPROFILE")
        .or_else(|| env::var_os("HOME"))
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("."));
    base.join(".streamfind")
}

/// `<home>/tools`.
pub fn tools_dir() -> PathBuf {
    streamfind_home().join("tools")
}

fn executable(name: &str) -> String {
    if cfg!(windows) {
        format!("{name}.exe")
    } else {
        name.to_owned()
    }
}

fn find_on_path(name: &str) -> Option<PathBuf> {
    let name = executable(name);
    env::var_os("PATH")?
        .to_str()?
        .split(if cfg!(windows) { ';' } else { ':' })
        .map(PathBuf::from)
        .flat_map(|dir| [dir.join(&name), dir.join(&name)])
        .find(|path| path.is_file())
        .or_else(|| {
            // process-local helper (e.g. git-bash) may shadow; also try `which`-style
            // via command lookup on Windows without a shell.
            None
        })
}

/// Locates `java`/`java.exe` following the R package rule:
/// PATH -> `JAVA_HOME/bin` -> `<tools>/java/jdk-*/bin`.
pub fn resolve_java() -> Option<PathBuf> {
    if let Some(path) = find_on_path("java") {
        return Some(path);
    }
    if let Some(java_home) = env::var_os("JAVA_HOME") {
        let candidate = PathBuf::from(java_home).join("bin").join(executable("java"));
        if candidate.is_file() {
            return Some(candidate);
        }
    }
    let java_tools = tools_dir().join("java");
    let Ok(entries) = std::fs::read_dir(&java_tools) else {
        return None;
    };
    let mut jdks: Vec<PathBuf> = entries
        .filter_map(|entry| entry.ok())
        .map(|entry| entry.path())
        .filter(|path| {
            path.file_name()
                .and_then(|name| name.to_str())
                .is_some_and(|name| name.starts_with("jdk"))
        })
        .collect();
    jdks.sort();
    jdks.into_iter().find_map(|jdk| {
        let candidate = jdk.join("bin").join(executable("java"));
        candidate.is_file().then_some(candidate)
    })
}

/// Locates the MetFrag command-line jar in `<tools>/metfrag/MetFragCL.jar`.
pub fn resolve_metfrag_jar() -> Option<PathBuf> {
    let jar = tools_dir().join("metfrag").join(METFRAG_JAR_NAME);
    jar.is_file().then_some(jar)
}

/// (java executable, metfrag jar) when both are installed.
pub fn resolve_metfrag() -> Option<(PathBuf, PathBuf)> {
    Some((resolve_java()?, resolve_metfrag_jar()?))
}

fn run(command: &mut Command) -> Result<(), String> {
    let status = command.status().map_err(|error| format!("failed to run {:?}: {error}", command.get_program()))?;
    if status.success() {
        Ok(())
    } else {
        Err(format!("{:?} exited with {status}", command.get_program()))
    }
}

/// Downloads `<tools>/metfrag/MetFragCL.jar` (MetFragCommandLine 2.6.11).
pub fn install_metfrag() -> Result<PathBuf, String> {
    let metfrag_dir = tools_dir().join("metfrag");
    std::fs::create_dir_all(&metfrag_dir).map_err(|error| error.to_string())?;
    let jar = metfrag_dir.join(METFRAG_JAR_NAME);
    if jar.is_file() {
        return Ok(jar);
    }
    let tmp = metfrag_dir.join(format!("{METFRAG_JAR_NAME}.download"));
    let _ = std::fs::remove_file(&tmp);
    run(Command::new("curl")
        .args(["-L", "--fail", "--silent", "--show-error", "-o"])
        .arg(&tmp)
        .arg(METFRAG_JAR_URL))?;
    std::fs::rename(&tmp, &jar).map_err(|error| error.to_string())?;
    Ok(jar)
}

/// Downloads and extracts the Temurin JDK 21 archive into `<tools>/java/`.
pub fn install_java() -> Result<PathBuf, String> {
    if let Some(java) = resolve_java() {
        return Ok(java);
    }
    let java_root = tools_dir().join("java");
    std::fs::create_dir_all(&java_root).map_err(|error| error.to_string())?;
    let (os, arch) = if cfg!(windows) {
        ("windows", "x64")
    } else if cfg!(target_os = "macos") {
        ("mac", "x64")
    } else {
        ("linux", "x64")
    };
    let url = JAVA_JDK_URL_TEMPLATE.replace("{os}", os).replace("{arch}", arch);
    let archive = java_root.join(if cfg!(windows) { "temurin21.zip" } else { "temurin21.tar.gz" });
    let _ = std::fs::remove_file(&archive);
    run(Command::new("curl")
        .args(["-L", "--fail", "--silent", "--show-error", "-o"])
        .arg(&archive)
        .arg(&url))?;
    run(Command::new("tar").arg("-xf").arg(&archive).arg("-C").arg(&java_root))?;
    let _ = std::fs::remove_file(&archive);
    resolve_java().ok_or_else(|| "JDK extracted but no jdk-* java executable found".to_owned())
}

/// Installs whatever is missing (optional Java first, then MetFrag).
pub fn install_metfrag_stack() -> Result<(PathBuf, PathBuf), String> {
    let java = install_java()?;
    let jar = install_metfrag()?;
    Ok((java, jar))
}
