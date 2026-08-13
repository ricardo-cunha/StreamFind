#include "streamfind/raman/register.hpp"

namespace streamfind::raman {

void register_methods(MethodRegistry &registry) {
    for (const auto &id : {"raman.add_analyses", "raman.remove_analyses"}) {
        MethodDefinition definition;
        definition.id = id;
        definition.name = id;
        definition.domain = "raman";
        definition.description = "Placeholder Raman analysis operation";
        const auto parameter = std::string(id).ends_with("remove_analyses") ? "analysis_names" : "analyses";
        definition.parameters.definitions.push_back({parameter, "Analysis file records or names", {ParameterType::array}, nullptr, true});
        registry.register_method(Method(
            definition,
            [](Project &, const Json &) -> Json {
                throw Error(ErrorCode::MethodExecution, "raman analysis operation is not implemented");
            }));
    }
}

}
