#include "streamfind/mass_spec/mass_spec.hpp"

#include <algorithm>
#include <cctype>
#include <filesystem>
#include <stdexcept>

namespace streamfind::mass_spec::detail {
std::string sql(const std::string &value) {
    std::string out = "'";
    for (const char c : value) out += c == '\'' ? "''" : std::string(1, c);
    return out + "'";
}
std::string lower(std::string value) {
    std::transform(value.begin(), value.end(), value.begin(), [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
    return value;
}
}

namespace streamfind::mass_spec {

Project::Project(streamfind::Project &project) : project_(project) { create_schema(); }

void Project::create_schema() {
    project_.execute_sql("CREATE TABLE IF NOT EXISTS MASS_SPEC_ANALYSES (project_id VARCHAR NOT NULL, analysis VARCHAR NOT NULL, replicate VARCHAR, blank VARCHAR, file_name VARCHAR, file_path VARCHAR NOT NULL, file_dir VARCHAR, file_extension VARCHAR, format VARCHAR, number_spectra INTEGER, number_chromatograms INTEGER, number_spectra_binary_arrays INTEGER, min_mz DOUBLE, max_mz DOUBLE, start_rt DOUBLE, end_rt DOUBLE, has_ion_mobility BOOLEAN, PRIMARY KEY(project_id, analysis))");
    project_.execute_sql("CREATE TABLE IF NOT EXISTS MASS_SPEC_SPECTRA_HEADERS (project_id VARCHAR NOT NULL, analysis VARCHAR NOT NULL, index INTEGER NOT NULL, scan INTEGER, array_length INTEGER, level INTEGER, mode INTEGER, polarity INTEGER, configuration INTEGER, lowmz DOUBLE, highmz DOUBLE, bpmz DOUBLE, bpint DOUBLE, tic DOUBLE, rt DOUBLE, mobility DOUBLE, window_mz DOUBLE, window_mzlow DOUBLE, window_mzhigh DOUBLE, precursor_mz DOUBLE, precursor_intensity DOUBLE, precursor_charge INTEGER, activation_ce DOUBLE, PRIMARY KEY(project_id, analysis, index))");
    project_.execute_sql("CREATE TABLE IF NOT EXISTS MASS_SPEC_CHROMATOGRAMS_HEADERS (project_id VARCHAR NOT NULL, analysis VARCHAR NOT NULL, index INTEGER NOT NULL, chromatogram_id VARCHAR, array_length INTEGER, polarity INTEGER, precursor_mz DOUBLE, activation_ce DOUBLE, product_mz DOUBLE, signal_type VARCHAR, chromatogram_type VARCHAR, detector VARCHAR, channel VARCHAR, units VARCHAR, wavelength_nm DOUBLE, interval_ms DOUBLE, start_time DOUBLE, end_time DOUBLE, intensity_multiplier DOUBLE, PRIMARY KEY(project_id, analysis, index))");
}

Json Project::add_analyses(const Json &parameters) {
    create_schema();
    Json added = Json::array();
    for (const auto &item : parameters.at("analyses")) {
        const std::filesystem::path path = item.at("path").get<std::string>();
        const auto extension = detail::lower(path.extension().string());
        if (extension != ".mzml" && extension != ".mzxml" && extension != ".lcd" && extension != ".asc" && extension != ".d")
            throw streamfind::Error(streamfind::ErrorCode::InvalidArgument, "unsupported mass spectrometry file extension: " + extension);
        ::mass_spec::reader::MASS_SPEC_FILE file(path.string());
        const auto summary = file.get_summary();
        const auto analysis = path.stem().string();
        const auto replicate = item.value("replicate_name", "");
        const auto blank = item.value("blank_name", "");
        const auto query = "INSERT OR REPLACE INTO MASS_SPEC_ANALYSES VALUES (" + detail::sql(project_.get_project_id()) + "," + detail::sql(analysis) + "," + detail::sql(replicate) + "," + detail::sql(blank) + "," + detail::sql(path.filename().string()) + "," + detail::sql(path.string()) + "," + detail::sql(path.parent_path().string()) + "," + detail::sql(extension) + "," + detail::sql(summary.format) + "," + std::to_string(summary.number_spectra) + "," + std::to_string(summary.number_chromatograms) + "," + std::to_string(summary.number_spectra_binary_arrays) + "," + std::to_string(summary.min_mz) + "," + std::to_string(summary.max_mz) + "," + std::to_string(summary.start_rt) + "," + std::to_string(summary.end_rt) + "," + (summary.has_ion_mobility ? "true" : "false") + ")";
        project_.execute_sql(query);
        added.push_back({{"analysis", analysis}, {"file_path", path.string()}, {"replicate_name", replicate}, {"blank_name", blank}});
    }
    return added;
}

Json Project::remove_analyses(const Json &parameters) {
    create_schema();
    Json removed = Json::array();
    for (const auto &value : parameters.at("analysis_names")) {
        const auto name = value.get<std::string>();
        project_.execute_sql("DELETE FROM MASS_SPEC_ANALYSES WHERE project_id = " + detail::sql(project_.get_project_id()) + " AND analysis = " + detail::sql(name));
        removed.push_back(name);
    }
    return removed;
}

Json Project::get_analyses_info(const Json &) {
    create_schema();
    return project_.query_json("SELECT analysis, replicate, blank, file_path, format, number_spectra, number_chromatograms FROM MASS_SPEC_ANALYSES WHERE project_id = " + detail::sql(project_.get_project_id()) + " ORDER BY analysis");
}

}
