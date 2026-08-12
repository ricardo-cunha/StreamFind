#include <iostream>
#include <string>
#include "streamfind/mcp.hpp"

int main() {
    std::string line;
    streamfind::mcp::Session session;
    while (std::getline(std::cin, line)) {
        try { std::cout << session.handle(streamfind::Json::parse(line)).dump() << '\n' << std::flush; }
        catch (const std::exception &error) { std::cout << streamfind::Json{{"jsonrpc", "2.0"}, {"error", {{"code", -32700}, {"message", error.what()}}}}.dump() << '\n' << std::flush; }
    }
}
