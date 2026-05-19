#include "project_mass_spec.h"
#include "reader.h"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <filesystem>
#include <iomanip>
#include <numeric>
#include <set>
#include <sstream>
#include <utility>
#include <map>
#include <limits>
#include <vector>
#include <string>
#include <iostream>
#include <unordered_map>

namespace mass_spec
{

  namespace utils
  {
    /// Reflect index at boundaries (mirror-padding).
    int reflect_idx(int i, int n)
    {
      if (n <= 1)
        return 0;
      if (i < 0)
        return -i;
      if (i >= n)
        return 2 * n - i - 2;
      return i;
    }

    /// Trapezoidal area between two consecutive points (no baseline subtraction).
    double trap(double x0, double y0, double x1, double y1)
    {
      return 0.5 * (y0 + y1) * (x1 - x0);
    }
  }

  namespace spectra
  {

    namespace spectra_targets
    {

      constexpr double kProtonMass = 1.007276;

      std::string trim_copy(const std::string &value)
      {
        std::size_t start = 0;
        while (start < value.size() && std::isspace(static_cast<unsigned char>(value[start])) != 0)
        {
          ++start;
        }
        std::size_t end = value.size();
        while (end > start && std::isspace(static_cast<unsigned char>(value[end - 1])) != 0)
        {
          --end;
        }
        return value.substr(start, end - start);
      }

      double non_negative_or_zero(double value)
      {
        if (!std::isfinite(value) || value < 0.0)
        {
          return 0.0;
        }
        return value;
      }

      std::string normalize_polarity(const std::string &value)
      {
        const auto trimmed = trim_copy(value);
        if (trimmed == "positive")
          return "1";
        if (trimmed == "negative")
          return "-1";
        return trimmed;
      }

      bool is_empty_target_row(const MS_TARGETS &targets, std::size_t index)
      {
        const auto sum = targets.mz[index] + targets.rt[index] + targets.mobility[index] +
                         targets.mzmin[index] + targets.mzmax[index] +
                         targets.rtmin[index] + targets.rtmax[index] +
                         targets.mobilitymin[index] + targets.mobilitymax[index];
        return std::abs(sum) < 1e-12;
      }

      double value_or_zero(const std::vector<double> &values, std::size_t index)
      {
        if (index >= values.size())
          return 0.0;
        return non_negative_or_zero(values[index]);
      }

      std::string string_or_empty(const std::vector<std::string> &values, std::size_t index)
      {
        if (index >= values.size())
          return std::string();
        return trim_copy(values[index]);
      }

      std::string make_default_target_id(double mzmin,
                                         double mzmax,
                                         double rtmin,
                                         double rtmax,
                                         double mobilitymin,
                                         double mobilitymax)
      {
        std::ostringstream oss;
        oss.setf(std::ios::fixed);
        oss.precision(3);
        oss << mzmin << '-' << mzmax << '/';
        oss.precision(0);
        oss << rtmin << '-' << rtmax << '/' << mobilitymin << '-' << mobilitymax;
        return oss.str();
      }

      bool is_valid_polarity(const std::string &polarity)
      {
        return polarity.empty() || polarity == "1" || polarity == "-1" || polarity == "1|-1";
      }

      struct TargetSeed
      {
        std::string id;
        std::string analysis;
        std::string polarity;
        double mass = 0.0;
        double mass_min = 0.0;
        double mass_max = 0.0;
        double mz = 0.0;
        double mzmin = 0.0;
        double mzmax = 0.0;
        double rt = 0.0;
        double rtmin = 0.0;
        double rtmax = 0.0;
        double mobility = 0.0;
        double mobilitymin = 0.0;
        double mobilitymax = 0.0;
      };

      TargetSeed seed_from_table_row(const MS_TARGETS_INPUT &table, std::size_t index)
      {
        TargetSeed seed;
        seed.id = string_or_empty(table.id, index);
        seed.analysis = string_or_empty(table.analysis, index);
        seed.polarity = normalize_polarity(string_or_empty(table.polarity, index));
        seed.mass = value_or_zero(table.mass, index);
        seed.mass_min = value_or_zero(table.mass_min, index);
        seed.mass_max = value_or_zero(table.mass_max, index);
        seed.mz = value_or_zero(table.mz, index);
        seed.mzmin = value_or_zero(table.mzmin, index);
        seed.mzmax = value_or_zero(table.mzmax, index);
        seed.rt = value_or_zero(table.rt, index);
        seed.rtmin = value_or_zero(table.rtmin, index);
        seed.rtmax = value_or_zero(table.rtmax, index);
        seed.mobility = value_or_zero(table.mobility, index);
        seed.mobilitymin = value_or_zero(table.mobilitymin, index);
        seed.mobilitymax = value_or_zero(table.mobilitymax, index);
        return seed;
      }

      std::vector<TargetSeed> expand_seed_polarity(const TargetSeed &seed,
                                                   const std::vector<std::string> &polarities)
      {
        std::vector<TargetSeed> out;
        const auto polarity = normalize_polarity(seed.polarity);
        if (!is_valid_polarity(polarity))
        {
          return out;
        }

        if (polarity == "1|-1")
        {
          if (seed.mz > 0.0 || seed.mzmin > 0.0 || seed.mzmax > 0.0)
          {
            return out;
          }
          TargetSeed positive = seed;
          positive.polarity = "1";
          TargetSeed negative = seed;
          negative.polarity = "-1";
          out.push_back(positive);
          out.push_back(negative);
          return out;
        }

        if (!polarity.empty())
        {
          out.push_back(seed);
          return out;
        }

        if (polarities.empty())
        {
          TargetSeed positive = seed;
          positive.polarity = "1";
          TargetSeed negative = seed;
          negative.polarity = "-1";
          out.push_back(positive);
          out.push_back(negative);
          return out;
        }

        for (const auto &candidate : polarities)
        {
          TargetSeed expanded = seed;
          expanded.polarity = normalize_polarity(candidate);
          out.push_back(expanded);
        }
        return out;
      }

      std::vector<TargetSeed> expand_seed_analyses(const std::vector<TargetSeed> &seeds,
                                                   const std::vector<std::string> &analyses)
      {
        std::vector<TargetSeed> out;
        for (const auto &seed : seeds)
        {
          if (!seed.analysis.empty())
          {
            out.push_back(seed);
            continue;
          }
          if (analyses.empty())
          {
            out.push_back(seed);
            continue;
          }
          for (const auto &analysis : analyses)
          {
            TargetSeed expanded = seed;
            expanded.analysis = analysis;
            out.push_back(expanded);
          }
        }
        return out;
      }

      void finalize_seed_ranges(TargetSeed &seed, double ppm, double sec, double millisec)
      {
        if (seed.mass > 0.0 && seed.mz == 0.0 && seed.mzmin == 0.0 && seed.mzmax == 0.0)
        {
          const double sign = seed.polarity == "-1" ? -1.0 : 1.0;
          seed.mz = non_negative_or_zero(seed.mass + (kProtonMass * sign));
        }

        if (seed.mass_min > 0.0 && seed.mass_max > 0.0 && seed.mz == 0.0 && seed.mzmin == 0.0 && seed.mzmax == 0.0)
        {
          const double sign = seed.polarity == "-1" ? -1.0 : 1.0;
          seed.mzmin = non_negative_or_zero(seed.mass_min + (kProtonMass * sign));
          seed.mzmax = non_negative_or_zero(seed.mass_max + (kProtonMass * sign));
        }

        if (seed.mz > 0.0 && seed.mzmin == 0.0 && seed.mzmax == 0.0)
        {
          const double ppm_delta = (ppm / 1e6) * seed.mz;
          seed.mzmin = non_negative_or_zero(seed.mz - ppm_delta);
          seed.mzmax = non_negative_or_zero(seed.mz + ppm_delta);
        }
        if (seed.mz == 0.0 && (seed.mzmin > 0.0 || seed.mzmax > 0.0))
        {
          seed.mz = (seed.mzmin + seed.mzmax) / 2.0;
        }

        if (seed.rt > 0.0 && seed.rtmin == 0.0 && seed.rtmax == 0.0)
        {
          seed.rtmin = non_negative_or_zero(seed.rt - sec);
          seed.rtmax = non_negative_or_zero(seed.rt + sec);
        }
        if (seed.rt == 0.0 && (seed.rtmin > 0.0 || seed.rtmax > 0.0))
        {
          seed.rt = (seed.rtmin + seed.rtmax) / 2.0;
        }

        if (seed.mobility > 0.0 && seed.mobilitymin == 0.0 && seed.mobilitymax == 0.0)
        {
          seed.mobilitymin = non_negative_or_zero(seed.mobility - millisec);
          seed.mobilitymax = non_negative_or_zero(seed.mobility + millisec);
        }
        if (seed.mobility == 0.0 && (seed.mobilitymin > 0.0 || seed.mobilitymax > 0.0))
        {
          seed.mobility = (seed.mobilitymin + seed.mobilitymax) / 2.0;
        }

        seed.mz = non_negative_or_zero(seed.mz);
        seed.mzmin = non_negative_or_zero(seed.mzmin);
        seed.mzmax = non_negative_or_zero(seed.mzmax);
        seed.rt = non_negative_or_zero(seed.rt);
        seed.rtmin = non_negative_or_zero(seed.rtmin);
        seed.rtmax = non_negative_or_zero(seed.rtmax);
        seed.mobility = non_negative_or_zero(seed.mobility);
        seed.mobilitymin = non_negative_or_zero(seed.mobilitymin);
        seed.mobilitymax = non_negative_or_zero(seed.mobilitymax);

        if (seed.id.empty())
        {
          seed.id = make_default_target_id(seed.mzmin, seed.mzmax, seed.rtmin, seed.rtmax, seed.mobilitymin, seed.mobilitymax);
        }
      }

      std::vector<TargetSeed> build_target_seeds(const MS_TARGETS_INPUT &table,
                                                 const std::vector<std::string> &analyses,
                                                 const std::vector<std::string> &polarities,
                                                 const std::vector<std::string> &ids,
                                                 double ppm,
                                                 double sec,
                                                 double millisec)
      {
        std::vector<TargetSeed> seeds;
        seeds.reserve(table.size);
        for (std::size_t i = 0; i < table.size; ++i)
        {
          seeds.push_back(seed_from_table_row(table, i));
        }

        std::vector<TargetSeed> with_polarity;
        for (const auto &seed : seeds)
        {
          auto expanded = expand_seed_polarity(seed, polarities);
          with_polarity.insert(with_polarity.end(), expanded.begin(), expanded.end());
        }

        auto expanded = expand_seed_analyses(with_polarity, analyses);
        for (std::size_t i = 0; i < expanded.size(); ++i)
        {
          if (i < ids.size())
          {
            const auto override_id = trim_copy(ids[i]);
            if (!override_id.empty())
            {
              expanded[i].id = override_id;
            }
          }
          finalize_seed_ranges(expanded[i], ppm, sec, millisec);
        }
        return expanded;
      }

    } // namespace spectra_targets

    std::vector<std::string> sanitize_analyses(const std::vector<std::string> &analyses)
    {
      std::vector<std::string> out;
      out.reserve(analyses.size());
      for (const auto &analysis : analyses)
      {
        const auto trimmed = spectra_targets::trim_copy(analysis);
        if (!trimmed.empty())
        {
          out.push_back(trimmed);
        }
      }
      return out;
    }

    void append_unique_analyses(std::vector<std::string> &target,
                                std::set<std::string> &seen,
                                const std::vector<std::string> &analyses)
    {
      const auto sanitized = sanitize_analyses(analyses);
      for (const auto &analysis : sanitized)
      {
        if (seen.insert(analysis).second)
        {
          target.push_back(analysis);
        }
      }
    }

    std::vector<std::string> resolve_selected_analyses(const MS_TARGETS_REQUEST &request,
                                                       const std::vector<api::MS_ANALYSIS_ROW> &analyses_rows)
    {
      std::vector<std::string> selected;
      std::set<std::string> seen;

      // Row-wise target tables own their analysis mapping when provided.
      append_unique_analyses(selected, seen, request.mz.analysis);
      append_unique_analyses(selected, seen, request.mass.analysis);
      append_unique_analyses(selected, seen, request.rt.analysis);
      append_unique_analyses(selected, seen, request.mobility.analysis);

      if (!selected.empty())
      {
        return selected;
      }

      append_unique_analyses(selected, seen, request.analyses);
      if (!selected.empty())
      {
        return selected;
      }

      selected.reserve(analyses_rows.size());
      for (const auto &row : analyses_rows)
      {
        const auto analysis = spectra_targets::trim_copy(row.analysis);
        if (!analysis.empty() && seen.insert(analysis).second)
        {
          selected.push_back(analysis);
        }
      }
      return selected;
    }

    std::vector<MS_TARGETS> build_targets_by_analysis(const MS_TARGETS_REQUEST &request,
                                                      const std::vector<std::string> &analyses,
                                                      const std::vector<std::string> &polarities)
    {
      const auto selected_analyses = sanitize_analyses(analyses.empty() ? request.analyses : analyses);
      if (selected_analyses.empty())
      {
        return {};
      }

      const MS_TARGETS_INPUT *selected = nullptr;
      if (!request.mz.empty())
      {
        selected = &request.mz;
      }
      else if (!request.mass.empty())
      {
        selected = &request.mass;
      }
      else if (!request.rt.empty())
      {
        selected = &request.rt;
      }
      else if (!request.mobility.empty())
      {
        selected = &request.mobility;
      }

      if (selected == nullptr)
      {
        return {};
      }

      const auto seeds = spectra_targets::build_target_seeds(*selected,
                                                             selected_analyses,
                                                             polarities,
                                                             request.id,
                                                             request.ppm,
                                                             request.sec,
                                                             request.millisec);

      std::vector<MS_TARGETS> out;
      out.reserve(selected_analyses.size());
      for (const auto &analysis : selected_analyses)
      {
        std::vector<const spectra_targets::TargetSeed *> matching;
        for (const auto &seed : seeds)
        {
          if (seed.analysis == analysis)
          {
            matching.push_back(&seed);
          }
        }
        MS_TARGETS targets;
        targets.resize_all(static_cast<int>(matching.size()));
        for (std::size_t i = 0; i < matching.size(); ++i)
        {
          const auto &seed = *matching[i];
          targets.index[i] = static_cast<int>(i);
          targets.id[i] = seed.id;
          targets.level[i] = 0;
          targets.polarity[i] = seed.polarity == "-1" ? -1 : 1;
          targets.precursor[i] = false;
          targets.mz[i] = static_cast<float>(seed.mz);
          targets.mzmin[i] = static_cast<float>(seed.mzmin);
          targets.mzmax[i] = static_cast<float>(seed.mzmax);
          targets.rt[i] = static_cast<float>(seed.rt);
          targets.rtmin[i] = static_cast<float>(seed.rtmin);
          targets.rtmax[i] = static_cast<float>(seed.rtmax);
          targets.mobility[i] = static_cast<float>(seed.mobility);
          targets.mobilitymin[i] = static_cast<float>(seed.mobilitymin);
          targets.mobilitymax[i] = static_cast<float>(seed.mobilitymax);
        }
        out.push_back(std::move(targets));
      }
      return out;
    }

    bool has_effective_targets(const MS_TARGETS &targets)
    {
      if (targets.id.empty())
      {
        return false;
      }
      for (std::size_t i = 0; i < targets.id.size(); ++i)
      {
        if (!spectra_targets::is_empty_target_row(targets, i))
        {
          return true;
        }
      }
      return false;
    }

    MS_TARGETS subset_targets(const MS_TARGETS &targets,
                              const std::vector<int> &levels,
                              bool all_traces,
                              double isolation_window)
    {
      MS_TARGETS out;
      out.resize_all(static_cast<int>(targets.id.size()));
      for (std::size_t i = 0; i < targets.id.size(); ++i)
      {
        out.index[i] = static_cast<int>(i);
        out.id[i] = spectra_targets::trim_copy(targets.id[i]);
        out.level[i] = levels.empty() ? 0 : levels.front();
        out.polarity[i] = targets.polarity[i];
        out.precursor[i] = !all_traces;
        out.mz[i] = targets.mz[i];
        out.mzmin[i] = targets.mzmin[i];
        out.mzmax[i] = targets.mzmax[i];
        out.rt[i] = targets.rt[i];
        out.rtmin[i] = targets.rtmin[i];
        out.rtmax[i] = targets.rtmax[i];
        out.mobility[i] = targets.mobility[i];
        out.mobilitymin[i] = targets.mobilitymin[i];
        out.mobilitymax[i] = targets.mobilitymax[i];
        if (!all_traces)
        {
          out.mzmin[i] -= static_cast<float>(isolation_window / 2.0);
          out.mzmax[i] += static_cast<float>(isolation_window / 2.0);
        }
      }
      return out;
    }

    std::pair<float, float> target_mz_bounds(const MS_TARGETS &targets, std::size_t index)
    {
      const float mzmin = index < targets.mzmin.size() ? targets.mzmin[index] : 0.0f;
      const float mzmax = index < targets.mzmax.size() ? targets.mzmax[index] : 0.0f;
      const float mzcenter = index < targets.mz.size() ? targets.mz[index] : 0.0f;
      const float mmin = mzmin == 0.0f && mzmax == 0.0f ? mzcenter - 0.01f : mzmin;
      const float mmax = mzmin == 0.0f && mzmax == 0.0f ? mzcenter + 0.01f : mzmax;
      return {mmin, mmax};
    }

    bool header_matches_target(const api::MS_SPECTRA_HEADER_ROW &header,
                               const MS_TARGETS &targets,
                               std::size_t index)
    {
      const int level = index < targets.level.size() ? targets.level[index] : 0;
      const int polarity = index < targets.polarity.size() ? targets.polarity[index] : 0;
      const float rtmin = index < targets.rtmin.size() ? targets.rtmin[index] : 0.0f;
      const float rtmax = index < targets.rtmax.size() ? targets.rtmax[index] : 0.0f;
      const float mobilitymin = index < targets.mobilitymin.size() ? targets.mobilitymin[index] : 0.0f;
      const float mobilitymax = index < targets.mobilitymax.size() ? targets.mobilitymax[index] : 0.0f;
      const bool precursor = index < targets.precursor.size() ? targets.precursor[index] : false;

      if (level != 0 && header.level != level)
      {
        return false;
      }
      if (polarity != 0 && header.polarity != polarity)
      {
        return false;
      }
      if (rtmin != 0.0f && header.rt < rtmin)
      {
        return false;
      }
      if (rtmax != 0.0f && header.rt > rtmax)
      {
        return false;
      }
      if (mobilitymin != 0.0f && header.mobility < mobilitymin)
      {
        return false;
      }
      if (mobilitymax != 0.0f && header.mobility > mobilitymax)
      {
        return false;
      }

      if (precursor)
      {
        const auto [mmin, mmax] = target_mz_bounds(targets, index);
        if ((mmin != 0.0f || mmax != 0.0f) && (header.precursor_mz < mmin || header.precursor_mz > mmax))
        {
          return false;
        }
      }

      return true;
    }

    std::vector<MS_CHARGE_POINT> calculate_spectra_charges(
        const std::vector<MS_SPECTRUM_POINT> &pts,
        int polarity,
        double round_val,
        double rel_low_cut,
        double abs_low_cut,
        int top_charges)
    {
      if (pts.empty())
        return {};

      // Base-peak intensity
      double base_int = 0.0;
      for (auto &p : pts)
        base_int = std::max(base_int, p.intensity);
      double int_cut = std::max(abs_low_cut, rel_low_cut * base_int);

      // Cluster by round(mz / round_val) * round_val
      // Use a map to accumulate sum intensity per cluster
      std::map<double, std::pair<double, double>> cluster_map; // cluster_mz → (sum_int, sum_mzmz)
      std::map<double, int> cluster_cnt;
      for (auto &p : pts)
      {
        if (round_val <= 0)
          round_val = 1.0;
        double ckey = std::round(p.mz / round_val) * round_val;
        cluster_map[ckey].first += p.intensity;
        cluster_map[ckey].second += p.mz * p.intensity;
        cluster_cnt[ckey]++;
      }

      // Build cluster list: (cluster_mz, mean_mz_weighted, sum_intensity)
      struct Cluster
      {
        double c_mz;
        double w_mz;
        double sum_int;
      };
      std::vector<Cluster> clusters;
      clusters.reserve(cluster_map.size());
      for (auto &kv : cluster_map)
      {
        double sum_int = kv.second.first;
        if (sum_int < int_cut)
          continue;
        double w_mz = kv.second.second / sum_int;
        clusters.push_back({kv.first, w_mz, sum_int});
      }
      if (clusters.size() < 2)
        return {};

      // Sort by m/z ascending
      std::sort(clusters.begin(), clusters.end(), [](const Cluster &a, const Cluster &b)
                { return a.w_mz < b.w_mz; });

      const int nc = (int)clusters.size();

      // For each cluster i, compute z_left (from left neighbour) and z_right
      // z = mz_i / (mz_i - mz_{i-1}) for left  →  same denominator as charge spacing
      // z = -mz_i / (mz_{i+1} - mz_i) for right  (using proton mass approximately)
      // More precisely: expected spacing for charge z is ~1/z Da,
      //   so z ≈ 1 / |mz_i - mz_{i-1}|  (rounded to nearest integer)
      std::vector<int> z_arr(nc, 0);
      for (int i = 0; i < nc; ++i)
      {
        double z_left = 0.0, z_right = 0.0;
        if (i > 0)
        {
          double delta = clusters[i].w_mz - clusters[i - 1].w_mz;
          if (delta > 0.0)
            z_left = 1.0 / delta;
        }
        if (i < nc - 1)
        {
          double delta = clusters[i + 1].w_mz - clusters[i].w_mz;
          if (delta > 0.0)
            z_right = 1.0 / delta;
        }
        int zl = (z_left > 0.5) ? (int)std::round(z_left) : 0;
        int zr = (z_right > 0.5) ? (int)std::round(z_right) : 0;
        // Take the more reliable (larger coverage = higher-intensity neighbour)
        if (i == 0)
          z_arr[i] = zr;
        else if (i == nc - 1)
          z_arr[i] = zl;
        else
          z_arr[i] = (clusters[i - 1].sum_int >= clusters[i + 1].sum_int) ? zl : zr;
      }

      // Pick top_charges most-intense clusters as "anchor" candidates
      std::vector<int> by_int(nc);
      std::iota(by_int.begin(), by_int.end(), 0);
      std::sort(by_int.begin(), by_int.end(), [&](int a, int b)
                { return clusters[a].sum_int > clusters[b].sum_int; });

      int n_cand = std::min(top_charges, nc);

      // For each anchor, try to build a consistent charge series and score it.
      // We use the anchor's z as the reference charge.
      // "score" = number of consistent charges matching anchor_z ±1 within mass tolerance.
      std::vector<MS_CHARGE_POINT> best;
      int best_score = -1;

      for (int ci = 0; ci < n_cand; ++ci)
      {
        int anchor = by_int[ci];
        int z_ref = (z_arr[anchor] > 0) ? z_arr[anchor] : 1;

        std::vector<MS_CHARGE_POINT> rows;
        int score = 0;
        for (int k = 0; k < nc; ++k)
        {
          int zk = (z_arr[k] > 0) ? z_arr[k] : z_ref;
          if (zk < 1)
            zk = 1;
          double mass = (double)zk * (clusters[k].w_mz - 1.007276);
          if (polarity < 0)
            mass = (double)zk * (clusters[k].w_mz + 1.007276);
          if (std::abs(zk - z_ref) <= 1)
            ++score;
          rows.push_back({clusters[k].w_mz, clusters[k].sum_int,
                          clusters[k].c_mz, zk, mass, polarity});
        }
        if (score > best_score)
        {
          best_score = score;
          best = rows;
        }
      }

      return best;
    };

    std::vector<MS_MASS_POINT> cluster_masses(
        const std::vector<MS_MASS_POINT> &pts,
        double clust_val)
    {
      if (pts.empty())
        return {};

      // Sort by mass
      std::vector<MS_MASS_POINT> sorted = pts;
      std::sort(sorted.begin(), sorted.end(), [](const MS_MASS_POINT &a, const MS_MASS_POINT &b)
                { return a.mass < b.mass; });

      std::vector<MS_MASS_POINT> result;
      int i = 0;
      const int m = (int)sorted.size();

      while (i < m)
      {
        // Collect cluster: all points within clust_val of sorted[i].mass
        double start_mass = sorted[i].mass;
        double sum_int = 0.0;
        double sum_mass_w = 0.0;

        int j = i;
        while (j < m && sorted[j].mass - start_mass <= clust_val)
        {
          sum_int += sorted[j].intensity;
          sum_mass_w += sorted[j].mass * sorted[j].intensity;
          ++j;
        }
        double avg_mass = (sum_int > 0) ? sum_mass_w / sum_int : start_mass;
        result.push_back({avg_mass, sum_int});
        i = j;
      }

      return result;
    };

    std::vector<MS_MASS_POINT> deconvolute_spectrum(
        const std::vector<MS_SPECTRUM_POINT> &spectrum_pts,
        const std::vector<MS_CHARGE_POINT> &charges,
        double clust_val,
        double window)
    {
      if (spectrum_pts.empty() || charges.empty())
        return {};

      std::vector<MS_MASS_POINT> all_mass_pts;
      all_mass_pts.reserve(charges.size() * 10);

      for (auto &ch : charges)
      {
        if (ch.z < 1)
          continue;
        double mz_lo = ch.mz - window;
        double mz_hi = ch.mz + window;

        for (auto &sp : spectrum_pts)
        {
          if (sp.mz < mz_lo)
            continue;
          if (sp.mz > mz_hi)
            break;
          double mass = (double)ch.z * (sp.mz - 1.007276);
          if (ch.polarity < 0)
            mass = (double)ch.z * (sp.mz + 1.007276);
          all_mass_pts.push_back({mass, sp.intensity});
        }
      }

      if (all_mass_pts.empty())
        return {};
      return cluster_masses(all_mass_pts, clust_val);
    };
  }

  namespace chromatograms
  {

  }

  namespace api
  {

    project::db::CONNECTION_GUARD connect_checked(const std::shared_ptr<project::api::CONTEXT> &ctx)
    {
      if (!ctx || ctx->db_path.empty() || ctx->project_id.empty())
      {
        throw project::error::ERROR(project::error::ERROR_CODE::InvalidArgument, "Project context is not initialized");
      }
      return project::db::CONNECTION_GUARD(ctx);
    }

    std::string default_analysis_name(const std::string &file_path)
    {
      return std::filesystem::path(file_path).stem().string();
    }

    std::vector<int> unique_levels(const std::vector<MS_SPECTRA_HEADER_ROW> &headers)
    {
      std::set<int> levels;
      for (const auto &header : headers)
      {
        levels.insert(header.level);
      }
      return std::vector<int>(levels.begin(), levels.end());
    }

    std::string polarity_to_string(int polarity)
    {
      if (polarity > 0)
        return "1";
      if (polarity < 0)
        return "-1";
      return "";
    }

    std::vector<std::string> collect_unique_polarities(const std::vector<MS_SPECTRA_HEADER_ROW> &headers)
    {
      std::set<std::string> out;
      for (const auto &header : headers)
      {
        const auto polarity = polarity_to_string(header.polarity);
        if (!polarity.empty())
        {
          out.insert(polarity);
        }
      }
      return std::vector<std::string>(out.begin(), out.end());
    }

    std::vector<MS_RAW_SPECTRUM_ROW> flatten_target_spectra(const std::string &analysis,
                                                            const std::string &replicate,
                                                            const mass_spec::spectra::MS_TARGETS_SPECTRA &spectra)
    {
      std::vector<MS_RAW_SPECTRUM_ROW> out;
      out.reserve(spectra.size());
      for (std::size_t i = 0; i < spectra.size(); ++i)
      {
        MS_RAW_SPECTRUM_ROW row;
        row.analysis = analysis;
        row.replicate = replicate;
        row.id = spectra.id[i];
        row.polarity = spectra.polarity[i];
        row.level = spectra.level[i];
        row.pre_mz = spectra.pre_mz[i];
        row.pre_mzlow = spectra.pre_mzlow[i];
        row.pre_mzhigh = spectra.pre_mzhigh[i];
        row.pre_ce = spectra.pre_ce[i];
        row.rt = spectra.rt[i];
        row.mobility = spectra.mobility[i];
        row.mz = spectra.mz[i];
        row.intensity = spectra.intensity[i];
        out.push_back(row);
      }
      return out;
    }

    std::vector<MS_RAW_SPECTRUM_ROW> flatten_spectra(const std::string &analysis,
                                                     const std::string &replicate,
                                                     const std::vector<reader::MS_SPECTRUM> &spectra,
                                                     float min_intensity_ms1,
                                                     float min_intensity_ms2)
    {
      std::vector<MS_RAW_SPECTRUM_ROW> out;
      for (const auto &spectrum : spectra)
      {
        if (spectrum.binary_data.size() < 2)
        {
          continue;
        }
        const auto &mz = spectrum.binary_data[0];
        const auto &intensity = spectrum.binary_data[1];
        const std::size_t size = std::min(mz.size(), intensity.size());
        for (std::size_t i = 0; i < size; ++i)
        {
          const float current_intensity = intensity[i];
          if (spectrum.level == 1 && current_intensity < min_intensity_ms1)
            continue;
          if (spectrum.level >= 2 && current_intensity < min_intensity_ms2)
            continue;
          MS_RAW_SPECTRUM_ROW row;
          row.analysis = analysis;
          row.replicate = replicate;
          row.polarity = spectrum.polarity;
          row.level = spectrum.level;
          row.pre_mz = spectrum.precursor_mz;
          row.pre_mzlow = spectrum.window_mzlow;
          row.pre_mzhigh = spectrum.window_mzhigh;
          row.pre_ce = spectrum.activation_ce;
          row.rt = spectrum.rt;
          row.mobility = spectrum.mobility;
          row.mz = mz[i];
          row.intensity = current_intensity;
          out.push_back(row);
        }
      }
      return out;
    }

    bool contains_level(const std::vector<int> &levels, int level)
    {
      return std::find(levels.begin(), levels.end(), level) != levels.end();
    }

    bool has_rt_window(double rt_min, double rt_max)
    {
      return rt_max > 0.0 && rt_max >= rt_min;
    }

    std::string build_mass_spec_import_cache_key(const std::string &project_id,
                                                 const std::string &file_path,
                                                 const std::string &replicate,
                                                 const std::string &blank)
    {
      return std::string("mass_spec_import|") +
             project_id + "|" +
             project::utils::normalized_path(file_path).generic_string() + "|" +
             replicate + "|" +
             blank;
    }

    MS_ANALYSES_TABLE build_analysis_table(const std::string &project_id,
                                           const std::string &analysis_name,
                                           const std::string &replicate,
                                           const std::string &blank,
                                           const reader::MS_SUMMARY &summary)
    {
      MS_ANALYSES_TABLE out;
      out.project_id.push_back(project_id);
      out.analysis.push_back(analysis_name);
      out.replicate.push_back(replicate);
      out.blank.push_back(blank);
      out.file_name.push_back(summary.file_name);
      out.file_path.push_back(summary.file_path);
      out.file_dir.push_back(summary.file_dir);
      out.file_extension.push_back(summary.file_extension);
      out.format.push_back(summary.format);
      out.type.push_back(summary.type);
      out.time_stamp.push_back(summary.time_stamp);
      out.number_spectra.push_back(summary.number_spectra);
      out.number_chromatograms.push_back(summary.number_chromatograms);
      out.number_spectra_binary_arrays.push_back(summary.number_spectra_binary_arrays);
      out.min_mz.push_back(summary.min_mz);
      out.max_mz.push_back(summary.max_mz);
      out.start_rt.push_back(summary.start_rt);
      out.end_rt.push_back(summary.end_rt);
      out.has_ion_mobility.push_back(summary.has_ion_mobility);
      out.concentration.push_back(0.0);
      out.created_at.push_back(std::string());
      return out;
    }

    MS_SPECTRA_HEADERS_TABLE build_spectra_headers_table(const std::string &project_id,
                                                         const std::string &analysis_name,
                                                         const reader::MS_SPECTRA_HEADERS &headers)
    {
      MS_SPECTRA_HEADERS_TABLE out;
      const std::size_t count = headers.size();
      out.project_id.assign(count, project_id);
      out.analysis.assign(count, analysis_name);
      out.index.assign(headers.index.begin(), headers.index.end());
      out.scan.assign(headers.scan.begin(), headers.scan.end());
      out.array_length.assign(headers.array_length.begin(), headers.array_length.end());
      out.level.assign(headers.level.begin(), headers.level.end());
      out.mode.assign(headers.mode.begin(), headers.mode.end());
      out.polarity.assign(headers.polarity.begin(), headers.polarity.end());
      out.configuration.assign(headers.configuration.begin(), headers.configuration.end());
      out.lowmz.assign(headers.lowmz.begin(), headers.lowmz.end());
      out.highmz.assign(headers.highmz.begin(), headers.highmz.end());
      out.bpmz.assign(headers.bpmz.begin(), headers.bpmz.end());
      out.bpint.assign(headers.bpint.begin(), headers.bpint.end());
      out.tic.assign(headers.tic.begin(), headers.tic.end());
      out.rt.assign(headers.rt.begin(), headers.rt.end());
      out.mobility.assign(headers.mobility.begin(), headers.mobility.end());
      out.window_mz.assign(headers.window_mz.begin(), headers.window_mz.end());
      out.window_mzlow.assign(headers.window_mzlow.begin(), headers.window_mzlow.end());
      out.window_mzhigh.assign(headers.window_mzhigh.begin(), headers.window_mzhigh.end());
      out.precursor_mz.assign(headers.precursor_mz.begin(), headers.precursor_mz.end());
      out.precursor_intensity.assign(headers.precursor_intensity.begin(), headers.precursor_intensity.end());
      out.precursor_charge.assign(headers.precursor_charge.begin(), headers.precursor_charge.end());
      out.activation_ce.assign(headers.activation_ce.begin(), headers.activation_ce.end());
      return out;
    }

    MS_CHROMATOGRAMS_HEADERS_TABLE build_chromatograms_headers_table(const std::string &project_id,
                                                                     const std::string &analysis_name,
                                                                     const reader::MS_CHROMATOGRAMS_HEADERS &headers)
    {
      MS_CHROMATOGRAMS_HEADERS_TABLE out;
      const std::size_t count = headers.size();
      out.project_id.assign(count, project_id);
      out.analysis.assign(count, analysis_name);
      out.index.assign(headers.index.begin(), headers.index.end());
      out.id.assign(headers.id.begin(), headers.id.end());
      out.array_length.assign(headers.array_length.begin(), headers.array_length.end());
      out.polarity.assign(headers.polarity.begin(), headers.polarity.end());
      out.precursor_mz.assign(headers.precursor_mz.begin(), headers.precursor_mz.end());
      out.activation_ce.assign(headers.activation_ce.begin(), headers.activation_ce.end());
      out.product_mz.assign(headers.product_mz.begin(), headers.product_mz.end());
      return out;
    }

    void insert_analysis_table(duckdb_connection con, const MS_ANALYSES_TABLE &analyses)
    {
      for (std::size_t i = 0; i < analyses.analysis.size(); ++i)
      {
        project::db::run_prepared(con, "INSERT INTO MS_ANALYSES (project_id, analysis, replicate, blank, file_name, file_path, file_dir, file_extension, format, type, time_stamp, number_spectra, number_chromatograms, number_spectra_binary_arrays, min_mz, max_mz, start_rt, end_rt, has_ion_mobility, concentration) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", "insert MS analysis", [&](duckdb_prepared_statement statement)
                                  {
                           duckdb_bind_varchar(statement, 1, analyses.project_id[i].c_str());
                           duckdb_bind_varchar(statement, 2, analyses.analysis[i].c_str());
                           project::db::bind_optional_varchar(statement, 3, analyses.replicate[i]);
                           project::db::bind_optional_varchar(statement, 4, analyses.blank[i]);
                           project::db::bind_optional_varchar(statement, 5, analyses.file_name[i]);
                           duckdb_bind_varchar(statement, 6, analyses.file_path[i].c_str());
                           project::db::bind_optional_varchar(statement, 7, analyses.file_dir[i]);
                           project::db::bind_optional_varchar(statement, 8, analyses.file_extension[i]);
                           project::db::bind_optional_varchar(statement, 9, analyses.format[i]);
                           project::db::bind_optional_varchar(statement, 10, analyses.type[i]);
                           project::db::bind_optional_varchar(statement, 11, analyses.time_stamp[i]);
                           duckdb_bind_int32(statement, 12, analyses.number_spectra[i]);
                           duckdb_bind_int32(statement, 13, analyses.number_chromatograms[i]);
                           duckdb_bind_int32(statement, 14, analyses.number_spectra_binary_arrays[i]);
                           duckdb_bind_double(statement, 15, analyses.min_mz[i]);
                           duckdb_bind_double(statement, 16, analyses.max_mz[i]);
                           duckdb_bind_double(statement, 17, analyses.start_rt[i]);
                           duckdb_bind_double(statement, 18, analyses.end_rt[i]);
                           duckdb_bind_boolean(statement, 19, analyses.has_ion_mobility[i]);
                           duckdb_bind_double(statement, 20, analyses.concentration[i]); }, [](duckdb_result &) {});
      }
    }

    void insert_spectra_headers_table(duckdb_connection con, const MS_SPECTRA_HEADERS_TABLE &spectra_headers)
    {
      const std::size_t count = static_cast<std::size_t>(spectra_headers.size());
      for (std::size_t i = 0; i < count; ++i)
      {
        project::db::run_prepared(con, "INSERT INTO MS_SPECTRA_HEADERS (project_id, analysis, index, scan, array_length, level, mode, polarity, configuration, lowmz, highmz, bpmz, bpint, tic, rt, mobility, window_mz, window_mzlow, window_mzhigh, precursor_mz, precursor_intensity, precursor_charge, activation_ce) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", "insert MS spectrum header", [&](duckdb_prepared_statement statement)
                                  {
                           duckdb_bind_varchar(statement, 1, spectra_headers.project_id[i].c_str());
                           duckdb_bind_varchar(statement, 2, spectra_headers.analysis[i].c_str());
                           duckdb_bind_int32(statement, 3, spectra_headers.index[i]);
                           duckdb_bind_int32(statement, 4, spectra_headers.scan[i]);
                           duckdb_bind_int32(statement, 5, spectra_headers.array_length[i]);
                           duckdb_bind_int32(statement, 6, spectra_headers.level[i]);
                           duckdb_bind_int32(statement, 7, spectra_headers.mode[i]);
                           duckdb_bind_int32(statement, 8, spectra_headers.polarity[i]);
                           duckdb_bind_int32(statement, 9, spectra_headers.configuration[i]);
                           duckdb_bind_double(statement, 10, spectra_headers.lowmz[i]);
                           duckdb_bind_double(statement, 11, spectra_headers.highmz[i]);
                           duckdb_bind_double(statement, 12, spectra_headers.bpmz[i]);
                           duckdb_bind_double(statement, 13, spectra_headers.bpint[i]);
                           duckdb_bind_double(statement, 14, spectra_headers.tic[i]);
                           duckdb_bind_double(statement, 15, spectra_headers.rt[i]);
                           duckdb_bind_double(statement, 16, spectra_headers.mobility[i]);
                           duckdb_bind_double(statement, 17, spectra_headers.window_mz[i]);
                           duckdb_bind_double(statement, 18, spectra_headers.window_mzlow[i]);
                           duckdb_bind_double(statement, 19, spectra_headers.window_mzhigh[i]);
                           duckdb_bind_double(statement, 20, spectra_headers.precursor_mz[i]);
                           duckdb_bind_double(statement, 21, spectra_headers.precursor_intensity[i]);
                           duckdb_bind_int32(statement, 22, spectra_headers.precursor_charge[i]);
                           duckdb_bind_double(statement, 23, spectra_headers.activation_ce[i]); }, [](duckdb_result &) {});
      }
    }

    void insert_chromatograms_headers_table(duckdb_connection con, const MS_CHROMATOGRAMS_HEADERS_TABLE &chromatograms_headers)
    {
      const std::size_t count = static_cast<std::size_t>(chromatograms_headers.size());
      for (std::size_t i = 0; i < count; ++i)
      {
        project::db::run_prepared(con, "INSERT INTO MS_CHROMATOGRAMS_HEADERS (project_id, analysis, index, id, array_length, polarity, precursor_mz, activation_ce, product_mz) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)", "insert MS chromatogram header", [&](duckdb_prepared_statement statement)
                                  {
                           duckdb_bind_varchar(statement, 1, chromatograms_headers.project_id[i].c_str());
                           duckdb_bind_varchar(statement, 2, chromatograms_headers.analysis[i].c_str());
                           duckdb_bind_int32(statement, 3, chromatograms_headers.index[i]);
                           project::db::bind_optional_varchar(statement, 4, chromatograms_headers.id[i]);
                           duckdb_bind_int32(statement, 5, chromatograms_headers.array_length[i]);
                           duckdb_bind_int32(statement, 6, chromatograms_headers.polarity[i]);
                           duckdb_bind_double(statement, 7, chromatograms_headers.precursor_mz[i]);
                           duckdb_bind_double(statement, 8, chromatograms_headers.activation_ce[i]);
                           duckdb_bind_double(statement, 9, chromatograms_headers.product_mz[i]); }, [](duckdb_result &) {});
      }
    }

    MS_ANALYSIS_ROW analysis_row_from_result(duckdb_result &result, idx_t row)
    {
      MS_ANALYSIS_ROW value;
      value.project_id = project::db::result_varchar(&result, 0, row);
      value.analysis = project::db::result_varchar(&result, 1, row);
      value.replicate = project::db::result_varchar(&result, 2, row);
      value.blank = project::db::result_varchar(&result, 3, row);
      value.file_name = project::db::result_varchar(&result, 4, row);
      value.file_path = project::db::result_varchar(&result, 5, row);
      value.file_dir = project::db::result_varchar(&result, 6, row);
      value.file_extension = project::db::result_varchar(&result, 7, row);
      value.format = project::db::result_varchar(&result, 8, row);
      value.type = project::db::result_varchar(&result, 9, row);
      value.time_stamp = project::db::result_varchar(&result, 10, row);
      value.number_spectra = duckdb_value_int32(&result, 11, row);
      value.number_chromatograms = duckdb_value_int32(&result, 12, row);
      value.number_spectra_binary_arrays = duckdb_value_int32(&result, 13, row);
      value.min_mz = duckdb_value_double(&result, 14, row);
      value.max_mz = duckdb_value_double(&result, 15, row);
      value.start_rt = duckdb_value_double(&result, 16, row);
      value.end_rt = duckdb_value_double(&result, 17, row);
      value.has_ion_mobility = duckdb_value_boolean(&result, 18, row) != 0;
      value.concentration = duckdb_value_double(&result, 19, row);
      value.created_at = project::db::result_varchar(&result, 20, row);
      return value;
    }

    MS_SPECTRA_HEADER_ROW spectra_header_row_from_result(duckdb_result &result, idx_t row)
    {
      MS_SPECTRA_HEADER_ROW value;
      value.project_id = project::db::result_varchar(&result, 0, row);
      value.analysis = project::db::result_varchar(&result, 1, row);
      value.index = duckdb_value_int32(&result, 2, row);
      value.scan = duckdb_value_int32(&result, 3, row);
      value.array_length = duckdb_value_int32(&result, 4, row);
      value.level = duckdb_value_int32(&result, 5, row);
      value.mode = duckdb_value_int32(&result, 6, row);
      value.polarity = duckdb_value_int32(&result, 7, row);
      value.configuration = duckdb_value_int32(&result, 8, row);
      value.lowmz = duckdb_value_double(&result, 9, row);
      value.highmz = duckdb_value_double(&result, 10, row);
      value.bpmz = duckdb_value_double(&result, 11, row);
      value.bpint = duckdb_value_double(&result, 12, row);
      value.tic = duckdb_value_double(&result, 13, row);
      value.rt = duckdb_value_double(&result, 14, row);
      value.mobility = duckdb_value_double(&result, 15, row);
      value.window_mz = duckdb_value_double(&result, 16, row);
      value.window_mzlow = duckdb_value_double(&result, 17, row);
      value.window_mzhigh = duckdb_value_double(&result, 18, row);
      value.precursor_mz = duckdb_value_double(&result, 19, row);
      value.precursor_intensity = duckdb_value_double(&result, 20, row);
      value.precursor_charge = duckdb_value_int32(&result, 21, row);
      value.activation_ce = duckdb_value_double(&result, 22, row);
      return value;
    }

    MS_CHROMATOGRAM_HEADER_ROW chromatogram_header_row_from_result(duckdb_result &result, idx_t row)
    {
      MS_CHROMATOGRAM_HEADER_ROW value;
      value.project_id = project::db::result_varchar(&result, 0, row);
      value.analysis = project::db::result_varchar(&result, 1, row);
      value.index = duckdb_value_int32(&result, 2, row);
      value.id = project::db::result_varchar(&result, 3, row);
      value.array_length = duckdb_value_int32(&result, 4, row);
      value.polarity = duckdb_value_int32(&result, 5, row);
      value.precursor_mz = duckdb_value_double(&result, 6, row);
      value.activation_ce = duckdb_value_double(&result, 7, row);
      value.product_mz = duckdb_value_double(&result, 8, row);
      return value;
    }

    std::vector<std::uint8_t> MS_ANALYSES_TABLE::serialize_object() const
    {
      std::vector<std::uint8_t> out;
      project::cache::write_vector(out, project_id);
      project::cache::write_vector(out, analysis);
      project::cache::write_vector(out, replicate);
      project::cache::write_vector(out, blank);
      project::cache::write_vector(out, file_name);
      project::cache::write_vector(out, file_path);
      project::cache::write_vector(out, file_dir);
      project::cache::write_vector(out, file_extension);
      project::cache::write_vector(out, format);
      project::cache::write_vector(out, type);
      project::cache::write_vector(out, time_stamp);
      project::cache::write_vector(out, number_spectra);
      project::cache::write_vector(out, number_chromatograms);
      project::cache::write_vector(out, number_spectra_binary_arrays);
      project::cache::write_vector(out, min_mz);
      project::cache::write_vector(out, max_mz);
      project::cache::write_vector(out, start_rt);
      project::cache::write_vector(out, end_rt);
      project::cache::write_vector(out, has_ion_mobility);
      project::cache::write_vector(out, concentration);
      project::cache::write_vector(out, created_at);
      return out;
    }

    MS_ANALYSES_TABLE MS_ANALYSES_TABLE::deserialize_object(const std::vector<std::uint8_t> &bytes)
    {
      project::cache::BINARY_READER reader(bytes);
      MS_ANALYSES_TABLE value;
      project::cache::read_vector(reader, value.project_id);
      project::cache::read_vector(reader, value.analysis);
      project::cache::read_vector(reader, value.replicate);
      project::cache::read_vector(reader, value.blank);
      project::cache::read_vector(reader, value.file_name);
      project::cache::read_vector(reader, value.file_path);
      project::cache::read_vector(reader, value.file_dir);
      project::cache::read_vector(reader, value.file_extension);
      project::cache::read_vector(reader, value.format);
      project::cache::read_vector(reader, value.type);
      project::cache::read_vector(reader, value.time_stamp);
      project::cache::read_vector(reader, value.number_spectra);
      project::cache::read_vector(reader, value.number_chromatograms);
      project::cache::read_vector(reader, value.number_spectra_binary_arrays);
      project::cache::read_vector(reader, value.min_mz);
      project::cache::read_vector(reader, value.max_mz);
      project::cache::read_vector(reader, value.start_rt);
      project::cache::read_vector(reader, value.end_rt);
      project::cache::read_vector(reader, value.has_ion_mobility);
      project::cache::read_vector(reader, value.concentration);
      project::cache::read_vector(reader, value.created_at);
      if (!reader.empty())
      {
        throw project::error::ERROR(project::error::ERROR_CODE::SchemaMismatch, "deserialize MS_ANALYSES_TABLE: trailing bytes remain");
      }
      return value;
    }

    std::vector<std::uint8_t> MS_SPECTRA_HEADERS_TABLE::serialize_object() const
    {
      std::vector<std::uint8_t> out;
      project::cache::write_vector(out, project_id);
      project::cache::write_vector(out, analysis);
      project::cache::write_vector(out, index);
      project::cache::write_vector(out, scan);
      project::cache::write_vector(out, array_length);
      project::cache::write_vector(out, level);
      project::cache::write_vector(out, mode);
      project::cache::write_vector(out, polarity);
      project::cache::write_vector(out, configuration);
      project::cache::write_vector(out, lowmz);
      project::cache::write_vector(out, highmz);
      project::cache::write_vector(out, bpmz);
      project::cache::write_vector(out, bpint);
      project::cache::write_vector(out, tic);
      project::cache::write_vector(out, rt);
      project::cache::write_vector(out, mobility);
      project::cache::write_vector(out, window_mz);
      project::cache::write_vector(out, window_mzlow);
      project::cache::write_vector(out, window_mzhigh);
      project::cache::write_vector(out, precursor_mz);
      project::cache::write_vector(out, precursor_intensity);
      project::cache::write_vector(out, precursor_charge);
      project::cache::write_vector(out, activation_ce);
      return out;
    }

    MS_SPECTRA_HEADERS_TABLE MS_SPECTRA_HEADERS_TABLE::deserialize_object(const std::vector<std::uint8_t> &bytes)
    {
      project::cache::BINARY_READER reader(bytes);
      MS_SPECTRA_HEADERS_TABLE value;
      project::cache::read_vector(reader, value.project_id);
      project::cache::read_vector(reader, value.analysis);
      project::cache::read_vector(reader, value.index);
      project::cache::read_vector(reader, value.scan);
      project::cache::read_vector(reader, value.array_length);
      project::cache::read_vector(reader, value.level);
      project::cache::read_vector(reader, value.mode);
      project::cache::read_vector(reader, value.polarity);
      project::cache::read_vector(reader, value.configuration);
      project::cache::read_vector(reader, value.lowmz);
      project::cache::read_vector(reader, value.highmz);
      project::cache::read_vector(reader, value.bpmz);
      project::cache::read_vector(reader, value.bpint);
      project::cache::read_vector(reader, value.tic);
      project::cache::read_vector(reader, value.rt);
      project::cache::read_vector(reader, value.mobility);
      project::cache::read_vector(reader, value.window_mz);
      project::cache::read_vector(reader, value.window_mzlow);
      project::cache::read_vector(reader, value.window_mzhigh);
      project::cache::read_vector(reader, value.precursor_mz);
      project::cache::read_vector(reader, value.precursor_intensity);
      project::cache::read_vector(reader, value.precursor_charge);
      project::cache::read_vector(reader, value.activation_ce);
      if (!reader.empty())
      {
        throw project::error::ERROR(project::error::ERROR_CODE::SchemaMismatch, "deserialize MS_SPECTRA_HEADERS_TABLE: trailing bytes remain");
      }
      return value;
    }

    std::vector<std::uint8_t> MS_CHROMATOGRAMS_HEADERS_TABLE::serialize_object() const
    {
      std::vector<std::uint8_t> out;
      project::cache::write_vector(out, project_id);
      project::cache::write_vector(out, analysis);
      project::cache::write_vector(out, index);
      project::cache::write_vector(out, id);
      project::cache::write_vector(out, array_length);
      project::cache::write_vector(out, polarity);
      project::cache::write_vector(out, precursor_mz);
      project::cache::write_vector(out, activation_ce);
      project::cache::write_vector(out, product_mz);
      return out;
    }

    MS_CHROMATOGRAMS_HEADERS_TABLE MS_CHROMATOGRAMS_HEADERS_TABLE::deserialize_object(const std::vector<std::uint8_t> &bytes)
    {
      project::cache::BINARY_READER reader(bytes);
      MS_CHROMATOGRAMS_HEADERS_TABLE value;
      project::cache::read_vector(reader, value.project_id);
      project::cache::read_vector(reader, value.analysis);
      project::cache::read_vector(reader, value.index);
      project::cache::read_vector(reader, value.id);
      project::cache::read_vector(reader, value.array_length);
      project::cache::read_vector(reader, value.polarity);
      project::cache::read_vector(reader, value.precursor_mz);
      project::cache::read_vector(reader, value.activation_ce);
      project::cache::read_vector(reader, value.product_mz);
      if (!reader.empty())
      {
        throw project::error::ERROR(project::error::ERROR_CODE::SchemaMismatch, "deserialize MS_CHROMATOGRAMS_HEADERS_TABLE: trailing bytes remain");
      }
      return value;
    }

    PROJECT_MASS_SPEC::PROJECT_MASS_SPEC(std::shared_ptr<project::api::CONTEXT> ctx,
                                         const std::vector<std::string> &file_paths,
                                         const std::vector<std::string> &replicates,
                                         const std::vector<std::string> &blanks)
        : ctx_(std::move(ctx))
    {
      create_schema(ctx_);
      validate_schema(ctx_);
      if (!file_paths.empty())
      {
        import_files(file_paths, replicates, blanks);
      }
    }

    void PROJECT_MASS_SPEC::create_schema(const std::shared_ptr<project::api::CONTEXT> &ctx)
    {
      auto guard = connect_checked(ctx);
      project::db::run_sql(guard.get(),
                           "CREATE TABLE IF NOT EXISTS MS_ANALYSES (project_id VARCHAR NOT NULL, analysis VARCHAR NOT NULL, replicate VARCHAR, blank VARCHAR, file_name VARCHAR, file_path VARCHAR NOT NULL, file_dir VARCHAR, file_extension VARCHAR, format VARCHAR, type VARCHAR, time_stamp VARCHAR, number_spectra INTEGER, number_chromatograms INTEGER, number_spectra_binary_arrays INTEGER, min_mz DOUBLE, max_mz DOUBLE, start_rt DOUBLE, end_rt DOUBLE, has_ion_mobility BOOLEAN, concentration DOUBLE, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY(project_id, analysis))",
                           "create MS_ANALYSES table");
      project::db::run_sql(guard.get(),
                           "CREATE TABLE IF NOT EXISTS MS_SPECTRA_HEADERS (project_id VARCHAR NOT NULL, analysis VARCHAR NOT NULL, index INTEGER NOT NULL, scan INTEGER, array_length INTEGER, level INTEGER, mode INTEGER, polarity INTEGER, configuration INTEGER, lowmz DOUBLE, highmz DOUBLE, bpmz DOUBLE, bpint DOUBLE, tic DOUBLE, rt DOUBLE, mobility DOUBLE, window_mz DOUBLE, window_mzlow DOUBLE, window_mzhigh DOUBLE, precursor_mz DOUBLE, precursor_intensity DOUBLE, precursor_charge INTEGER, activation_ce DOUBLE, PRIMARY KEY(project_id, analysis, index))",
                           "create MS_SPECTRA_HEADERS table");
      project::db::run_sql(guard.get(),
                           "CREATE TABLE IF NOT EXISTS MS_CHROMATOGRAMS_HEADERS (project_id VARCHAR NOT NULL, analysis VARCHAR NOT NULL, index INTEGER NOT NULL, id VARCHAR, array_length INTEGER, polarity INTEGER, precursor_mz DOUBLE, activation_ce DOUBLE, product_mz DOUBLE, PRIMARY KEY(project_id, analysis, index))",
                           "create MS_CHROMATOGRAMS_HEADERS table");
    }

    void PROJECT_MASS_SPEC::validate_schema(const std::shared_ptr<project::api::CONTEXT> &ctx)
    {
      auto guard = connect_checked(ctx);
      project::db::validate_columns(guard.get(), analyses_table_name(), {{"project_id", "VARCHAR", true}, {"analysis", "VARCHAR", true}, {"replicate", "VARCHAR", false}, {"blank", "VARCHAR", false}, {"file_name", "VARCHAR", false}, {"file_path", "VARCHAR", true}, {"file_dir", "VARCHAR", false}, {"file_extension", "VARCHAR", false}, {"format", "VARCHAR", false}, {"type", "VARCHAR", false}, {"time_stamp", "VARCHAR", false}, {"number_spectra", "INTEGER", false}, {"number_chromatograms", "INTEGER", false}, {"number_spectra_binary_arrays", "INTEGER", false}, {"min_mz", "DOUBLE", false}, {"max_mz", "DOUBLE", false}, {"start_rt", "DOUBLE", false}, {"end_rt", "DOUBLE", false}, {"has_ion_mobility", "BOOLEAN", false}, {"concentration", "DOUBLE", false}, {"created_at", "TIMESTAMP", false}});
      project::db::validate_columns(guard.get(), spectra_headers_table_name(), {{"project_id", "VARCHAR", true}, {"analysis", "VARCHAR", true}, {"index", "INTEGER", true}, {"scan", "INTEGER", false}, {"array_length", "INTEGER", false}, {"level", "INTEGER", false}, {"mode", "INTEGER", false}, {"polarity", "INTEGER", false}, {"configuration", "INTEGER", false}, {"lowmz", "DOUBLE", false}, {"highmz", "DOUBLE", false}, {"bpmz", "DOUBLE", false}, {"bpint", "DOUBLE", false}, {"tic", "DOUBLE", false}, {"rt", "DOUBLE", false}, {"mobility", "DOUBLE", false}, {"window_mz", "DOUBLE", false}, {"window_mzlow", "DOUBLE", false}, {"window_mzhigh", "DOUBLE", false}, {"precursor_mz", "DOUBLE", false}, {"precursor_intensity", "DOUBLE", false}, {"precursor_charge", "INTEGER", false}, {"activation_ce", "DOUBLE", false}});
      project::db::validate_columns(guard.get(), chromatograms_headers_table_name(), {{"project_id", "VARCHAR", true}, {"analysis", "VARCHAR", true}, {"index", "INTEGER", true}, {"id", "VARCHAR", false}, {"array_length", "INTEGER", false}, {"polarity", "INTEGER", false}, {"precursor_mz", "DOUBLE", false}, {"activation_ce", "DOUBLE", false}, {"product_mz", "DOUBLE", false}});
    }

    void PROJECT_MASS_SPEC::import_files(const std::vector<std::string> &file_paths,
                                         const std::vector<std::string> &replicates,
                                         const std::vector<std::string> &blanks)
    {
      if (file_paths.empty())
      {
        return;
      }
      if (!replicates.empty() && replicates.size() != file_paths.size())
      {
        throw project::error::ERROR(project::error::ERROR_CODE::InvalidArgument, "Mass spec import_files replicates length must match file_paths");
      }
      if (!blanks.empty() && blanks.size() != file_paths.size())
      {
        throw project::error::ERROR(project::error::ERROR_CODE::InvalidArgument, "Mass spec import_files blanks length must match file_paths");
      }

      create_schema(ctx_);
      validate_schema(ctx_);

      auto guard = connect_checked(ctx_);
      project::db::run_sql(guard.get(), "BEGIN TRANSACTION", "begin MS import_files transaction");
      try
      {
        for (std::size_t i = 0; i < file_paths.size(); ++i)
        {
          import_file_with_connection(guard.get(),
                                      file_paths[i],
                                      replicates.empty() ? std::string() : replicates[i],
                                      blanks.empty() ? std::string() : blanks[i]);
        }
        project::db::run_sql(guard.get(), "COMMIT", "commit MS import_files transaction");
      }
      catch (...)
      {
        try
        {
          project::db::run_sql(guard.get(), "ROLLBACK", "rollback MS import_files transaction");
        }
        catch (...)
        {
        }
        throw;
      }
    }

    void PROJECT_MASS_SPEC::import_file_with_connection(duckdb_connection con,
                                                        const std::string &file_path,
                                                        const std::string &replicate,
                                                        const std::string &blank)
    {
      const auto import_started = std::chrono::steady_clock::now();
      if (file_path.empty())
      {
        throw project::error::ERROR(project::error::ERROR_CODE::InvalidArgument, "Mass spec import requires a file path");
      }
      const std::string analysis_name = default_analysis_name(file_path);
      if (analysis_name.empty())
      {
        throw project::error::ERROR(project::error::ERROR_CODE::InvalidArgument, "Mass spec import requires a non-empty analysis name");
      }

      const std::string cache_key_base = build_mass_spec_import_cache_key(ctx_->project_id, file_path, replicate, blank);
      const std::string analyses_cache_key = cache_key_base + "|analyses";
      const std::string spectra_cache_key = cache_key_base + "|spectra_headers";
      const std::string chromatograms_cache_key = cache_key_base + "|chromatograms_headers";
      project::cache::CACHE cache(ctx_);

      const auto cache_lookup_started = std::chrono::steady_clock::now();
      std::optional<MS_ANALYSES_TABLE> analyses_table = cache.get_object<MS_ANALYSES_TABLE>(con, analyses_cache_key);
      std::optional<MS_SPECTRA_HEADERS_TABLE> spectra_headers_table = cache.get_object<MS_SPECTRA_HEADERS_TABLE>(con, spectra_cache_key);
      std::optional<MS_CHROMATOGRAMS_HEADERS_TABLE> chromatograms_headers_table = cache.get_object<MS_CHROMATOGRAMS_HEADERS_TABLE>(con, chromatograms_cache_key);
      const auto cache_lookup_finished = std::chrono::steady_clock::now();
      const bool cache_hit = analyses_table && spectra_headers_table && chromatograms_headers_table;
      const auto format_elapsed_seconds = [](const std::chrono::steady_clock::time_point &start,
                                             const std::chrono::steady_clock::time_point &end)
      {
        std::ostringstream stream;
        stream << std::fixed << std::setprecision(2)
               << std::chrono::duration<double>(end - start).count();
        return stream.str();
      };
      const auto format_done_message = [&](const std::chrono::steady_clock::time_point &start,
                                           const std::chrono::steady_clock::time_point &end)
      {
        return std::string("Done! (") + format_elapsed_seconds(start, end) + " s)";
      };

      std::cout << "Importing file '" << file_path << "'." << std::endl;

      if (cache_hit)
      {
        std::cout << "  Loading cached data... "
                  << format_done_message(cache_lookup_started, cache_lookup_finished)
                  << std::endl;
      }
      else
      {
        const auto parse_started = std::chrono::steady_clock::now();
        reader::MS_FILE file(file_path);
        const reader::MS_SUMMARY summary = file.get_summary();
        const reader::MS_SPECTRA_HEADERS spectra_headers = file.get_spectra_headers();
        const reader::MS_CHROMATOGRAMS_HEADERS chromatograms_headers = file.get_chromatograms_headers();
        const auto parse_finished = std::chrono::steady_clock::now();
        std::cout << "  Reading headers... "
            << format_done_message(parse_started, parse_finished)
                  << std::endl;

        analyses_table = build_analysis_table(ctx_->project_id, analysis_name, replicate, blank, summary);
        spectra_headers_table = build_spectra_headers_table(ctx_->project_id, analysis_name, spectra_headers);
        chromatograms_headers_table = build_chromatograms_headers_table(ctx_->project_id, analysis_name, chromatograms_headers);

        const auto cache_write_started = std::chrono::steady_clock::now();
        cache.put_object(con, "MS_ANALYSES_TABLE", analyses_cache_key, "Cached mass spec analyses table import payload", *analyses_table);
        cache.put_object(con, "MS_SPECTRA_HEADERS_TABLE", spectra_cache_key, "Cached mass spec spectra headers import payload", *spectra_headers_table);
        cache.put_object(con, "MS_CHROMATOGRAMS_HEADERS_TABLE", chromatograms_cache_key, "Cached mass spec chromatograms headers import payload", *chromatograms_headers_table);
        const auto cache_write_finished = std::chrono::steady_clock::now();
        std::cout << "  Caching data... "
            << format_done_message(cache_write_started, cache_write_finished)
                  << std::endl;
      }

      const auto delete_started = std::chrono::steady_clock::now();
      project::db::run_prepared(con, "DELETE FROM MS_SPECTRA_HEADERS WHERE project_id = ? AND analysis = ?", "delete MS spectra headers", [&](duckdb_prepared_statement statement)
                                {
                         duckdb_bind_varchar(statement, 1, ctx_->project_id.c_str());
                         duckdb_bind_varchar(statement, 2, analysis_name.c_str()); }, [](duckdb_result &) {});
      project::db::run_prepared(con, "DELETE FROM MS_CHROMATOGRAMS_HEADERS WHERE project_id = ? AND analysis = ?", "delete MS chromatogram headers", [&](duckdb_prepared_statement statement)
                                {
                         duckdb_bind_varchar(statement, 1, ctx_->project_id.c_str());
                         duckdb_bind_varchar(statement, 2, analysis_name.c_str()); }, [](duckdb_result &) {});
      project::db::run_prepared(con, "DELETE FROM MS_ANALYSES WHERE project_id = ? AND analysis = ?", "delete MS analysis", [&](duckdb_prepared_statement statement)
                                {
                         duckdb_bind_varchar(statement, 1, ctx_->project_id.c_str());
                         duckdb_bind_varchar(statement, 2, analysis_name.c_str()); }, [](duckdb_result &) {});
      const auto delete_finished = std::chrono::steady_clock::now();
                  std::cout << "  Removing existing DuckDB rows... "
                    << format_done_message(delete_started, delete_finished)
            << std::endl;

      const auto load_started = std::chrono::steady_clock::now();
      insert_analysis_table(con, *analyses_table);
      insert_spectra_headers_table(con, *spectra_headers_table);
      insert_chromatograms_headers_table(con, *chromatograms_headers_table);
      const auto load_finished = std::chrono::steady_clock::now();
      std::cout << "  Saving data... "
                << format_done_message(load_started, load_finished)
                << std::endl;
      const auto import_finished = std::chrono::steady_clock::now();
      std::cout << "  Total import time: "
        << format_elapsed_seconds(import_started, import_finished) << " s"
            << std::endl;
    }

    void PROJECT_MASS_SPEC::remove_analysis(const std::string &analysis)
    {
      if (analysis.empty())
      {
        throw project::error::ERROR(project::error::ERROR_CODE::InvalidArgument, "Mass spec remove requires an analysis name");
      }

      auto guard = connect_checked(ctx_);
      project::db::run_prepared(guard.get(), "DELETE FROM MS_SPECTRA_HEADERS WHERE project_id = ? AND analysis = ?", "delete MS spectra headers", [&](duckdb_prepared_statement statement)
                                {
                         duckdb_bind_varchar(statement, 1, ctx_->project_id.c_str());
                         duckdb_bind_varchar(statement, 2, analysis.c_str()); }, [](duckdb_result &) {});
      project::db::run_prepared(guard.get(), "DELETE FROM MS_CHROMATOGRAMS_HEADERS WHERE project_id = ? AND analysis = ?", "delete MS chromatogram headers", [&](duckdb_prepared_statement statement)
                                {
                         duckdb_bind_varchar(statement, 1, ctx_->project_id.c_str());
                         duckdb_bind_varchar(statement, 2, analysis.c_str()); }, [](duckdb_result &) {});
      project::db::run_prepared(guard.get(), "DELETE FROM MS_ANALYSES WHERE project_id = ? AND analysis = ?", "delete MS analysis", [&](duckdb_prepared_statement statement)
                                {
                         duckdb_bind_varchar(statement, 1, ctx_->project_id.c_str());
                         duckdb_bind_varchar(statement, 2, analysis.c_str()); }, [](duckdb_result &) {});
    }

    std::vector<MS_ANALYSIS_ROW> PROJECT_MASS_SPEC::get_analyses() const
    {
      auto guard = connect_checked(ctx_);
      std::vector<MS_ANALYSIS_ROW> out;
      project::db::run_prepared(guard.get(), "SELECT project_id, analysis, replicate, blank, file_name, file_path, file_dir, file_extension, format, type, time_stamp, number_spectra, number_chromatograms, number_spectra_binary_arrays, min_mz, max_mz, start_rt, end_rt, has_ion_mobility, concentration, created_at FROM MS_ANALYSES WHERE project_id = ? ORDER BY lower(analysis), analysis", "query MS analyses", [&](duckdb_prepared_statement statement)
                                { duckdb_bind_varchar(statement, 1, ctx_->project_id.c_str()); }, [&](duckdb_result &result)
                                { out = project::db::rows_from_result(&result, [&](idx_t row)
                                                                      { return analysis_row_from_result(result, row); }); });
      return out;
    }

    std::vector<std::string> PROJECT_MASS_SPEC::get_analysis_names() const
    {
      const auto rows = get_analyses();
      std::vector<std::string> out;
      out.reserve(rows.size());
      for (const auto &row : rows)
      {
        out.push_back(row.analysis);
      }
      return out;
    }

    MS_ANALYSES_TABLE PROJECT_MASS_SPEC::collect_analyses() const
    {
      const auto rows = get_analyses();
      MS_ANALYSES_TABLE out;
      out.project_id.reserve(rows.size());
      out.analysis.reserve(rows.size());
      out.replicate.reserve(rows.size());
      out.blank.reserve(rows.size());
      out.file_name.reserve(rows.size());
      out.file_path.reserve(rows.size());
      out.file_dir.reserve(rows.size());
      out.file_extension.reserve(rows.size());
      out.format.reserve(rows.size());
      out.type.reserve(rows.size());
      out.time_stamp.reserve(rows.size());
      out.number_spectra.reserve(rows.size());
      out.number_chromatograms.reserve(rows.size());
      out.number_spectra_binary_arrays.reserve(rows.size());
      out.min_mz.reserve(rows.size());
      out.max_mz.reserve(rows.size());
      out.start_rt.reserve(rows.size());
      out.end_rt.reserve(rows.size());
      out.has_ion_mobility.reserve(rows.size());
      out.concentration.reserve(rows.size());
      out.created_at.reserve(rows.size());
      for (const auto &row : rows)
      {
        out.project_id.push_back(row.project_id);
        out.analysis.push_back(row.analysis);
        out.replicate.push_back(row.replicate);
        out.blank.push_back(row.blank);
        out.file_name.push_back(row.file_name);
        out.file_path.push_back(row.file_path);
        out.file_dir.push_back(row.file_dir);
        out.file_extension.push_back(row.file_extension);
        out.format.push_back(row.format);
        out.type.push_back(row.type);
        out.time_stamp.push_back(row.time_stamp);
        out.number_spectra.push_back(row.number_spectra);
        out.number_chromatograms.push_back(row.number_chromatograms);
        out.number_spectra_binary_arrays.push_back(row.number_spectra_binary_arrays);
        out.min_mz.push_back(row.min_mz);
        out.max_mz.push_back(row.max_mz);
        out.start_rt.push_back(row.start_rt);
        out.end_rt.push_back(row.end_rt);
        out.has_ion_mobility.push_back(row.has_ion_mobility);
        out.concentration.push_back(row.concentration);
        out.created_at.push_back(row.created_at);
      }
      return out;
    }

    std::vector<std::string> PROJECT_MASS_SPEC::get_replicate_names() const
    {
      const auto rows = get_analyses();
      std::vector<std::string> out;
      out.reserve(rows.size());
      for (const auto &row : rows)
      {
        out.push_back(row.replicate);
      }
      return out;
    }

    std::vector<std::string> PROJECT_MASS_SPEC::get_blank_names() const
    {
      const auto rows = get_analyses();
      std::vector<std::string> out;
      out.reserve(rows.size());
      for (const auto &row : rows)
      {
        out.push_back(row.blank);
      }
      return out;
    }

    std::vector<double> PROJECT_MASS_SPEC::get_concentrations() const
    {
      const auto rows = get_analyses();
      std::vector<double> out;
      out.reserve(rows.size());
      for (const auto &row : rows)
      {
        out.push_back(row.concentration);
      }
      return out;
    }

    void PROJECT_MASS_SPEC::set_replicate_names(const std::vector<std::string> &values)
    {
      const auto names = get_analysis_names();
      if (values.size() != names.size())
      {
        throw project::error::ERROR(project::error::ERROR_CODE::InvalidArgument, "Mass spec replicate names length must match analyses");
      }

      auto guard = connect_checked(ctx_);
      project::db::run_sql(guard.get(), "BEGIN TRANSACTION", "begin MS set replicate names transaction");
      try
      {
        for (std::size_t i = 0; i < names.size(); ++i)
        {
          project::db::run_prepared(guard.get(), "UPDATE MS_ANALYSES SET replicate = ? WHERE project_id = ? AND analysis = ?", "update MS replicate name", [&](duckdb_prepared_statement statement)
                                    {
                             project::db::bind_optional_varchar(statement, 1, values[i]);
                             duckdb_bind_varchar(statement, 2, ctx_->project_id.c_str());
                             duckdb_bind_varchar(statement, 3, names[i].c_str()); }, [](duckdb_result &) {});
        }
        project::db::run_sql(guard.get(), "COMMIT", "commit MS set replicate names transaction");
      }
      catch (...)
      {
        try
        {
          project::db::run_sql(guard.get(), "ROLLBACK", "rollback MS set replicate names transaction");
        }
        catch (...)
        {
        }
        throw;
      }
    }

    void PROJECT_MASS_SPEC::set_blank_names(const std::vector<std::string> &values)
    {
      const auto names = get_analysis_names();
      if (values.size() != names.size())
      {
        throw project::error::ERROR(project::error::ERROR_CODE::InvalidArgument, "Mass spec blank names length must match analyses");
      }

      auto guard = connect_checked(ctx_);
      project::db::run_sql(guard.get(), "BEGIN TRANSACTION", "begin MS set blank names transaction");
      try
      {
        for (std::size_t i = 0; i < names.size(); ++i)
        {
          project::db::run_prepared(guard.get(), "UPDATE MS_ANALYSES SET blank = ? WHERE project_id = ? AND analysis = ?", "update MS blank name", [&](duckdb_prepared_statement statement)
                                    {
                             project::db::bind_optional_varchar(statement, 1, values[i]);
                             duckdb_bind_varchar(statement, 2, ctx_->project_id.c_str());
                             duckdb_bind_varchar(statement, 3, names[i].c_str()); }, [](duckdb_result &) {});
        }
        project::db::run_sql(guard.get(), "COMMIT", "commit MS set blank names transaction");
      }
      catch (...)
      {
        try
        {
          project::db::run_sql(guard.get(), "ROLLBACK", "rollback MS set blank names transaction");
        }
        catch (...)
        {
        }
        throw;
      }
    }

    void PROJECT_MASS_SPEC::set_concentrations(const std::vector<double> &values)
    {
      const auto names = get_analysis_names();
      if (values.size() != names.size())
      {
        throw project::error::ERROR(project::error::ERROR_CODE::InvalidArgument, "Mass spec concentrations length must match analyses");
      }

      auto guard = connect_checked(ctx_);
      project::db::run_sql(guard.get(), "BEGIN TRANSACTION", "begin MS set concentrations transaction");
      try
      {
        for (std::size_t i = 0; i < names.size(); ++i)
        {
          project::db::run_prepared(guard.get(), "UPDATE MS_ANALYSES SET concentration = ? WHERE project_id = ? AND analysis = ?", "update MS concentration", [&](duckdb_prepared_statement statement)
                                    {
                             duckdb_bind_double(statement, 1, values[i]);
                             duckdb_bind_varchar(statement, 2, ctx_->project_id.c_str());
                             duckdb_bind_varchar(statement, 3, names[i].c_str()); }, [](duckdb_result &) {});
        }
        project::db::run_sql(guard.get(), "COMMIT", "commit MS set concentrations transaction");
      }
      catch (...)
      {
        try
        {
          project::db::run_sql(guard.get(), "ROLLBACK", "rollback MS set concentrations transaction");
        }
        catch (...)
        {
        }
        throw;
      }
    }

    std::vector<MS_SPECTRA_HEADER_ROW> PROJECT_MASS_SPEC::get_spectra_headers(const std::vector<std::string> &analyses) const
    {
      auto guard = connect_checked(ctx_);
      std::vector<MS_SPECTRA_HEADER_ROW> out;
      const auto selected_analyses = spectra::sanitize_analyses(analyses);
      std::string sql = "SELECT project_id, analysis, index, scan, array_length, level, mode, polarity, configuration, lowmz, highmz, bpmz, bpint, tic, rt, mobility, window_mz, window_mzlow, window_mzhigh, precursor_mz, precursor_intensity, precursor_charge, activation_ce FROM MS_SPECTRA_HEADERS WHERE project_id = ?";
      if (!selected_analyses.empty())
      {
        sql += " AND analysis IN (";
        for (std::size_t i = 0; i < selected_analyses.size(); ++i)
        {
          if (i > 0)
          {
            sql += ", ";
          }
          sql += "?";
        }
        sql += ")";
      }
      sql += " ORDER BY lower(analysis), analysis, index";
      project::db::run_prepared(guard.get(), sql, "query MS spectra headers", [&](duckdb_prepared_statement statement)
                                {
                          idx_t bind_index = 1;
                          duckdb_bind_varchar(statement, bind_index++, ctx_->project_id.c_str());
                          for (const auto& analysis : selected_analyses) {
                            duckdb_bind_varchar(statement, bind_index++, analysis.c_str());
                          } }, [&](duckdb_result &result)
                                { out = project::db::rows_from_result(&result, [&](idx_t row)
                                                                      { return spectra_header_row_from_result(result, row); }); });
      return out;
    }

    std::vector<MS_CHROMATOGRAM_HEADER_ROW> PROJECT_MASS_SPEC::get_chromatograms_headers(const std::vector<std::string> &analyses) const
    {
      auto guard = connect_checked(ctx_);
      std::vector<MS_CHROMATOGRAM_HEADER_ROW> out;
      const auto selected_analyses = spectra::sanitize_analyses(analyses);
      std::string sql = "SELECT project_id, analysis, index, id, array_length, polarity, precursor_mz, activation_ce, product_mz FROM MS_CHROMATOGRAMS_HEADERS WHERE project_id = ?";
      if (!selected_analyses.empty())
      {
        sql += " AND analysis IN (";
        for (std::size_t i = 0; i < selected_analyses.size(); ++i)
        {
          if (i > 0)
          {
            sql += ", ";
          }
          sql += "?";
        }
        sql += ")";
      }
      sql += " ORDER BY lower(analysis), analysis, index";
      project::db::run_prepared(guard.get(), sql, "query MS chromatogram headers", [&](duckdb_prepared_statement statement)
                                {
                          idx_t bind_index = 1;
                          duckdb_bind_varchar(statement, bind_index++, ctx_->project_id.c_str());
                          for (const auto& analysis : selected_analyses) {
                            duckdb_bind_varchar(statement, bind_index++, analysis.c_str());
                          } }, [&](duckdb_result &result)
                                { out = project::db::rows_from_result(&result, [&](idx_t row)
                                                                      { return chromatogram_header_row_from_result(result, row); }); });
      return out;
    }

    MS_SPECTRA_HEADERS_TABLE PROJECT_MASS_SPEC::collect_spectra_headers(const std::vector<std::string> &analyses) const
    {
      const auto rows = get_spectra_headers(analyses);
      MS_SPECTRA_HEADERS_TABLE out;
      out.project_id.reserve(rows.size());
      out.analysis.reserve(rows.size());
      out.index.reserve(rows.size());
      out.scan.reserve(rows.size());
      out.array_length.reserve(rows.size());
      out.level.reserve(rows.size());
      out.mode.reserve(rows.size());
      out.polarity.reserve(rows.size());
      out.configuration.reserve(rows.size());
      out.lowmz.reserve(rows.size());
      out.highmz.reserve(rows.size());
      out.bpmz.reserve(rows.size());
      out.bpint.reserve(rows.size());
      out.tic.reserve(rows.size());
      out.rt.reserve(rows.size());
      out.mobility.reserve(rows.size());
      out.window_mz.reserve(rows.size());
      out.window_mzlow.reserve(rows.size());
      out.window_mzhigh.reserve(rows.size());
      out.precursor_mz.reserve(rows.size());
      out.precursor_intensity.reserve(rows.size());
      out.precursor_charge.reserve(rows.size());
      out.activation_ce.reserve(rows.size());
      for (const auto &row : rows)
      {
        out.project_id.push_back(row.project_id);
        out.analysis.push_back(row.analysis);
        out.index.push_back(row.index);
        out.scan.push_back(row.scan);
        out.array_length.push_back(row.array_length);
        out.level.push_back(row.level);
        out.mode.push_back(row.mode);
        out.polarity.push_back(row.polarity);
        out.configuration.push_back(row.configuration);
        out.lowmz.push_back(row.lowmz);
        out.highmz.push_back(row.highmz);
        out.bpmz.push_back(row.bpmz);
        out.bpint.push_back(row.bpint);
        out.tic.push_back(row.tic);
        out.rt.push_back(row.rt);
        out.mobility.push_back(row.mobility);
        out.window_mz.push_back(row.window_mz);
        out.window_mzlow.push_back(row.window_mzlow);
        out.window_mzhigh.push_back(row.window_mzhigh);
        out.precursor_mz.push_back(row.precursor_mz);
        out.precursor_intensity.push_back(row.precursor_intensity);
        out.precursor_charge.push_back(row.precursor_charge);
        out.activation_ce.push_back(row.activation_ce);
      }
      return out;
    }

    MS_CHROMATOGRAMS_HEADERS_TABLE PROJECT_MASS_SPEC::collect_chromatograms_headers(const std::vector<std::string> &analyses) const
    {
      const auto rows = get_chromatograms_headers(analyses);
      MS_CHROMATOGRAMS_HEADERS_TABLE out;
      out.project_id.reserve(rows.size());
      out.analysis.reserve(rows.size());
      out.index.reserve(rows.size());
      out.id.reserve(rows.size());
      out.array_length.reserve(rows.size());
      out.polarity.reserve(rows.size());
      out.precursor_mz.reserve(rows.size());
      out.activation_ce.reserve(rows.size());
      out.product_mz.reserve(rows.size());
      for (const auto &row : rows)
      {
        out.project_id.push_back(row.project_id);
        out.analysis.push_back(row.analysis);
        out.index.push_back(row.index);
        out.id.push_back(row.id);
        out.array_length.push_back(row.array_length);
        out.polarity.push_back(row.polarity);
        out.precursor_mz.push_back(row.precursor_mz);
        out.activation_ce.push_back(row.activation_ce);
        out.product_mz.push_back(row.product_mz);
      }
      return out;
    }

    std::vector<MS_SPECTRA_TIC_ROW> PROJECT_MASS_SPEC::get_spectra_tic(const std::vector<std::string> &analyses,
                                                                       const std::vector<int> &levels,
                                                                       double rt_min,
                                                                       double rt_max) const
    {
      auto guard = connect_checked(ctx_);
      std::vector<MS_SPECTRA_TIC_ROW> out;
      const auto selected_analyses = spectra::sanitize_analyses(analyses);
      const bool filter_analyses = !selected_analyses.empty();
      const bool filter_rt = has_rt_window(rt_min, rt_max);
      std::string sql = "SELECT h.analysis, a.replicate, h.polarity, h.level, h.rt, h.tic, h.bpmz, h.bpint FROM MS_SPECTRA_HEADERS h LEFT JOIN MS_ANALYSES a ON a.project_id = h.project_id AND a.analysis = h.analysis WHERE h.project_id = ?";
      if (filter_analyses)
      {
        sql += " AND h.analysis IN (";
        for (std::size_t i = 0; i < selected_analyses.size(); ++i)
        {
          if (i > 0)
          {
            sql += ", ";
          }
          sql += "?";
        }
        sql += ")";
      }
      if (!levels.empty())
      {
        sql += " AND h.level IN (";
        for (std::size_t i = 0; i < levels.size(); ++i)
        {
          if (i > 0)
          {
            sql += ", ";
          }
          sql += "?";
        }
        sql += ")";
      }
      if (filter_rt)
      {
        sql += " AND h.rt >= ? AND h.rt <= ?";
      }
      sql += " ORDER BY lower(h.analysis), h.analysis, h.index";
      project::db::run_prepared(guard.get(), sql, "query MS spectra traces", [&](duckdb_prepared_statement statement)
                                {
                          idx_t bind_index = 1;
                          duckdb_bind_varchar(statement, bind_index++, ctx_->project_id.c_str());
                          for (const auto& analysis : selected_analyses) {
                            duckdb_bind_varchar(statement, bind_index++, analysis.c_str());
                          }
                          for (int level : levels) {
                            duckdb_bind_int32(statement, bind_index++, level);
                          }
                          if (filter_rt) {
                            duckdb_bind_double(statement, bind_index++, rt_min);
                            duckdb_bind_double(statement, bind_index++, rt_max);
                          } }, [&](duckdb_result &result)
                                { out = project::db::rows_from_result(&result, [&](idx_t row)
                                                                      {
                            MS_SPECTRA_TIC_ROW value;
                           value.analysis = project::db::result_varchar(&result, 0, row);
                           value.replicate = project::db::result_varchar(&result, 1, row);
                           value.polarity = duckdb_value_int32(&result, 2, row);
                           value.level = duckdb_value_int32(&result, 3, row);
                           value.rt = duckdb_value_double(&result, 4, row);
                           value.tic = duckdb_value_double(&result, 5, row);
                           value.bpmz = duckdb_value_double(&result, 6, row);
                           value.bpint = duckdb_value_double(&result, 7, row);
                           return value; }); });
      return out;
    }

    std::vector<MS_RAW_SPECTRUM_ROW> PROJECT_MASS_SPEC::get_raw_spectra(const spectra::MS_TARGETS_REQUEST &request) const
    {
      const auto format_elapsed_seconds = [](const std::chrono::steady_clock::time_point &start,
                                             const std::chrono::steady_clock::time_point &end)
      {
        std::ostringstream stream;
        stream << std::fixed << std::setprecision(2)
               << std::chrono::duration<double>(end - start).count();
        return stream.str();
      };
      const auto format_done_message = [&](const std::chrono::steady_clock::time_point &start,
                                           const std::chrono::steady_clock::time_point &end)
      {
        return std::string("Done! (") + format_elapsed_seconds(start, end) + " s)";
      };

      const auto prepare_targets_started = std::chrono::steady_clock::now();
      const auto analyses_rows = this->get_analyses();
      const auto selected_analyses = spectra::resolve_selected_analyses(request, analyses_rows);
      if (selected_analyses.empty())
      {
        const auto prepare_targets_finished = std::chrono::steady_clock::now();
        std::cout << "Prepare targets for extraction... "
                  << format_done_message(prepare_targets_started, prepare_targets_finished)
                  << std::endl;
        return {};
      }

      const auto headers = get_spectra_headers(selected_analyses);
      std::unordered_map<std::string, std::vector<const MS_SPECTRA_HEADER_ROW *>> headers_by_analysis;
      headers_by_analysis.reserve(selected_analyses.size());
      for (const auto &header : headers)
      {
        headers_by_analysis[header.analysis].push_back(&header);
      }

      auto targets_by_analysis = spectra::build_targets_by_analysis(request, selected_analyses, collect_unique_polarities(headers));
      if (!targets_by_analysis.empty() && targets_by_analysis.size() != selected_analyses.size())
      {
        throw project::error::ERROR(project::error::ERROR_CODE::InvalidArgument, "Mass spec raw_spectra targets must match analyses");
      }

      std::vector<int> selected_levels = request.levels;
      if (selected_levels.empty())
      {
        if (headers.empty())
        {
          return {};
        }
        selected_levels = unique_levels(headers);
      }

      bool all_traces = request.all_traces;
      if (!contains_level(selected_levels, 2))
      {
        all_traces = true;
      }

      const auto prepare_targets_finished = std::chrono::steady_clock::now();
      std::cout << "Prepare targets for extraction... "
                << format_done_message(prepare_targets_started, prepare_targets_finished)
                << std::endl;

      std::vector<MS_RAW_SPECTRUM_ROW> out;
      for (std::size_t analysis_index = 0; analysis_index < selected_analyses.size(); ++analysis_index)
      {
        const auto analysis_started = std::chrono::steady_clock::now();
        const auto &analysis = selected_analyses[analysis_index];
        const auto analysis_it = std::find_if(analyses_rows.begin(), analyses_rows.end(), [&](const auto &row)
                                              { return row.analysis == analysis; });
        if (analysis_it == analyses_rows.end())
        {
          continue;
        }

        spectra::MS_TARGETS analysis_targets;
        analysis_targets.resize_all(0);
        if (!targets_by_analysis.empty())
        {
          analysis_targets = spectra::subset_targets(targets_by_analysis[analysis_index],
                                                     selected_levels,
                                                     all_traces,
                                                     request.isolation_window);
        }

        const auto headers_rows_it = headers_by_analysis.find(analysis);
        if (headers_rows_it == headers_by_analysis.end() || headers_rows_it->second.empty())
        {
          const auto analysis_finished = std::chrono::steady_clock::now();
          std::cout << "Extracting spectra for analysis '" << analysis << "'... "
                    << format_done_message(analysis_started, analysis_finished)
                    << std::endl;
          continue;
        }
        const auto &headers_rows = headers_rows_it->second;

        for (std::size_t i = 0; i < analysis_targets.id.size(); ++i)
        {
          if (analysis_targets.rtmin[i] == 0.0f && analysis_targets.rtmax[i] == 0.0f)
          {
            const auto previous_default_id = spectra::spectra_targets::make_default_target_id(
                analysis_targets.mzmin[i],
                analysis_targets.mzmax[i],
                analysis_targets.rtmin[i],
                analysis_targets.rtmax[i],
                analysis_targets.mobilitymin[i],
                analysis_targets.mobilitymax[i]);

            analysis_targets.rtmin[i] = static_cast<float>(analysis_it->start_rt);
            analysis_targets.rtmax[i] = static_cast<float>(analysis_it->end_rt);
            analysis_targets.rt[i] = static_cast<float>((analysis_it->start_rt + analysis_it->end_rt) / 2.0);

            if (analysis_targets.id[i].empty() || analysis_targets.id[i] == previous_default_id)
            {
              analysis_targets.id[i] = spectra::spectra_targets::make_default_target_id(
                  analysis_targets.mzmin[i],
                  analysis_targets.mzmax[i],
                  analysis_targets.rtmin[i],
                  analysis_targets.rtmax[i],
                  analysis_targets.mobilitymin[i],
                  analysis_targets.mobilitymax[i]);
            }
          }
        }

        reader::MS_FILE file(analysis_it->file_path);

        if (!has_effective_targets(analysis_targets))
        {
          std::vector<int> indices;
          indices.reserve(headers_rows.size());
          for (const auto *header : headers_rows)
          {
            bool keep = selected_levels.empty();
            for (int level : selected_levels)
            {
              if (header->level == level)
              {
                keep = true;
                break;
              }
            }
            if (keep && header->configuration < 3)
            {
              indices.push_back(header->index);
            }
          }

          for (int index : indices)
          {
            const auto spectrum = file.get_spectrum(index);
            if (spectrum.binary_data.size() < 2)
            {
              continue;
            }
            const auto &mz = spectrum.binary_data[0];
            const auto &intensity = spectrum.binary_data[1];
            const std::size_t size = std::min(mz.size(), intensity.size());
            for (std::size_t i = 0; i < size; ++i)
            {
              const float current_intensity = intensity[i];
              if (spectrum.level == 1 && current_intensity < request.min_intensity_ms1)
                continue;
              if (spectrum.level >= 2 && current_intensity < request.min_intensity_ms2)
                continue;
              MS_RAW_SPECTRUM_ROW row;
              row.analysis = analysis;
              row.replicate = analysis_it->replicate;
              row.polarity = spectrum.polarity;
              row.level = spectrum.level;
              row.pre_mz = spectrum.precursor_mz;
              row.pre_mzlow = spectrum.window_mzlow;
              row.pre_mzhigh = spectrum.window_mzhigh;
              row.pre_ce = spectrum.activation_ce;
              row.rt = spectrum.rt;
              row.mobility = spectrum.mobility;
              row.mz = mz[i];
              row.intensity = current_intensity;
              out.push_back(row);
            }
          }
          const auto analysis_finished = std::chrono::steady_clock::now();
          std::cout << "Extracting spectra for analysis '" << analysis << "'... "
                    << format_done_message(analysis_started, analysis_finished)
                    << std::endl;
          continue;
        }

        std::vector<std::vector<int>> matched_headers(analysis_targets.id.size());
        std::vector<int> matched_indices;
        std::unordered_map<int, std::size_t> matched_index_lookup;
        matched_index_lookup.reserve(headers_rows.size());

        for (std::size_t header_position = 0; header_position < headers_rows.size(); ++header_position)
        {
          const auto *header = headers_rows[header_position];
          for (std::size_t target_index = 0; target_index < analysis_targets.id.size(); ++target_index)
          {
            if (!spectra::header_matches_target(*header, analysis_targets, target_index))
            {
              continue;
            }
            matched_headers[target_index].push_back(static_cast<int>(header_position));
            if (matched_index_lookup.find(static_cast<int>(header_position)) == matched_index_lookup.end())
            {
              matched_index_lookup.emplace(static_cast<int>(header_position), matched_indices.size());
              matched_indices.push_back(static_cast<int>(header_position));
            }
          }
        }

        if (matched_indices.empty())
        {
          const auto analysis_finished = std::chrono::steady_clock::now();
          std::cout << "Extracting spectra for analysis '" << analysis << "'... "
                    << format_done_message(analysis_started, analysis_finished)
                    << std::endl;
          continue;
        }

        const auto spectra_data = file.get_spectra(matched_indices);

        out.reserve(out.size() + matched_indices.size());
        for (std::size_t target_index = 0; target_index < analysis_targets.id.size(); ++target_index)
        {
          const auto [mmin, mmax] = spectra::target_mz_bounds(analysis_targets, target_index);
          for (int header_position : matched_headers[target_index])
          {
            if (header_position < 0 || static_cast<std::size_t>(header_position) >= headers_rows.size())
            {
              continue;
            }
            const auto *header = headers_rows[header_position];
            const auto raw_index_it = matched_index_lookup.find(header_position);
            if (raw_index_it == matched_index_lookup.end())
            {
              continue;
            }
            const auto &scan = spectra_data[raw_index_it->second];
            if (scan.size() < 2)
            {
              continue;
            }
            const std::size_t size = std::min(scan[0].size(), scan[1].size());
            for (std::size_t peak_index = 0; peak_index < size; ++peak_index)
            {
              const float mz_value = scan[0][peak_index];
              const float intensity_value = scan[1][peak_index];
              if (header->level == 1 && intensity_value < request.min_intensity_ms1)
              {
                continue;
              }
              if (header->level >= 2 && intensity_value < request.min_intensity_ms2)
              {
                continue;
              }
              if (mz_value < mmin || mz_value > mmax)
              {
                continue;
              }

              MS_RAW_SPECTRUM_ROW row;
              row.analysis = analysis;
              row.replicate = analysis_it->replicate;
              row.id = analysis_targets.id[target_index];
              row.polarity = header->polarity;
              row.level = header->level;
              row.pre_mz = header->precursor_mz;
              row.pre_mzlow = header->window_mzlow;
              row.pre_mzhigh = header->window_mzhigh;
              row.pre_ce = header->activation_ce;
              row.rt = header->rt;
              row.mobility = header->mobility;
              row.mz = mz_value;
              row.intensity = intensity_value;
              out.push_back(row);
            }
          }
        }
        const auto analysis_finished = std::chrono::steady_clock::now();
        std::cout << "Extracting spectra for analysis '" << analysis << "'... "
                  << format_done_message(analysis_started, analysis_finished)
                  << std::endl;
      }

      std::sort(out.begin(), out.end(), [](const auto &lhs, const auto &rhs)
                {
    if (lhs.analysis != rhs.analysis) return lhs.analysis < rhs.analysis;
    if (lhs.id != rhs.id) return lhs.id < rhs.id;
    if (lhs.rt != rhs.rt) return lhs.rt < rhs.rt;
    return lhs.mz < rhs.mz; });
      return out;
    }

    std::vector<std::vector<std::vector<float>>> PROJECT_MASS_SPEC::get_chromatograms_data(const std::string &analysis,
                                                                                           const std::vector<int> &indices) const
    {
      const auto analyses_rows = this->get_analyses();
      const auto analysis_it = std::find_if(analyses_rows.begin(), analyses_rows.end(), [&](const auto &row)
                                            { return row.analysis == analysis; });
      if (analysis_it == analyses_rows.end())
      {
        return {};
      }

      reader::MS_FILE file(analysis_it->file_path);
      return file.get_chromatograms(indices);
    };

    PROJECT_MASS_SPEC_SPECTRA::PROJECT_MASS_SPEC_SPECTRA(std::shared_ptr<project::api::CONTEXT> ctx,
                                                         const std::vector<std::string> &file_paths,
                                                         const std::vector<std::string> &replicates,
                                                         const std::vector<std::string> &blanks)
        : ctx_(std::move(ctx)), base_(ctx_, file_paths, replicates, blanks)
    {
      project::PROJECT root(ctx_->db_path, ctx_->project_id);
      root.set_domain("mass_spec_spectra");
    };

    const std::shared_ptr<project::api::CONTEXT> &PROJECT_MASS_SPEC_SPECTRA::context() const noexcept
    {
      return ctx_;
    };

    PROJECT_MASS_SPEC &PROJECT_MASS_SPEC_SPECTRA::base() noexcept
    {
      return base_;
    };

    const PROJECT_MASS_SPEC &PROJECT_MASS_SPEC_SPECTRA::base() const noexcept
    {
      return base_;
    };

    PROJECT_MASS_SPEC_CHROMATOGRAMS::PROJECT_MASS_SPEC_CHROMATOGRAMS(std::shared_ptr<project::api::CONTEXT> ctx,
                                                                     const std::vector<std::string> &file_paths,
                                                                     const std::vector<std::string> &replicates,
                                                                     const std::vector<std::string> &blanks)
        : ctx_(std::move(ctx)), base_(ctx_, file_paths, replicates, blanks)
    {
      project::PROJECT root(ctx_->db_path, ctx_->project_id);
      root.set_domain("mass_spec_chromatograms");
    };

    const std::shared_ptr<project::api::CONTEXT> &PROJECT_MASS_SPEC_CHROMATOGRAMS::context() const noexcept
    {
      return ctx_;
    };

    PROJECT_MASS_SPEC &PROJECT_MASS_SPEC_CHROMATOGRAMS::base() noexcept
    {
      return base_;
    };

    const PROJECT_MASS_SPEC &PROJECT_MASS_SPEC_CHROMATOGRAMS::base() const noexcept
    {
      return base_;
    };

  } // namespace api

} // namespace mass_spec
