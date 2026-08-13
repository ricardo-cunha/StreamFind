#pragma once

#include "streamfind/project.hpp"
#include "streamfind/mass_spec/reader.hpp"

namespace streamfind::mass_spec {

inline constexpr const char *analyses_table_name = "MASS_SPEC_ANALYSES";
inline constexpr const char *spectra_headers_table_name = "MASS_SPEC_SPECTRA_HEADERS";
inline constexpr const char *chromatograms_headers_table_name = "MASS_SPEC_CHROMATOGRAMS_HEADERS";

class Project {
public:
    explicit Project(streamfind::Project &project);
    void create_schema();
    Json add_analyses(const Json &parameters);
    Json remove_analyses(const Json &parameters);
    Json get_analyses_info(const Json &parameters = Json::object());

private:
    streamfind::Project &project_;
};

void register_methods(MethodRegistry &registry);

}
