#include <cassert>
#include <filesystem>
#include <iostream>
#include <stdexcept>

#include "streamfind/api.hpp"
#include "streamfind/project.hpp"
#include "../tmp_projects.hpp"

int run() {
    const auto path = streamfind::test::tmp_projects_dir() / "streamfind-core-project-smoke.duckdb";
    std::error_code error;
    std::filesystem::remove(path, error);

    auto project = streamfind::Project::create({path, "smoke", std::nullopt, false, false, "test"});
    int table_runs = 0;
    streamfind::MethodRegistry registry;
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
    project.set_metadata({{"owner", "test"}});
    if (project.get_metadata().at("owner") != "test") {
        std::cerr << "metadata getter failed\n";
        return 1;
    }
    project.set_cache("test", "test cache", "hash", {{"value", 42}});
    if (project.get_cache().size() != 1) {
        std::cerr << "cache creation failed\n";
        return 1;
    }
    project.delete_cache();
    if (!project.get_cache().empty()) {
        std::cerr << "cache clear failed\n";
        return 1;
    }
    const auto copy_path = streamfind::test::tmp_projects_dir() / "streamfind-core-project-copy.duckdb";
    std::filesystem::remove(copy_path, error);
    auto copied = project.copy({copy_path, "copied", std::nullopt, false, false});
    if (copied.get_project_id() != "copied" || copied.get_metadata().at("owner") != "test") {
        std::cerr << "project copy failed\n";
        return 1;
    }
    copied.close();
    std::filesystem::remove(copy_path, error);
    streamfind::Workflow table_workflow;
    table_workflow.domain = "test";
    table_workflow.steps.push_back({"test.table", streamfind::ParameterValues{streamfind::Json::object()}});
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
    project.delete_cache();
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
    project.close();
    auto reopened = streamfind::Project::open({path, "smoke", std::nullopt, false, true, {}});
    if (reopened.get_project_id() != "smoke" ||
        reopened.get_domain() != "test" ||
        reopened.get_metadata().at("owner") != "test") {
        std::cerr << "project reopen failed\n";
        return 1;
    }
    reopened.validate();
    reopened.close();
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
