#pragma once

#include "streamfind/export.hpp"
#include "streamfind/project.hpp"

namespace streamfind::mcp {

class STREAMFIND_CORE_API Session {
public:
    explicit Session(const MethodRegistry &registry = methods());
    Json handle(const Json &request);

private:
    const MethodRegistry &registry_;
    Json project_{Json::object()};
    std::string domain_;
};

/** @brief Handle one MCP JSON-RPC request. */
STREAMFIND_CORE_API Json handle(const Json &request,
                                const MethodRegistry &registry = methods());

}
