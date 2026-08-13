#include "streamfind/mass_spec/register.hpp"
#include "streamfind/mass_spec/mass_spec.hpp"
#include <stdexcept>

namespace streamfind::mass_spec {

void register_methods(MethodRegistry &registry) {
    (void)registry;
}

void register_operations(OperationRegistry &registry) {
    for (const auto &id : {"mass_spec.add_analyses", "mass_spec.remove_analyses", "mass_spec.get_analyses_info"}) {
        OperationDefinition definition;
        definition.id = id;
        definition.name = id;
        definition.domain = "mass_spec";
        definition.description = "Mass spectrometry project operation";
        if (!std::string(id).ends_with("get_analyses_info")) {
            const auto parameter = std::string(id).ends_with("remove_analyses") ? "analysis_names" : "analyses";
            const auto item_type = std::string(id).ends_with("remove_analyses") ? TypeDescriptor{ParameterType::string} : TypeDescriptor{ParameterType::object};
            definition.parameters.definitions.push_back({parameter, "Analysis file records or names", {ParameterType::array, std::make_shared<TypeDescriptor>(item_type)}, nullptr, true});
        }
        registry.register_operation(Operation(std::move(definition), [id](streamfind::Project &project, const Json &parameters) {
            auto domain = mass_spec::Project(project);
            if (std::string(id).ends_with("add_analyses")) return domain.add_analyses(parameters);
            if (std::string(id).ends_with("remove_analyses")) return domain.remove_analyses(parameters);
            return domain.get_analyses_info(parameters);
        }));
    }
}

}
