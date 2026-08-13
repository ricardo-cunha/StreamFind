#include <algorithm>
#include <cassert>
#include <fstream>
#include <filesystem>
#include <iostream>

#include "streamfind/mcp.hpp"

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
    streamfind::mcp::Session session;
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
    if (session.handle({{"id", 4}, {"method", "tools/list"}}).at("result").at("tools").size() != fixture.at("generic_tools").size()) {
        std::cerr << "connected tools mismatch\n";
        return 1;
    }
    const auto close = session.handle({{"id", 5}, {"method", "tools/call"}, {"params", {
        {"name", "close"}, {"arguments", {{"database_path", path.string()}, {"project_id", "mcp"}}}
    }}});
    if (close.at("result").value("isError", false)) {
        std::cerr << "close failed\n";
        return 1;
    }
    if (session.handle({{"id", 6}, {"method", "tools/list"}}).at("result").at("tools").size() != fixture.at("generic_tools").size()) {
        std::cerr << "closed tools mismatch\n";
        return 1;
    }
    std::filesystem::remove(path, error);
}
