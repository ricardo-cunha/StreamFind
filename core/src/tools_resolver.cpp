// User-scoped external tool provisioning mirroring `bindings/r`:
// `~/.streamfind/tools/{java/jdk-*,metfrag/MetFragCL.jar}`.
#include "streamfind/external/tools_resolver.hpp"

#include <algorithm>
#include <cstdlib>
#include <filesystem>
#include <sstream>
#include <stdexcept>

namespace fs = std::filesystem;

namespace streamfind::tools {

namespace {

constexpr const char* kJdkUrlTemplate =
    "https://api.adoptium.net/v3/binary/latest/21/ga/{os}/{arch}/jdk/hotspot/normal/eclipse";
constexpr const char* kMetfragJarUrl =
    "https://github.com/ipb-halle/MetFragRelaunched/releases/download/v2.6.11/MetFragCommandLine-2.6.11.jar";

std::string executable_name(const char* name) {
#ifdef _WIN32
    return std::string(name) + ".exe";
#else
    return name;
#endif
}

bool run_command(const std::string& command) {
    return std::system(command.c_str()) == 0;
}

std::optional<std::string> find_on_path(const std::string& name) {
    const char* raw_path = std::getenv("PATH");
    if (!raw_path) return std::nullopt;
#ifdef _WIN32
    constexpr char kSep = ';';
#else
    constexpr char kSep = ':';
#endif
    std::istringstream stream(raw_path);
    std::string directory;
    while (std::getline(stream, directory, kSep)) {
        if (directory.empty()) continue;
        auto candidate = fs::path(directory) / name;
        if (fs::is_regular_file(candidate)) return candidate.string();
    }
    return std::nullopt;
}

} // namespace

std::string streamfind_home() {
    if (const char* home = std::getenv("STREAMFIND_HOME"); home && *home) return home;
    const char* base = std::getenv("USERPROFILE");
    if (!base) base = std::getenv("HOME");
    if (!base || !*base) base = ".";
    return (fs::path(base) / ".streamfind").string();
}

std::string tools_dir() { return (fs::path(streamfind_home()) / "tools").string(); }

std::optional<std::string> resolve_java() {
    if (auto java = find_on_path(executable_name("java"))) return java;
    if (const char* java_home = std::getenv("JAVA_HOME"); java_home && *java_home) {
        auto candidate = fs::path(java_home) / "bin" / executable_name("java");
        if (fs::is_regular_file(candidate)) return candidate.string();
    }
    auto java_root = fs::path(tools_dir()) / "java";
    if (!fs::is_directory(java_root)) return std::nullopt;
    std::vector<fs::path> jdks;
    for (const auto& entry : fs::directory_iterator(java_root))
        if (entry.is_directory() && entry.path().filename().string().rfind("jdk", 0) == 0)
            jdks.push_back(entry.path());
    std::sort(jdks.begin(), jdks.end());
    for (const auto& jdk : jdks) {
        auto candidate = jdk / "bin" / executable_name("java");
        if (fs::is_regular_file(candidate)) return candidate.string();
    }
    return std::nullopt;
}

std::optional<std::string> resolve_metfrag_jar() {
    auto jar = fs::path(tools_dir()) / "metfrag" / "MetFragCL.jar";
    if (fs::is_regular_file(jar)) return jar.string();
    return std::nullopt;
}

std::optional<std::pair<std::string, std::string>> resolve_metfrag() {
    auto java = resolve_java();
    auto jar = resolve_metfrag_jar();
    if (java && jar) return std::pair{*java, *jar};
    return std::nullopt;
}

std::string install_metfrag() {
    auto metfrag_dir = fs::path(tools_dir()) / "metfrag";
    fs::create_directories(metfrag_dir);
    auto jar = metfrag_dir / "MetFragCL.jar";
    if (fs::is_regular_file(jar)) return jar.string();
    if (!run_command("curl -L --fail --silent --show-error -o \"" + jar.string() +
                     "\" \"" + kMetfragJarUrl + "\""))
        throw std::runtime_error("MetFragCL.jar download failed (curl)");
    return jar.string();
}

std::string install_java() {
    if (auto java = resolve_java()) return *java;
    auto java_root = fs::path(tools_dir()) / "java";
    fs::create_directories(java_root);
    const auto [os, arch] =
#ifdef _WIN32
        std::pair{"windows", "x64"};
#elif defined(__APPLE__)
        std::pair{"mac", "x64"};
#else
        std::pair{"linux", "x64"};
#endif
    std::string url = kJdkUrlTemplate;
    url.replace(url.find("{os}"), 4, os);
    url.replace(url.find("{arch}"), 6, arch);
    auto archive = java_root / ("temurin21." + std::string(
#ifdef _WIN32
        "zip"
#else
        "tar.gz"
#endif
    ));
    if (!run_command("curl -L --fail --silent --show-error -o \"" + archive.string() +
                     "\" \"" + url + "\""))
        throw std::runtime_error("Temurin JDK download failed (curl)");
    if (!run_command("tar -xf \"" + archive.string() + "\" -C \"" + java_root.string() + "\""))
        throw std::runtime_error("Temurin JDK extraction failed (tar)");
    fs::remove(archive);
    if (auto java = resolve_java()) return *java;
    throw std::runtime_error("JDK extracted but no jdk-* java executable found");
}

std::string tool_status() {
    std::ostringstream out;
    out << "home: " << streamfind_home() << "\n";
    if (auto java = resolve_java())
        out << "java: " << *java << "\n";
    else
        out << "java: not found\n";
    if (auto jar = resolve_metfrag_jar())
        out << "metfrag: " << *jar << "\n";
    else
        out << "metfrag: not found\n";
    return out.str();
}

} // namespace streamfind::tools