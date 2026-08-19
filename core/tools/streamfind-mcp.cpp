#include <iostream>
#include <string>
#include "streamfind/mcp.hpp"
#include "streamfind/mass_spec/register.hpp"
#include "streamfind/raman/register.hpp"
#include "streamfind/sensors/register.hpp"

int main() {
    std::string line;
    streamfind::MethodRegistry registry;
    streamfind::OperationRegistry operations;
    streamfind::mass_spec::register_operations(operations);
    streamfind::mass_spec::register_methods(registry);
    streamfind::raman::register_methods(registry);
    streamfind::sensors::register_methods(registry);
    streamfind::mcp::Session session(registry, operations);
    while (std::getline(std::cin, line)) {
        try { std::cout << session.handle(streamfind::Json::parse(line)).dump() << '\n' << std::flush; }
        catch (const std::exception &error) { std::cout << streamfind::Json{{"jsonrpc", "2.0"}, {"error", {{"code", -32700}, {"message", error.what()}}}}.dump() << '\n' << std::flush; }
    }
}
