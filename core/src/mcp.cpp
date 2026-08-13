#include "streamfind/mcp.hpp"
#include "streamfind/api.hpp"
#include "streamfind/generated_metadata.hpp"
#include <algorithm>
#include <array>

namespace streamfind::mcp {

const OperationRegistry &operations() {
    static const OperationRegistry registry;
    return registry;
}

namespace detail {
Json tool(const char *name, const char *description, Json properties, Json required) {
    return {{"name", name}, {"description", description},
            {"inputSchema", {{"type", "object"}, {"properties", properties}, {"required", required}}}};
}

Json tools() {
    return Json::parse(generated::tools);
}

const char *command(const std::string &name) {
    static const std::array<std::string, 18> commands = {
        "create", "describe", "validate", "get_domain", "get_metadata",
        "set_metadata", "get_workflow", "set_workflow", "validate_workflow",
        "run_workflow", "get_cache", "get_cache_size", "delete_cache",
        "get_audit_trail", "get_available_methods", "run_method", "copy", "close"
    };
    return std::find(commands.begin(), commands.end(), name) == commands.end() ? nullptr : name.c_str();
}
}

Session::Session(const MethodRegistry &registry, const OperationRegistry &operations) : registry_(registry), operations_(operations) {}

Json Session::handle(const Json &request) {
    const auto id = request.value("id", Json(nullptr));
    const auto method = request.value("method", "");
    if (method == "initialize") return {{"jsonrpc", "2.0"}, {"id", id}, {"result", {{"protocolVersion", "2025-03-26"}, {"capabilities", {{"tools", Json::object()}}}, {"serverInfo", {{"name", "streamfind-cpp"}, {"version", "0.1.0"}}}}}};
    if (method == "tools/list") {
        auto catalogue = detail::tools();
        for (const auto &definition : registry_.list(domain_)) {
            if (domain_.empty()) break;
            Json properties = Json::object();
            std::vector<std::string> required;
            for (const auto &parameter : definition.parameters.definitions) {
                properties[parameter.name] = parameter.type.to_json();
                if (parameter.required && parameter.default_value.is_null()) required.push_back(parameter.name);
            }
            catalogue.push_back(detail::tool(definition.id.c_str(), definition.description.c_str(), properties, required));
        }
        for (const auto &definition : operations_.list(domain_)) {
            if (domain_.empty()) break;
            Json properties = Json::object();
            std::vector<std::string> required;
            for (const auto &parameter : definition.parameters.definitions) {
                properties[parameter.name] = parameter.type.to_json();
                if (parameter.required && parameter.default_value.is_null()) required.push_back(parameter.name);
            }
            catalogue.push_back(detail::tool(definition.id.c_str(), definition.description.c_str(), properties, required));
        }
        return {{"jsonrpc", "2.0"}, {"id", id}, {"result", {{"tools", catalogue}}}};
    }
    if (method != "tools/call") return {{"jsonrpc", "2.0"}, {"id", id}, {"error", {{"code", -32601}, {"message", "Unsupported MCP method"}}}};
    const auto name = request.at("params").value("name", "");
    if (name == "connect") {
        try {
            const auto arguments = request.at("params").value("arguments", Json::object());
            const auto domain = api::run(api::ProjectCommand::get_domain, arguments, registry_).get<std::string>();
            domain_ = domain;
            project_ = arguments;
            return {{"jsonrpc", "2.0"}, {"id", id}, {"result", {{"content", Json::array({{{"type", "text"}, {"text", Json{{{"domain", domain_}}}.dump()}}})}}}};
        } catch (const Error &error) {
            return {{"jsonrpc", "2.0"}, {"id", id}, {"result", {{"isError", true}, {"content", Json::array({{{"type", "text"}, {"text", error.what()}}})}}}};
        }
    }
    const auto command = detail::command(name);
    const auto dynamic = registry_.find(name);
    const auto operation = operations_.find(name);
    if (!command && operation && !domain_.empty() && operation->definition().domain == domain_) {
        if (project_.empty()) return {{"jsonrpc", "2.0"}, {"id", id}, {"error", {{"code", -32000}, {"message", "No project connected"}}}};
        const auto arguments = request.at("params").value("arguments", Json::object());
        try {
            ProjectOptions options{project_.at("database_path").get<std::string>(), project_.at("project_id").get<std::string>(), {}, false, true, domain_};
            auto project = Project::open(options);
            const Json result = project.run_operation(name, arguments, operations_);
            return {{"jsonrpc", "2.0"}, {"id", id}, {"result", {{"content", Json::array({{{"type", "text"}, {"text", result.dump()}}})}}}};
        } catch (const Error &error) { return {{"jsonrpc", "2.0"}, {"id", id}, {"result", {{"isError", true}, {"content", Json::array({{{"type", "text"}, {"text", error.what()}}})}}}}; }
    }
    if (!command && dynamic && !domain_.empty() && dynamic->definition().domain == domain_) {
        if (project_.empty()) return {{"jsonrpc", "2.0"}, {"id", id}, {"error", {{"code", -32000}, {"message", "No project connected"}}}};
        Json arguments = project_;
        arguments["method"] = name;
        arguments["parameters"] = request.at("params").value("arguments", Json::object());
        try {
            const Json result = api::run(api::ProjectCommand::run_method, arguments, registry_);
            return {{"jsonrpc", "2.0"}, {"id", id}, {"result", {{"content", Json::array({{{"type", "text"}, {"text", result.dump()}}})}}}};
        } catch (const Error &error) {
            return {{"jsonrpc", "2.0"}, {"id", id}, {"result", {{"isError", true}, {"content", Json::array({{{"type", "text"}, {"text", error.what()}}})}}}};
        }
    }
    if (!command) return {{"jsonrpc", "2.0"}, {"id", id}, {"error", {{"code", -32602}, {"message", "Unknown MCP tool"}}}};
    try {
        const Json result = api::run(api::command_from_string(command), request.at("params").value("arguments", Json::object()), registry_);
        if (name == "close") {
            project_ = Json::object();
            domain_.clear();
        }
        return {{"jsonrpc", "2.0"}, {"id", id}, {"result", {{"content", Json::array({{{"type", "text"}, {"text", result.dump()}}})}}}};
    } catch (const Error &error) {
        return {{"jsonrpc", "2.0"}, {"id", id}, {"result", {{"isError", true}, {"content", Json::array({{{"type", "text"}, {"text", error.what()}}})}}}};
    }
}

Json handle(const Json &request, const MethodRegistry &registry) {
    return Session(registry).handle(request);
}
}
