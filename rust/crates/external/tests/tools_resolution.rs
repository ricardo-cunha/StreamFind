//! `~/.streamfind` tool-layout resolution tests (mirrors `bindings/r`).
use streamfind_external::tools::{resolve_java, resolve_metfrag, resolve_metfrag_jar};
use std::sync::Mutex;
use std::{env, fs, path::PathBuf};

/// Tests mutate process environment; serialize them (cargo runs in parallel).
static ENV_LOCK: Mutex<()> = Mutex::new(());
const JAVA_EXECUTABLE: &str = if cfg!(windows) { "java.exe" } else { "java" };

fn fixture_home() -> PathBuf {
    let root = streamfind_rust_test_support::tmp_projects_dir().join("streamfind-tools-fixture");
    let _ = fs::remove_dir_all(&root);
    fs::create_dir_all(root.join("tools/metfrag")).unwrap();
    fs::create_dir_all(root.join("tools/java/jdk-21.0.5/bin")).unwrap();
    fs::write(
        root.join(format!("tools/java/jdk-21.0.5/bin/{JAVA_EXECUTABLE}")),
        b"",
    )
    .unwrap();
    fs::write(root.join("tools/metfrag/MetFragCL.jar"), b"").unwrap();
    root
}

#[test]
fn resolves_streamfind_layout() {
    let _guard = ENV_LOCK.lock().unwrap();
    let root = fixture_home();
    env::set_var("STREAMFIND_HOME", &root);
    env::remove_var("JAVA_HOME");
    // PATH-first rule: neutralize the real PATH so the fixture jdk is used.
    env::set_var("PATH", "");
    let java = resolve_java().expect("fixture java");
    env::remove_var("PATH");
    assert!(
        java.ends_with(&format!("jdk-21.0.5/bin/{JAVA_EXECUTABLE}")),
        "{java:?}"
    );
    let jar = resolve_metfrag_jar().expect("fixture jar");
    assert!(jar.ends_with("metfrag/MetFragCL.jar"), "{jar:?}");
    assert!(resolve_metfrag().is_some(), "java+jar pair expected");
    env::remove_var("STREAMFIND_HOME");
    let _ = fs::remove_dir_all(&root);
}

#[test]
fn java_home_fallback_is_tried() {
    let _guard = ENV_LOCK.lock().unwrap();
    let root = fixture_home();
    let java_home = root.join("tools/java/jdk-21.0.5");
    env::set_var("JAVA_HOME", &java_home);
    // STREAMFIND_HOME unset: java must still resolve via JAVA_HOME.
    env::remove_var("STREAMFIND_HOME");
    if env::var_os("PATH").is_some_and(|p| {
        p.to_str()
            .unwrap_or("")
            .split(if cfg!(windows) { ';' } else { ':' })
            .any(|d| PathBuf::from(d).join(if cfg!(windows) { "java.exe" } else { "java" }).is_file())
    }) {
        // java on PATH shadows JAVA_HOME by design (R rule: PATH first)
        return;
    }
    let java = resolve_java().expect("JAVA_HOME java");
    assert!(java.ends_with(&format!("bin/{JAVA_EXECUTABLE}")), "{java:?}");
    env::remove_var("JAVA_HOME");
    let _ = fs::remove_dir_all(&root);
}