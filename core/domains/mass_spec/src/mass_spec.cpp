#include "streamfind/mass_spec/mass_spec.hpp"
#include "streamfind/mass_spec/processing_methods_chromatograms.hpp"

#include <algorithm>
#include <cctype>
#include <filesystem>
#include <stdexcept>
#include <limits>
#include <set>
#include <vector>
#include <map>

namespace streamfind::mass_spec::detail
{
    std::string sql(const std::string &value)
    {
        std::string out = "'";
        for (const char c : value)
            out += c == '\'' ? "''" : std::string(1, c);
        return out + "'";
    }
    std::string lower(std::string value)
    {
        std::transform(value.begin(), value.end(), value.begin(), [](unsigned char c)
                       { return static_cast<char>(std::tolower(c)); });
        return value;
    }
    std::vector<std::string> names(const Json &parameters, const char *key)
    {
        std::vector<std::string> out;
        for (const auto &value : parameters.value(key, Json::array()))
            out.push_back(value.get<std::string>());
        return out;
    }
    std::vector<int> levels(const Json &parameters)
    {
        std::vector<int> out;
        for (const auto &value : parameters.value("levels", Json::array()))
            out.push_back(value.get<int>());
        return out;
    }
    std::vector<int> indices(const Json &parameters)
    {
        std::vector<int> out;
        for (const auto &value : parameters.value("indices", Json::array()))
            out.push_back(value.get<int>());
        return out;
    }
    bool selected(const std::vector<std::string> &names, const std::string &value)
    {
        return names.empty() || std::find(names.begin(), names.end(), value) != names.end();
    }
    bool in_range(float value, const Json &parameters, const char *low, const char *high)
    {
        return (!parameters.contains(low) || value >= parameters.value(low, -std::numeric_limits<float>::infinity())) &&
               (!parameters.contains(high) || value <= parameters.value(high, std::numeric_limits<float>::infinity()));
    }
    using streamfind::mass_spec::TargetRange;
    std::vector<TargetRange> normalize_targets(const Json &p)
    {
        constexpr double proton = 1.007276;
        const double ppm = p.value("ppm", 20.0);
        const double rt_tolerance = p.value("rt_tolerance", 60.0);
        const int charge = std::max(1, std::abs(p.value("charge", 1)));
        const auto sources = p.contains("targets") ? p.at("targets") : Json::array({Json::object()});
        std::vector<TargetRange> out;
        for (std::size_t i = 0; i < sources.size(); ++i)
        {
            const auto &s = sources[i];
            TargetRange t;
            t.id = s.value("id", "target" + std::to_string(i));
            if (s.contains("analyses"))
                t.analyses = s.at("analyses").get<std::vector<std::string>>();
            else
                t.analyses = names(p, "analysis_names");
            if (s.contains("polarity"))
                t.polarities = s.at("polarity").is_array() ? s.at("polarity").get<std::vector<int>>() : std::vector<int>{s.at("polarity").get<int>()};
            else if (p.contains("polarity"))
                t.polarities = {p.at("polarity").get<int>()};
            if (t.polarities.empty())
                t.polarities = {0};
            t.levels = s.value("levels", p.value("levels", Json::array())).get<std::vector<int>>();
            double polarity = t.polarities.front() < 0 ? -1.0 : 1.0;
            double mass = s.value("mass", 0.0);
            double mass_min = s.value("mass_min", mass);
            double mass_max = s.value("mass_max", mass);
            double mz_min = s.value("mz_min", 0.0);
            double mz_max = s.value("mz_max", 0.0);
            const double exact_mz = s.value("mz", 0.0);
            const bool mass_based = mass != 0.0 || mass_min != 0.0 || mass_max != 0.0;
            if (mz_min == 0.0 && mz_max == 0.0 && exact_mz != 0.0)
                mz_min = mz_max = exact_mz;
            if (mz_min == 0.0 && mz_max == 0.0 && mass_based)
            {
                mz_min = mass_min + polarity * proton / charge;
                mz_max = mass_max + polarity * proton / charge;
            }
            if (mz_min != 0.0 || mz_max != 0.0)
            {
                const double mz = mz_min != 0.0 ? mz_min : mz_max;
                const double delta = mz * ppm / 1e6;
                if ((mass_based || exact_mz != 0.0) && mz_min == mz_max)
                {
                    mz_min = mz - delta;
                    mz_max = mz + delta;
                }
                else
                {
                    if (mz_min == 0.0)
                        mz_min = mz - delta;
                    if (mz_max == 0.0)
                        mz_max = mz + delta;
                }
            }
            const double isolation_window = p.value("isolation_window", 0.0);
            if (isolation_window > 0.0)
            {
                mz_min -= isolation_window / 2.0;
                mz_max += isolation_window / 2.0;
            }
            t.mz_min = static_cast<float>(mz_min == 0.0 ? -std::numeric_limits<float>::infinity() : mz_min);
            t.mz_max = static_cast<float>(mz_max == 0.0 ? std::numeric_limits<float>::infinity() : mz_max);
            const double rt = s.value("rt", 0.0);
            t.rt_min = static_cast<float>(s.value("rt_min", rt == 0.0 ? -std::numeric_limits<double>::infinity() : rt - rt_tolerance));
            t.rt_max = static_cast<float>(s.value("rt_max", rt == 0.0 ? std::numeric_limits<double>::infinity() : rt + rt_tolerance));
            out.push_back(std::move(t));
        }
        return out;
    }
    std::vector<TargetRange> normalize_targets_for_operation(const Json &p)
    {
        constexpr double proton = 1.007276;
        const double ppm = p.value("ppm", 20.0);
        const double rt_tolerance = p.value("rt_tolerance", 60.0);
        const int charge = std::max(1, std::abs(p.value("charge", 1)));
        const auto sources = p.contains("targets") ? p.at("targets") : Json::array({Json::object()});
        std::vector<TargetRange> out;
        for (std::size_t i = 0; i < sources.size(); ++i)
        {
            const auto &source = sources[i];
            TargetRange target;
            target.id = source.value("id", "target" + std::to_string(i));
            const auto analysis = source.value("analyses", Json());
            if (!analysis.is_null())
                target.analyses = analysis.is_array() ? analysis.get<std::vector<std::string>>() : std::vector<std::string>{analysis.get<std::string>()};
            else
                target.analyses = names(p, "analysis_names");
            const auto polarity = source.contains("polarity") ? source.at("polarity") : p.value("polarity", Json());
            target.polarities = polarity.is_null() ? std::vector<int>{0} : polarity.is_array() ? polarity.get<std::vector<int>>()
                                                                                               : std::vector<int>{polarity.get<int>()};
            target.levels = source.value("levels", p.value("levels", Json::array())).get<std::vector<int>>();
            const double sign = target.polarities.front() < 0 ? -1.0 : 1.0;
            const double mass = source.value("mass", 0.0);
            const bool mass_based = mass != 0.0 || source.contains("mass_min") || source.contains("mass_max");
            double mz_min = source.value("mz_min", p.value("mz_min", 0.0));
            double mz_max = source.value("mz_max", p.value("mz_max", 0.0));
            const double exact_mz = source.value("mz", 0.0);
            if (mz_min == 0.0 && mz_max == 0.0 && exact_mz != 0.0)
                mz_min = mz_max = exact_mz;
            if (mz_min == 0.0 && mz_max == 0.0 && mass_based)
            {
                mz_min = source.value("mass_min", mass) + sign * proton / charge;
                mz_max = source.value("mass_max", mass) + sign * proton / charge;
            }
            if (mz_min != 0.0 || mz_max != 0.0)
            {
                const double mz = mz_min != 0.0 ? mz_min : mz_max;
                const double delta = mz * ppm / 1e6;
                if ((mass_based || exact_mz != 0.0) && mz_min == mz_max)
                    mz_min = mz - delta, mz_max = mz + delta;
                else
                {
                    if (mz_min == 0.0)
                        mz_min = mz - delta;
                    if (mz_max == 0.0)
                        mz_max = mz + delta;
                }
            }
            const double isolation_window = p.value("isolation_window", 0.0);
            if (isolation_window > 0.0)
            {
                mz_min -= isolation_window / 2.0;
                mz_max += isolation_window / 2.0;
            }
            const double rt = source.value("rt", 0.0);
            target.mz_min = static_cast<float>(mz_min == 0.0 ? -std::numeric_limits<float>::infinity() : mz_min);
            target.mz_max = static_cast<float>(mz_max == 0.0 ? std::numeric_limits<float>::infinity() : mz_max);
            target.rt_min = static_cast<float>(source.value("rt_min", p.value("rt_min", rt == 0.0 ? -std::numeric_limits<double>::infinity() : rt - rt_tolerance)));
            target.rt_max = static_cast<float>(source.value("rt_max", p.value("rt_max", rt == 0.0 ? std::numeric_limits<double>::infinity() : rt + rt_tolerance)));
            out.push_back(std::move(target));
        }
        return out;
    }
    bool target_matches(const TargetRange &t, const std::string &analysis, int polarity, int level, float rt, float mz) { return (t.analyses.empty() || std::find(t.analyses.begin(), t.analyses.end(), analysis) != t.analyses.end()) && (std::find(t.polarities.begin(), t.polarities.end(), 0) != t.polarities.end() || std::find(t.polarities.begin(), t.polarities.end(), polarity) != t.polarities.end()) && (t.levels.empty() || std::find(t.levels.begin(), t.levels.end(), level) != t.levels.end()) && mz >= t.mz_min && mz <= t.mz_max && rt >= t.rt_min && rt <= t.rt_max; }
    Json summarize_eic(const Json &rows)
    {
        struct Value
        {
            Json row;
            double mz = 0.0;
            double mobility = 0.0;
            std::size_t count = 0;
        };
        std::map<std::tuple<std::string, int, std::string, std::string, float>, Value> grouped;
        for (const auto &row : rows)
        {
            const auto key = std::make_tuple(row.at("analysis").get<std::string>(), row.at("polarity").get<int>(), row.value("target_id", ""), row.at("id").get<std::string>(), row.at("rt").get<float>());
            auto &value = grouped[key];
            if (value.count == 0)
                value.row = row;
            value.mz += row.at("mz").get<double>();
            value.mobility += row.at("mobility").get<double>();
            ++value.count;
            value.row["intensity"] = std::max(value.row.value("intensity", 0.0), row.value("intensity", 0.0));
        }
        Json out = Json::array();
        for (auto &[key, value] : grouped)
        {
            if (value.count == 0)
                continue;
            value.row["level"] = 1;
            value.row["mz"] = value.mz / value.count;
            value.row["mobility"] = value.mobility / value.count;
            out.push_back(std::move(value.row));
        }
        return out;
    }
    Json merge_ms_rows(const Json &rows, double mz_clust, double presence)
    {
        using Key = std::tuple<std::string, std::string, int>;
        std::map<Key, std::vector<Json>> groups;
        for (const auto &row : rows)
            groups[{row.value("analysis", ""), row.value("id", ""), row.value("polarity", 0)}].push_back(row);
        Json out = Json::array();
        const double tolerance = std::max(0.0, mz_clust);
        const double threshold = std::clamp(presence, 0.0, 1.0);
        for (auto &[key, values] : groups)
        {
            std::sort(values.begin(), values.end(), [](const Json &left, const Json &right) { return left.value("mz", 0.0) < right.value("mz", 0.0); });
            std::set<double> all_rt;
            for (const auto &row : values) all_rt.insert(row.value("rt", 0.0));
            std::size_t start = 0;
            while (start < values.size())
            {
                std::size_t end = start + 1;
                while (end < values.size() && values[end].value("mz", 0.0) - values[end - 1].value("mz", 0.0) <= tolerance) ++end;
                std::set<double> cluster_rt;
                for (std::size_t i = start; i < end; ++i) cluster_rt.insert(values[i].value("rt", 0.0));
                if (threshold > 0.0 && !all_rt.empty() && static_cast<double>(cluster_rt.size()) < threshold * static_cast<double>(all_rt.size())) { start = end; continue; }
                double intensity_sum = 0.0, weighted_mz = 0.0, rt_sum = 0.0, mobility_sum = 0.0, max_intensity = 0.0;
                Json row = values[start];
                for (std::size_t i = start; i < end; ++i) {
                    const double intensity = values[i].value("intensity", 0.0);
                    intensity_sum += intensity;
                    weighted_mz += values[i].value("mz", 0.0) * intensity;
                    rt_sum += values[i].value("rt", 0.0);
                    mobility_sum += values[i].value("mobility", 0.0);
                    max_intensity = std::max(max_intensity, intensity);
                }
                if (intensity_sum > 0.0) {
                    row["level"] = row.value("level", 1);
                    row["mz"] = weighted_mz / intensity_sum;
                    row["intensity"] = max_intensity;
                    row["rt"] = rt_sum / static_cast<double>(end - start);
                    row["mobility"] = mobility_sum / static_cast<double>(end - start);
                    out.push_back(std::move(row));
                }
                start = end;
            }
        }
        std::sort(out.begin(), out.end(), [](const Json &left, const Json &right) { return std::tie(left["analysis"], left["id"], left["mz"]) < std::tie(right["analysis"], right["id"], right["mz"]); });
        return out;
    }
}

namespace streamfind::mass_spec
{

    Project::Project(streamfind::Project &project) : project_(project) { create_schema(); }

    void Project::create_schema()
    {
        project_.execute_sql("CREATE TABLE IF NOT EXISTS MASS_SPEC_ANALYSES (project_id VARCHAR NOT NULL, analysis VARCHAR NOT NULL, replicate VARCHAR, blank VARCHAR, file_name VARCHAR, file_path VARCHAR NOT NULL, file_dir VARCHAR, file_extension VARCHAR, format VARCHAR, type VARCHAR, time_stamp VARCHAR, number_spectra INTEGER, number_chromatograms INTEGER, number_spectra_binary_arrays INTEGER, min_mz DOUBLE, max_mz DOUBLE, start_rt DOUBLE, end_rt DOUBLE, has_ion_mobility BOOLEAN, concentration DOUBLE, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY(project_id, analysis))");
        project_.execute_sql("CREATE TABLE IF NOT EXISTS MASS_SPEC_SPECTRA_HEADERS (project_id VARCHAR NOT NULL, analysis VARCHAR NOT NULL, index INTEGER NOT NULL, scan INTEGER, array_length INTEGER, level INTEGER, mode INTEGER, polarity INTEGER, configuration INTEGER, lowmz DOUBLE, highmz DOUBLE, bpmz DOUBLE, bpint DOUBLE, tic DOUBLE, rt DOUBLE, mobility DOUBLE, window_mz DOUBLE, window_mzlow DOUBLE, window_mzhigh DOUBLE, precursor_mz DOUBLE, precursor_intensity DOUBLE, precursor_charge INTEGER, activation_ce DOUBLE, PRIMARY KEY(project_id, analysis, index))");
        project_.execute_sql("CREATE TABLE IF NOT EXISTS MASS_SPEC_CHROMATOGRAMS_HEADERS (project_id VARCHAR NOT NULL, analysis VARCHAR NOT NULL, index INTEGER NOT NULL, chromatogram_id VARCHAR, array_length INTEGER, polarity INTEGER, precursor_mz DOUBLE, activation_ce DOUBLE, product_mz DOUBLE, signal_type VARCHAR, chromatogram_type VARCHAR, detector VARCHAR, channel VARCHAR, units VARCHAR, wavelength_nm DOUBLE, interval_ms DOUBLE, start_time DOUBLE, end_time DOUBLE, intensity_multiplier DOUBLE, PRIMARY KEY(project_id, analysis, index))");
    }

    Json Project::add_analyses(const Json &parameters)
    {
        create_schema();
        Json added = Json::array();
        for (const auto &item : parameters.at("analyses"))
        {
            const std::filesystem::path path = item.at("path").get<std::string>();
            const auto extension = detail::lower(path.extension().string());
            if (extension != ".mzml" && extension != ".mzxml" && extension != ".lcd" && extension != ".asc" && extension != ".d")
                throw streamfind::Error(streamfind::ErrorCode::InvalidArgument, "unsupported mass spectrometry file extension: " + extension);
            ::mass_spec::reader::MASS_SPEC_FILE file(path.string());
            const auto summary = file.get_summary();
            const auto analysis = path.stem().string();
            const auto replicate = item.value("replicate_name", "");
            const auto blank = item.value("blank_name", "");
            const auto query = "INSERT OR REPLACE INTO MASS_SPEC_ANALYSES (project_id, analysis, replicate, blank, file_name, file_path, file_dir, file_extension, format, type, time_stamp, number_spectra, number_chromatograms, number_spectra_binary_arrays, min_mz, max_mz, start_rt, end_rt, has_ion_mobility, concentration) VALUES (" + detail::sql(project_.get_project_id()) + "," + detail::sql(analysis) + "," + detail::sql(replicate) + "," + detail::sql(blank) + "," + detail::sql(path.filename().string()) + "," + detail::sql(path.string()) + "," + detail::sql(path.parent_path().string()) + "," + detail::sql(extension) + "," + detail::sql(summary.format) + ",'MS',''," + std::to_string(summary.number_spectra) + "," + std::to_string(summary.number_chromatograms) + "," + std::to_string(summary.number_spectra_binary_arrays) + "," + std::to_string(summary.min_mz) + "," + std::to_string(summary.max_mz) + "," + std::to_string(summary.start_rt) + "," + std::to_string(summary.end_rt) + "," + (summary.has_ion_mobility ? "true" : "false") + ",NULL)";
            project_.execute_sql(query);
            added.push_back({{"analysis", analysis}, {"file_path", path.string()}, {"replicate", replicate}, {"blank", blank}});
        }
        return added;
    }

    Json Project::remove_analyses(const Json &parameters)
    {
        create_schema();
        Json removed = Json::array();
        for (const auto &value : parameters.at("analysis_names"))
        {
            const auto name = value.get<std::string>();
            project_.execute_sql("DELETE FROM MASS_SPEC_ANALYSES WHERE project_id = " + detail::sql(project_.get_project_id()) + " AND analysis = " + detail::sql(name));
            removed.push_back(name);
        }
        return removed;
    }

    Json Project::get_analyses_info(const Json &)
    {
        create_schema();
        return project_.query_json("SELECT analysis, replicate, blank, file_path, format, number_spectra, number_chromatograms FROM MASS_SPEC_ANALYSES WHERE project_id = " + detail::sql(project_.get_project_id()) + " ORDER BY analysis");
    }

    Json analysis_column(streamfind::Project &project, const char *column, bool numeric = false)
    {
        Json out = Json::array();
        const std::string expression = numeric ? std::string("COALESCE(CAST(concentration AS VARCHAR), '')") : "COALESCE(" + std::string(column) + ", '')";
        for (const auto &row : project.query_json("SELECT " + expression + " AS value FROM MASS_SPEC_ANALYSES WHERE project_id = " + detail::sql(project.get_project_id()) + " ORDER BY analysis"))
        {
            const auto value = row.value("value", "");
            out.push_back(numeric && !value.empty() ? Json(std::stod(value)) : Json(value));
        }
        return out;
    }
    Json Project::get_analysis_names(const Json &)
    {
        create_schema();
        return analysis_column(project_, "analysis");
    }
    Json Project::get_replicate_names(const Json &)
    {
        create_schema();
        return analysis_column(project_, "replicate");
    }
    Json Project::get_blank_names(const Json &)
    {
        create_schema();
        return analysis_column(project_, "blank");
    }
    Json Project::get_concentrations(const Json &)
    {
        create_schema();
        return analysis_column(project_, "concentration", true);
    }

    Json update_analysis_values(streamfind::Project &project, const Json &parameters, const char *key, const char *column)
    {
        const auto names = project.query_json("SELECT analysis FROM MASS_SPEC_ANALYSES WHERE project_id = " + detail::sql(project.get_project_id()) + " ORDER BY analysis");
        const auto values = parameters.at(key);
        if (values.size() != names.size())
            throw streamfind::Error(streamfind::ErrorCode::InvalidArgument, std::string(key) + " length must match analyses");
        for (std::size_t i = 0; i < names.size(); ++i)
        {
            const auto analysis = names[i].at("analysis").get<std::string>();
            const auto value = values[i];
            const auto expression = std::string(column) == "concentration" ? std::to_string(value.get<double>()) : detail::sql(value.get<std::string>());
            project.execute_sql(std::string("UPDATE MASS_SPEC_ANALYSES SET ") + column + " = " + expression + " WHERE project_id = " + detail::sql(project.get_project_id()) + " AND analysis = " + detail::sql(analysis));
        }
        return Json{{"updated", values.size()}};
    }
    Json Project::set_replicate_names(const Json &p)
    {
        create_schema();
        return update_analysis_values(project_, p, "replicate_names", "replicate");
    }
    Json Project::set_blank_names(const Json &p)
    {
        create_schema();
        return update_analysis_values(project_, p, "blank_names", "blank");
    }
    Json Project::set_concentrations(const Json &p)
    {
        create_schema();
        return update_analysis_values(project_, p, "concentrations", "concentration");
    }

    Json Project::get_spectra_headers(const Json &parameters)
    {
        create_schema();
        Json out = Json::array();
        const auto wanted = detail::names(parameters, "analysis_names");
        const auto rows = project_.query_json("SELECT analysis, file_path FROM MASS_SPEC_ANALYSES WHERE project_id = " + detail::sql(project_.get_project_id()) + " ORDER BY analysis");
        for (const auto &row : rows)
            if (detail::selected(wanted, row.at("analysis").get<std::string>()))
            {
                ::mass_spec::reader::MASS_SPEC_FILE file(row.at("file_path").get<std::string>());
                const auto h = file.get_spectra_headers();
                for (std::size_t i = 0; i < h.index.size(); ++i)
                    out.push_back({{"analysis", row.at("analysis")}, {"index", h.index[i]}, {"scan", h.scan[i]}, {"array_length", h.array_length[i]}, {"level", h.level[i]}, {"mode", h.mode[i]}, {"polarity", h.polarity[i]}, {"configuration", h.configuration[i]}, {"lowmz", h.lowmz[i]}, {"highmz", h.highmz[i]}, {"bpmz", h.bpmz[i]}, {"bpint", h.bpint[i]}, {"tic", h.tic[i]}, {"rt", h.rt[i]}, {"mobility", h.mobility[i]}, {"window_mz", h.window_mz[i]}, {"window_mzlow", h.window_mzlow[i]}, {"window_mzhigh", h.window_mzhigh[i]}, {"precursor_mz", h.precursor_mz[i]}, {"precursor_intensity", h.precursor_intensity[i]}, {"precursor_charge", h.precursor_charge[i]}, {"activation_ce", h.activation_ce[i]}});
            }
        return out;
    }

    Json Project::get_chromatograms_headers(const Json &parameters)
    {
        create_schema();
        Json out = Json::array();
        const auto wanted = detail::names(parameters, "analysis_names");
        const auto rows = project_.query_json("SELECT analysis, file_path FROM MASS_SPEC_ANALYSES WHERE project_id = " + detail::sql(project_.get_project_id()) + " ORDER BY analysis");
        for (const auto &row : rows)
            if (detail::selected(wanted, row.at("analysis").get<std::string>()))
            {
                ::mass_spec::reader::MASS_SPEC_FILE file(row.at("file_path").get<std::string>());
                const auto h = file.get_chromatograms_headers();
                for (std::size_t i = 0; i < h.index.size(); ++i)
                    out.push_back({{"analysis", row.at("analysis")}, {"index", h.index[i]}, {"chromatogram_id", h.chromatogram_id[i]}, {"array_length", h.array_length[i]}, {"polarity", h.polarity[i]}, {"precursor_mz", h.precursor_mz[i]}, {"activation_ce", h.activation_ce[i]}, {"product_mz", h.product_mz[i]}, {"signal_type", h.signal_type[i]}, {"chromatogram_type", h.chromatogram_type[i]}, {"detector", h.detector[i]}, {"channel", h.channel[i]}, {"units", h.units[i]}, {"wavelength_nm", h.wavelength_nm[i]}, {"interval_ms", h.interval_ms[i]}, {"start_time", h.start_time[i]}, {"end_time", h.end_time[i]}, {"intensity_multiplier", h.intensity_multiplier[i]}});
            }
        return out;
    }

    Json Project::get_spectra_tic(const Json &parameters)
    {
        Json out = Json::array();
        const auto headers = get_spectra_headers(parameters);
        const auto rows = project_.query_json("SELECT analysis, replicate FROM MASS_SPEC_ANALYSES WHERE project_id = " + detail::sql(project_.get_project_id()));
        std::map<std::string, std::string> replicate;
        for (const auto &row : rows)
            replicate[row.at("analysis").get<std::string>()] = row.value("replicate", "");
        const auto level_values = detail::levels(parameters);
        for (const auto &h : headers)
            if ((level_values.empty() || std::find(level_values.begin(), level_values.end(), h.at("level").get<int>()) != level_values.end()) && detail::in_range(h.at("rt").get<float>(), parameters, "rt_min", "rt_max"))
                out.push_back({{"analysis", h.at("analysis")}, {"replicate", replicate[h.at("analysis").get<std::string>()]}, {"polarity", h.at("polarity")}, {"level", h.at("level")}, {"rt", h.at("rt")}, {"mobility", h.at("mobility")}, {"tic", h.at("tic")}, {"bpmz", h.at("bpmz")}, {"bpint", h.at("bpint")}});
        return out;
    }

    Json Project::get_raw_spectra(const Json &parameters)
    {
        create_schema();
        Json out = Json::array();
        const auto targets = detail::normalize_targets_for_operation(parameters);
        const auto rows = project_.query_json("SELECT analysis, file_path, replicate FROM MASS_SPEC_ANALYSES WHERE project_id = " + detail::sql(project_.get_project_id()) + " ORDER BY analysis");
        for (const auto &row : rows)
        {
            const auto analysis = row.at("analysis").get<std::string>();
            ::mass_spec::reader::MASS_SPEC_FILE file(row.at("file_path").get<std::string>());
            const auto headers = file.get_spectra_headers();
            const auto spectra = file.get_spectra();
            for (std::size_t i = 0; i < spectra.size() && i < headers.index.size(); ++i)
            {
                if (spectra[i].size() < 2)
                    continue;
                for (std::size_t j = 0; j < spectra[i][0].size() && j < spectra[i][1].size(); ++j)
                {
                    const double intensity = spectra[i][1][j];
                    if ((headers.level[i] == 1 && intensity < parameters.value("min_intensity_ms1", 0.0)) ||
                        (headers.level[i] >= 2 && intensity < parameters.value("min_intensity_ms2", 0.0)))
                        continue;
                    for (const auto &target : targets)
                        if (detail::target_matches(target, analysis, headers.polarity[i], headers.level[i], headers.rt[i], spectra[i][0][j]))
                            out.push_back({{"analysis", analysis}, {"replicate", row.value("replicate", "")}, {"target_id", target.id}, {"id", analysis + ":" + std::to_string(headers.index[i])}, {"polarity", headers.polarity[i]}, {"level", headers.level[i]}, {"pre_mz", headers.precursor_mz[i]}, {"pre_mzlow", headers.window_mzlow[i]}, {"pre_mzhigh", headers.window_mzhigh[i]}, {"pre_ce", headers.activation_ce[i]}, {"rt", headers.rt[i]}, {"mobility", headers.mobility[i]}, {"mz", spectra[i][0][j]}, {"intensity", spectra[i][1][j]}});
                }
            }
        }
        return out;
    }
    Json Project::get_raw_spectra_eic(const Json &p)
    {
        Json copy = p;
        copy["levels"] = Json::array({1});
        return detail::summarize_eic(get_raw_spectra(copy));
    }
    Json Project::get_raw_spectra_ms1(const Json &p)
    {
        Json copy = p;
        copy["levels"] = Json::array({1});
        return detail::merge_ms_rows(get_raw_spectra(copy), copy.value("mz_clust", 0.003), copy.value("presence", 0.8));
    }
    Json Project::get_raw_spectra_ms2(const Json &p)
    {
        Json copy = p;
        copy["levels"] = Json::array({2});
        return detail::merge_ms_rows(get_raw_spectra(copy), copy.value("mz_clust", 0.005), copy.value("presence", 0.0));
    }

    Json Project::get_chromatograms(const Json &parameters)
    {
        project_.execute_sql("CREATE TABLE IF NOT EXISTS MASS_SPEC_CHROMATOGRAMS (project_id VARCHAR NOT NULL, analysis VARCHAR NOT NULL, chromatogram_id VARCHAR NOT NULL, rt DOUBLE NOT NULL, raw_intensity DOUBLE NOT NULL, baseline DOUBLE NOT NULL DEFAULT 0, intensity DOUBLE NOT NULL, created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY(project_id, analysis, chromatogram_id, rt))");
        std::string query = "SELECT project_id, analysis, chromatogram_id, rt, raw_intensity, baseline, intensity FROM MASS_SPEC_CHROMATOGRAMS WHERE project_id = " + detail::sql(project_.get_project_id());
        const auto wanted = detail::names(parameters, "analysis_names");
        if (!wanted.empty()) {
            query += " AND analysis IN (";
            for (std::size_t i = 0; i < wanted.size(); ++i) query += (i ? "," : "") + detail::sql(wanted[i]);
            query += ")";
        }
        query += " ORDER BY analysis, chromatogram_id, rt";
        auto rows = project_.query_json(query);
        for (auto &row : rows) {
            row["rt"] = std::stod(row.at("rt").get<std::string>());
            row["raw_intensity"] = std::stod(row.at("raw_intensity").get<std::string>());
            row["baseline"] = std::stod(row.at("baseline").get<std::string>());
            row["intensity"] = std::stod(row.at("intensity").get<std::string>());
        }
        return rows;
    }

    Json Project::get_raw_chromatograms(const Json &parameters)
    {
        std::vector<int> indices;
        for (const auto &value : parameters.value("indices", Json::array())) indices.push_back(value.get<int>());
        Json output = Json::array();
        const auto wanted = detail::names(parameters, "analysis_names");
        const auto rows = project_.query_json("SELECT analysis, file_path FROM MASS_SPEC_ANALYSES WHERE project_id = " + detail::sql(project_.get_project_id()) + " ORDER BY analysis");
        for (const auto &row : rows) {
            const auto analysis = row.at("analysis").get<std::string>();
            if (!detail::selected(wanted, analysis)) continue;
            ::mass_spec::reader::MASS_SPEC_FILE file(row.at("file_path").get<std::string>());
            const auto headers = file.get_chromatograms_headers(indices);
            const auto arrays = file.get_chromatograms(indices);
            for (std::size_t i = 0; i < arrays.size() && i < headers.chromatogram_id.size(); ++i) {
                if (arrays[i].size() < 2) continue;
                const auto &times = arrays[i][0];
                const auto &intensities = arrays[i][1];
                const auto count = std::min(times.size(), intensities.size());
                for (std::size_t j = 0; j < count; ++j)
                    output.push_back({{"project_id", project_.get_project_id()}, {"analysis", analysis},
                                      {"chromatogram_id", headers.chromatogram_id[i]}, {"rt", times[j]},
                                      {"raw_intensity", intensities[j]}, {"baseline", 0.0},
                                      {"intensity", intensities[j]}});
            }
        }
        return output;
    }

    Json Project::get_features(const Json &p)
    {
        const double ppm = p.value("ppm", 20.0);
        const double rt_tolerance = p.value("rt_tolerance", 60.0);
        if (ppm < 0.0 || rt_tolerance < 0.0)
            throw streamfind::Error(streamfind::ErrorCode::InvalidArgument, "ppm and rt_tolerance must be non-negative");
        auto number = [](double value) { return std::to_string(value); };
        auto values = [](const Json &value) {
            return value.is_array() ? value.get<std::vector<int>>() : std::vector<int>{value.get<int>()};
        };
        std::vector<std::string> filters;
        const auto analyses = detail::names(p, "analysis_names");
        if (!analyses.empty()) {
            std::string filter = "analysis IN (";
            for (std::size_t i = 0; i < analyses.size(); ++i) filter += (i ? "," : "") + detail::sql(analyses[i]);
            filters.push_back(filter + ")");
        }
        const auto targets = p.value("targets", Json::array({Json::object()}));
        std::vector<std::string> target_filters;
        for (const auto &target : targets) {
            std::vector<std::string> match;
            const auto target_analyses = target.contains("analyses") ? (target.at("analyses").is_array() ? target.at("analyses").get<std::vector<std::string>>() : std::vector<std::string>{target.at("analyses").get<std::string>()}) : analyses;
            if (!target_analyses.empty()) {
                std::string filter = "analysis IN (";
                for (std::size_t i = 0; i < target_analyses.size(); ++i) filter += (i ? "," : "") + detail::sql(target_analyses[i]);
                match.push_back(filter + ")");
            }
            const auto polarity = target.contains("polarity") ? values(target.at("polarity")) : (p.contains("polarity") ? values(p.at("polarity")) : std::vector<int>{});
            if (!polarity.empty()) {
                std::string filter = "polarity IN (";
                for (std::size_t i = 0; i < polarity.size(); ++i) filter += (i ? "," : "") + std::to_string(polarity[i]);
                match.push_back(filter + ")");
            }
            auto add_window = [&](const char *column, const char *exact, const char *minimum, const char *maximum) {
                if (target.contains(exact)) {
                    const double center = target.at(exact).get<double>();
                    const double delta = std::abs(center) * ppm / 1e6;
                    match.push_back(std::string(column) + " BETWEEN " + number(center - delta) + " AND " + number(center + delta));
                } else if (target.contains(minimum) || target.contains(maximum)) {
                    std::string range = std::string(column) + " >= " + number(target.value(minimum, -1e300));
                    if (target.contains(maximum)) range += " AND " + std::string(column) + " <= " + number(target.at(maximum).get<double>());
                    match.push_back(std::move(range));
                }
            };
            add_window("mass", "mass", "mass_min", "mass_max");
            add_window("mz", "mz", "mz_min", "mz_max");
            if (target.contains("rt")) {
                const double center = target.at("rt").get<double>();
                match.push_back("rt BETWEEN " + number(center - rt_tolerance) + " AND " + number(center + rt_tolerance));
            } else if (target.contains("rt_min") || target.contains("rt_max")) {
                std::string range = "rt >= " + number(target.value("rt_min", -1e300));
                if (target.contains("rt_max")) range += " AND rt <= " + number(target.at("rt_max").get<double>());
                match.push_back(std::move(range));
            }
            if (!match.empty()) {
                std::string expression = "(";
                for (std::size_t i = 0; i < match.size(); ++i) expression += (i ? " AND " : "") + match[i];
                target_filters.push_back(expression + ")");
            }
        }
        if (!target_filters.empty()) {
            std::string filter = "(";
            for (std::size_t i = 0; i < target_filters.size(); ++i) filter += (i ? " OR " : "") + target_filters[i];
            filters.push_back(filter + ")");
        }
        std::string query = "SELECT * FROM MASS_SPEC_NTA_FEATURES WHERE project_id = " + detail::sql(project_.get_project_id());
        for (const auto &filter : filters) query += " AND " + filter;
        query += " ORDER BY analysis, rt, feature";
        return project_.query_json(query);
    }

}
