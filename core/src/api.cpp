/**
 * @file api.cpp
 * @brief JSON command facade over the streamfind Project API.
 */

#include "streamfind/api.hpp"

#include <algorithm>
#include <stdexcept>
#include <utility>

namespace streamfind::api {
namespace detail {

ProjectOptions options_from_request(const Json &request, bool read_only = false) {
    if (!request.is_object() || !request.contains("database_path") || !request.contains("project_id")) {
        throw Error(ErrorCode::InvalidArgument, "Request requires database_path and project_id");
    }
    ProjectOptions options;
    options.database_path = request.at("database_path").get<std::string>();
    options.project_id = request.at("project_id").get<std::string>();
    options.domain = request.value("domain", "");
    options.read_only = read_only;
    return options;
}

Json descriptor(const Project &project) {
    const auto &info = project.info();
    return {
        {"id", info.id},
        {"database_path", project.get_database_path().string()},
        {"domain", info.domain},
        {"metadata", info.metadata},
        {"schema_version", info.schema_version},
        {"framework_version", info.framework_version},
        {"created_at", info.created_at},
        {"workflow", project.get_workflow().to_json()},
        {"tables", project.list_tables()},
        {"cache_size", project.get_cache_size()}
    };
}

Json cache_entries(const Project &project) {
    Json output = Json::array();
    for (const auto &entry : project.get_cache()) {
        output.push_back({{"name", entry.name}, {"description", entry.description},
                          {"hash", entry.hash}, {"created_at", entry.created_at},
                          {"size", entry.data.size()}});
    }
    return output;
}

Json audit_entries(const Project &project) {
    Json output = Json::array();
    for (const auto &entry : project.get_audit_trail()) {
        output.push_back({{"operation_type", entry.operation_type},
                          {"object_type", entry.object_type},
                          {"details", entry.details}, {"created_at", entry.created_at}});
    }
    return output;
}

Json method_entries(const MethodRegistry &registry, const std::string &domain) {
    Json output = Json::array();
    for (const auto &definition : registry.list(domain)) {
        if (const auto *method = registry.find(definition.id)) output.push_back(method->to_json());
    }
    return output;
}

} // namespace detail

ProjectCommand command_from_string(std::string_view name) {
    if (name == "create") return ProjectCommand::create;
    if (name == "describe") return ProjectCommand::describe;
    if (name == "get_workflow") return ProjectCommand::get_workflow;
    if (name == "set_workflow") return ProjectCommand::set_workflow;
    if (name == "validate_workflow") return ProjectCommand::validate_workflow;
    if (name == "validate") return ProjectCommand::validate;
    if (name == "get_domain") return ProjectCommand::get_domain;
    if (name == "get_available_methods") return ProjectCommand::get_available_methods;
    if (name == "run_method") return ProjectCommand::run_method;
    if (name == "copy") return ProjectCommand::copy;
    if (name == "run_workflow") return ProjectCommand::run_workflow;
    if (name == "get_metadata") return ProjectCommand::get_metadata;
    if (name == "set_metadata") return ProjectCommand::set_metadata;
    if (name == "get_cache") return ProjectCommand::get_cache;
    if (name == "delete_cache") return ProjectCommand::delete_cache;
    if (name == "get_cache_size") return ProjectCommand::get_cache_size;
    if (name == "get_audit_trail") return ProjectCommand::get_audit_trail;
    if (name == "close") return ProjectCommand::close;
    throw Error(ErrorCode::InvalidArgument, "Unknown Project command: " + std::string(name));
}

Json run(ProjectCommand command, const Json &request, const MethodRegistry &registry) {
    switch (command) {
    case ProjectCommand::create: {
        auto options = detail::options_from_request(request);
        auto project = Project::create(options);
        if (request.contains("metadata")) project.set_metadata(request.at("metadata"));
        return detail::descriptor(project);
    }
    case ProjectCommand::describe:
        return detail::descriptor(Project::open(detail::options_from_request(request, true)));
    case ProjectCommand::get_workflow: {
        auto project = Project::open(detail::options_from_request(request, true));
        return project.get_workflow().to_json();
    }
    case ProjectCommand::validate_workflow: {
        if (!request.contains("workflow")) throw Error(ErrorCode::InvalidArgument, "Request requires workflow");
        const auto workflow = Workflow::from_json(request.at("workflow"));
        workflow.validate(registry);
        return {{"valid", true}, {"workflow", workflow.to_json()}};
    }
    case ProjectCommand::validate: {
        auto project = Project::open(detail::options_from_request(request, true));
        project.validate();
        return {{"valid", true}};
    }
    case ProjectCommand::get_domain:
        return Project::open(detail::options_from_request(request, true)).get_domain();
    case ProjectCommand::get_available_methods:
        return detail::method_entries(registry, request.value("domain", ""));
    case ProjectCommand::run_method: {
        if (!request.contains("method")) throw Error(ErrorCode::InvalidArgument, "Request requires method");
        auto project = Project::open(detail::options_from_request(request));
        return project.run_method(request.at("method").get<std::string>(), request.value("parameters", Json::object()), registry);
    }
    case ProjectCommand::copy: {
        if (!request.contains("destination_database_path") || !request.contains("destination_project_id")) {
            throw Error(ErrorCode::InvalidArgument, "Request requires destination_database_path and destination_project_id");
        }
        auto source = Project::open(detail::options_from_request(request, true));
        ProjectOptions destination_options;
        destination_options.database_path = request.at("destination_database_path").get<std::string>();
        destination_options.project_id = request.at("destination_project_id").get<std::string>();
        auto destination = source.copy(destination_options);
        return detail::descriptor(destination);
    }
    case ProjectCommand::set_workflow: {
        if (!request.contains("workflow")) throw Error(ErrorCode::InvalidArgument, "Request requires workflow");
        auto project = Project::open(detail::options_from_request(request));
        auto workflow = Workflow::from_json(request.at("workflow"));
        workflow.validate(registry);
        project.set_workflow(std::move(workflow), registry);
        return project.get_workflow().to_json();
    }
    case ProjectCommand::run_workflow: {
        auto project = Project::open(detail::options_from_request(request));
        return {{"result", project.run_workflow(registry).to_json()}, {"workflow", project.get_workflow().to_json()}};
    }
    case ProjectCommand::get_metadata:
        return Project::open(detail::options_from_request(request, true)).get_metadata();
    case ProjectCommand::set_metadata: {
        if (!request.contains("metadata")) throw Error(ErrorCode::InvalidArgument, "Request requires metadata");
        auto project = Project::open(detail::options_from_request(request));
        project.set_metadata(request.at("metadata"));
        return project.get_metadata();
    }
    case ProjectCommand::get_cache:
        return detail::cache_entries(Project::open(detail::options_from_request(request, true)));
    case ProjectCommand::delete_cache: {
        auto project = Project::open(detail::options_from_request(request));
        project.delete_cache();
        return Json{{"deleted", true}};
    }
    case ProjectCommand::get_cache_size:
        return Project::open(detail::options_from_request(request, true)).get_cache_size();
    case ProjectCommand::get_audit_trail:
        return detail::audit_entries(Project::open(detail::options_from_request(request, true)));
    case ProjectCommand::close: {
        auto project = Project::open(detail::options_from_request(request, true));
        project.close();
        return Json{{"closed", true}};
    }
    }
    throw Error(ErrorCode::InvalidArgument, "Unsupported Project command");
}

} // namespace streamfind::api
