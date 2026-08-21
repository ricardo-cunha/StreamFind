#include "streamfind/mass_spec/processing_methods_nta.hpp"
#include "streamfind/mass_spec/nta.hpp"
#include "streamfind/mass_spec/nta_deconvolution.hpp"
#include "streamfind/mass_spec/reader.hpp"
#include "streamfind/mass_spec/nta_annotation.hpp"
#include "streamfind/mass_spec/nta_blank_subtraction.hpp"
#include "streamfind/mass_spec/nta_componentization.hpp"
#include "streamfind/mass_spec/nta_correction_algorithms.hpp"
#include "streamfind/mass_spec/nta_filters.hpp"
#include "streamfind/mass_spec/nta_gap_filling.hpp"
#include "streamfind/mass_spec/nta_alignment.hpp"
#include "streamfind/mass_spec/nta_suspect_screening.hpp"

#include <algorithm>
#include <cmath>
#include <filesystem>
#include <limits>
#include <map>
#include <numeric>
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

struct MZ_INTENSITY {
    std::vector<float> mz;
    std::vector<float> intensity;
};

// Port of merge_NTA_FEATURE_SPECTRA: cluster a per-feature spectrum by m/z,
// merge cross-scan representatives and apply a presence filter. Matches the
// former R implementation (bindings/r/src/core/nta/nta.cpp).
MZ_INTENSITY merge_nta_feature_spectra(const ::mass_spec::spectra::MASS_SPEC_TARGETS_SPECTRA &spectra,
                                       float mzClust, float presence) {
    MZ_INTENSITY out;
    const size_t n = spectra.mz.size();
    if (n == 0) return out;

    std::vector<size_t> idx(n);
    std::iota(idx.begin(), idx.end(), 0);
    std::sort(idx.begin(), idx.end(), [&](size_t i, size_t j) { return spectra.mz[i] < spectra.mz[j]; });

    std::vector<float> sorted_mz(n), sorted_intensity(n), sorted_rt(n);
    std::vector<float> sorted_pre_ce(n, std::numeric_limits<float>::quiet_NaN());
    for (size_t k = 0; k < n; ++k) {
        const size_t src = idx[k];
        sorted_mz[k] = spectra.mz[src];
        sorted_intensity[k] = spectra.intensity[src];
        if (spectra.rt.size() > src) sorted_rt[k] = spectra.rt[src];
        if (spectra.pre_ce.size() > src) sorted_pre_ce[k] = spectra.pre_ce[src];
    }

    size_t total_unique_rt = 0;
    if (!sorted_rt.empty()) {
        std::vector<float> tmp = sorted_rt;
        std::sort(tmp.begin(), tmp.end());
        total_unique_rt = static_cast<size_t>(std::unique(tmp.begin(), tmp.end()) - tmp.begin());
    }

    std::vector<float> all_finite_pre_ce;
    all_finite_pre_ce.reserve(n);
    for (float v : sorted_pre_ce)
        if (std::isfinite(v)) all_finite_pre_ce.push_back(v);
    std::sort(all_finite_pre_ce.begin(), all_finite_pre_ce.end());
    all_finite_pre_ce.erase(std::unique(all_finite_pre_ce.begin(), all_finite_pre_ce.end()), all_finite_pre_ce.end());
    const size_t total_unique_pre_ce = all_finite_pre_ce.size();

    const float mz_tol = std::max(mzClust, 0.0f);
    const float presence_thresh = std::clamp(presence, 0.0f, 1.0f);

    std::vector<float> new_mz, new_intensity;
    new_mz.reserve(n);
    new_intensity.reserve(n);

    size_t start = 0;
    while (start < n) {
        size_t end = start + 1;
        while (end < n && (sorted_mz[end] - sorted_mz[end - 1]) <= mz_tol) ++end;

        std::map<float, std::vector<size_t>> rt_groups;
        for (size_t i = start; i < end; ++i) rt_groups[sorted_rt[i]].push_back(i);

        if (rt_groups.size() <= 1) {
            for (size_t i = start; i < end; ++i) {
                new_mz.push_back(sorted_mz[i]);
                new_intensity.push_back(sorted_intensity[i]);
            }
            start = end;
            continue;
        }

        std::vector<float> reps_mz, reps_int, reps_pre_ce;
        reps_mz.reserve(rt_groups.size());
        reps_int.reserve(rt_groups.size());
        reps_pre_ce.reserve(rt_groups.size());
        for (auto &[rt_val, indices] : rt_groups) {
            size_t best = indices[0];
            float best_int = sorted_intensity[best];
            for (size_t ji : indices)
                if (sorted_intensity[ji] > best_int) { best = ji; best_int = sorted_intensity[ji]; }
            reps_mz.push_back(sorted_mz[best]);
            reps_int.push_back(best_int);
            if (std::isfinite(sorted_pre_ce[best])) reps_pre_ce.push_back(sorted_pre_ce[best]);
        }

        bool pass = true;
        if (presence_thresh > 0.0f && total_unique_rt > 0) {
            float required = presence_thresh * static_cast<float>(total_unique_rt);
            if (total_unique_pre_ce > 0 && !reps_pre_ce.empty()) {
                std::sort(reps_pre_ce.begin(), reps_pre_ce.end());
                size_t uniq_ce = static_cast<size_t>(std::unique(reps_pre_ce.begin(), reps_pre_ce.end()) - reps_pre_ce.begin());
                if (uniq_ce < total_unique_pre_ce)
                    required *= static_cast<float>(uniq_ce) / static_cast<float>(total_unique_pre_ce);
            }
            if (static_cast<float>(reps_mz.size()) < required) pass = false;
        }

        if (!pass) { start = end; continue; }

        size_t best_rep = 0;
        float best_rep_int = reps_int[0];
        for (size_t i = 1; i < reps_mz.size(); ++i)
            if (reps_int[i] > best_rep_int) { best_rep = i; best_rep_int = reps_int[i]; }
        new_mz.push_back(reps_mz[best_rep]);
        new_intensity.push_back(best_rep_int);

        start = end;
    }

    out.mz = std::move(new_mz);
    out.intensity = std::move(new_intensity);
    return out;
}

std::string encode_float_array(const std::vector<float> &values) {
    return ::mass_spec::reader::utils::encode_base64(
        ::mass_spec::reader::utils::encode_little_endian_from_float(values, 4));
}

// Load every persisted feature for the selected analyses from MASS_SPEC_NTA_FEATURES
// and bundle them per analysis, alongside the analysis names/paths/headers needed to
// open the raw data through the reader, and the blank/replicate metadata used by the
// processing algorithms.
nta::PROJECT_NON_TARGET_ANALYSIS load_analysis_features(streamfind::Project &project, const Json &parameters) {
    const auto project_id = project.get_project_id();
    std::vector<std::string> names, paths, blanks, replicates;
    std::vector<::mass_spec::reader::MASS_SPEC_SPECTRA_HEADERS> headers;
    const auto wanted = parameters.value("analysis_names", Json::array());
    for (const auto &row : project.query_json("SELECT analysis,file_path,blank,replicate FROM MASS_SPEC_ANALYSES WHERE project_id="+detail::sql(project_id)+" ORDER BY analysis")) {
        const auto name = row.at("analysis").get<std::string>();
        bool selected = wanted.empty();
        for (const auto &x : wanted) selected = selected || x.get<std::string>() == name;
        if (!selected) continue;
        ::mass_spec::reader::MASS_SPEC_FILE file(row.at("file_path").get<std::string>());
        names.push_back(name);
        paths.push_back(row.at("file_path").get<std::string>());
        blanks.push_back(row.value("blank", ""));
        replicates.push_back(row.value("replicate", ""));
        headers.push_back(file.get_spectra_headers());
    }
    nta::PROJECT_NON_TARGET_ANALYSIS data(std::move(names), std::move(paths), std::move(headers));
    data.set_blank_names(std::move(blanks));
    data.set_replicate_names(std::move(replicates));
    auto &buffers = data.feature_buffers();
    for (size_t i = 0; i < buffers.size(); ++i) buffers[i].analysis = data.analysis_names()[i];
    // NULL-tolerant row accessors (query_json stringifies all column values).
    auto s = [&](const Json &row, const char *col) {
        auto it = row.find(col);
        return (it != row.end() && !it->is_null()) ? it->get<std::string>() : std::string();
    };
    auto d = [&](const Json &row, const char *col) { auto v = s(row, col); return v.empty() ? 0.0 : std::stod(v); };
    auto i = [&](const Json &row, const char *col) { auto v = s(row, col); return v.empty() ? 0 : std::stoi(v); };
    auto b = [&](const Json &row, const char *col) {
        auto v = s(row, col);
        return v == "true" || v == "TRUE" || v == "1";
    };
    for (const auto &row : project.query_json("SELECT analysis, feature, feature_component, feature_group, adduct, rt, mz, mass, intensity, noise, sn, area, rtmin, rtmax, width, mzmin, mzmax, ppm, fwhm_rt, fwhm_mz, gaussian_A, gaussian_mu, gaussian_sigma, gaussian_r2, jaggedness, sharpness, asymmetry, modality, plates, polarity, filtered, filter, filled, correction, eic_size, eic_rt, eic_mz, eic_intensity, eic_baseline, eic_smoothed, ms1_size, ms1_mz, ms1_intensity, ms2_size, ms2_mz, ms2_intensity, annotation_category, annotation_type, annotation_parent_feature, annotation_element, annotation_mass_error_da, annotation_mass_error_ppm, annotation_rt_error, annotation_rel_intensity, annotation_expected_rel_intensity_min, annotation_expected_rel_intensity_max, annotation_score, component_size, component_rt_center, component_rt_spread, component_density, component_mean_correlation, component_best_partner, component_max_correlation, component_mean_correlation_to_component, component_membership_score, component_is_core, component_bridge_flag FROM MASS_SPEC_NTA_FEATURES WHERE project_id="+detail::sql(project_id)+" ORDER BY analysis")) {
        const auto an = row.at("analysis").get<std::string>();
        const auto it = std::find(data.analysis_names().begin(), data.analysis_names().end(), an);
        if (it == data.analysis_names().end()) continue;
        nta::api::NTA_FEATURE_ROW r;
        r.analysis = an;
        r.feature = s(row, "feature");
        r.feature_component = s(row, "feature_component");
        r.feature_group = s(row, "feature_group");
        r.adduct = s(row, "adduct");
        r.rt = d(row, "rt");
        r.mz = d(row, "mz");
        r.mass = d(row, "mass");
        r.intensity = d(row, "intensity");
        r.noise = d(row, "noise");
        r.sn = d(row, "sn");
        r.area = d(row, "area");
        r.rtmin = d(row, "rtmin");
        r.rtmax = d(row, "rtmax");
        r.width = d(row, "width");
        r.mzmin = d(row, "mzmin");
        r.mzmax = d(row, "mzmax");
        r.ppm = d(row, "ppm");
        r.fwhm_rt = d(row, "fwhm_rt");
        r.fwhm_mz = d(row, "fwhm_mz");
        r.gaussian_A = d(row, "gaussian_A");
        r.gaussian_mu = d(row, "gaussian_mu");
        r.gaussian_sigma = d(row, "gaussian_sigma");
        r.gaussian_r2 = d(row, "gaussian_r2");
        r.jaggedness = d(row, "jaggedness");
        r.sharpness = d(row, "sharpness");
        r.asymmetry = d(row, "asymmetry");
        r.modality = i(row, "modality");
        r.plates = d(row, "plates");
        r.polarity = i(row, "polarity");
        r.filtered = b(row, "filtered");
        r.filter = s(row, "filter");
        r.filled = b(row, "filled");
        r.correction = d(row, "correction");
        r.eic_size = i(row, "eic_size");
        r.eic_rt = s(row, "eic_rt");
        r.eic_mz = s(row, "eic_mz");
        r.eic_intensity = s(row, "eic_intensity");
        r.eic_baseline = s(row, "eic_baseline");
        r.eic_smoothed = s(row, "eic_smoothed");
        r.ms1_size = i(row, "ms1_size");
        r.ms1_mz = s(row, "ms1_mz");
        r.ms1_intensity = s(row, "ms1_intensity");
        r.ms2_size = i(row, "ms2_size");
        r.ms2_mz = s(row, "ms2_mz");
        r.ms2_intensity = s(row, "ms2_intensity");
        r.annotation_category = s(row, "annotation_category");
        r.annotation_type = s(row, "annotation_type");
        r.annotation_parent_feature = s(row, "annotation_parent_feature");
        r.annotation_element = s(row, "annotation_element");
        r.annotation_mass_error_da = d(row, "annotation_mass_error_da");
        r.annotation_mass_error_ppm = d(row, "annotation_mass_error_ppm");
        r.annotation_rt_error = d(row, "annotation_rt_error");
        r.annotation_rel_intensity = d(row, "annotation_rel_intensity");
        r.annotation_expected_rel_intensity_min = d(row, "annotation_expected_rel_intensity_min");
        r.annotation_expected_rel_intensity_max = d(row, "annotation_expected_rel_intensity_max");
        r.annotation_score = d(row, "annotation_score");
        r.component_size = i(row, "component_size");
        r.component_rt_center = d(row, "component_rt_center");
        r.component_rt_spread = d(row, "component_rt_spread");
        r.component_density = d(row, "component_density");
        r.component_mean_correlation = d(row, "component_mean_correlation");
        r.component_best_partner = s(row, "component_best_partner");
        r.component_max_correlation = d(row, "component_max_correlation");
        r.component_mean_correlation_to_component = d(row, "component_mean_correlation_to_component");
        r.component_membership_score = d(row, "component_membership_score");
        r.component_is_core = b(row, "component_is_core");
        r.component_bridge_flag = b(row, "component_bridge_flag");
        buffers[static_cast<size_t>(it - data.analysis_names().begin())].append_feature(r);
    }
    return data;
}

// Map the JSON `targets` array (suspects/internal standards) into SuspectQuery objects.
std::vector<nta::suspect_screening::SuspectQuery> parse_suspect_targets(const Json &parameters) {
    std::vector<nta::suspect_screening::SuspectQuery> out;
    const auto targets = parameters.value("targets", Json::array());
    for (const auto &t : targets) {
        nta::suspect_screening::SuspectQuery q;
        q.name = t.value("id", t.value("name", ""));
        if (t.contains("mass")) { q.has_mass = true; q.mass = t.at("mass").get<double>(); }
        else if (t.contains("mz")) { q.has_mass = true; q.mass = t.at("mz").get<double>(); }
        q.rt = t.value("rt", 0.0);
        q.formula = t.value("formula", "");
        q.SMILES = t.value("SMILES", t.value("smiles", ""));
        q.InChI = t.value("InChI", t.value("inchi", ""));
        q.InChIKey = t.value("InChIKey", t.value("inchikey", ""));
        q.database_id = t.value("database_id", "");
        q.score = t.value("score", 0.0);
        if (t.contains("xLogP")) { q.has_xLogP = true; q.xLogP = t.at("xLogP").get<double>(); }
        // Fragments: use the explicit fragment vectors when present, else the positive mode.
        const auto frag_mz = t.value("fragments_mz", t.value("fragments_mz_pos", Json::array()));
        const auto frag_int = t.value("fragments_intensity", t.value("fragments_intensity_pos", Json::array()));
        for (const auto &v : frag_mz) q.fragments_mz_pos.push_back(v.get<double>());
        for (const auto &v : frag_int) q.fragments_intensity_pos.push_back(v.get<double>());
        out.push_back(std::move(q));
    }
    return out;
}

bool excluded_feature(const nta::api::NTA_FEATURE_ROW &r, bool filtered) {
    return r.filtered && !filtered;
}

bool already_had(const nta::api::NTA_FEATURE_ROW &r, int level) {
    if (level == 1) return r.ms1_size > 0 && !r.ms1_mz.empty() && !r.ms1_intensity.empty();
    return r.ms2_size > 0 && !r.ms2_mz.empty() && !r.ms2_intensity.empty();
}

// Non-finite doubles are stored as SQL NULL so DuckDB accepts them; loading maps
// NULL back to NaN to preserve the R NA "disabled" semantics of the filter steps.
std::string dn(const double v) { return std::isfinite(v) ? std::to_string(v) : std::string("NULL"); }
std::string suspect_row_sql(const std::string &project, const nta::api::NTA_SUSPECT_ROW &r) {
    return detail::sql(project) + "," + detail::sql(r.analysis) + "," + detail::sql(r.feature) + "," + detail::sql(r.feature_group) + "," +
      std::to_string(r.candidate_rank) + "," + detail::sql(r.name) + "," + std::to_string(r.polarity) + "," + dn(r.db_mass) + "," + dn(r.exp_mass) + "," + dn(r.error_mass) + "," +
      dn(r.db_rt) + "," + dn(r.exp_rt) + "," + dn(r.error_rt) + "," + dn(r.intensity) + "," + dn(r.area) + "," + std::to_string(r.id_level) + "," + dn(r.score) + "," +
      std::to_string(r.shared_fragments) + "," + dn(r.cosine_similarity) + "," + detail::sql(r.formula) + "," + detail::sql(r.SMILES) + "," + detail::sql(r.InChI) + "," +
      detail::sql(r.InChIKey) + "," + dn(r.xLogP) + "," + detail::sql(r.database_id) + "," + std::to_string(r.db_ms2_size) + "," + detail::sql(r.db_ms2_mz) + "," +
      detail::sql(r.db_ms2_intensity) + "," + detail::sql(r.db_ms2_formula) + "," + detail::sql(r.db_ms2_smiles) + "," + std::to_string(r.exp_ms2_size) + "," +
      detail::sql(r.exp_ms2_mz) + "," + detail::sql(r.exp_ms2_intensity);
}
std::string internal_standard_row_sql(const std::string &project, const nta::api::NTA_INTERNAL_STANDARD_ROW &r) {
    return detail::sql(project) + "," + detail::sql(r.analysis) + "," + detail::sql(r.feature) + "," + detail::sql(r.feature_group) + "," +
      detail::sql(r.feature_component) + "," + detail::sql(r.adduct) + "," + std::to_string(r.candidate_rank) + "," + detail::sql(r.name) + "," +
      std::to_string(r.polarity) + "," + dn(r.db_mass) + "," + dn(r.exp_mass) + "," + dn(r.error_mass) + "," + dn(r.db_rt) + "," + dn(r.exp_rt) + "," + dn(r.error_rt) + "," +
      dn(r.intensity) + "," + dn(r.area) + "," + std::to_string(r.id_level) + "," + dn(r.score) + "," + std::to_string(r.shared_fragments) + "," + dn(r.cosine_similarity) + "," +
      detail::sql(r.formula) + "," + detail::sql(r.SMILES) + "," + detail::sql(r.InChI) + "," + detail::sql(r.InChIKey) + "," + dn(r.xLogP) + "," + detail::sql(r.database_id) + "," +
      std::to_string(r.db_ms2_size) + "," + detail::sql(r.db_ms2_mz) + "," + detail::sql(r.db_ms2_intensity) + "," + detail::sql(r.db_ms2_formula) + "," +
      detail::sql(r.db_ms2_smiles) + "," + std::to_string(r.exp_ms2_size) + "," + detail::sql(r.exp_ms2_mz) + "," + detail::sql(r.exp_ms2_intensity);
}

// ---------------------------------------------------------------------------
// Batched Appender persistence helpers.
//
// Each row is a vector of optional strings aligned to `*_columns()`. A cell is
// SQL NULL when `std::nullopt`, otherwise the already-stringified scalar. The
// core `Project::append_rows` reflects the DuckDB column types and appends each
// cell with the matching typed duckdb_append_* call, so numbers stay numeric.
// The column lists omit `created_at`: it is left to the table DEFAULT so the
// persisted `created_at` stays CURRENT_TIMESTAMP exactly as before.
// ---------------------------------------------------------------------------
std::optional<std::string> str_cell(const std::string &v) { return v; }
std::optional<std::string> inum_cell(int v) { return std::to_string(v); }
// Mirror `n()` used by features row_sql: always present, even for non-finite.
std::optional<std::string> fnum_cell(double v) { return std::to_string(v); }
// Mirror `dn()` used by suspects/internal standards: non-finite becomes NULL.
std::optional<std::string> dnum_cell(double v) {
    return std::isfinite(v) ? std::optional<std::string>(std::to_string(v)) : std::nullopt;
}
std::optional<std::string> bool_cell(bool v) { return v ? "true" : "false"; }

const std::vector<std::string> &features_columns() {
    static const std::vector<std::string> cols = {
        "project_id", "analysis", "feature", "feature_component", "feature_group", "adduct",
        "rt", "mz", "mass", "intensity", "noise", "sn", "area", "trace_count",
        "rtmin", "rtmax", "width", "mzmin", "mzmax", "ppm", "fwhm_rt", "fwhm_mz",
        "gaussian_A", "gaussian_mu", "gaussian_sigma", "gaussian_r2", "jaggedness", "sharpness", "asymmetry",
        "modality", "plates", "polarity", "filtered", "filter", "filled", "correction",
        "eic_size", "eic_rt", "eic_mz", "eic_intensity", "eic_baseline", "eic_smoothed",
        "ms1_size", "ms1_mz", "ms1_intensity", "ms2_size", "ms2_mz", "ms2_intensity",
        "annotation_category", "annotation_type", "annotation_parent_feature", "annotation_element",
        "annotation_mass_error_da", "annotation_mass_error_ppm", "annotation_rt_error",
        "annotation_rel_intensity", "annotation_expected_rel_intensity_min", "annotation_expected_rel_intensity_max", "annotation_score",
        "component_size", "component_rt_center", "component_rt_spread", "component_density",
        "component_mean_correlation", "component_best_partner", "component_max_correlation",
        "component_mean_correlation_to_component", "component_membership_score", "component_is_core", "component_bridge_flag"};
    return cols;
}

std::vector<std::optional<std::string>> feature_cells(const std::string &project, const nta::api::NTA_FEATURE_ROW &r) {
    return {
        str_cell(project), str_cell(r.analysis), str_cell(r.feature), str_cell(r.feature_component), str_cell(r.feature_group), str_cell(r.adduct),
        fnum_cell(r.rt), fnum_cell(r.mz), fnum_cell(r.mass), fnum_cell(r.intensity), fnum_cell(r.noise), fnum_cell(r.sn), fnum_cell(r.area),
        // Note: preserved existing binding — the current row_sql writes eic_size
        // into the trace_count column slot.
        inum_cell(r.eic_size),
        fnum_cell(r.rtmin), fnum_cell(r.rtmax), fnum_cell(r.width), fnum_cell(r.mzmin), fnum_cell(r.mzmax), fnum_cell(r.ppm),
        fnum_cell(r.fwhm_rt), fnum_cell(r.fwhm_mz), fnum_cell(r.gaussian_A), fnum_cell(r.gaussian_mu), fnum_cell(r.gaussian_sigma), fnum_cell(r.gaussian_r2),
        fnum_cell(r.jaggedness), fnum_cell(r.sharpness), fnum_cell(r.asymmetry),
        inum_cell(r.modality), fnum_cell(r.plates), inum_cell(r.polarity),
        bool_cell(r.filtered), str_cell(r.filter), bool_cell(r.filled), fnum_cell(r.correction),
        inum_cell(r.eic_size), str_cell(r.eic_rt), str_cell(r.eic_mz), str_cell(r.eic_intensity), str_cell(r.eic_baseline), str_cell(r.eic_smoothed),
        inum_cell(r.ms1_size), str_cell(r.ms1_mz), str_cell(r.ms1_intensity), inum_cell(r.ms2_size), str_cell(r.ms2_mz), str_cell(r.ms2_intensity),
        str_cell(r.annotation_category), str_cell(r.annotation_type), str_cell(r.annotation_parent_feature), str_cell(r.annotation_element),
        fnum_cell(r.annotation_mass_error_da), fnum_cell(r.annotation_mass_error_ppm), fnum_cell(r.annotation_rt_error),
        fnum_cell(r.annotation_rel_intensity), fnum_cell(r.annotation_expected_rel_intensity_min), fnum_cell(r.annotation_expected_rel_intensity_max), fnum_cell(r.annotation_score),
        inum_cell(r.component_size), fnum_cell(r.component_rt_center), fnum_cell(r.component_rt_spread), fnum_cell(r.component_density),
        fnum_cell(r.component_mean_correlation), str_cell(r.component_best_partner), fnum_cell(r.component_max_correlation),
        fnum_cell(r.component_mean_correlation_to_component), fnum_cell(r.component_membership_score),
        bool_cell(r.component_is_core), bool_cell(r.component_bridge_flag)};
}

const std::vector<std::string> &suspects_columns() {
    static const std::vector<std::string> cols = {
        "project_id", "analysis", "feature", "feature_group", "candidate_rank", "name", "polarity",
        "db_mass", "exp_mass", "error_mass", "db_rt", "exp_rt", "error_rt", "intensity", "area",
        "id_level", "score", "shared_fragments", "cosine_similarity", "formula", "SMILES", "InChI", "InChIKey",
        "xLogP", "database_id", "db_ms2_size", "db_ms2_mz", "db_ms2_intensity", "db_ms2_formula", "db_ms2_smiles",
        "exp_ms2_size", "exp_ms2_mz", "exp_ms2_intensity"};
    return cols;
}

std::vector<std::optional<std::string>> suspect_cells(const std::string &project, const nta::api::NTA_SUSPECT_ROW &r) {
    return {
        str_cell(project), str_cell(r.analysis), str_cell(r.feature), str_cell(r.feature_group),
        inum_cell(r.candidate_rank), str_cell(r.name), inum_cell(r.polarity),
        dnum_cell(r.db_mass), dnum_cell(r.exp_mass), dnum_cell(r.error_mass), dnum_cell(r.db_rt), dnum_cell(r.exp_rt), dnum_cell(r.error_rt),
        dnum_cell(r.intensity), dnum_cell(r.area), inum_cell(r.id_level), dnum_cell(r.score), inum_cell(r.shared_fragments), dnum_cell(r.cosine_similarity),
        str_cell(r.formula), str_cell(r.SMILES), str_cell(r.InChI), str_cell(r.InChIKey),
        dnum_cell(r.xLogP), str_cell(r.database_id), inum_cell(r.db_ms2_size), str_cell(r.db_ms2_mz), str_cell(r.db_ms2_intensity),
        str_cell(r.db_ms2_formula), str_cell(r.db_ms2_smiles), inum_cell(r.exp_ms2_size), str_cell(r.exp_ms2_mz), str_cell(r.exp_ms2_intensity)};
}

const std::vector<std::string> &internal_standards_columns() {
    static const std::vector<std::string> cols = {
        "project_id", "analysis", "feature", "feature_group", "feature_component", "adduct",
        "candidate_rank", "name", "polarity", "db_mass", "exp_mass", "error_mass", "db_rt", "exp_rt", "error_rt",
        "intensity", "area", "id_level", "score", "shared_fragments", "cosine_similarity",
        "formula", "SMILES", "InChI", "InChIKey", "xLogP", "database_id",
        "db_ms2_size", "db_ms2_mz", "db_ms2_intensity", "db_ms2_formula", "db_ms2_smiles",
        "exp_ms2_size", "exp_ms2_mz", "exp_ms2_intensity"};
    return cols;
}

std::vector<std::optional<std::string>> internal_standard_cells(const std::string &project, const nta::api::NTA_INTERNAL_STANDARD_ROW &r) {
    return {
        str_cell(project), str_cell(r.analysis), str_cell(r.feature), str_cell(r.feature_group), str_cell(r.feature_component), str_cell(r.adduct),
        inum_cell(r.candidate_rank), str_cell(r.name), inum_cell(r.polarity),
        dnum_cell(r.db_mass), dnum_cell(r.exp_mass), dnum_cell(r.error_mass), dnum_cell(r.db_rt), dnum_cell(r.exp_rt), dnum_cell(r.error_rt),
        dnum_cell(r.intensity), dnum_cell(r.area), inum_cell(r.id_level), dnum_cell(r.score), inum_cell(r.shared_fragments), dnum_cell(r.cosine_similarity),
        str_cell(r.formula), str_cell(r.SMILES), str_cell(r.InChI), str_cell(r.InChIKey), dnum_cell(r.xLogP), str_cell(r.database_id),
        inum_cell(r.db_ms2_size), str_cell(r.db_ms2_mz), str_cell(r.db_ms2_intensity), str_cell(r.db_ms2_formula), str_cell(r.db_ms2_smiles),
        inum_cell(r.exp_ms2_size), str_cell(r.exp_ms2_mz), str_cell(r.exp_ms2_intensity)};
}

void persist_features(streamfind::Project &project, nta::PROJECT_NON_TARGET_ANALYSIS &data) {
    const auto project_id = project.get_project_id();
    project.execute_sql("DELETE FROM MASS_SPEC_NTA_FEATURES WHERE project_id="+detail::sql(project_id));
    std::vector<std::vector<std::optional<std::string>>> rows;
    for (const auto &buffer : data.feature_buffers())
        for (int fi = 0; fi < buffer.size(); ++fi)
            rows.push_back(feature_cells(project_id, buffer.get_feature(fi)));
    project.append_rows("MASS_SPEC_NTA_FEATURES", features_columns(), rows);
}

void persist_suspects(streamfind::Project &project, nta::PROJECT_NON_TARGET_ANALYSIS &data) {
    const auto project_id = project.get_project_id();
    project.execute_sql("CREATE TABLE IF NOT EXISTS MASS_SPEC_NTA_SUSPECTS (project_id VARCHAR NOT NULL, analysis VARCHAR NOT NULL, feature VARCHAR NOT NULL, feature_group VARCHAR, candidate_rank INTEGER, name VARCHAR, polarity INTEGER, db_mass DOUBLE, exp_mass DOUBLE, error_mass DOUBLE, db_rt DOUBLE, exp_rt DOUBLE, error_rt DOUBLE, intensity DOUBLE, area DOUBLE, id_level INTEGER, score DOUBLE, shared_fragments INTEGER, cosine_similarity DOUBLE, formula VARCHAR, SMILES VARCHAR, InChI VARCHAR, InChIKey VARCHAR, xLogP DOUBLE, database_id VARCHAR, db_ms2_size INTEGER, db_ms2_mz VARCHAR, db_ms2_intensity VARCHAR, db_ms2_formula VARCHAR, db_ms2_smiles VARCHAR, exp_ms2_size INTEGER, exp_ms2_mz VARCHAR, exp_ms2_intensity VARCHAR, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY(project_id, analysis, feature))");
    project.execute_sql("DELETE FROM MASS_SPEC_NTA_SUSPECTS WHERE project_id=" + detail::sql(project_id));
    std::vector<std::vector<std::optional<std::string>>> rows;
    for (const auto &buffer : data.suspect_buffers())
        for (int s = 0; s < buffer.size(); ++s)
            rows.push_back(suspect_cells(project_id, buffer.get_suspect(s)));
    project.append_rows("MASS_SPEC_NTA_SUSPECTS", suspects_columns(), rows);
}

void persist_internal_standards(streamfind::Project &project, nta::PROJECT_NON_TARGET_ANALYSIS &data) {
    const auto project_id = project.get_project_id();
    project.execute_sql("CREATE TABLE IF NOT EXISTS MASS_SPEC_NTA_INTERNAL_STANDARDS (project_id VARCHAR NOT NULL, analysis VARCHAR NOT NULL, feature VARCHAR NOT NULL, feature_group VARCHAR, feature_component VARCHAR, adduct VARCHAR, candidate_rank INTEGER, name VARCHAR, polarity INTEGER, db_mass DOUBLE, exp_mass DOUBLE, error_mass DOUBLE, db_rt DOUBLE, exp_rt DOUBLE, error_rt DOUBLE, intensity DOUBLE, area DOUBLE, id_level INTEGER, score DOUBLE, shared_fragments INTEGER, cosine_similarity DOUBLE, formula VARCHAR, SMILES VARCHAR, InChI VARCHAR, InChIKey VARCHAR, xLogP DOUBLE, database_id VARCHAR, db_ms2_size INTEGER, db_ms2_mz VARCHAR, db_ms2_intensity VARCHAR, db_ms2_formula VARCHAR, db_ms2_smiles VARCHAR, exp_ms2_size INTEGER, exp_ms2_mz VARCHAR, exp_ms2_intensity VARCHAR, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY(project_id, analysis, feature))");
    project.execute_sql("DELETE FROM MASS_SPEC_NTA_INTERNAL_STANDARDS WHERE project_id=" + detail::sql(project_id));
    std::vector<std::vector<std::optional<std::string>>> rows;
    for (const auto &buffer : data.internal_standard_buffers())
        for (int s = 0; s < buffer.size(); ++s)
            rows.push_back(internal_standard_cells(project_id, buffer.get_internal_standard(s)));
    project.append_rows("MASS_SPEC_NTA_INTERNAL_STANDARDS", internal_standards_columns(), rows);
}

// NULL-tolerant accessors (query_json stringifies all column values).
static std::string col_s(const Json &row, const char *col) { auto it = row.find(col); return (it != row.end() && !it->is_null()) ? it->get<std::string>() : std::string(); }
static double col_d(const Json &row, const char *col) { auto v = col_s(row, col); return v.empty() ? std::numeric_limits<double>::quiet_NaN() : std::stod(v); }
static int col_i(const Json &row, const char *col) { auto v = col_s(row, col); return v.empty() ? 0 : std::stoi(v); }

void load_suspects(streamfind::Project &project, nta::PROJECT_NON_TARGET_ANALYSIS &data) {
    const auto project_id = project.get_project_id();
    project.execute_sql("CREATE TABLE IF NOT EXISTS MASS_SPEC_NTA_SUSPECTS (project_id VARCHAR NOT NULL, analysis VARCHAR NOT NULL, feature VARCHAR NOT NULL, feature_group VARCHAR, candidate_rank INTEGER, name VARCHAR, polarity INTEGER, db_mass DOUBLE, exp_mass DOUBLE, error_mass DOUBLE, db_rt DOUBLE, exp_rt DOUBLE, error_rt DOUBLE, intensity DOUBLE, area DOUBLE, id_level INTEGER, score DOUBLE, shared_fragments INTEGER, cosine_similarity DOUBLE, formula VARCHAR, SMILES VARCHAR, InChI VARCHAR, InChIKey VARCHAR, xLogP DOUBLE, database_id VARCHAR, db_ms2_size INTEGER, db_ms2_mz VARCHAR, db_ms2_intensity VARCHAR, db_ms2_formula VARCHAR, db_ms2_smiles VARCHAR, exp_ms2_size INTEGER, exp_ms2_mz VARCHAR, exp_ms2_intensity VARCHAR, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY(project_id, analysis, feature))");
    auto &buffers = data.suspect_buffers();
    for (auto &b : buffers) b = nta::api::NTA_SUSPECTS();
    for (const auto &row : project.query_json("SELECT * FROM MASS_SPEC_NTA_SUSPECTS WHERE project_id=" + detail::sql(project_id) + " ORDER BY analysis")) {
        const auto an = row.at("analysis").get<std::string>();
        const auto it = std::find(data.analysis_names().begin(), data.analysis_names().end(), an);
        if (it == data.analysis_names().end()) continue;
        nta::api::NTA_SUSPECT_ROW r;
        r.analysis = an; r.feature = col_s(row, "feature"); r.feature_group = col_s(row, "feature_group");
        r.candidate_rank = col_i(row, "candidate_rank"); r.name = col_s(row, "name");
        r.polarity = col_i(row, "polarity"); r.db_mass = col_d(row, "db_mass"); r.exp_mass = col_d(row, "exp_mass");
        r.error_mass = col_d(row, "error_mass"); r.db_rt = col_d(row, "db_rt"); r.exp_rt = col_d(row, "exp_rt");
        r.error_rt = col_d(row, "error_rt"); r.intensity = col_d(row, "intensity"); r.area = col_d(row, "area");
        r.id_level = col_i(row, "id_level"); r.score = col_d(row, "score"); r.shared_fragments = col_i(row, "shared_fragments");
        r.cosine_similarity = col_d(row, "cosine_similarity"); r.formula = col_s(row, "formula"); r.SMILES = col_s(row, "SMILES");
        r.InChI = col_s(row, "InChI"); r.InChIKey = col_s(row, "InChIKey"); r.xLogP = col_d(row, "xLogP");
        r.database_id = col_s(row, "database_id"); r.db_ms2_size = col_i(row, "db_ms2_size"); r.db_ms2_mz = col_s(row, "db_ms2_mz");
        r.db_ms2_intensity = col_s(row, "db_ms2_intensity"); r.db_ms2_formula = col_s(row, "db_ms2_formula"); r.db_ms2_smiles = col_s(row, "db_ms2_smiles");
        r.exp_ms2_size = col_i(row, "exp_ms2_size"); r.exp_ms2_mz = col_s(row, "exp_ms2_mz"); r.exp_ms2_intensity = col_s(row, "exp_ms2_intensity");
        buffers[static_cast<size_t>(it - data.analysis_names().begin())].append(r);
    }
}

void load_internal_standards(streamfind::Project &project, nta::PROJECT_NON_TARGET_ANALYSIS &data) {
    const auto project_id = project.get_project_id();
    project.execute_sql("CREATE TABLE IF NOT EXISTS MASS_SPEC_NTA_INTERNAL_STANDARDS (project_id VARCHAR NOT NULL, analysis VARCHAR NOT NULL, feature VARCHAR NOT NULL, feature_group VARCHAR, feature_component VARCHAR, adduct VARCHAR, candidate_rank INTEGER, name VARCHAR, polarity INTEGER, db_mass DOUBLE, exp_mass DOUBLE, error_mass DOUBLE, db_rt DOUBLE, exp_rt DOUBLE, error_rt DOUBLE, intensity DOUBLE, area DOUBLE, id_level INTEGER, score DOUBLE, shared_fragments INTEGER, cosine_similarity DOUBLE, formula VARCHAR, SMILES VARCHAR, InChI VARCHAR, InChIKey VARCHAR, xLogP DOUBLE, database_id VARCHAR, db_ms2_size INTEGER, db_ms2_mz VARCHAR, db_ms2_intensity VARCHAR, db_ms2_formula VARCHAR, db_ms2_smiles VARCHAR, exp_ms2_size INTEGER, exp_ms2_mz VARCHAR, exp_ms2_intensity VARCHAR, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY(project_id, analysis, feature))");
    auto &buffers = data.internal_standard_buffers();
    for (auto &b : buffers) b = nta::api::NTA_INTERNAL_STANDARDS();
    for (const auto &row : project.query_json("SELECT * FROM MASS_SPEC_NTA_INTERNAL_STANDARDS WHERE project_id=" + detail::sql(project_id) + " ORDER BY analysis")) {
        const auto an = row.at("analysis").get<std::string>();
        const auto it = std::find(data.analysis_names().begin(), data.analysis_names().end(), an);
        if (it == data.analysis_names().end()) continue;
        nta::api::NTA_INTERNAL_STANDARD_ROW r;
        r.analysis = an; r.feature = col_s(row, "feature"); r.feature_group = col_s(row, "feature_group");
        r.feature_component = col_s(row, "feature_component"); r.adduct = col_s(row, "adduct");
        r.candidate_rank = col_i(row, "candidate_rank"); r.name = col_s(row, "name");
        r.polarity = col_i(row, "polarity"); r.db_mass = col_d(row, "db_mass"); r.exp_mass = col_d(row, "exp_mass");
        r.error_mass = col_d(row, "error_mass"); r.db_rt = col_d(row, "db_rt"); r.exp_rt = col_d(row, "exp_rt");
        r.error_rt = col_d(row, "error_rt"); r.intensity = col_d(row, "intensity"); r.area = col_d(row, "area");
        r.id_level = col_i(row, "id_level"); r.score = col_d(row, "score"); r.shared_fragments = col_i(row, "shared_fragments");
        r.cosine_similarity = col_d(row, "cosine_similarity"); r.formula = col_s(row, "formula"); r.SMILES = col_s(row, "SMILES");
        r.InChI = col_s(row, "InChI"); r.InChIKey = col_s(row, "InChIKey"); r.xLogP = col_d(row, "xLogP");
        r.database_id = col_s(row, "database_id"); r.db_ms2_size = col_i(row, "db_ms2_size"); r.db_ms2_mz = col_s(row, "db_ms2_mz");
        r.db_ms2_intensity = col_s(row, "db_ms2_intensity"); r.db_ms2_formula = col_s(row, "db_ms2_formula"); r.db_ms2_smiles = col_s(row, "db_ms2_smiles");
        r.exp_ms2_size = col_i(row, "exp_ms2_size"); r.exp_ms2_mz = col_s(row, "exp_ms2_mz"); r.exp_ms2_intensity = col_s(row, "exp_ms2_intensity");
        buffers[static_cast<size_t>(it - data.analysis_names().begin())].append(r);
    }
}

} // namespace detail

Json find_features(streamfind::Project &project, const Json &parameters) {
    const auto minimums = parameters.value("rt_windows_min", Json::array()), maximums = parameters.value("rt_windows_max", Json::array());
    // Empty RT windows (R default) mean the full retention-time range.
    if (!minimums.empty() || !maximums.empty()) {
        if (minimums.size() != maximums.size()) throw Error(ErrorCode::InvalidArgument, "rt_windows_min and rt_windows_max must have equal lengths.");
    }
    const float ppm = parameters.value("ppm_threshold", 15.0), noise = parameters.value("noise_threshold", 250.0), snr = parameters.value("min_snr", 3.0);
    const int traces = parameters.value("min_traces", 3);
    const float baseline = parameters.value("baseline_window", 200.0), width = parameters.value("max_width", parameters.value("max_feature_width", 100.0)), quantile = parameters.value("base_quantile", .1);
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
    std::vector<std::vector<std::optional<std::string>>> feature_rows;
    for (const auto &buffer : data.feature_buffers())
        for (int fi = 0; fi < buffer.size(); ++fi)
            feature_rows.push_back(detail::feature_cells(project_id, buffer.get_feature(fi)));
    project.append_rows("MASS_SPEC_NTA_FEATURES", detail::features_columns(), feature_rows);
    return Json{{"status","finished"},{"info","Features detected."}};
}

Json load_features_ms1(streamfind::Project &project, const Json &parameters) {
    const bool filtered = parameters.value("filtered", false);
    const auto rt_window = parameters.value("rt_window", Json::array({-2.0, 2.0}));
    const auto mz_window = parameters.value("mz_window", Json::array({-1.0, 6.0}));
    const float min_traces = parameters.value("min_traces_intensity", 250.0);
    const float mz_clust = parameters.value("mz_clust", 0.005);
    const float presence = parameters.value("presence", 0.8);
    if (min_traces < 0 || mz_clust < 0 || presence < 0 || presence > 1) throw Error(ErrorCode::InvalidArgument, "invalid MS1 spectrum loading parameters");
    const float rt_lo = rt_window.size() >= 1 ? rt_window[0].get<float>() : 0.0f;
    const float rt_hi = rt_window.size() >= 2 ? rt_window[1].get<float>() : 0.0f;
    const float mz_lo = mz_window.size() >= 1 ? mz_window[0].get<float>() : 0.0f;
    const float mz_hi = mz_window.size() >= 2 ? mz_window[1].get<float>() : 0.0f;
    const auto project_id = project.get_project_id();
    auto data = detail::load_analysis_features(project, parameters);
    auto &buffers = data.feature_buffers();
    for (size_t i = 0; i < buffers.size(); ++i) {
        ::mass_spec::spectra::MASS_SPEC_TARGETS targets;
        int counter = 0;
        for (int j = 0; j < buffers[i].size(); ++j) {
            const auto ft = buffers[i].get_feature(j);
            if (detail::excluded_feature(ft, filtered)) continue;
            if (detail::already_had(ft, 1)) continue;
            targets.index.push_back(counter++);
            targets.id.push_back(ft.feature);
            targets.level.push_back(1);
            targets.polarity.push_back(ft.polarity);
            targets.precursor.push_back(false);
            targets.mzmin.push_back(static_cast<float>(ft.mzmin) + mz_lo);
            targets.mzmax.push_back(static_cast<float>(ft.mzmax) + mz_hi);
            targets.rtmin.push_back(static_cast<float>(ft.rtmin) + rt_lo);
            targets.rtmax.push_back(static_cast<float>(ft.rtmax) + rt_hi);
            targets.mz.push_back(static_cast<float>(ft.mz));
            targets.mass.push_back(static_cast<float>(ft.mass));
            targets.rt.push_back(static_cast<float>(ft.rt));
            targets.mobility.push_back(0.0f);
            targets.mobilitymin.push_back(0.0f);
            targets.mobilitymax.push_back(0.0f);
        }
        if (targets.id.empty()) continue;
        if (!std::filesystem::exists(data.file_paths()[i])) continue;
        ::mass_spec::reader::MASS_SPEC_FILE file(data.file_paths()[i]);
        auto spectra = file.get_spectra_targets(targets, data.spectra_headers_at(i), min_traces, 0.0f);
        for (int j = 0; j < buffers[i].size(); ++j) {
            auto ft = buffers[i].get_feature(j);
            if (detail::excluded_feature(ft, filtered)) continue;
            if (detail::already_had(ft, 1)) continue;
            ::mass_spec::spectra::MASS_SPEC_TARGETS_SPECTRA sub;
            for (size_t k = 0; k < spectra.id.size(); ++k) {
                if (spectra.id[k] != ft.feature) continue;
                sub.mz.push_back(spectra.mz[k]);
                sub.intensity.push_back(spectra.intensity[k]);
                if (k < spectra.rt.size()) sub.rt.push_back(spectra.rt[k]);
                if (k < spectra.pre_ce.size()) sub.pre_ce.push_back(spectra.pre_ce[k]);
            }
            auto merged = detail::merge_nta_feature_spectra(sub, mz_clust, presence);
            if (merged.mz.empty()) continue;
            ft.ms1_size = static_cast<int>(merged.mz.size());
            ft.ms1_mz = detail::encode_float_array(merged.mz);
            ft.ms1_intensity = detail::encode_float_array(merged.intensity);
            buffers[i].set_feature(j, ft);
            project.execute_sql("UPDATE MASS_SPEC_NTA_FEATURES SET ms1_size=" + std::to_string(ft.ms1_size) +
                ", ms1_mz=" + detail::sql(ft.ms1_mz) + ", ms1_intensity=" + detail::sql(ft.ms1_intensity) +
                " WHERE project_id=" + detail::sql(project_id) + " AND analysis=" + detail::sql(ft.analysis) +
                " AND feature=" + detail::sql(ft.feature));
        }
    }
    return Json{{"status","finished"},{"info","MS1 spectra loaded."}};
}

Json load_features_ms2(streamfind::Project &project, const Json &parameters) {
    const bool filtered = parameters.value("filtered", false);
    const float min_traces = parameters.value("min_traces_intensity", 10.0);
    const float isolation_window = parameters.value("isolation_window", 1.3);
    const float mz_clust = parameters.value("mz_clust", 0.005);
    const float presence = parameters.value("presence", 0.8);
    if (min_traces < 0 || isolation_window < 0 || mz_clust < 0 || presence < 0 || presence > 1) throw Error(ErrorCode::InvalidArgument, "invalid MS2 spectrum loading parameters");
    const auto project_id = project.get_project_id();
    auto data = detail::load_analysis_features(project, parameters);
    auto &buffers = data.feature_buffers();
    for (size_t i = 0; i < buffers.size(); ++i) {
        ::mass_spec::spectra::MASS_SPEC_TARGETS targets;
        int counter = 0;
        for (int j = 0; j < buffers[i].size(); ++j) {
            const auto ft = buffers[i].get_feature(j);
            if (detail::excluded_feature(ft, filtered)) continue;
            if (detail::already_had(ft, 2)) continue;
            targets.index.push_back(counter++);
            targets.id.push_back(ft.feature);
            targets.level.push_back(2);
            targets.polarity.push_back(ft.polarity);
            targets.precursor.push_back(true);
            targets.mzmin.push_back(static_cast<float>(ft.mz) - isolation_window / 2.0f);
            targets.mzmax.push_back(static_cast<float>(ft.mz) + isolation_window / 2.0f);
            targets.rtmin.push_back(static_cast<float>(ft.rtmin));
            targets.rtmax.push_back(static_cast<float>(ft.rtmax));
            targets.mz.push_back(static_cast<float>(ft.mz));
            targets.mass.push_back(static_cast<float>(ft.mass));
            targets.rt.push_back(static_cast<float>(ft.rt));
            targets.mobility.push_back(0.0f);
            targets.mobilitymin.push_back(0.0f);
            targets.mobilitymax.push_back(0.0f);
        }
        if (targets.id.empty()) continue;
        if (!std::filesystem::exists(data.file_paths()[i])) continue;
        ::mass_spec::reader::MASS_SPEC_FILE file(data.file_paths()[i]);
        auto spectra = file.get_spectra_targets(targets, data.spectra_headers_at(i), 0.0f, min_traces);
        for (int j = 0; j < buffers[i].size(); ++j) {
            auto ft = buffers[i].get_feature(j);
            if (detail::excluded_feature(ft, filtered)) continue;
            if (detail::already_had(ft, 2)) continue;
            ::mass_spec::spectra::MASS_SPEC_TARGETS_SPECTRA sub;
            for (size_t k = 0; k < spectra.id.size(); ++k) {
                if (spectra.id[k] != ft.feature) continue;
                sub.mz.push_back(spectra.mz[k]);
                sub.intensity.push_back(spectra.intensity[k]);
                if (k < spectra.rt.size()) sub.rt.push_back(spectra.rt[k]);
                if (k < spectra.pre_ce.size()) sub.pre_ce.push_back(spectra.pre_ce[k]);
            }
            auto merged = detail::merge_nta_feature_spectra(sub, mz_clust, presence);
            if (merged.mz.empty()) continue;
            ft.ms2_size = static_cast<int>(merged.mz.size());
            ft.ms2_mz = detail::encode_float_array(merged.mz);
            ft.ms2_intensity = detail::encode_float_array(merged.intensity);
            buffers[i].set_feature(j, ft);
            project.execute_sql("UPDATE MASS_SPEC_NTA_FEATURES SET ms2_size=" + std::to_string(ft.ms2_size) +
                ", ms2_mz=" + detail::sql(ft.ms2_mz) + ", ms2_intensity=" + detail::sql(ft.ms2_intensity) +
                " WHERE project_id=" + detail::sql(project_id) + " AND analysis=" + detail::sql(ft.analysis) +
                " AND feature=" + detail::sql(ft.feature));
        }
    }
    return Json{{"status","finished"},{"info","MS2 spectra loaded."}};
}

Json subtract_blank(streamfind::Project &project, const Json &parameters) {
    const float blank_threshold = parameters.value("blank_threshold", 5.0);
    const float rt_expand = parameters.value("rt_expand", 10.0);
    const float mz_expand = parameters.value("mz_expand", 0.005);
    const float min_traces_intensity = parameters.value("min_traces_intensity", 0.0);
    if (blank_threshold < 0 || rt_expand < 0 || mz_expand < 0 || min_traces_intensity < 0)
        throw Error(ErrorCode::InvalidArgument, "invalid blank subtraction parameters");
    auto data = detail::load_analysis_features(project, parameters);
    nta::blank_subtraction::subtract_blank_impl(data, blank_threshold, rt_expand, mz_expand, min_traces_intensity);
    detail::persist_features(project, data);
    return Json{{"status","finished"},{"info","Blank subtraction completed."}};
}

Json filter_features(streamfind::Project &project, const Json &parameters) {
    // Optional numeric filters: null/absent (R NA) disable the filter via NaN.
    auto opt_real = [&](const char *key) -> double {
        auto it = parameters.find(key);
        if (it == parameters.end() || it->is_null()) return std::numeric_limits<double>::quiet_NaN();
        return it->get<double>();
    };
    auto opt_int = [&](const char *key) -> int {
        auto it = parameters.find(key);
        if (it == parameters.end() || it->is_null()) return 0;
        return it->get<int>();
    };
    auto has = [&](const char *key) -> bool {
        auto it = parameters.find(key);
        return it != parameters.end() && !it->is_null();
    };

    const double minSN = opt_real("min_sn");
    const double minIntensity = opt_real("min_intensity");
    const double minArea = opt_real("min_area");
    const double minWidth = opt_real("min_width");
    const double maxWidth = opt_real("max_width");
    const double maxPPM = opt_real("max_ppm");
    const double minFwhmRT = opt_real("min_fwhm_rt");
    const double maxFwhmRT = opt_real("max_fwhm_rt");
    const double minFwhmMZ = opt_real("min_fwhm_mz");
    const double maxFwhmMZ = opt_real("max_fwhm_mz");
    const double minGaussianA = opt_real("min_gaussian_a");
    const double minGaussianMu = opt_real("min_gaussian_mu");
    const double maxGaussianMu = opt_real("max_gaussian_mu");
    const double minGaussianSigma = opt_real("min_gaussian_sigma");
    const double maxGaussianSigma = opt_real("max_gaussian_sigma");
    const double minGaussianR2 = opt_real("min_gaussian_r2");
    const double maxJaggedness = opt_real("max_jaggedness");
    const double minSharpness = opt_real("min_sharpness");
    const double minAsymmetry = opt_real("min_asymmetry");
    const double maxAsymmetry = opt_real("max_asymmetry");
    const double minPlates = opt_real("min_plates");
    const double minRelPresenceReplicate = opt_real("min_rel_presence_replicate");
    const int maxModality = opt_int("max_modality");
    const bool hasMaxModality = has("max_modality");
    const int minSizeEIC = opt_int("min_size_eic");
    const bool hasMinSizeEIC = has("min_size_eic");
    const int minSizeMS1 = opt_int("min_size_ms1");
    const bool hasMinSizeMS1 = has("min_size_ms1");
    const int minSizeMS2 = opt_int("min_size_ms2");
    const bool hasMinSizeMS2 = has("min_size_ms2");

    // only_filled is tri-state: true=keep only filled, false=keep only non-filled,
    // null/absent=disabled (matches R onlyFilled=NA).
    bool hasOnlyFilled = false, onlyFilledValue = false;
    if (auto it = parameters.find("only_filled"); it != parameters.end() && !it->is_null()) {
        hasOnlyFilled = true;
        onlyFilledValue = it->get<bool>();
    }
    const bool removeFilled = parameters.value("remove_filled", false);
    const bool removeIsotopes = parameters.value("remove_isotopes", false);
    const bool removeAdducts = parameters.value("remove_adducts", false);
    const bool removeLosses = parameters.value("remove_losses", false);

    auto data = detail::load_analysis_features(project, parameters);
    nta::filter_features::filter_features_impl(
        data,
        minSN, minIntensity, minArea, minWidth, maxWidth, maxPPM,
        minFwhmRT, maxFwhmRT, minFwhmMZ, maxFwhmMZ,
        minGaussianA, minGaussianMu, maxGaussianMu, minGaussianSigma, maxGaussianSigma, minGaussianR2,
        maxJaggedness, minSharpness, minAsymmetry, maxAsymmetry,
        maxModality, hasMaxModality, minPlates,
        hasOnlyFilled, onlyFilledValue, removeFilled,
        minSizeEIC, hasMinSizeEIC, minSizeMS1, hasMinSizeMS1, minSizeMS2, hasMinSizeMS2,
        minRelPresenceReplicate,
        removeIsotopes, removeAdducts, removeLosses);
    detail::persist_features(project, data);
    return Json{{"status","finished"},{"info","Features filtered."}};
}

Json filter_features_ms2(streamfind::Project &project, const Json &parameters) {
    const int top = parameters.value("top", 0);
    const float min_intensity_ms2 = parameters.value("min_intensity_ms2", NAN);
    const float rel_min_intensity = parameters.value("rel_min_intensity", NAN);
    const bool blank_clean = parameters.value("blank_clean", false);
    const float mz_clust = parameters.value("mz_clust", 0.005);
    const float blank_presence_threshold = parameters.value("blank_presence_threshold", 0.8);
    const float global_presence_threshold = parameters.value("global_presence_threshold", 0.1);
    if (top < 0 || mz_clust < 0 || blank_presence_threshold < 0 || blank_presence_threshold > 1 ||
        global_presence_threshold < 0 || global_presence_threshold > 1)
        throw Error(ErrorCode::InvalidArgument, "invalid MS2 feature filtering parameters");
    auto data = detail::load_analysis_features(project, parameters);
    nta::filter_features_ms2::filter_features_ms2_impl(data, top, min_intensity_ms2, rel_min_intensity,
        blank_clean, mz_clust, blank_presence_threshold, global_presence_threshold);
    detail::persist_features(project, data);
    return Json{{"status","finished"},{"info","MS2 peak lists filtered."}};
}

Json group_features(streamfind::Project &project, const Json &parameters) {
    const auto method = parameters.value("method", std::string("internal_standards"));
    const float rt_deviation = parameters.value("rt_deviation", 5.0);
    const float ppm = parameters.value("ppm", 10.0);
    const int min_samples = parameters.value("min_samples", 1);
    const float bin_size = parameters.value("bin_size", 5.0);
    if (method.empty() || rt_deviation < 0 || ppm < 0 || min_samples < 1 || bin_size <= 0)
        throw Error(ErrorCode::InvalidArgument, "invalid feature grouping parameters");
    auto data = detail::load_analysis_features(project, parameters);
    if (method == "internal_standards") detail::load_internal_standards(project, data);
    nta::alignment::group_features_impl(data, method, rt_deviation, ppm, min_samples, bin_size);
    detail::persist_features(project, data);
    return Json{{"status","finished"},{"info","Features grouped."}};
}

Json fill_features(streamfind::Project &project, const Json &parameters) {
    const bool within_replicate = parameters.value("within_replicate", false);
    const bool filtered = parameters.value("filtered", false);
    const float rt_expand = parameters.value("rt_expand", 10.0);
    const float mz_expand = parameters.value("mz_expand", 0.01);
    const float max_peak_width = parameters.value("max_peak_width", 30.0);
    const float min_traces_intensity = parameters.value("min_traces_intensity", 1000.0);
    const int min_number_traces = parameters.value("min_number_traces", 5);
    const float min_intensity_ms1 = parameters.value("min_intensity", parameters.value("min_intensity_ms1", 5000.0));
    const float rt_apex_deviation = parameters.value("rt_apex_deviation", 5.0);
    const float min_signal_to_noise_ratio = parameters.value("min_signal_to_noise_ratio", 3.0);
    const float min_gaussian_fit = parameters.value("min_gaussian_fit", 0.2);
    if (rt_expand < 0 || mz_expand < 0 || max_peak_width <= 0 || min_traces_intensity < 0 ||
        min_number_traces < 1 || min_intensity_ms1 < 0 || rt_apex_deviation < 0 ||
        min_signal_to_noise_ratio < 0 || min_gaussian_fit < 0 || min_gaussian_fit > 1)
        throw Error(ErrorCode::InvalidArgument, "invalid gap filling parameters");
    auto data = detail::load_analysis_features(project, parameters);
    nta::gap_filling::fill_features_impl(data, within_replicate, filtered, rt_expand, mz_expand,
        max_peak_width, min_traces_intensity, min_number_traces, min_intensity_ms1,
        rt_apex_deviation, min_signal_to_noise_ratio, min_gaussian_fit);
    detail::persist_features(project, data);
    return Json{{"status","finished"},{"info","Feature gaps filled."}};
}

Json create_components(streamfind::Project &project, const Json &parameters) {
    const float min_correlation = parameters.value("min_correlation", 0.8);
    std::vector<float> rt_window;
    const auto rt_window_param = parameters.value("rt_window", Json::array());
    for (const auto &v : rt_window_param) rt_window.push_back(v.get<float>());
    if (rt_window.empty()) rt_window = {0.0f, 0.0f};
    if (min_correlation < 0 || min_correlation > 1)
        throw Error(ErrorCode::InvalidArgument, "invalid componentization parameters");
    auto data = detail::load_analysis_features(project, parameters);
    nta::componentization::create_components_impl(data, rt_window, min_correlation);
    detail::persist_features(project, data);
    return Json{{"status","finished"},{"info","Components created."}};
}

Json annotate_components(streamfind::Project &project, const Json &parameters) {
    const int max_isotopes = parameters.value("max_isotopes", 5);
    const int max_charge = parameters.value("max_charge", 1);
    const int max_gaps = parameters.value("max_gaps", 1);
    const float ppm = parameters.value("ppm", 10.0);
    std::vector<std::string> isotope_elements;
    const auto isotope_elements_param = parameters.value("isotope_elements", Json::array({
        Json("C:1-60"), Json("N:0-10"), Json("O:0-20"), Json("S:0-4"), Json("Cl:0-6"), Json("Br:0-4")}));
    for (const auto &v : isotope_elements_param) isotope_elements.push_back(v.get<std::string>());
    if (max_isotopes < 1 || max_charge < 1 || max_gaps < 0 || ppm < 0)
        throw Error(ErrorCode::InvalidArgument, "invalid annotation parameters");
    auto data = detail::load_analysis_features(project, parameters);
    nta::annotation::annotate_components_impl(data, max_isotopes, max_charge, max_gaps, ppm, isotope_elements);
    detail::persist_features(project, data);
    return Json{{"status","finished"},{"info","Components annotated."}};
}

Json suspect_screening(streamfind::Project &project, const Json &parameters) {
    const double ppm = parameters.value("ppm", 5.0);
    const double sec = parameters.value("sec", 10.0);
    const double ppm_ms2 = parameters.value("ppm_ms2", 10.0);
    const double mzr_ms2 = parameters.value("mzr_ms2", 0.008);
    const double min_cosine_similarity = parameters.value("min_cosine_similarity", 0.7);
    const int min_shared_fragments = parameters.value("min_shared_fragments", 3);
    const bool filtered = parameters.value("filtered", true);
    if (ppm < 0 || sec < 0 || ppm_ms2 < 0 || mzr_ms2 < 0 || min_cosine_similarity < 0 ||
        min_cosine_similarity > 1 || min_shared_fragments < 0)
        throw Error(ErrorCode::InvalidArgument, "invalid suspect screening parameters");
    auto data = detail::load_analysis_features(project, parameters);
    const auto suspects = detail::parse_suspect_targets(parameters);
    nta::suspect_screening::suspect_screening_impl(data, data.analysis_names(), suspects,
        ppm, sec, ppm_ms2, mzr_ms2, min_cosine_similarity, min_shared_fragments, filtered);
    detail::persist_features(project, data);
    detail::persist_suspects(project, data);
    return Json{{"status","finished"},{"info","Suspect screening completed."}};
}

Json filter_suspects(streamfind::Project &project, const Json &parameters) {
    std::vector<std::string> names;
    for (const auto &v : parameters.value("names", Json::array())) names.push_back(v.get<std::string>());
    auto opt_real = [&](const char *key) -> double {
        auto it = parameters.find(key);
        return (it != parameters.end() && !it->is_null()) ? it->get<double>() : std::numeric_limits<double>::quiet_NaN();
    };
    const double min_score = opt_real("min_score");
    const double max_error_rt = opt_real("max_error_rt");
    const double max_error_mass = opt_real("max_error_mass");
    std::vector<int> id_levels;
    for (const auto &v : parameters.value("id_levels", Json::array())) id_levels.push_back(v.get<int>());
    const int min_shared_fragments = parameters.value("min_shared_fragments", 0);
    const double min_cosine_similarity = opt_real("min_cosine_similarity");
    if (min_shared_fragments < 0) throw Error(ErrorCode::InvalidArgument, "invalid suspect filtering parameters");
    auto data = detail::load_analysis_features(project, parameters);
    detail::load_suspects(project, data);
    nta::filter_suspects::filter_suspects_impl(data, names, min_score, max_error_rt, max_error_mass,
        id_levels, min_shared_fragments, min_cosine_similarity);
    detail::persist_suspects(project, data);
    return Json{{"status","finished"},{"info","Suspects filtered."}};
}

Json find_internal_standards(streamfind::Project &project, const Json &parameters) {
    const double ppm = parameters.value("ppm", 5.0);
    const double sec = parameters.value("sec", 10.0);
    const double ppm_ms2 = parameters.value("ppm_ms2", 10.0);
    const double mzr_ms2 = parameters.value("mzr_ms2", 0.008);
    const double min_cosine_similarity = parameters.value("min_cosine_similarity", 0.7);
    const int min_shared_fragments = parameters.value("min_shared_fragments", 3);
    const bool filtered = parameters.value("filtered", true);
    if (ppm < 0 || sec < 0 || ppm_ms2 < 0 || mzr_ms2 < 0 || min_cosine_similarity < 0 ||
        min_cosine_similarity > 1 || min_shared_fragments < 0)
        throw Error(ErrorCode::InvalidArgument, "invalid internal standard parameters");
    auto data = detail::load_analysis_features(project, parameters);
    const auto suspects = detail::parse_suspect_targets(parameters);
    nta::suspect_screening::find_internal_standards_impl(data, data.analysis_names(), suspects,
        ppm, sec, ppm_ms2, mzr_ms2, min_cosine_similarity, min_shared_fragments, filtered);
    detail::persist_features(project, data);
    detail::persist_internal_standards(project, data);
    return Json{{"status","finished"},{"info","Internal standards found."}};
}

Json filter_internal_standards(streamfind::Project &project, const Json &parameters) {
    std::vector<std::string> names;
    for (const auto &v : parameters.value("names", Json::array())) names.push_back(v.get<std::string>());
    auto opt_real = [&](const char *key) -> double {
        auto it = parameters.find(key);
        return (it != parameters.end() && !it->is_null()) ? it->get<double>() : std::numeric_limits<double>::quiet_NaN();
    };
    const double min_score = opt_real("min_score");
    const double max_error_rt = opt_real("max_error_rt");
    const double max_error_mass = opt_real("max_error_mass");
    std::vector<int> id_levels;
    for (const auto &v : parameters.value("id_levels", Json::array())) id_levels.push_back(v.get<int>());
    const int min_shared_fragments = parameters.value("min_shared_fragments", 0);
    const double min_cosine_similarity = opt_real("min_cosine_similarity");
    if (min_shared_fragments < 0) throw Error(ErrorCode::InvalidArgument, "invalid internal standard filtering parameters");
    auto data = detail::load_analysis_features(project, parameters);
    detail::load_internal_standards(project, data);
    nta::filter_internal_standards::filter_internal_standards_impl(data, names, min_score, max_error_rt, max_error_mass,
        id_levels, min_shared_fragments, min_cosine_similarity);
    detail::persist_internal_standards(project, data);
    return Json{{"status","finished"},{"info","Internal standards filtered."}};
}

Json correct_matrix_suppression(streamfind::Project &project, const Json &parameters) {
    const float mp_rt_window = parameters.value("mp_rt_window", 10.0);
    std::string ref_blank_replicate = parameters.value("ref_blank_replicate", std::string(""));
    if (ref_blank_replicate == "NA" || ref_blank_replicate == "NA_character_") ref_blank_replicate.clear();
    if (mp_rt_window <= 0)
        throw Error(ErrorCode::InvalidArgument, "invalid matrix suppression correction parameters");
    auto data = detail::load_analysis_features(project, parameters);
    detail::load_internal_standards(project, data);
    nta::correction_algorithms::correct_matrix_suppression_impl(data, mp_rt_window, ref_blank_replicate);
    detail::persist_features(project, data);
    return Json{{"status","finished"},{"info","Matrix suppression corrected."}};
}

} // namespace streamfind::mass_spec::processing_methods
