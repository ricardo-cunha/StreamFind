#include "streamfind/mass_spec/processing_methods_chromatograms.hpp"

#include "streamfind/mass_spec/reader.hpp"

#include <algorithm>
#include <regex>
#include <string>
#include <vector>

namespace streamfind::mass_spec::processing {
namespace detail {

std::string sql(const std::string &value) {
    std::string result = "'";
    for (const char c : value) result += c == '\'' ? "''" : std::string(1, c);
    return result + "'";
}

void ensure_table(streamfind::Project &project) {
    project.execute_sql(
        "CREATE TABLE IF NOT EXISTS MASS_SPEC_CHROMATOGRAMS ("
        "project_id VARCHAR NOT NULL, analysis VARCHAR NOT NULL, "
        "chromatogram_id VARCHAR NOT NULL, rt DOUBLE NOT NULL, "
        "raw_intensity DOUBLE NOT NULL, baseline DOUBLE NOT NULL DEFAULT 0, "
        "intensity DOUBLE NOT NULL, created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, "
        "PRIMARY KEY(project_id, analysis, chromatogram_id, rt))");
}

std::vector<std::pair<std::string, std::string>> analyses(
    streamfind::Project &project, const Json &parameters) {
    const auto rows = project.query_json(
        "SELECT analysis, file_path FROM MASS_SPEC_ANALYSES WHERE project_id = " +
        sql(project.get_project_id()) + " ORDER BY analysis");
    const auto wanted = parameters.value("analysis_names", Json::array());
    std::vector<std::pair<std::string, std::string>> result;
    for (const auto &row : rows) {
        const auto name = row.at("analysis").get<std::string>();
        bool selected = wanted.empty();
        for (const auto &value : wanted)
            selected = selected || value.get<std::string>() == name;
        if (selected) result.emplace_back(name, row.at("file_path").get<std::string>());
    }
    if (result.empty()) throw Error(ErrorCode::InvalidArgument, "No analyses available for chromatogram processing.");
    return result;
}

bool matches(const std::string &value, const Json &parameters) {
    const auto patterns = parameters.value("chromatogram_id_regex", Json::array());
    const auto flags = std::regex::ECMAScript |
                       (parameters.value("ignore_case", true) ? std::regex::icase : std::regex_constants::syntax_option_type{});
    for (const auto &pattern : patterns) {
        try {
            if (std::regex_search(value, std::regex(pattern.get<std::string>(), flags))) return true;
        } catch (const std::regex_error &) {
        }
    }
    return false;
}

Json status(const char *message) {
    return Json{{"status", "finished"}, {"info", message}};
}

}

Json load_chromatograms(streamfind::Project &project, const Json &parameters) {
    detail::ensure_table(project);
    for (const auto &[analysis, path] : detail::analyses(project, parameters)) {
        ::mass_spec::reader::MASS_SPEC_FILE file(path);
        const auto headers = file.get_chromatograms_headers();
        const auto arrays = file.get_chromatograms();
        for (std::size_t i = 0; i < arrays.size() && i < headers.chromatogram_id.size(); ++i) {
            const auto &id = headers.chromatogram_id[i];
            const bool keep = detail::matches(id, parameters) ^ parameters.value("invert", false);
            if (!keep || arrays[i].size() < 2) continue;
            project.execute_sql("DELETE FROM MASS_SPEC_CHROMATOGRAMS WHERE project_id = " + detail::sql(project.get_project_id()) +
                                " AND analysis = " + detail::sql(analysis) + " AND chromatogram_id = " + detail::sql(id));
            const auto &times = arrays[i][0];
            const auto &intensities = arrays[i][1];
            const auto count = std::min(times.size(), intensities.size());
            for (std::size_t j = 0; j < count; ++j)
                project.execute_sql("INSERT INTO MASS_SPEC_CHROMATOGRAMS (project_id, analysis, chromatogram_id, rt, raw_intensity, baseline, intensity) VALUES (" +
                                    detail::sql(project.get_project_id()) + "," + detail::sql(analysis) + "," + detail::sql(id) + "," +
                                    std::to_string(times[j]) + "," + std::to_string(intensities[j]) + ",0," + std::to_string(intensities[j]) + ")");
        }
    }
    return detail::status("Chromatograms loaded.");
}

Json filter_chromatograms_retention_time(streamfind::Project &project, const Json &parameters) {
    const double minimum = parameters.at("rt_min").get<double>();
    const double maximum = parameters.at("rt_max").get<double>();
    if (minimum >= maximum) throw Error(ErrorCode::InvalidArgument, "rt_min must be less than rt_max.");
    detail::ensure_table(project);
    std::string filter = " AND (rt < " + std::to_string(minimum) + " OR rt > " + std::to_string(maximum) + ")";
    const auto wanted = parameters.value("analysis_names", Json::array());
    if (!wanted.empty()) {
        filter += " AND analysis IN (";
        for (std::size_t i = 0; i < wanted.size(); ++i) filter += (i ? "," : "") + detail::sql(wanted[i].get<std::string>());
        filter += ")";
    }
    project.execute_sql("DELETE FROM MASS_SPEC_CHROMATOGRAMS WHERE project_id = " + detail::sql(project.get_project_id()) + filter);
    return detail::status("Chromatograms filtered by retention time.");
}

}
