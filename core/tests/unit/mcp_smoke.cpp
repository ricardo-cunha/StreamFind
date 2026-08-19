#include <algorithm>
#include <cassert>
#include <fstream>
#include <filesystem>
#include <iostream>

#include "streamfind/mcp.hpp"
#include "streamfind/mass_spec/register.hpp"

#ifndef STREAMFIND_MCP_FIXTURE
#error STREAMFIND_MCP_FIXTURE is required
#endif

int main() {
    std::ifstream input(STREAMFIND_MCP_FIXTURE);
    assert(input);
    const auto fixture = streamfind::Json::parse(input);
    const auto response = streamfind::mcp::handle({{"id", 1}, {"method", "tools/list"}});
    const auto tools = response.at("result").at("tools");
    assert(tools.size() == fixture.at("generic_tools").size());
    for (const auto &expected : fixture.at("generic_tools")) {
        const auto found = std::find_if(tools.begin(), tools.end(), [&](const auto &tool) {
            return tool.at("name") == expected.at("name");
        });
        assert(found != tools.end());
        for (const auto &required : expected.at("required")) {
            assert(std::find(found->at("inputSchema").at("required").begin(),
                             found->at("inputSchema").at("required").end(), required) !=
                   found->at("inputSchema").at("required").end());
        }
    }

    const auto path = std::filesystem::temp_directory_path() / "streamfind-mcp-lifecycle.duckdb";
    std::error_code error;
    std::filesystem::remove(path, error);
    streamfind::MethodRegistry registry;
    streamfind::OperationRegistry operations;
    streamfind::mass_spec::register_operations(operations);
    streamfind::mcp::Session session(registry, operations);
    const auto create = session.handle({{"id", 2}, {"method", "tools/call"}, {"params", {
        {"name", "create"}, {"arguments", {{"database_path", path.string()}, {"project_id", "mcp"}, {"domain", "mass_spec"}}}
    }}});
    if (create.at("result").value("isError", false)) {
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
    if (connected_tools.size() != fixture.at("generic_tools").size() + operations.list("mass_spec").size()) {
        std::cerr << "connected tools mismatch\n";
        return 1;
    }
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
    if (session.handle({{"id", 7}, {"method", "tools/list"}}).at("result").at("tools").size() !=
        fixture.at("generic_tools").size() + operations.list("mass_spec").size()) {
        std::cerr << "closed tools mismatch\n";
        return 1;
    }
    std::filesystem::remove(path, error);
}
