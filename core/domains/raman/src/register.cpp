#include "streamfind/catalogue.hpp"
#include "streamfind/raman/register.hpp"

#include <algorithm>
#include <limits>

namespace streamfind::raman {

void register_methods(MethodRegistry &registry) {
    const auto entries = streamfind::catalogue::entries_json();
    if (!entries) return;
    for (const auto &id : {"raman.add_analyses", "raman.remove_analyses"}) {
        const auto entry = std::find_if(entries->begin(), entries->end(), [id](const auto &value) {
            return value.value("canonical_id", "") == id;
        });
        MethodDefinition definition;
        definition.id = id;
        definition.name = id;
        definition.domain = "raman";
        definition.description = entry == entries->end() ? "Placeholder Raman analysis operation" : entry->value("definition", "");
        if (entry != entries->end()) {
            definition.cacheable = entry->value("cacheable", false);
            definition.writes = entry->value("effects", Json::object()).value("writes", std::vector<std::string>{});
            definition.required_methods = entry->value("required_methods", std::vector<std::string>{});
            definition.single_occurrence = entry->value("single_occurrence", false);
        }
        const auto parameter = std::string(id).ends_with("remove_analyses") ? "analysis_names" : "analyses";
        definition.parameters.definitions.push_back({parameter, "Analysis file records or names", {ParameterType::array}, nullptr, true});
        registry.register_method(Method(std::move(definition)));
    }
}

}
