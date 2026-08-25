//! Resolution of user-installed external tools, plus `~/.streamfind`-scoped
//! provisioning for Java + MetFragCL (mirrors `bindings/r`).

pub mod tools;

use std::env;
use std::fmt;
use std::path::PathBuf;

#[derive(Debug, Clone, Copy)]
/// An external executable required by a backend.
pub enum Tool {
    OpenBabel,
}

impl Tool {
    fn command(self) -> &'static str {
        match self {
            Self::OpenBabel => "obabel",
        }
    }
}

#[derive(Debug)]
/// Failure to resolve a required external executable.
pub enum Error {
    ToolNotOnPath { command: &'static str },
}

impl fmt::Display for Error {
    fn fmt(&self, output: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::ToolNotOnPath { command } => write!(output, "required external tool '{command}' was not found on PATH; install it and restart the process"),
        }
    }
}

impl std::error::Error for Error {}

pub type Result<T> = std::result::Result<T, Error>;

/// Resolves external tools from the process `PATH`.
pub struct ToolResolver {}

impl ToolResolver {
    /// Creates a resolver without changing the environment or installing tools.
    pub fn new() -> Self {
        Self {}
    }

    /// Returns the executable path for `tool`, or an actionable prerequisite error.
    pub fn resolve(&self, tool: Tool) -> Result<PathBuf> {
        match tool {
            Tool::OpenBabel => self.resolve_openbabel(),
        }
    }

    fn resolve_openbabel(&self) -> Result<PathBuf> {
        find_on_path(Tool::OpenBabel.command()).ok_or(Error::ToolNotOnPath {
            command: Tool::OpenBabel.command(),
        })
    }
}

fn find_on_path(name: &str) -> Option<PathBuf> {
    env::var_os("PATH")?
        .to_str()
        .into_iter()
        .flat_map(env::split_paths)
        .flat_map(|directory| [directory.join(name), directory.join(format!("{name}.exe"))])
        .find(|path| path.is_file())
}
