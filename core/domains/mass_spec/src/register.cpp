#include "streamfind/generated_metadata.hpp"
#include "streamfind/mass_spec/mass_spec.hpp"
#include "streamfind/mass_spec/processing_methods_chromatograms.hpp"
#include "streamfind/mass_spec/register.hpp"

namespace streamfind::mass_spec {

namespace detail {

Json columnar(Json rows, const Json &schema) {
    Json columns = Json::object();
    const auto properties = schema.value("properties", Json::object());
    for (auto it = properties.begin(); it != properties.end(); ++it)
        columns[it.key()] = Json::array();
    for (const auto &row : rows) {
        for (auto it = columns.begin(); it != columns.end(); ++it)
            it.value().push_back(row.contains(it.key()) ? row.at(it.key()) : Json(nullptr));
    }
    return {{"row_count", rows.size()}, {"columns", std::move(columns)}};
}

}

void register_methods(MethodRegistry &registry) {
    const auto catalogue = Json::parse(streamfind::mcp::generated::catalogue);
    for (const auto &entry : catalogue.at("entries")) {
        if (entry.value("domain", "") != "mass_spec" || entry.value("kind", "") != "method") continue;
        MethodDefinition definition;
        definition.id = entry.at("canonical_id").get<std::string>();
        definition.name = definition.id;
        definition.description = entry.value("definition", entry.value("label", ""));
        definition.domain = "mass_spec";
        for (const auto &item : entry.value("parameters", Json::array())) {
            ParameterDefinition parameter;
            parameter.name = item.at("name").get<std::string>();
            parameter.description = item.value("definition", "");
            parameter.type = TypeDescriptor::from_json(item.at("schema"));
            parameter.required = item.value("required", false);
            parameter.example = item.value("example", Json(nullptr));
            definition.parameters.definitions.push_back(std::move(parameter));
        }
        registry.register_method(Method(std::move(definition), [id = entry.at("canonical_id").get<std::string>()](streamfind::Project &project, const Json &parameters) {
            if (id == "mass_spec.load_chromatograms") return processing::load_chromatograms(project, parameters);
            return processing::filter_chromatograms_retention_time(project, parameters);
        }));
    }
}

void register_operations(OperationRegistry &registry) {
    const auto catalogue = Json::parse(streamfind::mcp::generated::catalogue);
    for (const auto &entry : catalogue.at("entries")) {
        if (entry.value("domain", "") != "mass_spec" || entry.value("kind", "") != "operation") continue;
        OperationDefinition definition;
        const std::string id = entry.at("canonical_id").get<std::string>();
        const Json result_schema = entry.value("result", Json::object()).value("schema", Json::object());
        definition.id = id;
        definition.name = id;
        definition.domain = "mass_spec";
        definition.description = entry.value("definition", entry.value("label", ""));
        for (const auto &item : entry.value("parameters", Json::array())) {
            ParameterDefinition parameter;
            parameter.name = item.at("name").get<std::string>();
            parameter.description = item.value("description", "");
            parameter.type = TypeDescriptor::from_json(item.at("schema"));
            parameter.default_value = item.value("default", Json(nullptr));
            parameter.required = item.value("required", false);
            parameter.example = item.value("example", Json(nullptr));
            definition.parameters.definitions.push_back(std::move(parameter));
        }
        registry.register_operation(Operation(std::move(definition), [id, result_schema](streamfind::Project &project, const Json &parameters) {
            auto domain = mass_spec::Project(project);
            Json result;
            if (id == "mass_spec.add_analyses") result = domain.add_analyses(parameters);
            else if (id == "mass_spec.remove_analyses") result = domain.remove_analyses(parameters);
            else if (id == "mass_spec.get_analyses_info") result = domain.get_analyses_info(parameters);
            else if (id == "mass_spec.get_analysis_names") result = domain.get_analysis_names(parameters);
            else if (id == "mass_spec.get_replicate_names") result = domain.get_replicate_names(parameters);
            else if (id == "mass_spec.get_blank_names") result = domain.get_blank_names(parameters);
            else if (id == "mass_spec.get_concentrations") result = domain.get_concentrations(parameters);
            else if (id == "mass_spec.set_replicate_names") result = domain.set_replicate_names(parameters);
            else if (id == "mass_spec.set_blank_names") result = domain.set_blank_names(parameters);
            else if (id == "mass_spec.set_concentrations") result = domain.set_concentrations(parameters);
            else if (id == "mass_spec.get_spectra_headers") result = domain.get_spectra_headers(parameters);
            else if (id == "mass_spec.get_chromatograms_headers") result = domain.get_chromatograms_headers(parameters);
            else if (id == "mass_spec.get_spectra_tic") result = domain.get_spectra_tic(parameters);
            else if (id == "mass_spec.get_raw_spectra_eic") result = domain.get_raw_spectra_eic(parameters);
            else if (id == "mass_spec.get_raw_spectra_ms1") result = domain.get_raw_spectra_ms1(parameters);
            else if (id == "mass_spec.get_raw_spectra_ms2") result = domain.get_raw_spectra_ms2(parameters);
            else if (id == "mass_spec.get_raw_spectra") result = domain.get_raw_spectra(parameters);
            else if (id == "mass_spec.get_chromatograms") result = domain.get_chromatograms(parameters);
            else if (id == "mass_spec.get_raw_chromatograms") result = domain.get_raw_chromatograms(parameters);
            else result = domain.get_analyses_info(parameters);
            return result_schema.value("type", "") == "table" ? detail::columnar(std::move(result), result_schema) : result;
        }));
    }
}

}
