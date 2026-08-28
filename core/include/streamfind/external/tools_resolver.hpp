#ifndef streamfind_TOOLS_RESOLVER_H
#define streamfind_TOOLS_RESOLVER_H

#include <optional>
#include <string>

namespace streamfind::tools {

/// `STREAMFIND_HOME` override, else `%USERPROFILE%\.streamfind` / `~/.streamfind`
/// — mirrors `bindings/r/R/fct_external_tools.R`.
std::string streamfind_home();

/// `<home>/tools`.
std::string tools_dir();

/// Locates `java`/`java.exe`: PATH -> `JAVA_HOME/bin` ->
/// `<tools>/java/jdk-*/bin` (R rule: PATH first).
std::optional<std::string> resolve_java();

/// Locates the MetFrag command-line jar: `<tools>/metfrag/MetFragCL.jar`.
std::optional<std::string> resolve_metfrag_jar();

/// `java` + jar when both are installed.
std::optional<std::pair<std::string, std::string>> resolve_metfrag();

/// Installs the Temurin JDK 21 archive into `<tools>/java/` (curl + tar).
/// Returns the resolved java executable, or a std::runtime_error message.
std::string install_java();

/// Downloads `<tools>/metfrag/MetFragCL.jar` (MetFragCommandLine 2.6.11).
std::string install_metfrag();

/// Human-readable tool status (paths or "not found").
std::string tool_status();

} // namespace streamfind::tools

#endif // streamfind_TOOLS_RESOLVER_H