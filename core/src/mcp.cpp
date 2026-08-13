#include "streamfind/mcp.hpp"
#include "streamfind/api.hpp"

namespace streamfind::mcp {

namespace detail {
Json tool(const char *name, const char *description, Json properties, Json required) {
    return {{"name", name}, {"description", description},
            {"inputSchema", {{"type", "object"}, {"properties", properties}, {"required", required}}}};
}

Json tools() {
    const Json project = {{"type", "string"}};
    const Json metadata = {{"type", "object"}};
    const Json workflow = {{"type", "object"}};
    return Json::array({
        tool("project_create", "Create a project", {{"database_path", project}, {"project_id", project}, {"domain", project}}, {"database_path", "project_id", "domain"}),
        tool("project_connect", "Connect this MCP session to a project", {{"database_path", project}, {"project_id", project}}, {"database_path", "project_id"}),
        tool("project_describe", "Describe a project", {{"database_path", project}, {"project_id", project}}, {"database_path", "project_id"}),
        tool("project_validate", "Validate a project", {{"database_path", project}, {"project_id", project}}, {"database_path", "project_id"}),
        tool("project_get_domain", "Read the project domain", {{"database_path", project}, {"project_id", project}}, {"database_path", "project_id"}),
        tool("project_get_metadata", "Read project metadata", {{"database_path", project}, {"project_id", project}}, {"database_path", "project_id"}),
        tool("project_set_metadata", "Set project metadata", {{"database_path", project}, {"project_id", project}, {"metadata", metadata}}, {"database_path", "project_id", "metadata"}),
        tool("project_get_workflow", "Read the project workflow", {{"database_path", project}, {"project_id", project}}, {"database_path", "project_id"}),
        tool("project_set_workflow", "Set the project workflow", {{"database_path", project}, {"project_id", project}, {"workflow", workflow}}, {"database_path", "project_id", "workflow"}),
        tool("project_validate_workflow", "Validate a workflow", {{"workflow", workflow}}, {"workflow"}),
        tool("project_run_workflow", "Run the project workflow", {{"database_path", project}, {"project_id", project}}, {"database_path", "project_id"}),
        tool("project_get_cache", "Read project cache", {{"database_path", project}, {"project_id", project}}, {"database_path", "project_id"}),
        tool("project_get_cache_size", "Read project cache size", {{"database_path", project}, {"project_id", project}}, {"database_path", "project_id"}),
        tool("project_delete_cache", "Delete project cache", {{"database_path", project}, {"project_id", project}}, {"database_path", "project_id"}),
        tool("project_get_audit_trail", "Read project audit events", {{"database_path", project}, {"project_id", project}}, {"database_path", "project_id"}),
        tool("get_available_methods", "List methods registered for a domain", {{"domain", { {"type", "string"} }}}, {"domain"}),
        tool("project_run_method", "Append and run a workflow method", {{"database_path", project}, {"project_id", project}, {"method", project}, {"parameters", Json{{"type", "object"}}}}, {"database_path", "project_id", "method"}),
        tool("project_copy", "Copy a project", {{"database_path", project}, {"project_id", project}, {"destination_database_path", project}, {"destination_project_id", project}}, {"database_path", "project_id", "destination_database_path", "destination_project_id"}),
        tool("project_close", "Close a project handle", {{"database_path", project}, {"project_id", project}}, {"database_path", "project_id"}),
    });
}

const char *command(const std::string &name) {
    if (name == "project_create") return "create";
    if (name == "project_describe") return "describe";
    if (name == "project_validate") return "validate";
    if (name == "project_get_domain") return "get_domain";
    if (name == "project_get_metadata") return "get_metadata";
    if (name == "project_set_metadata") return "set_metadata";
    if (name == "project_get_workflow") return "get_workflow";
    if (name == "project_set_workflow") return "set_workflow";
    if (name == "project_validate_workflow") return "validate_workflow";
    if (name == "project_run_workflow") return "run_workflow";
    if (name == "project_get_cache") return "get_cache";
    if (name == "project_get_cache_size") return "get_cache_size";
    if (name == "project_delete_cache") return "delete_cache";
    if (name == "project_get_audit_trail") return "get_audit_trail";
    if (name == "get_available_methods") return "get_available_methods";
    if (name == "project_run_method") return "run_method";
    if (name == "project_copy") return "copy";
    if (name == "project_close") return "close";
    return nullptr;
}
}

Session::Session(const MethodRegistry &registry) : registry_(registry) {}

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
        return {{"jsonrpc", "2.0"}, {"id", id}, {"result", {{"tools", catalogue}}}};
    }
    if (method != "tools/call") return {{"jsonrpc", "2.0"}, {"id", id}, {"error", {{"code", -32601}, {"message", "Unsupported MCP method"}}}};
    const auto name = request.at("params").value("name", "");
    if (name == "project_connect") {
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
        if (name == "project_close") {
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
