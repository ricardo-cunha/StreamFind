#include <cassert>
#include <filesystem>
#include <fstream>
#include <iterator>

#include "streamfind/project.hpp"
#include "../tmp_projects.hpp"

namespace streamfind::conformance {

Json fixture() {
    std::ifstream input(STREAMFIND_CONFORMANCE_FIXTURE);
    return Json::parse(std::string(std::istreambuf_iterator<char>(input), {}));
}

std::filesystem::path temporary_database(const char *name) {
    auto path = streamfind::test::tmp_projects_dir() / name;
    std::error_code error;
    std::filesystem::remove(path, error);
    return path;
}

void assert_project(const Project &project, const Json &expected) {
    assert(project.get_project_id() == expected.at("project_id").get<std::string>());
    assert(project.get_domain() == expected.at("domain").get<std::string>());
    assert(project.get_metadata() == expected.at("metadata"));
    assert(project.get_workflow().to_json() == expected.at("workflow"));
    assert(project.get_cache_size() == 1);
    assert(project.get_cache().front().hash == expected.at("cache").at("hash").get<std::string>());
}

void run() {
    const Json expected = fixture();
    const auto path = temporary_database("streamfind-cpp-conformance.duckdb");
    auto project = Project::create({path, expected.at("project_id"), std::nullopt, false, false, expected.at("domain")});
    project.set_metadata(expected.at("metadata"));
    project.set_workflow(Workflow::from_json(expected.at("workflow")));
    project.set_cache(expected.at("cache").at("name"), expected.at("cache").at("description"),
                      expected.at("cache").at("hash"), expected.at("cache").at("value"));
    assert_project(project, expected);
    project.validate();
    project.close();

    auto reopened = Project::open({path, expected.at("project_id"), std::nullopt, false, true, {}});
    assert_project(reopened, expected);
    reopened.validate();
    reopened.close();
    std::error_code error;
    std::filesystem::remove(path, error);
}

} // namespace streamfind::conformance

int main() {
    streamfind::conformance::run();
    return 0;
}
