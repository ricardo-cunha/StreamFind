#include "project_non_target_analysis.h"

#include "../project/project.h"
#include "../mass_spec/targets.h"

#include <cmath>
#include <functional>
#include <iomanip>
#include <limits>
#include <map>
#include <set>
#include <unordered_set>
#include <unordered_map>

namespace nts
{

  namespace
  {


    using project::json;
      using project::error::ERROR_CODE;
      using project::ERROR;
    using project::PROJECT;
    namespace detail = project;

    detail::CONNECTION_GUARD connect_checked(const std::shared_ptr<project::api::CONTEXT> &ctx)
    {
      if (!ctx || ctx->db_path.empty() || ctx->project_id.empty())
      {
        throw ERROR(ERROR_CODE::InvalidArgument, "Project context is not initialized");
      }
      return detail::CONNECTION_GUARD(ctx);
    }

    inline double nullable_double(double value) { return value; }

    inline int nullable_int(int value) { return value; }

    std::vector<std::string> sanitize_analyses(const std::vector<std::string> &analyses)
    {
      return mass_spec::sanitize_analyses(analyses);
    }

    std::string placeholders(std::size_t count)
    {
      std::string sql;
      sql.reserve(count * 3);
      for (std::size_t i = 0; i < count; ++i)
      {
        if (i > 0)
        {
          sql += ", ";
        }
        sql += "?";
      }
      return sql;
    }

    nts::NTS_INFO nts_info_from_analysis_rows(const std::vector<mass_spec::MS_ANALYSIS_ROW> &analyses)
    {
      nts::NTS_INFO info;
      info.analyses.reserve(analyses.size());
      info.replicates.reserve(analyses.size());
      info.blanks.reserve(analyses.size());
      info.files.reserve(analyses.size());
      for (const auto &row : analyses)
      {
        info.analyses.push_back(row.analysis);
        info.replicates.push_back(row.replicate);
        info.blanks.push_back(row.blank);
        info.files.push_back(row.file_path);
      }
      return info;
    }

    mass_spec::MS_SPECTRA_HEADERS spectra_headers_from_rows(const std::vector<mass_spec::MS_SPECTRA_HEADER_ROW> &rows)
    {
      mass_spec::MS_SPECTRA_HEADERS out;
      out.resize_all(static_cast<int>(rows.size()));
      for (std::size_t i = 0; i < rows.size(); ++i)
      {
        out.index[i] = rows[i].index;
        out.scan[i] = rows[i].scan;
        out.array_length[i] = rows[i].array_length;
        out.level[i] = rows[i].level;
        out.mode[i] = rows[i].mode;
        out.polarity[i] = rows[i].polarity;
        out.lowmz[i] = static_cast<float>(rows[i].lowmz);
        out.highmz[i] = static_cast<float>(rows[i].highmz);
        out.bpmz[i] = static_cast<float>(rows[i].bpmz);
        out.bpint[i] = static_cast<float>(rows[i].bpint);
        out.tic[i] = static_cast<float>(rows[i].tic);
        out.configuration[i] = rows[i].configuration;
        out.rt[i] = static_cast<float>(rows[i].rt);
        out.mobility[i] = static_cast<float>(rows[i].mobility);
        out.window_mz[i] = static_cast<float>(rows[i].window_mz);
        out.window_mzlow[i] = static_cast<float>(rows[i].window_mzlow);
        out.window_mzhigh[i] = static_cast<float>(rows[i].window_mzhigh);
        out.precursor_mz[i] = static_cast<float>(rows[i].precursor_mz);
        out.precursor_intensity[i] = static_cast<float>(rows[i].precursor_intensity);
        out.precursor_charge[i] = rows[i].precursor_charge;
        out.activation_ce[i] = static_cast<float>(rows[i].activation_ce);
      }
      return out;
    }

    std::vector<mass_spec::MS_ANALYSIS_ROW> load_selected_analyses(
        const std::shared_ptr<CONTEXT> &ctx,
        const std::vector<std::string> &analyses)
    {
      mass_spec::PROJECT_MASS_SPEC ms(ctx);
      const auto all_rows = ms.get_analyses();
      const auto selected = sanitize_analyses(analyses);
      if (selected.empty())
      {
        return all_rows;
      }
      std::unordered_map<std::string, mass_spec::MS_ANALYSIS_ROW> row_by_analysis;
      for (const auto &row : all_rows)
      {
        row_by_analysis.emplace(row.analysis, row);
      }
      std::vector<mass_spec::MS_ANALYSIS_ROW> out;
      out.reserve(selected.size());
      for (const auto &analysis : selected)
      {
        const auto it = row_by_analysis.find(analysis);
        if (it != row_by_analysis.end())
        {
          out.push_back(it->second);
        }
      }
      return out;
    }

    std::vector<mass_spec::MS_SPECTRA_HEADERS> load_selected_headers(
        const std::shared_ptr<CONTEXT> &ctx,
        const std::vector<mass_spec::MS_ANALYSIS_ROW> &analyses)
    {
      mass_spec::PROJECT_MASS_SPEC ms(ctx);
      std::vector<mass_spec::MS_SPECTRA_HEADERS> out;
      out.reserve(analyses.size());
      for (const auto &analysis : analyses)
      {
        out.push_back(spectra_headers_from_rows(ms.get_spectra_headers({analysis.analysis})));
      }
      return out;
    }

    std::vector<std::string> analysis_names_from_rows(const std::vector<mass_spec::MS_ANALYSIS_ROW> &analyses)
    {
      std::vector<std::string> out;
      out.reserve(analyses.size());
      for (const auto &analysis : analyses)
      {
        out.push_back(analysis.analysis);
      }
      return out;
    }

    std::vector<std::string> collect_analysis_polarities(
        const std::shared_ptr<CONTEXT> &ctx,
        const std::vector<std::string> &analyses)
    {
      mass_spec::PROJECT_MASS_SPEC ms(ctx);
      const auto headers = ms.get_spectra_headers(analyses);
      std::unordered_map<std::string, std::vector<std::string>> by_analysis;
      for (const auto &header : headers)
      {
        if (header.polarity == 1)
        {
          by_analysis[header.analysis].push_back("1");
        }
        else if (header.polarity == -1)
        {
          by_analysis[header.analysis].push_back("-1");
        }
      }

      std::vector<std::string> out;
      out.reserve(analyses.size());
      for (const auto &analysis : analyses)
      {
        auto it = by_analysis.find(analysis);
        if (it == by_analysis.end())
        {
          out.push_back("1|-1");
          continue;
        }
        bool has_positive = false;
        bool has_negative = false;
        for (const auto &polarity : it->second)
        {
          has_positive = has_positive || polarity == "1";
          has_negative = has_negative || polarity == "-1";
        }
        if (has_positive && has_negative)
        {
          out.push_back("1|-1");
        }
        else if (has_negative)
        {
          out.push_back("-1");
        }
        else
        {
          out.push_back("1");
        }
      }
      return out;
    }

    bool has_target_request(const mass_spec::MS_TARGETS_INPUT &targets)
    {
      return targets.size > 0;
    }

    template <typename Row>
    std::vector<Row> filter_rows_by_feature_group(
        const std::vector<Row> &rows,
        const std::vector<std::string> &groups,
        const std::unordered_map<std::string, std::string> &feature_group_by_key)
    {
      if (groups.empty())
      {
        return rows;
      }
      std::unordered_set<std::string> allowed(groups.begin(), groups.end());
      std::vector<Row> out;
      out.reserve(rows.size());
      for (const auto &row : rows)
      {
        const auto key = row.analysis + "\n" + row.feature;
        const auto it = feature_group_by_key.find(key);
        if (it != feature_group_by_key.end() && allowed.find(it->second) != allowed.end())
        {
          out.push_back(row);
        }
      }
      return out;
    }

    std::unordered_map<std::string, std::string> load_feature_groups_for_analyses(
        const std::shared_ptr<CONTEXT> &ctx,
        const std::vector<std::string> &analyses)
    {
      auto guard = connect_checked(ctx);
      std::unordered_map<std::string, std::string> out;
      std::string sql = "SELECT analysis, feature, feature_group FROM NTS_FEATURES WHERE project_id = ?";
      if (!analyses.empty())
      {
        sql += " AND analysis IN (";
        sql += placeholders(analyses.size());
        sql += ")";
      }
      detail::run_prepared(guard.get(), sql, "load NTS feature groups", [&](duckdb_prepared_statement statement)
                           {
                         idx_t bind_index = 1;
                         duckdb_bind_varchar(statement, bind_index++, ctx->project_id.c_str());
                         for (const auto& analysis : analyses) {
                           duckdb_bind_varchar(statement, bind_index++, analysis.c_str());
                         } }, [&](duckdb_result &result)
                           {
                         const idx_t count = duckdb_row_count(&result);
                         out.reserve(static_cast<std::size_t>(count));
                         for (idx_t row = 0; row < count; ++row) {
                           const auto analysis = detail::result_varchar(&result, 0, row);
                           const auto feature = detail::result_varchar(&result, 1, row);
                           const auto feature_group = detail::result_varchar(&result, 2, row);
                           out.emplace(analysis + "\n" + feature, feature_group);
                         } });
      return out;
    }

    template <typename Row>
    std::vector<Row> filter_rows_by_targets(const std::vector<Row> &rows,
                                            const std::vector<mass_spec::MS_TARGETS> &targets_by_analysis,
                                            const std::vector<std::string> &analyses)
    {
      if (targets_by_analysis.empty())
      {
        return rows;
      }

      std::unordered_map<std::string, const mass_spec::MS_TARGETS *> targets_by_name;
      for (std::size_t i = 0; i < analyses.size() && i < targets_by_analysis.size(); ++i)
      {
        targets_by_name.emplace(analyses[i], &targets_by_analysis[i]);
      }

      constexpr double proton_mass = 1.007276;
      std::vector<Row> out;
      out.reserve(rows.size());
      for (auto row : rows)
      {
        const auto it = targets_by_name.find(row.analysis);
        if (it == targets_by_name.end())
        {
          continue;
        }
        const auto &targets = *it->second;
        bool keep = false;
        for (std::size_t i = 0; i < targets.id.size(); ++i)
        {
          const bool has_mz_window = i < targets.mzmin.size() && i < targets.mzmax.size() &&
                                     (targets.mzmin[i] > 0.0f || targets.mzmax[i] > 0.0f);
          const bool has_rt_window = i < targets.rtmin.size() && i < targets.rtmax.size() &&
                                     (targets.rtmin[i] > 0.0f || targets.rtmax[i] > 0.0f);
          const bool has_mobility_window = i < targets.mobilitymin.size() && i < targets.mobilitymax.size() &&
                                           (targets.mobilitymin[i] > 0.0f || targets.mobilitymax[i] > 0.0f);

          bool mass_match = true;
          if (has_mz_window)
          {
            double mz_value = row.exp_mass;
            if (row.polarity == 1)
            {
              mz_value += proton_mass;
            }
            else if (row.polarity == -1)
            {
              mz_value -= proton_mass;
            }
            mass_match = mz_value >= targets.mzmin[i] && mz_value <= targets.mzmax[i];
          }

          bool rt_match = true;
          if (has_rt_window)
          {
            rt_match = row.exp_rt >= targets.rtmin[i] && row.exp_rt <= targets.rtmax[i];
          }

          bool mobility_match = true;
          if (has_mobility_window)
          {
            mobility_match = true;
          }

          bool polarity_match = true;
          if (i < targets.polarity.size() && row.polarity != 0)
          {
            polarity_match = row.polarity == targets.polarity[i];
          }

          if (mass_match && rt_match && mobility_match && polarity_match)
          {
            keep = true;
            if (i < targets.id.size() && !targets.id[i].empty())
            {
              row.name = targets.id[i];
            }
            break;
          }
        }
        if (keep)
        {
          out.push_back(std::move(row));
        }
      }
      return out;
    }

    void delete_features_for_analyses(duckdb_connection con,
                                      const std::string &project_id,
                                      const std::vector<std::string> &analyses)
    {
      if (analyses.empty())
      {
        return;
      }
      std::string sql = "DELETE FROM NTS_FEATURES WHERE project_id = ? AND analysis IN (";
      sql += placeholders(analyses.size());
      sql += ")";
      detail::run_prepared(con, sql, "delete NTS features for analyses", [&](duckdb_prepared_statement statement)
                           {
                         idx_t bind_index = 1;
                         duckdb_bind_varchar(statement, bind_index++, project_id.c_str());
                         for (const auto& analysis : analyses) {
                           duckdb_bind_varchar(statement, bind_index++, analysis.c_str());
                         } }, [](duckdb_result &) {});
    }

    void bind_optional_string(duckdb_prepared_statement statement, idx_t index, const std::string &value)
    {
      if (value.empty())
      {
        duckdb_bind_null(statement, index);
      }
      else
      {
        duckdb_bind_varchar(statement, index, value.c_str());
      }
    }

    void bind_feature_insert_row(duckdb_prepared_statement statement,
                                 const std::string &project_id,
                                 const nts::FEATURE &feature)
    {
      idx_t bind_index = 1;
      duckdb_bind_varchar(statement, bind_index++, project_id.c_str());
      duckdb_bind_varchar(statement, bind_index++, feature.analysis.c_str());
      duckdb_bind_varchar(statement, bind_index++, feature.feature.c_str());
      bind_optional_string(statement, bind_index++, feature.feature_component);
      bind_optional_string(statement, bind_index++, feature.feature_group);
      bind_optional_string(statement, bind_index++, feature.adduct);
      duckdb_bind_double(statement, bind_index++, feature.rt);
      duckdb_bind_double(statement, bind_index++, feature.mz);
      duckdb_bind_double(statement, bind_index++, feature.mass);
      duckdb_bind_double(statement, bind_index++, feature.intensity);
      duckdb_bind_double(statement, bind_index++, feature.noise);
      duckdb_bind_double(statement, bind_index++, feature.sn);
      duckdb_bind_double(statement, bind_index++, feature.area);
      duckdb_bind_double(statement, bind_index++, feature.rtmin);
      duckdb_bind_double(statement, bind_index++, feature.rtmax);
      duckdb_bind_double(statement, bind_index++, feature.width);
      duckdb_bind_double(statement, bind_index++, feature.mzmin);
      duckdb_bind_double(statement, bind_index++, feature.mzmax);
      duckdb_bind_double(statement, bind_index++, feature.ppm);
      duckdb_bind_double(statement, bind_index++, feature.fwhm_rt);
      duckdb_bind_double(statement, bind_index++, feature.fwhm_mz);
      duckdb_bind_double(statement, bind_index++, feature.gaussian_A);
      duckdb_bind_double(statement, bind_index++, feature.gaussian_mu);
      duckdb_bind_double(statement, bind_index++, feature.gaussian_sigma);
      duckdb_bind_double(statement, bind_index++, feature.gaussian_r2);
      duckdb_bind_double(statement, bind_index++, feature.jaggedness);
      duckdb_bind_double(statement, bind_index++, feature.sharpness);
      duckdb_bind_double(statement, bind_index++, feature.asymmetry);
      duckdb_bind_int32(statement, bind_index++, feature.modality);
      duckdb_bind_double(statement, bind_index++, feature.plates);
      duckdb_bind_int32(statement, bind_index++, feature.polarity);
      duckdb_bind_boolean(statement, bind_index++, feature.filtered);
      bind_optional_string(statement, bind_index++, feature.filter);
      duckdb_bind_boolean(statement, bind_index++, feature.filled);
      duckdb_bind_double(statement, bind_index++, feature.correction);
      duckdb_bind_int32(statement, bind_index++, feature.eic_size);
      bind_optional_string(statement, bind_index++, feature.eic_rt);
      bind_optional_string(statement, bind_index++, feature.eic_mz);
      bind_optional_string(statement, bind_index++, feature.eic_intensity);
      bind_optional_string(statement, bind_index++, feature.eic_baseline);
      bind_optional_string(statement, bind_index++, feature.eic_smoothed);
      duckdb_bind_int32(statement, bind_index++, feature.ms1_size);
      bind_optional_string(statement, bind_index++, feature.ms1_mz);
      bind_optional_string(statement, bind_index++, feature.ms1_intensity);
      duckdb_bind_int32(statement, bind_index++, feature.ms2_size);
      bind_optional_string(statement, bind_index++, feature.ms2_mz);
      bind_optional_string(statement, bind_index++, feature.ms2_intensity);
    }

    void insert_feature_rows(duckdb_connection con,
                             const std::string &project_id,
                             const std::vector<nts::FEATURES> &features_by_analysis)
    {
      const std::string insert_sql =
          "INSERT INTO NTS_FEATURES ("
          "project_id, analysis, feature, feature_component, feature_group, adduct, rt, mz, mass, intensity, "
          "noise, sn, area, rtmin, rtmax, width, mzmin, mzmax, ppm, fwhm_rt, fwhm_mz, gaussian_A, gaussian_mu, "
          "gaussian_sigma, gaussian_r2, jaggedness, sharpness, asymmetry, modality, plates, polarity, filtered, "
          "filter, filled, correction, eic_size, eic_rt, eic_mz, eic_intensity, eic_baseline, eic_smoothed, "
          "ms1_size, ms1_mz, ms1_intensity, ms2_size, ms2_mz, ms2_intensity"
          ") VALUES ("
          "?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?"
          ")";
      for (const auto &features : features_by_analysis)
      {
        for (int i = 0; i < features.size(); ++i)
        {
          nts::FEATURE feature = features.get_feature(i);
          feature.analysis = features.analysis;
          detail::run_prepared(con, insert_sql, "insert NTS feature row", [&](duckdb_prepared_statement statement)
                               { bind_feature_insert_row(statement, project_id, feature); }, [](duckdb_result &) {});
        }
      }
    }

    std::vector<nts::FEATURES> features_by_analysis_from_rows(const std::vector<NTS_FEATURE_ROW> &rows,
                                                              const std::vector<std::string> &analyses)
    {
      std::unordered_map<std::string, nts::FEATURES> grouped;
      for (const auto &analysis : analyses)
      {
        grouped.emplace(analysis, nts::FEATURES());
        grouped[analysis].analysis = analysis;
      }
      for (const auto &row : rows)
      {
        auto it = grouped.find(row.analysis);
        if (it == grouped.end())
        {
          continue;
        }
        nts::FEATURE feature;
        feature.analysis = row.analysis;
        feature.feature = row.feature;
        feature.feature_component = row.feature_component;
        feature.feature_group = row.feature_group;
        feature.adduct = row.adduct;
        feature.rt = static_cast<float>(row.rt);
        feature.mz = static_cast<float>(row.mz);
        feature.mass = static_cast<float>(row.mass);
        feature.intensity = static_cast<float>(row.intensity);
        feature.noise = static_cast<float>(row.noise);
        feature.sn = static_cast<float>(row.sn);
        feature.area = static_cast<float>(row.area);
        feature.rtmin = static_cast<float>(row.rtmin);
        feature.rtmax = static_cast<float>(row.rtmax);
        feature.width = static_cast<float>(row.width);
        feature.mzmin = static_cast<float>(row.mzmin);
        feature.mzmax = static_cast<float>(row.mzmax);
        feature.ppm = static_cast<float>(row.ppm);
        feature.fwhm_rt = static_cast<float>(row.fwhm_rt);
        feature.fwhm_mz = static_cast<float>(row.fwhm_mz);
        feature.gaussian_A = static_cast<float>(row.gaussian_A);
        feature.gaussian_mu = static_cast<float>(row.gaussian_mu);
        feature.gaussian_sigma = static_cast<float>(row.gaussian_sigma);
        feature.gaussian_r2 = static_cast<float>(row.gaussian_r2);
        feature.jaggedness = static_cast<float>(row.jaggedness);
        feature.sharpness = static_cast<float>(row.sharpness);
        feature.asymmetry = static_cast<float>(row.asymmetry);
        feature.modality = row.modality;
        feature.plates = static_cast<float>(row.plates);
        feature.polarity = row.polarity;
        feature.filtered = row.filtered;
        feature.filter = row.filter;
        feature.filled = row.filled;
        feature.correction = static_cast<float>(row.correction);
        feature.eic_size = row.eic_size;
        feature.eic_rt = row.eic_rt;
        feature.eic_mz = row.eic_mz;
        feature.eic_intensity = row.eic_intensity;
        feature.eic_baseline = row.eic_baseline;
        feature.eic_smoothed = row.eic_smoothed;
        feature.ms1_size = row.ms1_size;
        feature.ms1_mz = row.ms1_mz;
        feature.ms1_intensity = row.ms1_intensity;
        feature.ms2_size = row.ms2_size;
        feature.ms2_mz = row.ms2_mz;
        feature.ms2_intensity = row.ms2_intensity;
        it->second.append_feature(feature);
      }
      std::vector<nts::FEATURES> out;
      out.reserve(analyses.size());
      for (const auto &analysis : analyses)
      {
        out.push_back(grouped[analysis]);
      }
      return out;
    }

    void delete_rows_for_analyses(duckdb_connection con,
                                  const char *table_name,
                                  const std::string &project_id,
                                  const std::vector<std::string> &analyses)
    {
      if (analyses.empty())
      {
        return;
      }
      std::string sql = std::string("DELETE FROM ") + table_name + " WHERE project_id = ? AND analysis IN (";
      sql += placeholders(analyses.size());
      sql += ")";
      detail::run_prepared(con, sql, "delete project NTS rows for analyses", [&](duckdb_prepared_statement statement)
                           {
                         idx_t bind_index = 1;
                         duckdb_bind_varchar(statement, bind_index++, project_id.c_str());
                         for (const auto& analysis : analyses) {
                           duckdb_bind_varchar(statement, bind_index++, analysis.c_str());
                         } }, [](duckdb_result &) {});
    }

    void insert_suspects_rows(duckdb_connection con,
                              const std::string &project_id,
                              const nts::SUSPECTS &suspects)
    {
      const std::string sql =
          "INSERT INTO NTS_SUSPECTS ("
          "project_id, analysis, feature, candidate_rank, name, polarity, db_mass, exp_mass, error_mass, db_rt, exp_rt, error_rt, "
          "intensity, area, id_level, score, shared_fragments, cosine_similarity, formula, SMILES, InChI, InChIKey, xLogP, database_id, "
          "db_ms2_size, db_ms2_mz, db_ms2_intensity, db_ms2_formula, exp_ms2_size, exp_ms2_mz, exp_ms2_intensity"
          ") VALUES ("
          "?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?"
          ")";
      for (std::size_t i = 0; i < suspects.analysis.size(); ++i)
      {
        detail::run_prepared(con, sql, "insert NTS suspect row", [&](duckdb_prepared_statement statement)
                             {
                           idx_t bind_index = 1;
                           duckdb_bind_varchar(statement, bind_index++, project_id.c_str());
                           duckdb_bind_varchar(statement, bind_index++, suspects.analysis[i].c_str());
                           duckdb_bind_varchar(statement, bind_index++, suspects.feature[i].c_str());
                           duckdb_bind_int32(statement, bind_index++, suspects.candidate_rank[i]);
                           duckdb_bind_varchar(statement, bind_index++, suspects.name[i].c_str());
                           duckdb_bind_int32(statement, bind_index++, suspects.polarity[i]);
                           duckdb_bind_double(statement, bind_index++, suspects.db_mass[i]);
                           duckdb_bind_double(statement, bind_index++, suspects.exp_mass[i]);
                           duckdb_bind_double(statement, bind_index++, suspects.error_mass[i]);
                           duckdb_bind_double(statement, bind_index++, suspects.db_rt[i]);
                           duckdb_bind_double(statement, bind_index++, suspects.exp_rt[i]);
                           duckdb_bind_double(statement, bind_index++, suspects.error_rt[i]);
                           duckdb_bind_double(statement, bind_index++, suspects.intensity[i]);
                           duckdb_bind_double(statement, bind_index++, suspects.area[i]);
                           duckdb_bind_int32(statement, bind_index++, suspects.id_level[i]);
                           duckdb_bind_double(statement, bind_index++, suspects.score[i]);
                           duckdb_bind_int32(statement, bind_index++, suspects.shared_fragments[i]);
                           duckdb_bind_double(statement, bind_index++, suspects.cosine_similarity[i]);
                           bind_optional_string(statement, bind_index++, suspects.formula[i]);
                           bind_optional_string(statement, bind_index++, suspects.SMILES[i]);
                           bind_optional_string(statement, bind_index++, suspects.InChI[i]);
                           bind_optional_string(statement, bind_index++, suspects.InChIKey[i]);
                           duckdb_bind_double(statement, bind_index++, suspects.xLogP[i]);
                           bind_optional_string(statement, bind_index++, suspects.database_id[i]);
                           duckdb_bind_int32(statement, bind_index++, suspects.db_ms2_size[i]);
                           bind_optional_string(statement, bind_index++, suspects.db_ms2_mz[i]);
                           bind_optional_string(statement, bind_index++, suspects.db_ms2_intensity[i]);
                           bind_optional_string(statement, bind_index++, suspects.db_ms2_formula[i]);
                           duckdb_bind_int32(statement, bind_index++, suspects.exp_ms2_size[i]);
                           bind_optional_string(statement, bind_index++, suspects.exp_ms2_mz[i]);
                           bind_optional_string(statement, bind_index++, suspects.exp_ms2_intensity[i]); }, [](duckdb_result &) {});
      }
    }

    void insert_internal_standards_rows(duckdb_connection con,
                                        const std::string &project_id,
                                        const nts::INTERNAL_STANDARDS &internal_standards)
    {
      const std::string sql =
          "INSERT INTO NTS_INTERNAL_STANDARDS ("
          "project_id, analysis, feature, candidate_rank, name, polarity, db_mass, exp_mass, error_mass, db_rt, exp_rt, error_rt, "
          "intensity, area, id_level, score, shared_fragments, cosine_similarity, formula, SMILES, InChI, InChIKey, xLogP, database_id, "
          "db_ms2_size, db_ms2_mz, db_ms2_intensity, db_ms2_formula, exp_ms2_size, exp_ms2_mz, exp_ms2_intensity"
          ") VALUES ("
          "?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?"
          ")";
      for (std::size_t i = 0; i < internal_standards.analysis.size(); ++i)
      {
        detail::run_prepared(con, sql, "insert NTS internal standard row", [&](duckdb_prepared_statement statement)
                             {
                           idx_t bind_index = 1;
                           duckdb_bind_varchar(statement, bind_index++, project_id.c_str());
                           duckdb_bind_varchar(statement, bind_index++, internal_standards.analysis[i].c_str());
                           duckdb_bind_varchar(statement, bind_index++, internal_standards.feature[i].c_str());
                           duckdb_bind_int32(statement, bind_index++, internal_standards.candidate_rank[i]);
                           duckdb_bind_varchar(statement, bind_index++, internal_standards.name[i].c_str());
                           duckdb_bind_int32(statement, bind_index++, internal_standards.polarity[i]);
                           duckdb_bind_double(statement, bind_index++, internal_standards.db_mass[i]);
                           duckdb_bind_double(statement, bind_index++, internal_standards.exp_mass[i]);
                           duckdb_bind_double(statement, bind_index++, internal_standards.error_mass[i]);
                           duckdb_bind_double(statement, bind_index++, internal_standards.db_rt[i]);
                           duckdb_bind_double(statement, bind_index++, internal_standards.exp_rt[i]);
                           duckdb_bind_double(statement, bind_index++, internal_standards.error_rt[i]);
                           duckdb_bind_double(statement, bind_index++, internal_standards.intensity[i]);
                           duckdb_bind_double(statement, bind_index++, internal_standards.area[i]);
                           duckdb_bind_int32(statement, bind_index++, internal_standards.id_level[i]);
                           duckdb_bind_double(statement, bind_index++, internal_standards.score[i]);
                           duckdb_bind_int32(statement, bind_index++, internal_standards.shared_fragments[i]);
                           duckdb_bind_double(statement, bind_index++, internal_standards.cosine_similarity[i]);
                           bind_optional_string(statement, bind_index++, internal_standards.formula[i]);
                           bind_optional_string(statement, bind_index++, internal_standards.SMILES[i]);
                           bind_optional_string(statement, bind_index++, internal_standards.InChI[i]);
                           bind_optional_string(statement, bind_index++, internal_standards.InChIKey[i]);
                           duckdb_bind_double(statement, bind_index++, internal_standards.xLogP[i]);
                           bind_optional_string(statement, bind_index++, internal_standards.database_id[i]);
                           duckdb_bind_int32(statement, bind_index++, internal_standards.db_ms2_size[i]);
                           bind_optional_string(statement, bind_index++, internal_standards.db_ms2_mz[i]);
                           bind_optional_string(statement, bind_index++, internal_standards.db_ms2_intensity[i]);
                           bind_optional_string(statement, bind_index++, internal_standards.db_ms2_formula[i]);
                           duckdb_bind_int32(statement, bind_index++, internal_standards.exp_ms2_size[i]);
                           bind_optional_string(statement, bind_index++, internal_standards.exp_ms2_mz[i]);
                           bind_optional_string(statement, bind_index++, internal_standards.exp_ms2_intensity[i]); }, [](duckdb_result &) {});
      }
    }

    nts::SUSPECTS flatten_suspects(const std::vector<nts::SUSPECTS> &suspects_by_analysis)
    {
      nts::SUSPECTS out;
      for (const auto &suspects : suspects_by_analysis)
      {
        for (std::size_t i = 0; i < suspects.analysis.size(); ++i)
        {
          nts::SUSPECT row;
          row.analysis = suspects.analysis[i];
          row.feature = suspects.feature[i];
          row.candidate_rank = suspects.candidate_rank[i];
          row.name = suspects.name[i];
          row.polarity = suspects.polarity[i];
          row.db_mass = suspects.db_mass[i];
          row.exp_mass = suspects.exp_mass[i];
          row.error_mass = suspects.error_mass[i];
          row.db_rt = suspects.db_rt[i];
          row.exp_rt = suspects.exp_rt[i];
          row.error_rt = suspects.error_rt[i];
          row.intensity = suspects.intensity[i];
          row.area = suspects.area[i];
          row.id_level = suspects.id_level[i];
          row.score = suspects.score[i];
          row.shared_fragments = suspects.shared_fragments[i];
          row.cosine_similarity = suspects.cosine_similarity[i];
          row.formula = suspects.formula[i];
          row.SMILES = suspects.SMILES[i];
          row.InChI = suspects.InChI[i];
          row.InChIKey = suspects.InChIKey[i];
          row.xLogP = suspects.xLogP[i];
          row.database_id = suspects.database_id[i];
          row.db_ms2_size = suspects.db_ms2_size[i];
          row.db_ms2_mz = suspects.db_ms2_mz[i];
          row.db_ms2_intensity = suspects.db_ms2_intensity[i];
          row.db_ms2_formula = suspects.db_ms2_formula[i];
          row.exp_ms2_size = suspects.exp_ms2_size[i];
          row.exp_ms2_mz = suspects.exp_ms2_mz[i];
          row.exp_ms2_intensity = suspects.exp_ms2_intensity[i];
          out.append(row);
        }
      }
      return out;
    }

    nts::INTERNAL_STANDARDS internal_standards_from_suspects(const nts::SUSPECTS &suspects)
    {
      nts::INTERNAL_STANDARDS out;
      for (std::size_t i = 0; i < suspects.analysis.size(); ++i)
      {
        nts::INTERNAL_STANDARD row;
        row.analysis = suspects.analysis[i];
        row.feature = suspects.feature[i];
        row.candidate_rank = suspects.candidate_rank[i];
        row.name = suspects.name[i];
        row.polarity = suspects.polarity[i];
        row.db_mass = suspects.db_mass[i];
        row.exp_mass = suspects.exp_mass[i];
        row.error_mass = suspects.error_mass[i];
        row.db_rt = suspects.db_rt[i];
        row.exp_rt = suspects.exp_rt[i];
        row.error_rt = suspects.error_rt[i];
        row.intensity = suspects.intensity[i];
        row.area = suspects.area[i];
        row.id_level = suspects.id_level[i];
        row.score = suspects.score[i];
        row.shared_fragments = suspects.shared_fragments[i];
        row.cosine_similarity = suspects.cosine_similarity[i];
        row.formula = suspects.formula[i];
        row.SMILES = suspects.SMILES[i];
        row.InChI = suspects.InChI[i];
        row.InChIKey = suspects.InChIKey[i];
        row.xLogP = suspects.xLogP[i];
        row.database_id = suspects.database_id[i];
        row.db_ms2_size = suspects.db_ms2_size[i];
        row.db_ms2_mz = suspects.db_ms2_mz[i];
        row.db_ms2_intensity = suspects.db_ms2_intensity[i];
        row.db_ms2_formula = suspects.db_ms2_formula[i];
        row.exp_ms2_size = suspects.exp_ms2_size[i];
        row.exp_ms2_mz = suspects.exp_ms2_mz[i];
        row.exp_ms2_intensity = suspects.exp_ms2_intensity[i];
        out.append(row);
      }
      return out;
    }

    std::vector<nts::SUSPECTS> suspects_by_analysis_from_flat(const nts::SUSPECTS &suspects,
                                                              const std::vector<std::string> &analyses)
    {
      std::unordered_map<std::string, nts::SUSPECTS> grouped;
      for (const auto &analysis : analyses)
      {
        grouped.emplace(analysis, nts::SUSPECTS());
      }
      for (std::size_t i = 0; i < suspects.analysis.size(); ++i)
      {
        auto it = grouped.find(suspects.analysis[i]);
        if (it == grouped.end())
        {
          continue;
        }
        nts::SUSPECT row;
        row.analysis = suspects.analysis[i];
        row.feature = suspects.feature[i];
        row.candidate_rank = suspects.candidate_rank[i];
        row.name = suspects.name[i];
        row.polarity = suspects.polarity[i];
        row.db_mass = suspects.db_mass[i];
        row.exp_mass = suspects.exp_mass[i];
        row.error_mass = suspects.error_mass[i];
        row.db_rt = suspects.db_rt[i];
        row.exp_rt = suspects.exp_rt[i];
        row.error_rt = suspects.error_rt[i];
        row.intensity = suspects.intensity[i];
        row.area = suspects.area[i];
        row.id_level = suspects.id_level[i];
        row.score = suspects.score[i];
        row.shared_fragments = suspects.shared_fragments[i];
        row.cosine_similarity = suspects.cosine_similarity[i];
        row.formula = suspects.formula[i];
        row.SMILES = suspects.SMILES[i];
        row.InChI = suspects.InChI[i];
        row.InChIKey = suspects.InChIKey[i];
        row.xLogP = suspects.xLogP[i];
        row.database_id = suspects.database_id[i];
        row.db_ms2_size = suspects.db_ms2_size[i];
        row.db_ms2_mz = suspects.db_ms2_mz[i];
        row.db_ms2_intensity = suspects.db_ms2_intensity[i];
        row.db_ms2_formula = suspects.db_ms2_formula[i];
        row.exp_ms2_size = suspects.exp_ms2_size[i];
        row.exp_ms2_mz = suspects.exp_ms2_mz[i];
        row.exp_ms2_intensity = suspects.exp_ms2_intensity[i];
        it->second.append(row);
      }
      std::vector<nts::SUSPECTS> out;
      out.reserve(analyses.size());
      for (const auto &analysis : analyses)
      {
        out.push_back(grouped[analysis]);
      }
      return out;
    }

    std::vector<nts::INTERNAL_STANDARDS> internal_standards_by_analysis_from_flat(const nts::INTERNAL_STANDARDS &internal_standards,
                                                                                  const std::vector<std::string> &analyses)
    {
      std::unordered_map<std::string, nts::INTERNAL_STANDARDS> grouped;
      for (const auto &analysis : analyses)
      {
        grouped.emplace(analysis, nts::INTERNAL_STANDARDS());
      }
      for (std::size_t i = 0; i < internal_standards.analysis.size(); ++i)
      {
        auto it = grouped.find(internal_standards.analysis[i]);
        if (it == grouped.end())
        {
          continue;
        }
        nts::INTERNAL_STANDARD row;
        row.analysis = internal_standards.analysis[i];
        row.feature = internal_standards.feature[i];
        row.candidate_rank = internal_standards.candidate_rank[i];
        row.name = internal_standards.name[i];
        row.polarity = internal_standards.polarity[i];
        row.db_mass = internal_standards.db_mass[i];
        row.exp_mass = internal_standards.exp_mass[i];
        row.error_mass = internal_standards.error_mass[i];
        row.db_rt = internal_standards.db_rt[i];
        row.exp_rt = internal_standards.exp_rt[i];
        row.error_rt = internal_standards.error_rt[i];
        row.intensity = internal_standards.intensity[i];
        row.area = internal_standards.area[i];
        row.id_level = internal_standards.id_level[i];
        row.score = internal_standards.score[i];
        row.shared_fragments = internal_standards.shared_fragments[i];
        row.cosine_similarity = internal_standards.cosine_similarity[i];
        row.formula = internal_standards.formula[i];
        row.SMILES = internal_standards.SMILES[i];
        row.InChI = internal_standards.InChI[i];
        row.InChIKey = internal_standards.InChIKey[i];
        row.xLogP = internal_standards.xLogP[i];
        row.database_id = internal_standards.database_id[i];
        row.db_ms2_size = internal_standards.db_ms2_size[i];
        row.db_ms2_mz = internal_standards.db_ms2_mz[i];
        row.db_ms2_intensity = internal_standards.db_ms2_intensity[i];
        row.db_ms2_formula = internal_standards.db_ms2_formula[i];
        row.exp_ms2_size = internal_standards.exp_ms2_size[i];
        row.exp_ms2_mz = internal_standards.exp_ms2_mz[i];
        row.exp_ms2_intensity = internal_standards.exp_ms2_intensity[i];
        it->second.append(row);
      }
      std::vector<nts::INTERNAL_STANDARDS> out;
      out.reserve(analyses.size());
      for (const auto &analysis : analyses)
      {
        out.push_back(grouped[analysis]);
      }
      return out;
    }

    std::vector<assign_transformation_products::FlatSuspect> transformation_flat_suspects_from_suspects(const nts::SUSPECTS &suspects)
    {
      std::vector<assign_transformation_products::FlatSuspect> out;
      return out;
    }

    nts::SUSPECTS query_suspects_for_analyses(const std::shared_ptr<CONTEXT> &ctx,
                                              const std::vector<std::string> &analyses)
    {
      nts::SUSPECTS out;
      const auto selected = sanitize_analyses(analyses);
      if (selected.empty())
      {
        return out;
      }
      auto guard = connect_checked(ctx);
      std::string sql =
          "SELECT analysis, feature, candidate_rank, name, polarity, db_mass, exp_mass, error_mass, db_rt, exp_rt, error_rt, "
          "intensity, area, id_level, score, shared_fragments, cosine_similarity, formula, SMILES, InChI, InChIKey, xLogP, database_id, "
          "db_ms2_size, db_ms2_mz, db_ms2_intensity, db_ms2_formula, exp_ms2_size, exp_ms2_mz, exp_ms2_intensity "
          "FROM NTS_SUSPECTS WHERE project_id = ? AND analysis IN (";
      sql += placeholders(selected.size());
      sql += ") ORDER BY lower(analysis), analysis, candidate_rank, name";
      detail::run_prepared(guard.get(), sql, "query project NTS suspects", [&](duckdb_prepared_statement statement)
                           {
                         idx_t bind_index = 1;
                         duckdb_bind_varchar(statement, bind_index++, ctx->project_id.c_str());
                         for (const auto& analysis : selected) {
                           duckdb_bind_varchar(statement, bind_index++, analysis.c_str());
                         } }, [&](duckdb_result &result)
                           {
                         const idx_t count = duckdb_row_count(&result);
                         for (idx_t row = 0; row < count; ++row) {
                           nts::SUSPECT value;
                           value.analysis = detail::result_varchar(&result, 0, row);
                           value.feature = detail::result_varchar(&result, 1, row);
                           value.candidate_rank = duckdb_value_int32(&result, 2, row);
                           value.name = detail::result_varchar(&result, 3, row);
                           value.polarity = duckdb_value_int32(&result, 4, row);
                           value.db_mass = duckdb_value_double(&result, 5, row);
                           value.exp_mass = duckdb_value_double(&result, 6, row);
                           value.error_mass = duckdb_value_double(&result, 7, row);
                           value.db_rt = duckdb_value_double(&result, 8, row);
                           value.exp_rt = duckdb_value_double(&result, 9, row);
                           value.error_rt = duckdb_value_double(&result, 10, row);
                           value.intensity = duckdb_value_double(&result, 11, row);
                           value.area = duckdb_value_double(&result, 12, row);
                           value.id_level = duckdb_value_int32(&result, 13, row);
                           value.score = duckdb_value_double(&result, 14, row);
                           value.shared_fragments = duckdb_value_int32(&result, 15, row);
                           value.cosine_similarity = duckdb_value_double(&result, 16, row);
                           value.formula = detail::result_varchar(&result, 17, row);
                           value.SMILES = detail::result_varchar(&result, 18, row);
                           value.InChI = detail::result_varchar(&result, 19, row);
                           value.InChIKey = detail::result_varchar(&result, 20, row);
                           value.xLogP = duckdb_value_double(&result, 21, row);
                           value.database_id = detail::result_varchar(&result, 22, row);
                           value.db_ms2_size = duckdb_value_int32(&result, 23, row);
                           value.db_ms2_mz = detail::result_varchar(&result, 24, row);
                           value.db_ms2_intensity = detail::result_varchar(&result, 25, row);
                           value.db_ms2_formula = detail::result_varchar(&result, 26, row);
                           value.exp_ms2_size = duckdb_value_int32(&result, 27, row);
                           value.exp_ms2_mz = detail::result_varchar(&result, 28, row);
                           value.exp_ms2_intensity = detail::result_varchar(&result, 29, row);
                           out.append(value);
                         } });
      return out;
    }

    nts::INTERNAL_STANDARDS query_internal_standards_for_analyses(const std::shared_ptr<CONTEXT> &ctx,
                                                                  const std::vector<std::string> &analyses)
    {
      nts::INTERNAL_STANDARDS out;
      const auto selected = sanitize_analyses(analyses);
      if (selected.empty())
      {
        return out;
      }
      auto guard = connect_checked(ctx);
      std::string sql =
          "SELECT analysis, feature, candidate_rank, name, polarity, db_mass, exp_mass, error_mass, db_rt, exp_rt, error_rt, "
          "intensity, area, id_level, score, shared_fragments, cosine_similarity, formula, SMILES, InChI, InChIKey, xLogP, database_id, "
          "db_ms2_size, db_ms2_mz, db_ms2_intensity, db_ms2_formula, exp_ms2_size, exp_ms2_mz, exp_ms2_intensity "
          "FROM NTS_INTERNAL_STANDARDS WHERE project_id = ? AND analysis IN (";
      sql += placeholders(selected.size());
      sql += ") ORDER BY lower(analysis), analysis, candidate_rank, name";
      detail::run_prepared(guard.get(), sql, "query project NTS internal standards", [&](duckdb_prepared_statement statement)
                           {
                         idx_t bind_index = 1;
                         duckdb_bind_varchar(statement, bind_index++, ctx->project_id.c_str());
                         for (const auto& analysis : selected) {
                           duckdb_bind_varchar(statement, bind_index++, analysis.c_str());
                         } }, [&](duckdb_result &result)
                           {
                         const idx_t count = duckdb_row_count(&result);
                         for (idx_t row = 0; row < count; ++row) {
                           nts::INTERNAL_STANDARD value;
                           value.analysis = detail::result_varchar(&result, 0, row);
                           value.feature = detail::result_varchar(&result, 1, row);
                           value.candidate_rank = duckdb_value_int32(&result, 2, row);
                           value.name = detail::result_varchar(&result, 3, row);
                           value.polarity = duckdb_value_int32(&result, 4, row);
                           value.db_mass = duckdb_value_double(&result, 5, row);
                           value.exp_mass = duckdb_value_double(&result, 6, row);
                           value.error_mass = duckdb_value_double(&result, 7, row);
                           value.db_rt = duckdb_value_double(&result, 8, row);
                           value.exp_rt = duckdb_value_double(&result, 9, row);
                           value.error_rt = duckdb_value_double(&result, 10, row);
                           value.intensity = duckdb_value_double(&result, 11, row);
                           value.area = duckdb_value_double(&result, 12, row);
                           value.id_level = duckdb_value_int32(&result, 13, row);
                           value.score = duckdb_value_double(&result, 14, row);
                           value.shared_fragments = duckdb_value_int32(&result, 15, row);
                           value.cosine_similarity = duckdb_value_double(&result, 16, row);
                           value.formula = detail::result_varchar(&result, 17, row);
                           value.SMILES = detail::result_varchar(&result, 18, row);
                           value.InChI = detail::result_varchar(&result, 19, row);
                           value.InChIKey = detail::result_varchar(&result, 20, row);
                           value.xLogP = duckdb_value_double(&result, 21, row);
                           value.database_id = detail::result_varchar(&result, 22, row);
                           value.db_ms2_size = duckdb_value_int32(&result, 23, row);
                           value.db_ms2_mz = detail::result_varchar(&result, 24, row);
                           value.db_ms2_intensity = detail::result_varchar(&result, 25, row);
                           value.db_ms2_formula = detail::result_varchar(&result, 26, row);
                           value.exp_ms2_size = duckdb_value_int32(&result, 27, row);
                           value.exp_ms2_mz = detail::result_varchar(&result, 28, row);
                           value.exp_ms2_intensity = detail::result_varchar(&result, 29, row);
                           out.append(value);
                         } });
      return out;
    }

    std::vector<assign_transformation_products::FlatSuspect> query_transformation_flat_suspects(const std::shared_ptr<CONTEXT> &ctx)
    {
      std::vector<assign_transformation_products::FlatSuspect> out;
      auto guard = connect_checked(ctx);
      const std::string sql =
          "SELECT s.SMILES, COALESCE(f.feature_group, ''), s.exp_rt, s.exp_ms2_size, s.exp_ms2_mz, s.exp_ms2_intensity "
          "FROM NTS_SUSPECTS s "
          "LEFT JOIN NTS_FEATURES f "
          "ON s.project_id = f.project_id AND s.analysis = f.analysis AND s.feature = f.feature "
          "WHERE s.project_id = ? "
          "ORDER BY lower(s.analysis), s.analysis, s.name, s.candidate_rank";
      detail::run_prepared(guard.get(), sql, "query flat suspects for transformation products", [&](duckdb_prepared_statement statement)
                           { duckdb_bind_varchar(statement, 1, ctx->project_id.c_str()); }, [&](duckdb_result &result)
                           {
                         const idx_t count = duckdb_row_count(&result);
                         out.reserve(count);
                         for (idx_t row = 0; row < count; ++row) {
                           assign_transformation_products::FlatSuspect value;
                           value.SMILES = detail::result_varchar(&result, 0, row);
                           value.feature_group = detail::result_varchar(&result, 1, row);
                           value.exp_rt = duckdb_value_double(&result, 2, row);
                           value.exp_ms2_size = duckdb_value_int32(&result, 3, row);
                           value.exp_ms2_mz = detail::result_varchar(&result, 4, row);
                           value.exp_ms2_intensity = detail::result_varchar(&result, 5, row);
                           out.push_back(value);
                         } });
      return out;
    }

    void delete_transformation_products(duckdb_connection con, const std::string &project_id)
    {
      detail::run_prepared(con, "DELETE FROM NTS_TRANSFORMATION_PRODUCTS WHERE project_id = ?", "delete project NTS transformation products", [&](duckdb_prepared_statement statement)
                           { duckdb_bind_varchar(statement, 1, project_id.c_str()); }, [](duckdb_result &) {});
    }

    void insert_transformation_products_rows(
        duckdb_connection con,
        const std::string &project_id,
        const assign_transformation_products::TRANSFORMATION_PRODUCTS &transformation_products)
    {
      const std::string sql =
          "INSERT INTO NTS_TRANSFORMATION_PRODUCTS ("
          "project_id, name, formula, mass, SMILES, InChI, InChIKey, xLogP, transformation, precursor_name, precursor_formula, precursor_mass, precursor_SMILES, precursor_InChI, precursor_InChIKey, precursor_xLogP, main_precursor_name, main_precursor_formula, main_precursor_mass, main_precursor_SMILES, main_precursor_InChI, main_precursor_InChIKey, main_precursor_xLogP, feature_group, precursor_feature_group, main_precursor_feature_group, cosine_similarity, main_precursor_cosine_similarity, rt_plausibility, main_precursor_rt_plausibility"
          ") VALUES ("
          "?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?"
          ")";
      for (int i = 0; i < transformation_products.size(); ++i)
      {
        detail::run_prepared(con, sql, "insert NTS transformation product row", [&](duckdb_prepared_statement statement)
                             {
                           idx_t bind_index = 1;
                           duckdb_bind_varchar(statement, bind_index++, project_id.c_str());
                           bind_optional_string(statement, bind_index++, transformation_products.name[i]);
                           bind_optional_string(statement, bind_index++, transformation_products.formula[i]);
                           duckdb_bind_double(statement, bind_index++, transformation_products.mass[i]);
                           bind_optional_string(statement, bind_index++, transformation_products.SMILES[i]);
                           bind_optional_string(statement, bind_index++, transformation_products.InChI[i]);
                           bind_optional_string(statement, bind_index++, transformation_products.InChIKey[i]);
                           duckdb_bind_double(statement, bind_index++, transformation_products.xLogP[i]);
                           bind_optional_string(statement, bind_index++, transformation_products.transformation[i]);
                           bind_optional_string(statement, bind_index++, transformation_products.precursor_name[i]);
                           bind_optional_string(statement, bind_index++, transformation_products.precursor_formula[i]);
                           duckdb_bind_double(statement, bind_index++, transformation_products.precursor_mass[i]);
                           bind_optional_string(statement, bind_index++, transformation_products.precursor_SMILES[i]);
                           bind_optional_string(statement, bind_index++, transformation_products.precursor_InChI[i]);
                           bind_optional_string(statement, bind_index++, transformation_products.precursor_InChIKey[i]);
                           duckdb_bind_double(statement, bind_index++, transformation_products.precursor_xLogP[i]);
                           bind_optional_string(statement, bind_index++, transformation_products.main_precursor_name[i]);
                           bind_optional_string(statement, bind_index++, transformation_products.main_precursor_formula[i]);
                           duckdb_bind_double(statement, bind_index++, transformation_products.main_precursor_mass[i]);
                           bind_optional_string(statement, bind_index++, transformation_products.main_precursor_SMILES[i]);
                           bind_optional_string(statement, bind_index++, transformation_products.main_precursor_InChI[i]);
                           bind_optional_string(statement, bind_index++, transformation_products.main_precursor_InChIKey[i]);
                           duckdb_bind_double(statement, bind_index++, transformation_products.main_precursor_xLogP[i]);
                           bind_optional_string(statement, bind_index++, transformation_products.feature_group[i]);
                           bind_optional_string(statement, bind_index++, transformation_products.precursor_feature_group[i]);
                           bind_optional_string(statement, bind_index++, transformation_products.main_precursor_feature_group[i]);
                           duckdb_bind_double(statement, bind_index++, transformation_products.cosine_similarity[i]);
                           duckdb_bind_double(statement, bind_index++, transformation_products.main_precursor_cosine_similarity[i]);
                           duckdb_bind_double(statement, bind_index++, transformation_products.rt_plausibility[i]);
                           duckdb_bind_double(statement, bind_index++, transformation_products.main_precursor_rt_plausibility[i]); }, [](duckdb_result &) {});
      }
    }

    nts::NTS_DATA load_nts_data_with_features(const std::shared_ptr<CONTEXT> &ctx,
                                              const std::vector<mass_spec::MS_ANALYSIS_ROW> &selected_analyses,
                                              bool include_filtered_features,
                                              bool include_internal_standards = false,
                                              bool include_suspects = false)
    {
      const nts::NTS_INFO info = nts_info_from_analysis_rows(selected_analyses);
      const auto headers = load_selected_headers(ctx, selected_analyses);
      const auto feature_rows = nts::PROJECT_NON_TARGET_ANALYSIS(ctx).get_features(info.analyses, include_filtered_features);
      const auto features = features_by_analysis_from_rows(feature_rows, info.analyses);
      std::vector<nts::SUSPECTS> suspects_cpp;
      std::vector<nts::INTERNAL_STANDARDS> internal_standards_cpp;
      if (include_suspects)
      {
        suspects_cpp = suspects_by_analysis_from_flat(query_suspects_for_analyses(ctx, info.analyses), info.analyses);
      }
      if (include_internal_standards)
      {
        internal_standards_cpp = internal_standards_by_analysis_from_flat(query_internal_standards_for_analyses(ctx, info.analyses), info.analyses);
      }
      return nts::NTS_DATA(info, headers, features, suspects_cpp, internal_standards_cpp);
    }

    std::vector<NTS_FEATURE_ROW> replace_feature_rows(const std::shared_ptr<CONTEXT> &ctx,
                                                      const std::vector<std::string> &analyses,
                                                      const std::vector<nts::FEATURES> &features)
    {
      auto guard = connect_checked(ctx);
      try
      {
        detail::run_sql(guard.get(), "BEGIN", "begin project NTS feature replace transaction");
        delete_features_for_analyses(guard.get(), ctx->project_id, analyses);
        insert_feature_rows(guard.get(), ctx->project_id, features);
        detail::run_sql(guard.get(), "COMMIT", "commit project NTS feature replace transaction");
      }
      catch (...)
      {
        try
        {
          detail::run_sql(guard.get(), "ROLLBACK", "rollback project NTS feature replace transaction");
        }
        catch (...)
        {
        }
        throw;
      }
      return nts::PROJECT_NON_TARGET_ANALYSIS(ctx).get_features(analyses, true);
    }

    std::vector<std::string> unique_analysis_names(const nts::SUSPECTS &suspects)
    {
      std::vector<std::string> out;
      std::unordered_map<std::string, bool> seen;
      for (const auto &analysis : suspects.analysis)
      {
        if (!seen[analysis])
        {
          seen[analysis] = true;
          out.push_back(analysis);
        }
      }
      return out;
    }

    std::vector<std::string> unique_analysis_names(const nts::INTERNAL_STANDARDS &internal_standards)
    {
      std::vector<std::string> out;
      std::unordered_map<std::string, bool> seen;
      for (const auto &analysis : internal_standards.analysis)
      {
        if (!seen[analysis])
        {
          seen[analysis] = true;
          out.push_back(analysis);
        }
      }
      return out;
    }

    json feature_row_to_json(const NTS_FEATURE_ROW &row)
    {
      return json{{"project_id", row.project_id},
                  {"analysis", row.analysis},
                  {"feature", row.feature},
                  {"feature_component", row.feature_component},
                  {"feature_group", row.feature_group},
                  {"adduct", row.adduct},
                  {"rt", project::CACHE::stable_number(row.rt)},
                  {"mz", project::CACHE::stable_number(row.mz)},
                  {"mass", project::CACHE::stable_number(row.mass)},
                  {"intensity", project::CACHE::stable_number(row.intensity)},
                  {"noise", project::CACHE::stable_number(row.noise)},
                  {"sn", project::CACHE::stable_number(row.sn)},
                  {"area", project::CACHE::stable_number(row.area)},
                  {"rtmin", project::CACHE::stable_number(row.rtmin)},
                  {"rtmax", project::CACHE::stable_number(row.rtmax)},
                  {"width", project::CACHE::stable_number(row.width)},
                  {"mzmin", project::CACHE::stable_number(row.mzmin)},
                  {"mzmax", project::CACHE::stable_number(row.mzmax)},
                  {"ppm", project::CACHE::stable_number(row.ppm)},
                  {"fwhm_rt", project::CACHE::stable_number(row.fwhm_rt)},
                  {"fwhm_mz", project::CACHE::stable_number(row.fwhm_mz)},
                  {"gaussian_A", project::CACHE::stable_number(row.gaussian_A)},
                  {"gaussian_mu", project::CACHE::stable_number(row.gaussian_mu)},
                  {"gaussian_sigma", project::CACHE::stable_number(row.gaussian_sigma)},
                  {"gaussian_r2", project::CACHE::stable_number(row.gaussian_r2)},
                  {"jaggedness", project::CACHE::stable_number(row.jaggedness)},
                  {"sharpness", project::CACHE::stable_number(row.sharpness)},
                  {"asymmetry", project::CACHE::stable_number(row.asymmetry)},
                  {"modality", row.modality},
                  {"plates", project::CACHE::stable_number(row.plates)},
                  {"polarity", row.polarity},
                  {"filtered", row.filtered},
                  {"filter", row.filter},
                  {"filled", row.filled},
                  {"correction", project::CACHE::stable_number(row.correction)},
                  {"eic_size", row.eic_size},
                  {"eic_rt", row.eic_rt},
                  {"eic_mz", row.eic_mz},
                  {"eic_intensity", row.eic_intensity},
                  {"eic_baseline", row.eic_baseline},
                  {"eic_smoothed", row.eic_smoothed},
                  {"ms1_size", row.ms1_size},
                  {"ms1_mz", row.ms1_mz},
                  {"ms1_intensity", row.ms1_intensity},
                  {"ms2_size", row.ms2_size},
                  {"ms2_mz", row.ms2_mz},
                  {"ms2_intensity", row.ms2_intensity}};
    }

    json suspect_row_to_json(const NTS_SUSPECT_ROW &row)
    {
      return json{{"project_id", row.project_id},
                  {"analysis", row.analysis},
                  {"feature", row.feature},
                  {"candidate_rank", row.candidate_rank},
                  {"name", row.name},
                  {"polarity", row.polarity},
                  {"db_mass", project::CACHE::stable_number(row.db_mass)},
                  {"exp_mass", project::CACHE::stable_number(row.exp_mass)},
                  {"error_mass", project::CACHE::stable_number(row.error_mass)},
                  {"db_rt", project::CACHE::stable_number(row.db_rt)},
                  {"exp_rt", project::CACHE::stable_number(row.exp_rt)},
                  {"error_rt", project::CACHE::stable_number(row.error_rt)},
                  {"intensity", project::CACHE::stable_number(row.intensity)},
                  {"area", project::CACHE::stable_number(row.area)},
                  {"id_level", row.id_level},
                  {"score", project::CACHE::stable_number(row.score)},
                  {"shared_fragments", row.shared_fragments},
                  {"cosine_similarity", project::CACHE::stable_number(row.cosine_similarity)},
                  {"formula", row.formula},
                  {"SMILES", row.SMILES},
                  {"InChI", row.InChI},
                  {"InChIKey", row.InChIKey},
                  {"xLogP", project::CACHE::stable_number(row.xLogP)},
                  {"database_id", row.database_id},
                  {"db_ms2_size", row.db_ms2_size},
                  {"db_ms2_mz", row.db_ms2_mz},
                  {"db_ms2_intensity", row.db_ms2_intensity},
                  {"db_ms2_formula", row.db_ms2_formula},
                  {"exp_ms2_size", row.exp_ms2_size},
                  {"exp_ms2_mz", row.exp_ms2_mz},
                  {"exp_ms2_intensity", row.exp_ms2_intensity}};
    }

    json internal_standard_row_to_json(const NTS_INTERNAL_STANDARD_ROW &row)
    {
      return json{{"project_id", row.project_id},
                  {"analysis", row.analysis},
                  {"feature", row.feature},
                  {"candidate_rank", row.candidate_rank},
                  {"name", row.name},
                  {"polarity", row.polarity},
                  {"db_mass", project::CACHE::stable_number(row.db_mass)},
                  {"exp_mass", project::CACHE::stable_number(row.exp_mass)},
                  {"error_mass", project::CACHE::stable_number(row.error_mass)},
                  {"db_rt", project::CACHE::stable_number(row.db_rt)},
                  {"exp_rt", project::CACHE::stable_number(row.exp_rt)},
                  {"error_rt", project::CACHE::stable_number(row.error_rt)},
                  {"intensity", project::CACHE::stable_number(row.intensity)},
                  {"area", project::CACHE::stable_number(row.area)},
                  {"id_level", row.id_level},
                  {"score", project::CACHE::stable_number(row.score)},
                  {"shared_fragments", row.shared_fragments},
                  {"cosine_similarity", project::CACHE::stable_number(row.cosine_similarity)},
                  {"formula", row.formula},
                  {"SMILES", row.SMILES},
                  {"InChI", row.InChI},
                  {"InChIKey", row.InChIKey},
                  {"xLogP", project::CACHE::stable_number(row.xLogP)},
                  {"database_id", row.database_id},
                  {"db_ms2_size", row.db_ms2_size},
                  {"db_ms2_mz", row.db_ms2_mz},
                  {"db_ms2_intensity", row.db_ms2_intensity},
                  {"db_ms2_formula", row.db_ms2_formula},
                  {"exp_ms2_size", row.exp_ms2_size},
                  {"exp_ms2_mz", row.exp_ms2_mz},
                  {"exp_ms2_intensity", row.exp_ms2_intensity}};
    }

    json transformation_product_row_to_json(const NTS_TRANSFORMATION_PRODUCT_ROW &row)
    {
      return json{{"project_id", row.project_id},
                  {"name", row.name},
                  {"formula", row.formula},
                  {"mass", project::CACHE::stable_number(row.mass)},
                  {"SMILES", row.SMILES},
                  {"InChI", row.InChI},
                  {"InChIKey", row.InChIKey},
                  {"xLogP", project::CACHE::stable_number(row.xLogP)},
                  {"transformation", row.transformation},
                  {"precursor_name", row.precursor_name},
                  {"precursor_formula", row.precursor_formula},
                  {"precursor_mass", project::CACHE::stable_number(row.precursor_mass)},
                  {"precursor_SMILES", row.precursor_SMILES},
                  {"precursor_InChI", row.precursor_InChI},
                  {"precursor_InChIKey", row.precursor_InChIKey},
                  {"precursor_xLogP", project::CACHE::stable_number(row.precursor_xLogP)},
                  {"main_precursor_name", row.main_precursor_name},
                  {"main_precursor_formula", row.main_precursor_formula},
                  {"main_precursor_mass", project::CACHE::stable_number(row.main_precursor_mass)},
                  {"main_precursor_SMILES", row.main_precursor_SMILES},
                  {"main_precursor_InChI", row.main_precursor_InChI},
                  {"main_precursor_InChIKey", row.main_precursor_InChIKey},
                  {"main_precursor_xLogP", project::CACHE::stable_number(row.main_precursor_xLogP)},
                  {"feature_group", row.feature_group},
                  {"precursor_feature_group", row.precursor_feature_group},
                  {"main_precursor_feature_group", row.main_precursor_feature_group},
                  {"cosine_similarity", project::CACHE::stable_number(row.cosine_similarity)},
                  {"main_precursor_cosine_similarity", project::CACHE::stable_number(row.main_precursor_cosine_similarity)},
                  {"rt_plausibility", project::CACHE::stable_number(row.rt_plausibility)},
                  {"main_precursor_rt_plausibility", project::CACHE::stable_number(row.main_precursor_rt_plausibility)}};
    }

    std::string json_string(const json &value, const char *key)
    {
      return value.contains(key) && !value[key].is_null() ? value[key].get<std::string>() : std::string();
    }

    double json_double(const json &value, const char *key)
    {
      if (!value.contains(key) || value[key].is_null())
      {
        return 0.0;
      }
      const auto text = value[key].get<std::string>();
      if (text == "NaN")
      {
        return std::numeric_limits<double>::quiet_NaN();
      }
      if (text == "Inf")
      {
        return std::numeric_limits<double>::infinity();
      }
      if (text == "-Inf")
      {
        return -std::numeric_limits<double>::infinity();
      }
      return std::stod(text);
    }

    int json_int(const json &value, const char *key)
    {
      return value.contains(key) && !value[key].is_null() ? value[key].get<int>() : 0;
    }

    bool json_bool(const json &value, const char *key)
    {
      return value.contains(key) && !value[key].is_null() ? value[key].get<bool>() : false;
    }

    NTS_FEATURE_ROW feature_row_from_json(const json &value)
    {
      NTS_FEATURE_ROW row;
      row.project_id = json_string(value, "project_id");
      row.analysis = json_string(value, "analysis");
      row.feature = json_string(value, "feature");
      row.feature_component = json_string(value, "feature_component");
      row.feature_group = json_string(value, "feature_group");
      row.adduct = json_string(value, "adduct");
      row.rt = json_double(value, "rt");
      row.mz = json_double(value, "mz");
      row.mass = json_double(value, "mass");
      row.intensity = json_double(value, "intensity");
      row.noise = json_double(value, "noise");
      row.sn = json_double(value, "sn");
      row.area = json_double(value, "area");
      row.rtmin = json_double(value, "rtmin");
      row.rtmax = json_double(value, "rtmax");
      row.width = json_double(value, "width");
      row.mzmin = json_double(value, "mzmin");
      row.mzmax = json_double(value, "mzmax");
      row.ppm = json_double(value, "ppm");
      row.fwhm_rt = json_double(value, "fwhm_rt");
      row.fwhm_mz = json_double(value, "fwhm_mz");
      row.gaussian_A = json_double(value, "gaussian_A");
      row.gaussian_mu = json_double(value, "gaussian_mu");
      row.gaussian_sigma = json_double(value, "gaussian_sigma");
      row.gaussian_r2 = json_double(value, "gaussian_r2");
      row.jaggedness = json_double(value, "jaggedness");
      row.sharpness = json_double(value, "sharpness");
      row.asymmetry = json_double(value, "asymmetry");
      row.modality = json_int(value, "modality");
      row.plates = json_double(value, "plates");
      row.polarity = json_int(value, "polarity");
      row.filtered = json_bool(value, "filtered");
      row.filter = json_string(value, "filter");
      row.filled = json_bool(value, "filled");
      row.correction = json_double(value, "correction");
      row.eic_size = json_int(value, "eic_size");
      row.eic_rt = json_string(value, "eic_rt");
      row.eic_mz = json_string(value, "eic_mz");
      row.eic_intensity = json_string(value, "eic_intensity");
      row.eic_baseline = json_string(value, "eic_baseline");
      row.eic_smoothed = json_string(value, "eic_smoothed");
      row.ms1_size = json_int(value, "ms1_size");
      row.ms1_mz = json_string(value, "ms1_mz");
      row.ms1_intensity = json_string(value, "ms1_intensity");
      row.ms2_size = json_int(value, "ms2_size");
      row.ms2_mz = json_string(value, "ms2_mz");
      row.ms2_intensity = json_string(value, "ms2_intensity");
      return row;
    }

    NTS_SUSPECT_ROW suspect_row_from_json(const json &value)
    {
      NTS_SUSPECT_ROW row;
      row.project_id = json_string(value, "project_id");
      row.analysis = json_string(value, "analysis");
      row.feature = json_string(value, "feature");
      row.candidate_rank = json_int(value, "candidate_rank");
      row.name = json_string(value, "name");
      row.polarity = json_int(value, "polarity");
      row.db_mass = json_double(value, "db_mass");
      row.exp_mass = json_double(value, "exp_mass");
      row.error_mass = json_double(value, "error_mass");
      row.db_rt = json_double(value, "db_rt");
      row.exp_rt = json_double(value, "exp_rt");
      row.error_rt = json_double(value, "error_rt");
      row.intensity = json_double(value, "intensity");
      row.area = json_double(value, "area");
      row.id_level = json_int(value, "id_level");
      row.score = json_double(value, "score");
      row.shared_fragments = json_int(value, "shared_fragments");
      row.cosine_similarity = json_double(value, "cosine_similarity");
      row.formula = json_string(value, "formula");
      row.SMILES = json_string(value, "SMILES");
      row.InChI = json_string(value, "InChI");
      row.InChIKey = json_string(value, "InChIKey");
      row.xLogP = json_double(value, "xLogP");
      row.database_id = json_string(value, "database_id");
      row.db_ms2_size = json_int(value, "db_ms2_size");
      row.db_ms2_mz = json_string(value, "db_ms2_mz");
      row.db_ms2_intensity = json_string(value, "db_ms2_intensity");
      row.db_ms2_formula = json_string(value, "db_ms2_formula");
      row.exp_ms2_size = json_int(value, "exp_ms2_size");
      row.exp_ms2_mz = json_string(value, "exp_ms2_mz");
      row.exp_ms2_intensity = json_string(value, "exp_ms2_intensity");
      return row;
    }

    NTS_INTERNAL_STANDARD_ROW internal_standard_row_from_json(const json &value)
    {
      NTS_INTERNAL_STANDARD_ROW row;
      row.project_id = json_string(value, "project_id");
      row.analysis = json_string(value, "analysis");
      row.feature = json_string(value, "feature");
      row.candidate_rank = json_int(value, "candidate_rank");
      row.name = json_string(value, "name");
      row.polarity = json_int(value, "polarity");
      row.db_mass = json_double(value, "db_mass");
      row.exp_mass = json_double(value, "exp_mass");
      row.error_mass = json_double(value, "error_mass");
      row.db_rt = json_double(value, "db_rt");
      row.exp_rt = json_double(value, "exp_rt");
      row.error_rt = json_double(value, "error_rt");
      row.intensity = json_double(value, "intensity");
      row.area = json_double(value, "area");
      row.id_level = json_int(value, "id_level");
      row.score = json_double(value, "score");
      row.shared_fragments = json_int(value, "shared_fragments");
      row.cosine_similarity = json_double(value, "cosine_similarity");
      row.formula = json_string(value, "formula");
      row.SMILES = json_string(value, "SMILES");
      row.InChI = json_string(value, "InChI");
      row.InChIKey = json_string(value, "InChIKey");
      row.xLogP = json_double(value, "xLogP");
      row.database_id = json_string(value, "database_id");
      row.db_ms2_size = json_int(value, "db_ms2_size");
      row.db_ms2_mz = json_string(value, "db_ms2_mz");
      row.db_ms2_intensity = json_string(value, "db_ms2_intensity");
      row.db_ms2_formula = json_string(value, "db_ms2_formula");
      row.exp_ms2_size = json_int(value, "exp_ms2_size");
      row.exp_ms2_mz = json_string(value, "exp_ms2_mz");
      row.exp_ms2_intensity = json_string(value, "exp_ms2_intensity");
      return row;
    }

    NTS_TRANSFORMATION_PRODUCT_ROW transformation_product_row_from_json(const json &value)
    {
      NTS_TRANSFORMATION_PRODUCT_ROW row;
      row.project_id = json_string(value, "project_id");
      row.name = json_string(value, "name");
      row.formula = json_string(value, "formula");
      row.mass = json_double(value, "mass");
      row.SMILES = json_string(value, "SMILES");
      row.InChI = json_string(value, "InChI");
      row.InChIKey = json_string(value, "InChIKey");
      row.xLogP = json_double(value, "xLogP");
      row.transformation = json_string(value, "transformation");
      row.precursor_name = json_string(value, "precursor_name");
      row.precursor_formula = json_string(value, "precursor_formula");
      row.precursor_mass = json_double(value, "precursor_mass");
      row.precursor_SMILES = json_string(value, "precursor_SMILES");
      row.precursor_InChI = json_string(value, "precursor_InChI");
      row.precursor_InChIKey = json_string(value, "precursor_InChIKey");
      row.precursor_xLogP = json_double(value, "precursor_xLogP");
      row.main_precursor_name = json_string(value, "main_precursor_name");
      row.main_precursor_formula = json_string(value, "main_precursor_formula");
      row.main_precursor_mass = json_double(value, "main_precursor_mass");
      row.main_precursor_SMILES = json_string(value, "main_precursor_SMILES");
      row.main_precursor_InChI = json_string(value, "main_precursor_InChI");
      row.main_precursor_InChIKey = json_string(value, "main_precursor_InChIKey");
      row.main_precursor_xLogP = json_double(value, "main_precursor_xLogP");
      row.feature_group = json_string(value, "feature_group");
      row.precursor_feature_group = json_string(value, "precursor_feature_group");
      row.main_precursor_feature_group = json_string(value, "main_precursor_feature_group");
      row.cosine_similarity = json_double(value, "cosine_similarity");
      row.main_precursor_cosine_similarity = json_double(value, "main_precursor_cosine_similarity");
      row.rt_plausibility = json_double(value, "rt_plausibility");
      row.main_precursor_rt_plausibility = json_double(value, "main_precursor_rt_plausibility");
      return row;
    }

    json feature_rows_to_json(const std::vector<NTS_FEATURE_ROW> &rows)
    {
      json out = json::array();
      for (const auto &row : rows)
      {
        out.push_back(feature_row_to_json(row));
      }
      return out;
    }

    json suspect_rows_to_json(const std::vector<NTS_SUSPECT_ROW> &rows)
    {
      json out = json::array();
      for (const auto &row : rows)
      {
        out.push_back(suspect_row_to_json(row));
      }
      return out;
    }

    json internal_standard_rows_to_json(const std::vector<NTS_INTERNAL_STANDARD_ROW> &rows)
    {
      json out = json::array();
      for (const auto &row : rows)
      {
        out.push_back(internal_standard_row_to_json(row));
      }
      return out;
    }

    json transformation_product_rows_to_json(const std::vector<NTS_TRANSFORMATION_PRODUCT_ROW> &rows)
    {
      json out = json::array();
      for (const auto &row : rows)
      {
        out.push_back(transformation_product_row_to_json(row));
      }
      return out;
    }

    std::vector<NTS_FEATURE_ROW> feature_rows_from_json(const json &rows)
    {
      std::vector<NTS_FEATURE_ROW> out;
      out.reserve(rows.size());
      for (const auto &value : rows)
      {
        out.push_back(feature_row_from_json(value));
      }
      return out;
    }

    std::vector<NTS_SUSPECT_ROW> suspect_rows_from_json(const json &rows)
    {
      std::vector<NTS_SUSPECT_ROW> out;
      out.reserve(rows.size());
      for (const auto &value : rows)
      {
        out.push_back(suspect_row_from_json(value));
      }
      return out;
    }

    std::vector<NTS_INTERNAL_STANDARD_ROW> internal_standard_rows_from_json(const json &rows)
    {
      std::vector<NTS_INTERNAL_STANDARD_ROW> out;
      out.reserve(rows.size());
      for (const auto &value : rows)
      {
        out.push_back(internal_standard_row_from_json(value));
      }
      return out;
    }

    std::vector<NTS_TRANSFORMATION_PRODUCT_ROW> transformation_product_rows_from_json(const json &rows)
    {
      std::vector<NTS_TRANSFORMATION_PRODUCT_ROW> out;
      out.reserve(rows.size());
      for (const auto &value : rows)
      {
        out.push_back(transformation_product_row_from_json(value));
      }
      return out;
    }

    void replace_suspect_rows(duckdb_connection con,
                              const std::string &project_id,
                              const std::vector<std::string> &analyses,
                              const std::vector<NTS_SUSPECT_ROW> &rows)
    {
      delete_rows_for_analyses(con, "NTS_SUSPECTS", project_id, analyses);
      nts::SUSPECTS suspects;
      for (const auto &row : rows)
      {
        nts::SUSPECT value;
        value.analysis = row.analysis;
        value.feature = row.feature;
        value.candidate_rank = row.candidate_rank;
        value.name = row.name;
        value.polarity = row.polarity;
        value.db_mass = row.db_mass;
        value.exp_mass = row.exp_mass;
        value.error_mass = row.error_mass;
        value.db_rt = row.db_rt;
        value.exp_rt = row.exp_rt;
        value.error_rt = row.error_rt;
        value.intensity = row.intensity;
        value.area = row.area;
        value.id_level = row.id_level;
        value.score = row.score;
        value.shared_fragments = row.shared_fragments;
        value.cosine_similarity = row.cosine_similarity;
        value.formula = row.formula;
        value.SMILES = row.SMILES;
        value.InChI = row.InChI;
        value.InChIKey = row.InChIKey;
        value.xLogP = row.xLogP;
        value.database_id = row.database_id;
        value.db_ms2_size = row.db_ms2_size;
        value.db_ms2_mz = row.db_ms2_mz;
        value.db_ms2_intensity = row.db_ms2_intensity;
        value.db_ms2_formula = row.db_ms2_formula;
        value.exp_ms2_size = row.exp_ms2_size;
        value.exp_ms2_mz = row.exp_ms2_mz;
        value.exp_ms2_intensity = row.exp_ms2_intensity;
        suspects.append(value);
      }
      insert_suspects_rows(con, project_id, suspects);
    }

    void replace_internal_standard_rows(duckdb_connection con,
                                        const std::string &project_id,
                                        const std::vector<std::string> &analyses,
                                        const std::vector<NTS_INTERNAL_STANDARD_ROW> &rows)
    {
      delete_rows_for_analyses(con, "NTS_INTERNAL_STANDARDS", project_id, analyses);
      nts::INTERNAL_STANDARDS internal_standards;
      for (const auto &row : rows)
      {
        nts::INTERNAL_STANDARD value;
        value.analysis = row.analysis;
        value.feature = row.feature;
        value.candidate_rank = row.candidate_rank;
        value.name = row.name;
        value.polarity = row.polarity;
        value.db_mass = row.db_mass;
        value.exp_mass = row.exp_mass;
        value.error_mass = row.error_mass;
        value.db_rt = row.db_rt;
        value.exp_rt = row.exp_rt;
        value.error_rt = row.error_rt;
        value.intensity = row.intensity;
        value.area = row.area;
        value.id_level = row.id_level;
        value.score = row.score;
        value.shared_fragments = row.shared_fragments;
        value.cosine_similarity = row.cosine_similarity;
        value.formula = row.formula;
        value.SMILES = row.SMILES;
        value.InChI = row.InChI;
        value.InChIKey = row.InChIKey;
        value.xLogP = row.xLogP;
        value.database_id = row.database_id;
        value.db_ms2_size = row.db_ms2_size;
        value.db_ms2_mz = row.db_ms2_mz;
        value.db_ms2_intensity = row.db_ms2_intensity;
        value.db_ms2_formula = row.db_ms2_formula;
        value.exp_ms2_size = row.exp_ms2_size;
        value.exp_ms2_mz = row.exp_ms2_mz;
        value.exp_ms2_intensity = row.exp_ms2_intensity;
        internal_standards.append(value);
      }
      insert_internal_standards_rows(con, project_id, internal_standards);
    }

    void replace_transformation_product_rows(duckdb_connection con,
                                             const std::string &project_id,
                                             const std::vector<NTS_TRANSFORMATION_PRODUCT_ROW> &rows)
    {
      delete_transformation_products(con, project_id);
      assign_transformation_products::TRANSFORMATION_PRODUCTS out;
      for (const auto &row : rows)
      {
        assign_transformation_products::TPInputRow value;
        value.name = row.name;
        value.formula = row.formula;
        value.mass = row.mass;
        value.SMILES = row.SMILES;
        value.InChI = row.InChI;
        value.InChIKey = row.InChIKey;
        value.xLogP = row.xLogP;
        value.transformation = row.transformation;
        value.precursor_name = row.precursor_name;
        value.precursor_formula = row.precursor_formula;
        value.precursor_mass = row.precursor_mass;
        value.precursor_SMILES = row.precursor_SMILES;
        value.precursor_InChI = row.precursor_InChI;
        value.precursor_InChIKey = row.precursor_InChIKey;
        value.precursor_xLogP = row.precursor_xLogP;
        value.main_precursor_name = row.main_precursor_name;
        value.main_precursor_formula = row.main_precursor_formula;
        value.main_precursor_mass = row.main_precursor_mass;
        value.main_precursor_SMILES = row.main_precursor_SMILES;
        value.main_precursor_InChI = row.main_precursor_InChI;
        value.main_precursor_InChIKey = row.main_precursor_InChIKey;
        value.main_precursor_xLogP = row.main_precursor_xLogP;
        out.append_row(value,
                       row.feature_group,
                       row.precursor_feature_group,
                       row.main_precursor_feature_group,
                       row.cosine_similarity,
                       row.main_precursor_cosine_similarity,
                       row.rt_plausibility,
                       row.main_precursor_rt_plausibility);
      }
      insert_transformation_products_rows(con, project_id, out);
    }

    json feature_snapshot_payload(const std::shared_ptr<CONTEXT> &ctx,
                                  const std::vector<std::string> &analyses)
    {
      return json{{"features", feature_rows_to_json(nts::PROJECT_NON_TARGET_ANALYSIS(ctx).get_features(analyses, true))}};
    }

    json suspect_snapshot_payload(const std::shared_ptr<CONTEXT> &ctx,
                                  const std::vector<std::string> &analyses)
    {
      return json{{"suspects", suspect_rows_to_json(nts::PROJECT_NON_TARGET_ANALYSIS(ctx).get_suspects(analyses))}};
    }

    json internal_standard_snapshot_payload(const std::shared_ptr<CONTEXT> &ctx,
                                            const std::vector<std::string> &analyses)
    {
      return json{{"internal_standards", internal_standard_rows_to_json(nts::PROJECT_NON_TARGET_ANALYSIS(ctx).get_internal_standards(analyses))}};
    }

    json transformation_product_snapshot_payload(const std::shared_ptr<CONTEXT> &ctx)
    {
      return json{{"transformation_products", transformation_product_rows_to_json(nts::PROJECT_NON_TARGET_ANALYSIS(ctx).get_transformation_products())}};
    }

    void restore_feature_snapshot(const std::shared_ptr<CONTEXT> &ctx,
                                  const std::vector<std::string> &analyses,
                                  const json &snapshot)
    {
      auto guard = connect_checked(ctx);
      try
      {
        detail::run_sql(guard.get(), "BEGIN", "begin restore cached NTS features");
        const auto rows = feature_rows_from_json(snapshot.at("features"));
        delete_features_for_analyses(guard.get(), ctx->project_id, analyses);
        insert_feature_rows(guard.get(), ctx->project_id, features_by_analysis_from_rows(rows, analyses));
        detail::run_sql(guard.get(), "COMMIT", "commit restore cached NTS features");
      }
      catch (...)
      {
        try
        {
          detail::run_sql(guard.get(), "ROLLBACK", "rollback restore cached NTS features");
        }
        catch (...)
        {
        }
        throw;
      }
    }

    void restore_suspect_snapshot(const std::shared_ptr<CONTEXT> &ctx,
                                  const std::vector<std::string> &analyses,
                                  const json &snapshot)
    {
      auto guard = connect_checked(ctx);
      try
      {
        detail::run_sql(guard.get(), "BEGIN", "begin restore cached NTS suspects");
        replace_suspect_rows(guard.get(), ctx->project_id, analyses, suspect_rows_from_json(snapshot.at("suspects")));
        detail::run_sql(guard.get(), "COMMIT", "commit restore cached NTS suspects");
      }
      catch (...)
      {
        try
        {
          detail::run_sql(guard.get(), "ROLLBACK", "rollback restore cached NTS suspects");
        }
        catch (...)
        {
        }
        throw;
      }
    }

    void restore_internal_standard_snapshot(const std::shared_ptr<CONTEXT> &ctx,
                                            const std::vector<std::string> &analyses,
                                            const json &snapshot)
    {
      auto guard = connect_checked(ctx);
      try
      {
        detail::run_sql(guard.get(), "BEGIN", "begin restore cached NTS internal standards");
        replace_internal_standard_rows(guard.get(), ctx->project_id, analyses, internal_standard_rows_from_json(snapshot.at("internal_standards")));
        detail::run_sql(guard.get(), "COMMIT", "commit restore cached NTS internal standards");
      }
      catch (...)
      {
        try
        {
          detail::run_sql(guard.get(), "ROLLBACK", "rollback restore cached NTS internal standards");
        }
        catch (...)
        {
        }
        throw;
      }
    }

    void restore_transformation_product_snapshot(const std::shared_ptr<CONTEXT> &ctx,
                                                 const json &snapshot)
    {
      auto guard = connect_checked(ctx);
      try
      {
        detail::run_sql(guard.get(), "BEGIN", "begin restore cached NTS transformation products");
        replace_transformation_product_rows(guard.get(), ctx->project_id, transformation_product_rows_from_json(snapshot.at("transformation_products")));
        detail::run_sql(guard.get(), "COMMIT", "commit restore cached NTS transformation products");
      }
      catch (...)
      {
        try
        {
          detail::run_sql(guard.get(), "ROLLBACK", "rollback restore cached NTS transformation products");
        }
        catch (...)
        {
        }
        throw;
      }
    }

    NTS_FEATURE_ROW feature_row_from_result(duckdb_result &result, idx_t row)
    {
      NTS_FEATURE_ROW value;
      value.project_id = detail::result_varchar(&result, 0, row);
      value.analysis = detail::result_varchar(&result, 1, row);
      value.feature = detail::result_varchar(&result, 2, row);
      value.feature_component = detail::result_varchar(&result, 3, row);
      value.feature_group = detail::result_varchar(&result, 4, row);
      value.adduct = detail::result_varchar(&result, 5, row);
      value.rt = nullable_double(duckdb_value_double(&result, 6, row));
      value.mz = nullable_double(duckdb_value_double(&result, 7, row));
      value.mass = nullable_double(duckdb_value_double(&result, 8, row));
      value.intensity = nullable_double(duckdb_value_double(&result, 9, row));
      value.noise = nullable_double(duckdb_value_double(&result, 10, row));
      value.sn = nullable_double(duckdb_value_double(&result, 11, row));
      value.area = nullable_double(duckdb_value_double(&result, 12, row));
      value.rtmin = nullable_double(duckdb_value_double(&result, 13, row));
      value.rtmax = nullable_double(duckdb_value_double(&result, 14, row));
      value.width = nullable_double(duckdb_value_double(&result, 15, row));
      value.mzmin = nullable_double(duckdb_value_double(&result, 16, row));
      value.mzmax = nullable_double(duckdb_value_double(&result, 17, row));
      value.ppm = nullable_double(duckdb_value_double(&result, 18, row));
      value.fwhm_rt = nullable_double(duckdb_value_double(&result, 19, row));
      value.fwhm_mz = nullable_double(duckdb_value_double(&result, 20, row));
      value.gaussian_A = nullable_double(duckdb_value_double(&result, 21, row));
      value.gaussian_mu = nullable_double(duckdb_value_double(&result, 22, row));
      value.gaussian_sigma = nullable_double(duckdb_value_double(&result, 23, row));
      value.gaussian_r2 = nullable_double(duckdb_value_double(&result, 24, row));
      value.jaggedness = nullable_double(duckdb_value_double(&result, 25, row));
      value.sharpness = nullable_double(duckdb_value_double(&result, 26, row));
      value.asymmetry = nullable_double(duckdb_value_double(&result, 27, row));
      value.modality = nullable_int(duckdb_value_int32(&result, 28, row));
      value.plates = nullable_double(duckdb_value_double(&result, 29, row));
      value.polarity = nullable_int(duckdb_value_int32(&result, 30, row));
      value.filtered = duckdb_value_boolean(&result, 31, row) != 0;
      value.filter = detail::result_varchar(&result, 32, row);
      value.filled = duckdb_value_boolean(&result, 33, row) != 0;
      value.correction = nullable_double(duckdb_value_double(&result, 34, row));
      value.eic_size = nullable_int(duckdb_value_int32(&result, 35, row));
      value.eic_rt = detail::result_varchar(&result, 36, row);
      value.eic_mz = detail::result_varchar(&result, 37, row);
      value.eic_intensity = detail::result_varchar(&result, 38, row);
      value.eic_baseline = detail::result_varchar(&result, 39, row);
      value.eic_smoothed = detail::result_varchar(&result, 40, row);
      value.ms1_size = nullable_int(duckdb_value_int32(&result, 41, row));
      value.ms1_mz = detail::result_varchar(&result, 42, row);
      value.ms1_intensity = detail::result_varchar(&result, 43, row);
      value.ms2_size = nullable_int(duckdb_value_int32(&result, 44, row));
      value.ms2_mz = detail::result_varchar(&result, 45, row);
      value.ms2_intensity = detail::result_varchar(&result, 46, row);
      value.created_at = detail::result_varchar(&result, 47, row);
      return value;
    }

    NTS_SUSPECT_ROW suspect_row_from_result(duckdb_result &result, idx_t row)
    {
      NTS_SUSPECT_ROW value;
      value.project_id = detail::result_varchar(&result, 0, row);
      value.analysis = detail::result_varchar(&result, 1, row);
      value.feature = detail::result_varchar(&result, 2, row);
      value.candidate_rank = duckdb_value_int32(&result, 3, row);
      value.name = detail::result_varchar(&result, 4, row);
      value.polarity = duckdb_value_int32(&result, 5, row);
      value.db_mass = duckdb_value_double(&result, 6, row);
      value.exp_mass = duckdb_value_double(&result, 7, row);
      value.error_mass = duckdb_value_double(&result, 8, row);
      value.db_rt = duckdb_value_double(&result, 9, row);
      value.exp_rt = duckdb_value_double(&result, 10, row);
      value.error_rt = duckdb_value_double(&result, 11, row);
      value.intensity = duckdb_value_double(&result, 12, row);
      value.area = duckdb_value_double(&result, 13, row);
      value.id_level = duckdb_value_int32(&result, 14, row);
      value.score = duckdb_value_double(&result, 15, row);
      value.shared_fragments = duckdb_value_int32(&result, 16, row);
      value.cosine_similarity = duckdb_value_double(&result, 17, row);
      value.formula = detail::result_varchar(&result, 18, row);
      value.SMILES = detail::result_varchar(&result, 19, row);
      value.InChI = detail::result_varchar(&result, 20, row);
      value.InChIKey = detail::result_varchar(&result, 21, row);
      value.xLogP = duckdb_value_double(&result, 22, row);
      value.database_id = detail::result_varchar(&result, 23, row);
      value.db_ms2_size = duckdb_value_int32(&result, 24, row);
      value.db_ms2_mz = detail::result_varchar(&result, 25, row);
      value.db_ms2_intensity = detail::result_varchar(&result, 26, row);
      value.db_ms2_formula = detail::result_varchar(&result, 27, row);
      value.exp_ms2_size = duckdb_value_int32(&result, 28, row);
      value.exp_ms2_mz = detail::result_varchar(&result, 29, row);
      value.exp_ms2_intensity = detail::result_varchar(&result, 30, row);
      value.created_at = detail::result_varchar(&result, 31, row);
      return value;
    }

    NTS_INTERNAL_STANDARD_ROW internal_standard_row_from_result(duckdb_result &result, idx_t row)
    {
      NTS_INTERNAL_STANDARD_ROW value;
      value.project_id = detail::result_varchar(&result, 0, row);
      value.analysis = detail::result_varchar(&result, 1, row);
      value.feature = detail::result_varchar(&result, 2, row);
      value.candidate_rank = duckdb_value_int32(&result, 3, row);
      value.name = detail::result_varchar(&result, 4, row);
      value.polarity = duckdb_value_int32(&result, 5, row);
      value.db_mass = duckdb_value_double(&result, 6, row);
      value.exp_mass = duckdb_value_double(&result, 7, row);
      value.error_mass = duckdb_value_double(&result, 8, row);
      value.db_rt = duckdb_value_double(&result, 9, row);
      value.exp_rt = duckdb_value_double(&result, 10, row);
      value.error_rt = duckdb_value_double(&result, 11, row);
      value.intensity = duckdb_value_double(&result, 12, row);
      value.area = duckdb_value_double(&result, 13, row);
      value.id_level = duckdb_value_int32(&result, 14, row);
      value.score = duckdb_value_double(&result, 15, row);
      value.shared_fragments = duckdb_value_int32(&result, 16, row);
      value.cosine_similarity = duckdb_value_double(&result, 17, row);
      value.formula = detail::result_varchar(&result, 18, row);
      value.SMILES = detail::result_varchar(&result, 19, row);
      value.InChI = detail::result_varchar(&result, 20, row);
      value.InChIKey = detail::result_varchar(&result, 21, row);
      value.xLogP = duckdb_value_double(&result, 22, row);
      value.database_id = detail::result_varchar(&result, 23, row);
      value.db_ms2_size = duckdb_value_int32(&result, 24, row);
      value.db_ms2_mz = detail::result_varchar(&result, 25, row);
      value.db_ms2_intensity = detail::result_varchar(&result, 26, row);
      value.db_ms2_formula = detail::result_varchar(&result, 27, row);
      value.exp_ms2_size = duckdb_value_int32(&result, 28, row);
      value.exp_ms2_mz = detail::result_varchar(&result, 29, row);
      value.exp_ms2_intensity = detail::result_varchar(&result, 30, row);
      value.created_at = detail::result_varchar(&result, 31, row);
      return value;
    }

    NTS_TRANSFORMATION_PRODUCT_ROW transformation_product_row_from_result(duckdb_result &result, idx_t row)
    {
      NTS_TRANSFORMATION_PRODUCT_ROW value;
      value.project_id = detail::result_varchar(&result, 0, row);
      value.name = detail::result_varchar(&result, 1, row);
      value.formula = detail::result_varchar(&result, 2, row);
      value.mass = duckdb_value_double(&result, 3, row);
      value.SMILES = detail::result_varchar(&result, 4, row);
      value.InChI = detail::result_varchar(&result, 5, row);
      value.InChIKey = detail::result_varchar(&result, 6, row);
      value.xLogP = duckdb_value_double(&result, 7, row);
      value.transformation = detail::result_varchar(&result, 8, row);
      value.precursor_name = detail::result_varchar(&result, 9, row);
      value.precursor_formula = detail::result_varchar(&result, 10, row);
      value.precursor_mass = duckdb_value_double(&result, 11, row);
      value.precursor_SMILES = detail::result_varchar(&result, 12, row);
      value.precursor_InChI = detail::result_varchar(&result, 13, row);
      value.precursor_InChIKey = detail::result_varchar(&result, 14, row);
      value.precursor_xLogP = duckdb_value_double(&result, 15, row);
      value.main_precursor_name = detail::result_varchar(&result, 16, row);
      value.main_precursor_formula = detail::result_varchar(&result, 17, row);
      value.main_precursor_mass = duckdb_value_double(&result, 18, row);
      value.main_precursor_SMILES = detail::result_varchar(&result, 19, row);
      value.main_precursor_InChI = detail::result_varchar(&result, 20, row);
      value.main_precursor_InChIKey = detail::result_varchar(&result, 21, row);
      value.main_precursor_xLogP = duckdb_value_double(&result, 22, row);
      value.feature_group = detail::result_varchar(&result, 23, row);
      value.precursor_feature_group = detail::result_varchar(&result, 24, row);
      value.main_precursor_feature_group = detail::result_varchar(&result, 25, row);
      value.cosine_similarity = duckdb_value_double(&result, 26, row);
      value.main_precursor_cosine_similarity = duckdb_value_double(&result, 27, row);
      value.rt_plausibility = duckdb_value_double(&result, 28, row);
      value.main_precursor_rt_plausibility = duckdb_value_double(&result, 29, row);
      value.created_at = detail::result_varchar(&result, 30, row);
      return value;
    }

  } // namespace

  PROJECT_NON_TARGET_ANALYSIS::PROJECT_NON_TARGET_ANALYSIS(std::shared_ptr<project::api::CONTEXT> ctx)
      : ctx_(std::move(ctx))
  {
    PROJECT root(ctx_->db_path, ctx_->project_id);
    root.set_domain("mass_spec_nta");
    mass_spec::PROJECT_MASS_SPEC::create_schema(ctx_);
    mass_spec::PROJECT_MASS_SPEC::validate_schema(ctx_);
    create_schema(ctx_);
    validate_schema(ctx_);
  }

  bool PROJECT_NON_TARGET_ANALYSIS::find_features(const std::vector<std::string> &analyses,
                                                  const std::vector<float> &rt_windows_min,
                                                  const std::vector<float> &rt_windows_max,
                                                  float ppm_threshold,
                                                  float noise_threshold,
                                                  float min_snr,
                                                  int min_traces,
                                                  float baseline_window,
                                                  float max_width,
                                                  float base_quantile,
                                                  const std::string &debug_analysis,
                                                  float debug_mz,
                                                  int debug_spec_idx)
  {
    const auto selected_analyses = load_selected_analyses(ctx_, analyses);
    if (selected_analyses.empty())
    {
      return true;
    }

    const nts::NTS_INFO info = nts_info_from_analysis_rows(selected_analyses);
    const auto analysis_names = info.analyses;
    json cache_request = project::CACHE::make_request_payload("find_features", analysis_names);
    cache_request["rt_windows_min"] = project::CACHE::json_array(rt_windows_min);
    cache_request["rt_windows_max"] = project::CACHE::json_array(rt_windows_max);
    cache_request["ppm_threshold"] = project::CACHE::stable_number(ppm_threshold);
    cache_request["noise_threshold"] = project::CACHE::stable_number(noise_threshold);
    cache_request["min_snr"] = project::CACHE::stable_number(min_snr);
    cache_request["min_traces"] = min_traces;
    cache_request["baseline_window"] = project::CACHE::stable_number(baseline_window);
    cache_request["max_width"] = project::CACHE::stable_number(max_width);
    cache_request["base_quantile"] = project::CACHE::stable_number(base_quantile);
    cache_request["debug_analysis"] = debug_analysis;
    cache_request["debug_mz"] = project::CACHE::stable_number(debug_mz);
    cache_request["debug_spec_idx"] = debug_spec_idx;
    cache_request["analysis_files"] = project::CACHE::json_array(info.files);
    const auto headers_for_cache = load_selected_headers(ctx_, selected_analyses);
    json header_counts = json::array();
    for (const auto &headers : headers_for_cache)
    {
      header_counts.push_back(headers.size());
    }
    cache_request["spectra_header_counts"] = header_counts;
    const auto hash = project::CACHE::hash_json(cache_request);
    project::CACHE cache(ctx_);
    if (cache.restore_json_if_present(hash, [&](const json &snapshot)
                                      { restore_feature_snapshot(ctx_, analysis_names, snapshot); }))
    {
      return true;
    }

    const auto headers = load_selected_headers(ctx_, selected_analyses);
    std::vector<nts::FEATURES> features_cpp;
    std::vector<nts::SUSPECTS> suspects_cpp;
    std::vector<nts::INTERNAL_STANDARDS> internal_standards_cpp;
    nts::NTS_DATA nts_data(info, headers, features_cpp, suspects_cpp, internal_standards_cpp);
    nts_data.find_features(rt_windows_min,
                           rt_windows_max,
                           ppm_threshold,
                           noise_threshold,
                           min_snr,
                           min_traces,
                           baseline_window,
                           max_width,
                           base_quantile,
                           debug_analysis,
                           debug_mz,
                           debug_spec_idx);

    auto guard = connect_checked(ctx_);
    try
    {
      detail::run_sql(guard.get(), "BEGIN", "begin project NTS find_features transaction");
      delete_features_for_analyses(guard.get(), ctx_->project_id, info.analyses);
      insert_feature_rows(guard.get(), ctx_->project_id, nts_data.features);
      detail::run_sql(guard.get(), "COMMIT", "commit project NTS find_features transaction");
    }
    catch (...)
    {
      try
      {
        detail::run_sql(guard.get(), "ROLLBACK", "rollback project NTS find_features transaction");
      }
      catch (...)
      {
      }
      throw;
    }

    cache.put_json("ProjectNonTargetAnalysis::find_features",
                   hash,
                   project::CACHE::describe_scope("find_features", analysis_names),
                   feature_snapshot_payload(ctx_, analysis_names));
    return true;
  }

  bool PROJECT_NON_TARGET_ANALYSIS::load_features_ms1(const std::vector<std::string> &analyses,
                                                      bool filtered,
                                                      const std::vector<float> &rt_window,
                                                      const std::vector<float> &mz_window,
                                                      float min_traces_intensity,
                                                      float mz_clust,
                                                      float presence)
  {
    const auto selected_analyses = load_selected_analyses(ctx_, analyses);
    if (selected_analyses.empty())
    {
      return true;
    }
    const auto analysis_names = analysis_names_from_rows(selected_analyses);
    json cache_request = project::CACHE::make_request_payload("load_features_ms1", analysis_names);
    cache_request["filtered"] = filtered;
    cache_request["rt_window"] = project::CACHE::json_array(rt_window);
    cache_request["mz_window"] = project::CACHE::json_array(mz_window);
    cache_request["min_traces_intensity"] = project::CACHE::stable_number(min_traces_intensity);
    cache_request["mz_clust"] = project::CACHE::stable_number(mz_clust);
    cache_request["presence"] = project::CACHE::stable_number(presence);
    cache_request["upstream_features"] = feature_snapshot_payload(ctx_, analysis_names)["features"];
    project::CACHE cache(ctx_);
    const auto hash = project::CACHE::hash_json(cache_request);
    if (cache.restore_json_if_present(hash, [&](const json &snapshot)
                                 { restore_feature_snapshot(ctx_, analysis_names, snapshot); }))
    {
      return true;
    }
    auto nts_data = load_nts_data_with_features(ctx_, selected_analyses, true);
    nts_data.load_features_ms1(filtered, rt_window, mz_window, min_traces_intensity, mz_clust, presence);
    replace_feature_rows(ctx_, analysis_names, nts_data.features);
    cache.put_json(
                         "ProjectNonTargetAnalysis::load_features_ms1",
                         hash,
                         project::CACHE::describe_scope("load_features_ms1", analysis_names),
                         feature_snapshot_payload(ctx_, analysis_names));
    return true;
  }

  bool PROJECT_NON_TARGET_ANALYSIS::load_features_ms2(const std::vector<std::string> &analyses,
                                                      bool filtered,
                                                      float min_traces_intensity,
                                                      float isolation_window,
                                                      float mz_clust,
                                                      float presence)
  {
    const auto selected_analyses = load_selected_analyses(ctx_, analyses);
    if (selected_analyses.empty())
    {
      return true;
    }
    const auto analysis_names = analysis_names_from_rows(selected_analyses);
    json cache_request = project::CACHE::make_request_payload("load_features_ms2", analysis_names);
    cache_request["filtered"] = filtered;
    cache_request["min_traces_intensity"] = project::CACHE::stable_number(min_traces_intensity);
    cache_request["isolation_window"] = project::CACHE::stable_number(isolation_window);
    cache_request["mz_clust"] = project::CACHE::stable_number(mz_clust);
    cache_request["presence"] = project::CACHE::stable_number(presence);
    cache_request["upstream_features"] = feature_snapshot_payload(ctx_, analysis_names)["features"];
    project::CACHE cache(ctx_);
    const auto hash = project::CACHE::hash_json(cache_request);
    if (cache.restore_json_if_present(hash, [&](const json &snapshot)
                                 { restore_feature_snapshot(ctx_, analysis_names, snapshot); }))
    {
      return true;
    }
    auto nts_data = load_nts_data_with_features(ctx_, selected_analyses, true);
    nts_data.load_features_ms2(filtered, min_traces_intensity, isolation_window, mz_clust, presence);
    replace_feature_rows(ctx_, analysis_names, nts_data.features);
    cache.put_json(
                         "ProjectNonTargetAnalysis::load_features_ms2",
                         hash,
                         project::CACHE::describe_scope("load_features_ms2", analysis_names),
                         feature_snapshot_payload(ctx_, analysis_names));
    return true;
  }

  bool PROJECT_NON_TARGET_ANALYSIS::create_components(const std::vector<std::string> &analyses,
                                                      const std::vector<float> &rt_window,
                                                      float min_correlation,
                                                      float debug_rt,
                                                      const std::string &debug_analysis)
  {
    const auto selected_analyses = load_selected_analyses(ctx_, analyses);
    if (selected_analyses.empty())
    {
      return true;
    }
    const auto analysis_names = analysis_names_from_rows(selected_analyses);
    json cache_request = project::CACHE::make_request_payload("create_components", analysis_names);
    cache_request["rt_window"] = project::CACHE::json_array(rt_window);
    cache_request["min_correlation"] = project::CACHE::stable_number(min_correlation);
    cache_request["debug_rt"] = project::CACHE::stable_number(debug_rt);
    cache_request["debug_analysis"] = debug_analysis;
    cache_request["upstream_features"] = feature_snapshot_payload(ctx_, analysis_names)["features"];
    project::CACHE cache(ctx_);
    const auto hash = project::CACHE::hash_json(cache_request);
    if (cache.restore_json_if_present(hash, [&](const json &snapshot)
                                 { restore_feature_snapshot(ctx_, analysis_names, snapshot); }))
    {
      return true;
    }
    auto nts_data = load_nts_data_with_features(ctx_, selected_analyses, true);
    nts_data.create_components(rt_window, min_correlation, debug_rt, debug_analysis);
    replace_feature_rows(ctx_, analysis_names, nts_data.features);
    cache.put_json(
                         "ProjectNonTargetAnalysis::create_components",
                         hash,
                         project::CACHE::describe_scope("create_components", analysis_names),
                         feature_snapshot_payload(ctx_, analysis_names));
    return true;
  }

  bool PROJECT_NON_TARGET_ANALYSIS::annotate_components(const std::vector<std::string> &analyses,
                                                        int max_isotopes,
                                                        int max_charge,
                                                        int max_gaps,
                                                        float ppm,
                                                        const std::string &debug_component,
                                                        const std::string &debug_analysis)
  {
    const auto selected_analyses = load_selected_analyses(ctx_, analyses);
    if (selected_analyses.empty())
    {
      return true;
    }
    const auto analysis_names = analysis_names_from_rows(selected_analyses);
    json cache_request = project::CACHE::make_request_payload("annotate_components", analysis_names);
    cache_request["max_isotopes"] = max_isotopes;
    cache_request["max_charge"] = max_charge;
    cache_request["max_gaps"] = max_gaps;
    cache_request["ppm"] = project::CACHE::stable_number(ppm);
    cache_request["debug_component"] = debug_component;
    cache_request["debug_analysis"] = debug_analysis;
    cache_request["upstream_features"] = feature_snapshot_payload(ctx_, analysis_names)["features"];
    project::CACHE cache(ctx_);
    const auto hash = project::CACHE::hash_json(cache_request);
    if (cache.restore_json_if_present(hash, [&](const json &snapshot)
                                 { restore_feature_snapshot(ctx_, analysis_names, snapshot); }))
    {
      return true;
    }
    auto nts_data = load_nts_data_with_features(ctx_, selected_analyses, true);
    nts_data.annotate_components(max_isotopes, max_charge, max_gaps, ppm, debug_component, debug_analysis);
    replace_feature_rows(ctx_, analysis_names, nts_data.features);
    cache.put_json(
                         "ProjectNonTargetAnalysis::annotate_components",
                         hash,
                         project::CACHE::describe_scope("annotate_components", analysis_names),
                         feature_snapshot_payload(ctx_, analysis_names));
    return true;
  }

  bool PROJECT_NON_TARGET_ANALYSIS::group_features(const std::vector<std::string> &analyses,
                                                   const std::string &method,
                                                   float rt_deviation,
                                                   float ppm,
                                                   int min_samples,
                                                   float bin_size,
                                                   bool filtered,
                                                   bool debug,
                                                   float debug_rt)
  {
    const auto selected_analyses = load_selected_analyses(ctx_, analyses);
    if (selected_analyses.empty())
    {
      return true;
    }
    const auto analysis_names = analysis_names_from_rows(selected_analyses);
    json cache_request = project::CACHE::make_request_payload("group_features", analysis_names);
    cache_request["method"] = method;
    cache_request["rt_deviation"] = project::CACHE::stable_number(rt_deviation);
    cache_request["ppm"] = project::CACHE::stable_number(ppm);
    cache_request["min_samples"] = min_samples;
    cache_request["bin_size"] = project::CACHE::stable_number(bin_size);
    cache_request["filtered"] = filtered;
    cache_request["debug"] = debug;
    cache_request["debug_rt"] = project::CACHE::stable_number(debug_rt);
    cache_request["upstream_features"] = feature_snapshot_payload(ctx_, analysis_names)["features"];
    if (method == "internal_standards")
    {
      cache_request["upstream_internal_standards"] = internal_standard_snapshot_payload(ctx_, analysis_names)["internal_standards"];
    }
    project::CACHE cache(ctx_);
    const auto hash = project::CACHE::hash_json(cache_request);
    if (cache.restore_json_if_present(hash, [&](const json &snapshot)
                                 { restore_feature_snapshot(ctx_, analysis_names, snapshot); }))
    {
      return true;
    }
    auto nts_data = load_nts_data_with_features(ctx_, selected_analyses, filtered, method == "internal_standards", false);
    nts_data.group_features(method, rt_deviation, ppm, min_samples, bin_size, debug, debug_rt);
    replace_feature_rows(ctx_, analysis_names, nts_data.features);
    cache.put_json(
                         "ProjectNonTargetAnalysis::group_features",
                         hash,
                         project::CACHE::describe_scope("group_features", analysis_names),
                         feature_snapshot_payload(ctx_, analysis_names));
    return true;
  }

  bool PROJECT_NON_TARGET_ANALYSIS::fill_features(const std::vector<std::string> &analyses,
                                                  bool within_replicate,
                                                  bool filtered,
                                                  float rt_expand,
                                                  float mz_expand,
                                                  float max_peak_width,
                                                  float min_traces_intensity,
                                                  int min_number_traces,
                                                  float min_intensity,
                                                  float rt_apex_deviation,
                                                  float min_signal_to_noise_ratio,
                                                  float min_gaussian_fit,
                                                  const std::string &debug_fg)
  {
    const auto selected_analyses = load_selected_analyses(ctx_, analyses);
    if (selected_analyses.empty())
    {
      return true;
    }
    const auto analysis_names = analysis_names_from_rows(selected_analyses);
    json cache_request = project::CACHE::make_request_payload("fill_features", analysis_names);
    cache_request["within_replicate"] = within_replicate;
    cache_request["filtered"] = filtered;
    cache_request["rt_expand"] = project::CACHE::stable_number(rt_expand);
    cache_request["mz_expand"] = project::CACHE::stable_number(mz_expand);
    cache_request["max_peak_width"] = project::CACHE::stable_number(max_peak_width);
    cache_request["min_traces_intensity"] = project::CACHE::stable_number(min_traces_intensity);
    cache_request["min_number_traces"] = min_number_traces;
    cache_request["min_intensity"] = project::CACHE::stable_number(min_intensity);
    cache_request["rt_apex_deviation"] = project::CACHE::stable_number(rt_apex_deviation);
    cache_request["min_signal_to_noise_ratio"] = project::CACHE::stable_number(min_signal_to_noise_ratio);
    cache_request["min_gaussian_fit"] = project::CACHE::stable_number(min_gaussian_fit);
    cache_request["debug_fg"] = debug_fg;
    cache_request["upstream_features"] = feature_snapshot_payload(ctx_, analysis_names)["features"];
    project::CACHE cache(ctx_);
    const auto hash = project::CACHE::hash_json(cache_request);
    if (cache.restore_json_if_present(hash, [&](const json &snapshot)
                                 { restore_feature_snapshot(ctx_, analysis_names, snapshot); }))
    {
      return true;
    }
    auto nts_data = load_nts_data_with_features(ctx_, selected_analyses, true);
    nts_data.fill_features(within_replicate,
                           filtered,
                           rt_expand,
                           mz_expand,
                           max_peak_width,
                           min_traces_intensity,
                           min_number_traces,
                           min_intensity,
                           rt_apex_deviation,
                           min_signal_to_noise_ratio,
                           min_gaussian_fit,
                           debug_fg);
    replace_feature_rows(ctx_, analysis_names, nts_data.features);
    cache.put_json(
                         "ProjectNonTargetAnalysis::fill_features",
                         hash,
                         project::CACHE::describe_scope("fill_features", analysis_names),
                         feature_snapshot_payload(ctx_, analysis_names));
    return true;
  }

  bool PROJECT_NON_TARGET_ANALYSIS::blank_subtraction(const std::vector<std::string> &analyses,
                                                      float blank_threshold,
                                                      float rt_expand,
                                                      float mz_expand)
  {
    const auto selected_analyses = load_selected_analyses(ctx_, analyses);
    if (selected_analyses.empty())
    {
      return true;
    }
    const auto analysis_names = analysis_names_from_rows(selected_analyses);
    json cache_request = project::CACHE::make_request_payload("blank_subtraction", analysis_names);
    cache_request["blank_threshold"] = project::CACHE::stable_number(blank_threshold);
    cache_request["rt_expand"] = project::CACHE::stable_number(rt_expand);
    cache_request["mz_expand"] = project::CACHE::stable_number(mz_expand);
    cache_request["upstream_features"] = feature_snapshot_payload(ctx_, analysis_names)["features"];
    project::CACHE cache(ctx_);
    const auto hash = project::CACHE::hash_json(cache_request);
    if (cache.restore_json_if_present(hash, [&](const json &snapshot)
                                 { restore_feature_snapshot(ctx_, analysis_names, snapshot); }))
    {
      return true;
    }
    auto nts_data = load_nts_data_with_features(ctx_, selected_analyses, true);
    nts_data.subtract_blank(blank_threshold, rt_expand, mz_expand);
    replace_feature_rows(ctx_, analysis_names, nts_data.features);
    cache.put_json(
                         "ProjectNonTargetAnalysis::blank_subtraction",
                         hash,
                         project::CACHE::describe_scope("blank_subtraction", analysis_names),
                         feature_snapshot_payload(ctx_, analysis_names));
    return true;
  }

  bool PROJECT_NON_TARGET_ANALYSIS::filter_features(const std::vector<std::string> &analyses,
                                                    double min_sn,
                                                    double min_intensity,
                                                    double min_area,
                                                    double min_width,
                                                    double max_width,
                                                    double max_ppm,
                                                    double min_fwhm_rt,
                                                    double max_fwhm_rt,
                                                    double min_fwhm_mz,
                                                    double max_fwhm_mz,
                                                    double min_gaussian_a,
                                                    double min_gaussian_mu,
                                                    double max_gaussian_mu,
                                                    double min_gaussian_sigma,
                                                    double max_gaussian_sigma,
                                                    double min_gaussian_r2,
                                                    double max_jaggedness,
                                                    double min_sharpness,
                                                    double min_asymmetry,
                                                    double max_asymmetry,
                                                    int max_modality,
                                                    double min_plates,
                                                    bool has_only_filled,
                                                    bool only_filled_value,
                                                    bool remove_filled,
                                                    int min_size_eic,
                                                    bool has_min_size_eic,
                                                    int min_size_ms1,
                                                    bool has_min_size_ms1,
                                                    int min_size_ms2,
                                                    bool has_min_size_ms2,
                                                    double min_rel_presence_replicate,
                                                    bool remove_isotopes,
                                                    bool remove_adducts,
                                                    bool remove_losses)
  {
    const auto selected_analyses = load_selected_analyses(ctx_, analyses);
    if (selected_analyses.empty())
    {
      return true;
    }
    const auto analysis_names = analysis_names_from_rows(selected_analyses);
    json cache_request = project::CACHE::make_request_payload("filter_features", analysis_names);
    cache_request["min_sn"] = project::CACHE::stable_number(min_sn);
    cache_request["min_intensity"] = project::CACHE::stable_number(min_intensity);
    cache_request["min_area"] = project::CACHE::stable_number(min_area);
    cache_request["min_width"] = project::CACHE::stable_number(min_width);
    cache_request["max_width"] = project::CACHE::stable_number(max_width);
    cache_request["max_ppm"] = project::CACHE::stable_number(max_ppm);
    cache_request["min_fwhm_rt"] = project::CACHE::stable_number(min_fwhm_rt);
    cache_request["max_fwhm_rt"] = project::CACHE::stable_number(max_fwhm_rt);
    cache_request["min_fwhm_mz"] = project::CACHE::stable_number(min_fwhm_mz);
    cache_request["max_fwhm_mz"] = project::CACHE::stable_number(max_fwhm_mz);
    cache_request["min_gaussian_a"] = project::CACHE::stable_number(min_gaussian_a);
    cache_request["min_gaussian_mu"] = project::CACHE::stable_number(min_gaussian_mu);
    cache_request["max_gaussian_mu"] = project::CACHE::stable_number(max_gaussian_mu);
    cache_request["min_gaussian_sigma"] = project::CACHE::stable_number(min_gaussian_sigma);
    cache_request["max_gaussian_sigma"] = project::CACHE::stable_number(max_gaussian_sigma);
    cache_request["min_gaussian_r2"] = project::CACHE::stable_number(min_gaussian_r2);
    cache_request["max_jaggedness"] = project::CACHE::stable_number(max_jaggedness);
    cache_request["min_sharpness"] = project::CACHE::stable_number(min_sharpness);
    cache_request["min_asymmetry"] = project::CACHE::stable_number(min_asymmetry);
    cache_request["max_asymmetry"] = project::CACHE::stable_number(max_asymmetry);
    cache_request["max_modality"] = max_modality;
    cache_request["min_plates"] = project::CACHE::stable_number(min_plates);
    cache_request["has_only_filled"] = has_only_filled;
    cache_request["only_filled_value"] = only_filled_value;
    cache_request["remove_filled"] = remove_filled;
    cache_request["min_size_eic"] = min_size_eic;
    cache_request["has_min_size_eic"] = has_min_size_eic;
    cache_request["min_size_ms1"] = min_size_ms1;
    cache_request["has_min_size_ms1"] = has_min_size_ms1;
    cache_request["min_size_ms2"] = min_size_ms2;
    cache_request["has_min_size_ms2"] = has_min_size_ms2;
    cache_request["min_rel_presence_replicate"] = project::CACHE::stable_number(min_rel_presence_replicate);
    cache_request["remove_isotopes"] = remove_isotopes;
    cache_request["remove_adducts"] = remove_adducts;
    cache_request["remove_losses"] = remove_losses;
    cache_request["upstream_features"] = feature_snapshot_payload(ctx_, analysis_names)["features"];
    project::CACHE cache(ctx_);
    const auto hash = project::CACHE::hash_json(cache_request);
    if (cache.restore_json_if_present(hash, [&](const json &snapshot)
                                 { restore_feature_snapshot(ctx_, analysis_names, snapshot); }))
    {
      return true;
    }
    auto nts_data = load_nts_data_with_features(ctx_, selected_analyses, true);
    const bool has_max_modality = max_modality != std::numeric_limits<int>::min();
    nts_data.filter_features(min_sn,
                             min_intensity,
                             min_area,
                             min_width,
                             max_width,
                             max_ppm,
                             min_fwhm_rt,
                             max_fwhm_rt,
                             min_fwhm_mz,
                             max_fwhm_mz,
                             min_gaussian_a,
                             min_gaussian_mu,
                             max_gaussian_mu,
                             min_gaussian_sigma,
                             max_gaussian_sigma,
                             min_gaussian_r2,
                             max_jaggedness,
                             min_sharpness,
                             min_asymmetry,
                             max_asymmetry,
                             max_modality,
                             has_max_modality,
                             min_plates,
                             has_only_filled,
                             only_filled_value,
                             remove_filled,
                             min_size_eic,
                             has_min_size_eic,
                             min_size_ms1,
                             has_min_size_ms1,
                             min_size_ms2,
                             has_min_size_ms2,
                             min_rel_presence_replicate,
                             remove_isotopes,
                             remove_adducts,
                             remove_losses);
    replace_feature_rows(ctx_, analysis_names, nts_data.features);
    cache.put_json(
                         "ProjectNonTargetAnalysis::filter_features",
                         hash,
                         project::CACHE::describe_scope("filter_features", analysis_names),
                         feature_snapshot_payload(ctx_, analysis_names));
    return true;
  }

  bool PROJECT_NON_TARGET_ANALYSIS::suspect_screening(
      const std::vector<suspect_screening::SuspectQuery> &suspects,
      const std::vector<std::string> &analyses,
      double ppm,
      double sec,
      double ppm_ms2,
      double mzr_ms2,
      double min_cosine_similarity,
      int min_shared_fragments,
      bool filtered)
  {
    const auto selected_analyses = load_selected_analyses(ctx_, analyses);
    if (selected_analyses.empty())
    {
      return true;
    }
    const nts::NTS_INFO info = nts_info_from_analysis_rows(selected_analyses);
    json cache_request = project::CACHE::make_request_payload("suspect_screening", info.analyses);
    cache_request["ppm"] = project::CACHE::stable_number(ppm);
    cache_request["sec"] = project::CACHE::stable_number(sec);
    cache_request["ppm_ms2"] = project::CACHE::stable_number(ppm_ms2);
    cache_request["mzr_ms2"] = project::CACHE::stable_number(mzr_ms2);
    cache_request["min_cosine_similarity"] = project::CACHE::stable_number(min_cosine_similarity);
    cache_request["min_shared_fragments"] = min_shared_fragments;
    cache_request["filtered"] = filtered;
    json suspects_json = json::array();
    for (const auto &suspect : suspects)
    {
      suspects_json.push_back(json{{"name", suspect.name},
                                   {"has_mass", suspect.has_mass},
                                   {"mass", project::CACHE::stable_number(suspect.mass)},
                                   {"rt", project::CACHE::stable_number(suspect.rt)},
                                   {"formula", suspect.formula},
                                   {"SMILES", suspect.SMILES},
                                   {"InChI", suspect.InChI},
                                   {"InChIKey", suspect.InChIKey},
                                   {"score", project::CACHE::stable_number(suspect.score)},
                                   {"has_xLogP", suspect.has_xLogP},
                                   {"xLogP", project::CACHE::stable_number(suspect.xLogP)},
                                   {"database_id", suspect.database_id},
                                   {"fragments_mz_pos", project::CACHE::json_array(suspect.fragments_mz_pos)},
                                   {"fragments_intensity_pos", project::CACHE::json_array(suspect.fragments_intensity_pos)},
                                   {"fragments_mz_neg", project::CACHE::json_array(suspect.fragments_mz_neg)},
                                   {"fragments_intensity_neg", project::CACHE::json_array(suspect.fragments_intensity_neg)}});
    }
    cache_request["suspects_input"] = suspects_json;
    cache_request["upstream_features"] = feature_snapshot_payload(ctx_, info.analyses)["features"];
    project::CACHE cache(ctx_);
    const auto hash = project::CACHE::hash_json(cache_request);
    if (cache.restore_json_if_present(hash, [&](const json &snapshot)
                                 { restore_suspect_snapshot(ctx_, info.analyses, snapshot); }))
    {
      return true;
    }
    const auto headers = load_selected_headers(ctx_, selected_analyses);
    const auto feature_rows = get_features(info.analyses, true);
    const auto features = features_by_analysis_from_rows(feature_rows, info.analyses);
    std::vector<nts::SUSPECTS> suspects_cpp;
    std::vector<nts::INTERNAL_STANDARDS> internal_standards_cpp;
    nts::NTS_DATA nts_data(info, headers, features, suspects_cpp, internal_standards_cpp);
    nts_data.suspect_screening(info.analyses,
                               suspects,
                               ppm,
                               sec,
                               ppm_ms2,
                               mzr_ms2,
                               min_cosine_similarity,
                               min_shared_fragments,
                               filtered);
    const nts::SUSPECTS combined = flatten_suspects(nts_data.suspects);
    auto guard = connect_checked(ctx_);
    try
    {
      detail::run_sql(guard.get(), "BEGIN", "begin project NTS suspect_screening transaction");
      delete_rows_for_analyses(guard.get(), suspects_table_name(), ctx_->project_id, info.analyses);
      insert_suspects_rows(guard.get(), ctx_->project_id, combined);
      detail::run_sql(guard.get(), "COMMIT", "commit project NTS suspect_screening transaction");
    }
    catch (...)
    {
      try
      {
        detail::run_sql(guard.get(), "ROLLBACK", "rollback project NTS suspect_screening transaction");
      }
      catch (...)
      {
      }
      throw;
    }
    cache.put_json(
                         "ProjectNonTargetAnalysis::suspect_screening",
                         hash,
                         project::CACHE::describe_scope("suspect_screening", info.analyses),
                         suspect_snapshot_payload(ctx_, info.analyses));
    return true;
  }

  bool PROJECT_NON_TARGET_ANALYSIS::find_internal_standards(
      const std::vector<suspect_screening::SuspectQuery> &suspects,
      const std::vector<std::string> &analyses,
      double ppm,
      double sec,
      double ppm_ms2,
      double mzr_ms2,
      double min_cosine_similarity,
      int min_shared_fragments,
      bool filtered)
  {
    const auto selected_analyses = load_selected_analyses(ctx_, analyses);
    if (selected_analyses.empty())
    {
      return true;
    }
    const auto analysis_names = analysis_names_from_rows(selected_analyses);
    json cache_request = project::CACHE::make_request_payload("find_internal_standards", analysis_names);
    cache_request["ppm"] = project::CACHE::stable_number(ppm);
    cache_request["sec"] = project::CACHE::stable_number(sec);
    cache_request["ppm_ms2"] = project::CACHE::stable_number(ppm_ms2);
    cache_request["mzr_ms2"] = project::CACHE::stable_number(mzr_ms2);
    cache_request["min_cosine_similarity"] = project::CACHE::stable_number(min_cosine_similarity);
    cache_request["min_shared_fragments"] = min_shared_fragments;
    cache_request["filtered"] = filtered;
    json suspects_json = json::array();
    for (const auto &suspect : suspects)
    {
      suspects_json.push_back(json{{"name", suspect.name},
                                   {"has_mass", suspect.has_mass},
                                   {"mass", project::CACHE::stable_number(suspect.mass)},
                                   {"rt", project::CACHE::stable_number(suspect.rt)},
                                   {"formula", suspect.formula},
                                   {"SMILES", suspect.SMILES},
                                   {"InChI", suspect.InChI},
                                   {"InChIKey", suspect.InChIKey},
                                   {"score", project::CACHE::stable_number(suspect.score)},
                                   {"has_xLogP", suspect.has_xLogP},
                                   {"xLogP", project::CACHE::stable_number(suspect.xLogP)},
                                   {"database_id", suspect.database_id},
                                   {"fragments_mz_pos", project::CACHE::json_array(suspect.fragments_mz_pos)},
                                   {"fragments_intensity_pos", project::CACHE::json_array(suspect.fragments_intensity_pos)},
                                   {"fragments_mz_neg", project::CACHE::json_array(suspect.fragments_mz_neg)},
                                   {"fragments_intensity_neg", project::CACHE::json_array(suspect.fragments_intensity_neg)}});
    }
    cache_request["suspects_input"] = suspects_json;
    cache_request["upstream_features"] = feature_snapshot_payload(ctx_, analysis_names)["features"];
    project::CACHE cache(ctx_);
    const auto hash = project::CACHE::hash_json(cache_request);
    if (cache.restore_json_if_present(hash, [&](const json &snapshot)
                                 {
                                   restore_suspect_snapshot(ctx_, analysis_names, snapshot);
                                   restore_internal_standard_snapshot(ctx_, analysis_names, snapshot);
                                 }))
    {
      return true;
    }

    suspect_screening(suspects,
                      analysis_names,
                      ppm,
                      sec,
                      ppm_ms2,
                      mzr_ms2,
                      min_cosine_similarity,
                      min_shared_fragments,
                      filtered);
    const nts::SUSPECTS suspects_out = query_suspects_for_analyses(ctx_, analysis_names);
    const nts::INTERNAL_STANDARDS internal_standards = internal_standards_from_suspects(suspects_out);
    const auto analyses_to_replace = unique_analysis_names(suspects_out);
    auto guard = connect_checked(ctx_);
    try
    {
      detail::run_sql(guard.get(), "BEGIN", "begin project NTS find_internal_standards transaction");
      delete_rows_for_analyses(guard.get(), internal_standards_table_name(), ctx_->project_id, analyses_to_replace);
      insert_internal_standards_rows(guard.get(), ctx_->project_id, internal_standards);
      detail::run_sql(guard.get(), "COMMIT", "commit project NTS find_internal_standards transaction");
    }
    catch (...)
    {
      try
      {
        detail::run_sql(guard.get(), "ROLLBACK", "rollback project NTS find_internal_standards transaction");
      }
      catch (...)
      {
      }
      throw;
    }
    json snapshot = suspect_snapshot_payload(ctx_, analysis_names);
    snapshot.update(internal_standard_snapshot_payload(ctx_, analysis_names));
    cache.put_json(
                         "ProjectNonTargetAnalysis::find_internal_standards",
                         hash,
                         project::CACHE::describe_scope("find_internal_standards", analysis_names),
                         snapshot);
    return true;
  }

  bool PROJECT_NON_TARGET_ANALYSIS::filter_suspects(const std::vector<std::string> &analyses,
                                                    const std::vector<std::string> &names,
                                                    double min_score,
                                                    double max_error_rt,
                                                    double max_error_mass,
                                                    const std::vector<int> &id_levels,
                                                    int min_shared_fragments,
                                                    double min_cosine_similarity)
  {
    const auto selected_analyses = load_selected_analyses(ctx_, analyses);
    if (selected_analyses.empty())
    {
      return true;
    }
    const auto analysis_names = analysis_names_from_rows(selected_analyses);
    json cache_request = project::CACHE::make_request_payload("filter_suspects", analysis_names);
    cache_request["names"] = project::CACHE::json_array(names);
    cache_request["min_score"] = project::CACHE::stable_number(min_score);
    cache_request["max_error_rt"] = project::CACHE::stable_number(max_error_rt);
    cache_request["max_error_mass"] = project::CACHE::stable_number(max_error_mass);
    cache_request["id_levels"] = id_levels;
    cache_request["min_shared_fragments"] = min_shared_fragments;
    cache_request["min_cosine_similarity"] = project::CACHE::stable_number(min_cosine_similarity);
    cache_request["upstream_suspects"] = suspect_snapshot_payload(ctx_, analysis_names)["suspects"];
    project::CACHE cache(ctx_);
    const auto hash = project::CACHE::hash_json(cache_request);
    if (cache.restore_json_if_present(hash, [&](const json &snapshot)
                                 { restore_suspect_snapshot(ctx_, analysis_names, snapshot); }))
    {
      return true;
    }
    const nts::NTS_INFO info = nts_info_from_analysis_rows(selected_analyses);
    std::vector<mass_spec::MS_SPECTRA_HEADERS> headers_cpp;
    std::vector<nts::FEATURES> features_cpp;
    std::vector<nts::INTERNAL_STANDARDS> internal_standards_cpp;
    const auto suspects_cpp = suspects_by_analysis_from_flat(query_suspects_for_analyses(ctx_, analysis_names), analysis_names);
    nts::NTS_DATA nts_data(info, headers_cpp, features_cpp, suspects_cpp, internal_standards_cpp);
    nts_data.filter_suspects(names,
                             min_score,
                             max_error_rt,
                             max_error_mass,
                             id_levels,
                             min_shared_fragments,
                             min_cosine_similarity);
    const nts::SUSPECTS filtered_suspects = flatten_suspects(nts_data.suspects);
    auto guard = connect_checked(ctx_);
    try
    {
      detail::run_sql(guard.get(), "BEGIN", "begin project NTS filter_suspects transaction");
      delete_rows_for_analyses(guard.get(), suspects_table_name(), ctx_->project_id, analysis_names);
      insert_suspects_rows(guard.get(), ctx_->project_id, filtered_suspects);
      detail::run_sql(guard.get(), "COMMIT", "commit project NTS filter_suspects transaction");
    }
    catch (...)
    {
      try
      {
        detail::run_sql(guard.get(), "ROLLBACK", "rollback project NTS filter_suspects transaction");
      }
      catch (...)
      {
      }
      throw;
    }
    cache.put_json(
                         "ProjectNonTargetAnalysis::filter_suspects",
                         hash,
                         project::CACHE::describe_scope("filter_suspects", analysis_names),
                         suspect_snapshot_payload(ctx_, analysis_names));
    return true;
  }

  bool PROJECT_NON_TARGET_ANALYSIS::filter_internal_standards(const std::vector<std::string> &analyses,
                                                              const std::vector<std::string> &names,
                                                              double min_score,
                                                              double max_error_rt,
                                                              double max_error_mass,
                                                              const std::vector<int> &id_levels,
                                                              int min_shared_fragments,
                                                              double min_cosine_similarity)
  {
    const auto selected_analyses = load_selected_analyses(ctx_, analyses);
    if (selected_analyses.empty())
    {
      return true;
    }
    const auto analysis_names = analysis_names_from_rows(selected_analyses);
    json cache_request = project::CACHE::make_request_payload("filter_internal_standards", analysis_names);
    cache_request["names"] = project::CACHE::json_array(names);
    cache_request["min_score"] = project::CACHE::stable_number(min_score);
    cache_request["max_error_rt"] = project::CACHE::stable_number(max_error_rt);
    cache_request["max_error_mass"] = project::CACHE::stable_number(max_error_mass);
    cache_request["id_levels"] = id_levels;
    cache_request["min_shared_fragments"] = min_shared_fragments;
    cache_request["min_cosine_similarity"] = project::CACHE::stable_number(min_cosine_similarity);
    cache_request["upstream_internal_standards"] = internal_standard_snapshot_payload(ctx_, analysis_names)["internal_standards"];
    project::CACHE cache(ctx_);
    const auto hash = project::CACHE::hash_json(cache_request);
    if (cache.restore_json_if_present(hash, [&](const json &snapshot)
                                 { restore_internal_standard_snapshot(ctx_, analysis_names, snapshot); }))
    {
      return true;
    }
    const nts::NTS_INFO info = nts_info_from_analysis_rows(selected_analyses);
    std::vector<mass_spec::MS_SPECTRA_HEADERS> headers_cpp;
    std::vector<nts::FEATURES> features_cpp;
    std::vector<nts::SUSPECTS> suspects_cpp;
    const auto internal_standards_cpp = internal_standards_by_analysis_from_flat(
        query_internal_standards_for_analyses(ctx_, analysis_names), analysis_names);
    nts::NTS_DATA nts_data(info, headers_cpp, features_cpp, suspects_cpp, internal_standards_cpp);
    nts_data.filter_internal_standards(names,
                                       min_score,
                                       max_error_rt,
                                       max_error_mass,
                                       id_levels,
                                       min_shared_fragments,
                                       min_cosine_similarity);
    nts::INTERNAL_STANDARDS filtered_internal_standards;
    for (const auto &rows : nts_data.internal_standards)
    {
      for (std::size_t i = 0; i < rows.analysis.size(); ++i)
      {
        nts::INTERNAL_STANDARD row;
        row.analysis = rows.analysis[i];
        row.feature = rows.feature[i];
        row.candidate_rank = rows.candidate_rank[i];
        row.name = rows.name[i];
        row.polarity = rows.polarity[i];
        row.db_mass = rows.db_mass[i];
        row.exp_mass = rows.exp_mass[i];
        row.error_mass = rows.error_mass[i];
        row.db_rt = rows.db_rt[i];
        row.exp_rt = rows.exp_rt[i];
        row.error_rt = rows.error_rt[i];
        row.intensity = rows.intensity[i];
        row.area = rows.area[i];
        row.id_level = rows.id_level[i];
        row.score = rows.score[i];
        row.shared_fragments = rows.shared_fragments[i];
        row.cosine_similarity = rows.cosine_similarity[i];
        row.formula = rows.formula[i];
        row.SMILES = rows.SMILES[i];
        row.InChI = rows.InChI[i];
        row.InChIKey = rows.InChIKey[i];
        row.xLogP = rows.xLogP[i];
        row.database_id = rows.database_id[i];
        row.db_ms2_size = rows.db_ms2_size[i];
        row.db_ms2_mz = rows.db_ms2_mz[i];
        row.db_ms2_intensity = rows.db_ms2_intensity[i];
        row.db_ms2_formula = rows.db_ms2_formula[i];
        row.exp_ms2_size = rows.exp_ms2_size[i];
        row.exp_ms2_mz = rows.exp_ms2_mz[i];
        row.exp_ms2_intensity = rows.exp_ms2_intensity[i];
        filtered_internal_standards.append(row);
      }
    }
    auto guard = connect_checked(ctx_);
    try
    {
      detail::run_sql(guard.get(), "BEGIN", "begin project NTS filter_internal_standards transaction");
      delete_rows_for_analyses(guard.get(), internal_standards_table_name(), ctx_->project_id, analysis_names);
      insert_internal_standards_rows(guard.get(), ctx_->project_id, filtered_internal_standards);
      detail::run_sql(guard.get(), "COMMIT", "commit project NTS filter_internal_standards transaction");
    }
    catch (...)
    {
      try
      {
        detail::run_sql(guard.get(), "ROLLBACK", "rollback project NTS filter_internal_standards transaction");
      }
      catch (...)
      {
      }
      throw;
    }
    cache.put_json(
                         "ProjectNonTargetAnalysis::filter_internal_standards",
                         hash,
                         project::CACHE::describe_scope("filter_internal_standards", analysis_names),
                         internal_standard_snapshot_payload(ctx_, analysis_names));
    return true;
  }

  bool PROJECT_NON_TARGET_ANALYSIS::filter_features_ms2(const std::vector<std::string> &analyses,
                                                        int top,
                                                        double min_intensity,
                                                        double rel_min_intensity,
                                                        bool blank_clean,
                                                        double mz_clust,
                                                        double blank_presence_threshold,
                                                        double global_presence_threshold)
  {
    const auto selected_analyses = load_selected_analyses(ctx_, analyses);
    if (selected_analyses.empty())
    {
      return true;
    }
    const auto analysis_names = analysis_names_from_rows(selected_analyses);
    json cache_request = project::CACHE::make_request_payload("filter_features_ms2", analysis_names);
    cache_request["top"] = top;
    cache_request["min_intensity"] = project::CACHE::stable_number(min_intensity);
    cache_request["rel_min_intensity"] = project::CACHE::stable_number(rel_min_intensity);
    cache_request["blank_clean"] = blank_clean;
    cache_request["mz_clust"] = project::CACHE::stable_number(mz_clust);
    cache_request["blank_presence_threshold"] = project::CACHE::stable_number(blank_presence_threshold);
    cache_request["global_presence_threshold"] = project::CACHE::stable_number(global_presence_threshold);
    cache_request["upstream_features"] = feature_snapshot_payload(ctx_, analysis_names)["features"];
    project::CACHE cache(ctx_);
    const auto hash = project::CACHE::hash_json(cache_request);
    if (cache.restore_json_if_present(hash, [&](const json &snapshot)
                                 { restore_feature_snapshot(ctx_, analysis_names, snapshot); }))
    {
      return true;
    }
    auto nts_data = load_nts_data_with_features(ctx_, selected_analyses, true);
    nts::filter_features_ms2::filter_features_ms2_impl(
        nts_data,
        top,
        std::isnan(min_intensity) ? std::numeric_limits<float>::quiet_NaN() : static_cast<float>(min_intensity),
        std::isnan(rel_min_intensity) ? std::numeric_limits<float>::quiet_NaN() : static_cast<float>(rel_min_intensity),
        blank_clean,
        static_cast<float>(mz_clust),
        static_cast<float>(blank_presence_threshold),
        static_cast<float>(global_presence_threshold));
    replace_feature_rows(ctx_, analysis_names, nts_data.features);
    cache.put_json(
                         "ProjectNonTargetAnalysis::filter_features_ms2",
                         hash,
                         project::CACHE::describe_scope("filter_features_ms2", analysis_names),
                         feature_snapshot_payload(ctx_, analysis_names));
    return true;
  }

  bool PROJECT_NON_TARGET_ANALYSIS::metfrag_screening(
      const std::string &metfrag_path,
      const std::vector<std::string> &analyses,
      const std::string &database_type,
      const std::string &database_path,
      double ppm,
      double sec,
      double ppm_ms2,
      double mzr_ms2,
      int top_n,
      bool filtered,
      const std::string &java_path,
      const std::string &run_dir,
      bool debug,
      const std::vector<std::pair<std::string, std::string>> &extra_params)
  {
    const auto selected_analyses = load_selected_analyses(ctx_, analyses);
    if (selected_analyses.empty())
    {
      return true;
    }
    const auto analysis_names = analysis_names_from_rows(selected_analyses);
    json cache_request = project::CACHE::make_request_payload("metfrag_screening", analysis_names);
    cache_request["metfrag_path"] = metfrag_path;
    cache_request["database_type"] = database_type;
    cache_request["database_path"] = database_path;
    cache_request["ppm"] = project::CACHE::stable_number(ppm);
    cache_request["sec"] = project::CACHE::stable_number(sec);
    cache_request["ppm_ms2"] = project::CACHE::stable_number(ppm_ms2);
    cache_request["mzr_ms2"] = project::CACHE::stable_number(mzr_ms2);
    cache_request["top_n"] = top_n;
    cache_request["filtered"] = filtered;
    cache_request["java_path"] = java_path;
    cache_request["run_dir"] = run_dir;
    cache_request["debug"] = debug;
    json extra_json = json::array();
    for (const auto &entry : extra_params)
    {
      extra_json.push_back(json{{"key", entry.first}, {"value", entry.second}});
    }
    cache_request["extra_params"] = extra_json;
    cache_request["upstream_features"] = feature_snapshot_payload(ctx_, analysis_names)["features"];
    project::CACHE cache(ctx_);
    const auto hash = project::CACHE::hash_json(cache_request);
    if (cache.restore_json_if_present(hash, [&](const json &snapshot)
                                 { restore_suspect_snapshot(ctx_, analysis_names, snapshot); }))
    {
      return true;
    }
    auto nts_data = load_nts_data_with_features(ctx_, selected_analyses, true);
    nts::metfrag_runner::MetFragParams params;
    params.metfrag_path = metfrag_path;
    params.database_type = database_type;
    params.database_path = database_path;
    params.ppm = ppm;
    params.sec = sec;
    params.ppmMS2 = ppm_ms2;
    params.mzrMS2 = mzr_ms2;
    params.top_n = top_n;
    params.filtered = filtered;
    params.java_path = java_path;
    params.run_dir = run_dir;
    params.debug = debug;
    params.extra_params = extra_params;
    nts_data.metfrag_screening(analysis_names, params);
    const nts::SUSPECTS combined = flatten_suspects(nts_data.suspects);
    auto guard = connect_checked(ctx_);
    try
    {
      detail::run_sql(guard.get(), "BEGIN", "begin project NTS metfrag_screening transaction");
      delete_rows_for_analyses(guard.get(), suspects_table_name(), ctx_->project_id, analysis_names);
      insert_suspects_rows(guard.get(), ctx_->project_id, combined);
      detail::run_sql(guard.get(), "COMMIT", "commit project NTS metfrag_screening transaction");
    }
    catch (...)
    {
      try
      {
        detail::run_sql(guard.get(), "ROLLBACK", "rollback project NTS metfrag_screening transaction");
      }
      catch (...)
      {
      }
      throw;
    }
    cache.put_json(
                         "ProjectNonTargetAnalysis::metfrag_screening",
                         hash,
                         project::CACHE::describe_scope("metfrag_screening", analysis_names),
                         suspect_snapshot_payload(ctx_, analysis_names));
    return true;
  }

  bool PROJECT_NON_TARGET_ANALYSIS::assign_transformation_products(
      const std::vector<assign_transformation_products::TPInputRow> &transformation_products,
      const std::string &chromatographic_phase,
      double mzr_ms2)
  {
    json cache_request = project::CACHE::make_request_payload("assign_transformation_products", {});
    cache_request["chromatographic_phase"] = chromatographic_phase;
    cache_request["mzr_ms2"] = project::CACHE::stable_number(mzr_ms2);
    json tp_json = json::array();
    for (const auto &row : transformation_products)
    {
      tp_json.push_back(json{{"name", row.name},
                             {"formula", row.formula},
                             {"mass", project::CACHE::stable_number(row.mass)},
                             {"SMILES", row.SMILES},
                             {"InChI", row.InChI},
                             {"InChIKey", row.InChIKey},
                             {"xLogP", project::CACHE::stable_number(row.xLogP)},
                             {"transformation", row.transformation},
                             {"precursor_name", row.precursor_name},
                             {"precursor_formula", row.precursor_formula},
                             {"precursor_mass", project::CACHE::stable_number(row.precursor_mass)},
                             {"precursor_SMILES", row.precursor_SMILES},
                             {"precursor_InChI", row.precursor_InChI},
                             {"precursor_InChIKey", row.precursor_InChIKey},
                             {"precursor_xLogP", project::CACHE::stable_number(row.precursor_xLogP)},
                             {"main_precursor_name", row.main_precursor_name},
                             {"main_precursor_formula", row.main_precursor_formula},
                             {"main_precursor_mass", project::CACHE::stable_number(row.main_precursor_mass)},
                             {"main_precursor_SMILES", row.main_precursor_SMILES},
                             {"main_precursor_InChI", row.main_precursor_InChI},
                             {"main_precursor_InChIKey", row.main_precursor_InChIKey},
                             {"main_precursor_xLogP", project::CACHE::stable_number(row.main_precursor_xLogP)}});
    }
    cache_request["transformation_products_input"] = tp_json;
    cache_request["upstream_suspects"] = suspect_snapshot_payload(ctx_, analysis_names_from_rows(load_selected_analyses(ctx_, {})))["suspects"];
    project::CACHE cache(ctx_);
    const auto hash = project::CACHE::hash_json(cache_request);
    if (cache.restore_json_if_present(hash, [&](const json &snapshot)
                                 { restore_transformation_product_snapshot(ctx_, snapshot); }))
    {
      return true;
    }
    const auto flat_suspects = query_transformation_flat_suspects(ctx_);
    const auto result = assign_transformation_products::assign_transformation_products_impl(
        flat_suspects,
        transformation_products,
        chromatographic_phase,
        mzr_ms2);
    auto guard = connect_checked(ctx_);
    try
    {
      detail::run_sql(guard.get(), "BEGIN", "begin project NTS assign_transformation_products transaction");
      delete_transformation_products(guard.get(), ctx_->project_id);
      insert_transformation_products_rows(guard.get(), ctx_->project_id, result);
      detail::run_sql(guard.get(), "COMMIT", "commit project NTS assign_transformation_products transaction");
    }
    catch (...)
    {
      try
      {
        detail::run_sql(guard.get(), "ROLLBACK", "rollback project NTS assign_transformation_products transaction");
      }
      catch (...)
      {
      }
      throw;
    }
    cache.put_json(
                         "ProjectNonTargetAnalysis::assign_transformation_products",
                         hash,
                         project::CACHE::describe_scope("assign_transformation_products", {}),
                         transformation_product_snapshot_payload(ctx_));
    return true;
  }

  void PROJECT_NON_TARGET_ANALYSIS::create_schema(const std::shared_ptr<project::api::CONTEXT> &ctx)
  {
    auto guard = connect_checked(ctx);
    detail::run_sql(
        guard.get(),
        "CREATE TABLE IF NOT EXISTS NTS_FEATURES ("
        "project_id VARCHAR NOT NULL, "
        "analysis VARCHAR NOT NULL, "
        "feature VARCHAR NOT NULL, "
        "feature_component VARCHAR, "
        "feature_group VARCHAR, "
        "adduct VARCHAR, "
        "rt DOUBLE, "
        "mz DOUBLE, "
        "mass DOUBLE, "
        "intensity DOUBLE, "
        "noise DOUBLE, "
        "sn DOUBLE, "
        "area DOUBLE, "
        "rtmin DOUBLE, "
        "rtmax DOUBLE, "
        "width DOUBLE, "
        "mzmin DOUBLE, "
        "mzmax DOUBLE, "
        "ppm DOUBLE, "
        "fwhm_rt DOUBLE, "
        "fwhm_mz DOUBLE, "
        "gaussian_A DOUBLE, "
        "gaussian_mu DOUBLE, "
        "gaussian_sigma DOUBLE, "
        "gaussian_r2 DOUBLE, "
        "jaggedness DOUBLE, "
        "sharpness DOUBLE, "
        "asymmetry DOUBLE, "
        "modality INTEGER, "
        "plates DOUBLE, "
        "polarity INTEGER, "
        "filtered BOOLEAN, "
        "filter VARCHAR, "
        "filled BOOLEAN, "
        "correction DOUBLE, "
        "eic_size INTEGER, "
        "eic_rt VARCHAR, "
        "eic_mz VARCHAR, "
        "eic_intensity VARCHAR, "
        "eic_baseline VARCHAR, "
        "eic_smoothed VARCHAR, "
        "ms1_size INTEGER, "
        "ms1_mz VARCHAR, "
        "ms1_intensity VARCHAR, "
        "ms2_size INTEGER, "
        "ms2_mz VARCHAR, "
        "ms2_intensity VARCHAR, "
        "created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, "
        "PRIMARY KEY(project_id, analysis, feature)"
        ")",
        "create NTS_FEATURES table");
    detail::run_sql(
        guard.get(),
        "CREATE TABLE IF NOT EXISTS NTS_INTERNAL_STANDARDS ("
        "project_id VARCHAR NOT NULL, "
        "analysis VARCHAR NOT NULL, "
        "feature VARCHAR NOT NULL, "
        "candidate_rank INTEGER NOT NULL, "
        "name VARCHAR NOT NULL, "
        "polarity INTEGER, "
        "db_mass DOUBLE, "
        "exp_mass DOUBLE, "
        "error_mass DOUBLE, "
        "db_rt DOUBLE, "
        "exp_rt DOUBLE, "
        "error_rt DOUBLE, "
        "intensity DOUBLE, "
        "area DOUBLE, "
        "id_level INTEGER, "
        "score DOUBLE, "
        "shared_fragments INTEGER, "
        "cosine_similarity DOUBLE, "
        "formula VARCHAR, "
        "SMILES VARCHAR, "
        "InChI VARCHAR, "
        "InChIKey VARCHAR, "
        "xLogP DOUBLE, "
        "database_id VARCHAR, "
        "db_ms2_size INTEGER, "
        "db_ms2_mz VARCHAR, "
        "db_ms2_intensity VARCHAR, "
        "db_ms2_formula VARCHAR, "
        "exp_ms2_size INTEGER, "
        "exp_ms2_mz VARCHAR, "
        "exp_ms2_intensity VARCHAR, "
        "created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, "
        "PRIMARY KEY(project_id, analysis, feature, candidate_rank, name)"
        ")",
        "create NTS_INTERNAL_STANDARDS table");
    detail::run_sql(
        guard.get(),
        "CREATE TABLE IF NOT EXISTS NTS_SUSPECTS ("
        "project_id VARCHAR NOT NULL, "
        "analysis VARCHAR NOT NULL, "
        "feature VARCHAR NOT NULL, "
        "candidate_rank INTEGER NOT NULL, "
        "name VARCHAR NOT NULL, "
        "polarity INTEGER, "
        "db_mass DOUBLE, "
        "exp_mass DOUBLE, "
        "error_mass DOUBLE, "
        "db_rt DOUBLE, "
        "exp_rt DOUBLE, "
        "error_rt DOUBLE, "
        "intensity DOUBLE, "
        "area DOUBLE, "
        "id_level INTEGER, "
        "score DOUBLE, "
        "shared_fragments INTEGER, "
        "cosine_similarity DOUBLE, "
        "formula VARCHAR, "
        "SMILES VARCHAR, "
        "InChI VARCHAR, "
        "InChIKey VARCHAR, "
        "xLogP DOUBLE, "
        "database_id VARCHAR, "
        "db_ms2_size INTEGER, "
        "db_ms2_mz VARCHAR, "
        "db_ms2_intensity VARCHAR, "
        "db_ms2_formula VARCHAR, "
        "exp_ms2_size INTEGER, "
        "exp_ms2_mz VARCHAR, "
        "exp_ms2_intensity VARCHAR, "
        "created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, "
        "PRIMARY KEY(project_id, analysis, feature, candidate_rank, name)"
        ")",
        "create NTS_SUSPECTS table");
    detail::run_sql(
        guard.get(),
        "CREATE TABLE IF NOT EXISTS NTS_TRANSFORMATION_PRODUCTS ("
        "project_id VARCHAR NOT NULL, "
        "name VARCHAR, "
        "formula VARCHAR, "
        "mass DOUBLE, "
        "SMILES VARCHAR, "
        "InChI VARCHAR, "
        "InChIKey VARCHAR, "
        "xLogP DOUBLE, "
        "transformation VARCHAR, "
        "precursor_name VARCHAR, "
        "precursor_formula VARCHAR, "
        "precursor_mass DOUBLE, "
        "precursor_SMILES VARCHAR, "
        "precursor_InChI VARCHAR, "
        "precursor_InChIKey VARCHAR, "
        "precursor_xLogP DOUBLE, "
        "main_precursor_name VARCHAR, "
        "main_precursor_formula VARCHAR, "
        "main_precursor_mass DOUBLE, "
        "main_precursor_SMILES VARCHAR, "
        "main_precursor_InChI VARCHAR, "
        "main_precursor_InChIKey VARCHAR, "
        "main_precursor_xLogP DOUBLE, "
        "feature_group VARCHAR, "
        "precursor_feature_group VARCHAR, "
        "main_precursor_feature_group VARCHAR, "
        "cosine_similarity DOUBLE, "
        "main_precursor_cosine_similarity DOUBLE, "
        "rt_plausibility DOUBLE, "
        "main_precursor_rt_plausibility DOUBLE, "
        "created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP"
        ")",
        "create NTS_TRANSFORMATION_PRODUCTS table");
  }

  void PROJECT_NON_TARGET_ANALYSIS::validate_schema(const std::shared_ptr<project::api::CONTEXT> &ctx)
  {
    auto guard = connect_checked(ctx);
    detail::validate_columns_present(
        guard.get(),
        features_table_name(),
        {{"project_id", "VARCHAR", true},
         {"analysis", "VARCHAR", true},
         {"feature", "VARCHAR", true},
         {"feature_component", "VARCHAR", false},
         {"feature_group", "VARCHAR", false},
         {"adduct", "VARCHAR", false},
         {"rt", "DOUBLE", false},
         {"mz", "DOUBLE", false},
         {"mass", "DOUBLE", false},
         {"intensity", "DOUBLE", false},
         {"noise", "DOUBLE", false},
         {"sn", "DOUBLE", false},
         {"area", "DOUBLE", false},
         {"rtmin", "DOUBLE", false},
         {"rtmax", "DOUBLE", false},
         {"width", "DOUBLE", false},
         {"mzmin", "DOUBLE", false},
         {"mzmax", "DOUBLE", false},
         {"ppm", "DOUBLE", false},
         {"fwhm_rt", "DOUBLE", false},
         {"fwhm_mz", "DOUBLE", false},
         {"gaussian_A", "DOUBLE", false},
         {"gaussian_mu", "DOUBLE", false},
         {"gaussian_sigma", "DOUBLE", false},
         {"gaussian_r2", "DOUBLE", false},
         {"jaggedness", "DOUBLE", false},
         {"sharpness", "DOUBLE", false},
         {"asymmetry", "DOUBLE", false},
         {"modality", "INTEGER", false},
         {"plates", "DOUBLE", false},
         {"polarity", "INTEGER", false},
         {"filtered", "BOOLEAN", false},
         {"filter", "VARCHAR", false},
         {"filled", "BOOLEAN", false},
         {"correction", "DOUBLE", false},
         {"eic_size", "INTEGER", false},
         {"eic_rt", "VARCHAR", false},
         {"eic_mz", "VARCHAR", false},
         {"eic_intensity", "VARCHAR", false},
         {"eic_baseline", "VARCHAR", false},
         {"eic_smoothed", "VARCHAR", false},
         {"ms1_size", "INTEGER", false},
         {"ms1_mz", "VARCHAR", false},
         {"ms1_intensity", "VARCHAR", false},
         {"ms2_size", "INTEGER", false},
         {"ms2_mz", "VARCHAR", false},
         {"ms2_intensity", "VARCHAR", false},
         {"created_at", "TIMESTAMP", false}});
    detail::validate_columns_present(
        guard.get(),
        internal_standards_table_name(),
        {{"project_id", "VARCHAR", true},
         {"analysis", "VARCHAR", true},
         {"feature", "VARCHAR", true},
         {"candidate_rank", "INTEGER", true},
         {"name", "VARCHAR", true},
         {"polarity", "INTEGER", false},
         {"db_mass", "DOUBLE", false},
         {"exp_mass", "DOUBLE", false},
         {"error_mass", "DOUBLE", false},
         {"db_rt", "DOUBLE", false},
         {"exp_rt", "DOUBLE", false},
         {"error_rt", "DOUBLE", false},
         {"intensity", "DOUBLE", false},
         {"area", "DOUBLE", false},
         {"id_level", "INTEGER", false},
         {"score", "DOUBLE", false},
         {"shared_fragments", "INTEGER", false},
         {"cosine_similarity", "DOUBLE", false},
         {"formula", "VARCHAR", false},
         {"SMILES", "VARCHAR", false},
         {"InChI", "VARCHAR", false},
         {"InChIKey", "VARCHAR", false},
         {"xLogP", "DOUBLE", false},
         {"database_id", "VARCHAR", false},
         {"db_ms2_size", "INTEGER", false},
         {"db_ms2_mz", "VARCHAR", false},
         {"db_ms2_intensity", "VARCHAR", false},
         {"db_ms2_formula", "VARCHAR", false},
         {"exp_ms2_size", "INTEGER", false},
         {"exp_ms2_mz", "VARCHAR", false},
         {"exp_ms2_intensity", "VARCHAR", false},
         {"created_at", "TIMESTAMP", false}});
    detail::validate_columns_present(
        guard.get(),
        suspects_table_name(),
        {{"project_id", "VARCHAR", true},
         {"analysis", "VARCHAR", true},
         {"feature", "VARCHAR", true},
         {"candidate_rank", "INTEGER", true},
         {"name", "VARCHAR", true},
         {"polarity", "INTEGER", false},
         {"db_mass", "DOUBLE", false},
         {"exp_mass", "DOUBLE", false},
         {"error_mass", "DOUBLE", false},
         {"db_rt", "DOUBLE", false},
         {"exp_rt", "DOUBLE", false},
         {"error_rt", "DOUBLE", false},
         {"intensity", "DOUBLE", false},
         {"area", "DOUBLE", false},
         {"id_level", "INTEGER", false},
         {"score", "DOUBLE", false},
         {"shared_fragments", "INTEGER", false},
         {"cosine_similarity", "DOUBLE", false},
         {"formula", "VARCHAR", false},
         {"SMILES", "VARCHAR", false},
         {"InChI", "VARCHAR", false},
         {"InChIKey", "VARCHAR", false},
         {"xLogP", "DOUBLE", false},
         {"database_id", "VARCHAR", false},
         {"db_ms2_size", "INTEGER", false},
         {"db_ms2_mz", "VARCHAR", false},
         {"db_ms2_intensity", "VARCHAR", false},
         {"db_ms2_formula", "VARCHAR", false},
         {"exp_ms2_size", "INTEGER", false},
         {"exp_ms2_mz", "VARCHAR", false},
         {"exp_ms2_intensity", "VARCHAR", false},
         {"created_at", "TIMESTAMP", false}});
    detail::validate_columns_present(
        guard.get(),
        transformation_products_table_name(),
        {{"project_id", "VARCHAR", true},
         {"name", "VARCHAR", false},
         {"formula", "VARCHAR", false},
         {"mass", "DOUBLE", false},
         {"SMILES", "VARCHAR", false},
         {"InChI", "VARCHAR", false},
         {"InChIKey", "VARCHAR", false},
         {"xLogP", "DOUBLE", false},
         {"transformation", "VARCHAR", false},
         {"precursor_name", "VARCHAR", false},
         {"precursor_formula", "VARCHAR", false},
         {"precursor_mass", "DOUBLE", false},
         {"precursor_SMILES", "VARCHAR", false},
         {"precursor_InChI", "VARCHAR", false},
         {"precursor_InChIKey", "VARCHAR", false},
         {"precursor_xLogP", "DOUBLE", false},
         {"main_precursor_name", "VARCHAR", false},
         {"main_precursor_formula", "VARCHAR", false},
         {"main_precursor_mass", "DOUBLE", false},
         {"main_precursor_SMILES", "VARCHAR", false},
         {"main_precursor_InChI", "VARCHAR", false},
         {"main_precursor_InChIKey", "VARCHAR", false},
         {"main_precursor_xLogP", "DOUBLE", false},
         {"feature_group", "VARCHAR", false},
         {"precursor_feature_group", "VARCHAR", false},
         {"main_precursor_feature_group", "VARCHAR", false},
         {"cosine_similarity", "DOUBLE", false},
         {"main_precursor_cosine_similarity", "DOUBLE", false},
         {"rt_plausibility", "DOUBLE", false},
         {"main_precursor_rt_plausibility", "DOUBLE", false},
         {"created_at", "TIMESTAMP", false}});
  }

  std::vector<NTS_FEATURE_ROW> PROJECT_NON_TARGET_ANALYSIS::get_features(const std::vector<std::string> &analyses,
                                                                         bool include_filtered) const
  {
    auto guard = connect_checked(ctx_);
    std::vector<NTS_FEATURE_ROW> out;
    const auto selected_analyses = sanitize_analyses(analyses);
    std::string sql =
        "SELECT project_id, analysis, feature, feature_component, feature_group, adduct, rt, mz, mass, intensity, "
        "noise, sn, area, rtmin, rtmax, width, mzmin, mzmax, ppm, fwhm_rt, fwhm_mz, gaussian_A, gaussian_mu, "
        "gaussian_sigma, gaussian_r2, jaggedness, sharpness, asymmetry, modality, plates, polarity, filtered, "
        "filter, filled, correction, eic_size, eic_rt, eic_mz, eic_intensity, eic_baseline, eic_smoothed, "
        "ms1_size, ms1_mz, ms1_intensity, ms2_size, ms2_mz, ms2_intensity, created_at "
        "FROM NTS_FEATURES WHERE project_id = ?";
    if (!include_filtered)
    {
      sql += " AND filtered = FALSE";
    }
    if (!selected_analyses.empty())
    {
      sql += " AND analysis IN (";
      sql += placeholders(selected_analyses.size());
      sql += ")";
    }
    sql += " ORDER BY lower(analysis), analysis, mz, rt, feature";

    detail::run_prepared(guard.get(), sql, "query NTS feature rows", [&](duckdb_prepared_statement statement)
                         {
                         idx_t bind_index = 1;
                         duckdb_bind_varchar(statement, bind_index++, ctx_->project_id.c_str());
                         for (const auto& analysis : selected_analyses) {
                           duckdb_bind_varchar(statement, bind_index++, analysis.c_str());
                         } }, [&](duckdb_result &result)
                         { out = detail::rows_from_result(&result, [&](idx_t row)
                                                          { return feature_row_from_result(result, row); }); });
    return out;
  }

  std::vector<NTS_FEATURE_COUNT_ROW> PROJECT_NON_TARGET_ANALYSIS::get_features_count(const std::vector<std::string> &analyses,
                                                                                     bool include_filtered) const
  {
    auto guard = connect_checked(ctx_);
    std::vector<NTS_FEATURE_COUNT_ROW> out;
    const auto selected_analyses = sanitize_analyses(analyses);
    if (selected_analyses.empty())
    {
      return out;
    }

    std::string sql =
        "SELECT analysis, COUNT(*) AS total, "
        "SUM(CASE WHEN filtered THEN 1 ELSE 0 END) AS filtered_count, "
        "COUNT(DISTINCT CASE WHEN feature_group IS NOT NULL AND feature_group != '' THEN feature_group END) AS groups_count, "
        "COUNT(DISTINCT CASE WHEN feature_component IS NOT NULL AND feature_component != '' THEN feature_component END) AS components_count "
        "FROM NTS_FEATURES WHERE project_id = ? AND analysis IN (";
    sql += placeholders(selected_analyses.size());
    sql += ")";
    if (!include_filtered)
    {
      sql += " AND filtered = FALSE";
    }
    sql += " GROUP BY analysis ORDER BY lower(analysis), analysis";

    std::unordered_map<std::string, NTS_FEATURE_COUNT_ROW> rows_by_analysis;
    detail::run_prepared(guard.get(), sql, "query NTS feature counts", [&](duckdb_prepared_statement statement)
                         {
                         idx_t bind_index = 1;
                         duckdb_bind_varchar(statement, bind_index++, ctx_->project_id.c_str());
                         for (const auto& analysis : selected_analyses) {
                           duckdb_bind_varchar(statement, bind_index++, analysis.c_str());
                         } }, [&](duckdb_result &result)
                         {
                         const idx_t count = duckdb_row_count(&result);
                         for (idx_t row = 0; row < count; ++row) {
                           NTS_FEATURE_COUNT_ROW value;
                           value.analysis = detail::result_varchar(&result, 0, row);
                           value.total = duckdb_value_int64(&result, 1, row);
                           value.filtered = duckdb_value_int64(&result, 2, row);
                           value.groups = duckdb_value_int64(&result, 3, row);
                           value.components = duckdb_value_int64(&result, 4, row);
                           rows_by_analysis.emplace(value.analysis, value);
                         } });

    out.reserve(selected_analyses.size());
    for (const auto &analysis : selected_analyses)
    {
      const auto it = rows_by_analysis.find(analysis);
      if (it == rows_by_analysis.end())
      {
        out.push_back(NTS_FEATURE_COUNT_ROW{analysis, 0, 0, 0, 0});
      }
      else
      {
        out.push_back(it->second);
      }
    }
    return out;
  }

  std::vector<NTS_SUSPECT_ROW> PROJECT_NON_TARGET_ANALYSIS::get_suspects(
      const std::vector<std::string> &analyses,
      const std::vector<std::string> &features,
      const std::vector<std::string> &groups,
      const mass_spec::MS_TARGETS_INPUT &targets,
      double ppm,
      double sec,
      double millisec) const
  {
    auto guard = connect_checked(ctx_);
    std::vector<NTS_SUSPECT_ROW> out;
    const auto selected_analyses = sanitize_analyses(analyses);
    std::string sql =
        "SELECT project_id, analysis, feature, candidate_rank, name, polarity, db_mass, exp_mass, error_mass, db_rt, exp_rt, error_rt, "
        "intensity, area, id_level, score, shared_fragments, cosine_similarity, formula, SMILES, InChI, InChIKey, xLogP, database_id, "
        "db_ms2_size, db_ms2_mz, db_ms2_intensity, db_ms2_formula, exp_ms2_size, exp_ms2_mz, exp_ms2_intensity, created_at "
        "FROM NTS_SUSPECTS WHERE project_id = ?";
    if (!selected_analyses.empty())
    {
      sql += " AND analysis IN (";
      sql += placeholders(selected_analyses.size());
      sql += ")";
    }
    sql += " ORDER BY lower(analysis), analysis, feature, candidate_rank, name";

    detail::run_prepared(guard.get(), sql, "query NTS suspect rows", [&](duckdb_prepared_statement statement)
                         {
                         idx_t bind_index = 1;
                         duckdb_bind_varchar(statement, bind_index++, ctx_->project_id.c_str());
                         for (const auto& analysis : selected_analyses) {
                           duckdb_bind_varchar(statement, bind_index++, analysis.c_str());
                         } }, [&](duckdb_result &result)
                         { out = detail::rows_from_result(&result, [&](idx_t row)
                                                          { return suspect_row_from_result(result, row); }); });
    if (!features.empty())
    {
      std::unordered_set<std::string> allowed(features.begin(), features.end());
      std::vector<NTS_SUSPECT_ROW> filtered;
      filtered.reserve(out.size());
      for (const auto &row : out)
      {
        if (allowed.find(row.feature) != allowed.end())
        {
          filtered.push_back(row);
        }
      }
      out = std::move(filtered);
    }
    if (!groups.empty())
    {
      out = filter_rows_by_feature_group(out, groups, load_feature_groups_for_analyses(ctx_, selected_analyses));
    }
    if (has_target_request(targets))
    {
      const auto target_analyses = selected_analyses.empty() ? analysis_names_from_rows(load_selected_analyses(ctx_, {})) : selected_analyses;
      const auto polarities = collect_analysis_polarities(ctx_, target_analyses);
      const mass_spec::MS_TARGETS_REQUEST request{
          target_analyses,
          {},
          targets,
          {},
          {},
          {},
          {},
          ppm,
          sec,
          millisec,
          true,
          1.3,
          0.0f,
          0.0f};
      out = filter_rows_by_targets(out,
                                   mass_spec::build_targets_by_analysis(request, target_analyses, polarities),
                                   target_analyses);
    }
    return out;
  }

  std::vector<NTS_INTERNAL_STANDARD_ROW> PROJECT_NON_TARGET_ANALYSIS::get_internal_standards(
      const std::vector<std::string> &analyses,
      const std::vector<std::string> &features,
      const std::vector<std::string> &groups,
      const mass_spec::MS_TARGETS_INPUT &targets,
      double ppm,
      double sec,
      double millisec) const
  {
    auto guard = connect_checked(ctx_);
    std::vector<NTS_INTERNAL_STANDARD_ROW> out;
    const auto selected_analyses = sanitize_analyses(analyses);
    std::string sql =
        "SELECT project_id, analysis, feature, candidate_rank, name, polarity, db_mass, exp_mass, error_mass, db_rt, exp_rt, error_rt, "
        "intensity, area, id_level, score, shared_fragments, cosine_similarity, formula, SMILES, InChI, InChIKey, xLogP, database_id, "
        "db_ms2_size, db_ms2_mz, db_ms2_intensity, db_ms2_formula, exp_ms2_size, exp_ms2_mz, exp_ms2_intensity, created_at "
        "FROM NTS_INTERNAL_STANDARDS WHERE project_id = ?";
    if (!selected_analyses.empty())
    {
      sql += " AND analysis IN (";
      sql += placeholders(selected_analyses.size());
      sql += ")";
    }
    sql += " ORDER BY lower(analysis), analysis, feature, candidate_rank, name";

    detail::run_prepared(guard.get(), sql, "query NTS internal standard rows", [&](duckdb_prepared_statement statement)
                         {
                         idx_t bind_index = 1;
                         duckdb_bind_varchar(statement, bind_index++, ctx_->project_id.c_str());
                         for (const auto& analysis : selected_analyses) {
                           duckdb_bind_varchar(statement, bind_index++, analysis.c_str());
                         } }, [&](duckdb_result &result)
                         { out = detail::rows_from_result(&result, [&](idx_t row)
                                                          { return internal_standard_row_from_result(result, row); }); });
    if (!features.empty())
    {
      std::unordered_set<std::string> allowed(features.begin(), features.end());
      std::vector<NTS_INTERNAL_STANDARD_ROW> filtered;
      filtered.reserve(out.size());
      for (const auto &row : out)
      {
        if (allowed.find(row.feature) != allowed.end())
        {
          filtered.push_back(row);
        }
      }
      out = std::move(filtered);
    }
    if (!groups.empty())
    {
      out = filter_rows_by_feature_group(out, groups, load_feature_groups_for_analyses(ctx_, selected_analyses));
    }
    if (has_target_request(targets))
    {
      const auto target_analyses = selected_analyses.empty() ? analysis_names_from_rows(load_selected_analyses(ctx_, {})) : selected_analyses;
      const auto polarities = collect_analysis_polarities(ctx_, target_analyses);
      const mass_spec::MS_TARGETS_REQUEST request{
          target_analyses,
          {},
          targets,
          {},
          {},
          {},
          {},
          ppm,
          sec,
          millisec,
          true,
          1.3,
          0.0f,
          0.0f};
      out = filter_rows_by_targets(out,
                                   mass_spec::build_targets_by_analysis(request, target_analyses, polarities),
                                   target_analyses);
    }
    return out;
  }

  std::vector<NTS_TRANSFORMATION_PRODUCT_ROW> PROJECT_NON_TARGET_ANALYSIS::get_transformation_products() const
  {
    auto guard = connect_checked(ctx_);
    std::vector<NTS_TRANSFORMATION_PRODUCT_ROW> out;
    const std::string sql =
        "SELECT project_id, name, formula, mass, SMILES, InChI, InChIKey, xLogP, transformation, precursor_name, precursor_formula, precursor_mass, precursor_SMILES, precursor_InChI, precursor_InChIKey, precursor_xLogP, main_precursor_name, main_precursor_formula, main_precursor_mass, main_precursor_SMILES, main_precursor_InChI, main_precursor_InChIKey, main_precursor_xLogP, feature_group, precursor_feature_group, main_precursor_feature_group, cosine_similarity, main_precursor_cosine_similarity, rt_plausibility, main_precursor_rt_plausibility, created_at "
        "FROM NTS_TRANSFORMATION_PRODUCTS WHERE project_id = ? "
        "ORDER BY lower(name), name, lower(precursor_name), precursor_name, feature_group";
    detail::run_prepared(guard.get(), sql, "query NTS transformation product rows", [&](duckdb_prepared_statement statement)
                         { duckdb_bind_varchar(statement, 1, ctx_->project_id.c_str()); }, [&](duckdb_result &result)
                         { out = detail::rows_from_result(&result, [&](idx_t row)
                                                          { return transformation_product_row_from_result(result, row); }); });
    return out;
  }

} // namespace nts
