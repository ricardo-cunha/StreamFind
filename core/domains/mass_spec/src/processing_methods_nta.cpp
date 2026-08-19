#include "streamfind/mass_spec/processing_methods_nta.hpp"
#include "streamfind/mass_spec/nta.hpp"
#include "streamfind/mass_spec/nta_deconvolution.hpp"
#include "streamfind/mass_spec/reader.hpp"

#include <string>
#include <vector>

namespace streamfind::mass_spec::processing_methods {
namespace detail {
std::string sql(const std::string &value) { std::string out = "'"; for (char c : value) out += c == '\'' ? "''" : std::string(1, c); return out + "'"; }
std::string row_sql(const std::string &project, const nta::api::NTA_FEATURE_ROW &r) {
    auto n = [](double v) { return std::to_string(v); };
    return sql(project)+","+sql(r.analysis)+","+sql(r.feature)+","+sql(r.feature_component)+","+sql(r.feature_group)+","+sql(r.adduct)+","+
      n(r.rt)+","+n(r.mz)+","+n(r.mass)+","+n(r.intensity)+","+n(r.noise)+","+n(r.sn)+","+n(r.area)+","+std::to_string(r.eic_size)+","+n(r.rtmin)+","+n(r.rtmax)+","+n(r.width)+","+
      n(r.mzmin)+","+n(r.mzmax)+","+n(r.ppm)+","+n(r.fwhm_rt)+","+n(r.fwhm_mz)+","+n(r.gaussian_A)+","+n(r.gaussian_mu)+","+n(r.gaussian_sigma)+","+n(r.gaussian_r2)+","+
      n(r.jaggedness)+","+n(r.sharpness)+","+n(r.asymmetry)+","+std::to_string(r.modality)+","+n(r.plates)+","+std::to_string(r.polarity)+","+(r.filtered?"TRUE":"FALSE")+","+
      sql(r.filter)+","+(r.filled?"TRUE":"FALSE")+","+n(r.correction)+","+std::to_string(r.eic_size)+","+sql(r.eic_rt)+","+sql(r.eic_mz)+","+sql(r.eic_intensity)+","+sql(r.eic_baseline)+","+sql(r.eic_smoothed)+","+
      std::to_string(r.ms1_size)+","+sql(r.ms1_mz)+","+sql(r.ms1_intensity)+","+std::to_string(r.ms2_size)+","+sql(r.ms2_mz)+","+sql(r.ms2_intensity)+","+
      sql(r.annotation_category)+","+sql(r.annotation_type)+","+sql(r.annotation_parent_feature)+","+sql(r.annotation_element)+","+n(r.annotation_mass_error_da)+","+n(r.annotation_mass_error_ppm)+","+n(r.annotation_rt_error)+","+
      n(r.annotation_rel_intensity)+","+n(r.annotation_expected_rel_intensity_min)+","+n(r.annotation_expected_rel_intensity_max)+","+n(r.annotation_score)+","+std::to_string(r.component_size)+","+n(r.component_rt_center)+","+n(r.component_rt_spread)+","+n(r.component_density)+","+
      n(r.component_mean_correlation)+","+sql(r.component_best_partner)+","+n(r.component_max_correlation)+","+n(r.component_mean_correlation_to_component)+","+n(r.component_membership_score)+","+(r.component_is_core?"TRUE":"FALSE")+","+(r.component_bridge_flag?"TRUE":"FALSE");
}
}

Json find_features(streamfind::Project &project, const Json &parameters) {
    const auto minimums = parameters.at("rt_windows_min"), maximums = parameters.at("rt_windows_max");
    if (minimums.size() != maximums.size()) throw Error(ErrorCode::InvalidArgument, "rt_windows_min and rt_windows_max must have equal lengths.");
    const float ppm = parameters.value("ppm_threshold", 15.0), noise = parameters.value("noise_threshold", 15.0), snr = parameters.value("min_snr", 3.0);
    const int traces = parameters.value("min_traces", 3);
    const float baseline = parameters.value("baseline_window", 30.0), width = parameters.value("max_width", 30.0), quantile = parameters.value("base_quantile", .1);
    if (ppm <= 0 || noise < 0 || snr < 0 || traces < 1 || baseline <= 0 || width <= 0 || quantile <= 0 || quantile >= 1) throw Error(ErrorCode::InvalidArgument, "invalid feature detector parameters");
    const auto project_id = project.get_project_id();
     project.execute_sql("CREATE TABLE IF NOT EXISTS MASS_SPEC_NTA_FEATURES (project_id VARCHAR NOT NULL, analysis VARCHAR NOT NULL, feature VARCHAR NOT NULL, feature_component VARCHAR, feature_group VARCHAR, adduct VARCHAR, rt DOUBLE, mz DOUBLE, mass DOUBLE, intensity DOUBLE, noise DOUBLE, sn DOUBLE, area DOUBLE, trace_count INTEGER, rtmin DOUBLE, rtmax DOUBLE, width DOUBLE, mzmin DOUBLE, mzmax DOUBLE, ppm DOUBLE, fwhm_rt DOUBLE, fwhm_mz DOUBLE, gaussian_A DOUBLE, gaussian_mu DOUBLE, gaussian_sigma DOUBLE, gaussian_r2 DOUBLE, jaggedness DOUBLE, sharpness DOUBLE, asymmetry DOUBLE, modality INTEGER, plates DOUBLE, polarity INTEGER, filtered BOOLEAN, filter VARCHAR, filled BOOLEAN, correction DOUBLE, eic_size INTEGER, eic_rt VARCHAR, eic_mz VARCHAR, eic_intensity VARCHAR, eic_baseline VARCHAR, eic_smoothed VARCHAR, ms1_size INTEGER, ms1_mz VARCHAR, ms1_intensity VARCHAR, ms2_size INTEGER, ms2_mz VARCHAR, ms2_intensity VARCHAR, annotation_category VARCHAR, annotation_type VARCHAR, annotation_parent_feature VARCHAR, annotation_element VARCHAR, annotation_mass_error_da DOUBLE, annotation_mass_error_ppm DOUBLE, annotation_rt_error DOUBLE, annotation_rel_intensity DOUBLE, annotation_expected_rel_intensity_min DOUBLE, annotation_expected_rel_intensity_max DOUBLE, annotation_score DOUBLE, component_size INTEGER, component_rt_center DOUBLE, component_rt_spread DOUBLE, component_density DOUBLE, component_mean_correlation DOUBLE, component_best_partner VARCHAR, component_max_correlation DOUBLE, component_mean_correlation_to_component DOUBLE, component_membership_score DOUBLE, component_is_core BOOLEAN, component_bridge_flag BOOLEAN, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY(project_id, analysis, feature))");
    project.execute_sql("DELETE FROM MASS_SPEC_NTA_FEATURES WHERE project_id=" + detail::sql(project_id));
    std::vector<std::string> names, paths; std::vector<::mass_spec::reader::MASS_SPEC_SPECTRA_HEADERS> headers;
    const auto wanted = parameters.value("analysis_names", Json::array());
    for (const auto &row : project.query_json("SELECT analysis,file_path FROM MASS_SPEC_ANALYSES WHERE project_id="+detail::sql(project_id)+" ORDER BY analysis")) {
        const auto name=row.at("analysis").get<std::string>(); bool selected=wanted.empty(); for(const auto &x:wanted) selected=selected||x.get<std::string>()==name; if(!selected)continue;
        ::mass_spec::reader::MASS_SPEC_FILE file(row.at("file_path").get<std::string>()); names.push_back(name); paths.push_back(row.at("file_path").get<std::string>()); headers.push_back(file.get_spectra_headers());
    }
    nta::PROJECT_NON_TARGET_ANALYSIS data(std::move(names), std::move(paths), std::move(headers));
    std::vector<float> mins, maxs; for(const auto &v:minimums) mins.push_back(v.get<float>()); for(const auto &v:maximums) maxs.push_back(v.get<float>());
    nta::deconvolution::find_features_impl(data, mins, maxs, ppm, noise, snr, traces, baseline, width, quantile, "", 0, -1);
    for (const auto &buffer : data.feature_buffers()) for (const auto &r : buffer.rows)
        project.execute_sql("INSERT INTO MASS_SPEC_NTA_FEATURES VALUES ("+detail::row_sql(project_id,r)+",CURRENT_TIMESTAMP)");
    return Json{{"status","finished"},{"info","Features detected."}};
}
}
