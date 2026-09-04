#include <algorithm>
#include <iostream>
#include <string>
#include <vector>

#include "streamfind/catalogue.hpp"
#include "streamfind/mass_spec/register.hpp"

#ifndef STREAMFIND_CATALOGUE_PATH
#error STREAMFIND_CATALOGUE_PATH is required
#endif

int main() {
    const auto entries = streamfind::catalogue::load(STREAMFIND_CATALOGUE_PATH);
    if (!entries) {
        std::cerr << "NTA interface: catalogue load failed\n";
        return 1;
    }

    const std::vector<std::string> expected_ids = {
        "mass_spec.find_features",
        "mass_spec.load_features_ms1",
        "mass_spec.load_features_ms2",
        "mass_spec.create_components",
        "mass_spec.annotate_components",
        "mass_spec.group_features",
        "mass_spec.fill_features",
        "mass_spec.subtract_blank",
        "mass_spec.correct_matrix_suppression",
        "mass_spec.filter_features",
        "mass_spec.suspect_screening",
        "mass_spec.find_internal_standards",
        "mass_spec.filter_suspects",
        "mass_spec.filter_internal_standards",
        "mass_spec.filter_features_ms2",
        "mass_spec.metfrag_screening",
        "mass_spec.assign_transformation_products",
    };

    streamfind::MethodRegistry methods;
    streamfind::mass_spec::register_methods(methods);
    for (const auto &id : expected_ids) {
        const auto *definition = methods.find(id);
        if (!definition) {
            std::cerr << "NTA interface: method not registered: " << id << '\n';
            return 1;
        }
        const auto found = std::find_if(entries->begin(), entries->end(), [&](const auto &entry) {
            return entry.value("canonical_id", "") == id;
        });
        if (found == entries->end()) {
            std::cerr << "NTA interface: catalogue entry missing for " << id << '\n';
            return 1;
        }
        if (found->value("kind", "") != "method" || found->value("domain", "") != "mass_spec") {
            std::cerr << "NTA interface: invalid catalogue classification for " << id << '\n';
            return 1;
        }
    }

    const auto expected_count = static_cast<std::size_t>(std::count_if(
        entries->begin(), entries->end(), [](const auto &entry) {
            const auto id = entry.value("canonical_id", "");
            return entry.value("kind", "") == "method" &&
                   entry.value("domain", "") == "mass_spec" &&
                   id.rfind("mass_spec.", 0) == 0;
        }));
    const auto registered = methods.list("mass_spec");
    const auto actual_count = static_cast<std::size_t>(std::count_if(
        registered.begin(), registered.end(), [](const auto &definition) {
            return definition.id.rfind("mass_spec.", 0) == 0;
        }));
    if (actual_count != expected_count) {
        std::cerr << "NTA interface: method count mismatch\n";
        return 1;
    }

    const auto *find_features = methods.find("mass_spec.find_features");
    if (!find_features->definition().cacheable || !find_features->definition().single_occurrence) {
        std::cerr << "NTA interface: find_features lifecycle metadata mismatch\n";
        return 1;
    }
    return 0;
}
