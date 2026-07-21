#include "processing.h"
#include "mass_spec.h"
#include "reader.h"

#include <algorithm>
#include <chrono>
#include <regex>
#include <set>
#include <stdexcept>
#include <string>
#include <vector>

namespace mass_spec
{
  namespace processing
  {

    namespace
    {

      void ensure_ms_chromatograms_table(duckdb_connection con)
      {
        project::db::run_sql(con, R"SQL(
          CREATE TABLE IF NOT EXISTS MS_CHROMATOGRAMS (
            project_id TEXT NOT NULL,
            analysis TEXT NOT NULL,
            chromatogram_id TEXT NOT NULL,
            rt DOUBLE NOT NULL,
            raw_intensity DOUBLE NOT NULL,
            baseline DOUBLE NOT NULL DEFAULT 0,
            intensity DOUBLE NOT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY(project_id, analysis, chromatogram_id, rt)
          )
        )SQL", "create MS_CHROMATOGRAMS table");
      }

      bool matches_any_regex(const std::string &value,
                             const std::vector<std::string> &patterns,
                             bool ignore_case)
      {
        auto flags = std::regex::ECMAScript;
        if (ignore_case)
        {
          flags |= std::regex::icase;
        }
        for (const auto &pattern : patterns)
        {
          try
          {
            std::regex re(pattern, flags);
            if (std::regex_search(value, re))
            {
              return true;
            }
          }
          catch (const std::regex_error &)
          {
            continue;
          }
        }
        return false;
      }

      std::vector<std::string> resolve_analyses(api::PROJECT_MASS_SPEC &base,
                                                const std::vector<std::string> &requested)
      {
        if (requested.empty())
        {
          return base.get_analysis_names();
        }
        const auto all = base.get_analysis_names();
        std::set<std::string> valid(all.begin(), all.end());
        std::vector<std::string> out;
        for (const auto &name : requested)
        {
          if (valid.count(name) > 0)
          {
            out.push_back(name);
          }
        }
        return out;
      }

      std::string current_timestamp()
      {
        auto now = std::chrono::system_clock::now();
        auto time_t_now = std::chrono::system_clock::to_time_t(now);
        std::tm tm_buf{};
#ifdef _WIN32
        localtime_s(&tm_buf, &time_t_now);
#else
        localtime_r(&time_t_now, &tm_buf);
#endif
        char buf[32];
        std::strftime(buf, sizeof(buf), "%Y-%m-%d %H:%M:%S", &tm_buf);
        return std::string(buf);
      }

      struct APPENDER_GUARD
      {
        explicit APPENDER_GUARD(duckdb_appender *appender) : appender_(appender) {}
        ~APPENDER_GUARD()
        {
          if (appender_ && *appender_)
          {
            duckdb_appender_destroy(appender_);
          }
        }
        duckdb_appender *appender_;
      };

      std::string appender_error_message(duckdb_appender appender)
      {
        const char *message = duckdb_appender_error(appender);
        return message ? std::string(message) : std::string("unknown DuckDB appender error");
      }

      void check_append_state(duckdb_state state, duckdb_appender appender, const char *context)
      {
        if (state != DuckDBSuccess)
        {
          throw project::error::ERROR(project::error::ERROR_CODE::DuckDB,
                                      std::string(context) + ": " + appender_error_message(appender));
        }
      }

    } // anonymous namespace

    bool load_chromatograms(
        api::PROJECT_MASS_SPEC_CHROMATOGRAMS &project,
        const LOAD_CHROMATOGRAMS_REQUEST &request)
    {
      auto &base = project.base();
      const auto &ctx = project.context();
      const auto analyses = resolve_analyses(base, request.analyses);

      if (analyses.empty())
      {
        throw std::runtime_error("No analyses available for loading chromatograms.");
      }

      const std::string project_id = ctx->project_id;
      const std::string timestamp = current_timestamp();

      struct ChromatogramData
      {
        std::string analysis;
        std::string chromatogram_id;
        std::vector<double> rt;
        std::vector<double> intensity;
      };

      std::vector<ChromatogramData> all_data;

      for (const auto &analysis : analyses)
      {
        const auto headers = base.get_chromatograms_headers({analysis});

        std::vector<int> matched_indices;
        std::vector<std::string> matched_ids;

        for (const auto &header : headers)
        {
          const bool matches = matches_any_regex(header.chromatogram_id, request.chromatogram_id_regex, request.ignore_case);
          const bool keep = request.invert ? !matches : matches;
          if (keep)
          {
            matched_indices.push_back(header.index);
            matched_ids.push_back(header.chromatogram_id);
          }
        }

        if (matched_indices.empty())
        {
          continue;
        }

        const auto traces = base.get_raw_chromatograms(analysis, matched_indices);

        for (std::size_t i = 0; i < matched_indices.size(); ++i)
        {
          if (i >= traces.size() || traces[i].size() < 2)
          {
            continue;
          }

          const auto &rt_data = traces[i][0];
          const auto &intensity_data = traces[i][1];
          const std::size_t n_points = std::min(rt_data.size(), intensity_data.size());

          if (n_points == 0)
          {
            continue;
          }

          ChromatogramData data;
          data.analysis = analysis;
          data.chromatogram_id = matched_ids[i];
          data.rt.reserve(n_points);
          data.intensity.reserve(n_points);

          for (std::size_t j = 0; j < n_points; ++j)
          {
            data.rt.push_back(static_cast<double>(rt_data[j]));
            data.intensity.push_back(static_cast<double>(intensity_data[j]));
          }

          all_data.push_back(std::move(data));
        }
      }

      if (all_data.empty())
      {
        return true;
      }

      project::db::CONNECTION_GUARD guard(ctx);
      ensure_ms_chromatograms_table(guard.get());

      for (const auto &data : all_data)
      {
        const std::string delete_sql = "DELETE FROM MS_CHROMATOGRAMS WHERE project_id = ? AND analysis = ? AND chromatogram_id = ?";
        project::db::run_prepared(guard.get(), delete_sql, "delete existing chromatogram rows",
                                  [&](duckdb_prepared_statement stmt)
                                  {
                                    duckdb_bind_varchar(stmt, 1, project_id.c_str());
                                    duckdb_bind_varchar(stmt, 2, data.analysis.c_str());
                                    duckdb_bind_varchar(stmt, 3, data.chromatogram_id.c_str());
                                  },
                                  [](duckdb_result &) {});

        duckdb_appender appender = nullptr;
        if (duckdb_appender_create(guard.get(), nullptr, "MS_CHROMATOGRAMS", &appender) == DuckDBError)
        {
          throw std::runtime_error("create MS_CHROMATOGRAMS appender failed");
        }
        APPENDER_GUARD appender_guard(&appender);

        for (std::size_t j = 0; j < data.rt.size(); ++j)
        {
          check_append_state(duckdb_appender_begin_row(appender), appender, "begin MS_CHROMATOGRAMS row");
          check_append_state(duckdb_append_varchar(appender, project_id.c_str()), appender, "append MS_CHROMATOGRAMS project_id");
          check_append_state(duckdb_append_varchar(appender, data.analysis.c_str()), appender, "append MS_CHROMATOGRAMS analysis");
          check_append_state(duckdb_append_varchar(appender, data.chromatogram_id.c_str()), appender, "append MS_CHROMATOGRAMS chromatogram_id");
          check_append_state(duckdb_append_double(appender, data.rt[j]), appender, "append MS_CHROMATOGRAMS rt");
          check_append_state(duckdb_append_double(appender, data.intensity[j]), appender, "append MS_CHROMATOGRAMS raw_intensity");
          check_append_state(duckdb_append_double(appender, 0.0), appender, "append MS_CHROMATOGRAMS baseline");
          check_append_state(duckdb_append_double(appender, data.intensity[j]), appender, "append MS_CHROMATOGRAMS intensity");
          check_append_state(duckdb_append_varchar(appender, timestamp.c_str()), appender, "append MS_CHROMATOGRAMS created_at");
          check_append_state(duckdb_appender_end_row(appender), appender, "end MS_CHROMATOGRAMS row");
        }

        check_append_state(duckdb_appender_close(appender), appender, "close MS_CHROMATOGRAMS appender");
      }

      return true;
    }

    bool filter_chromatograms_retention_time(
        api::PROJECT_MASS_SPEC_CHROMATOGRAMS &project,
        const FILTER_CHROMATOGRAMS_RT_REQUEST &request)
    {
      if (request.rtmin >= request.rtmax)
      {
        throw std::runtime_error("rtmin must be less than rtmax.");
      }

      const auto &ctx = project.context();
      const std::string project_id = ctx->project_id;

      project::db::CONNECTION_GUARD guard(ctx);
      ensure_ms_chromatograms_table(guard.get());

      std::vector<std::string> analyses = request.analyses;
      if (analyses.empty())
      {
        const std::string sql = "SELECT DISTINCT analysis FROM MS_CHROMATOGRAMS WHERE project_id = ?";
        project::db::run_prepared(guard.get(), sql, "query analyses from MS_CHROMATOGRAMS",
                                  [&](duckdb_prepared_statement stmt)
                                  {
                                    duckdb_bind_varchar(stmt, 1, project_id.c_str());
                                  },
                                  [&](duckdb_result &result)
                                  {
                                    const idx_t count = duckdb_row_count(&result);
                                    for (idx_t row = 0; row < count; ++row)
                                    {
                                      analyses.push_back(project::db::result_varchar(&result, 0, row));
                                    }
                                  });
      }

      if (analyses.empty())
      {
        throw std::runtime_error("No chromatogram rows found in MS_CHROMATOGRAMS.");
      }

      for (const auto &analysis : analyses)
      {
        const std::string select_sql =
            "SELECT chromatogram_id, rt, raw_intensity, baseline, intensity FROM MS_CHROMATOGRAMS "
            "WHERE project_id = ? AND analysis = ? AND rt >= ? AND rt <= ? "
            "ORDER BY chromatogram_id, rt";

        std::vector<MS_CHROMATOGRAM_ROW> filtered_rows;

        project::db::run_prepared(guard.get(), select_sql, "query filtered chromatogram rows",
                                  [&](duckdb_prepared_statement stmt)
                                  {
                                    duckdb_bind_varchar(stmt, 1, project_id.c_str());
                                    duckdb_bind_varchar(stmt, 2, analysis.c_str());
                                    duckdb_bind_double(stmt, 3, request.rtmin);
                                    duckdb_bind_double(stmt, 4, request.rtmax);
                                  },
                                  [&](duckdb_result &result)
                                  {
                                    const idx_t count = duckdb_row_count(&result);
                                    for (idx_t row = 0; row < count; ++row)
                                    {
                                      MS_CHROMATOGRAM_ROW r;
                                      r.project_id = project_id;
                                      r.analysis = analysis;
                                      r.chromatogram_id = project::db::result_varchar(&result, 0, row);
                                      r.rt = duckdb_value_double(&result, 1, row);
                                      r.raw_intensity = duckdb_value_double(&result, 2, row);
                                      r.baseline = duckdb_value_double(&result, 3, row);
                                      r.intensity = duckdb_value_double(&result, 4, row);
                                      filtered_rows.push_back(std::move(r));
                                    }
                                  });

        if (filtered_rows.empty())
        {
          continue;
        }

        std::set<std::string> affected_chromatogram_ids;
        for (const auto &r : filtered_rows)
        {
          affected_chromatogram_ids.insert(r.chromatogram_id);
        }

        for (const auto &chrom_id : affected_chromatogram_ids)
        {
          const std::string delete_sql = "DELETE FROM MS_CHROMATOGRAMS WHERE project_id = ? AND analysis = ? AND chromatogram_id = ?";
          project::db::run_prepared(guard.get(), delete_sql, "delete old chromatogram rows",
                                    [&](duckdb_prepared_statement stmt)
                                    {
                                      duckdb_bind_varchar(stmt, 1, project_id.c_str());
                                      duckdb_bind_varchar(stmt, 2, analysis.c_str());
                                      duckdb_bind_varchar(stmt, 3, chrom_id.c_str());
                                    },
                                    [](duckdb_result &) {});
        }

        duckdb_appender appender = nullptr;
        if (duckdb_appender_create(guard.get(), nullptr, "MS_CHROMATOGRAMS", &appender) == DuckDBError)
        {
          throw std::runtime_error("create MS_CHROMATOGRAMS appender failed");
        }
        APPENDER_GUARD appender_guard(&appender);

        for (const auto &r : filtered_rows)
        {
          check_append_state(duckdb_appender_begin_row(appender), appender, "begin MS_CHROMATOGRAMS row");
          check_append_state(duckdb_append_varchar(appender, r.project_id.c_str()), appender, "append MS_CHROMATOGRAMS project_id");
          check_append_state(duckdb_append_varchar(appender, r.analysis.c_str()), appender, "append MS_CHROMATOGRAMS analysis");
          check_append_state(duckdb_append_varchar(appender, r.chromatogram_id.c_str()), appender, "append MS_CHROMATOGRAMS chromatogram_id");
          check_append_state(duckdb_append_double(appender, r.rt), appender, "append MS_CHROMATOGRAMS rt");
          check_append_state(duckdb_append_double(appender, r.raw_intensity), appender, "append MS_CHROMATOGRAMS raw_intensity");
          check_append_state(duckdb_append_double(appender, r.baseline), appender, "append MS_CHROMATOGRAMS baseline");
          check_append_state(duckdb_append_double(appender, r.intensity), appender, "append MS_CHROMATOGRAMS intensity");
          check_append_state(duckdb_append_default(appender), appender, "append MS_CHROMATOGRAMS created_at default");
          check_append_state(duckdb_appender_end_row(appender), appender, "end MS_CHROMATOGRAMS row");
        }

        check_append_state(duckdb_appender_close(appender), appender, "close MS_CHROMATOGRAMS appender");
      }

      return true;
    }

    std::vector<MS_CHROMATOGRAM_ROW> get_chromatograms(
        api::PROJECT_MASS_SPEC_CHROMATOGRAMS &project,
        const std::vector<std::string> &analyses)
    {
      const auto &ctx = project.context();
      const std::string project_id = ctx->project_id;

      project::db::CONNECTION_GUARD guard(ctx);
      ensure_ms_chromatograms_table(guard.get());

      std::string sql = "SELECT project_id, analysis, chromatogram_id, rt, raw_intensity, baseline, intensity FROM MS_CHROMATOGRAMS WHERE project_id = ?";
      std::vector<std::string> resolved = analyses;
      if (resolved.empty())
      {
        sql += " ORDER BY analysis, chromatogram_id, rt";
      }
      else
      {
        sql += " AND analysis IN (";
        for (std::size_t i = 0; i < resolved.size(); ++i)
        {
          if (i > 0)
            sql += ", ";
          sql += "?";
        }
        sql += ") ORDER BY analysis, chromatogram_id, rt";
      }

      std::vector<MS_CHROMATOGRAM_ROW> out;

      project::db::run_prepared(guard.get(), sql, "query MS_CHROMATOGRAMS",
                                [&](duckdb_prepared_statement stmt)
                                {
                                  idx_t bind_idx = 1;
                                  duckdb_bind_varchar(stmt, bind_idx++, project_id.c_str());
                                  for (const auto &a : resolved)
                                  {
                                    duckdb_bind_varchar(stmt, bind_idx++, a.c_str());
                                  }
                                },
                                [&](duckdb_result &result)
                                {
                                  const idx_t count = duckdb_row_count(&result);
                                  for (idx_t row = 0; row < count; ++row)
                                  {
                                    MS_CHROMATOGRAM_ROW r;
                                    r.project_id = project::db::result_varchar(&result, 0, row);
                                    r.analysis = project::db::result_varchar(&result, 1, row);
                                    r.chromatogram_id = project::db::result_varchar(&result, 2, row);
                                    r.rt = duckdb_value_double(&result, 3, row);
                                    r.raw_intensity = duckdb_value_double(&result, 4, row);
                                    r.baseline = duckdb_value_double(&result, 5, row);
                                    r.intensity = duckdb_value_double(&result, 6, row);
                                    out.push_back(std::move(r));
                                  }
                                });

      return out;
    }

  } // namespace processing
} // namespace mass_spec
