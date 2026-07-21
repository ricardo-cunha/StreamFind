use duckdb::Connection;
use std::path::PathBuf;
use std::process::Command;

#[test]
fn duckdb_executes_query() {
    let connection = Connection::open_in_memory().unwrap();
    let value: i32 = connection
        .query_row("SELECT 42", [], |row| row.get(0))
        .unwrap();
    assert_eq!(value, 42);
}

#[test]
#[ignore = "requires the OpenBabel CLI under ~/.streamfind/tools/openbabel"]
fn openbabel_cli_parses_benzene() {
    let binary = std::env::var_os("OPENBABEL_BIN")
        .map(PathBuf::from)
        .or_else(|| {
            let root = std::env::var_os("USERPROFILE")
                .map(PathBuf::from)?
                .join(".streamfind/tools/openbabel");
            [root.join("obabel.exe"), root.join("bin/obabel.exe")]
                .into_iter()
                .find(|path| path.is_file())
        })
        .expect("set OPENBABEL_BIN or install OpenBabel under ~/.streamfind/tools/openbabel");

    let output = Command::new(binary)
        .args(["-:c1ccccc1", "-osmi"])
        .output()
        .expect("failed to run OpenBabel");
    assert!(
        output.status.success(),
        "OpenBabel failed: {}",
        String::from_utf8_lossy(&output.stderr)
    );
    assert!(String::from_utf8_lossy(&output.stdout).contains("c1ccccc1"));
}
