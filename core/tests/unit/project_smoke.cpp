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

    streamfind::MethodDefinition unavailable;
    unavailable.id = "test.unavailable";
    unavailable.name = "Unavailable";
    unavailable.domain = "test";
    registry.register_method(streamfind::Method(unavailable));

    const auto path = std::filesystem::temp_directory_path() / "streamfind-core-project-smoke.duckdb";
    std::error_code error;
    std::filesystem::remove(path, error);

    auto project = streamfind::Project::create({path, "smoke", std::nullopt, false, false, "test"});
    streamfind::Workflow unavailable_workflow;
    unavailable_workflow.domain = "test";
    unavailable_workflow.steps.push_back({"test.unavailable", {}});
    try {
        project.set_workflow(unavailable_workflow, registry);
        std::cerr << "unimplemented method was accepted into workflow\n";
        return 1;
    } catch (const streamfind::Error &) {
    }
    int table_runs = 0;
    streamfind::MethodDefinition table_method;
    table_method.id = "test.table";
    table_method.name = "Table";
    table_method.domain = "test";
    table_method.cacheable = true;
    table_method.writes = {"TEST_OUTPUT"};
    registry.register_method(streamfind::Method(
        table_method,
        [&table_runs](streamfind::Project &project, const streamfind::Json &) {
            ++table_runs;
            project.execute_sql("CREATE TABLE IF NOT EXISTS TEST_OUTPUT (project_id VARCHAR, value VARCHAR)");
            project.execute_sql("DELETE FROM TEST_OUTPUT WHERE project_id = 'smoke'");
            project.execute_sql("INSERT INTO TEST_OUTPUT VALUES ('smoke', 'materialized')");
            return streamfind::Json{{"status", "finished"}};
        }));
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
    streamfind::Workflow table_workflow;
    table_workflow.domain = "test";
    table_workflow.steps.push_back({"test.table", {}});
    project.set_workflow(table_workflow, registry);
    project.run_workflow(registry);
    project.execute_sql("DELETE FROM TEST_OUTPUT WHERE project_id = 'smoke'");
    project.run_workflow(registry);
    if (table_runs != 1 || project.query_json("SELECT value FROM TEST_OUTPUT WHERE project_id = 'smoke'") != streamfind::Json::array({{{"value", "materialized"}}})) {
        std::cerr << "cache table materialization failed\n";
        return 1;
    }
    const auto execution = project.get_workflow_execution();
    if (execution.at(0).at("status") != "succeeded") {
        std::cerr << "workflow execution tracking failed\n";
        return 1;
    }
    project.set_workflow(workflow, registry);
    project.delete_cache();
    const auto described = streamfind::api::run(
        streamfind::api::ProjectCommand::describe,
        {{"database_path", path.string()}, {"project_id", "smoke"}});
    if (described.at("row_count") != 1 || described.at("columns").at("project_id").at(0) != "smoke") {
        std::cerr << "project API failed\n";
        return 1;
    }
    const auto execution_table = streamfind::api::run(
        streamfind::api::ProjectCommand::get_workflow_execution,
        {{"database_path", path.string()}, {"project_id", "smoke"}});
    if (!execution_table.contains("columns") || execution_table.at("columns").at("step_index").empty()) {
        std::cerr << "workflow execution table API failed\n";
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
