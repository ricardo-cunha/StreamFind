#include <filesystem>
#include <iostream>
#include <exception>

#include "streamfind/mass_spec/register.hpp"
#include "streamfind/project.hpp"
#include "streamfind/raman/register.hpp"
#include "streamfind/sensors/register.hpp"

int run_domain_smoke() {
    const auto fail = [](const char *check) {
        std::cerr << "domain smoke failed: " << check << "\n";
        return 1;
    };
    streamfind::MethodRegistry registry;
    streamfind::OperationRegistry operations;
    streamfind::mass_spec::register_operations(operations);
    streamfind::raman::register_methods(registry);
    streamfind::sensors::register_methods(registry);
    if (operations.list("mass_spec").size() != 3) return fail("mass_spec registration");
    if (registry.list("raman").size() != 2) return fail("raman registration");
    if (!operations.find("mass_spec.add_analyses")) return fail("mass_spec.add_analyses registration");
    if (!registry.find("raman.remove_analyses")) return fail("raman.remove_analyses registration");
    if (!registry.list("sensors").empty()) return fail("sensors registration");

    const auto data = std::filesystem::path(STREAMFIND_MASS_SPEC_DATA_ROOT);
    const auto wastewater = data / "wastewater";
    const auto r001 = wastewater / "03_tof_ww_is_pos_o3sw_effluent-r001.mzML";
    const auto r002 = wastewater / "03_tof_ww_is_pos_o3sw_effluent-r002.mzML";
    const auto r003 = wastewater / "03_tof_ww_is_pos_o3sw_effluent-r003.mzML";
    const auto database = std::filesystem::temp_directory_path() / "streamfind-mass-spec-domain-smoke.duckdb";
    std::error_code error;
    std::filesystem::remove(database, error);
    auto project = streamfind::Project::create({database, "mass-spec-smoke", std::nullopt, false, false, "mass_spec"});

    const streamfind::Json analyses = streamfind::Json::array({
        streamfind::Json{{"path", r001.string()}},
        streamfind::Json{{"path", r002.string()}},
        streamfind::Json{{"path", r003.string()}}
    });
    const auto added = project.run_operation("mass_spec.add_analyses", {{"analyses", analyses}}, operations);
    if (added.size() != 3) {
        std::cerr << "add_analyses returned " << added.dump() << "\n";
        return 1;
    }
    const auto initial_info = project.run_operation("mass_spec.get_analyses_info", {}, operations);
    if (initial_info.size() != 3) {
        std::cerr << "initial get_analyses_info returned " << initial_info.dump() << "\n";
        return 1;
    }

    project.run_operation("mass_spec.remove_analyses", {{"analysis_names", streamfind::Json::array({r003.stem().string()})}}, operations);
    const auto remaining_info = project.run_operation("mass_spec.get_analyses_info", {}, operations);
    if (remaining_info.size() != 2) {
        std::cerr << "remaining get_analyses_info returned " << remaining_info.dump() << "\n";
        return 1;
    }
    std::filesystem::remove(database, error);
    return 0;
}

int main() {
    try {
        return run_domain_smoke();
    } catch (const std::exception &exception) {
        std::cerr << "domain smoke exception: " << exception.what() << "\n";
        return 1;
    } catch (...) {
        std::cerr << "domain smoke exception: unknown\n";
        return 1;
    }
}
