#include <algorithm>
#include <cassert>
#include <filesystem>
#include <iostream>
#include <string>
#include <vector>

#include "streamfind/catalogue.hpp"
#include "streamfind/mcp.hpp"
#include "streamfind/mass_spec/register.hpp"
#include "../tmp_projects.hpp"

#ifndef STREAMFIND_CATALOGUE_PATH
#error STREAMFIND_CATALOGUE_PATH is required
#endif

namespace {

/// Core tool names `tools/list` must advertise, derived from the committed
/// semantic catalogue (the same file the MCP servers serve from): exposed
/// operations of the `streamfind` domain. Tests adapt automatically when
/// operations are added or removed — no hardcoded counts.
std::vector<std::string> expected_core_tools(const streamfind::Json &entries) {
    std::vector<std::string> names;
    for (const auto &entry : entries) {
        if (entry.value("kind", "") == "operation" &&
            entry.value("domain", "") == "streamfind" &&
            entry.value("exposed", false)) {
            names.push_back(entry.at("mcp").at("name").get<std::string>());
        }
    }
    std::sort(names.begin(), names.end());
    return names;
}

/// The full expected tool set after connecting to a mass_spec project: core
/// tools + registered mass_spec operations (methods are never tools).
std::vector<std::string> expected_with_mass_spec(const streamfind::Json &entries,
                                                 const streamfind::OperationRegistry &operations) {
    auto names = expected_core_tools(entries);
    for (const auto &definition : operations.list("mass_spec")) {
        names.push_back(definition.id);
    }
    std::sort(names.begin(), names.end());
    return names;
}

/// Assert a tools/list payload advertises exactly the expected tool names.
void assert_advertises(const streamfind::Json &tools, const std::vector<std::string> &expected) {
    std::vector<std::string> actual;
    for (const auto &tool : tools) actual.push_back(tool.at("name").get<std::string>());
    std::sort(actual.begin(), actual.end());
    assert(actual == expected);
    assert(tools.size() == expected.size());
    for (const auto &tool : tools) assert(tool.at("inputSchema").at("type") == "object");
}

}  // namespace

int main() {
    // Load the catalogue explicitly so the test exercises the same artifact the
    // MCP servers query at runtime.
    const auto entries = streamfind::catalogue::load(STREAMFIND_CATALOGUE_PATH);
    assert(entries && "catalogue load failed");
    const auto expected_core = expected_core_tools(*entries);

    const auto response = streamfind::mcp::handle({{"id", 1}, {"method", "tools/list"}});
    const auto tools = response.at("result").at("tools");
    assert_advertises(tools, expected_core);
    // A well-known core tool keeps a behavioural contract check: its required
    // parameters are statically meaningful and change only with that operation.
    const auto create = std::find_if(tools.begin(), tools.end(), [](const auto &tool) {
        return tool.at("name") == "create";
    });
    assert(create != tools.end());
    const auto required = create->at("inputSchema").at("required");
    assert(std::find(required.begin(), required.end(), "database_path") != required.end());
    assert(std::find(required.begin(), required.end(), "project_id") != required.end());

    const auto path = streamfind::test::tmp_projects_dir() / "streamfind-mcp-lifecycle.duckdb";
    std::error_code error;
    std::filesystem::remove(path, error);
    streamfind::MethodRegistry registry;
    streamfind::OperationRegistry operations;
    streamfind::mass_spec::register_operations(operations);
    const auto expected_connected = expected_with_mass_spec(*entries, operations);
    streamfind::mcp::Session session(registry, operations);
    const auto create_call = session.handle({{"id", 2}, {"method", "tools/call"}, {"params", {
        {"name", "create"}, {"arguments", {{"database_path", path.string()}, {"project_id", "mcp"}, {"domain", "mass_spec"}}}
    }}});
    if (create_call.at("result").value("isError", false)) {
        std::cerr << "create failed\n";
        return 1;
    }
    const auto connect = session.handle({{"id", 3}, {"method", "tools/call"}, {"params", {
        {"name", "connect"}, {"arguments", {{"database_path", path.string()}, {"project_id", "mcp"}}}
    }}});
    if (connect.at("result").value("isError", false)) {
        std::cerr << "connect failed\n";
        return 1;
    }
    const auto connected_tools = session.handle({{"id", 4}, {"method", "tools/list"}}).at("result").at("tools");
    assert_advertises(connected_tools, expected_connected);
    const auto eic_tool = std::find_if(connected_tools.begin(), connected_tools.end(), [](const auto &tool) {
        return tool.at("name") == "mass_spec.get_raw_spectra_eic";
    });
    if (eic_tool == connected_tools.end() || eic_tool->at("inputSchema").at("properties").at("targets").at("type") != "array" ||
        eic_tool->at("inputSchema").at("properties").at("targets").at("items").at("type") != "object" ||
        eic_tool->at("inputSchema").at("properties").at("rt_tolerance").at("type") != "number" ||
        eic_tool->at("inputSchema").at("properties").at("targets").at("examples").empty() ||
        eic_tool->at("inputSchema").at("properties").at("targets").at("examples")[0][0].at("id") != "caffeine") {
        std::cerr << "mass-spec target schema mismatch\n";
        return 1;
    }
    const auto info = session.handle({{"id", 5}, {"method", "tools/call"}, {"params", {
        {"name", "mass_spec.get_analyses_info"}, {"arguments", {{"database_path", path.string()}, {"project_id", "mcp"}}}
    }}});
    if (info.at("result").value("isError", false) ||
        streamfind::Json::parse(info.at("result").at("content").at(0).at("text").get<std::string>()).at("row_count") != 0) {
        std::cerr << "mass_spec.get_analyses_info failed\n";
        return 1;
    }
    const auto close = session.handle({{"id", 6}, {"method", "tools/call"}, {"params", {
        {"name", "close"}, {"arguments", {{"database_path", path.string()}, {"project_id", "mcp"}}}
    }}});
    if (close.at("result").value("isError", false)) {
        std::cerr << "close failed\n";
        return 1;
    }
    assert_advertises(session.handle({{"id", 7}, {"method", "tools/list"}}).at("result").at("tools"), expected_core);
    std::filesystem::remove(path, error);
}