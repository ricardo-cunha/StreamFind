#include <cassert>
#include <filesystem>
#include <iostream>
#include <stdexcept>

#include "streamfind/api.hpp"
#include "streamfind/project.hpp"

int run() {
    const streamfind::Json suspect_json = {
        {"columns", {
            {{"name", "name"}, {"type", "string"}, {"values", {"benzene", "toluene"}}},
            {{"name", "mass"}, {"type", "real"}, {"values", {78.046, 92.063}}}
        }}
    };
    const auto suspects = streamfind::Table::from_json(suspect_json);
    if (suspects.row_count() != 2 || suspects.to_json() != suspect_json) {
        std::cerr << "table parameter failed\n";
        return 1;
    }

    streamfind::MethodDefinition definition;
    definition.id = "test.echo";
    definition.name = "Echo";
    definition.domain = "test";
    definition.parameters.definitions.push_back({
        "value", "Echo value", {streamfind::ParameterType::string}, "default", true
    });
    definition.cacheable = true;

    streamfind::MethodRegistry registry;
    registry.register_method(streamfind::Method(
        definition,
        [](streamfind::Project &, const streamfind::Json &parameters) {
            return parameters;
        },
        [](const streamfind::Json &parameters) {
            if (!parameters.at("value").is_string()) {
                throw std::invalid_argument("value must be a string");
            }
        }));
    streamfind::methods().register_method(streamfind::Method(
        definition,
        [](streamfind::Project &, const streamfind::Json &parameters) {
            return parameters;
        },
        [](const streamfind::Json &parameters) {
            if (!parameters.at("value").is_string()) {
                throw std::invalid_argument("value must be a string");
            }
        }));

    const auto path = std::filesystem::temp_directory_path() / "streamfind-core-project-smoke.duckdb";
    std::error_code error;
    std::filesystem::remove(path, error);

    auto project = streamfind::Project::create({path, "smoke", std::nullopt, false, false, "test"});
    project.execute_sql("CREATE TABLE SQL_BOUNDARY (value VARCHAR)");
    project.execute_sql("INSERT INTO SQL_BOUNDARY VALUES ('ok')");
    if (project.query_json("SELECT value FROM SQL_BOUNDARY") != streamfind::Json::array({{{"value", "ok"}}})) {
        std::cerr << "SQL boundary failed\n";
        return 1;
    }
    project.set_metadata({{"owner", "test"}});
    if (project.get_metadata().at("owner") != "test") {
        std::cerr << "metadata getter failed\n";
        return 1;
    }

    streamfind::Workflow workflow;
    workflow.name = "smoke";
    workflow.domain = "test";
    workflow.steps.push_back({"test.echo", streamfind::ParameterValues{streamfind::Json{{"value", "hello"}}}});
    project.set_workflow(workflow);

    const auto first = project.run_workflow(registry).results;
    if (first.size() != 1 || first[0]["value"] != "hello" || project.get_cache().size() != 1) {
        std::cerr << "first execution failed\n";
        return 1;
    }

    const auto second = project.run_workflow(registry).results;
    if (second != first || project.get_audit_trail().size() < 3) {
        std::cerr << "cached execution failed\n";
        return 1;
    }

    project.delete_cache();
    if (!project.get_cache().empty()) {
        std::cerr << "cache clear failed\n";
        return 1;
    }
    const auto described = streamfind::api::run(
        streamfind::api::ProjectCommand::describe,
        {{"database_path", path.string()}, {"project_id", "smoke"}});
    if (described.at("row_count") != 1 || described.at("columns").at("project_id").at(0) != "smoke") {
        std::cerr << "project API failed\n";
        return 1;
    }
    const auto metadata = streamfind::api::run(
        streamfind::api::ProjectCommand::get_metadata,
        {{"database_path", path.string()}, {"project_id", "smoke"}});
    if (streamfind::Json::parse(metadata.at("columns").at("metadata").at(0).get<std::string>()).at("owner") != "test") {
        std::cerr << "metadata API failed\n";
        return 1;
    }
    if (streamfind::api::run(streamfind::api::ProjectCommand::validate,
                             {{"database_path", path.string()}, {"project_id", "smoke"}}).at("valid") != true ||
        streamfind::api::run(streamfind::api::ProjectCommand::get_cache_size,
                             {{"database_path", path.string()}, {"project_id", "smoke"}}) != 0) {
        std::cerr << "project validation API failed\n";
        return 1;
    }
    const auto copy_path = std::filesystem::temp_directory_path() / "streamfind-core-project-copy.duckdb";
    std::filesystem::remove(copy_path, error);
    auto copied = project.copy({copy_path, "copied", std::nullopt, false, false});
    if (copied.get_project_id() != "copied" || copied.get_metadata().at("owner") != "test") {
        std::cerr << "project copy failed\n";
        return 1;
    }
    copied.close();
    std::filesystem::remove(copy_path, error);
    project.close();
    std::filesystem::remove(path, error);
    return 0;
}

int main() {
    try {
        return run();
    } catch (const std::exception &error) {
        std::cerr << error.what() << '\n';
        return 1;
    }
}
